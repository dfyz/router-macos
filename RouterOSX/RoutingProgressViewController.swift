import Cocoa
import Foundation

class RoutingProgressViewController: NSViewController {
    @IBOutlet weak var progressTextField: NSTextField!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var cancelButton: NSButton!

    var parentController: MapViewController!
    var shouldContinue = true

    override func viewDidLoad() {
        super.viewDidLoad()

        let points = parentController.stage.points.map { NamedPoint(name: $0.name, lat: $0.lat, lon: $0.lon) }
        let binMapFileName = parentController.stage.binMapFileName

        startRouting(Array(points), binMapFileName)
    }

    @IBAction func onCancel(_ sender: AnyObject) {
        shouldContinue = false
    }

    fileprivate func startRouting(_ points: [NamedPoint], _ binMapFileName: String) {
        DispatchQueue.global().async {
            let routingResult: RoutingResultOrError
            do {
                let router = try Router(points: points, binMapFileName: binMapFileName) {
                    (progressText, progressValue) -> Bool in

                    DispatchQueue.main.async {
                        self.updateProgress(progressText, progressValue)
                    }
                    return self.shouldContinue
                }
                routingResult = .ok(try router.route())
            } catch RoutingError.abortedByUser {
                routingResult = .abortedByUser
            } catch RoutingError.error(let message) {
                routingResult = .error(message)
            } catch {
                fatalError("Should never happen")
            }

            DispatchQueue.main.async {
                self.onRoutingCompleted(routingResult)
            }
        }
    }

    fileprivate func updateProgress(_ progressText: String, _ progressValue: Double?) {
        progressTextField.stringValue = progressText
        if let value = progressValue {
            progressBar.isIndeterminate = false
            progressBar.doubleValue = value * 100.0
        } else {
            progressBar.isIndeterminate = true
            progressBar.startAnimation(self)
        }
    }

    fileprivate func onRoutingCompleted(_ routingResult: RoutingResultOrError) {
        switch routingResult {
        case .ok(let result):
            parentController.drawRoutingResult(result)
        case .error(let message):
            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = message
            alert.runModal()
        default:
            break
        }
        dismiss()
    }

    fileprivate func dismiss() {
        self.dismiss(self)
    }
}

private enum RoutingResultOrError {
    case ok(RoutingResult)
    case error(String)
    case abortedByUser
}
