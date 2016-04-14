// generated with FlatBuffersSchemaEditor https://github.com/mzaks/FlatBuffersSchemaEditor

public final class OsmNode {
	public var lat : Float64 = 0
	public var lon : Float64 = 0
	public var adj : [UInt32] = []
	public init(){}
	public init(lat: Float64, lon: Float64, adj: [UInt32]){
		self.lat = lat
		self.lon = lon
		self.adj = adj
	}
}
public extension OsmNode {
	private static func create(reader : FlatBufferReader, objectOffset : Offset?) -> OsmNode? {
		guard let objectOffset = objectOffset else {
			return nil
		}
		let _result = OsmNode()
		_result.lat = reader.get(objectOffset, propertyIndex: 0, defaultValue: 0)
		_result.lon = reader.get(objectOffset, propertyIndex: 1, defaultValue: 0)
		let offset_adj : Offset? = reader.getOffset(objectOffset, propertyIndex: 2)
		let length_adj = reader.getVectorLength(offset_adj)
		if(length_adj > 0){
			var index = 0
			while index < length_adj {
				_result.adj.append(reader.getVectorScalarElement(offset_adj!, index: index))
				index += 1
			}
		}
		return _result
	}
}
public extension OsmNode {
	public final class LazyAccess{
		private let _reader : FlatBufferReader!
		private let _objectOffset : Offset!
		private init?(reader : FlatBufferReader, objectOffset : Offset?){
			guard let objectOffset = objectOffset else {
				_reader = nil
				_objectOffset = nil
				return nil
			}
			_reader = reader
			_objectOffset = objectOffset
		}

		public lazy var lat : Float64 = self._reader.get(self._objectOffset, propertyIndex: 0, defaultValue:0)
		public lazy var lon : Float64 = self._reader.get(self._objectOffset, propertyIndex: 1, defaultValue:0)
		public lazy var adj : LazyVector<UInt32> = {
			let vectorOffset : Offset? = self._reader.getOffset(self._objectOffset, propertyIndex: 2)
			let vectorLength = self._reader.getVectorLength(vectorOffset)
			return LazyVector(count: vectorLength){
				self._reader.getVectorScalarElement(vectorOffset!, index: $0) as UInt32
			}
		}()

		public lazy var createEagerVersion : OsmNode? = OsmNode.create(self._reader, objectOffset: self._objectOffset)
	}
}
public extension OsmNode {
	private func addToByteArray(builder : FlatBufferBuilder) -> Offset {
		var offset2 = Offset(0)
		if adj.count > 0{
			try! builder.startVector(adj.count)
			var index = adj.count - 1
			while(index >= 0){
				builder.put(adj[index])
				index -= 1
			}
			offset2 = builder.endVector()
		}
		try! builder.openObject(3)
		try! builder.addPropertyOffsetToOpenObject(2, offset: offset2)
		try! builder.addPropertyToOpenObject(1, value : lon, defaultValue : 0)
		try! builder.addPropertyToOpenObject(0, value : lat, defaultValue : 0)
		return try! builder.closeObject()
	}
}
public final class OsmGraph {
	public var nodes : [OsmNode?] = []
	public init(){}
	public init(nodes: [OsmNode?]){
		self.nodes = nodes
	}
}
public extension OsmGraph {
	private static func create(reader : FlatBufferReader, objectOffset : Offset?) -> OsmGraph? {
		guard let objectOffset = objectOffset else {
			return nil
		}
		let _result = OsmGraph()
		let offset_nodes : Offset? = reader.getOffset(objectOffset, propertyIndex: 0)
		let length_nodes = reader.getVectorLength(offset_nodes)
		if(length_nodes > 0){
			var index = 0
			while index < length_nodes {
				_result.nodes.append(OsmNode.create(reader, objectOffset: reader.getVectorOffsetElement(offset_nodes!, index: index)))
				index += 1
			}
		}
		return _result
	}
}
public extension OsmGraph {
	public static func fromByteArray(data : UnsafePointer<UInt8>) -> OsmGraph {
		let reader = FlatBufferReader(bytes: data)
		let objectOffset = reader.rootObjectOffset
		return create(reader, objectOffset : objectOffset)!
	}
}
public extension OsmGraph {
	public var toByteArray : [UInt8] {
		let builder = FlatBufferBuilder()
		return try! builder.finish(addToByteArray(builder), fileIdentifier: nil)
	}
}
public extension OsmGraph {
	public final class LazyAccess{
		private let _reader : FlatBufferReader!
		private let _objectOffset : Offset!
		public init(data : UnsafePointer<UInt8>){
			_reader = FlatBufferReader(bytes: data)
			_objectOffset = _reader.rootObjectOffset
		}
		private init?(reader : FlatBufferReader, objectOffset : Offset?){
			guard let objectOffset = objectOffset else {
				_reader = nil
				_objectOffset = nil
				return nil
			}
			_reader = reader
			_objectOffset = objectOffset
		}

		public lazy var nodes : LazyVector<OsmNode.LazyAccess> = {
			let vectorOffset : Offset? = self._reader.getOffset(self._objectOffset, propertyIndex: 0)
			let vectorLength = self._reader.getVectorLength(vectorOffset)
			return LazyVector(count: vectorLength){
				OsmNode.LazyAccess(reader: self._reader, objectOffset : self._reader.getVectorOffsetElement(vectorOffset!, index: $0))
			}
		}()

		public lazy var createEagerVersion : OsmGraph? = OsmGraph.create(self._reader, objectOffset: self._objectOffset)
	}
}
public extension OsmGraph {
	private func addToByteArray(builder : FlatBufferBuilder) -> Offset {
		var offset0 = Offset(0)
		if nodes.count > 0{
			var offsets = [Offset?](count: nodes.count, repeatedValue: nil)
			var index = nodes.count - 1
			while(index >= 0){
				offsets[index] = nodes[index]?.addToByteArray(builder)
				index -= 1
			}
			try! builder.startVector(nodes.count)
			index = nodes.count - 1
			while(index >= 0){
				try! builder.putOffset(offsets[index])
				index -= 1
			}
			offset0 = builder.endVector()
		}
		try! builder.openObject(1)
		try! builder.addPropertyOffsetToOpenObject(0, offset: offset0)
		return try! builder.closeObject()
	}
}
