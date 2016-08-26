import Foundation
import RealmSwift

enum MapImportError: ErrorType {
    case Error(String)
}

struct ImportResult {
    let mapArea: MapArea
    let binMapFileName: String
}

class MapImporter: NSObject, NSXMLParserDelegate {
    let fileManager = NSFileManager.defaultManager()

    let sourceMapFileName: String
    let callback: Double -> Bool

    var input: NSInputStream!
    var fileSize: UInt64!

    var globalIdToNode = [UInt64: OsmNode]()
    var globalIdToIndex = [UInt64: UInt32]()
    var nodes = [OsmNode?]()
    var currentNodes = [UInt64]()

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
            if
                let idAttr = attributeDict["id"],
                let globalId = UInt64(idAttr),
                let latAttr = attributeDict["lat"],
                let lat = Double(latAttr),
                let lonAttr = attributeDict["lon"],
                let lon = Double(lonAttr)
            {
                globalIdToNode[globalId] = OsmNode(lat: lat, lon: lon, adj: [])
            }
        case "way":
            inWay = true
            isHighway = false
        case "nd" where inWay:
            if
                let refAttr = attributeDict["ref"],
                let currentId = UInt64(refAttr)
            {
                currentNodes.append(currentId)
            }
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
                if
                    let prevIndex = idToIndex(currentNodes[i - 1]),
                    let currentIndex = idToIndex(currentNodes[i])
                {
                    nodes[Int(prevIndex)]!.adj.append(currentIndex)
                    nodes[Int(currentIndex)]!.adj.append(prevIndex)
                }
            }
        }

        inWay = false
        isHighway = false
        currentNodes.removeAll()
    }

    func doImport() throws -> ImportResult {
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
        return ImportResult(mapArea: getMapArea(), binMapFileName: resultFileName)
    }

    private func getBinMapFileName(sourceMapFileName: String) -> String {
        let sourceMapBasename = NSString(string: sourceMapFileName).lastPathComponent
        let binMapBasename = NSString(string: sourceMapBasename).stringByDeletingPathExtension + ".bin"
        var config = Realm.Configuration()
        return (config.fileURL!.URLByDeletingLastPathComponent?.URLByAppendingPathComponent(binMapBasename).path)!
    }

    private func saveToFile(resultFileName: String) {
        let graph = OsmGraph(nodes: nodes)
        let rawData = graph.toByteArray
        let nsData = NSData(bytes: rawData, length: rawData.count)
        nsData.writeToFile(resultFileName, atomically: true)
    }

    private func getMapArea() -> MapArea {
        var minLat = Double.infinity
        var maxLat = -Double.infinity
        var minLon = Double.infinity
        var maxLon = -Double.infinity

        for maybeNode in nodes {
            let node = maybeNode!
            minLat = min(minLat, node.lat)
            maxLat = max(maxLat, node.lat)
            minLon = min(minLon, node.lon)
            maxLon = max(maxLon, node.lon)
        }

        let result = MapArea()
        result.height = maxLat - minLat
        result.width = maxLon - minLon
        result.centerLat = (minLat + maxLat) / 2.0
        result.centerLon = (minLon + maxLon) / 2.0
        return result
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

    private func idToIndex(id: UInt64) -> UInt32? {
        if let result = globalIdToIndex[id] {
            return result
        }
        guard let node = globalIdToNode[id] else {
            return nil
        }
        let result = UInt32(nodes.count)
        globalIdToIndex[id] = result
        nodes.append(node)
        return result
    }
}
