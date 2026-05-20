import Foundation

public final class XXHash64 {
    private static let PR1: UInt64 = 11400714785074694791
    private static let PR2: UInt64 = 14029467366897019727
    private static let PR3: UInt64 = 1609587929392839161
    private static let PR4: UInt64 = 9650029242287828579
    private static let PR5: UInt64 = 2870177450012600261
    
    private let seed: UInt64
    private var v1: UInt64
    private var v2: UInt64
    private var v3: UInt64
    private var v4: UInt64
    
    private var buffer = Data()
    private var totalLength: UInt64 = 0
    
    public init(seed: UInt64 = 0) {
        self.seed = seed
        self.v1 = seed &+ Self.PR1 &+ Self.PR2
        self.v2 = seed &+ Self.PR2
        self.v3 = seed
        self.v4 = seed &- Self.PR1
    }
    
    @inline(__always) private static func rotl(_ x: UInt64, _ r: Int) -> UInt64 {
        return (x << r) | (x >> (64 - r))
    }
    
    @inline(__always) private static func round(_ acc: UInt64, _ input: UInt64) -> UInt64 {
        var acc = acc &+ (input &* PR2)
        acc = rotl(acc, 31)
        acc = acc &* PR1
        return acc
    }
    
    public func update(data: Data) {
        totalLength += UInt64(data.count)
        buffer.append(data)
        
        var offset = 0
        while buffer.count - offset >= 32 {
            let chunk = buffer.subdata(in: offset..<(offset + 32))
            chunk.withUnsafeBytes { ptr in
                let u64ptr = ptr.bindMemory(to: UInt64.self)
                v1 = Self.round(v1, u64ptr[0].littleEndian)
                v2 = Self.round(v2, u64ptr[1].littleEndian)
                v3 = Self.round(v3, u64ptr[2].littleEndian)
                v4 = Self.round(v4, u64ptr[3].littleEndian)
            }
            offset += 32
        }
        if offset > 0 {
            buffer = buffer.subdata(in: offset..<buffer.count)
        }
    }
    
    public func finalize() -> UInt64 {
        var h64: UInt64
        
        if totalLength >= 32 {
            h64 = Self.rotl(v1, 1) &+ Self.rotl(v2, 7) &+ Self.rotl(v3, 12) &+ Self.rotl(v4, 18)
            
            h64 = Self.mergeRound(h64, v1)
            h64 = Self.mergeRound(h64, v2)
            h64 = Self.mergeRound(h64, v3)
            h64 = Self.mergeRound(h64, v4)
        } else {
            h64 = seed &+ Self.PR5
        }
        
        h64 = h64 &+ totalLength
        
        var offset = 0
        // Обробка 8-байтових блоків
        while buffer.count - offset >= 8 {
            let val = buffer.subdata(in: offset..<(offset + 8)).withUnsafeBytes { ptr in
                ptr.load(as: UInt64.self).littleEndian
            }
            let k1 = Self.round(0, val)
            h64 = h64 ^ k1
            h64 = Self.rotl(h64, 27) &* Self.PR1 &+ Self.PR4
            offset += 8
        }
        
        // Обробка 4-байтових блоків
        if buffer.count - offset >= 4 {
            let val = buffer.subdata(in: offset..<(offset + 4)).withUnsafeBytes { ptr in
                UInt64(ptr.load(as: UInt32.self).littleEndian)
            }
            h64 = h64 ^ (val &* Self.PR1)
            h64 = Self.rotl(h64, 23) &* Self.PR2 &+ Self.PR3
            offset += 4
        }
        
        // Обробка залишкових байтів
        while buffer.count - offset > 0 {
            let val = UInt64(buffer[offset])
            h64 = h64 ^ (val &* Self.PR5)
            h64 = Self.rotl(h64, 11) &* Self.PR1
            offset += 1
        }
        
        // Avalanche
        h64 = h64 ^ (h64 >> 33)
        h64 = h64 &* Self.PR2
        h64 = h64 ^ (h64 >> 29)
        h64 = h64 &* Self.PR3
        h64 = h64 ^ (h64 >> 32)
        
        return h64
    }
    
    @inline(__always) private static func mergeRound(_ acc: UInt64, _ val: UInt64) -> UInt64 {
        let valRound = round(0, val)
        var acc = acc ^ valRound
        acc = acc &* PR1 &+ PR4
        return acc
    }
}
