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
        guard let columnIdentifier = tableColumn?.identifier else {
            return nil
        }

        let stage = allStages[row]

        var text = ""
        switch columnIdentifier {
        case "CompetitionNameColumn":
            text = stage.competitionName
        case "StageNumberColumn":
            text = "\(stage.stageNumber)"
        case "MapAreaColumn":
            let center = stage.mapArea!
            let roundedCenterLat = String(format: "%.6f", center.centerLat)
            let roundedCenterLon = String(format: "%.6f", center.centerLon)
            text = "(\(roundedCenterLat), \(roundedCenterLon))"
        default:
            print("Unknown column \(columnIdentifier)")
            return nil
        }

        let cellIdentifier = columnIdentifier.stringByReplacingOccurrencesOfString("Column", withString: "Cell")
        guard let cell = tableView.makeViewWithIdentifier(cellIdentifier, owner: nil) as? NSTableCellView else {
            return nil
        }

        cell.textField?.stringValue = text
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        realm = try! Realm()
        allStages = realm.objects(Stage).sorted("competitionName")

        mainTableView.setDataSource(self)
        mainTableView.setDelegate(self)
    }

    override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
        if let dest = segue.destinationController as? AddStageViewController {
            dest.parentController = self
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

    @IBAction func onDeleteStageClick(sender: AnyObject) {
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
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(stage.binMapFileName)
                } catch {
                }
                try! self.realm.write {
                    self.realm.delete(stage)
                }
                self.reloadData()
            }
        }
    }

    private func getSelectedStage() -> Stage? {
        let stageIndex = mainTableView.selectedRow
        if stageIndex < 0 {
            return nil
        }
        return allStages[stageIndex]
    }
}

