import Cocoa
import RealmSwift

class AddStageViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet weak var competitionNameTextField: NSTextField!
    @IBOutlet weak var osmFileTextField: NSTextField!
    @IBOutlet weak var osmSelectButton: NSButton!
    @IBOutlet weak var conversionProgressBar: NSProgressIndicator!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var progressStackView: NSStackView!

    let fileManager = FileManager.default
    var parentController: MainViewController!
    var importInProgress: Bool = false

    override func controlTextDidChange(_ obj: Notification) {
        osmFileTextField.textColor = isGoodOsmFile() ? NSColor.black : NSColor.red
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        competitionNameTextField.becomeFirstResponder()
        osmFileTextField.delegate = self
    }

    @IBAction func onSelectOsmFileClick(_ sender: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["osm"]
        openPanel.begin {
            (result) -> Void in
            if result.rawValue != NSFileHandlingPanelOKButton {
                return
            }
            if let filePath = openPanel.url?.path {
                self.osmFileTextField.stringValue = filePath
            }
        }
    }

    @IBAction func onCancelClick(_ sender: AnyObject) {
        let canDismiss = !importInProgress
        setImportState(false)
        if canDismiss {
            dismiss()
        }
    }

    @IBAction func onAddStageClick(_ sender: AnyObject) {
        if competitionNameTextField.stringValue.isEmpty || !isGoodOsmFile() {
            return
        }

        setImportState(true)

        DispatchQueue.global().async {
            self.createStage(self.competitionNameTextField.stringValue, self.osmFileTextField.stringValue)
        }
    }

    fileprivate func createStage(_ competitionName: String, _ mapFileName: String) {
        DispatchQueue.main.async {
            self.conversionProgressBar.doubleValue = 0.0
        }

        let importer = MapImporter(sourceMapFileName: mapFileName) {
            progress -> Bool in
            DispatchQueue.main.async {
                self.conversionProgressBar.doubleValue = progress
            }
            return self.importInProgress
        }

        var maybeImportResult: ImportResult?
        do {
            maybeImportResult = try importer.doImport()
        } catch MapImportError.error(let message) {
            DispatchQueue.main.async {
                if self.importInProgress {
                    let alert = NSAlert()
                    alert.addButton(withTitle: "OK")
                    alert.messageText = message
                    alert.runModal()
                }
                self.setImportState(false)
            }
        } catch {
            fatalError("Should never happen")
        }

        if !importInProgress {
            return
        }

        if let importResult = maybeImportResult {
            let realm = try! Realm()
            try! realm.write {
                let stage = Stage()
                stage.competitionName = competitionName
                stage.stageNumber = 1
                stage.binMapFileName = importResult.binMapFileName
                stage.mapArea = importResult.mapArea

                realm.add(stage)
            }
            DispatchQueue.main.async(execute: dismiss)
        }
    }

    fileprivate func isGoodOsmFile() -> Bool {
        let filePath = osmFileTextField.stringValue
        var isDirectory = ObjCBool(false)
        let osmFileExists = fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
        if !osmFileExists || isDirectory.boolValue {
            return false
        }
        return filePath.hasSuffix(".osm")
    }

    fileprivate func dismiss() {
        self.parentController.reloadData()
        self.dismiss(self)
    }
    
    fileprivate func setImportState(_ inProgress: Bool) {
        self.importInProgress = inProgress
        let noImportInProgress = !importInProgress
        self.progressStackView.isHidden = noImportInProgress

        let controls: [NSControl?] = [
            self.addButton,
            self.osmSelectButton,
            self.osmFileTextField,
            self.competitionNameTextField
        ]
        for control in controls {
            control?.isEnabled = noImportInProgress
        }
    }
}
