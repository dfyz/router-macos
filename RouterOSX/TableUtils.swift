import Cocoa
import Foundation

func getTextViewForTableCell(
        _ tableView: NSTableView,
        _ tableColumn: NSTableColumn?,
        _ getText: (String) -> String?) -> NSView?
{
    guard let columnIdentifier = tableColumn?.identifier else {
        return nil
    }

    guard let text = getText(columnIdentifier.rawValue) else {
        fatalError("Unknown column: \(columnIdentifier)")
    }

    let cellIdentifier = NSUserInterfaceItemIdentifier(columnIdentifier.rawValue.replacingOccurrences(of: "Column", with: "Cell"))
    guard let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else {
        return nil
    }
    cell.textField?.stringValue = text
    return cell
}
