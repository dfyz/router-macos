import Cocoa
import Foundation

func getTextViewForTableCell(
        tableView: NSTableView,
        _ tableColumn: NSTableColumn?,
        _ getText: String -> String?) -> NSView?
{
    guard let columnIdentifier = tableColumn?.identifier else {
        return nil
    }

    guard let text = getText(columnIdentifier) else {
        fatalError("Unknown column: \(columnIdentifier)")
    }

    let cellIdentifier = columnIdentifier.stringByReplacingOccurrencesOfString("Column", withString: "Cell")
    guard let cell = tableView.makeViewWithIdentifier(cellIdentifier, owner: nil) as? NSTableCellView else {
        return nil
    }
    cell.textField?.stringValue = text
    return cell
}