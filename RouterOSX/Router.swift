import CoreLocation
import Foundation

enum RoutingError: ErrorType {
    case Error(String)
}

struct NamedPoint {
    let name: String
    let lat: Double
    let lon: Double
}

class Router {
    let points: [NamedPoint]
    let graph: OsmGraph.LazyAccess

    init(points: [NamedPoint], binMapFileName: String) {
        self.points = points
        print(binMapFileName)
        graph = OsmGraph.LazyAccess(data: UnsafePointer(NSData(contentsOfFile: binMapFileName)!.bytes))
    }

    func route() throws -> [Int] {
        let osmNodes = try getNearestOsmNodes()
        let allPaths = try getAllPaths(osmNodes)

        return []
    }

    private func getAllPaths(osmNodes: [LazyOsmNode]) throws -> [[FoundPath]] {
        let n = osmNodes.count
        return try (0..<n).map {
            from in
            return try (0..<n).map {
                to in
                guard let path = getPath(osmNodes[from], to: osmNodes[to]) else {
                    let fromName = self.points[from].name
                    let toName = self.points[to].name
                    throw RoutingError.Error("Failed to compute path between \(fromName) and \(toName)")
                }
                return path
            }
        }
    }

    private func getPath(from: LazyOsmNode, to: LazyOsmNode) -> FoundPath? {
        return nil
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

private struct FoundPath {
    let path: [LazyOsmNode]
    let cost: Double
}

private typealias LazyOsmNode = OsmNode.LazyAccess

private protocol WithCoordinates {
    var lat: Double { get }
    var lon: Double { get }
}

extension NamedPoint: WithCoordinates {}
extension LazyOsmNode: WithCoordinates {}
