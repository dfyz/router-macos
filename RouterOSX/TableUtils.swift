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

    guard let text = getText(columnIdentifier) else {
        fatalError("Unknown column: \(columnIdentifier)")
    }

    let cellIdentifier = columnIdentifier.replacingOccurrences(of: "Column", with: "Cell")
    guard let cell = tableView.make(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else {
        return nil
    }
    cell.textField?.stringValue = text
    return cell
}
