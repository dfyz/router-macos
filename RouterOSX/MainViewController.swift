import Cocoa
import RealmSwift

class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var mainTableView: NSTableView!

    var realm: Realm!
    var allStages: Results<Stage>!

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        realm.refresh()
        return allStages.count
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return getTextViewForTableCell(tableView, tableColumn) {
            columnIdentifier in

            let stage = self.allStages[row]
            switch columnIdentifier {
            case "CompetitionNameColumn":
                return stage.competitionName
            case "StageNumberColumn":
                return "\(stage.stageNumber)"
            case "MapAreaColumn":
                let center = stage.mapArea!
                let roundedCenterLat = String(format: "%.6f", center.centerLat)
                let roundedCenterLon = String(format: "%.6f", center.centerLon)
                return "(\(roundedCenterLat), \(roundedCenterLon))"
            default:
                return nil
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Realm.Configuration.defaultConfiguration = Realm.Configuration(schemaVersion: 2)

        realm = try! Realm()
        allStages = realm.objects(Stage).sorted("competitionName")

        mainTableView.setDataSource(self)
        mainTableView.setDelegate(self)
    }

    override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
        if let dest = segue.destinationController as? AddStageViewController {
            dest.parentController = self
        }
        if let dest = segue.destinationController as? MapViewController {
            if let stage = getSelectedStage() {
                dest.stage = stage
            }
        }
    }

    func reloadData() {
        mainTableView.reloadData()
    }

    @IBAction func onStageNameEdited(sender: NSTextField) {
        guard let stage = getSelectedStage() else {
            return
        }

        try! realm.write {
            stage.competitionName = sender.stringValue
        }
        reloadData()
    }

    @IBAction func onCopyExistingStageClick(sender: AnyObject) {
        guard let original = getSelectedStage() else {
            return
        }

        try! realm.write {
            let copy = Stage()
            copy.competitionName = original.competitionName
            copy.stageNumber = original.stageNumber + 1
            copy.binMapFileName = original.binMapFileName
            copy.mapArea = original.mapArea
            realm.add(copy)
        }
        reloadData()
    }

    @IBAction func onDeleteItem(sender: AnyObject) {
        guard let stage = getSelectedStage() else {
            return
        }

        let alert = NSAlert()
        alert.addButtonWithTitle("OK")
        alert.addButtonWithTitle("Cancel")
        alert.messageText = "Delete \(stage.competitionName)?"

        alert.beginSheetModalForWindow(view.window!) {
            (response) -> Void in
            if response == NSAlertFirstButtonReturn {
                try! self.realm.write {
                    self.realm.delete(stage)
                }
                self.reloadData()
            }
        }
    }

    @IBAction func onStageDoubleClick(sender: AnyObject) {
        if getSelectedStage() == nil {
            return
        }
        performSegueWithIdentifier("ShowMapSegue", sender: self)
    }

    private func getSelectedStage() -> Stage? {
        let stageIndex = mainTableView.selectedRow
        if stageIndex < 0 {
            return nil
        }
        return allStages[stageIndex]
    }
}

