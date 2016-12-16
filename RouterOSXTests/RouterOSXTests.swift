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

        XCTAssertEqual([0, 6, 1, 9, 3, 5, 10, 7, 4, 2, 8, 11], result.pointIndexes)

        var totalDistance = 0.0
        for i in 1..<result.path.count {
            let a = result.path[i - 1]
            let b = result.path[i]
            let aa = CLLocation(latitude: a.latitude, longitude: a.longitude)
            let bb = CLLocation(latitude: b.latitude, longitude: b.longitude)
            totalDistance += aa.distance(from: bb)
        }

        XCTAssertLessThanOrEqual(totalDistance, 7064)
    }
}
