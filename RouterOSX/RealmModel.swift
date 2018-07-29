import RealmSwift

class MapArea: Object {
    @objc dynamic var centerLat = 0.0
    @objc dynamic var centerLon = 0.0
    @objc dynamic var width = 0.0
    @objc dynamic var height = 0.0
}

class Point: Object {
    @objc dynamic var name = ""
    @objc dynamic var lat: Double = 0.0
    @objc dynamic var lon: Double = 0.0
}

class Stage: Object {
    @objc dynamic var competitionName = ""
    @objc dynamic var stageNumber = 0
    @objc dynamic var binMapFileName = ""
    @objc dynamic var mapArea: MapArea? = nil
    let points = List<Point>()
}
