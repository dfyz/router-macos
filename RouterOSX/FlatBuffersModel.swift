
// generated with FlatBuffersSchemaEditor https://github.com/mzaks/FlatBuffersSchemaEditor

import Foundation

public final class OsmNode {
	public var lat : Float64 = 0
	public var lon : Float64 = 0
	public var adj : ContiguousArray<UInt32> = []
	public init(){}
	public init(lat: Float64, lon: Float64, adj: ContiguousArray<UInt32>){
		self.lat = lat
		self.lon = lon
		self.adj = adj
	}
}
public extension OsmNode {
	fileprivate static func create(_ reader : FBReader, objectOffset : Offset?) -> OsmNode? {
		guard let objectOffset = objectOffset else {
			return nil
		}
		if  let cache = reader.cache,
			let o = cache.objectPool[objectOffset] {
			return o as? OsmNode
		}
		let _result = OsmNode()
		if let cache = reader.cache {
			cache.objectPool[objectOffset] = _result
		}
		_result.lat = reader.get(objectOffset: objectOffset, propertyIndex: 0, defaultValue: 0)
		_result.lon = reader.get(objectOffset: objectOffset, propertyIndex: 1, defaultValue: 0)
		let offset_adj : Offset? = reader.getOffset(objectOffset: objectOffset, propertyIndex: 2)
		let length_adj = reader.getVectorLength(vectorOffset: offset_adj)
		if(length_adj > 0){
			var index = 0
			_result.adj.reserveCapacity(length_adj)
			while index < length_adj {
				if let element : UInt32 = reader.getVectorScalarElement(vectorOffset: offset_adj, index: index) {
                    _result.adj.append(element)
                }
				index += 1
			}
		}
		return _result
	}
}
public struct OsmNode_Direct<T : FBReader> : Hashable {
	fileprivate let reader : T
	fileprivate let myOffset : Offset
	fileprivate init(reader: T, myOffset: Offset){
		self.reader = reader
		self.myOffset = myOffset
	}
	public var lat : Float64 { 
		get { return reader.get(objectOffset: myOffset, propertyIndex: 0, defaultValue: 0) }
	}
	public var lon : Float64 { 
		get { return reader.get(objectOffset: myOffset, propertyIndex: 1, defaultValue: 0) }
	}
	public var adjCount : Int {
		return reader.getVectorLength(vectorOffset: reader.getOffset(objectOffset: myOffset, propertyIndex: 2))
	}
	public var hashValue: Int { return Int(myOffset) }
}
public func ==<T>(t1 : OsmNode_Direct<T>, t2 : OsmNode_Direct<T>) -> Bool {
	return t1.reader.isEqual(other: t2.reader) && t1.myOffset == t2.myOffset
}
public extension OsmNode {
	fileprivate func addToByteArray(_ builder : FBBuilder) throws -> Offset {
		if builder.config.uniqueTables {
			if let myOffset = builder.cache[ObjectIdentifier(self)] {
				return myOffset
			}
		}
		var offset2 = Offset(0)
		if adj.count > 0 {
			try builder.startVector(count: adj.count, elementSize: MemoryLayout<UInt32>.stride)
			var index = adj.count - 1
			while(index >= 0){
				builder.put(value: adj[index])
				index -= 1
			}
			offset2 = builder.endVector()
		}
		try builder.openObject(numOfProperties: 3)
		if adj.count > 0 {
			try builder.addPropertyOffsetToOpenObject(propertyIndex: 2, offset: offset2)
		}
		try builder.addPropertyToOpenObject(propertyIndex: 1, value : lon, defaultValue : 0)
		try builder.addPropertyToOpenObject(propertyIndex: 0, value : lat, defaultValue : 0)
		let myOffset =  try builder.closeObject()
		if builder.config.uniqueTables {
			builder.cache[ObjectIdentifier(self)] = myOffset
		}
		return myOffset
	}
}
public final class OsmGraph {
	public var nodes : ContiguousArray<OsmNode?> = []
	public init(){}
	public init(nodes: ContiguousArray<OsmNode?>){
		self.nodes = nodes
	}
}
public extension OsmGraph {
	fileprivate static func create(_ reader : FBReader, objectOffset : Offset?) -> OsmGraph? {
		guard let objectOffset = objectOffset else {
			return nil
		}
		if  let cache = reader.cache,
			let o = cache.objectPool[objectOffset] {
			return o as? OsmGraph
		}
		let _result = OsmGraph()
		if let cache = reader.cache {
			cache.objectPool[objectOffset] = _result
		}
		let offset_nodes : Offset? = reader.getOffset(objectOffset: objectOffset, propertyIndex: 0)
		let length_nodes = reader.getVectorLength(vectorOffset: offset_nodes)
		if(length_nodes > 0){
			var index = 0
			_result.nodes.reserveCapacity(length_nodes)
			while index < length_nodes {
				let element = OsmNode.create(reader, objectOffset: reader.getVectorOffsetElement(vectorOffset: offset_nodes, index: index))
				_result.nodes.append(element)
				index += 1
			}
		}
		return _result
	}
}
public extension OsmGraph {
	public static func from(data : Data,  cache : FBReaderCache? = FBReaderCache()) -> OsmGraph? {
		let reader = FBMemoryReader(data: data, cache: cache)
		return from(reader: reader)
	}
	public static func from(reader : FBReader) -> OsmGraph? {
		let objectOffset = reader.rootObjectOffset
		return create(reader, objectOffset : objectOffset)
	}
}

public extension OsmGraph {
	public func encode(withBuilder builder : FBBuilder) throws -> Void {
		let offset = try addToByteArray(builder)
		try builder.finish(offset: offset, fileIdentifier: nil)
	}
	public func toData(withConfig config : FBBuildConfig = FBBuildConfig()) throws -> Data {
		let builder = FBBuilder(config: config)
		try encode(withBuilder: builder)
		return builder.data
	}
}

public struct OsmGraph_Direct<T : FBReader> : Hashable {
	fileprivate let reader : T
	fileprivate let myOffset : Offset
	fileprivate init(reader: T, myOffset: Offset){
		self.reader = reader
		self.myOffset = myOffset
	}
	public init?(_ reader: T) {
		self.reader = reader
		guard let offest = reader.rootObjectOffset else {
			return nil
		}
		self.myOffset = offest
	}
	public var nodesCount : Int {
		return reader.getVectorLength(vectorOffset: reader.getOffset(objectOffset: myOffset, propertyIndex: 0))
	}
	public func getNodesElement(atIndex index : Int) -> OsmNode_Direct<T>? {
		let offsetList = reader.getOffset(objectOffset: myOffset, propertyIndex: 0)
		if let ofs = reader.getVectorOffsetElement(vectorOffset: offsetList, index: index) {
			return OsmNode_Direct<T>(reader: reader, myOffset: ofs)
		}
		return nil
	}
	public var hashValue: Int { return Int(myOffset) }
}
public func ==<T>(t1 : OsmGraph_Direct<T>, t2 : OsmGraph_Direct<T>) -> Bool {
	return t1.reader.isEqual(other: t2.reader) && t1.myOffset == t2.myOffset
}
public extension OsmGraph {
	fileprivate func addToByteArray(_ builder : FBBuilder) throws -> Offset {
		if builder.config.uniqueTables {
			if let myOffset = builder.cache[ObjectIdentifier(self)] {
				return myOffset
			}
		}
		var offset0 = Offset(0)
		if nodes.count > 0{
			var offsets = [Offset?](repeating: nil, count: nodes.count)
			var index = nodes.count - 1
			while(index >= 0){
				offsets[index] = try nodes[index]?.addToByteArray(builder)
				index -= 1
			}
			try builder.startVector(count: nodes.count, elementSize: MemoryLayout<Offset>.stride)
			index = nodes.count - 1
			while(index >= 0){
				try builder.putOffset(offset: offsets[index])
				index -= 1
			}
			offset0 = builder.endVector()
		}
		try builder.openObject(numOfProperties: 1)
		if nodes.count > 0 {
			try builder.addPropertyOffsetToOpenObject(propertyIndex: 0, offset: offset0)
		}
		let myOffset =  try builder.closeObject()
		if builder.config.uniqueTables {
			builder.cache[ObjectIdentifier(self)] = myOffset
		}
		return myOffset
	}
}
// MARK: Reader
public protocol FBReader {
    func fromByteArray<T : Scalar>(position : Int) throws -> T
    func buffer(position : Int, length : Int) throws -> UnsafeBufferPointer<UInt8>
    var cache : FBReaderCache? {get}
    func isEqual(other : FBReader) -> Bool
}


fileprivate enum FBReaderError : Error {
    case OutOfBufferBounds
    case CanNotSetProperty
}

public class FBReaderCache {
    public var objectPool : [Offset : AnyObject] = [:]
    func reset(){
        objectPool.removeAll(keepingCapacity: true)
    }
    public init(){}
}

public extension FBReader {
    
    private func getPropertyOffset(objectOffset : Offset, propertyIndex : Int) -> Int {
        guard propertyIndex >= 0 else {
            return 0
        }
        do {
            let offset = Int(objectOffset)
            let localOffset : Int32 = try fromByteArray(position: offset)
            let vTableOffset : Int = offset - Int(localOffset)
            let vTableLength : Int16 = try fromByteArray(position: vTableOffset)
            let objectLength : Int16 = try fromByteArray(position: vTableOffset + 2)
            let positionInVTable = 4 + propertyIndex * 2
            if(vTableLength<=Int16(positionInVTable)) {
                return 0
            }
            let propertyStart = vTableOffset + positionInVTable
            let propertyOffset : Int16 = try fromByteArray(position: propertyStart)
            if(objectLength<=propertyOffset) {
                return 0
            }
            return Int(propertyOffset)
        } catch {
            return 0 // Currently don't want to propagate the error
        }
    }
    
    public func getOffset(objectOffset : Offset, propertyIndex : Int) -> Offset? {
        
        let propertyOffset = getPropertyOffset(objectOffset: objectOffset, propertyIndex: propertyIndex)
        if propertyOffset == 0 {
            return nil
        }
        
        let position = objectOffset + propertyOffset
        do {
            let localObjectOffset : Int32 = try fromByteArray(position: Int(position))
            let offset = position + localObjectOffset
            
            if localObjectOffset == 0 {
                return nil
            }
            return offset
        } catch {
            return nil
        }
        
    }
    
    public func getVectorLength(vectorOffset : Offset?) -> Int {
        guard let vectorOffset = vectorOffset else {
            return 0
        }
        let vectorPosition = Int(vectorOffset)
        do {
            let length2 : Int32 = try fromByteArray(position: vectorPosition)
            return Int(length2)
        } catch {
            return 0
        }
    }
    
    public func getVectorOffsetElement(vectorOffset : Offset?, index : Int) -> Offset? {
        guard let vectorOffset = vectorOffset else {
            return nil
        }
        guard index >= 0 else{
            return nil
        }
        guard index < getVectorLength(vectorOffset: vectorOffset) else {
            return nil
        }
        let valueStartPosition = Int(vectorOffset + MemoryLayout<Int32>.stride + (index * MemoryLayout<Int32>.stride))
        do {
            let localOffset : Int32 = try fromByteArray(position: valueStartPosition)
            if(localOffset == 0){
                return nil
            }
            return localOffset + valueStartPosition
        } catch {
            return nil
        }
    }
    
    public func getVectorScalarElement<T : Scalar>(vectorOffset : Offset?, index : Int) -> T? {
        guard let vectorOffset = vectorOffset else {
            return nil
        }
        guard index >= 0 else{
            return nil
        }
        guard index < getVectorLength(vectorOffset: vectorOffset) else {
            return nil
        }
        
        let valueStartPosition = Int(vectorOffset + MemoryLayout<Int32>.stride + (index * MemoryLayout<T>.stride))
        
        do {
            return try fromByteArray(position: valueStartPosition) as T
        } catch {
            return nil
        }
    }
    
    public func get<T : Scalar>(objectOffset : Offset, propertyIndex : Int, defaultValue : T) -> T {
        let propertyOffset = getPropertyOffset(objectOffset: objectOffset, propertyIndex: propertyIndex)
        if propertyOffset == 0 {
            return defaultValue
        }
        let position = Int(objectOffset + propertyOffset)
        do {
            return try fromByteArray(position: position)
        } catch {
            return defaultValue
        }
    }
    
    public func get<T : Scalar>(objectOffset : Offset, propertyIndex : Int) -> T? {
        let propertyOffset = getPropertyOffset(objectOffset: objectOffset, propertyIndex: propertyIndex)
        if propertyOffset == 0 {
            return nil
        }
        let position = Int(objectOffset + propertyOffset)
        do {
            return try fromByteArray(position: position) as T
        } catch {
            return nil
        }
    }
    
    public func getStringBuffer(stringOffset : Offset?) -> UnsafeBufferPointer<UInt8>? {
        guard let stringOffset = stringOffset else {
            return nil
        }
        let stringPosition = Int(stringOffset)
        do {
            let stringLength : Int32 = try fromByteArray(position: stringPosition)
            let stringCharactersPosition = stringPosition + MemoryLayout<Int32>.stride
            
            return try buffer(position: stringCharactersPosition, length: Int(stringLength))
        } catch {
            return nil
        }
    }
    
    public var rootObjectOffset : Offset? {
        do {
            return try fromByteArray(position: 0) as Offset
        } catch {
            return nil
        }
    }
}

public struct FBMemoryReader : FBReader {
    
    private let count : Int
    public let cache : FBReaderCache?
    private let buffer : UnsafeRawPointer
    
    public init(buffer : UnsafeRawPointer, count : Int, cache : FBReaderCache? = FBReaderCache()) {
        self.buffer = buffer
        self.count = count
        self.cache = cache
    }
    
    public init(data : Data, cache : FBReaderCache? = FBReaderCache()) {
        self.count = data.count
        self.cache = cache
        var pointer : UnsafePointer<UInt8>! = nil
        data.withUnsafeBytes { (u8Ptr: UnsafePointer<UInt8>) in
            pointer = u8Ptr
        }
        self.buffer = UnsafeRawPointer(pointer)
    }
    
    public func fromByteArray<T : Scalar>(position : Int) throws -> T {
        if position + MemoryLayout<T>.stride > count || position < 0 {
            throw FBReaderError.OutOfBufferBounds
        }
        
        return buffer.load(fromByteOffset: position, as: T.self)
    }
    
    public func buffer(position : Int, length : Int) throws -> UnsafeBufferPointer<UInt8> {
        if Int(position + length) > count {
            throw FBReaderError.OutOfBufferBounds
        }
        let pointer = buffer.advanced(by:position).bindMemory(to: UInt8.self, capacity: length)
        return UnsafeBufferPointer<UInt8>.init(start: pointer, count: Int(length))
    }
    
    public func isEqual(other: FBReader) -> Bool{
        guard let other = other as? FBMemoryReader else {
            return false
        }
        return self.buffer == other.buffer
    }
}

public struct FBFileReader : FBReader {
    
    private let fileSize : UInt64
    private let fileHandle : FileHandle
    public let cache : FBReaderCache?
    
    public init(fileHandle : FileHandle, cache : FBReaderCache? = FBReaderCache()){
        self.fileHandle = fileHandle
        fileSize = fileHandle.seekToEndOfFile()
        
        self.cache = cache
    }
    
    public func fromByteArray<T : Scalar>(position : Int) throws -> T {
        let seekPosition = UInt64(position)
        if seekPosition + UInt64(MemoryLayout<T>.stride) > fileSize {
            throw FBReaderError.OutOfBufferBounds
        }
        fileHandle.seek(toFileOffset: seekPosition)
        let data = fileHandle.readData(ofLength:MemoryLayout<T>.stride)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T>.stride)
        let t : UnsafeMutableBufferPointer<T> = UnsafeMutableBufferPointer(start: pointer, count: 1)
        _ = data.copyBytes(to: t)
        if let result = t.baseAddress?.pointee {
            pointer.deinitialize()
            return result
        }
        throw FBReaderError.OutOfBufferBounds
    }
    
    public func buffer(position : Int, length : Int) throws -> UnsafeBufferPointer<UInt8> {
        if UInt64(position + length) > fileSize {
            throw FBReaderError.OutOfBufferBounds
        }
        fileHandle.seek(toFileOffset: UInt64(position))
        let data = fileHandle.readData(ofLength:Int(length))
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        let t : UnsafeMutableBufferPointer<UInt8> = UnsafeMutableBufferPointer(start: pointer, count: length)
        _ = data.copyBytes(to: t)
        pointer.deinitialize()
        return UnsafeBufferPointer<UInt8>(start: t.baseAddress, count: length)
    }
    
    public func isEqual(other: FBReader) -> Bool{
        guard let other = other as? FBFileReader else {
            return false
        }
        return self.fileHandle === other.fileHandle
    }
}

postfix operator § 

public postfix func §(value: UnsafeBufferPointer<UInt8>) -> String? {
    return String.init(bytesNoCopy: UnsafeMutablePointer<UInt8>(mutating: value.baseAddress!), length: value.count, encoding: String.Encoding.utf8, freeWhenDone: false)
}
// MARK: Builder
public typealias Offset = Int32

public protocol Scalar : Equatable {}

extension Bool : Scalar {}
extension Int8 : Scalar {}
extension UInt8 : Scalar {}
extension Int16 : Scalar {}
extension UInt16 : Scalar {}
extension Int32 : Scalar {}
extension UInt32 : Scalar {}
extension Int64 : Scalar {}
extension UInt64 : Scalar {}
extension Int : Scalar {}
extension UInt : Scalar {}
extension Float32 : Scalar {}
extension Float64 : Scalar {}

public struct FBBuildConfig {
    public let initialCapacity : Int
    public let uniqueStrings : Bool
    public let uniqueTables : Bool
    public let uniqueVTables : Bool
    public let forceDefaults : Bool
    public let nullTerminatedUTF8 : Bool
    public init(initialCapacity : Int = 1, uniqueStrings : Bool = true, uniqueTables : Bool = true, uniqueVTables : Bool = true, forceDefaults : Bool = false, nullTerminatedUTF8 : Bool = false) {
        self.initialCapacity = initialCapacity
        self.uniqueStrings = uniqueStrings
        self.uniqueTables = uniqueTables
        self.uniqueVTables = uniqueVTables
        self.forceDefaults = forceDefaults
        self.nullTerminatedUTF8 = nullTerminatedUTF8
    }
}

public enum FBBuildError : Error {
    case ObjectIsNotClosed
    case NoOpenObject
    case PropertyIndexIsInvalid
    case OffsetIsTooBig
    case CursorIsInvalid
    case BadFileIdentifier
    case UnsupportedType
}

public final class FBBuilder {
    
    private var _config : FBBuildConfig
    public var config : FBBuildConfig { return _config }
    private var capacity : Int
    private var _data : UnsafeMutableRawPointer
    private var minalign = 1;
    private var cursor = 0
    private var leftCursor : Int {
        return capacity - cursor
    }
    
    private var currentVTable : ContiguousArray<Int32> = []
    private var objectStart : Int32 = -1
    private var vectorNumElems : Int32 = -1;
    private var vTableOffsets : ContiguousArray<Int32> = []
    
    public var cache : [ObjectIdentifier : Offset] = [:]
    public var inProgress : Set<ObjectIdentifier> = []
    public var deferedBindings : ContiguousArray<(object:Any, cursor:Int)> = []
    
    public init(config : FBBuildConfig = FBBuildConfig()) {
        self._config = config
        self.capacity = config.initialCapacity
        _data = UnsafeMutableRawPointer.allocate(bytes: capacity, alignedTo: minalign)
    }
    
    public var data : Data {
        return Data(bytes:_data.advanced(by:leftCursor), count: cursor)
    }
    
    private func increaseCapacity(size : Int){
        guard leftCursor <= size else {
            return
        }
        let _leftCursor = leftCursor
        let _capacity = capacity
        while leftCursor <= size {
            capacity = capacity << 1
        }
        
        let newData = UnsafeMutableRawPointer.allocate(bytes: capacity, alignedTo: minalign)
        newData.advanced(by:leftCursor).copyBytes(from: _data.advanced(by: _leftCursor), count: cursor)
        _data.deallocate(bytes: _capacity, alignedTo: minalign)
        _data = newData
    }
    
    private func align(size : Int, additionalBytes : Int){
        if size > minalign {
            minalign = size
        }
        let alignSize = ((~(cursor + additionalBytes)) + 1) & (size - 1)
        increaseCapacity(size: alignSize)
        cursor += alignSize
        
    }
    
    public func put<T : Scalar>(value : T){
        let c = MemoryLayout.stride(ofValue: value)
        if c > 8 {
            align(size: 8, additionalBytes: c)
        } else {
            align(size: c, additionalBytes: 0)
        }
        
        increaseCapacity(size: c)
        
        _data.storeBytes(of: value, toByteOffset: leftCursor-c, as: T.self)
        cursor += c
    }
    
    @discardableResult
    public func putOffset(offset : Offset?) throws -> Int { // make offset relative and put it into byte buffer
        guard let offset = offset else {
            put(value: Offset(0))
            return cursor
        }
        guard offset <= Int32(cursor) else {
            throw FBBuildError.OffsetIsTooBig
        }
        
        if offset == Int32(0) {
            put(value: Offset(0))
            return cursor
        }
        align(size: 4, additionalBytes: 0)
        let _offset = Int32(cursor) - offset + MemoryLayout<Int32>.stride;
        put(value: _offset)
        return cursor
    }
    
    public func replaceOffset(offset : Offset, atCursor jumpCursor: Int) throws{
        guard offset <= Int32(cursor) else {
            throw FBBuildError.OffsetIsTooBig
        }
        guard jumpCursor <= cursor else {
            throw FBBuildError.CursorIsInvalid
        }
        let _offset = Int32(jumpCursor) - offset;
        
        _data.storeBytes(of: _offset, toByteOffset: capacity - jumpCursor, as: Int32.self)
    }
    
    private func put<T : Scalar>(value : T, at index : Int) {
        _data.storeBytes(of: value, toByteOffset: index + leftCursor, as: T.self)
    }
    
    public func openObject(numOfProperties : Int) throws {
        guard objectStart == -1 && vectorNumElems == -1 else {
            throw FBBuildError.ObjectIsNotClosed
        }
        currentVTable.removeAll(keepingCapacity: true)
        currentVTable.reserveCapacity(numOfProperties)
        for _ in 0..<numOfProperties {
            currentVTable.append(0)
        }
        objectStart = Int32(cursor)
    }
    
    @discardableResult
    public func addPropertyOffsetToOpenObject(propertyIndex : Int, offset : Offset) throws -> Int{
        guard objectStart > -1 else {
            throw FBBuildError.NoOpenObject
        }
        guard propertyIndex >= 0 && propertyIndex < currentVTable.count else {
            throw FBBuildError.PropertyIndexIsInvalid
        }
        _ = try putOffset(offset: offset)
        currentVTable[propertyIndex] = Int32(cursor)
        return cursor
    }
    
    public func addPropertyToOpenObject<T : Scalar>(propertyIndex : Int, value : T, defaultValue : T) throws {
        guard objectStart > -1 else {
            throw FBBuildError.NoOpenObject
        }
        guard propertyIndex >= 0 && propertyIndex < currentVTable.count else {
            throw FBBuildError.PropertyIndexIsInvalid
        }
        
        if(config.forceDefaults == false && value == defaultValue) {
            return
        }
        
        put(value: value)
        currentVTable[propertyIndex] = Int32(cursor)
    }
    
    public func addCurrentOffsetAsPropertyToOpenObject(propertyIndex : Int) throws {
        guard objectStart > -1 else {
            throw FBBuildError.NoOpenObject
        }
        guard propertyIndex >= 0 && propertyIndex < currentVTable.count else {
            throw FBBuildError.PropertyIndexIsInvalid
        }
        currentVTable[propertyIndex] = Int32(cursor)
    }
    
    public func closeObject() throws -> Offset {
        guard objectStart > -1 else {
            throw FBBuildError.NoOpenObject
        }
        align(size: 4, additionalBytes: 0)
        increaseCapacity(size: 4)
        cursor += 4 // Will be set to vtable offset afterwards
        
        let vtableloc = cursor
        
        // vtable is stored as relative offset for object data
        var index = currentVTable.count - 1
        while(index>=0) {
            // Offset relative to the start of the table.
            let off = Int16(currentVTable[index] != 0 ? Int32(vtableloc) - currentVTable[index] : 0);
            put(value: off);
            index -= 1
        }
        
        let numberOfstandardFields = 2
        
        put(value: Int16(Int32(vtableloc) - objectStart)); // standard field 1: lenght of the object data
        put(value: Int16((currentVTable.count + numberOfstandardFields) * MemoryLayout<Int16>.stride)); // standard field 2: length of vtable and standard fields them selves
        
        // search if we already have same vtable
        let vtableDataLength = cursor - vtableloc
        
        var foundVTableOffset = vtableDataLength
        
        if config.uniqueVTables{
            for otherVTableOffset in vTableOffsets {
                let start = cursor - Int(otherVTableOffset)
                var found = true
                for i in 0 ..< vtableDataLength {
                    let a = _data.advanced(by:leftCursor + i).assumingMemoryBound(to: UInt8.self).pointee
                    let b = _data.advanced(by:leftCursor + i + start).assumingMemoryBound(to: UInt8.self).pointee
                    if a != b {
                        found = false
                        break;
                    }
                }
                if found == true {
                    foundVTableOffset = Int(otherVTableOffset) - vtableloc
                    break
                }
            }
            
            if foundVTableOffset != vtableDataLength {
                cursor -= vtableDataLength
            } else {
                vTableOffsets.append(Int32(cursor))
            }
        }
        
        let indexLocation = cursor - vtableloc
        
        put(value: Int32(foundVTableOffset), at: indexLocation)
        
        objectStart = -1
        
        return Offset(vtableloc)
    }
    
    public func startVector(count : Int, elementSize : Int) throws{
        align(size: 4, additionalBytes: count * elementSize)
        guard objectStart == -1 && vectorNumElems == -1 else {
            throw FBBuildError.ObjectIsNotClosed
        }
        vectorNumElems = Int32(count)
    }
    
    public func endVector() -> Offset {
        put(value: vectorNumElems)
        vectorNumElems = -1
        return Int32(cursor)
    }
    
    private var stringCache : [String:Offset] = [:]
    public func createString(value : String?) throws -> Offset {
        guard objectStart == -1 && vectorNumElems == -1 else {
            throw FBBuildError.ObjectIsNotClosed
        }
        guard let value = value else {
            return 0
        }
        
        if config.uniqueStrings{
            if let o = stringCache[value]{
                return o
            }
        }
        // TODO: Performance Test
        if config.nullTerminatedUTF8 {
            let utf8View = value.utf8CString
            let length = utf8View.count
            align(size: 4, additionalBytes: length)
            increaseCapacity(size: length)
            for c in utf8View.lazy.reversed() {
                put(value: c)
            }
            put(value: Int32(length - 1))
        } else {
            let utf8View = value.utf8
            let length = utf8View.count
            align(size: 4, additionalBytes: length)
            increaseCapacity(size: length)
            for c in utf8View.lazy.reversed() {
                put(value: c)
            }
            put(value: Int32(length))
        }
        
        let o = Offset(cursor)
        if config.uniqueStrings {
            stringCache[value] = o
        }
        return o
    }
    
    public func finish(offset : Offset, fileIdentifier : String?) throws -> Void {
        guard offset <= Int32(cursor) else {
            throw FBBuildError.OffsetIsTooBig
        }
        guard objectStart == -1 && vectorNumElems == -1 else {
            throw FBBuildError.ObjectIsNotClosed
        }
        var prefixLength = 4
        if let fileIdentifier = fileIdentifier {
            prefixLength += 4
            align(size: minalign, additionalBytes: prefixLength)
            let utf8View = fileIdentifier.utf8
            let count = utf8View.count
            guard count == 4 else {
                throw FBBuildError.BadFileIdentifier
            }
            for c in utf8View.lazy.reversed() {
                put(value: c)
            }
        } else {
            align(size: minalign, additionalBytes: prefixLength)
        }
        
        let v = (Int32(cursor + 4) - offset)
        
        put(value: v)
    }
}
