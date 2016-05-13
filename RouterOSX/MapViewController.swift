import Cocoa
import MapKit
import RealmSwift

class NSTableViewWithActionOnEnter: NSTableView {
    override func keyDown(event: NSEvent) {
        if event.keyCode == 0x24 {
            self.sendAction(self.action, to: self.target)
        } else {
            super.keyDown(event)
        }
    }
}

class GeocodingResultTable: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    weak var mapView: MapViewController!
    let resultTable: NSScrollView

    private var results: [GeocodingResult]
    private let innerTable: NSTableView

    init(mapView: MapViewController, results: [GeocodingResult]) {
        self.mapView = mapView
        self.results = results

        let displayBelow = mapView.geocoderTextField

        let resultHeight = CGFloat(300.0)
        let tableFrame = NSMakeRect(
            displayBelow.frame.minX,
            displayBelow.frame.minY - resultHeight,
            displayBelow.frame.width,
            resultHeight
        )
        self.resultTable = NSScrollView(frame: tableFrame)
        self.innerTable = NSTableViewWithActionOnEnter(frame: tableFrame)
        super.init()

        addColumns(innerTable)

        self.innerTable.headerView = nil
        self.innerTable.setDataSource(self)
        self.innerTable.setDelegate(self)
        self.innerTable.reloadData()

        self.resultTable.documentView = self.innerTable
        self.resultTable.hasVerticalScroller = true
        self.resultTable.hasHorizontalScroller = true

        mapView.view.window?.contentView?.addSubview(self.resultTable)

        self.resultTable.autoresizesSubviews = true
        self.resultTable.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
        self.resultTable.topAnchor.constraintEqualToAnchor(displayBelow.bottomAnchor).active = true
        self.resultTable.rightAnchor.constraintEqualToAnchor(displayBelow.rightAnchor).active = true

        self.innerTable.sizeLastColumnToFit()

        self.innerTable.nextKeyView = displayBelow
        displayBelow.nextKeyView = self.innerTable

        self.innerTable.target = self
        self.innerTable.action = #selector(GeocodingResultTable.addPointToMap)
    }

    deinit {
        self.resultTable.removeFromSuperview()
    }

    func addPointToMap(sender: NSControl) {
        let placeIndex = self.innerTable.selectedRow
        if placeIndex >= 0 {
            if case .Ok(let place) = self.results[placeIndex] {
                mapView.addPointToMap(
                    mapView.geocoderTextField.stringValue,
                    lat: place.lat,
                    lon: place.lon,
                    permanent: false
                )
            }
        }
    }

    func addResults(results: [GeocodingResult]) {
        var resultsByProvider = [String: [GeocodingResult]]()
        for result in self.results + results {
            var key = ""
            switch result {
            case .Ok(let place):
                key = place.provider
            case .Error(let failure):
                key = failure.provider
            }
            var currentResults = resultsByProvider[key] ?? []
            currentResults.append(result)
            resultsByProvider[key] = currentResults
        }

        var newResults = [GeocodingResult]()
        let keys = Array(resultsByProvider.keys)
        var added = true
        while added {
            added = false
            for key in keys {
                if var currentResults = resultsByProvider[key] where !currentResults.isEmpty {
                    newResults.append(currentResults.first!)
                    currentResults.removeAtIndex(0)
                    resultsByProvider[key] = currentResults
                    added = true
                }
            }
        }
        self.results = newResults
        self.innerTable.reloadData()
        self.resultTable.becomeFirstResponder()
    }

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return results.count
    }

    struct TableRowParams {
        let image: NSImage?
        let text: String
        let color: NSColor
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier else {
            return nil
        }

        let result = getTableRowParams(results[row])
        switch columnIdentifier {
        case "ImageColumn":
            let imageCell = NSImageView()
            imageCell.image = result.image
            return imageCell
        case "NameColumn":
            let textCell = NSTextField()
            textCell.drawsBackground = false
            textCell.bezeled = false
            textCell.editable = false
            textCell.selectable = false
            textCell.stringValue = result.text
            textCell.textColor = result.color
            textCell.font = NSFont.controlContentFontOfSize(24.0)
            return textCell
        default:
            fatalError("Unknown column " + columnIdentifier)
        }
    }

    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return CGFloat(30.0)
    }

    private func getTableRowParams(result: GeocodingResult) -> TableRowParams {
        var provider = ""
        var text = ""
        var color = NSColor.blackColor()

        switch result {
        case .Error(let failure):
            provider = failure.provider
            text = "Error: \(failure.error)"
            color = NSColor.redColor()
        case .Ok(let place):
            provider = place.provider
            text = place.name
        }

        let image = NSImage(named: "\(provider).ico")
        return TableRowParams(image: image, text: text, color: color)
    }

    private func addColumns(table: NSTableView) {
        let imageColumn = NSTableColumn(identifier: "ImageColumn")
        imageColumn.width = 30
        table.addTableColumn(imageColumn)

        let nameColumn = NSTableColumn(identifier: "NameColumn")
        table.addTableColumn(nameColumn)
    }
}

class PointAnnotation: MKPointAnnotation {
    var permanent = false
}

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

class MapViewController: NSViewController, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var geocoderTextField: NSTextField!
    @IBOutlet weak var geocoderClearButton: NSButton!
    @IBOutlet weak var pointTableView: NSTableView!
    @IBOutlet weak var routeButton: NSButton!

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
        routeButton.wantsLayer = true

        let mapArea = stage.mapArea!
        let center = CLLocationCoordinate2D(latitude: mapArea.centerLat, longitude: mapArea.centerLon)
        let span = MKCoordinateSpan(latitudeDelta: mapArea.height, longitudeDelta: mapArea.width)
        mapView.region = MKCoordinateRegion(center: center, span: span)

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
        guard let annotationView = view as? MKPinAnnotationView else {
            return
        }

        guard let point = annotationView.annotation as? PointAnnotation else {
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
            permanentPoint.number = getNextPointNumber()
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

    private func getNextPointNumber() -> Int {
        if stage.points.isEmpty {
            return 1
        }
        return stage.points.last!.number + 1
    }

    private func getSelectedPoint() -> Point? {
        let pointIndex = pointTableView.selectedRow
        if pointIndex < 0 {
            return nil
        }
        return stage.points[pointIndex]
    }
}
