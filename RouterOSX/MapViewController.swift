import Cocoa
import MapKit

class MapViewController: NSViewController {
    @IBOutlet weak var mapView: MKMapView!

    var stage: Stage!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let mapArea = stage.mapArea {
            let center = CLLocationCoordinate2D(latitude: mapArea.centerLat, longitude: mapArea.centerLon)
            let span = MKCoordinateSpan(latitudeDelta: mapArea.height, longitudeDelta: mapArea.width)
            mapView.region = MKCoordinateRegion(center: center, span: span)
        }
    }
}
