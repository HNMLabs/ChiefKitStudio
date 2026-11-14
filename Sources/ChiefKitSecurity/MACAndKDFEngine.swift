import ChiefKitStudioCore
import Foundation

// MARK: - KDF & OTP Errors

public enum KDFAndMACError: Error, LocalizedError, Equatable, Sendable {
    case invalidHKDFOutputLength(requested: Int, maxAllowed: Int)
    case invalidHKDFPseudorandomKeyLength(actual: Int, minimum: Int)
    case invalidPBKDF2IterationCount(Int)
    case invalidPBKDF2OutputLength(Int)
    case emptyPBKDF2Salt
    case invalidOTPDigitCount(Int)
    case invalidOTPPeriodSeconds(Int)
    case invalidBase32Character(UInt8, offset: Int)
    case malformedCredentialString(String)
    case malformedOTPAuthURI(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHKDFOutputLength(let requested, let maxAllowed):
            return "HKDF output length (\(requested)) must be between 0 and \(maxAllowed) bytes."
        case .invalidHKDFPseudorandomKeyLength(let actual, let minimum):
            return "HKDF pseudorandom key length (\(actual)) must be at least \(minimum) bytes."
        case .invalidPBKDF2IterationCount(let count):
            return "PBKDF2 iteration count (\(count)) must be >= 1."
        case .invalidPBKDF2OutputLength(let length):
            return "PBKDF2 derived key length (\(length)) must be >= 1."
        case .emptyPBKDF2Salt:
            return "PBKDF2 salt must contain at least 1 byte."
        case .invalidOTPDigitCount(let digits):
            return "OTP digit count (\(digits)) must be 6, 7, or 8."
        case .invalidOTPPeriodSeconds(let period):
            return "TOTP period (\(period)s) must be greater than zero."
        case .invalidBase32Character(let byte, let offset):
            return "Invalid RFC 4648 Base32 byte 0x\(String(byte, radix: 16)) at offset \(offset)."
        case .malformedCredentialString(let reason):
            return "Malformed PBKDF2 credential record: \(reason)"
        case .malformedOTPAuthURI(let reason):
            return "Malformed otpauth URI: \(reason)"
        }
    }
}

public enum PseudorandomFunctionVariant: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case hmacSHA256 = "HMAC-SHA256"
    case hmacSHA384 = "HMAC-SHA384"
    case hmacSHA512 = "HMAC-SHA512"

    public var digestByteCount: Int {
        switch self {
        case .hmacSHA256: return 32
        case .hmacSHA384: return 48
        case .hmacSHA512: return 64
        }
    }

    public var blockByteCount: Int {
        switch self {
        case .hmacSHA256: return 64
        case .hmacSHA384, .hmacSHA512: return 128
        }
    }
}

// MARK: - RFC 2104 HMAC-SHA256, HMAC-SHA384 & HMAC-SHA512

public struct HMACSHA256: Sendable, Equatable {
    public static let blockByteCount = 64
    public static let tagByteCount = 32

    private let outerBase: SHA256Engine
    private var innerHasher: SHA256Engine

    /// Precomputes and compresses the 64-byte `ipad` and `opad` blocks once so cloning this struct
    /// reuses mid-state SHA-256 blocks directly (dramatically accelerating PBKDF2/HKDF loops).
    public init(key: [UInt8]) {
        let normalizedKey: [UInt8]
        if key.count > Self.blockByteCount {
            normalizedKey = SHA256Engine.hash(key)
        } else {
            normalizedKey = key
        }

        var ipad = [UInt8](repeating: 0x36, count: Self.blockByteCount)
        var opad = [UInt8](repeating: 0x5C, count: Self.blockByteCount)
        for idx in 0..<normalizedKey.count {
            ipad[idx] ^= normalizedKey[idx]
            opad[idx] ^= normalizedKey[idx]
        }

        var inner = SHA256Engine()
        inner.update(ipad)
        var outer = SHA256Engine()
        outer.update(opad)

        self.innerHasher = inner
        self.outerBase = outer
    }

    public init(keyData: Data) {
        self.init(key: Array(keyData))
    }

    public init(keyUTF8: String) {
        self.init(key: Array(keyUTF8.utf8))
    }

    public mutating func update(_ bytes: [UInt8]) {
        innerHasher.update(bytes)
    }

    public mutating func update(_ data: Data) {
        innerHasher.update(data)
    }

    public mutating func updateUTF8(_ string: String) {
        innerHasher.updateUTF8(string)
    }

    public func finalize() -> [UInt8] {
        let innerDigest = innerHasher.finalize()
        var outer = outerBase
        outer.update(innerDigest)
        return outer.finalizeMutating()
    }

    public func mac(for message: [UInt8]) -> [UInt8] {
        var copy = self
        copy.update(message)
        return copy.finalize()
    }

    public static func authenticate(message: [UInt8], key: [UInt8]) -> [UInt8] {
        var hmac = HMACSHA256(key: key)
        hmac.update(message)
        return hmac.finalize()
    }

    public static func authenticate(data: Data, key: Data) -> Data {
        Data(authenticate(message: Array(data), key: Array(key)))
    }

    public static func hexMAC(message: String, key: String, uppercase: Bool = false) -> String {
        let tag = authenticate(message: Array(message.utf8), key: Array(key.utf8))
        return HexCodec.encode(tag, uppercase: uppercase)
    }

    public static func verify(tag: [UInt8], message: [UInt8], key: [UInt8]) -> Bool {
        guard tag.count == tagByteCount else { return false }
        let computed = authenticate(message: message, key: key)
        return ConstantTime.equal(computed, tag)
    }

    public static func verifyTruncated(
        tag: [UInt8],
        minimumTagBytes: Int = 16,
        message: [UInt8],
        key: [UInt8]
    ) -> Bool {
        guard tag.count >= minimumTagBytes && tag.count <= tagByteCount else { return false }
        let computed = Array(authenticate(message: message, key: key).prefix(tag.count))
        return ConstantTime.equal(computed, tag)
    }
}

public struct HMACSHA384: Sendable, Equatable {
    public static let blockByteCount = 128
    public static let tagByteCount = 48

    private let outerBase: SHA384Engine
    private var innerHasher: SHA384Engine

    public init(key: [UInt8]) {
        let normalizedKey: [UInt8]
        if key.count > Self.blockByteCount {
            normalizedKey = SHA384Engine.hash(key)
        } else {
            normalizedKey = key
        }

        var ipad = [UInt8](repeating: 0x36, count: Self.blockByteCount)
        var opad = [UInt8](repeating: 0x5C, count: Self.blockByteCount)
        for idx in 0..<normalizedKey.count {
            ipad[idx] ^= normalizedKey[idx]
            opad[idx] ^= normalizedKey[idx]
        }

        var inner = SHA384Engine()
        inner.update(ipad)
        var outer = SHA384Engine()
        outer.update(opad)

        self.innerHasher = inner
        self.outerBase = outer
    }

    public mutating func update(_ bytes: [UInt8]) {
        innerHasher.update(bytes)
    }

    public func finalize() -> [UInt8] {
        let innerDigest = innerHasher.finalize()
        var outer = outerBase
        outer.update(innerDigest)
        return outer.finalize()
    }

    public func mac(for message: [UInt8]) -> [UInt8] {
        var copy = self
        copy.update(message)
        return copy.finalize()
    }

    public static func authenticate(message: [UInt8], key: [UInt8]) -> [UInt8] {
        var hmac = HMACSHA384(key: key)
        hmac.update(message)
        return hmac.finalize()
    }

    public static func verify(tag: [UInt8], message: [UInt8], key: [UInt8]) -> Bool {
        guard tag.count == tagByteCount else { return false }
        let computed = authenticate(message: message, key: key)
        return ConstantTime.equal(computed, tag)
    }
}

public struct HMACSHA512: Sendable, Equatable {
    public static let blockByteCount = 128
    public static let tagByteCount = 64

    private let outerBase: SHA512Engine
    private var innerHasher: SHA512Engine

    public init(key: [UInt8]) {
        let normalizedKey: [UInt8]
        if key.count > Self.blockByteCount {
            normalizedKey = SHA512Engine.hash(key)
        } else {
            normalizedKey = key
        }

        var ipad = [UInt8](repeating: 0x36, count: Self.blockByteCount)
        var opad = [UInt8](repeating: 0x5C, count: Self.blockByteCount)
        for idx in 0..<normalizedKey.count {
            ipad[idx] ^= normalizedKey[idx]
            opad[idx] ^= normalizedKey[idx]
        }

        var inner = SHA512Engine()
        inner.update(ipad)
        var outer = SHA512Engine()
        outer.update(opad)

        self.innerHasher = inner
        self.outerBase = outer
    }

    public init(keyData: Data) {
        self.init(key: Array(keyData))
    }

    public init(keyUTF8: String) {
        self.init(key: Array(keyUTF8.utf8))
    }

    public mutating func update(_ bytes: [UInt8]) {
        innerHasher.update(bytes)
    }

    public mutating func update(_ data: Data) {
        innerHasher.update(data)
    }

    public mutating func updateUTF8(_ string: String) {
        innerHasher.updateUTF8(string)
    }

    public func finalize() -> [UInt8] {
        let innerDigest = innerHasher.finalize()
        var outer = outerBase
        outer.update(innerDigest)
        return outer.finalizeMutating()
    }

    public func mac(for message: [UInt8]) -> [UInt8] {
        var copy = self
        copy.update(message)
        return copy.finalize()
    }

    public static func authenticate(message: [UInt8], key: [UInt8]) -> [UInt8] {
        var hmac = HMACSHA512(key: key)
        hmac.update(message)
        return hmac.finalize()
    }

    public static func authenticate(data: Data, key: Data) -> Data {
        Data(authenticate(message: Array(data), key: Array(key)))
    }

    public static func hexMAC(message: String, key: String, uppercase: Bool = false) -> String {
        let tag = authenticate(message: Array(message.utf8), key: Array(key.utf8))
        return HexCodec.encode(tag, uppercase: uppercase)
    }

    public static func verify(tag: [UInt8], message: [UInt8], key: [UInt8]) -> Bool {
        guard tag.count == tagByteCount else { return false }
        let computed = authenticate(message: message, key: key)
        return ConstantTime.equal(computed, tag)
    }
}

public enum PureHMAC {
    public static func authenticate(
        message: [UInt8],
        key: [UInt8],
        prf: PseudorandomFunctionVariant = .hmacSHA256
    ) -> [UInt8] {
        switch prf {
        case .hmacSHA256:
            return HMACSHA256.authenticate(message: message, key: key)
        case .hmacSHA384:
            return HMACSHA384.authenticate(message: message, key: key)
        case .hmacSHA512:
            return HMACSHA512.authenticate(message: message, key: key)
        }
    }

    public static func verify(
        tag: [UInt8],
        message: [UInt8],
        key: [UInt8],
        prf: PseudorandomFunctionVariant = .hmacSHA256
    ) -> Bool {
        let computed = authenticate(message: message, key: key, prf: prf)
        return ConstantTime.equal(computed, tag)
    }
}

// MARK: - RFC 5869 HKDF-SHA256 & HKDF-SHA512

public enum HKDFSHA256 {
    public static let hashByteCount = 32
    public static let maxOutputByteCount = 255 * 32

    public static func extract(salt: [UInt8]? = nil, ikm: [UInt8]) -> [UInt8] {
        let effectiveSalt: [UInt8]
        if let salt, !salt.isEmpty {
            effectiveSalt = salt
        } else {
            effectiveSalt = [UInt8](repeating: 0, count: hashByteCount)
        }
        return HMACSHA256.authenticate(message: ikm, key: effectiveSalt)
    }

    public static func expand(
        prk: [UInt8],
        info: [UInt8] = [],
        outputByteCount: Int
    ) throws -> [UInt8] {
        guard prk.count >= hashByteCount else {
            throw KDFAndMACError.invalidHKDFPseudorandomKeyLength(actual: prk.count, minimum: hashByteCount)
        }
        guard outputByteCount >= 0 && outputByteCount <= maxOutputByteCount else {
            throw KDFAndMACError.invalidHKDFOutputLength(requested: outputByteCount, maxAllowed: maxOutputByteCount)
        }
        if outputByteCount == 0 { return [] }

        let baseMAC = HMACSHA256(key: prk)
        let blockCount = (outputByteCount + hashByteCount - 1) / hashByteCount
        var okm = [UInt8]()
        okm.reserveCapacity(blockCount * hashByteCount)
        var previousBlock = [UInt8]()

        for blockIndex in 1...blockCount {
            var mac = baseMAC
            if !previousBlock.isEmpty {
                mac.update(previousBlock)
            }
            if !info.isEmpty {
                mac.update(info)
            }
            mac.update([UInt8(blockIndex)])
            previousBlock = mac.finalize()
            okm.append(contentsOf: previousBlock)
        }

        return Array(okm.prefix(outputByteCount))
    }

    public static func deriveKey(
        ikm: [UInt8],
        salt: [UInt8]? = nil,
        info: [UInt8] = [],
        outputByteCount: Int = 32
    ) throws -> [UInt8] {
        let prk = extract(salt: salt, ikm: ikm)
        return try expand(prk: prk, info: info, outputByteCount: outputByteCount)
    }
}

public enum HKDFSHA512 {
    public static let hashByteCount = 64
    public static let maxOutputByteCount = 255 * 64

    public static func extract(salt: [UInt8]? = nil, ikm: [UInt8]) -> [UInt8] {
        let effectiveSalt: [UInt8]
        if let salt, !salt.isEmpty {
            effectiveSalt = salt
        } else {
            effectiveSalt = [UInt8](repeating: 0, count: hashByteCount)
        }
        return HMACSHA512.authenticate(message: ikm, key: effectiveSalt)
    }

    public static func expand(
        prk: [UInt8],
        info: [UInt8] = [],
        outputByteCount: Int
    ) throws -> [UInt8] {
        guard prk.count >= hashByteCount else {
            throw KDFAndMACError.invalidHKDFPseudorandomKeyLength(actual: prk.count, minimum: hashByteCount)
        }
        guard outputByteCount >= 0 && outputByteCount <= maxOutputByteCount else {
            throw KDFAndMACError.invalidHKDFOutputLength(requested: outputByteCount, maxAllowed: maxOutputByteCount)
        }
        if outputByteCount == 0 { return [] }

        let baseMAC = HMACSHA512(key: prk)
        let blockCount = (outputByteCount + hashByteCount - 1) / hashByteCount
        var okm = [UInt8]()
        okm.reserveCapacity(blockCount * hashByteCount)
        var previousBlock = [UInt8]()

        for blockIndex in 1...blockCount {
            var mac = baseMAC
            if !previousBlock.isEmpty {
                mac.update(previousBlock)
            }
            if !info.isEmpty {
                mac.update(info)
            }
            mac.update([UInt8(blockIndex)])
            previousBlock = mac.finalize()
            okm.append(contentsOf: previousBlock)
        }

        return Array(okm.prefix(outputByteCount))
    }

    public static func deriveKey(
        ikm: [UInt8],
        salt: [UInt8]? = nil,
        info: [UInt8] = [],
        outputByteCount: Int = 64
    ) throws -> [UInt8] {
        let prk = extract(salt: salt, ikm: ikm)
        return try expand(prk: prk, info: info, outputByteCount: outputByteCount)
    }
}

/// Domain-separated labeled HKDF key hierarchy inspired by RFC 8446 `HKDF-Expand-Label`.
public struct HKDFKeyHierarchy: Sendable, Equatable {
    public let prf: PseudorandomFunctionVariant
    private let rootPRK: [UInt8]
    public let namespacePrefix: String

    public init(
        ikm: [UInt8],
        salt: [UInt8]? = nil,
        prf: PseudorandomFunctionVariant = .hmacSHA512,
        namespacePrefix: String = "ChiefKit3.0 "
    ) {
        self.prf = prf
        self.namespacePrefix = namespacePrefix
        switch prf {
        case .hmacSHA256, .hmacSHA384:
            self.rootPRK = HKDFSHA256.extract(salt: salt, ikm: ikm)
        case .hmacSHA512:
            self.rootPRK = HKDFSHA512.extract(salt: salt, ikm: ikm)
        }
    }

    public func expandLabeled(
        label: String,
        context: [UInt8] = [],
        outputByteCount: Int
    ) throws -> [UInt8] {
        let fullLabel = Array((namespacePrefix + label).utf8)
        var info = [UInt8]()
        info.reserveCapacity(2 + 1 + fullLabel.count + 1 + context.count)
        info.append(UInt8(truncatingIfNeeded: outputByteCount >> 8))
        info.append(UInt8(truncatingIfNeeded: outputByteCount))
        info.append(UInt8(truncatingIfNeeded: fullLabel.count))
        info.append(contentsOf: fullLabel)
        info.append(UInt8(truncatingIfNeeded: context.count))
        info.append(contentsOf: context)

        switch prf {
        case .hmacSHA256, .hmacSHA384:
            return try HKDFSHA256.expand(prk: rootPRK, info: info, outputByteCount: outputByteCount)
        case .hmacSHA512:
            return try HKDFSHA512.expand(prk: rootPRK, info: info, outputByteCount: outputByteCount)
        }
    }
}

// MARK: - RFC 8018 PBKDF2-HMAC-SHA256 & PBKDF2-HMAC-SHA512

public enum PBKDF2Engine {
    public static func deriveKeySHA256(
        password: [UInt8],
        salt: [UInt8],
        iterations: Int,
        derivedKeyLength: Int = 32
    ) throws -> [UInt8] {
        guard iterations >= 1 else {
            throw KDFAndMACError.invalidPBKDF2IterationCount(iterations)
        }
        guard derivedKeyLength >= 1 else {
            throw KDFAndMACError.invalidPBKDF2OutputLength(derivedKeyLength)
        }

        let prfBase = HMACSHA256(key: password)
        let hLen = HMACSHA256.tagByteCount
        let blockCount = (derivedKeyLength + hLen - 1) / hLen
        var derived = [UInt8]()
        derived.reserveCapacity(blockCount * hLen)

        for blockIndex in 1...blockCount {
            let beCounter: [UInt8] = [
                UInt8(truncatingIfNeeded: UInt32(blockIndex) >> 24),
                UInt8(truncatingIfNeeded: UInt32(blockIndex) >> 16),
                UInt8(truncatingIfNeeded: UInt32(blockIndex) >> 8),
                UInt8(truncatingIfNeeded: UInt32(blockIndex))
            ]

            var firstMAC = prfBase
            firstMAC.update(salt)
            firstMAC.update(beCounter)
            var u = firstMAC.finalize()
            var blockAcc = u

            if iterations > 1 {
                for _ in 2...iterations {
                    u = prfBase.mac(for: u)
                    for idx in 0..<hLen {
                        blockAcc[idx] ^= u[idx]
                    }
                }
            }
            derived.append(contentsOf: blockAcc)
        }

        return Array(derived.prefix(derivedKeyLength))
    }

    public static func deriveKeySHA512(
        password: [UInt8],
        salt: [UInt8],
        iterations: Int,
        derivedKeyLength: Int = 64
    ) throws -> [UInt8] {
        guard iterations >= 1 else {
            throw KDFAndMACError.invalidPBKDF2IterationCount(iterations)
        }
        guard derivedKeyLength >= 1 else {
            throw KDFAndMACError.invalidPBKDF2OutputLength(derivedKeyLength)
        }

        let prfBase = HMACSHA512(key: password)
        let hLen = HMACSHA512.tagByteCount
        let blockCount = (derivedKeyLength + hLen - 1) / hLen
        var derived = [UInt8]()
        derived.reserveCapacity(blockCount * hLen)

        for blockIndex in 1...blockCount {
            let beCounter: [UInt8] = [
                UInt8(truncatingIfNeeded: UInt32(blockIndex) >> 24),
                UInt8(truncatingIfNeeded: UInt32(blockIndex) >> 16),
                UInt8(truncatingIfNeeded: UInt32(blockIndex) >> 8),
                UInt8(truncatingIfNeeded: UInt32(blockIndex))
            ]

            var firstMAC = prfBase
            firstMAC.update(salt)
            firstMAC.update(beCounter)
            var u = firstMAC.finalize()
            var blockAcc = u

            if iterations > 1 {
                for _ in 2...iterations {
                    u = prfBase.mac(for: u)
                    for idx in 0..<hLen {
                        blockAcc[idx] ^= u[idx]
                    }
                }
            }
            derived.append(contentsOf: blockAcc)
        }

        return Array(derived.prefix(derivedKeyLength))
    }

    public static func deriveKey(
        passwordUTF8: String,
        salt: [UInt8],
        iterations: Int,
        derivedKeyLength: Int = 32,
        prf: PseudorandomFunctionVariant = .hmacSHA256
    ) throws -> [UInt8] {
        let pwd = Array(passwordUTF8.utf8)
        switch prf {
        case .hmacSHA256, .hmacSHA384:
            return try deriveKeySHA256(
                password: pwd,
                salt: salt,
                iterations: iterations,
                derivedKeyLength: derivedKeyLength
            )
        case .hmacSHA512:
            return try deriveKeySHA512(
                password: pwd,
                salt: salt,
                iterations: iterations,
                derivedKeyLength: derivedKeyLength
            )
        }
    }
}

/// Portable PHC-style PBKDF2 password credential record (`$pbkdf2-sha256$i=100000$<saltB64>$<dkB64>`).
public struct PBKDF2PasswordRecord: Codable, Equatable, Hashable, Sendable {
    public let prf: PseudorandomFunctionVariant
    public let iterations: Int
    public let salt: [UInt8]
    public let derivedVerifier: [UInt8]

    public init(
        prf: PseudorandomFunctionVariant = .hmacSHA256,
        iterations: Int,
        salt: [UInt8],
        derivedVerifier: [UInt8]
    ) {
        self.prf = prf
        self.iterations = iterations
        self.salt = salt
        self.derivedVerifier = derivedVerifier
    }

    public static func create(
        password: String,
        salt: [UInt8],
        iterations: Int = 100_000,
        prf: PseudorandomFunctionVariant = .hmacSHA256,
        verifierLength: Int = 32
    ) throws -> PBKDF2PasswordRecord {
        guard !salt.isEmpty else {
            throw KDFAndMACError.emptyPBKDF2Salt
        }
        let dk = try PBKDF2Engine.deriveKey(
            passwordUTF8: password,
            salt: salt,
            iterations: iterations,
            derivedKeyLength: verifierLength,
            prf: prf
        )
        return PBKDF2PasswordRecord(prf: prf, iterations: iterations, salt: salt, derivedVerifier: dk)
    }

    public func verify(password: String) -> Bool {
        guard let candidate = try? PBKDF2Engine.deriveKey(
            passwordUTF8: password,
            salt: salt,
            iterations: iterations,
            derivedKeyLength: derivedVerifier.count,
            prf: prf
        ) else {
            return false
        }
        return ConstantTime.equal(candidate, derivedVerifier)
    }

    public func serializedPHCString() -> String {
        let algTag = (prf == .hmacSHA512) ? "pbkdf2-sha512" : "pbkdf2-sha256"
        let saltText = Base64URLCodec.encode(salt, padded: false, urlSafe: true)
        let verifierText = Base64URLCodec.encode(derivedVerifier, padded: false, urlSafe: true)
        return "$\(algTag)$i=\(iterations)$\(saltText)$\(verifierText)"
    }

    public static func parse(phcString: String) throws -> PBKDF2PasswordRecord {
        let parts = phcString.split(separator: "$", omittingEmptySubsequences: true)
        guard parts.count == 4 else {
            throw KDFAndMACError.malformedCredentialString("Expected 4 $-delimited fields")
        }
        let prf: PseudorandomFunctionVariant
        switch parts[0] {
        case "pbkdf2-sha256":
            prf = .hmacSHA256
        case "pbkdf2-sha512":
            prf = .hmacSHA512
        default:
            throw KDFAndMACError.malformedCredentialString("Unsupported algorithm \(parts[0])")
        }
        guard parts[1].hasPrefix("i="), let iter = Int(parts[1].dropFirst(2)), iter >= 1 else {
            throw KDFAndMACError.malformedCredentialString("Invalid iteration parameter \(parts[1])")
        }
        let salt = try Base64URLCodec.decode(String(parts[2]))
        let verifier = try Base64URLCodec.decode(String(parts[3]))
        guard !salt.isEmpty, !verifier.isEmpty else {
            throw KDFAndMACError.malformedCredentialString("Salt and verifier must be non-empty")
        }
        return PBKDF2PasswordRecord(prf: prf, iterations: iter, salt: salt, derivedVerifier: verifier)
    }
}

// MARK: - RFC 4648 Base32 Codec (for OTP Provisioning Secrets)

public enum Base32Codec {
    private static let alphabet: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)

    public static func encode(_ bytes: [UInt8], padded: Bool = false) -> String {
        guard !bytes.isEmpty else { return "" }
        var output = [UInt8]()
        output.reserveCapacity(((bytes.count + 4) / 5) * 8)

        var bitBuffer: UInt64 = 0
        var bitCount = 0
        for byte in bytes {
            bitBuffer = (bitBuffer << 8) | UInt64(byte)
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                let index = Int((bitBuffer >> bitCount) & 0x1F)
                output.append(alphabet[index])
            }
        }
        if bitCount > 0 {
            let index = Int((bitBuffer << (5 - bitCount)) & 0x1F)
            output.append(alphabet[index])
        }
        if padded {
            while output.count % 8 != 0 {
                output.append(0x3D)
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    public static func decode(_ encoded: String) throws -> [UInt8] {
        var bitBuffer: UInt64 = 0
        var bitCount = 0
        var output = [UInt8]()
        output.reserveCapacity((encoded.utf8.count * 5) / 8)

        for (offset, byte) in encoded.utf8.enumerated() {
            if byte == 0x3D || byte == 0x20 || byte == 0x2D || byte == 0x0A || byte == 0x0D {
                continue
            }
            let quintet: UInt8
            switch byte {
            case 0x41...0x5A: quintet = byte - 0x41
            case 0x61...0x7A: quintet = byte - 0x61
            case 0x32...0x37: quintet = byte - 0x32 + 26
            default:
                throw KDFAndMACError.invalidBase32Character(byte, offset: offset)
            }
            bitBuffer = (bitBuffer << 5) | UInt64(quintet)
            bitCount += 5
            if bitCount >= 8 {
                bitCount -= 8
                output.append(UInt8((bitBuffer >> bitCount) & 0xFF))
            }
        }
        return output
    }
}

// MARK: - RFC 4226 HOTP & RFC 6238 TOTP Generators & Verifiers

public struct OTPVerificationMatch: Codable, Equatable, Hashable, Sendable {
    public let isValid: Bool
    public let matchedCounter: UInt64?
    public let stepOffset: Int?

    public init(isValid: Bool, matchedCounter: UInt64?, stepOffset: Int?) {
        self.isValid = isValid
        self.matchedCounter = matchedCounter
        self.stepOffset = stepOffset
    }
}

public enum HOTPGenerator {
    public static func generate(
        secret: [UInt8],
        counter: UInt64,
        digits: Int = 6,
        prf: PseudorandomFunctionVariant = .hmacSHA256
    ) throws -> String {
        guard (6...8).contains(digits) else {
            throw KDFAndMACError.invalidOTPDigitCount(digits)
        }

        var counterBytes = [UInt8](repeating: 0, count: 8)
        for idx in 0..<8 {
            counterBytes[idx] = UInt8(truncatingIfNeeded: counter >> ((7 - idx) * 8))
        }

        let mac = PureHMAC.authenticate(message: counterBytes, key: secret, prf: prf)
        let offset = Int(mac[mac.count - 1] & 0x0F)
        let binaryCode: UInt32 = (UInt32(mac[offset] & 0x7F) << 24)
            | (UInt32(mac[offset + 1]) << 16)
            | (UInt32(mac[offset + 2]) << 8)
            | UInt32(mac[offset + 3])

        let modulus: UInt32
        switch digits {
        case 6: modulus = 1_000_000
        case 7: modulus = 10_000_000
        default: modulus = 100_000_000
        }

        let numeric = binaryCode % modulus
        let rawText = String(numeric)
        if rawText.count >= digits {
            return rawText
        }
        return String(repeating: "0", count: digits - rawText.count) + rawText
    }

    public static func verify(
        code: String,
        secret: [UInt8],
        counter: UInt64,
        lookaheadSteps: Int = 0,
        digits: Int = 6,
        prf: PseudorandomFunctionVariant = .hmacSHA256
    ) throws -> OTPVerificationMatch {
        let normalizedCandidate = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let upperSteps = max(0, lookaheadSteps)
        var matchedCounter: UInt64?
        var matchedOffset: Int?

        for step in 0...upperSteps {
            let testCounter = counter &+ UInt64(step)
            let expected = try generate(secret: secret, counter: testCounter, digits: digits, prf: prf)
            if ConstantTime.equalStrings(expected, normalizedCandidate) && matchedCounter == nil {
                matchedCounter = testCounter
                matchedOffset = step
            }
        }

        if let matchedCounter {
            return OTPVerificationMatch(isValid: true, matchedCounter: matchedCounter, stepOffset: matchedOffset)
        }
        return OTPVerificationMatch(isValid: false, matchedCounter: nil, stepOffset: nil)
    }
}

public enum TOTPGenerator {
    public static func timeStepCounter(
        unixTimestamp: TimeInterval,
        periodSeconds: Int = 30,
        epochT0: TimeInterval = 0
    ) throws -> UInt64 {
        guard periodSeconds > 0 else {
            throw KDFAndMACError.invalidOTPPeriodSeconds(periodSeconds)
        }
        let elapsed = max(0.0, unixTimestamp - epochT0)
        return UInt64(floor(elapsed / Double(periodSeconds)))
    }

    public static func generate(
        secret: [UInt8],
        timestamp: Date = Date(),
        periodSeconds: Int = 30,
        epochT0: TimeInterval = 0,
        digits: Int = 6,
        prf: PseudorandomFunctionVariant = .hmacSHA256
    ) throws -> String {
        let counter = try timeStepCounter(
            unixTimestamp: timestamp.timeIntervalSince1970,
            periodSeconds: periodSeconds,
            epochT0: epochT0
        )
        return try HOTPGenerator.generate(secret: secret, counter: counter, digits: digits, prf: prf)
    }

    public static func generateAtUnixTime(
        secret: [UInt8],
        unixTimestamp: TimeInterval,
        periodSeconds: Int = 30,
        epochT0: TimeInterval = 0,
        digits: Int = 6,
        prf: PseudorandomFunctionVariant = .hmacSHA256
    ) throws -> String {
        let counter = try timeStepCounter(
            unixTimestamp: unixTimestamp,
            periodSeconds: periodSeconds,
            epochT0: epochT0
        )
        return try HOTPGenerator.generate(secret: secret, counter: counter, digits: digits, prf: prf)
    }

    public static func remainingSecondsInStep(
        unixTimestamp: TimeInterval,
        periodSeconds: Int = 30,
        epochT0: TimeInterval = 0
    ) -> Double {
        guard periodSeconds > 0 else { return 0 }
        let elapsed = max(0.0, unixTimestamp - epochT0)
        let mod = elapsed.truncatingRemainder(dividingBy: Double(periodSeconds))
        return Double(periodSeconds) - mod
    }

    public static func verify(
        code: String,
        secret: [UInt8],
        unixTimestamp: TimeInterval,
        driftSteps: Int = 1,
        periodSeconds: Int = 30,
        epochT0: TimeInterval = 0,
        digits: Int = 6,
        prf: PseudorandomFunctionVariant = .hmacSHA256
    ) throws -> OTPVerificationMatch {
        let baseCounter = try timeStepCounter(
            unixTimestamp: unixTimestamp,
            periodSeconds: periodSeconds,
            epochT0: epochT0
        )
        let normalizedCandidate = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let window = max(0, driftSteps)

        var foundCounter: UInt64?
        var foundDelta: Int?

        for delta in (-window)...window {
            let signedBase = Int64(bitPattern: baseCounter)
            let candidateStep = signedBase + Int64(delta)
            if candidateStep < 0 { continue }
            let stepUInt = UInt64(candidateStep)
            let expected = try HOTPGenerator.generate(secret: secret, counter: stepUInt, digits: digits, prf: prf)
            if ConstantTime.equalStrings(expected, normalizedCandidate) && foundCounter == nil {
                foundCounter = stepUInt
                foundDelta = delta
            }
        }

        if let foundCounter {
            return OTPVerificationMatch(isValid: true, matchedCounter: foundCounter, stepOffset: foundDelta)
        }
        return OTPVerificationMatch(isValid: false, matchedCounter: nil, stepOffset: nil)
    }
}

public struct OTPAuthProvisioningURI: Codable, Equatable, Hashable, Sendable {
    public let issuer: String
    public let accountName: String
    public let secret: [UInt8]
    public let prf: PseudorandomFunctionVariant
    public let digits: Int
    public let periodSeconds: Int

    public init(
        issuer: String,
        accountName: String,
        secret: [UInt8],
        prf: PseudorandomFunctionVariant = .hmacSHA256,
        digits: Int = 6,
        periodSeconds: Int = 30
    ) {
        self.issuer = issuer
        self.accountName = accountName
        self.secret = secret
        self.prf = prf
        self.digits = digits
        self.periodSeconds = periodSeconds
    }

    public func buildURIString() -> String {
        let secretB32 = Base32Codec.encode(secret, padded: false)
        let algorithmParam: String
        switch prf {
        case .hmacSHA256: algorithmParam = "SHA256"
        case .hmacSHA384: algorithmParam = "SHA384"
        case .hmacSHA512: algorithmParam = "SHA512"
        }
        let encodedIssuer = Self.percentEncode(issuer)
        let encodedAccount = Self.percentEncode(accountName)
        return "otpauth://totp/\(encodedIssuer):\(encodedAccount)?secret=\(secretB32)&issuer=\(encodedIssuer)&algorithm=\(algorithmParam)&digits=\(digits)&period=\(periodSeconds)"
    }

    private static func percentEncode(_ raw: String) -> String {
        var out = ""
        for byte in raw.utf8 {
            let isUnreserved = (0x41...0x5A).contains(byte)
                || (0x61...0x7A).contains(byte)
                || (0x30...0x39).contains(byte)
                || byte == 0x2D || byte == 0x5F || byte == 0x2E || byte == 0x7E
            if isUnreserved {
                out.append(Character(UnicodeScalar(byte)))
            } else {
                out.append("%")
                out.append(HexCodec.encode([byte], uppercase: true))
            }
        }
        return out
    }
}
