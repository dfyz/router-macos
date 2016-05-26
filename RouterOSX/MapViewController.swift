import Cocoa
import MapKit
import RealmSwift

class PointAnnotation: MKPointAnnotation {
    var permanent = false
}

class MapViewController: NSViewController, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var geocoderTextField: NSTextField!
    @IBOutlet weak var geocoderClearButton: NSButton!
    @IBOutlet weak var pointTableView: NSTableView!

    var realm: Realm!
    var stage: Stage!
    var geocodingResults: GeocodingResultTable?
    var mapMonitor: AnyObject!
    var pointToAnnotation = [HashablePoint: PointAnnotation]()

    override func viewDidLoad() {
        super.viewDidLoad()

        realm = try! Realm()

        geocoderTextField.wantsLayer = true
        geocoderTextField.delegate = self
        geocoderTextField.becomeFirstResponder()

        geocoderClearButton.wantsLayer = true

        let osmTileTemplate = "http://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let osmOverlay = MKTileOverlay(URLTemplate: osmTileTemplate)
        osmOverlay.canReplaceMapContent = true
        mapView.addOverlay(osmOverlay)

        self.mapMonitor = NSEvent.addLocalMonitorForEventsMatchingMask(.RightMouseUpMask, handler: onMapRightClick)
        mapView.delegate = self

        pointTableView.setDataSource(self)
        pointTableView.setDelegate(self)
        pointTableView.registerForDraggedTypes(["point.index"])

        hideGeocodingResults()

        for point in stage.points {
            addPointToMap(point.name, lat: point.lat, lon: point.lon, permanent: true)
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        if stage == nil {
            return
        }

        view.window?.title = "\(stage.competitionName) — \(stage.stageNumber)"

        if let screenFrame = NSScreen.mainScreen()?.visibleFrame {
            view.window?.setFrame(screenFrame, display: true)
        }

        onGetOverview(self)
    }

    override func viewWillDisappear() {
        NSEvent.removeMonitor(mapMonitor)
    }

    @IBAction func onGeocodingRequest(sender: AnyObject) {
        hideGeocodingResults()

        let place = "\(geocoderTextField.stringValue) \(stage?.competitionName ?? String())"
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let geocoder = Geocoder(place: place) {
                results in

                if self.geocodingResults == nil {
                    self.showGeocodingResults()
                }
                self.geocodingResults!.addResults(results)
            }

            geocoder.geocode()
        }
    }

    @IBAction func onGeocoderClear(sender: AnyObject) {
        hideGeocodingResults()
    }

    @IBAction func onPointSelected(sender: AnyObject) {
        guard let point = getSelectedPoint() else {
            return
        }

        if let annotation = pointToAnnotation[HashablePoint(lat: point.lat, lon: point.lon)] {
            mapView.selectAnnotation(annotation, animated: true)
            let coords = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
            mapView.setCenterCoordinate(coords, animated: true)
        }
    }

    @IBAction func onPointNameEdited(sender: NSTextField) {
        guard let point = getSelectedPoint() else {
            return
        }

        let newValue = sender.stringValue

        try! realm.write {
            point.name = newValue
        }

        if let annotation = pointToAnnotation[HashablePoint(lat: point.lat, lon: point.lon)] {
            annotation.title = newValue
        }

        reloadPoints()
    }

    @IBAction func onDeleteItem(sender: AnyObject) {
        guard let point = getSelectedPoint() else {
            return
        }

        if let annotation = pointToAnnotation[HashablePoint(lat: point.lat, lon: point.lon)] {
            mapView.removeAnnotation(annotation)
        }

        try! realm.write {
            realm.delete(point)
        }

        reloadPoints()
    }

    func onGetOverview(sender: AnyObject) {
        if !pointToAnnotation.isEmpty {
            mapView.showAnnotations(mapView.annotations, animated: true)
            return
        }
        let mapArea = stage.mapArea!
        let center = CLLocationCoordinate2D(latitude: mapArea.centerLat, longitude: mapArea.centerLon)
        let span = MKCoordinateSpan(latitudeDelta: mapArea.height, longitudeDelta: mapArea.width)
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: true)
    }

    func onRoute(sender: AnyObject) {
        let points = stage.points.map { NamedPoint(name: $0.name, lat: $0.lat, lon: $0.lon) }
        let router = Router(points: points, binMapFileName: stage.binMapFileName)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let indexes: [Int]
            do {
                indexes = try router.route()
            } catch RoutingError.Error(let message) {
                print(message)
                return
            } catch {
                fatalError("Should never happen")
            }

            dispatch_async(dispatch_get_main_queue()) {
                try! self.realm.write {
                    let newPoints = List<Point>()
                    for idx in indexes {
                        newPoints.append(self.stage.points[idx])
                    }
                    self.stage.points.removeAll()
                    self.stage.points.appendContentsOf(newPoints)
                }

                self.reloadPoints()
            }
        }
    }

    func onMapRightClick(event: NSEvent) -> NSEvent? {
        if event.window == view.window {
            let locationInMapView = mapView.convertPoint(event.locationInWindow, fromView: nil)
            let clickedCoords = mapView.convertPoint(locationInMapView, toCoordinateFromView: mapView)
            let clickedPoint = MKMapPointForCoordinate(clickedCoords)
            if MKMapRectContainsPoint(mapView.visibleMapRect, clickedPoint) {
                addPointToMap(
                    "HERE BE DRAGONS",
                    lat: clickedCoords.latitude,
                    lon: clickedCoords.longitude,
                    permanent: false
                )
            }
        }
        return event
    }

    func control(
        control: NSControl,
        textView: NSTextView,
        completions words: [String],
        forPartialWordRange charRange: NSRange,
        indexOfSelectedItem index: UnsafeMutablePointer<Int>
    ) -> [String]
    {
        hideGeocodingResults()
        return []
    }

    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        guard let osmOverlay = overlay as? MKTileOverlay else {
            return MKOverlayRenderer()
        }
        return MKTileOverlayRenderer(tileOverlay: osmOverlay)
    }

    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        guard let point = annotation as? PointAnnotation else {
            return nil
        }

        let result = MKPinAnnotationView(annotation: point, reuseIdentifier: nil)
        result.canShowCallout = true

        if !point.permanent {
            let button = NSButton()
            button.bezelStyle = .SmallSquareBezelStyle
            button.image = NSImage(named: NSImageNameAddTemplate)
            button.target = self
            button.action = #selector(makePointPermanent)
            result.rightCalloutAccessoryView = button
        }

        return result
    }

    func mapView(mapView: MKMapView, didDeselectAnnotationView view: MKAnnotationView) {
        guard
            let annotationView = view as? MKPinAnnotationView,
            let point = annotationView.annotation as? PointAnnotation
        else {
            return
        }

        if !point.permanent {
            mapView.removeAnnotation(point)
        }
    }

    func makePointPermanent(sender: NSButton?) {
        guard let btn = sender else {
            return
        }

        var currentView = btn.superview
        while currentView != nil {
            if let annotationView = currentView as? MKPinAnnotationView {
                if let point = annotationView.annotation as? PointAnnotation {
                    addPointToRealm(point)
                    mapView.removeAnnotation(point)
                    point.permanent = true
                    mapView.addAnnotation(point)
                    mapView.selectAnnotation(point, animated: false)
                    break
                }
            }
            currentView = currentView!.superview
        }
    }

    func addPointToRealm(point: PointAnnotation) {
        let permanentPoint = Point()
        try! realm.write {
            permanentPoint.name = point.title!
            permanentPoint.lat = point.coordinate.latitude
            permanentPoint.lon = point.coordinate.longitude
            stage.points.append(permanentPoint)
        }
        pointToAnnotation[HashablePoint(lat: permanentPoint.lat, lon: permanentPoint.lon)] = point

        reloadPoints()
    }

    func addPointToMap(name: String, lat: Double, lon: Double, permanent: Bool) {
        let point = PointAnnotation()
        let coords = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        point.coordinate = coords
        point.title = name
        point.permanent = permanent
        mapView.addAnnotation(point)

        if !permanent {
            mapView.selectAnnotation(point, animated: true)
            mapView.setCenterCoordinate(coords, animated: true)
            hideGeocodingResults()
        } else {
            pointToAnnotation[HashablePoint(lat: lat, lon: lon)] = point
        }
    }

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        realm.refresh()
        return stage.points.count
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return getTextViewForTableCell(tableView, tableColumn) {
            columnIdentifier in

            let point = self.stage.points[row]
            switch columnIdentifier {
            case "PointNumberColumn":
                if row == 0 {
                    return "🚩"
                } else if row + 1 >= self.stage.points.count {
                    return "🏁"
                }
                return String(format: "%02d", row)
            case "PointNameColumn":
                return "\(point.name)"
            default:
                return nil
            }
        }
    }

    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return CGFloat(50.0)
    }

    func tableView(
            tableView: NSTableView,
            writeRowsWithIndexes rowIndexes: NSIndexSet,
            toPasteboard pboard: NSPasteboard
    ) -> Bool {
        guard pointTableView.selectedRow >= 0 else {
            return false
        }
        pboard.setString(String(pointTableView.selectedRow), forType: "point.index")
        return true
    }

    func tableView(
            tableView: NSTableView,
            validateDrop info: NSDraggingInfo,
            proposedRow row: Int,
            proposedDropOperation dropOperation: NSTableViewDropOperation
    ) -> NSDragOperation {
        return .Move
    }

    func tableView(
            tableView: NSTableView,
            acceptDrop info: NSDraggingInfo,
            row: Int,
            dropOperation: NSTableViewDropOperation
    ) -> Bool {
        let sourceIndex = Int(info.draggingPasteboard().stringForType("point.index")!)!
        if sourceIndex == row {
            return false
        }
        try! realm.write {
            if dropOperation == .On {
                stage.points.swap(sourceIndex, row)
            } else {
                stage.points.move(from: sourceIndex, to: row < sourceIndex ? row : row - 1)
            }
        }
        reloadPoints()
        return true
    }

    private func hideGeocodingResults() {
        self.geocodingResults = nil
        self.geocoderClearButton.hidden = true
    }

    private func showGeocodingResults() {
        self.geocodingResults = GeocodingResultTable(
            mapView: self,
            results: []
        )
        self.geocoderClearButton.hidden = false
    }

    private func reloadPoints() {
        pointTableView.reloadData()
    }

    private func getSelectedPoint() -> Point? {
        let pointIndex = pointTableView.selectedRow
        if pointIndex < 0 {
            return nil
        }
        return stage.points[pointIndex]
    }
}
