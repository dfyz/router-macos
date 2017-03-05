import Cocoa
import RealmSwift

class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var mainTableView: NSTableView!

    var realm: Realm!
    var allStages: Results<Stage>!

    func numberOfRows(in tableView: NSTableView) -> Int {
        realm.refresh()
        return allStages.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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
        allStages = realm.objects(Stage.self).sorted(byKeyPath: "competitionName")

        mainTableView.dataSource = self
        mainTableView.delegate = self
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
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

    @IBAction func onStageNameEdited(_ sender: NSTextField) {
        guard let stage = getSelectedStage() else {
            return
        }

        try! realm.write {
            stage.competitionName = sender.stringValue
        }
        reloadData()
    }

    @IBAction func onCopyExistingStageClick(_ sender: AnyObject) {
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

    @IBAction func onDeleteItem(_ sender: AnyObject) {
        guard let stage = getSelectedStage() else {
            return
        }

        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.messageText = "Delete \(stage.competitionName)?"

        alert.beginSheetModal(for: view.window!, completionHandler: {
            (response) -> Void in
            if response == NSAlertFirstButtonReturn {
                try! self.realm.write {
                    self.realm.delete(stage)
                }
                self.reloadData()
            }
        }) 
    }

    @IBAction func onStageDoubleClick(_ sender: AnyObject) {
        if getSelectedStage() == nil {
            return
        }
        performSegue(withIdentifier: "ShowMapSegue", sender: self)
    }

    fileprivate func getSelectedStage() -> Stage? {
        let stageIndex = mainTableView.selectedRow
        if stageIndex < 0 {
            return nil
        }
        return allStages[stageIndex]
    }
}

