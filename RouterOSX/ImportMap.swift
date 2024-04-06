import Foundation
import RealmSwift

enum MapImportError: Error {
    case error(String)
}

struct ImportResult {
    let mapArea: MapArea
    let binMapFileName: String
}

class MapImporter: NSObject, XMLParserDelegate {
    let fileManager = FileManager.default

    let sourceMapFileName: String
    let callback: (Double) -> Bool

    var input: InputStream!
    var fileSize: UInt64!

    var globalIdToNode = [UInt64: OsmNode]()
    var globalIdToIndex = [UInt64: UInt32]()
    var nodes = [OsmNode]()
    var currentNodes = [UInt64]()

    var inWay = false
    var isHighway = false

    init(sourceMapFileName: String, callback: @escaping (Double) -> Bool) {
        self.sourceMapFileName = sourceMapFileName
        self.callback = callback
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
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

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName != "way" {
            return
        }

        if isHighway && !currentNodes.isEmpty {
            for i in 1..<currentNodes.count {
                if
                    let prevIndex = idToIndex(currentNodes[i - 1]),
                    let currentIndex = idToIndex(currentNodes[i])
                {
                    nodes[Int(prevIndex)].adj.append(currentIndex)
                    nodes[Int(currentIndex)].adj.append(prevIndex)
                }
            }
        }

        inWay = false
        isHighway = false
        currentNodes.removeAll()
    }

    func doImport() throws -> ImportResult {
        input = InputStream(fileAtPath: sourceMapFileName)
        if input == nil {
            throw MapImportError.error("Failed to load \(sourceMapFileName)")
        }
        fileSize = getFileSize(sourceMapFileName)
        if fileSize == nil {
            throw MapImportError.error("Failed to get size for \(sourceMapFileName)")
        }

        let parser = XMLParser(stream: input)
        parser.delegate = self
        guard parser.parse() else {
            let err = parser.parserError!
            throw MapImportError.error("Failed to parse \(sourceMapFileName): \(err.localizedDescription)")
        }

        let resultFileName = getBinMapFileName(sourceMapFileName)
        do {
            try saveToFile(resultFileName)
        } catch _ {
            throw MapImportError.error("Failed to save the loaded data to \(resultFileName)")
        }
        return ImportResult(mapArea: getMapArea(), binMapFileName: resultFileName)
    }

    fileprivate func getBinMapFileName(_ sourceMapFileName: String) -> String {
        let sourceMapBasename = NSString(string: sourceMapFileName).lastPathComponent
        let binMapBasename = NSString(string: sourceMapBasename).deletingPathExtension + ".bin"
        let config = Realm.Configuration()
        return config.fileURL!.deletingLastPathComponent().appendingPathComponent(binMapBasename).path
    }

    fileprivate func saveToFile(_ resultFileName: String) throws {
        let graph = OsmGraph(nodes: nodes)
        let graphData = try graph.makeData()
        try graphData.write(to: URL(fileURLWithPath: resultFileName), options: [.atomic])
    }

    fileprivate func getMapArea() -> MapArea {
        var minLat = Double.infinity
        var maxLat = -Double.infinity
        var minLon = Double.infinity
        var maxLon = -Double.infinity

        for maybeNode in nodes {
            let node = maybeNode
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

    fileprivate func getFileSize(_ fileName: String) -> UInt64? {
        do {
            let attrs = try fileManager.attributesOfItem(atPath: fileName)
            return (attrs[FileAttributeKey.size] as! NSNumber).uint64Value
        } catch _ {
            return nil
        }
    }

    fileprivate func updateProgress(_ parser: XMLParser) {
        let bytesRead = (input.property(forKey: Stream.PropertyKey.fileCurrentOffsetKey) as! NSNumber).doubleValue
        let progress = bytesRead / Double(fileSize) * 100.0
        if !self.callback(progress) {
            parser.abortParsing()
        }
    }

    fileprivate func idToIndex(_ id: UInt64) -> UInt32? {
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
