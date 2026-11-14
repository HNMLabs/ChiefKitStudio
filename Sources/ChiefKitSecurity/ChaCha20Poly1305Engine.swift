import ChiefKitStudioCore
import Foundation

// MARK: - ChaCha20-Poly1305 Errors

public enum ChaChaPolyError: Error, LocalizedError, Equatable, Sendable {
    case invalidKeyLength(expected: Int, actual: Int)
    case invalidNonceLength(expected: Int, actual: Int)
    case invalidHChaChaNonceLength(expected: Int, actual: Int)
    case invalidTagLength(expected: Int, actual: Int)
    case invalidCombinedWireLength(minimum: Int, actual: Int)
    case counterOverflow
    case authenticationFailed
    case invalidStreamHeader
    case unexpectedStreamTruncation
    case invalidChunkFrameLength
    case chunkSequenceMismatch(expected: UInt64, actual: UInt64)

    public var errorDescription: String? {
        switch self {
        case .invalidKeyLength(let expected, let actual):
            return "Invalid symmetric key length: expected \(expected) bytes, got \(actual)."
        case .invalidNonceLength(let expected, let actual):
            return "Invalid AEAD nonce length: expected \(expected) bytes, got \(actual)."
        case .invalidHChaChaNonceLength(let expected, let actual):
            return "Invalid HChaCha20 input nonce length: expected \(expected) bytes, got \(actual)."
        case .invalidTagLength(let expected, let actual):
            return "Invalid Poly1305 tag length: expected \(expected) bytes, got \(actual)."
        case .invalidCombinedWireLength(let minimum, let actual):
            return "Combined sealed box length (\(actual)) is shorter than minimum \(minimum) bytes."
        case .counterOverflow:
            return "ChaCha20 32-bit block counter overflowed maximum keystream capacity."
        case .authenticationFailed:
            return "ChaCha20-Poly1305 authentication tag verification failed (ciphertext or AAD tampered)."
        case .invalidStreamHeader:
            return "Invalid ChunkedAEADStream magic header or unsupported version."
        case .unexpectedStreamTruncation:
            return "Encrypted stream ended without an authenticated final-frame marker."
        case .invalidChunkFrameLength:
            return "Malformed encrypted chunk length prefix in stream."
        case .chunkSequenceMismatch(let expected, let actual):
            return "Chunk sequence mismatch: expected frame #\(expected), encountered #\(actual)."
        }
    }
}

// MARK: - RFC 8439 ChaCha20 & HChaCha20 Core

public enum ChaCha20Engine {
    public static let keyByteCount = 32
    public static let nonceByteCount = 12
    public static let hChaChaNonceByteCount = 16
    public static let blockByteCount = 64

    // Little-endian 32-bit words of ASCII "expand 32-byte k"
    private static let sigma0: UInt32 = 0x6170_7865
    private static let sigma1: UInt32 = 0x3320_646E
    private static let sigma2: UInt32 = 0x7962_2D32
    private static let sigma3: UInt32 = 0x6B20_6574

    @inline(__always)
    public static func rotl32(_ value: UInt32, _ bits: UInt32) -> UInt32 {
        (value << bits) | (value >> (32 - bits))
    }

    @inline(__always)
    public static func quarterRound(
        _ state: inout [UInt32],
        _ a: Int,
        _ b: Int,
        _ c: Int,
        _ d: Int
    ) {
        state[a] &+= state[b]
        state[d] ^= state[a]
        state[d] = rotl32(state[d], 16)

        state[c] &+= state[d]
        state[b] ^= state[c]
        state[b] = rotl32(state[b], 12)

        state[a] &+= state[b]
        state[d] ^= state[a]
        state[d] = rotl32(state[d], 8)

        state[c] &+= state[d]
        state[b] ^= state[c]
        state[b] = rotl32(state[b], 7)
    }

    /// RFC 8439 Section 2.3 20-round ChaCha20 block function producing 64 keystream bytes.
    public static func chacha20Block(
        key: [UInt8],
        counter: UInt32,
        nonce: [UInt8]
    ) throws -> [UInt8] {
        guard key.count == keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: keyByteCount, actual: key.count)
        }
        guard nonce.count == nonceByteCount else {
            throw ChaChaPolyError.invalidNonceLength(expected: nonceByteCount, actual: nonce.count)
        }

        let initial = makeInitialState(key: key, counter: counter, nonce: nonce)
        var working = initial

        for _ in 0..<10 {
            // Column round
            quarterRound(&working, 0, 4, 8, 12)
            quarterRound(&working, 1, 5, 9, 13)
            quarterRound(&working, 2, 6, 10, 14)
            quarterRound(&working, 3, 7, 11, 15)
            // Diagonal round
            quarterRound(&working, 0, 5, 10, 15)
            quarterRound(&working, 1, 6, 11, 12)
            quarterRound(&working, 2, 7, 8, 13)
            quarterRound(&working, 3, 4, 9, 14)
        }

        var output = [UInt8](repeating: 0, count: blockByteCount)
        for wordIndex in 0..<16 {
            let sum = working[wordIndex] &+ initial[wordIndex]
            writeLE32(sum, into: &output, at: wordIndex * 4)
        }
        return output
    }

    /// XChaCha20 subkey derivation (`HChaCha20`): runs 20 ChaCha rounds on a 32-byte key and
    /// 16-byte input without feedforward addition, returning words `[0, 1, 2, 3, 12, 13, 14, 15]`.
    public static func hChaCha20(key: [UInt8], nonce16: [UInt8]) throws -> [UInt8] {
        guard key.count == keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: keyByteCount, actual: key.count)
        }
        guard nonce16.count == hChaChaNonceByteCount else {
            throw ChaChaPolyError.invalidHChaChaNonceLength(
                expected: hChaChaNonceByteCount,
                actual: nonce16.count
            )
        }

        var working = [UInt32](repeating: 0, count: 16)
        working[0] = sigma0
        working[1] = sigma1
        working[2] = sigma2
        working[3] = sigma3
        for idx in 0..<8 {
            working[4 + idx] = readLE32(key, at: idx * 4)
        }
        for idx in 0..<4 {
            working[12 + idx] = readLE32(nonce16, at: idx * 4)
        }

        for _ in 0..<10 {
            quarterRound(&working, 0, 4, 8, 12)
            quarterRound(&working, 1, 5, 9, 13)
            quarterRound(&working, 2, 6, 10, 14)
            quarterRound(&working, 3, 7, 11, 15)

            quarterRound(&working, 0, 5, 10, 15)
            quarterRound(&working, 1, 6, 11, 12)
            quarterRound(&working, 2, 7, 8, 13)
            quarterRound(&working, 3, 4, 9, 14)
        }

        var subkey = [UInt8](repeating: 0, count: 32)
        writeLE32(working[0], into: &subkey, at: 0)
        writeLE32(working[1], into: &subkey, at: 4)
        writeLE32(working[2], into: &subkey, at: 8)
        writeLE32(working[3], into: &subkey, at: 12)
        writeLE32(working[12], into: &subkey, at: 16)
        writeLE32(working[13], into: &subkey, at: 20)
        writeLE32(working[14], into: &subkey, at: 24)
        writeLE32(working[15], into: &subkey, at: 28)
        return subkey
    }

    /// RFC 8439 Section 2.4 stream encryption / decryption (`plaintext XOR keystream`).
    public static func chacha20XOR(
        input: [UInt8],
        key: [UInt8],
        initialCounter: UInt32 = 1,
        nonce: [UInt8]
    ) throws -> [UInt8] {
        guard key.count == keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: keyByteCount, actual: key.count)
        }
        guard nonce.count == nonceByteCount else {
            throw ChaChaPolyError.invalidNonceLength(expected: nonceByteCount, actual: nonce.count)
        }
        if input.isEmpty { return [] }

        let totalBlocks = UInt64((input.count + blockByteCount - 1) / blockByteCount)
        let maxRemainingBlocks = UInt64(UInt32.max) - UInt64(initialCounter) + 1
        guard totalBlocks <= maxRemainingBlocks else {
            throw ChaChaPolyError.counterOverflow
        }

        var output = [UInt8](repeating: 0, count: input.count)
        var offset = 0
        var blockCounter = initialCounter

        while offset < input.count {
            let keystream = try chacha20Block(key: key, counter: blockCounter, nonce: nonce)
            let chunkLength = min(blockByteCount, input.count - offset)
            for idx in 0..<chunkLength {
                output[offset + idx] = input[offset + idx] ^ keystream[idx]
            }
            offset += chunkLength
            if offset < input.count {
                blockCounter &+= 1
            }
        }
        return output
    }

    @inline(__always)
    private static func makeInitialState(key: [UInt8], counter: UInt32, nonce: [UInt8]) -> [UInt32] {
        var st = [UInt32](repeating: 0, count: 16)
        st[0] = sigma0
        st[1] = sigma1
        st[2] = sigma2
        st[3] = sigma3
        for idx in 0..<8 {
            st[4 + idx] = readLE32(key, at: idx * 4)
        }
        st[12] = counter
        st[13] = readLE32(nonce, at: 0)
        st[14] = readLE32(nonce, at: 4)
        st[15] = readLE32(nonce, at: 8)
        return st
    }

    @inline(__always)
    internal static func readLE32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }

    @inline(__always)
    internal static func writeLE32(_ value: UInt32, into buffer: inout [UInt8], at offset: Int) {
        buffer[offset] = UInt8(truncatingIfNeeded: value)
        buffer[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        buffer[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
        buffer[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }

    @inline(__always)
    internal static func writeLE64(_ value: UInt64, into buffer: inout [UInt8], at offset: Int) {
        for idx in 0..<8 {
            buffer[offset + idx] = UInt8(truncatingIfNeeded: value >> (idx * 8))
        }
    }
}

// MARK: - Stateful ChaCha20 Stream Cipher & Fast-Key-Erasure DRBG

public struct ChaCha20StreamCipher: Sendable {
    private let key: [UInt8]
    private let nonce: [UInt8]
    private var nextBlockCounter: UInt32
    private var keystreamBuffer: [UInt8]
    private var keystreamCursor: Int
    private var counterExhausted: Bool

    public init(key: [UInt8], nonce: [UInt8], initialCounter: UInt32 = 1) throws {
        guard key.count == ChaCha20Engine.keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: ChaCha20Engine.keyByteCount, actual: key.count)
        }
        guard nonce.count == ChaCha20Engine.nonceByteCount else {
            throw ChaChaPolyError.invalidNonceLength(expected: ChaCha20Engine.nonceByteCount, actual: nonce.count)
        }
        self.key = key
        self.nonce = nonce
        self.nextBlockCounter = initialCounter
        self.keystreamBuffer = []
        self.keystreamCursor = 0
        self.counterExhausted = false
    }

    public mutating func seek(toByteOffset byteOffset: UInt64, baseCounter: UInt32 = 1) throws {
        let blockOffset = byteOffset / 64
        let newCounter64 = UInt64(baseCounter) + blockOffset
        guard newCounter64 <= UInt64(UInt32.max) else {
            throw ChaChaPolyError.counterOverflow
        }
        let intraBlock = Int(byteOffset % 64)
        let block = try ChaCha20Engine.chacha20Block(
            key: key,
            counter: UInt32(newCounter64),
            nonce: nonce
        )
        self.keystreamBuffer = block
        self.keystreamCursor = intraBlock
        if newCounter64 == UInt64(UInt32.max) {
            self.nextBlockCounter = UInt32.max
            self.counterExhausted = true
        } else {
            self.nextBlockCounter = UInt32(newCounter64 + 1)
            self.counterExhausted = false
        }
    }

    public mutating func process(_ bytes: [UInt8]) throws -> [UInt8] {
        if bytes.isEmpty { return [] }
        var output = [UInt8](repeating: 0, count: bytes.count)

        for idx in 0..<bytes.count {
            if keystreamCursor >= keystreamBuffer.count {
                if counterExhausted {
                    throw ChaChaPolyError.counterOverflow
                }
                keystreamBuffer = try ChaCha20Engine.chacha20Block(
                    key: key,
                    counter: nextBlockCounter,
                    nonce: nonce
                )
                keystreamCursor = 0
                if nextBlockCounter == UInt32.max {
                    counterExhausted = true
                } else {
                    nextBlockCounter &+= 1
                }
            }
            output[idx] = bytes[idx] ^ keystreamBuffer[keystreamCursor]
            keystreamCursor += 1
        }
        return output
    }
}

/// Fast-key-erasure deterministic CSPRNG backed by ChaCha20 keystream ratchet,
/// plus OS `/dev/urandom` entropy collector for Linux and macOS.
public struct ChaCha20DRBG: Sendable {
    private var key: [UInt8]
    private var reseedCounter: UInt64

    public init(seedMaterial: [UInt8], personalization: [UInt8] = Array("ChiefKitSecurity.DRBG.v3".utf8)) {
        let extracted = HKDFSHA256.extract(salt: personalization, ikm: seedMaterial)
        self.key = extracted
        self.reseedCounter = 1
    }

    public static func seededFromSystemEntropy(
        additionalEntropy: [UInt8] = []
    ) -> ChaCha20DRBG {
        var pool = systemRandomBytes(count: 32)
        let nanos = UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
        var tsBytes = [UInt8](repeating: 0, count: 8)
        ChaCha20Engine.writeLE64(nanos, into: &tsBytes, at: 0)
        pool.append(contentsOf: tsBytes)
        pool.append(contentsOf: additionalEntropy)
        return ChaCha20DRBG(seedMaterial: pool)
    }

    public static func systemRandomBytes(count: Int) -> [UInt8] {
        guard count > 0 else { return [] }
        if let handle = FileHandle(forReadingAtPath: "/dev/urandom") {
            defer { try? handle.close() }
            if let data = try? handle.read(upToCount: count), data.count == count {
                return Array(data)
            }
        }
        // Fallback deterministic entropy mixer if sandbox blocks device node access
        var fallbackSeed = Array(UUID().uuidString.utf8)
        fallbackSeed.append(contentsOf: Array(UUID().uuidString.utf8))
        let expanded = (try? HKDFSHA512.deriveKey(
            ikm: fallbackSeed,
            salt: Array("ChiefKitFallbackEntropy".utf8),
            info: [],
            outputByteCount: count
        )) ?? [UInt8](repeating: 0x5A, count: count)
        return expanded
    }

    public mutating func reseed(additionalMaterial: [UInt8]) {
        var combined = key
        combined.append(contentsOf: additionalMaterial)
        key = SHA256Engine.hash(combined)
        reseedCounter &+= 1
    }

    /// Generates `count` pseudorandom bytes and immediately overwrites the internal 32-byte key
    /// with fresh keystream bytes (forward-secure fast key erasure).
    public mutating func generateBytes(count: Int) -> [UInt8] {
        guard count > 0 else { return [] }
        var nonce = [UInt8](repeating: 0, count: 12)
        ChaCha20Engine.writeLE64(reseedCounter, into: &nonce, at: 0)
        reseedCounter &+= 1

        // Block 0 ratchets the internal DRBG key for forward secrecy
        let ratchetBlock = (try? ChaCha20Engine.chacha20Block(key: key, counter: 0, nonce: nonce))
            ?? SHA512Engine.hash(key)
        let activeKey = key
        self.key = Array(ratchetBlock.prefix(32))

        var output = [UInt8]()
        output.reserveCapacity(count)
        var blockIndex: UInt32 = 1

        while output.count < count {
            if let blk = try? ChaCha20Engine.chacha20Block(key: activeKey, counter: blockIndex, nonce: nonce) {
                let needed = min(64, count - output.count)
                output.append(contentsOf: blk.prefix(needed))
            }
            if blockIndex == UInt32.max {
                nonce[8] &+= 1
                blockIndex = 1
            } else {
                blockIndex &+= 1
            }
        }
        return output
    }
}

// MARK: - RFC 8439 Poly1305 One-Time Authenticator (Exact 5-Limb Radix-2^26 Modulo 2^130 - 5)

public struct Poly1305State: Sendable {
    public static let keyByteCount = 32
    public static let tagByteCount = 16
    private static let limbMask: UInt64 = 0x03FF_FFFF

    private let r0: UInt64
    private let r1: UInt64
    private let r2: UInt64
    private let r3: UInt64
    private let r4: UInt64

    private let s1: UInt64
    private let s2: UInt64
    private let s3: UInt64
    private let s4: UInt64

    private let pad0: UInt32
    private let pad1: UInt32
    private let pad2: UInt32
    private let pad3: UInt32

    private var h0: UInt64 = 0
    private var h1: UInt64 = 0
    private var h2: UInt64 = 0
    private var h3: UInt64 = 0
    private var h4: UInt64 = 0

    private var pendingBuffer: [UInt8] = []

    public init(oneTimeKey: [UInt8]) throws {
        guard oneTimeKey.count == Self.keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: Self.keyByteCount, actual: oneTimeKey.count)
        }

        // RFC 8439 Section 2.5 clamping of `r = key[0..<16]`
        var rBytes = Array(oneTimeKey[0..<16])
        rBytes[3] &= 15
        rBytes[7] &= 15
        rBytes[11] &= 15
        rBytes[15] &= 15
        rBytes[4] &= 252
        rBytes[8] &= 252
        rBytes[12] &= 252

        let t0 = ChaCha20Engine.readLE32(rBytes, at: 0)
        let t1 = ChaCha20Engine.readLE32(rBytes, at: 4)
        let t2 = ChaCha20Engine.readLE32(rBytes, at: 8)
        let t3 = ChaCha20Engine.readLE32(rBytes, at: 12)

        let r0Val = UInt64(t0) & Self.limbMask
        let r1Val = (UInt64(t0 >> 26) | (UInt64(t1) << 6)) & Self.limbMask
        let r2Val = (UInt64(t1 >> 20) | (UInt64(t2) << 12)) & Self.limbMask
        let r3Val = (UInt64(t2 >> 14) | (UInt64(t3) << 18)) & Self.limbMask
        let r4Val = UInt64(t3 >> 8)

        self.r0 = r0Val
        self.r1 = r1Val
        self.r2 = r2Val
        self.r3 = r3Val
        self.r4 = r4Val

        self.s1 = r1Val * 5
        self.s2 = r2Val * 5
        self.s3 = r3Val * 5
        self.s4 = r4Val * 5

        self.pad0 = ChaCha20Engine.readLE32(oneTimeKey, at: 16)
        self.pad1 = ChaCha20Engine.readLE32(oneTimeKey, at: 20)
        self.pad2 = ChaCha20Engine.readLE32(oneTimeKey, at: 24)
        self.pad3 = ChaCha20Engine.readLE32(oneTimeKey, at: 28)
        self.pendingBuffer.reserveCapacity(16)
    }

    public mutating func update(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        var offset = 0

        if !pendingBuffer.isEmpty {
            let needed = 16 - pendingBuffer.count
            if bytes.count < needed {
                pendingBuffer.append(contentsOf: bytes)
                return
            }
            pendingBuffer.append(contentsOf: bytes[0..<needed])
            processFull16ByteBlock(pendingBuffer, startOffset: 0)
            pendingBuffer.removeAll(keepingCapacity: true)
            offset = needed
        }

        while offset + 16 <= bytes.count {
            processFull16ByteBlock(bytes, startOffset: offset)
            offset += 16
        }

        if offset < bytes.count {
            pendingBuffer.append(contentsOf: bytes[offset..<bytes.count])
        }
    }

    public mutating func updateZeroPaddingTo16() {
        let rem = pendingBuffer.count % 16
        if rem != 0 {
            let padZeros = [UInt8](repeating: 0, count: 16 - rem)
            update(padZeros)
        }
    }

    public func finalize() -> [UInt8] {
        var copy = self
        return copy.finalizeMutating()
    }

    public mutating func finalizeMutating() -> [UInt8] {
        if !pendingBuffer.isEmpty {
            var tailBuf = [UInt8](repeating: 0, count: 17)
            for idx in 0..<pendingBuffer.count {
                tailBuf[idx] = pendingBuffer[idx]
            }
            tailBuf[pendingBuffer.count] = 0x01
            processPadded17ByteBlock(tailBuf)
            pendingBuffer.removeAll(keepingCapacity: true)
        }

        // Complete carry propagation modulo 2^130 - 5
        var carry = h1 >> 26
        h1 &= Self.limbMask
        h2 &+= carry
        carry = h2 >> 26
        h2 &= Self.limbMask
        h3 &+= carry
        carry = h3 >> 26
        h3 &= Self.limbMask
        h4 &+= carry
        carry = h4 >> 26
        h4 &= Self.limbMask
        h0 &+= carry * 5
        carry = h0 >> 26
        h0 &= Self.limbMask
        h1 &+= carry

        // Constant-time conditional subtraction of (2^130 - 5) via g = h + 5 - 2^130
        var g0 = h0 &+ 5
        carry = g0 >> 26
        g0 &= Self.limbMask
        var g1 = h1 &+ carry
        carry = g1 >> 26
        g1 &= Self.limbMask
        var g2 = h2 &+ carry
        carry = g2 >> 26
        g2 &= Self.limbMask
        var g3 = h3 &+ carry
        carry = g3 >> 26
        g3 &= Self.limbMask
        var g4 = h4 &+ carry &- (UInt64(1) << 26)

        // mask is all-ones when g4 did NOT underflow (i.e. h >= 2^130 - 5), all-zeros otherwise
        let mask = (g4 >> 63) &- 1
        let nmask = ~mask
        g0 &= mask
        g1 &= mask
        g2 &= mask
        g3 &= mask
        g4 &= mask

        h0 = (h0 & nmask) | g0
        h1 = (h1 & nmask) | g1
        h2 = (h2 & nmask) | g2
        h3 = (h3 & nmask) | g3
        h4 = (h4 & nmask) | g4

        // Reassemble 128-bit accumulator into four 32-bit words
        let w0 = (h0 | (h1 << 26)) & 0xFFFF_FFFF
        let w1 = ((h1 >> 6) | (h2 << 20)) & 0xFFFF_FFFF
        let w2 = ((h2 >> 12) | (h3 << 14)) & 0xFFFF_FFFF
        let w3 = ((h3 >> 18) | (h4 << 8)) & 0xFFFF_FFFF

        // Add secret pad `s = key[16..<32]` modulo 2^128
        var acc = w0 &+ UInt64(pad0)
        let out0 = UInt32(truncatingIfNeeded: acc)
        acc = w1 &+ UInt64(pad1) &+ (acc >> 32)
        let out1 = UInt32(truncatingIfNeeded: acc)
        acc = w2 &+ UInt64(pad2) &+ (acc >> 32)
        let out2 = UInt32(truncatingIfNeeded: acc)
        acc = w3 &+ UInt64(pad3) &+ (acc >> 32)
        let out3 = UInt32(truncatingIfNeeded: acc)

        var tag = [UInt8](repeating: 0, count: Self.tagByteCount)
        ChaCha20Engine.writeLE32(out0, into: &tag, at: 0)
        ChaCha20Engine.writeLE32(out1, into: &tag, at: 4)
        ChaCha20Engine.writeLE32(out2, into: &tag, at: 8)
        ChaCha20Engine.writeLE32(out3, into: &tag, at: 12)
        return tag
    }

    @inline(__always)
    private mutating func processFull16ByteBlock(_ bytes: [UInt8], startOffset: Int) {
        let u0 = ChaCha20Engine.readLE32(bytes, at: startOffset)
        let u1 = ChaCha20Engine.readLE32(bytes, at: startOffset + 4)
        let u2 = ChaCha20Engine.readLE32(bytes, at: startOffset + 8)
        let u3 = ChaCha20Engine.readLE32(bytes, at: startOffset + 12)

        h0 &+= UInt64(u0) & Self.limbMask
        h1 &+= (UInt64(u0 >> 26) | (UInt64(u1) << 6)) & Self.limbMask
        h2 &+= (UInt64(u1 >> 20) | (UInt64(u2) << 12)) & Self.limbMask
        h3 &+= (UInt64(u2 >> 14) | (UInt64(u3) << 18)) & Self.limbMask
        h4 &+= UInt64(u3 >> 8) | (UInt64(1) << 24)

        multiplyAndCarryReduce()
    }

    @inline(__always)
    private mutating func processPadded17ByteBlock(_ buf17: [UInt8]) {
        let u0 = ChaCha20Engine.readLE32(buf17, at: 0)
        let u1 = ChaCha20Engine.readLE32(buf17, at: 4)
        let u2 = ChaCha20Engine.readLE32(buf17, at: 8)
        let u3 = ChaCha20Engine.readLE32(buf17, at: 12)
        let hibit = UInt64(buf17[16]) << 24

        h0 &+= UInt64(u0) & Self.limbMask
        h1 &+= (UInt64(u0 >> 26) | (UInt64(u1) << 6)) & Self.limbMask
        h2 &+= (UInt64(u1 >> 20) | (UInt64(u2) << 12)) & Self.limbMask
        h3 &+= (UInt64(u2 >> 14) | (UInt64(u3) << 18)) & Self.limbMask
        h4 &+= UInt64(u3 >> 8) | hibit

        multiplyAndCarryReduce()
    }

    @inline(__always)
    private mutating func multiplyAndCarryReduce() {
        let d0 = (h0 &* r0) &+ (h1 &* s4) &+ (h2 &* s3) &+ (h3 &* s2) &+ (h4 &* s1)
        var d1 = (h0 &* r1) &+ (h1 &* r0) &+ (h2 &* s4) &+ (h3 &* s3) &+ (h4 &* s2)
        var d2 = (h0 &* r2) &+ (h1 &* r1) &+ (h2 &* r0) &+ (h3 &* s4) &+ (h4 &* s3)
        var d3 = (h0 &* r3) &+ (h1 &* r2) &+ (h2 &* r1) &+ (h3 &* r0) &+ (h4 &* s4)
        var d4 = (h0 &* r4) &+ (h1 &* r3) &+ (h2 &* r2) &+ (h3 &* r1) &+ (h4 &* r0)

        var carry = d0 >> 26
        h0 = d0 & Self.limbMask
        d1 &+= carry
        carry = d1 >> 26
        h1 = d1 & Self.limbMask
        d2 &+= carry
        carry = d2 >> 26
        h2 = d2 & Self.limbMask
        d3 &+= carry
        carry = d3 >> 26
        h3 = d3 & Self.limbMask
        d4 &+= carry
        carry = d4 >> 26
        h4 = d4 & Self.limbMask

        h0 &+= carry * 5
        carry = h0 >> 26
        h0 &= Self.limbMask
        h1 &+= carry
    }
}

public enum Poly1305MAC {
    public static func poly1305MAC(message: [UInt8], key: [UInt8]) throws -> [UInt8] {
        var state = try Poly1305State(oneTimeKey: key)
        state.update(message)
        return state.finalizeMutating()
    }

    public static func verify(tag: [UInt8], message: [UInt8], key: [UInt8]) throws -> Bool {
        guard tag.count == Poly1305State.tagByteCount else {
            throw ChaChaPolyError.invalidTagLength(expected: Poly1305State.tagByteCount, actual: tag.count)
        }
        let expected = try poly1305MAC(message: message, key: key)
        return ConstantTime.equal(expected, tag)
    }
}

// MARK: - SealedBox & RFC 8439 ChaCha20-Poly1305 AEAD

public struct SealedBox: Codable, Equatable, Hashable, Sendable {
    public let nonce: [UInt8]
    public let ciphertext: [UInt8]
    public let tag: [UInt8]

    public init(nonce: [UInt8], ciphertext: [UInt8], tag: [UInt8]) throws {
        guard nonce.count == ChaCha20Engine.nonceByteCount
            || nonce.count == XChaCha20Poly1305AEAD.nonceByteCount
        else {
            throw ChaChaPolyError.invalidNonceLength(
                expected: ChaCha20Engine.nonceByteCount,
                actual: nonce.count
            )
        }
        guard tag.count == Poly1305State.tagByteCount else {
            throw ChaChaPolyError.invalidTagLength(
                expected: Poly1305State.tagByteCount,
                actual: tag.count
            )
        }
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
    }

    public init(combinedWireBytes: [UInt8], nonceByteCount: Int = 12) throws {
        let minLength = nonceByteCount + Poly1305State.tagByteCount
        guard combinedWireBytes.count >= minLength else {
            throw ChaChaPolyError.invalidCombinedWireLength(
                minimum: minLength,
                actual: combinedWireBytes.count
            )
        }
        let extractedNonce = Array(combinedWireBytes[0..<nonceByteCount])
        let tagStart = combinedWireBytes.count - Poly1305State.tagByteCount
        let extractedCiphertext = Array(combinedWireBytes[nonceByteCount..<tagStart])
        let extractedTag = Array(combinedWireBytes[tagStart..<combinedWireBytes.count])
        try self.init(nonce: extractedNonce, ciphertext: extractedCiphertext, tag: extractedTag)
    }

    public func combinedWireBytes() -> [UInt8] {
        var wire = [UInt8]()
        wire.reserveCapacity(nonce.count + ciphertext.count + tag.count)
        wire.append(contentsOf: nonce)
        wire.append(contentsOf: ciphertext)
        wire.append(contentsOf: tag)
        return wire
    }

    public var combinedData: Data {
        Data(combinedWireBytes())
    }
}

public enum ChaCha20Poly1305AEAD {
    public static let keyByteCount = 32
    public static let nonceByteCount = 12
    public static let tagByteCount = 16

    /// Generates the 32-byte Poly1305 one-time key using ChaCha20 block counter `0` per RFC 8439 Section 2.6.
    public static func poly1305KeyGen(key: [UInt8], nonce: [UInt8]) throws -> [UInt8] {
        let block0 = try ChaCha20Engine.chacha20Block(key: key, counter: 0, nonce: nonce)
        return Array(block0[0..<32])
    }

    /// RFC 8439 Section 2.8 AEAD Seal: encrypts `plaintext` starting at counter `1` and authenticates
    /// `aad || pad16(aad) || ciphertext || pad16(ciphertext) || le64(aad.count) || le64(ciphertext.count)`.
    public static func seal(
        plaintext: [UInt8],
        key: [UInt8],
        nonce: [UInt8],
        aad: [UInt8] = []
    ) throws -> SealedBox {
        guard key.count == keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: keyByteCount, actual: key.count)
        }
        guard nonce.count == nonceByteCount else {
            throw ChaChaPolyError.invalidNonceLength(expected: nonceByteCount, actual: nonce.count)
        }

        let otk = try poly1305KeyGen(key: key, nonce: nonce)
        let ciphertext = try ChaCha20Engine.chacha20XOR(
            input: plaintext,
            key: key,
            initialCounter: 1,
            nonce: nonce
        )
        let tag = try computeAEADTag(aad: aad, ciphertext: ciphertext, oneTimeKey: otk)
        return try SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
    }

    /// RFC 8439 Section 2.8 AEAD Open: verifies the Poly1305 authentication tag in constant time BEFORE
    /// decrypting a single byte of ciphertext.
    public static func open(
        sealedBox: SealedBox,
        key: [UInt8],
        aad: [UInt8] = []
    ) throws -> [UInt8] {
        guard key.count == keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: keyByteCount, actual: key.count)
        }
        guard sealedBox.nonce.count == nonceByteCount else {
            throw ChaChaPolyError.invalidNonceLength(expected: nonceByteCount, actual: sealedBox.nonce.count)
        }
        guard sealedBox.tag.count == tagByteCount else {
            throw ChaChaPolyError.invalidTagLength(expected: tagByteCount, actual: sealedBox.tag.count)
        }

        let otk = try poly1305KeyGen(key: key, nonce: sealedBox.nonce)
        let expectedTag = try computeAEADTag(aad: aad, ciphertext: sealedBox.ciphertext, oneTimeKey: otk)
        guard ConstantTime.equal(expectedTag, sealedBox.tag) else {
            throw ChaChaPolyError.authenticationFailed
        }

        return try ChaCha20Engine.chacha20XOR(
            input: sealedBox.ciphertext,
            key: key,
            initialCounter: 1,
            nonce: sealedBox.nonce
        )
    }

    public static func sealData(
        plaintext: Data,
        key: Data,
        nonce: Data,
        aad: Data = Data()
    ) throws -> SealedBox {
        try seal(
            plaintext: Array(plaintext),
            key: Array(key),
            nonce: Array(nonce),
            aad: Array(aad)
        )
    }

    public static func openData(
        sealedBox: SealedBox,
        key: Data,
        aad: Data = Data()
    ) throws -> Data {
        let plain = try open(sealedBox: sealedBox, key: Array(key), aad: Array(aad))
        return Data(plain)
    }

    internal static func computeAEADTag(
        aad: [UInt8],
        ciphertext: [UInt8],
        oneTimeKey: [UInt8]
    ) throws -> [UInt8] {
        var poly = try Poly1305State(oneTimeKey: oneTimeKey)
        poly.update(aad)
        poly.updateZeroPaddingTo16()
        poly.update(ciphertext)
        poly.updateZeroPaddingTo16()

        var lengthsFooter = [UInt8](repeating: 0, count: 16)
        ChaCha20Engine.writeLE64(UInt64(aad.count), into: &lengthsFooter, at: 0)
        ChaCha20Engine.writeLE64(UInt64(ciphertext.count), into: &lengthsFooter, at: 8)
        poly.update(lengthsFooter)

        return poly.finalizeMutating()
    }
}

// MARK: - XChaCha20-Poly1305 Extended-Nonce (192-bit / 24-byte Nonce) AEAD

public enum XChaCha20Poly1305AEAD {
    public static let keyByteCount = 32
    public static let nonceByteCount = 24
    public static let tagByteCount = 16

    /// Encrypts and authenticates using a 24-byte random-safe nonce via `HChaCha20(key, nonce[0..<16])`
    /// and standard `ChaCha20Poly1305` on `[0, 0, 0, 0] || nonce[16..<24]`.
    public static func seal(
        plaintext: [UInt8],
        key: [UInt8],
        nonce24: [UInt8],
        aad: [UInt8] = []
    ) throws -> SealedBox {
        guard key.count == keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: keyByteCount, actual: key.count)
        }
        guard nonce24.count == nonceByteCount else {
            throw ChaChaPolyError.invalidNonceLength(expected: nonceByteCount, actual: nonce24.count)
        }

        let subkey = try ChaCha20Engine.hChaCha20(key: key, nonce16: Array(nonce24[0..<16]))
        var innerNonce = [UInt8](repeating: 0, count: 12)
        for idx in 0..<8 {
            innerNonce[4 + idx] = nonce24[16 + idx]
        }

        let innerBox = try ChaCha20Poly1305AEAD.seal(
            plaintext: plaintext,
            key: subkey,
            nonce: innerNonce,
            aad: aad
        )
        return try SealedBox(nonce: nonce24, ciphertext: innerBox.ciphertext, tag: innerBox.tag)
    }

    public static func open(
        sealedBox: SealedBox,
        key: [UInt8],
        aad: [UInt8] = []
    ) throws -> [UInt8] {
        guard key.count == keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: keyByteCount, actual: key.count)
        }
        guard sealedBox.nonce.count == nonceByteCount else {
            throw ChaChaPolyError.invalidNonceLength(expected: nonceByteCount, actual: sealedBox.nonce.count)
        }

        let subkey = try ChaCha20Engine.hChaCha20(key: key, nonce16: Array(sealedBox.nonce[0..<16]))
        var innerNonce = [UInt8](repeating: 0, count: 12)
        for idx in 0..<8 {
            innerNonce[4 + idx] = sealedBox.nonce[16 + idx]
        }

        let innerBox = try SealedBox(
            nonce: innerNonce,
            ciphertext: sealedBox.ciphertext,
            tag: sealedBox.tag
        )
        return try ChaCha20Poly1305AEAD.open(sealedBox: innerBox, key: subkey, aad: aad)
    }
}

// MARK: - Authenticated Chunked AEAD Stream Framing (Truncation & Reorder Resistant)

/// Encrypts arbitrarily large payloads in bounded chunks where each chunk derives a unique 12-byte
/// nonce (`streamNoncePrefix4 || le64(chunkIndex)`) and binds a finality marker byte (`0x00` intermediate,
/// `0xFF` terminal) into the AEAD AAD so chunk reordering, dropping, or truncation is cryptographically impossible.
public enum ChunkedAEADStream {
    private static let magicBytes: [UInt8] = [0x43, 0x4B, 0x53, 0x33] // "CKS3"

    public static func encryptStream(
        plaintext: [UInt8],
        key: [UInt8],
        streamPrefix4: [UInt8],
        chunkByteSize: Int = 16_384,
        streamAAD: [UInt8] = []
    ) throws -> [UInt8] {
        guard key.count == ChaCha20Poly1305AEAD.keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: ChaCha20Poly1305AEAD.keyByteCount, actual: key.count)
        }
        guard streamPrefix4.count == 4 else {
            throw ChaChaPolyError.invalidNonceLength(expected: 4, actual: streamPrefix4.count)
        }
        let effectiveChunkSize = max(64, chunkByteSize)

        var output = [UInt8]()
        output.append(contentsOf: magicBytes)
        output.append(contentsOf: streamPrefix4)

        if plaintext.isEmpty {
            let framed = try encryptSingleFrame(
                slice: [],
                key: key,
                streamPrefix4: streamPrefix4,
                chunkIndex: 0,
                isFinal: true,
                streamAAD: streamAAD
            )
            output.append(contentsOf: framed)
            return output
        }

        var offset = 0
        var chunkIndex: UInt64 = 0
        while offset < plaintext.count {
            let end = min(plaintext.count, offset + effectiveChunkSize)
            let isFinal = (end == plaintext.count)
            let slice = Array(plaintext[offset..<end])
            let framed = try encryptSingleFrame(
                slice: slice,
                key: key,
                streamPrefix4: streamPrefix4,
                chunkIndex: chunkIndex,
                isFinal: isFinal,
                streamAAD: streamAAD
            )
            output.append(contentsOf: framed)
            offset = end
            chunkIndex &+= 1
        }
        return output
    }

    public static func decryptStream(
        encryptedWire: [UInt8],
        key: [UInt8],
        streamAAD: [UInt8] = []
    ) throws -> [UInt8] {
        guard key.count == ChaCha20Poly1305AEAD.keyByteCount else {
            throw ChaChaPolyError.invalidKeyLength(expected: ChaCha20Poly1305AEAD.keyByteCount, actual: key.count)
        }
        guard encryptedWire.count >= 8 else {
            throw ChaChaPolyError.invalidStreamHeader
        }
        guard Array(encryptedWire[0..<4]) == magicBytes else {
            throw ChaChaPolyError.invalidStreamHeader
        }

        let streamPrefix4 = Array(encryptedWire[4..<8])
        var cursor = 8
        var expectedIndex: UInt64 = 0
        var sawFinalFrame = false
        var plaintext = [UInt8]()

        while cursor < encryptedWire.count {
            guard !sawFinalFrame else {
                throw ChaChaPolyError.invalidChunkFrameLength
            }
            // Frame header: [isFinal: 1B][chunkIndexLE: 8B][ciphertextLenLE: 4B][ciphertext][tag: 16B]
            guard cursor + 13 <= encryptedWire.count else {
                throw ChaChaPolyError.invalidChunkFrameLength
            }
            let finalityByte = encryptedWire[cursor]
            let isFinal = (finalityByte == 0xFF)
            guard finalityByte == 0x00 || finalityByte == 0xFF else {
                throw ChaChaPolyError.invalidChunkFrameLength
            }

            var actualIndex: UInt64 = 0
            for idx in 0..<8 {
                actualIndex |= UInt64(encryptedWire[cursor + 1 + idx]) << (idx * 8)
            }
            guard actualIndex == expectedIndex else {
                throw ChaChaPolyError.chunkSequenceMismatch(expected: expectedIndex, actual: actualIndex)
            }

            let ctLength = Int(ChaCha20Engine.readLE32(encryptedWire, at: cursor + 9))
            let frameEnd = cursor + 13 + ctLength + 16
            guard ctLength >= 0 && frameEnd <= encryptedWire.count else {
                throw ChaChaPolyError.invalidChunkFrameLength
            }

            let ctBytes = Array(encryptedWire[(cursor + 13)..<(cursor + 13 + ctLength)])
            let tagBytes = Array(encryptedWire[(cursor + 13 + ctLength)..<frameEnd])

            let nonce = makeChunkNonce(prefix4: streamPrefix4, chunkIndex: expectedIndex)
            let frameAAD = makeChunkAAD(
                streamAAD: streamAAD,
                chunkIndex: expectedIndex,
                finalityByte: finalityByte
            )
            let box = try SealedBox(nonce: nonce, ciphertext: ctBytes, tag: tagBytes)
            let chunkPlain = try ChaCha20Poly1305AEAD.open(sealedBox: box, key: key, aad: frameAAD)
            plaintext.append(contentsOf: chunkPlain)

            cursor = frameEnd
            expectedIndex &+= 1
            if isFinal {
                sawFinalFrame = true
            }
        }

        guard sawFinalFrame else {
            throw ChaChaPolyError.unexpectedStreamTruncation
        }
        return plaintext
    }

    private static func encryptSingleFrame(
        slice: [UInt8],
        key: [UInt8],
        streamPrefix4: [UInt8],
        chunkIndex: UInt64,
        isFinal: Bool,
        streamAAD: [UInt8]
    ) throws -> [UInt8] {
        let finalityByte: UInt8 = isFinal ? 0xFF : 0x00
        let nonce = makeChunkNonce(prefix4: streamPrefix4, chunkIndex: chunkIndex)
        let frameAAD = makeChunkAAD(streamAAD: streamAAD, chunkIndex: chunkIndex, finalityByte: finalityByte)
        let box = try ChaCha20Poly1305AEAD.seal(plaintext: slice, key: key, nonce: nonce, aad: frameAAD)

        var frame = [UInt8](repeating: 0, count: 13)
        frame[0] = finalityByte
        ChaCha20Engine.writeLE64(chunkIndex, into: &frame, at: 1)
        ChaCha20Engine.writeLE32(UInt32(box.ciphertext.count), into: &frame, at: 9)
        frame.append(contentsOf: box.ciphertext)
        frame.append(contentsOf: box.tag)
        return frame
    }

    private static func makeChunkNonce(prefix4: [UInt8], chunkIndex: UInt64) -> [UInt8] {
        var nonce = [UInt8](repeating: 0, count: 12)
        for idx in 0..<4 {
            nonce[idx] = prefix4[idx]
        }
        ChaCha20Engine.writeLE64(chunkIndex, into: &nonce, at: 4)
        return nonce
    }

    private static func makeChunkAAD(
        streamAAD: [UInt8],
        chunkIndex: UInt64,
        finalityByte: UInt8
    ) -> [UInt8] {
        var aad = [UInt8]()
        aad.reserveCapacity(streamAAD.count + 9)
        aad.append(contentsOf: streamAAD)
        var idxBuf = [UInt8](repeating: 0, count: 8)
        ChaCha20Engine.writeLE64(chunkIndex, into: &idxBuf, at: 0)
        aad.append(contentsOf: idxBuf)
        aad.append(finalityByte)
        return aad
    }
}
