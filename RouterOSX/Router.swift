import CoreLocation
import Foundation
import SwiftPriorityQueue

enum RoutingError: Error {
    case abortedByUser
    case error(String)
}

struct NamedPoint {
    let name: String
    let lat: Double
    let lon: Double
}

struct RouteSegment {
    let startPointIndex: Int
    let path: [CLLocationCoordinate2D]
    let distance: Double
}

struct RoutingResult {
    let segments: [RouteSegment]
}

typealias ProgressCallback = (String, Double?) -> Bool

class Router {
    let points: [NamedPoint]
    let graph: OsmGraph
    let callback: ProgressCallback

    init(points: [NamedPoint], binMapFileName: String, callback: @escaping ProgressCallback) throws {
        self.points = points
        guard let mapData = try? Data(contentsOf: URL(fileURLWithPath: binMapFileName)) else {
            throw RoutingError.error("Failed to load \(binMapFileName)")
        }
        guard let mappedGraph = OsmGraph.makeOsmGraph(data: mapData) else {
            throw RoutingError.error("Failed to map graph data from \(binMapFileName) to memory")
        }
        self.graph = mappedGraph
        self.callback = callback
    }

    func route() throws -> RoutingResult {
        let osmNodeIndexes = try getNearestOsmNodes()
        let allPaths = try getAllPaths(osmNodeIndexes)

        let costMatrix = allPaths.map { row in row.map { $0.cost } }

        if !callback("Solving TSP", nil) {
            throw RoutingError.abortedByUser
        }
        let permutation = solveTsp(costMatrix)

        var segments = [RouteSegment]()
        var totalDistance = 0.0
        if !permutation.isEmpty {
            for i in 1 ..< permutation.count {
                let from = permutation[i - 1]
                let to = permutation[i]

                var path = [CLLocationCoordinate2D]()

                let fromPoint = points[from]
                path.append(CLLocationCoordinate2D(latitude: fromPoint.lat, longitude: fromPoint.lon))

                path.append(contentsOf: allPaths[from][to].path)

                let toPoint = points[to]
                path.append(CLLocationCoordinate2D(latitude: toPoint.lat, longitude: toPoint.lon))

                let distance = costMatrix[from][to]
                totalDistance += distance
                segments.append(RouteSegment(startPointIndex: from, path: path, distance: distance))
            }
            segments.append(RouteSegment(startPointIndex: permutation.last!, path: [], distance: totalDistance))
        }

        return RoutingResult(segments: segments)
    }

    fileprivate func getAllPaths(_ osmNodeIndexes: [Int]) throws -> [[FoundPath]] {
        let n = osmNodeIndexes.count
        return try (0..<n).map {
            from in
            return try (0..<n).map {
                to in

                let fromName = self.points[from].name
                let toName = self.points[to].name

                let progress = Double(from*n + to) / Double(n*n)
                if !callback("Searching for a path from \(fromName) to \(toName)", progress) {
                    throw RoutingError.abortedByUser
                }

                guard let path = getPath(osmNodeIndexes[from], to: osmNodeIndexes[to]) else {
                    throw RoutingError.error("Failed to compute path between \(fromName) and \(toName)")
                }
                return path
            }
        }
    }

    fileprivate func getPath(_ from: Int, to: Int) -> FoundPath? {
        if from == to {
            return FoundPath(path: [], cost: 0.0)
        }

        let n = graph.nodes.count

        var prevIndex = [Int?](repeating: nil, count: n)
        var dist = [Double](repeating: Double.infinity, count: n)

        dist[from] = 0.0

        let startState = PathfindingState(index: from, cost: 0.0)
        var heap = PriorityQueue<PathfindingState>(ascending: true, startingValues: [startState])

        let getNode = { (idx: Int) in self.graph.nodes[idx] }

        while let current = heap.pop() {
            if current.index == to {
                break
            }

            for next in getNode(current.index).adj {
                let nextIndex = Int(next)
                let newDist = dist[current.index] + getDistance(getNode(current.index), to: getNode(nextIndex))
                if newDist < dist[nextIndex] {
                    dist[nextIndex] = newDist
                    let priority = newDist + getDistance(getNode(nextIndex), to: getNode(to))
                    heap.push(PathfindingState(index: nextIndex, cost: priority))
                    prevIndex[nextIndex] = current.index
                }
            }
        }

        if prevIndex[to] == nil {
            return nil
        }

        var indexes = [to]
        var current = to
        while let prev = prevIndex[current] {
            indexes.append(prev)
            current = prev
        }
        indexes = indexes.reversed()

        let finalPath: [CLLocationCoordinate2D] = indexes.map {
            idx in
            let node = getNode(idx)
            return CLLocationCoordinate2D(latitude: node.lat, longitude: node.lon)
        }
        return FoundPath(path: finalPath, cost: dist[to])
    }

    fileprivate func getNearestOsmNodes() throws -> [Int] {
        return try points.enumerated().map {
            (idx, point) in

            if !callback("Preprocessing \(point.name)", Double(idx) / Double(points.count)) {
                throw RoutingError.abortedByUser
            }
            guard let result = getNearestOsmNodeIndex(point) else {
                throw RoutingError.error("Failed to find an osm node for \(point.name)")
            }
            return result
        }
    }

    fileprivate func getNearestOsmNodeIndex(_ point: NamedPoint) -> Int? {
        var result: Int? = nil
        var minDistance = Double.infinity
        for (idx, node) in graph.nodes.enumerated() {
            if node.adj.count == 0 {
                continue
            }

            let newCost = getDistance(node, to: point)
            if newCost < minDistance {
                minDistance = newCost
                result = idx
            }
        }
        return result
    }

    fileprivate func getDistance(_ from: WithCoordinates, to: WithCoordinates) -> Double {
        let locationA = CLLocation(latitude: from.lat, longitude: from.lon)
        let locationB = CLLocation(latitude: to.lat, longitude: to.lon)
        return locationA.distance(from: locationB)
    }
}

private struct PathfindingState: Comparable {
    let index: Int
    let cost: Double
}

private func ==(lhs: PathfindingState, rhs: PathfindingState) -> Bool {
    return lhs.index == rhs.index && lhs.cost == rhs.cost
}

private func <(lhs: PathfindingState, rhs: PathfindingState) -> Bool {
    return lhs.cost < rhs.cost
}

private struct FoundPath {
    let path: [CLLocationCoordinate2D]
    let cost: Double
}


private protocol WithCoordinates {
    var lat: Double { get }
    var lon: Double { get }
}

extension NamedPoint: WithCoordinates {}
extension OsmNode: WithCoordinates {}
