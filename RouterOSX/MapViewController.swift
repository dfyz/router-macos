import Cocoa
import MapKit

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
        self.innerTable.action = #selector(GeocodingResultTable.addPoint)
    }

    deinit {
        self.resultTable.removeFromSuperview()
    }

    func addPoint(sender: NSControl) {
        let placeIndex = self.innerTable.selectedRow
        if placeIndex >= 0 {
            if case .Ok(let place) = self.results[placeIndex] {
                mapView.addPoint(mapView.geocoderTextField.stringValue, lat: place.lat, lon: place.lon)
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

class MapViewController: NSViewController, NSTextFieldDelegate, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var geocoderTextField: NSTextField!
    @IBOutlet weak var geocoderClearButton: NSButton!

    var stage: Stage!
    var geocodingResults: GeocodingResultTable?
    var mapMonitor: AnyObject!

    override func viewDidLoad() {
        super.viewDidLoad()

        geocoderTextField.wantsLayer = true
        geocoderClearButton.wantsLayer = true
        geocoderTextField.delegate = self

        if let mapArea = stage?.mapArea {
            let center = CLLocationCoordinate2D(latitude: mapArea.centerLat, longitude: mapArea.centerLon)
            let span = MKCoordinateSpan(latitudeDelta: mapArea.height, longitudeDelta: mapArea.width)
            mapView.region = MKCoordinateRegion(center: center, span: span)
        }

        let osmTileTemplate = "http://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let osmOverlay = MKTileOverlay(URLTemplate: osmTileTemplate)
        osmOverlay.canReplaceMapContent = true
        mapView.addOverlay(osmOverlay)

        self.mapMonitor = NSEvent.addLocalMonitorForEventsMatchingMask(.RightMouseUpMask, handler: onMapRightClick)
        mapView.delegate = self

        hideGeocodingResults()
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

    func onMapRightClick(event: NSEvent) -> NSEvent? {
        if event.window == view.window {
            let locationInMapView = mapView.convertPoint(event.locationInWindow, fromView: nil)
            let clickedCoords = mapView.convertPoint(locationInMapView, toCoordinateFromView: mapView)
            let clickedPoint = MKMapPointForCoordinate(clickedCoords)
            if MKMapRectContainsPoint(mapView.visibleMapRect, clickedPoint) {
                addPoint("HERE BE DRAGONS", lat: clickedCoords.latitude, lon: clickedCoords.longitude)
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

    func addPoint(name: String, lat: Double, lon: Double) {
        let point = MKPointAnnotation()
        let coords = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        point.coordinate = coords
        point.title = name
        mapView.addAnnotation(point)
        mapView.setCenterCoordinate(coords, animated: true)
        hideGeocodingResults()
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
}
