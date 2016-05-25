import Foundation

struct HashablePoint: Hashable {
    var lat: Double = 0.0
    var lon: Double = 0.0

    var hashValue: Int {
        get {
            return "\(lat) \(lon)".hashValue
        }
    }
}

func ==(lhs: HashablePoint, rhs: HashablePoint) -> Bool {
    return lhs.lat == rhs.lat && lhs.lon == rhs.lon
}
