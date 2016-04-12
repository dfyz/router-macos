import Cocoa
import RealmSwift

class AddStageViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet weak var competitionNameTextField: NSTextField!
    @IBOutlet weak var osmFileTextField: NSTextField!

    let fileManager = NSFileManager.defaultManager()

    override func controlTextDidChange(obj: NSNotification) {
        osmFileTextField.textColor = isGoodOsmFile() ? NSColor.blackColor() : NSColor.redColor()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        competitionNameTextField.becomeFirstResponder()
        osmFileTextField.delegate = self
    }

    @IBAction func onSelectOsmFileClick(sender: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["osm"]
        openPanel.beginWithCompletionHandler {
            (result) -> Void in
            if result != NSFileHandlingPanelOKButton {
                return
            }
            if let filePath = openPanel.URL?.path {
                self.osmFileTextField.stringValue = filePath
            }
        }
    }

    @IBAction func onAddStageClick(sender: AnyObject) {
        if competitionNameTextField.stringValue.isEmpty || !isGoodOsmFile() {
            return
        }

        let realm = try! Realm()
        try! realm.write {
            let stage = Stage()
            stage.competitionName = competitionNameTextField.stringValue
            stage.stageNumber = 1
            stage.binMapFileName = osmFileTextField.stringValue

            let mapArea = MapArea()
            stage.mapArea = mapArea

            realm.add(stage)
        }

        dismissController(self)
    }

    private func isGoodOsmFile() -> Bool {
        let filePath = osmFileTextField.stringValue
        var isDirectory = ObjCBool(false)
        let osmFileExists = fileManager.fileExistsAtPath(filePath, isDirectory: &isDirectory)
        if !osmFileExists || isDirectory {
            return false
        }
        return filePath.hasSuffix(".osm")
    }
}
