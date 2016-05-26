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
        let osmNodes: [LazyOsmNode] =
            try points.map {
                point in
                guard let result = getNearestOsmNode(point) else {
                    throw RoutingError.Error("Failed to find an osm node for \(point.name)")
                }
                return result
            }
        return []
    }

    private func getNearestOsmNode(point: NamedPoint) -> LazyOsmNode? {
        var result: LazyOsmNode? = nil
        var minDistance = Double.infinity
        for node in graph.nodes {
            if node.adj.count == 0 {
                continue
            }

            let newCost = getDistance(from: node, to: point)
            if newCost < minDistance {
                minDistance = newCost
                result = node
            }
        }
        return result
    }

    private func getDistance(from a: WithCoordinates, to b: WithCoordinates) -> Double {
        let locationA = CLLocation(latitude: a.lat, longitude: a.lon)
        let locationB = CLLocation(latitude: b.lat, longitude: b.lon)
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
