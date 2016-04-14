import Foundation

enum MapImportError: ErrorType {
    case Error(String)
}

class MapImporter: NSObject, NSXMLParserDelegate {
    let fileManager = NSFileManager.defaultManager()

    let sourceMapFileName: String
    let callback: Double -> Bool

    var input: NSInputStream!
    var fileSize: UInt64!
    var nodeCount: uint = 0

    init(sourceMapFileName: String, callback: Double -> Bool) {
        self.sourceMapFileName = sourceMapFileName
        self.callback = callback
    }

    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        let bytesRead = (input.propertyForKey(NSStreamFileCurrentOffsetKey) as! NSNumber).doubleValue
        let progress = bytesRead / Double(fileSize) * 100.0
        if !self.callback(progress) {
            parser.abortParsing()
        }
    }

    func doImport() throws -> String {
        input = NSInputStream(fileAtPath: sourceMapFileName)
        if input == nil {
            throw MapImportError.Error("Failed to load \(sourceMapFileName)")
        }
        fileSize = getFileSize(sourceMapFileName)
        if fileSize == nil {
            throw MapImportError.Error("Failed to get size for \(sourceMapFileName)")
        }

        let resultFileName = getBinMapFileName(sourceMapFileName)
        let parser = NSXMLParser(stream: input)
        parser.delegate = self
        guard parser.parse() else {
            let err = parser.parserError!
            throw MapImportError.Error("Failed to parse \(sourceMapFileName): \(err.localizedDescription)")
        }
        return resultFileName
    }

    private func getBinMapFileName(sourceMapFileName: String) -> String {
        return ""
    }

    private func getFileSize(fileName: String) -> UInt64? {
        do {
            let attrs = try fileManager.attributesOfItemAtPath(fileName)
            return (attrs[NSFileSize] as! NSNumber).unsignedLongLongValue
        } catch _ {
            return nil
        }
    }
}
