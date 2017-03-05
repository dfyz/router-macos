import AEXML
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
    var routeOverlays = [MKOverlay]()
    var routingResult: RoutingResult?

    func addPointToMap(_ name: String, lat: Double, lon: Double, permanent: Bool) {
        let point = PointAnnotation()
        let coords = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        point.coordinate = coords
        point.title = name
        point.permanent = permanent
        mapView.addAnnotation(point)

        if !permanent {
            mapView.selectAnnotation(point, animated: true)
            mapView.setCenter(coords, animated: true)
            hideGeocodingResults()
        } else {
            pointToAnnotation[HashablePoint(lat: lat, lon: lon)] = point
        }
    }

    func drawRoutingResult(_ routingResult: RoutingResult) {
        self.routingResult = routingResult
        try! realm.write {
            let newPoints = List<Point>()
            for segment in routingResult.segments {
                newPoints.append(stage.points[segment.startPointIndex])
            }
            stage.points.removeAll()
            stage.points.append(objectsIn: newPoints)
        }

        reloadPoints()

        addPathOverlays(routingResult.segments)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        realm = try! Realm()

        geocoderTextField.wantsLayer = true
        geocoderTextField.delegate = self
        geocoderTextField.becomeFirstResponder()

        geocoderClearButton.wantsLayer = true

        let osmTileTemplate = "http://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let osmOverlay = MKTileOverlay(urlTemplate: osmTileTemplate)
        osmOverlay.canReplaceMapContent = true
        mapView.add(osmOverlay)

        self.mapMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp, handler: onMapRightClick) as AnyObject!
        mapView.delegate = self

        pointTableView.dataSource = self
        pointTableView.delegate = self
        pointTableView.register(forDraggedTypes: ["point.index"])

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

        if let screenFrame = NSScreen.main()?.visibleFrame {
            view.window?.setFrame(screenFrame, display: true)
        }

        onGetOverview(self)
    }

    override func viewWillDisappear() {
        NSEvent.removeMonitor(mapMonitor)
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let dest = segue.destinationController as? RoutingProgressViewController {
            dest.parentController = self
        }
    }

    @IBAction func onGeocodingRequest(_ sender: AnyObject) {
        hideGeocodingResults()

        let place = "\(geocoderTextField.stringValue) \(stage?.competitionName ?? String())"
        DispatchQueue.global().async {
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

    @IBAction func onGeocoderClear(_ sender: AnyObject) {
        hideGeocodingResults()
    }

    @IBAction func onPointSelected(_ sender: AnyObject) {
        guard let point = getSelectedPoint() else {
            return
        }

        if let annotation = pointToAnnotation[HashablePoint(lat: point.lat, lon: point.lon)] {
            mapView.selectAnnotation(annotation, animated: true)
            let coords = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
            mapView.setCenter(coords, animated: true)
        }
    }

    @IBAction func onPointNameEdited(_ sender: NSTextField) {
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

    func onDeleteItem(_ sender: AnyObject) {
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

    func onGetOverview(_ sender: AnyObject) {
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

    func onRoute(_ sender: AnyObject) {
        performSegue(withIdentifier: "ShowRoutingProgressSegue", sender: self)
    }

    func onExportToGpx(_ sender: AnyObject) {
        guard let rr = routingResult else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = false
        savePanel.allowedFileTypes = ["gpx"]
        savePanel.begin {
            (result) -> Void in
            if result != NSFileHandlingPanelOKButton {
                return
            }
            if let filePath = savePanel.url?.path {
                self.saveRouteToGpx(rr: rr, filePath: filePath)
            }
        }
    }

    func onMapRightClick(_ event: NSEvent) -> NSEvent? {
        if event.window == view.window {
            let locationInMapView = mapView.convert(event.locationInWindow, from: nil)
            let clickedCoords = mapView.convert(locationInMapView, toCoordinateFrom: mapView)
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

    fileprivate func addPointToRealm(_ point: PointAnnotation) {
        let permanentPoint = Point()
        try! realm.write {
            permanentPoint.name = point.title!
            permanentPoint.lat = point.coordinate.latitude
            permanentPoint.lon = point.coordinate.longitude
            if stage.points.count >= 2 {
                // We have both start and finish, add new points in between.
                stage.points.insert(permanentPoint, at: stage.points.count - 1)
            } else {
                stage.points.append(permanentPoint)
            }
        }
        pointToAnnotation[HashablePoint(lat: permanentPoint.lat, lon: permanentPoint.lon)] = point

        reloadPoints()
        self.routingResult = nil
    }

    fileprivate func hideGeocodingResults() {
        self.geocodingResults = nil
        self.geocoderClearButton.isHidden = true
    }

    fileprivate func showGeocodingResults() {
        self.geocodingResults = GeocodingResultTable(
            mapView: self,
            results: []
        )
        self.geocoderClearButton.isHidden = false
    }

    fileprivate func reloadPoints() {
        pointTableView.reloadData()
        for (idx, p) in stage.points.enumerated() {
            let hp = HashablePoint(lat: p.lat, lon: p.lon)
            if let annotation = pointToAnnotation[hp] {
                mapView.removeAnnotation(annotation)
                annotation.baloonTitle = getRowTextByIndex(idx)
                mapView.addAnnotation(annotation)
            }
        }
    }

    fileprivate func getSelectedPoint() -> Point? {
        let pointIndex = pointTableView.selectedRow
        if pointIndex < 0 {
            return nil
        }
        return stage.points[pointIndex]
    }

    fileprivate func getRowTextByIndex(_ index: Int) -> String {
        if index == 0 {
            return "🚩"
        } else if index + 1 >= self.stage.points.count {
            return "🏁"
        }
        return String(format: "%02d", index)
    }

    fileprivate func addPathOverlays(_ segments: [RouteSegment]) {
        for prevPath in routeOverlays {
            mapView.remove(prevPath)
        }
        routeOverlays.removeAll()

        for seg in segments {
            var path = seg.path
            let routeOverlay = MKPolyline(coordinates: &path, count: path.count)
            routeOverlays.append(routeOverlay)
            mapView.add(routeOverlay, level: .aboveLabels)
        }
    }

    fileprivate func saveRouteToGpx(rr: RoutingResult, filePath: String) {
        let doc = AEXMLDocument()
        let gpx = doc.addChild(name: "gpx", attributes: [
            "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
            "xmlns": "http://www.topografix.com/GPX/1/0",
            "xsi:schemaLocation": "http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd",
            "version": "1.0",
        ])
        for (i, seg) in rr.segments.enumerated() {
            if i + 1 >= rr.segments.count {
                break
            }
            let from = stage.points[seg.startPointIndex].name
            let to = stage.points[rr.segments[i + 1].startPointIndex].name
            let rte = gpx.addChild(name: "rte")
            rte.addChild(name: "name", value: "\(from) -> \(to)")
            for point in seg.path {
                rte.addChild(name: "rtept", attributes: [
                    "lat": "\(point.latitude)",
                    "lon": "\(point.longitude)",
                ])
            }
        }
        do {
            try doc.xml.write(toFile: filePath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "Failed to write GPX data to \(filePath)"
            alert.runModal()
        }
    }

    @objc fileprivate func makePointPermanent(_ sender: NSButton?) {
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
    func numberOfRows(in tableView: NSTableView) -> Int {
        realm.refresh()
        return stage.points.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return getTextViewForTableCell(tableView, tableColumn) {
            columnIdentifier in

            let point = self.stage.points[row]
            switch columnIdentifier {
            case "PointNumberColumn":
                return self.getRowTextByIndex(row)
            case "PointNameColumn":
                return "\(point.name)"
            case "DistanceColumn":
                if let rr = routingResult, row < rr.segments.count {
                    return toHumanReadableDistance(rr.segments[row].distance)
                } else {
                    return "??? m"
                }
            default:
                return nil
            }
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return CGFloat(50.0)
    }

    func tableView(
            _ tableView: NSTableView,
            writeRowsWith rowIndexes: IndexSet,
            to pboard: NSPasteboard
    ) -> Bool {
        guard pointTableView.selectedRow >= 0 else {
            return false
        }
        pboard.setString(String(pointTableView.selectedRow), forType: "point.index")
        return true
    }

    func tableView(
            _ tableView: NSTableView,
            validateDrop info: NSDraggingInfo,
            proposedRow row: Int,
            proposedDropOperation dropOperation: NSTableViewDropOperation
    ) -> NSDragOperation {
        return .move
    }

    func tableView(
            _ tableView: NSTableView,
            acceptDrop info: NSDraggingInfo,
            row: Int,
            dropOperation: NSTableViewDropOperation
    ) -> Bool {
        let sourceIndex = Int(info.draggingPasteboard().string(forType: "point.index")!)!
        if sourceIndex == row {
            return false
        }
        try! realm.write {
            if dropOperation == .on {
                stage.points.swap(index1: sourceIndex, row)
            } else {
                stage.points.move(from: sourceIndex, to: row < sourceIndex ? row : row - 1)
            }
        }
        reloadPoints()
        return true
    }
}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let osmOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: osmOverlay)

        }
        if let polylineOverlay = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polylineOverlay)
            renderer.strokeColor = NSColor.red
            renderer.lineWidth = 3
            return renderer
        }
        return MKOverlayRenderer()
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
            button.bezelStyle = .smallSquare
            button.image = NSImage(named: NSImageNameAddTemplate)
            button.target = self
            button.action = #selector(makePointPermanent)
            result.rightCalloutAccessoryView = button
        }

        return result
    }

    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
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
            _ control: NSControl,
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
    override func draw(_ rect: NSRect) {
        NSColor.white.setFill()
        NSColor.red.setStroke()
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
        oval.appendOval(in: ovalRect)
        let ovalWidth = CGFloat(5)
        oval.lineWidth = ovalWidth
        oval.stroke()
        oval.fill()

        let lineFrom = CGPoint(x: frame.width / 2.0, y: ovalRect.height + ovalWidth)
        let lineTo = CGPoint(x: lineFrom.x, y: frame.height)
        NSBezierPath.setDefaultLineWidth(2.0)
        NSBezierPath.strokeLine(from: lineFrom, to: lineTo)

        if let point = annotation as? PointAnnotation {
            let attrs = [NSFontAttributeName: NSFont.boldSystemFont(ofSize: 24.0)]
            let str = NSString(string: point.baloonTitle)
            let strSize = str.size(withAttributes: attrs)

            let getPadding = {
                (ovalDim, strDim) in
                max(CGFloat(0.0), (ovalDim - strDim) / CGFloat(2.0))
            }
            let widthPadding = getPadding(ovalRect.width, strSize.width)
            let heightPadding = getPadding(ovalRect.height, strSize.height)
            let strRect = padRect(ovalRect, widthPadding: widthPadding, heightPadding: heightPadding)
            str.draw(in: strRect, withAttributes: attrs)
        }
    }

    fileprivate func padRect(_ rect: NSRect, widthPadding: CGFloat, heightPadding: CGFloat) -> NSRect {
        return NSRect(
            x: rect.origin.x + widthPadding,
            y: rect.origin.y + heightPadding,
            width: rect.width - 2*widthPadding,
            height: rect.height - 2*heightPadding
        )
    }
}

fileprivate func toHumanReadableDistance(_ distance: Double) -> String {
    var rounded = floor(distance)
    var suffix = "m"
    var spec = "%.0f"
    let mInKm = 1000.0
    if rounded >= mInKm {
        rounded /= mInKm
        suffix = "km"
        spec = "%.1f"
    }
    return String(format: spec + " %@", rounded, suffix)
}