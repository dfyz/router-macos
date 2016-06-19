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

func getArrowPolygon(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> MKPolygon? {
    if from.latitude == to.latitude && from.longitude == to.longitude {
        return nil
    }

    let mFrom = MKMapPointForCoordinate(from)
    let mTo = MKMapPointForCoordinate(to)

    let center = (mFrom + mTo) / 2.0
    let unit = (mTo - mFrom) / MKMetersBetweenMapPoints(mFrom, mTo)
    let nUnit = MKMapPoint(x: -unit.y, y: unit.x)

    let c1 = center - 0.1 * unit
    let c2 = center + 0.5 * unit
    let d = c1 - 0.15 * nUnit
    let e = c1 + 0.15 * nUnit

    var points = [d, c2, e, center]
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
