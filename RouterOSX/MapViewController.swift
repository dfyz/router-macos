import Cocoa
import MapKit

class VerticallyCenteredTextField: NSTextField {
    override func viewWillDraw() {
        self.topAnchor.constraintEqualToAnchor(superview!.topAnchor, constant: 50.0).active = true
    }
}

class GeocodingResultTable: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let resultTable: NSScrollView
    var results: [GeocodingResult]
    private let innerTable: NSTableView

    init(parent: NSView, displayBelow: NSView, results: [GeocodingResult]) {
        self.results = results
        let resultHeight = CGFloat(300.0)
        let tableFrame = NSMakeRect(
            displayBelow.frame.minX,
            displayBelow.frame.minY - resultHeight,
            displayBelow.frame.width,
            resultHeight
        )
        self.resultTable = NSScrollView(frame: tableFrame)
        self.innerTable = NSTableView(frame: tableFrame)
        super.init()

        addColumns(innerTable)

        innerTable.headerView = nil
        innerTable.setDataSource(self)
        innerTable.setDelegate(self)
        innerTable.reloadData()

        resultTable.documentView = innerTable
        resultTable.hasVerticalScroller = true
        resultTable.hasHorizontalScroller = true

        parent.window?.contentView?.addSubview(resultTable)

        resultTable.autoresizesSubviews = true
        resultTable.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
        resultTable.topAnchor.constraintEqualToAnchor(displayBelow.bottomAnchor).active = true
        resultTable.rightAnchor.constraintEqualToAnchor(displayBelow.rightAnchor).active = true

        innerTable.sizeLastColumnToFit()

        innerTable.nextKeyView = displayBelow
        displayBelow.nextKeyView = innerTable
    }

    deinit {
        resultTable.removeFromSuperview()
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
            let textCell = VerticallyCenteredTextField()
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

class MapViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var geocoderTextField: NSTextField!

    var stage: Stage!
    var geocodingResults: GeocodingResultTable?

    override func viewDidLoad() {
        super.viewDidLoad()

        geocoderTextField.wantsLayer = true
        geocoderTextField.delegate = self

        if let mapArea = stage?.mapArea {
            let center = CLLocationCoordinate2D(latitude: mapArea.centerLat, longitude: mapArea.centerLon)
            let span = MKCoordinateSpan(latitudeDelta: mapArea.height, longitudeDelta: mapArea.width)
            mapView.region = MKCoordinateRegion(center: center, span: span)
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

    @IBAction func onGeocodingRequest(sender: AnyObject) {
        self.geocodingResults = nil

        let place = "\(geocoderTextField.stringValue) \(stage?.competitionName ?? String())"
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let geocoder = Geocoder(place: place) {
                results in

                if self.geocodingResults == nil {
                    self.geocodingResults = GeocodingResultTable(
                        parent: self.view,
                        displayBelow: self.geocoderTextField,
                        results: []
                    )
                }
                self.geocodingResults!.addResults(results)
            }

            geocoder.geocode()
        }
    }

    func control(
        control: NSControl,
        textView: NSTextView,
        completions words: [String],
        forPartialWordRange charRange: NSRange,
        indexOfSelectedItem index: UnsafeMutablePointer<Int>
    ) -> [String]
    {
        self.geocodingResults = nil
        return []
    }
}
