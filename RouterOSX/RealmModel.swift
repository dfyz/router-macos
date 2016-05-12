import RealmSwift

class MapArea: Object {
    dynamic var centerLat = 0.0
    dynamic var centerLon = 0.0
    dynamic var width = 0.0
    dynamic var height = 0.0
}

class Point: Object {
    dynamic var number = 0
    dynamic var name = ""
    dynamic var lat: Double = 0.0
    dynamic var lon: Double = 0.0
}

class Stage: Object {
    dynamic var competitionName = ""
    dynamic var stageNumber = 0
    dynamic var binMapFileName = ""
    dynamic var mapArea: MapArea? = nil
    let points = List<Point>()
}