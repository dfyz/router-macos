import Cocoa
import MapKit
import RealmSwift

class PointAnnotation: MKPointAnnotation {
    var permanent = false
    var baloonTitle = ""
}

class MapViewController: NSViewController {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var geocoderTextField: NSTextField!
    @IBOutlet weak var geocoderClearButton: NSButton!
    @IBOutlet weak var pointTableView: NSTableView!

    var realm: Realm!
    var stage: Stage!
    var geocodingResults: GeocodingResultTable?
    var mapMonitor: AnyObject!
    var pointToAnnotation = [HashablePoint: PointAnnotation]()
    var routeOverlay: MKOverlay?

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

    func drawRoutingResult(routingResult: RoutingResult) {
        try! realm.write {
            let newPoints = List<Point>()
            for idx in routingResult.pointIndexes {
                newPoints.append(stage.points[idx])
            }
            stage.points.removeAll()
            stage.points.appendContentsOf(newPoints)
        }

        reloadPoints()

        addPathOverlay(routingResult.path)
    }

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

        self.mapMonitor = NSEvent.addLocalMonitorForEventsMatchingMask(.RightMouseUp, handler: onMapRightClick)
        mapView.delegate = self

        pointTableView.dataSource = self
        pointTableView.delegate = self
        pointTableView.registerForDraggedTypes(["point.index"])

        hideGeocodingResults()

        for point in stage.points {
            addPointToMap(point.name, lat: point.lat, lon: point.lon, permanent: true)
        }

        reloadPoints()
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

    override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
        if let dest = segue.destinationController as? RoutingProgressViewController {
            dest.parentController = self
        }
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

    func onDeleteItem(sender: AnyObject) {
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
        performSegueWithIdentifier("ShowRoutingProgressSegue", sender: self)
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

    private func addPointToRealm(point: PointAnnotation) {
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
        for (idx, p) in stage.points.enumerate() {
            let hp = HashablePoint(lat: p.lat, lon: p.lon)
            if let annotation = pointToAnnotation[hp] {
                mapView.removeAnnotation(annotation)
                annotation.baloonTitle = getRowTextByIndex(idx)
                mapView.addAnnotation(annotation)
            }
        }
    }

    private func getSelectedPoint() -> Point? {
        let pointIndex = pointTableView.selectedRow
        if pointIndex < 0 {
            return nil
        }
        return stage.points[pointIndex]
    }

    private func getRowTextByIndex(index: Int) -> String {
        if index == 0 {
            return "🚩"
        } else if index + 1 >= self.stage.points.count {
            return "🏁"
        }
        return String(format: "%02d", index)
    }

    private func addPathOverlay(path: [CLLocationCoordinate2D]) {
        if let prevPath = routeOverlay {
            mapView.removeOverlay(prevPath)
            routeOverlay = nil
        }

        var path = path
        routeOverlay = MKPolyline(coordinates: &path, count: path.count)
        mapView.addOverlay(routeOverlay!, level: .AboveLabels)
    }


    @objc private func makePointPermanent(sender: NSButton?) {
        guard let btn = sender else {
            return
        }

        var currentView = btn.superview
        while currentView != nil {
            if let annotationView = currentView as? BubbleAnnotationView {
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
}

extension MapViewController: NSTableViewDataSource, NSTableViewDelegate {
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
                return self.getRowTextByIndex(row)
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
}

extension MapViewController: MKMapViewDelegate {
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        if let osmOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: osmOverlay)

        }
        if let polylineOverlay = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polylineOverlay)
            renderer.strokeColor = NSColor.redColor()
            renderer.lineWidth = 3
            return renderer
        }
        return MKOverlayRenderer()
    }

    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        guard let point = annotation as? PointAnnotation else {
            return nil
        }

        let result = BubbleAnnotationView(annotation: point, reuseIdentifier: nil)
        result.canShowCallout = true

        let height = CGFloat(60.0)
        let width = CGFloat(50.0)
        result.setFrameSize(NSSize(width: width, height: height))
        result.centerOffset = CGPoint(x: 0.0, y: -height / 2.0)

        if !point.permanent {
            let button = NSButton()
            button.bezelStyle = .SmallSquare
            button.image = NSImage(named: NSImageNameAddTemplate)
            button.target = self
            button.action = #selector(makePointPermanent)
            result.rightCalloutAccessoryView = button
        }

        return result
    }

    func mapView(mapView: MKMapView, didDeselectAnnotationView view: MKAnnotationView) {
        guard
            let annotationView = view as? BubbleAnnotationView,
            let point = annotationView.annotation as? PointAnnotation
        else {
            return
        }

        if !point.permanent {
            mapView.removeAnnotation(point)
        }
    }
}

extension MapViewController: NSTextFieldDelegate {
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
}

private class BubbleAnnotationView: MKAnnotationView {
    override func drawRect(rect: NSRect) {
        NSColor.whiteColor().setFill()
        NSColor.redColor().setStroke()
        let oval = NSBezierPath()
        let ovalRect = padRect(
            NSRect(
                x: 0.0,
                y: 0.0,
                width: Double(frame.width),
                height: 0.6*Double(frame.height)
            ),
            widthPadding: 3.0,
            heightPadding: 3.0
        )
        oval.appendBezierPathWithOvalInRect(ovalRect)
        let ovalWidth = CGFloat(5)
        oval.lineWidth = ovalWidth
        oval.stroke()
        oval.fill()

        let lineFrom = CGPoint(x: frame.width / 2.0, y: ovalRect.height + ovalWidth)
        let lineTo = CGPoint(x: lineFrom.x, y: frame.height)
        NSBezierPath.setDefaultLineWidth(2.0)
        NSBezierPath.strokeLineFromPoint(lineFrom, toPoint: lineTo)

        if let point = annotation as? PointAnnotation {
            let attrs = [NSFontAttributeName: NSFont.boldSystemFontOfSize(24.0)]
            let str = NSString(string: point.baloonTitle)
            let strSize = str.sizeWithAttributes(attrs)

            let getPadding = {
                (ovalDim, strDim) in
                max(CGFloat(0.0), (ovalDim - strDim) / CGFloat(2.0))
            }
            let widthPadding = getPadding(ovalRect.width, strSize.width)
            let heightPadding = getPadding(ovalRect.height, strSize.height)
            let strRect = padRect(ovalRect, widthPadding: widthPadding, heightPadding: heightPadding)
            str.drawInRect(strRect, withAttributes: attrs)
        }
    }

    private func padRect(rect: NSRect, widthPadding: CGFloat, heightPadding: CGFloat) -> NSRect {
        return NSRect(
            x: rect.origin.x + widthPadding,
            y: rect.origin.y + heightPadding,
            width: rect.width - 2*widthPadding,
            height: rect.height - 2*heightPadding
        )
    }
}
