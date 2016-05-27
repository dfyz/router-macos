import CoreLocation
import Foundation
import SwiftPriorityQueue

enum RoutingError: ErrorType {
    case Error(String)
}

struct NamedPoint {
    let name: String
    let lat: Double
    let lon: Double
}

struct RoutingResult {
    let pointIndexes: [Int]
    let path: [NamedPoint]
}

class Router {
    let points: [NamedPoint]
    let graph: OsmGraph.LazyAccess

    init(points: [NamedPoint], binMapFileName: String) throws {
        self.points = points
        guard let mapData = NSData(contentsOfFile: binMapFileName) else {
            throw RoutingError.Error("Failed to load \(binMapFileName)")
        }
        graph = OsmGraph.LazyAccess(data: UnsafePointer(mapData.bytes))
    }

    func route() throws -> RoutingResult {
        let osmNodes = try getNearestOsmNodes()
        let allPaths = try getAllPaths(osmNodes)

        throw RoutingError.Error("not implemented")
    }

    private func getAllPaths(osmNodes: [LazyOsmNode]) throws -> [[FoundPath]] {
        let n = osmNodes.count
        return try (0..<n).map {
            from in
            return try (0..<n).map {
                to in
                guard let path = getPath(from, to: to) else {
                    let fromName = self.points[from].name
                    let toName = self.points[to].name
                    throw RoutingError.Error("Failed to compute path between \(fromName) and \(toName)")
                }
                return path
            }
        }
    }

    private func getPath(from: Int, to: Int) -> FoundPath? {
        let n = graph.nodes.count

        var prevIndex = [Int?](count: n, repeatedValue: nil)
        var dist = [Double](count: n, repeatedValue: Double.infinity)

        dist[from] = 0.0

        let startState = PathfindingState(index: from, cost: 0.0)
        var heap = PriorityQueue<PathfindingState>(startingValues: [startState])

        let getNode = { idx in self.graph.nodes[idx]! }

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
        indexes = indexes.reverse()

        let finalPath: [CLLocation] = indexes.map {
            idx in
            let node = getNode(idx)
            return CLLocation(latitude: node.lat, longitude: node.lon)
        }
        return FoundPath(path: finalPath, cost: dist[to])
    }

    private func getNearestOsmNodes() throws -> [LazyOsmNode] {
        return try points.map {
            point in
            guard let result = getNearestOsmNode(point) else {
                throw RoutingError.Error("Failed to find an osm node for \(point.name)")
            }
            return result
        }
    }

    private func getNearestOsmNode(point: NamedPoint) -> LazyOsmNode? {
        var result: LazyOsmNode? = nil
        var minDistance = Double.infinity
        for node in graph.nodes {
            if node.adj.count == 0 {
                continue
            }

            let newCost = getDistance(node, to: point)
            if newCost < minDistance {
                minDistance = newCost
                result = node
            }
        }
        return result
    }

    private func getDistance(from: WithCoordinates, to: WithCoordinates) -> Double {
        let locationA = CLLocation(latitude: from.lat, longitude: from.lon)
        let locationB = CLLocation(latitude: to.lat, longitude: to.lon)
        return locationA.distanceFromLocation(locationB)
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
    let path: [CLLocation]
    let cost: Double
}

private typealias LazyOsmNode = OsmNode.LazyAccess

private protocol WithCoordinates {
    var lat: Double { get }
    var lon: Double { get }
}

extension NamedPoint: WithCoordinates {}
extension LazyOsmNode: WithCoordinates {}
