import CoreLocation
import XCTest

@testable import RouterOSX

class RouterOSXTests: XCTestCase {
    func testRouter() {
        let points = [
            NamedPoint(name: "Литейная 23", lat: 56.33086, lon: 36.725033),
            NamedPoint(name: "Бородинский проезд, д. 7", lat: 56.326416, lon: 36.726806),
            NamedPoint(name: "Советская площадь", lat: 56.335216, lon: 36.733253),
            NamedPoint(name: "Ново-Ямская ул., д. 3", lat: 56.333694, lon: 36.716185),
            NamedPoint(name: "Советская пл., д. 18", lat: 56.336059, lon: 36.733558),
            NamedPoint(name: "Старо-Ямская ул., д. 12", lat: 56.3380952, lon: 36.7209823),
            NamedPoint(name: "ул. Крюкова, д. 3", lat: 56.328249, lon: 36.723129),
            NamedPoint(name: "наб. Бычкова, д.12", lat: 56.339587, lon: 36.727746),
            NamedPoint(name: "Театральная ул., д. 8", lat: 56.335346, lon: 36.728375),
            NamedPoint(name: "ул. Карла Маркса, д. 66", lat: 56.323281, lon: 36.719367),
            NamedPoint(name: "Музей Ёлочной игрушки", lat: 56.33815695, lon: 36.7214630479723),
            NamedPoint(name: "ул. Ленина, д. 18", lat: 56.336917, lon: 36.728824),
        ]

        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "mini_klin", ofType: "bin")!

        let router = try! Router(points: points, binMapFileName: path) {
            (text, _)
            in
            return true
        }
        let result = try! router.route()

        XCTAssertEqual([0, 6, 1, 9, 3, 5, 10, 7, 4, 2, 8, 11], result.segments.map { x in x.startPointIndex })

        var totalDistance = 0.0
        for seg in result.segments {
            if seg.path.isEmpty {
                continue
            }
            for i in 1..<seg.path.count {
                let a = seg.path[i - 1]
                let b = seg.path[i]
                let aa = CLLocation(latitude: a.latitude, longitude: a.longitude)
                let bb = CLLocation(latitude: b.latitude, longitude: b.longitude)
                totalDistance += aa.distance(from: bb)
            }
        }

        XCTAssertLessThanOrEqual(totalDistance, 7064)
    }

    func testTsp21() {
        let expected: [Int] = [0, 17, 2, 10, 11, 14, 6, 20, 1, 4, 15, 5, 7, 8, 12, 19, 13, 16, 3, 18, 9, 21]
        XCTAssertEqual(pathCost(expected, tsp21), pathCost(solveTsp(tsp21), tsp21))
    }

    func testTsp29() {
        let expected: [Int] = [0, 2, 8, 3, 4, 1, 5, 10, 6, 7, 9, 17, 18, 14, 16, 19, 28, 21, 15, 12, 13, 11, 27, 25, 20, 26, 22, 23, 24, 29]
        XCTAssertEqual(pathCost(expected, tsp29), pathCost(solveTsp(tsp29), tsp29))
    }

    func testTsp49() {
        let expected: [Int] = [0, 3, 24, 19, 25, 23, 33, 39, 29, 36, 27, 22, 26, 20, 21, 14, 8, 15, 10, 13, 34, 12, 16, 7, 32, 9, 28, 43, 42, 41, 45, 38, 46, 30, 35, 40, 44, 37, 6, 2, 4, 5, 1, 31, 18, 47, 11, 17, 48]
        XCTAssertEqual(pathCost(expected, tsp49), pathCost(solveTsp(tsp49), tsp49))
    }

    fileprivate func pathCost(_ indexes: [Int], _ costMatrix: [[Double]]) -> Double {
        var res = 0.0
        for i in 1..<indexes.count {
            res += costMatrix[indexes[i - 1]][indexes[i]]
        }
        return res
    }
}
