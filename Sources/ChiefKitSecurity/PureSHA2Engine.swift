import ChiefKitStudioCore
import Foundation

// MARK: - Errors & Variant Descriptors

public enum CryptoCodecError: Error, LocalizedError, Equatable, Sendable {
    case invalidHexLength(Int)
    case invalidHexCharacter(UInt8, offset: Int)
    case invalidBase64Character(UInt8, offset: Int)
    case invalidBase64Padding
    case invalidBase64Length(Int)
    case merkleLeafIndexOutOfBounds(index: Int, count: Int)
    case emptyMerkleLeaves

    public var errorDescription: String? {
        switch self {
        case .invalidHexLength(let length):
            return "Hex string byte length (\(length)) must be an even number."
        case .invalidHexCharacter(let byte, let offset):
            return "Invalid hexadecimal byte 0x\(String(byte, radix: 16)) at offset \(offset)."
        case .invalidBase64Character(let byte, let offset):
            return "Invalid Base64/Base64URL byte 0x\(String(byte, radix: 16)) at offset \(offset)."
        case .invalidBase64Padding:
            return "Malformed Base64 padding sequence."
        case .invalidBase64Length(let length):
            return "Invalid unpadded Base64 length (\(length)); remainder mod 4 cannot be 1."
        case .merkleLeafIndexOutOfBounds(let index, let count):
            return "Merkle leaf index \(index) is out of range for tree with \(count) leaves."
        case .emptyMerkleLeaves:
            return "Cannot construct a SHA-2 Merkle tree from an empty leaf set."
        }
    }
}

public enum SHA2Variant: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case sha224 = "SHA-224"
    case sha256 = "SHA-256"
    case sha384 = "SHA-384"
    case sha512 = "SHA-512"
    case sha512_256 = "SHA-512/256"

    public var digestByteCount: Int {
        switch self {
        case .sha224: return 28
        case .sha256: return 32
        case .sha384: return 48
        case .sha512: return 64
        case .sha512_256: return 32
        }
    }

    public var blockByteCount: Int {
        switch self {
        case .sha224, .sha256:
            return 64
        case .sha384, .sha512, .sha512_256:
            return 128
        }
    }

    public var bitSecurityLevel: Int {
        (digestByteCount * 8) / 2
    }
}

// MARK: - Constant-Time Primitives

public enum ConstantTime {
    /// Compares two byte arrays in constant time with respect to content when lengths match.
    /// Returns false immediately if lengths differ, otherwise accumulates bitwise XOR differences.
    @inlinable
    public static func equal(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for index in 0..<lhs.count {
            diff |= lhs[index] ^ rhs[index]
        }
        return isZero(diff)
    }

    /// Compares two `Data` buffers in constant time with respect to byte values.
    public static func equal(_ lhs: Data, _ rhs: Data) -> Bool {
        equal(Array(lhs), Array(rhs))
    }

    /// Compares two UTF-8 strings (e.g., hex digests or tokens) in constant time.
    public static func equalStrings(_ lhs: String, _ rhs: String) -> Bool {
        equal(Array(lhs.utf8), Array(rhs.utf8))
    }

    /// Returns true iff `byte == 0` using branchless bit propagation.
    @inlinable
    public static func isZero(_ byte: UInt8) -> Bool {
        let wide = UInt16(byte)
        let mask = (wide &- 1) >> 8
        return (mask & 1) == 1
    }

    /// Returns true iff every byte in `bytes` is zero, without early-exit branching.
    @inlinable
    public static func isAllZero(_ bytes: [UInt8]) -> Bool {
        var acc: UInt8 = 0
        for b in bytes {
            acc |= b
        }
        return isZero(acc)
    }

    /// Branchless byte selection: returns `ifOne` when `conditionBit == 1`, `ifZero` when `conditionBit == 0`.
    @inlinable
    public static func select(conditionBit: UInt8, ifOne: UInt8, ifZero: UInt8) -> UInt8 {
        let mask = UInt8(bitPattern: Int8(0) &- Int8(bitPattern: conditionBit & 1))
        return (ifOne & mask) | (ifZero & ~mask)
    }

    /// Branchless 32-bit word selection: returns `ifOne` when `conditionBit == 1`, `ifZero` when `0`.
    @inlinable
    public static func selectWord32(conditionBit: UInt32, ifOne: UInt32, ifZero: UInt32) -> UInt32 {
        let mask = UInt32(0) &- (conditionBit & 1)
        return (ifOne & mask) | (ifZero & ~mask)
    }

    /// Branchless 64-bit word selection: returns `ifOne` when `conditionBit == 1`, `ifZero` when `0`.
    @inlinable
    public static func selectWord64(conditionBit: UInt64, ifOne: UInt64, ifZero: UInt64) -> UInt64 {
        let mask = UInt64(0) &- (conditionBit & 1)
        return (ifOne & mask) | (ifZero & ~mask)
    }
}

// MARK: - Hex & Base64URL Byte Codecs

public enum HexCodec {
    private static let lowerAlphabet: [UInt8] = Array("0123456789abcdef".utf8)
    private static let upperAlphabet: [UInt8] = Array("0123456789ABCDEF".utf8)

    public static func encode(_ bytes: [UInt8], uppercase: Bool = false) -> String {
        guard !bytes.isEmpty else { return "" }
        let table = uppercase ? upperAlphabet : lowerAlphabet
        var output = [UInt8]()
        output.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            output.append(table[Int(byte >> 4)])
            output.append(table[Int(byte & 0x0F)])
        }
        return String(decoding: output, as: UTF8.self)
    }

    public static func encode(_ data: Data, uppercase: Bool = false) -> String {
        encode(Array(data), uppercase: uppercase)
    }

    public static func decode(_ hex: String, allowSeparators: Bool = false) throws -> [UInt8] {
        var filtered = [UInt8]()
        filtered.reserveCapacity(hex.utf8.count)
        let raw = Array(hex.utf8)
        let startIndex: Int
        if raw.count >= 2 && raw[0] == 0x30 && (raw[1] == 0x78 || raw[1] == 0x58) {
            startIndex = 2
        } else {
            startIndex = 0
        }

        for idx in startIndex..<raw.count {
            let b = raw[idx]
            if allowSeparators && (b == 0x20 || b == 0x3A || b == 0x2D || b == 0x5F || b == 0x0A || b == 0x0D) {
                continue
            }
            filtered.append(b)
        }

        guard filtered.count % 2 == 0 else {
            throw CryptoCodecError.invalidHexLength(filtered.count)
        }

        var decoded = [UInt8]()
        decoded.reserveCapacity(filtered.count / 2)
        var offset = 0
        while offset < filtered.count {
            guard let hi = nibbleValue(filtered[offset]) else {
                throw CryptoCodecError.invalidHexCharacter(filtered[offset], offset: offset)
            }
            guard let lo = nibbleValue(filtered[offset + 1]) else {
                throw CryptoCodecError.invalidHexCharacter(filtered[offset + 1], offset: offset + 1)
            }
            decoded.append((hi << 4) | lo)
            offset += 2
        }
        return decoded
    }

    @inline(__always)
    private static func nibbleValue(_ ascii: UInt8) -> UInt8? {
        switch ascii {
        case 0x30...0x39:
            return ascii - 0x30
        case 0x41...0x46:
            return ascii - 0x41 + 10
        case 0x61...0x66:
            return ascii - 0x61 + 10
        default:
            return nil
        }
    }
}

public enum Base64URLCodec {
    private static let urlSafeTable: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)
    private static let standardTable: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

    public static func encode(_ bytes: [UInt8], padded: Bool = false, urlSafe: Bool = true) -> String {
        guard !bytes.isEmpty else { return "" }
        let table = urlSafe ? urlSafeTable : standardTable
        var out = [UInt8]()
        out.reserveCapacity(((bytes.count + 2) / 3) * 4)

        var idx = 0
        while idx + 3 <= bytes.count {
            let b0 = UInt32(bytes[idx])
            let b1 = UInt32(bytes[idx + 1])
            let b2 = UInt32(bytes[idx + 2])
            let triple = (b0 << 16) | (b1 << 8) | b2
            out.append(table[Int((triple >> 18) & 0x3F)])
            out.append(table[Int((triple >> 12) & 0x3F)])
            out.append(table[Int((triple >> 6) & 0x3F)])
            out.append(table[Int(triple & 0x3F)])
            idx += 3
        }

        let rem = bytes.count - idx
        if rem == 1 {
            let b0 = UInt32(bytes[idx])
            out.append(table[Int((b0 >> 2) & 0x3F)])
            out.append(table[Int((b0 & 0x03) << 4)])
            if padded {
                out.append(0x3D)
                out.append(0x3D)
            }
        } else if rem == 2 {
            let b0 = UInt32(bytes[idx])
            let b1 = UInt32(bytes[idx + 1])
            let pair = (b0 << 8) | b1
            out.append(table[Int((pair >> 10) & 0x3F)])
            out.append(table[Int((pair >> 4) & 0x3F)])
            out.append(table[Int((pair & 0x0F) << 2)])
            if padded {
                out.append(0x3D)
            }
        }

        return String(decoding: out, as: UTF8.self)
    }

    public static func encode(_ data: Data, padded: Bool = false, urlSafe: Bool = true) -> String {
        encode(Array(data), padded: padded, urlSafe: urlSafe)
    }

    public static func decode(_ encoded: String) throws -> [UInt8] {
        var cleaned = [UInt8]()
        cleaned.reserveCapacity(encoded.utf8.count)
        for b in encoded.utf8 where b != 0x20 && b != 0x0A && b != 0x0D && b != 0x09 {
            cleaned.append(b)
        }
        if cleaned.isEmpty { return [] }

        var padCount = 0
        while let last = cleaned.last, last == 0x3D {
            padCount += 1
            cleaned.removeLast()
            if padCount > 2 {
                throw CryptoCodecError.invalidBase64Padding
            }
        }

        if cleaned.contains(0x3D) {
            throw CryptoCodecError.invalidBase64Padding
        }

        let mod = cleaned.count % 4
        if mod == 1 {
            throw CryptoCodecError.invalidBase64Length(cleaned.count)
        }
        if padCount > 0 && ((cleaned.count + padCount) % 4 != 0) {
            throw CryptoCodecError.invalidBase64Padding
        }

        var sextets = [UInt8]()
        sextets.reserveCapacity(cleaned.count)
        for (offset, ascii) in cleaned.enumerated() {
            guard let val = sextetValue(ascii) else {
                throw CryptoCodecError.invalidBase64Character(ascii, offset: offset)
            }
            sextets.append(val)
        }

        var output = [UInt8]()
        output.reserveCapacity((sextets.count * 3) / 4)

        var idx = 0
        while idx + 4 <= sextets.count {
            let v = (UInt32(sextets[idx]) << 18)
                | (UInt32(sextets[idx + 1]) << 12)
                | (UInt32(sextets[idx + 2]) << 6)
                | UInt32(sextets[idx + 3])
            output.append(UInt8((v >> 16) & 0xFF))
            output.append(UInt8((v >> 8) & 0xFF))
            output.append(UInt8(v & 0xFF))
            idx += 4
        }

        let tail = sextets.count - idx
        if tail == 2 {
            let v = (UInt32(sextets[idx]) << 6) | UInt32(sextets[idx + 1])
            output.append(UInt8((v >> 4) & 0xFF))
        } else if tail == 3 {
            let v = (UInt32(sextets[idx]) << 12)
                | (UInt32(sextets[idx + 1]) << 6)
                | UInt32(sextets[idx + 2])
            output.append(UInt8((v >> 10) & 0xFF))
            output.append(UInt8((v >> 2) & 0xFF))
        }

        return output
    }

    @inline(__always)
    private static func sextetValue(_ ascii: UInt8) -> UInt8? {
        switch ascii {
        case 0x41...0x5A: return ascii - 0x41
        case 0x61...0x7A: return ascii - 0x61 + 26
        case 0x30...0x39: return ascii - 0x30 + 52
        case 0x2B, 0x2D:  return 62 // '+' or '-'
        case 0x2F, 0x5F:  return 63 // '/' or '_'
        default:          return nil
        }
    }
}

// MARK: - Digest Value Type

public struct DigestOutput: Codable, Equatable, Hashable, Sendable {
    public let variant: SHA2Variant
    public let bytes: [UInt8]

    public init(variant: SHA2Variant, bytes: [UInt8]) {
        self.variant = variant
        self.bytes = bytes
    }

    public var data: Data {
        Data(bytes)
    }

    public var hexLowercase: String {
        HexCodec.encode(bytes, uppercase: false)
    }

    public var hexUppercase: String {
        HexCodec.encode(bytes, uppercase: true)
    }

    public var base64URL: String {
        Base64URLCodec.encode(bytes, padded: false, urlSafe: true)
    }

    public func constantTimeEquals(_ other: DigestOutput) -> Bool {
        variant == other.variant && ConstantTime.equal(bytes, other.bytes)
    }

    public func constantTimeEqualsHex(_ candidateHex: String) -> Bool {
        guard let decoded = try? HexCodec.decode(candidateHex) else { return false }
        return ConstantTime.equal(bytes, decoded)
    }
}

// MARK: - FIPS 180-4 Nothing-Up-My-Sleeve Prime Root Constant Synthesizer

internal struct FIPS180ConstantsTable: Sendable {
    let h256: [UInt32]
    let h224: [UInt32]
    let k256: [UInt32]
    let h512: [UInt64]
    let h384: [UInt64]
    let k512: [UInt64]

    static let shared: FIPS180ConstantsTable = {
        let primes = generateFirstPrimes(count: 80)

        var h256 = [UInt32]()
        var h512 = [UInt64]()
        h256.reserveCapacity(8)
        h512.reserveCapacity(8)
        for idx in 0..<8 {
            let frac64 = fractionalSqrt64(prime: primes[idx])
            h512.append(frac64)
            h256.append(UInt32(frac64 >> 32))
        }

        var h224 = [UInt32]()
        var h384 = [UInt64]()
        h224.reserveCapacity(8)
        h384.reserveCapacity(8)
        for idx in 8..<16 {
            let frac64 = fractionalSqrt64(prime: primes[idx])
            h384.append(frac64)
            h224.append(UInt32(truncatingIfNeeded: frac64))
        }

        var k256 = [UInt32]()
        var k512 = [UInt64]()
        k256.reserveCapacity(64)
        k512.reserveCapacity(80)
        for idx in 0..<80 {
            let frac64 = fractionalCbrt64(prime: primes[idx])
            k512.append(frac64)
            if idx < 64 {
                k256.append(UInt32(frac64 >> 32))
            }
        }

        return FIPS180ConstantsTable(
            h256: h256,
            h224: h224,
            k256: k256,
            h512: h512,
            h384: h384,
            k512: k512
        )
    }()

    private static func generateFirstPrimes(count: Int) -> [UInt64] {
        var primes = [UInt64]()
        primes.reserveCapacity(count)
        var candidate: UInt64 = 2
        while primes.count < count {
            var isPrime = true
            for p in primes {
                if p * p > candidate { break }
                if candidate % p == 0 {
                    isPrime = false
                    break
                }
            }
            if isPrime {
                primes.append(candidate)
            }
            candidate += 1
        }
        return primes
    }

    /// Computes exact 64-bit fractional bits of sqrt(prime): floor((sqrt(p) - floor(sqrt(p))) * 2^64).
    private static func fractionalSqrt64(prime p: UInt64) -> UInt64 {
        var q: UInt64 = 1
        while (q + 1) * (q + 1) <= p {
            q += 1
        }
        let rem = p - q * q
        var f: UInt64 = 0
        for bit in stride(from: 63, through: 0, by: -1) {
            let cand = f | (UInt64(1) << bit)
            if squareFractionFits(cand: cand, q: q, rem: rem) {
                f = cand
            }
        }
        return f
    }

    /// Checks `2 * q * cand * 2^64 + cand^2 <= rem * 2^128` using exact 192-bit arithmetic.
    @inline(__always)
    private static func squareFractionFits(cand: UInt64, q: UInt64, rem: UInt64) -> Bool {
        let (fHi, fLo) = cand.multipliedFullWidth(by: cand)
        let (qfHi, qfLo) = (2 * q).multipliedFullWidth(by: cand)
        let w0 = fLo
        let (w1, carry1) = fHi.addingReportingOverflow(qfLo)
        let w2 = qfHi &+ (carry1 ? 1 : 0)
        if w2 != rem {
            return w2 < rem
        }
        return w1 == 0 && w0 == 0
    }

    /// Computes exact 64-bit fractional bits of cbrt(prime): floor((cbrt(p) - floor(cbrt(p))) * 2^64).
    private static func fractionalCbrt64(prime p: UInt64) -> UInt64 {
        var q: UInt64 = 1
        while (q + 1) * (q + 1) * (q + 1) <= p {
            q += 1
        }
        let rem = p - q * q * q
        var f: UInt64 = 0
        for bit in stride(from: 63, through: 0, by: -1) {
            let cand = f | (UInt64(1) << bit)
            if cubeFractionFits(cand: cand, q: q, rem: rem) {
                f = cand
            }
        }
        return f
    }

    /// Checks `3 * q^2 * cand * 2^128 + 3 * q * cand^2 * 2^64 + cand^3 <= rem * 2^192` in exact 256-bit math.
    @inline(__always)
    private static func cubeFractionFits(cand: UInt64, q: UInt64, rem: UInt64) -> Bool {
        let (f2Hi, f2Lo) = cand.multipliedFullWidth(by: cand)

        // Term A: cand^3 = (f2Hi * 2^64 + f2Lo) * cand
        let (p0Hi, p0Lo) = f2Lo.multipliedFullWidth(by: cand)
        let (p1Hi, p1Lo) = f2Hi.multipliedFullWidth(by: cand)
        let w0 = p0Lo
        let (a1, cA1) = p0Hi.addingReportingOverflow(p1Lo)
        let a2 = p1Hi &+ (cA1 ? 1 : 0)
        var w1 = a1
        var w2 = a2
        var w3: UInt64 = 0

        // Term B: 3 * q * cand^2 * 2^64
        let threeQ = 3 * q
        let (m0Hi, m0Lo) = f2Lo.multipliedFullWidth(by: threeQ)
        let (m1Hi, m1Lo) = f2Hi.multipliedFullWidth(by: threeQ)

        let (nw1, cB1) = w1.addingReportingOverflow(m0Lo)
        w1 = nw1
        let (mid2, cB2a) = w2.addingReportingOverflow(m0Hi)
        let (nw2, cB2b) = mid2.addingReportingOverflow(cB1 ? 1 : 0)
        let (nw2Final, cB2c) = nw2.addingReportingOverflow(m1Lo)
        w2 = nw2Final
        let carryTo3FromB = (cB2a ? UInt64(1) : 0) &+ (cB2b ? UInt64(1) : 0) &+ (cB2c ? UInt64(1) : 0)
        w3 = w3 &+ m1Hi &+ carryTo3FromB

        // Term C: 3 * q^2 * cand * 2^128
        let threeQ2 = 3 * q * q
        let (n0Hi, n0Lo) = cand.multipliedFullWidth(by: threeQ2)
        let (cw2, cC2) = w2.addingReportingOverflow(n0Lo)
        w2 = cw2
        w3 = w3 &+ n0Hi &+ (cC2 ? 1 : 0)

        if w3 != rem {
            return w3 < rem
        }
        return w2 == 0 && w1 == 0 && w0 == 0
    }
}

// MARK: - 32-bit SHA-2 Core (SHA-256 & SHA-224)

public struct SHA256Engine: Sendable, Equatable {
    private var state: [UInt32]
    private var buffer: [UInt8]
    private var totalByteCount: UInt64
    private let outputWordCount: Int

    public init() {
        self.state = FIPS180ConstantsTable.shared.h256
        self.buffer = []
        self.buffer.reserveCapacity(64)
        self.totalByteCount = 0
        self.outputWordCount = 8
    }

    internal init(initialState: [UInt32], outputWordCount: Int) {
        self.state = initialState
        self.buffer = []
        self.buffer.reserveCapacity(64)
        self.totalByteCount = 0
        self.outputWordCount = outputWordCount
    }

    public mutating func update(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        totalByteCount &+= UInt64(bytes.count)
        var offset = 0

        if !buffer.isEmpty {
            let needed = 64 - buffer.count
            if bytes.count < needed {
                buffer.append(contentsOf: bytes)
                return
            }
            buffer.append(contentsOf: bytes[0..<needed])
            compressBlock(buffer, startOffset: 0)
            buffer.removeAll(keepingCapacity: true)
            offset = needed
        }

        while offset + 64 <= bytes.count {
            compressBlock(bytes, startOffset: offset)
            offset += 64
        }

        if offset < bytes.count {
            buffer.append(contentsOf: bytes[offset..<bytes.count])
        }
    }

    public mutating func update(_ slice: ArraySlice<UInt8>) {
        update(Array(slice))
    }

    public mutating func update(_ data: Data) {
        update(Array(data))
    }

    public mutating func updateUTF8(_ string: String) {
        update(Array(string.utf8))
    }

    public func finalize() -> [UInt8] {
        var copy = self
        return copy.finalizeMutating()
    }

    public mutating func finalizeMutating() -> [UInt8] {
        let totalBits = totalByteCount &* 8
        buffer.append(0x80)
        if buffer.count > 56 {
            while buffer.count < 64 {
                buffer.append(0x00)
            }
            compressBlock(buffer, startOffset: 0)
            buffer.removeAll(keepingCapacity: true)
        }
        while buffer.count < 56 {
            buffer.append(0x00)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            buffer.append(UInt8(truncatingIfNeeded: totalBits >> shift))
        }
        compressBlock(buffer, startOffset: 0)
        buffer.removeAll(keepingCapacity: true)

        var digest = [UInt8]()
        digest.reserveCapacity(outputWordCount * 4)
        for wordIndex in 0..<outputWordCount {
            let word = state[wordIndex]
            digest.append(UInt8(truncatingIfNeeded: word >> 24))
            digest.append(UInt8(truncatingIfNeeded: word >> 16))
            digest.append(UInt8(truncatingIfNeeded: word >> 8))
            digest.append(UInt8(truncatingIfNeeded: word))
        }
        return digest
    }

    @inline(__always)
    private static func rotr32(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x >> n) | (x << (32 - n))
    }

    private mutating func compressBlock(_ bytes: [UInt8], startOffset: Int) {
        let k = FIPS180ConstantsTable.shared.k256
        var w = [UInt32](repeating: 0, count: 64)

        for i in 0..<16 {
            let j = startOffset + (i * 4)
            w[i] = (UInt32(bytes[j]) << 24)
                | (UInt32(bytes[j + 1]) << 16)
                | (UInt32(bytes[j + 2]) << 8)
                | UInt32(bytes[j + 3])
        }

        for i in 16..<64 {
            let v0 = w[i - 15]
            let s0 = Self.rotr32(v0, 7) ^ Self.rotr32(v0, 18) ^ (v0 >> 3)
            let v1 = w[i - 2]
            let s1 = Self.rotr32(v1, 17) ^ Self.rotr32(v1, 19) ^ (v1 >> 10)
            w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
        }

        var a = state[0]
        var b = state[1]
        var c = state[2]
        var d = state[3]
        var e = state[4]
        var f = state[5]
        var g = state[6]
        var h = state[7]

        for i in 0..<64 {
            let bigSigma1 = Self.rotr32(e, 6) ^ Self.rotr32(e, 11) ^ Self.rotr32(e, 25)
            let ch = (e & f) ^ ((~e) & g)
            let temp1 = h &+ bigSigma1 &+ ch &+ k[i] &+ w[i]
            let bigSigma0 = Self.rotr32(a, 2) ^ Self.rotr32(a, 13) ^ Self.rotr32(a, 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = bigSigma0 &+ maj

            h = g
            g = f
            f = e
            e = d &+ temp1
            d = c
            c = b
            b = a
            a = temp1 &+ temp2
        }

        state[0] &+= a
        state[1] &+= b
        state[2] &+= c
        state[3] &+= d
        state[4] &+= e
        state[5] &+= f
        state[6] &+= g
        state[7] &+= h
    }

    // MARK: One-Shot Convenience APIs

    public static func hash(_ bytes: [UInt8]) -> [UInt8] {
        var engine = SHA256Engine()
        engine.update(bytes)
        return engine.finalizeMutating()
    }

    public static func hash(data: Data) -> [UInt8] {
        hash(Array(data))
    }

    public static func hashUTF8(_ text: String) -> [UInt8] {
        hash(Array(text.utf8))
    }

    public static func hash256(_ bytes: [UInt8]) -> [UInt8] {
        hash(hash(bytes))
    }

    public static func hexDigest(_ bytes: [UInt8], uppercase: Bool = false) -> String {
        HexCodec.encode(hash(bytes), uppercase: uppercase)
    }

    public static func hexDigest(_ data: Data, uppercase: Bool = false) -> String {
        HexCodec.encode(hash(data: data), uppercase: uppercase)
    }

    public static func hexDigest(_ text: String, uppercase: Bool = false) -> String {
        HexCodec.encode(hashUTF8(text), uppercase: uppercase)
    }

    public static func digestOutput(_ bytes: [UInt8]) -> DigestOutput {
        DigestOutput(variant: .sha256, bytes: hash(bytes))
    }
}

public struct SHA224Engine: Sendable, Equatable {
    private var inner: SHA256Engine

    public init() {
        self.inner = SHA256Engine(
            initialState: FIPS180ConstantsTable.shared.h224,
            outputWordCount: 7
        )
    }

    public mutating func update(_ bytes: [UInt8]) {
        inner.update(bytes)
    }

    public mutating func update(_ data: Data) {
        inner.update(data)
    }

    public mutating func updateUTF8(_ text: String) {
        inner.updateUTF8(text)
    }

    public func finalize() -> [UInt8] {
        inner.finalize()
    }

    public static func hash(_ bytes: [UInt8]) -> [UInt8] {
        var engine = SHA224Engine()
        engine.update(bytes)
        return engine.finalize()
    }

    public static func hash(data: Data) -> [UInt8] {
        hash(Array(data))
    }

    public static func hexDigest(_ bytes: [UInt8], uppercase: Bool = false) -> String {
        HexCodec.encode(hash(bytes), uppercase: uppercase)
    }

    public static func hexDigest(_ text: String, uppercase: Bool = false) -> String {
        HexCodec.encode(hash(Array(text.utf8)), uppercase: uppercase)
    }
}

// MARK: - 64-bit SHA-2 Core (SHA-512, SHA-384 & SHA-512/256)

public struct SHA512Engine: Sendable, Equatable {
    private var state: [UInt64]
    private var buffer: [UInt8]
    private var totalBytesLo: UInt64
    private var totalBytesHi: UInt64
    private let outputByteCount: Int

    public init() {
        self.state = FIPS180ConstantsTable.shared.h512
        self.buffer = []
        self.buffer.reserveCapacity(128)
        self.totalBytesLo = 0
        self.totalBytesHi = 0
        self.outputByteCount = 64
    }

    internal init(initialState: [UInt64], outputByteCount: Int) {
        self.state = initialState
        self.buffer = []
        self.buffer.reserveCapacity(128)
        self.totalBytesLo = 0
        self.totalBytesHi = 0
        self.outputByteCount = outputByteCount
    }

    public mutating func update(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        let (newLo, overflow) = totalBytesLo.addingReportingOverflow(UInt64(bytes.count))
        totalBytesLo = newLo
        if overflow {
            totalBytesHi &+= 1
        }

        var offset = 0
        if !buffer.isEmpty {
            let needed = 128 - buffer.count
            if bytes.count < needed {
                buffer.append(contentsOf: bytes)
                return
            }
            buffer.append(contentsOf: bytes[0..<needed])
            compressBlock(buffer, startOffset: 0)
            buffer.removeAll(keepingCapacity: true)
            offset = needed
        }

        while offset + 128 <= bytes.count {
            compressBlock(bytes, startOffset: offset)
            offset += 128
        }

        if offset < bytes.count {
            buffer.append(contentsOf: bytes[offset..<bytes.count])
        }
    }

    public mutating func update(_ slice: ArraySlice<UInt8>) {
        update(Array(slice))
    }

    public mutating func update(_ data: Data) {
        update(Array(data))
    }

    public mutating func updateUTF8(_ string: String) {
        update(Array(string.utf8))
    }

    public func finalize() -> [UInt8] {
        var copy = self
        return copy.finalizeMutating()
    }

    internal func currentInternalStateWords() -> [UInt64] {
        state
    }

    public mutating func finalizeMutating() -> [UInt8] {
        // 128-bit total bit length = (totalBytesHi * 2^64 + totalBytesLo) * 8
        let bitsLo = totalBytesLo << 3
        let bitsHi = (totalBytesHi << 3) | (totalBytesLo >> 61)

        buffer.append(0x80)
        if buffer.count > 112 {
            while buffer.count < 128 {
                buffer.append(0x00)
            }
            compressBlock(buffer, startOffset: 0)
            buffer.removeAll(keepingCapacity: true)
        }
        while buffer.count < 112 {
            buffer.append(0x00)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            buffer.append(UInt8(truncatingIfNeeded: bitsHi >> shift))
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            buffer.append(UInt8(truncatingIfNeeded: bitsLo >> shift))
        }
        compressBlock(buffer, startOffset: 0)
        buffer.removeAll(keepingCapacity: true)

        var fullDigest = [UInt8]()
        fullDigest.reserveCapacity(64)
        for word in state {
            for shift in stride(from: 56, through: 0, by: -8) {
                fullDigest.append(UInt8(truncatingIfNeeded: word >> shift))
            }
        }
        if outputByteCount == 64 {
            return fullDigest
        }
        return Array(fullDigest.prefix(outputByteCount))
    }

    @inline(__always)
    private static func rotr64(_ x: UInt64, _ n: UInt64) -> UInt64 {
        (x >> n) | (x << (64 - n))
    }

    private mutating func compressBlock(_ bytes: [UInt8], startOffset: Int) {
        let k = FIPS180ConstantsTable.shared.k512
        var w = [UInt64](repeating: 0, count: 80)

        for i in 0..<16 {
            let j = startOffset + (i * 8)
            var word: UInt64 = 0
            for b in 0..<8 {
                word = (word << 8) | UInt64(bytes[j + b])
            }
            w[i] = word
        }

        for i in 16..<80 {
            let v0 = w[i - 15]
            let s0 = Self.rotr64(v0, 1) ^ Self.rotr64(v0, 8) ^ (v0 >> 7)
            let v1 = w[i - 2]
            let s1 = Self.rotr64(v1, 19) ^ Self.rotr64(v1, 61) ^ (v1 >> 6)
            w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
        }

        var a = state[0]
        var b = state[1]
        var c = state[2]
        var d = state[3]
        var e = state[4]
        var f = state[5]
        var g = state[6]
        var h = state[7]

        for i in 0..<80 {
            let bigSigma1 = Self.rotr64(e, 14) ^ Self.rotr64(e, 18) ^ Self.rotr64(e, 41)
            let ch = (e & f) ^ ((~e) & g)
            let temp1 = h &+ bigSigma1 &+ ch &+ k[i] &+ w[i]
            let bigSigma0 = Self.rotr64(a, 28) ^ Self.rotr64(a, 34) ^ Self.rotr64(a, 39)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = bigSigma0 &+ maj

            h = g
            g = f
            f = e
            e = d &+ temp1
            d = c
            c = b
            b = a
            a = temp1 &+ temp2
        }

        state[0] &+= a
        state[1] &+= b
        state[2] &+= c
        state[3] &+= d
        state[4] &+= e
        state[5] &+= f
        state[6] &+= g
        state[7] &+= h
    }

    // MARK: One-Shot Convenience APIs

    public static func hash(_ bytes: [UInt8]) -> [UInt8] {
        var engine = SHA512Engine()
        engine.update(bytes)
        return engine.finalizeMutating()
    }

    public static func hash(data: Data) -> [UInt8] {
        hash(Array(data))
    }

    public static func hashUTF8(_ text: String) -> [UInt8] {
        hash(Array(text.utf8))
    }

    public static func hexDigest(_ bytes: [UInt8], uppercase: Bool = false) -> String {
        HexCodec.encode(hash(bytes), uppercase: uppercase)
    }

    public static func hexDigest(_ data: Data, uppercase: Bool = false) -> String {
        HexCodec.encode(hash(data: data), uppercase: uppercase)
    }

    public static func hexDigest(_ text: String, uppercase: Bool = false) -> String {
        HexCodec.encode(hashUTF8(text), uppercase: uppercase)
    }
}

public struct SHA384Engine: Sendable, Equatable {
    private var inner: SHA512Engine

    public init() {
        self.inner = SHA512Engine(
            initialState: FIPS180ConstantsTable.shared.h384,
            outputByteCount: 48
        )
    }

    public mutating func update(_ bytes: [UInt8]) {
        inner.update(bytes)
    }

    public mutating func update(_ data: Data) {
        inner.update(data)
    }

    public mutating func updateUTF8(_ text: String) {
        inner.updateUTF8(text)
    }

    public func finalize() -> [UInt8] {
        inner.finalize()
    }

    public static func hash(_ bytes: [UInt8]) -> [UInt8] {
        var engine = SHA384Engine()
        engine.update(bytes)
        return engine.finalize()
    }

    public static func hash(data: Data) -> [UInt8] {
        hash(Array(data))
    }

    public static func hexDigest(_ bytes: [UInt8], uppercase: Bool = false) -> String {
        HexCodec.encode(hash(bytes), uppercase: uppercase)
    }

    public static func hexDigest(_ text: String, uppercase: Bool = false) -> String {
        HexCodec.encode(hash(Array(text.utf8)), uppercase: uppercase)
    }
}

/// FIPS 180-4 Section 5.3.6 truncated 64-bit SHA-512/256 with IV derived via `H512 XOR 0xA5...A5` over `"SHA-512/256"`.
public struct SHA512_256Engine: Sendable, Equatable {
    private static let initialStateWords: [UInt64] = {
        let xored = FIPS180ConstantsTable.shared.h512.map { $0 ^ 0xA5A5_A5A5_A5A5_A5A5 }
        var ivGenerator = SHA512Engine(initialState: xored, outputByteCount: 64)
        ivGenerator.updateUTF8("SHA-512/256")
        _ = ivGenerator.finalizeMutating()
        return ivGenerator.currentInternalStateWords()
    }()

    private var inner: SHA512Engine

    public init() {
        self.inner = SHA512Engine(initialState: Self.initialStateWords, outputByteCount: 32)
    }

    public mutating func update(_ bytes: [UInt8]) {
        inner.update(bytes)
    }

    public mutating func update(_ data: Data) {
        inner.update(data)
    }

    public func finalize() -> [UInt8] {
        inner.finalize()
    }

    public static func hash(_ bytes: [UInt8]) -> [UInt8] {
        var engine = SHA512_256Engine()
        engine.update(bytes)
        return engine.finalize()
    }

    public static func hexDigest(_ bytes: [UInt8], uppercase: Bool = false) -> String {
        HexCodec.encode(hash(bytes), uppercase: uppercase)
    }
}

// MARK: - Unified SHA-2 Dispatcher & Domain-Separated Merkle Tree

public enum PureSHA2 {
    public static func hash(_ bytes: [UInt8], variant: SHA2Variant = .sha256) -> DigestOutput {
        let raw: [UInt8]
        switch variant {
        case .sha224:
            raw = SHA224Engine.hash(bytes)
        case .sha256:
            raw = SHA256Engine.hash(bytes)
        case .sha384:
            raw = SHA384Engine.hash(bytes)
        case .sha512:
            raw = SHA512Engine.hash(bytes)
        case .sha512_256:
            raw = SHA512_256Engine.hash(bytes)
        }
        return DigestOutput(variant: variant, bytes: raw)
    }

    public static func hash(data: Data, variant: SHA2Variant = .sha256) -> DigestOutput {
        hash(Array(data), variant: variant)
    }

    public static func hashUTF8(_ text: String, variant: SHA2Variant = .sha256) -> DigestOutput {
        hash(Array(text.utf8), variant: variant)
    }
}

public struct MerkleProofStep: Codable, Equatable, Hashable, Sendable {
    public let siblingHash: [UInt8]
    public let siblingIsRight: Bool

    public init(siblingHash: [UInt8], siblingIsRight: Bool) {
        self.siblingHash = siblingHash
        self.siblingIsRight = siblingIsRight
    }
}

public struct MerkleInclusionProof: Codable, Equatable, Hashable, Sendable {
    public let variant: SHA2Variant
    public let leafIndex: Int
    public let leafCount: Int
    public let steps: [MerkleProofStep]
    public let expectedRoot: [UInt8]

    public init(
        variant: SHA2Variant,
        leafIndex: Int,
        leafCount: Int,
        steps: [MerkleProofStep],
        expectedRoot: [UInt8]
    ) {
        self.variant = variant
        self.leafIndex = leafIndex
        self.leafCount = leafCount
        self.steps = steps
        self.expectedRoot = expectedRoot
    }
}

/// RFC 6962-style domain-separated binary Merkle tree (`0x00` leaf prefix, `0x01` internal node prefix)
/// immune to second-preimage leaf/node confusion attacks.
public struct SHA2MerkleTree: Codable, Equatable, Sendable {
    public let variant: SHA2Variant
    public let leafHashes: [[UInt8]]
    public let levels: [[[UInt8]]]
    public let rootHash: [UInt8]

    public init(leaves: [[UInt8]], variant: SHA2Variant = .sha256) throws {
        guard !leaves.isEmpty else {
            throw CryptoCodecError.emptyMerkleLeaves
        }
        self.variant = variant
        let hashedLeaves = leaves.map { Self.hashLeaf($0, variant: variant) }
        self.leafHashes = hashedLeaves

        var allLevels: [[[UInt8]]] = [hashedLeaves]
        var current = hashedLeaves
        while current.count > 1 {
            var nextLevel = [[UInt8]]()
            nextLevel.reserveCapacity((current.count + 1) / 2)
            var idx = 0
            while idx < current.count {
                if idx + 1 < current.count {
                    nextLevel.append(Self.hashInternal(left: current[idx], right: current[idx + 1], variant: variant))
                } else {
                    nextLevel.append(current[idx])
                }
                idx += 2
            }
            allLevels.append(nextLevel)
            current = nextLevel
        }
        self.levels = allLevels
        self.rootHash = current[0]
    }

    public var rootHex: String {
        HexCodec.encode(rootHash)
    }

    public func inclusionProof(forLeafAt index: Int) throws -> MerkleInclusionProof {
        guard index >= 0 && index < leafHashes.count else {
            throw CryptoCodecError.merkleLeafIndexOutOfBounds(index: index, count: leafHashes.count)
        }
        var steps = [MerkleProofStep]()
        var currentIndex = index
        for levelIndex in 0..<(levels.count - 1) {
            let level = levels[levelIndex]
            let isRightChild = (currentIndex % 2) == 1
            if isRightChild {
                let sibling = level[currentIndex - 1]
                steps.append(MerkleProofStep(siblingHash: sibling, siblingIsRight: false))
            } else if currentIndex + 1 < level.count {
                let sibling = level[currentIndex + 1]
                steps.append(MerkleProofStep(siblingHash: sibling, siblingIsRight: true))
            }
            currentIndex /= 2
        }
        return MerkleInclusionProof(
            variant: variant,
            leafIndex: index,
            leafCount: leafHashes.count,
            steps: steps,
            expectedRoot: rootHash
        )
    }

    public static func verify(leafPayload: [UInt8], proof: MerkleInclusionProof) -> Bool {
        var computed = hashLeaf(leafPayload, variant: proof.variant)
        for step in proof.steps {
            if step.siblingIsRight {
                computed = hashInternal(left: computed, right: step.siblingHash, variant: proof.variant)
            } else {
                computed = hashInternal(left: step.siblingHash, right: computed, variant: proof.variant)
            }
        }
        return ConstantTime.equal(computed, proof.expectedRoot)
    }

    private static func hashLeaf(_ leaf: [UInt8], variant: SHA2Variant) -> [UInt8] {
        var framed = [UInt8]()
        framed.reserveCapacity(1 + leaf.count)
        framed.append(0x00)
        framed.append(contentsOf: leaf)
        return PureSHA2.hash(framed, variant: variant).bytes
    }

    private static func hashInternal(left: [UInt8], right: [UInt8], variant: SHA2Variant) -> [UInt8] {
        var framed = [UInt8]()
        framed.reserveCapacity(1 + left.count + right.count)
        framed.append(0x01)
        framed.append(contentsOf: left)
        framed.append(contentsOf: right)
        return PureSHA2.hash(framed, variant: variant).bytes
    }
}
