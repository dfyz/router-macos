import CoreLocation
import Foundation
import MapKit

protocol WithCoordinates {
    var lat: Double { get }
    var lon: Double { get }
}

func getDistance(from: WithCoordinates, to: WithCoordinates) -> Double {
    let locationA = CLLocation(latitude: from.lat, longitude: from.lon)
    let locationB = CLLocation(latitude: to.lat, longitude: to.lon)
    return locationA.distanceFromLocation(locationB)
}

func getArrowPolygons(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> [MKPolygon] {
    var result = [MKPolygon]()

    let mFrom = MKMapPointForCoordinate(from)
    let mTo = MKMapPointForCoordinate(to)

    let delta = MKMetersBetweenMapPoints(mFrom, mTo) / 50.0
    let mDelta = (mTo - mFrom) / delta

    let steps = Int(delta)

    if steps > 0 {
        var currentFrom = mFrom
        for _ in 1 ... steps {
            let currentTo = currentFrom + mDelta
            if let arrow = getArrowPolygon(currentFrom, currentTo) {
                result.append(arrow)
            }
            currentFrom = currentTo
        }
    }

    return result
}

private func getArrowPolygon(mFrom: MKMapPoint, _ mTo: MKMapPoint) -> MKPolygon? {
    if mFrom.x == mTo.x && mFrom.y == mTo.y {
        return nil
    }

    let center = (mFrom + mTo) / 2.0
    let unit = (mTo - mFrom) / MKMetersBetweenMapPoints(mFrom, mTo)
    let nUnit = MKMapPoint(x: -unit.y, y: unit.x)

    let c1 = center + 0.1 * unit
    let d = center - 0.02 * nUnit
    let e = center + 0.02 * nUnit

    var points = [d, c1, e]
    return MKPolygon(points: &points, count: points.count)
}

private func+(a: MKMapPoint, b: MKMapPoint) -> MKMapPoint {
    return MKMapPoint(x: a.x + b.x, y: a.y + b.y)
}

private func-(a: MKMapPoint, b: MKMapPoint) -> MKMapPoint {
    return a + (-1.0)*b
}

private func*(a: Double, b: MKMapPoint) -> MKMapPoint {
    return MKMapPoint(x: a * b.x, y: a * b.y)
}

private func/(a: MKMapPoint, b: Double) -> MKMapPoint {
    return (1.0 / b) * a
}

extension CLLocationCoordinate2D: WithCoordinates {
    var lat: Double { return latitude }
    var lon: Double { return longitude }
}
