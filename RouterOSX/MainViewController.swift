import Cocoa
import RealmSwift

class MainViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var mainTableView: NSTableView!

    var realm: Realm!
    var allStages: Results<Stage>!

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
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
            text = "\(center.width) × \(center.height) (center is \(center.centerLat), \(center.centerLon))"
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
        allStages = realm.objects(Stage)

        mainTableView.setDataSource(self)
        mainTableView.setDelegate(self)
    }
}

