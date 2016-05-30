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

        startRouting(points, binMapFileName)
    }

    @IBAction func onCancel(sender: AnyObject) {
        shouldContinue = false
    }

    private func startRouting(points: [NamedPoint], _ binMapFileName: String) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let routingResult: RoutingResultOrError
            do {
                let router = try Router(points: points, binMapFileName: binMapFileName) {
                    (progressText, progressValue) -> Bool in

                    dispatch_async(dispatch_get_main_queue()) {
                        self.updateProgress(progressText, progressValue)
                    }
                    return self.shouldContinue
                }
                routingResult = .Ok(try router.route())
            } catch RoutingError.AbortedByUser {
                routingResult = .AbortedByUser
            } catch RoutingError.Error(let message) {
                routingResult = .Error(message)
            } catch {
                fatalError("Should never happen")
            }

            dispatch_async(dispatch_get_main_queue()) {
                self.onRoutingCompleted(routingResult)
            }
        }
    }

    private func updateProgress(progressText: String, _ progressValue: Double?) {
        progressTextField.stringValue = progressText
        if let value = progressValue {
            progressBar.indeterminate = false
            progressBar.doubleValue = value * 100.0
        } else {
            progressBar.indeterminate = true
            progressBar.startAnimation(self)
        }
    }

    private func onRoutingCompleted(routingResult: RoutingResultOrError) {
        switch routingResult {
        case .Ok(let result):
            parentController.drawRoutingResult(result)
        case .Error(let message):
            let alert = NSAlert()
            alert.addButtonWithTitle("OK")
            alert.messageText = message
            alert.runModal()
        default:
            break
        }
        dismiss()
    }

    private func dismiss() {
        self.dismissController(self)
    }
}

private enum RoutingResultOrError {
    case Ok(RoutingResult)
    case Error(String)
    case AbortedByUser
}