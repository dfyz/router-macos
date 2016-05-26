import CoreLocation
import Foundation

protocol WithCoordinates {
    var lat: Double { get }
    var lon: Double { get }
}

extension HashablePoint: WithCoordinates {}
extension OsmNode.LazyAccess: WithCoordinates {}

class Router {
    let points: [HashablePoint]
    let graph: OsmGraph.LazyAccess

    init(points: [HashablePoint], binMapFileName: String) {
        self.points = points
        print(binMapFileName)
        graph = OsmGraph.LazyAccess(data: UnsafePointer(NSData(contentsOfFile: binMapFileName)!.bytes))
    }

    func route() throws -> [Int] {
        return [0, 2, 1] + Array(3..<points.count)
    }

    private func getNearestPointIndex(point: HashablePoint) -> Int? {
        var result: Int? = nil
        var minDistance = Double.infinity
        for (idx, node) in graph.nodes.enumerate() {
            if node.adj.count == 0 {
                continue
            }

            let newCost = getDistance(from: node, to: point)
            if newCost < minDistance {
                minDistance = newCost
                result = idx
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
