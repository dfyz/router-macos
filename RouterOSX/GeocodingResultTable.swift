import Foundation
import Cocoa

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
