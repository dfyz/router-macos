import Cocoa
import RealmSwift

class AddStageViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet weak var competitionNameTextField: NSTextField!
    @IBOutlet weak var osmFileTextField: NSTextField!
    @IBOutlet weak var conversionProgressBar: NSProgressIndicator!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var addButton: NSButton!

    let fileManager = NSFileManager.defaultManager()
    var parentController: MainViewController!
    var shouldContinueImport: Bool = false

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

    @IBAction func onCancelClick(sender: AnyObject) {
        shouldContinueImport = false
        dismiss()
    }

    @IBAction func onAddStageClick(sender: AnyObject) {
        if competitionNameTextField.stringValue.isEmpty || !isGoodOsmFile() {
            return
        }

        shouldContinueImport = true
        addButton.enabled = false

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.createStage(self.competitionNameTextField.stringValue, self.osmFileTextField.stringValue)
        }
    }

    private func createStage(competitionName: String, _ mapFileName: String) {
        var maybeBinMapFileName: String?
        let importer = MapImporter(sourceMapFileName: mapFileName) {
            progress -> Bool in
            dispatch_async(dispatch_get_main_queue()) {
                self.conversionProgressBar.doubleValue = progress
            }
            return self.shouldContinueImport
        }
        do {
            maybeBinMapFileName = try importer.doImport()
        } catch MapImportError.Error(let message) {
            dispatch_async(dispatch_get_main_queue()) {
                let alert = NSAlert()
                alert.addButtonWithTitle("OK")
                alert.messageText = message
                alert.runModal()
            }
        } catch {
        }

        if let binMapFileName = maybeBinMapFileName {
            let realm = try! Realm()
            try! realm.write {
                let stage = Stage()
                stage.competitionName = competitionName
                stage.stageNumber = 1
                stage.binMapFileName = binMapFileName

                let mapArea = MapArea()
                stage.mapArea = mapArea

                realm.add(stage)
            }
        }

        dispatch_async(dispatch_get_main_queue(), dismiss)
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

    private func dismiss() {
        self.dismissController(self)
        self.parentController.reloadData()
    }
}
