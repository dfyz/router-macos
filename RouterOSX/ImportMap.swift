import Foundation
import RealmSwift

enum MapImportError: ErrorType {
    case Error(String)
}

class MapImporter: NSObject, NSXMLParserDelegate {
    let fileManager = NSFileManager.defaultManager()

    let sourceMapFileName: String
    let callback: Double -> Bool

    var input: NSInputStream!
    var fileSize: UInt64!

    var globalIdToNode = [UInt32: OsmNode]()
    var globalIdToIndex = [UInt32: Int]()
    var nodes = [OsmNode?]()
    var currentNodes = [UInt32]()

    var inWay = false
    var isHighway = false

    init(sourceMapFileName: String, callback: Double -> Bool) {
        self.sourceMapFileName = sourceMapFileName
        self.callback = callback
    }

    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        updateProgress(parser)

        switch elementName {
        case "node":
            let globalId = UInt32(attributeDict["id"]!)!
            let (lat, lon) = (Double(attributeDict["lat"]!)!, Double(attributeDict["lon"]!)!)
            globalIdToNode[globalId] = OsmNode(lat: lat, lon: lon, adj: [])
        case "way":
            inWay = true
            isHighway = false
        case "nd" where inWay:
            let currentId = UInt32(attributeDict["ref"]!)!
            currentNodes.append(currentId)
        case "tag" where inWay && attributeDict["k"] == "highway":
            isHighway = true
        default:
            break
        }
    }

    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName != "way" {
            return
        }

        if isHighway && !currentNodes.isEmpty {
            for i in 1..<currentNodes.count {
                let maybePrevIndex = idToIndex(currentNodes[i - 1])
                let maybeCurrentIndex = idToIndex(currentNodes[i])
                if maybePrevIndex != nil && maybeCurrentIndex != nil {
                    let prevIndex = maybePrevIndex!
                    let currentIndex = maybeCurrentIndex!
                    nodes[prevIndex]!.adj.append(UInt32(currentIndex))
                    nodes[currentIndex]!.adj.append(UInt32(prevIndex))
                }
            }
        }

        inWay = false
        isHighway = false
        currentNodes.removeAll()
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

        let parser = NSXMLParser(stream: input)
        parser.delegate = self
        guard parser.parse() else {
            let err = parser.parserError!
            throw MapImportError.Error("Failed to parse \(sourceMapFileName): \(err.localizedDescription)")
        }

        let resultFileName = getBinMapFileName(sourceMapFileName)
        saveToFile(resultFileName)
        return resultFileName
    }

    private func getBinMapFileName(sourceMapFileName: String) -> String {
        let sourceMapBasename = NSString(string: sourceMapFileName).lastPathComponent
        let binMapBasename = NSString(string: sourceMapBasename).stringByDeletingPathExtension + ".bin"
        var config = Realm.Configuration()
        return (NSURL.fileURLWithPath(config.path!).URLByDeletingLastPathComponent?.URLByAppendingPathComponent(binMapBasename).path)!
    }

    private func saveToFile(resultFileName: String) {
        let graph = OsmGraph(nodes: nodes)
        let rawData = graph.toByteArray
        let nsData = NSData(bytes: rawData, length: rawData.count)
        nsData.writeToFile(resultFileName, atomically: true)
    }

    private func getFileSize(fileName: String) -> UInt64? {
        do {
            let attrs = try fileManager.attributesOfItemAtPath(fileName)
            return (attrs[NSFileSize] as! NSNumber).unsignedLongLongValue
        } catch _ {
            return nil
        }
    }

    private func updateProgress(parser: NSXMLParser) {
        let bytesRead = (input.propertyForKey(NSStreamFileCurrentOffsetKey) as! NSNumber).doubleValue
        let progress = bytesRead / Double(fileSize) * 100.0
        if !self.callback(progress) {
            parser.abortParsing()
        }
    }

    private func idToIndex(id: UInt32) -> Int? {
        var result = globalIdToIndex[id]
        if result == nil {
            if let node = globalIdToNode[id] {
                result = nodes.count
                globalIdToIndex[id] = result
                nodes.append(node)
            }
        }
        return result
    }
}
