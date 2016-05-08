import Cocoa
import MapKit

struct GeocodingResult {
    let name: String
    let lat: Float64
    let lon: Float64
}

class GeocodingResultTable: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let resultTable: NSScrollView
    let results: [GeocodingResult]

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

        super.init()

        let innerTable = NSTableView(frame: tableFrame)

        for col in [
            NSTableColumn(identifier: "ImageColumn"),
            NSTableColumn(identifier: "NameColumn"),
        ] {
            innerTable.addTableColumn(col)
        }

        innerTable.headerView = nil
        innerTable.setDataSource(self)
        innerTable.setDelegate(self)
        innerTable.reloadData()

        resultTable.documentView = innerTable
        resultTable.hasVerticalScroller = true

        parent.window?.contentView?.addSubview(resultTable)

        resultTable.autoresizesSubviews = true
        resultTable.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
        resultTable.topAnchor.constraintEqualToAnchor(displayBelow.bottomAnchor).active = true
        resultTable.rightAnchor.constraintEqualToAnchor(displayBelow.rightAnchor).active = true
    }

    deinit {
        resultTable.removeFromSuperview()
    }

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return results.count
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return nil
    }
}

class MapViewController: NSViewController {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var geocoderTextField: NSTextField!

    var stage: Stage!
    var geocodingResults: GeocodingResultTable?

    override func viewDidLoad() {
        super.viewDidLoad()

        geocoderTextField.wantsLayer = true

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
    }

    @IBAction func onGeocodingRequest(sender: AnyObject) {
        let results = [
            GeocodingResult(name: "Abc", lat: 0.0, lon: 0.0),
            GeocodingResult(name: "Def", lat: 0.0, lon: 0.0),
            GeocodingResult(name: "Ololo", lat: 0.0, lon: 0.0),
        ]
        geocodingResults = GeocodingResultTable(parent: view, displayBelow: geocoderTextField, results: results)
    }
}
