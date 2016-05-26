import Foundation

struct HashablePoint: Hashable {
    let lat: Double
    let lon: Double

    var hashValue: Int {
        get {
            return "\(lat) \(lon)".hashValue
        }
    }
}

func ==(lhs: HashablePoint, rhs: HashablePoint) -> Bool {
    return lhs.lat == rhs.lat && lhs.lon == rhs.lon
}
