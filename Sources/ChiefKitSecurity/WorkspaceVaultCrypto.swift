import ChiefKitStudioCore
import Foundation

// MARK: - Workspace Vault Errors & Cipher Profiles

public enum VaultCryptoError: Error, LocalizedError, Equatable, Sendable {
    case emptyPassphrase
    case invalidPassphrase
    case tamperedVaultOrHeader
    case plaintextIntegrityMismatch
    case unsupportedVaultVersion(String)
    case invalidBinaryVaultMagic
    case malformedBinaryVaultEnvelope
    case invalidShamirParameters(threshold: Int, shareCount: Int)
    case emptySecretForSplitting
    case insufficientShamirShares(provided: Int, required: Int)
    case duplicateOrZeroShareCoordinate(UInt8)
    case mismatchedShamirShareMetadata
    case shamirCommitmentVerificationFailed
    case malformedShareMnemonic(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPassphrase:
            return "Vault passphrase must contain at least 1 UTF-8 byte."
        case .invalidPassphrase:
            return "Vault passphrase rejected: derived key fingerprint did not match header."
        case .tamperedVaultOrHeader:
            return "Vault AEAD authentication failed: ciphertext or metadata header was modified."
        case .plaintextIntegrityMismatch:
            return "Decrypted vault payload failed SHA-256 content commitment verification."
        case .unsupportedVaultVersion(let ver):
            return "Unsupported ChiefKit vault format version '\(ver)'."
        case .invalidBinaryVaultMagic:
            return "Invalid binary .chiefkit.vault file magic (expected 'CKV3')."
        case .malformedBinaryVaultEnvelope:
            return "Truncated or malformed binary .chiefkit.vault container."
        case .invalidShamirParameters(let k, let n):
            return "Invalid GF(256) Shamir threshold parameters (k=\(k), n=\(n)); require 1 <= k <= n <= 255."
        case .emptySecretForSplitting:
            return "Cannot split an empty secret byte array."
        case .insufficientShamirShares(let provided, let required):
            return "Insufficient Shamir shares: provided \(provided), threshold requires at least \(required)."
        case .duplicateOrZeroShareCoordinate(let x):
            return "Invalid or duplicate Shamir x-coordinate \(x)."
        case .mismatchedShamirShareMetadata:
            return "Shamir shares belong to incompatible split sets or byte lengths."
        case .shamirCommitmentVerificationFailed:
            return "Reconstructed secret failed SHA-256 commitment check (corrupted or wrong share subset)."
        case .malformedShareMnemonic(let detail):
            return "Malformed ChiefKit recovery share string: \(detail)"
        }
    }
}

public enum VaultCipherSuite: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case chacha20Poly1305 = "ChaCha20-Poly1305-RFC8439"
    case xchacha20Poly1305 = "XChaCha20-Poly1305-192Nonce"

    public var nonceByteCount: Int {
        switch self {
        case .chacha20Poly1305: return 12
        case .xchacha20Poly1305: return 24
        }
    }
}

public enum VaultKDFPreset: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case fastTesting = "fast-testing"
    case interactiveDesktop = "interactive-desktop"
    case hardenedArchive = "hardened-archive"

    public var iterations: Int {
        switch self {
        case .fastTesting: return 4_096
        case .interactiveDesktop: return 60_000
        case .hardenedArchive: return 210_000
        }
    }

    public var prf: PseudorandomFunctionVariant {
        switch self {
        case .fastTesting, .interactiveDesktop:
            return .hmacSHA256
        case .hardenedArchive:
            return .hmacSHA512
        }
    }
}

// MARK: - Authenticated Vault Metadata Header & Portable Container

public struct VaultMetadataHeader: Codable, Equatable, Hashable, Sendable {
    public static let formatMagic = "CKV3"
    public static let currentFormatVersion = "3.0"

    public let magic: String
    public let formatVersion: String
    public let cipherSuite: VaultCipherSuite
    public let kdfPRF: PseudorandomFunctionVariant
    public let kdfIterations: Int
    public let salt: [UInt8]
    /// 16-byte HKDF key-confirmation fingerprint (domain-separated from content encryption key).
    public let keyFingerprint: [UInt8]
    public let createdAtUnixTimestamp: Double
    public let contentMediaType: String
    public let uncompressedByteCount: Int
    /// SHA-256 commitment over `(contentEncryptionKey || plaintext)` for defense-in-depth integrity.
    public let keyedPlaintextCommitment: [UInt8]
    public let rotationGeneration: Int
    public let customAttributes: [String: String]

    public var keyFingerprintHex: String {
        HexCodec.encode(keyFingerprint)
    }

    /// Produces a strictly deterministic canonical byte array for AEAD Additional Authenticated Data (`aad`)
    /// so JSON key ordering differences can never cause spurious verification failures or malleability.
    public func canonicalAADBytes() -> [UInt8] {
        var aad = [UInt8]()
        aad.reserveCapacity(256)
        Self.appendLengthPrefixedUTF8(magic, to: &aad)
        Self.appendLengthPrefixedUTF8(formatVersion, to: &aad)
        Self.appendLengthPrefixedUTF8(cipherSuite.rawValue, to: &aad)
        Self.appendLengthPrefixedUTF8(kdfPRF.rawValue, to: &aad)
        CelestialStateFrame.appendBE32(UInt32(max(0, kdfIterations)), to: &aad)
        Self.appendLengthPrefixedBytes(salt, to: &aad)
        Self.appendLengthPrefixedBytes(keyFingerprint, to: &aad)
        CelestialStateFrame.appendBE64(createdAtUnixTimestamp.bitPattern, to: &aad)
        Self.appendLengthPrefixedUTF8(contentMediaType, to: &aad)
        CelestialStateFrame.appendBE64(UInt64(max(0, uncompressedByteCount)), to: &aad)
        Self.appendLengthPrefixedBytes(keyedPlaintextCommitment, to: &aad)
        CelestialStateFrame.appendBE32(UInt32(max(0, rotationGeneration)), to: &aad)

        let sortedKeys = customAttributes.keys.sorted()
        CelestialStateFrame.appendBE32(UInt32(sortedKeys.count), to: &aad)
        for key in sortedKeys {
            Self.appendLengthPrefixedUTF8(key, to: &aad)
            Self.appendLengthPrefixedUTF8(customAttributes[key] ?? "", to: &aad)
        }
        return aad
    }

    private static func appendLengthPrefixedUTF8(_ text: String, to out: inout [UInt8]) {
        appendLengthPrefixedBytes(Array(text.utf8), to: &out)
    }

    private static func appendLengthPrefixedBytes(_ bytes: [UInt8], to out: inout [UInt8]) {
        CelestialStateFrame.appendBE32(UInt32(bytes.count), to: &out)
        out.append(contentsOf: bytes)
    }
}

public struct EncryptedWorkspaceVault: Codable, Equatable, Sendable {
    public static let fileExtension = "chiefkit.vault"
    private static let binaryMagic: [UInt8] = [0x43, 0x4B, 0x56, 0x33] // "CKV3"

    public let header: VaultMetadataHeader
    public let sealedBox: SealedBox

    public init(header: VaultMetadataHeader, sealedBox: SealedBox) {
        self.header = header
        self.sealedBox = sealedBox
    }

    // MARK: Sealing APIs

    public static func seal(
        plaintext: [UInt8],
        passphrase: String,
        cipherSuite: VaultCipherSuite = .chacha20Poly1305,
        kdfPRF: PseudorandomFunctionVariant = .hmacSHA256,
        kdfIterations: Int = VaultKDFPreset.interactiveDesktop.iterations,
        deterministicContext: [UInt8]? = nil,
        contentMediaType: String = "application/octet-stream",
        createdAtTimestamp: Double = Date().timeIntervalSince1970,
        rotationGeneration: Int = 1,
        customAttributes: [String: String] = [:]
    ) throws -> EncryptedWorkspaceVault {
        let passphraseBytes = Array(passphrase.utf8)
        guard !passphraseBytes.isEmpty else {
            throw VaultCryptoError.emptyPassphrase
        }

        let salt32: [UInt8]
        let nonceBytes: [UInt8]
        if let detContext = deterministicContext {
            salt32 = try HKDFSHA256.deriveKey(
                ikm: detContext,
                salt: Array("ChiefKitVault.DeterministicSalt.v3".utf8),
                info: SHA256Engine.hash(plaintext),
                outputByteCount: 32
            )
            nonceBytes = try HKDFSHA256.deriveKey(
                ikm: salt32,
                salt: detContext,
                info: Array("ChiefKitVault.DeterministicNonce.v3".utf8),
                outputByteCount: cipherSuite.nonceByteCount
            )
        } else {
            var drbg = ChaCha20DRBG.seededFromSystemEntropy(additionalEntropy: SHA256Engine.hash(plaintext))
            salt32 = drbg.generateBytes(count: 32)
            nonceBytes = drbg.generateBytes(count: cipherSuite.nonceByteCount)
        }

        let derivedKeys = try deriveVaultSubkeys(
            passphraseBytes: passphraseBytes,
            salt: salt32,
            prf: kdfPRF,
            iterations: kdfIterations
        )

        let commitment = HMACSHA256.authenticate(message: plaintext, key: derivedKeys.integrityCommitmentKey)
        let header = VaultMetadataHeader(
            magic: VaultMetadataHeader.formatMagic,
            formatVersion: VaultMetadataHeader.currentFormatVersion,
            cipherSuite: cipherSuite,
            kdfPRF: kdfPRF,
            kdfIterations: kdfIterations,
            salt: salt32,
            keyFingerprint: derivedKeys.keyFingerprint16,
            createdAtUnixTimestamp: createdAtTimestamp,
            contentMediaType: contentMediaType,
            uncompressedByteCount: plaintext.count,
            keyedPlaintextCommitment: commitment,
            rotationGeneration: rotationGeneration,
            customAttributes: customAttributes
        )

        let aad = header.canonicalAADBytes()
        let box: SealedBox
        switch cipherSuite {
        case .chacha20Poly1305:
            box = try ChaCha20Poly1305AEAD.seal(
                plaintext: plaintext,
                key: derivedKeys.contentEncryptionKey32,
                nonce: nonceBytes,
                aad: aad
            )
        case .xchacha20Poly1305:
            box = try XChaCha20Poly1305AEAD.seal(
                plaintext: plaintext,
                key: derivedKeys.contentEncryptionKey32,
                nonce24: nonceBytes,
                aad: aad
            )
        }

        return EncryptedWorkspaceVault(header: header, sealedBox: box)
    }

    public static func sealData(
        _ data: Data,
        passphrase: String,
        preset: VaultKDFPreset = .interactiveDesktop,
        cipherSuite: VaultCipherSuite = .chacha20Poly1305,
        deterministicContext: [UInt8]? = nil,
        contentMediaType: String = "application/json; charset=utf-8",
        customAttributes: [String: String] = [:]
    ) throws -> EncryptedWorkspaceVault {
        try seal(
            plaintext: Array(data),
            passphrase: passphrase,
            cipherSuite: cipherSuite,
            kdfPRF: preset.prf,
            kdfIterations: preset.iterations,
            deterministicContext: deterministicContext,
            contentMediaType: contentMediaType,
            customAttributes: customAttributes
        )
    }

    public static func sealWorkspaceSnapshot(
        _ snapshot: WorkspaceSnapshot,
        passphrase: String,
        preset: VaultKDFPreset = .interactiveDesktop,
        cipherSuite: VaultCipherSuite = .xchacha20Poly1305,
        deterministicContext: [UInt8]? = nil
    ) throws -> EncryptedWorkspaceVault {
        let jsonData = try snapshot.encodedJSONData()
        return try sealData(
            jsonData,
            passphrase: passphrase,
            preset: preset,
            cipherSuite: cipherSuite,
            deterministicContext: deterministicContext,
            contentMediaType: "application/vnd.chiefkit.workspace+json",
            customAttributes: [
                "workspaceSchemaVersion": snapshot.schemaVersion,
                "activeThemePreset": snapshot.activeThemePreset.rawValue
            ]
        )
    }

    // MARK: Opening & Verification APIs

    public func open(passphrase: String, verifyKeyFingerprintFirst: Bool = true) throws -> [UInt8] {
        guard header.magic == VaultMetadataHeader.formatMagic,
              header.formatVersion == VaultMetadataHeader.currentFormatVersion
        else {
            throw VaultCryptoError.unsupportedVaultVersion(header.formatVersion)
        }

        let passphraseBytes = Array(passphrase.utf8)
        guard !passphraseBytes.isEmpty else {
            throw VaultCryptoError.emptyPassphrase
        }

        let derivedKeys = try Self.deriveVaultSubkeys(
            passphraseBytes: passphraseBytes,
            salt: header.salt,
            prf: header.kdfPRF,
            iterations: header.kdfIterations
        )

        let aad = header.canonicalAADBytes()
        let plaintext: [UInt8]
        do {
            switch header.cipherSuite {
            case .chacha20Poly1305:
                plaintext = try ChaCha20Poly1305AEAD.open(
                    sealedBox: sealedBox,
                    key: derivedKeys.contentEncryptionKey32,
                    aad: aad
                )
            case .xchacha20Poly1305:
                plaintext = try XChaCha20Poly1305AEAD.open(
                    sealedBox: sealedBox,
                    key: derivedKeys.contentEncryptionKey32,
                    aad: aad
                )
            }
        } catch {
            // Distinguish wrong passphrase from ciphertext/header tampering when fingerprint matches
            if verifyKeyFingerprintFirst && !ConstantTime.equal(derivedKeys.keyFingerprint16, header.keyFingerprint) {
                throw VaultCryptoError.invalidPassphrase
            }
            throw VaultCryptoError.tamperedVaultOrHeader
        }

        guard ConstantTime.equal(derivedKeys.keyFingerprint16, header.keyFingerprint) else {
            throw VaultCryptoError.tamperedVaultOrHeader
        }

        let expectedCommitment = HMACSHA256.authenticate(
            message: plaintext,
            key: derivedKeys.integrityCommitmentKey
        )
        guard plaintext.count == header.uncompressedByteCount,
              ConstantTime.equal(expectedCommitment, header.keyedPlaintextCommitment)
        else {
            throw VaultCryptoError.plaintextIntegrityMismatch
        }

        return plaintext
    }

    public func openData(passphrase: String) throws -> Data {
        Data(try open(passphrase: passphrase))
    }

    public func openWorkspaceSnapshot(passphrase: String) throws -> WorkspaceSnapshot {
        let data = try openData(passphrase: passphrase)
        return try WorkspaceSnapshot.decode(from: data)
    }

    // MARK: Lossless Passphrase & KDF Policy Rotation

    public func rotatePassphrase(
        currentPassphrase: String,
        newPassphrase: String,
        newCipherSuite: VaultCipherSuite? = nil,
        newKDFPRF: PseudorandomFunctionVariant? = nil,
        newKDFIterations: Int? = nil,
        deterministicContext: [UInt8]? = nil
    ) throws -> EncryptedWorkspaceVault {
        let decryptedPlaintext = try open(passphrase: currentPassphrase)
        let rotated = try Self.seal(
            plaintext: decryptedPlaintext,
            passphrase: newPassphrase,
            cipherSuite: newCipherSuite ?? header.cipherSuite,
            kdfPRF: newKDFPRF ?? header.kdfPRF,
            kdfIterations: newKDFIterations ?? header.kdfIterations,
            deterministicContext: deterministicContext,
            contentMediaType: header.contentMediaType,
            createdAtTimestamp: Date().timeIntervalSince1970,
            rotationGeneration: header.rotationGeneration + 1,
            customAttributes: header.customAttributes
        )
        // Verify bit-for-bit lossless roundtrip before returning rotated vault
        let verifiedPlaintext = try rotated.open(passphrase: newPassphrase)
        guard ConstantTime.equal(decryptedPlaintext, verifiedPlaintext) else {
            throw VaultCryptoError.plaintextIntegrityMismatch
        }
        return rotated
    }

    // MARK: Portable Binary & JSON Container Serialization

    public func encodePortableBinary() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let headerJSON = Array(try encoder.encode(header))
        let wireBox = sealedBox.combinedWireBytes()

        var out = [UInt8]()
        out.reserveCapacity(4 + 4 + headerJSON.count + 1 + 4 + wireBox.count)
        out.append(contentsOf: Self.binaryMagic)
        CelestialStateFrame.appendBE32(UInt32(headerJSON.count), to: &out)
        out.append(contentsOf: headerJSON)
        out.append(UInt8(sealedBox.nonce.count))
        CelestialStateFrame.appendBE32(UInt32(wireBox.count), to: &out)
        out.append(contentsOf: wireBox)
        return Data(out)
    }

    public static func decodePortableBinary(_ data: Data) throws -> EncryptedWorkspaceVault {
        let bytes = Array(data)
        guard bytes.count >= 13 else {
            throw VaultCryptoError.malformedBinaryVaultEnvelope
        }
        guard Array(bytes[0..<4]) == binaryMagic else {
            throw VaultCryptoError.invalidBinaryVaultMagic
        }
        let headerLen = Int(readBE32(bytes, at: 4))
        guard headerLen > 0 && 8 + headerLen + 5 <= bytes.count else {
            throw VaultCryptoError.malformedBinaryVaultEnvelope
        }
        let headerSlice = Data(bytes[8..<(8 + headerLen)])
        let header = try JSONDecoder().decode(VaultMetadataHeader.self, from: headerSlice)

        let nonceCursor = 8 + headerLen
        let nonceLen = Int(bytes[nonceCursor])
        let boxLen = Int(readBE32(bytes, at: nonceCursor + 1))
        let boxStart = nonceCursor + 5
        guard boxStart + boxLen == bytes.count else {
            throw VaultCryptoError.malformedBinaryVaultEnvelope
        }
        let wireSlice = Array(bytes[boxStart..<(boxStart + boxLen)])
        let box = try SealedBox(combinedWireBytes: wireSlice, nonceByteCount: nonceLen)
        return EncryptedWorkspaceVault(header: header, sealedBox: box)
    }

    private struct DerivedVaultKeys {
        let contentEncryptionKey32: [UInt8]
        let integrityCommitmentKey: [UInt8]
        let keyFingerprint16: [UInt8]
    }

    private static func deriveVaultSubkeys(
        passphraseBytes: [UInt8],
        salt: [UInt8],
        prf: PseudorandomFunctionVariant,
        iterations: Int
    ) throws -> DerivedVaultKeys {
        let stretchedMaster: [UInt8]
        switch prf {
        case .hmacSHA512:
            stretchedMaster = try PBKDF2Engine.deriveKeySHA512(
                password: passphraseBytes,
                salt: salt,
                iterations: iterations,
                derivedKeyLength: 64
            )
        case .hmacSHA256, .hmacSHA384:
            stretchedMaster = try PBKDF2Engine.deriveKeySHA256(
                password: passphraseBytes,
                salt: salt,
                iterations: iterations,
                derivedKeyLength: 32
            )
        }

        let tree = HKDFKeyHierarchy(
            ikm: stretchedMaster,
            salt: salt,
            prf: prf,
            namespacePrefix: "ChiefKitVault.v3."
        )
        let cek = try tree.expandLabeled(label: "content.aead.key", outputByteCount: 32)
        let icKey = try tree.expandLabeled(label: "plaintext.commitment.key", outputByteCount: 32)
        let fp = try tree.expandLabeled(label: "header.key.fingerprint", outputByteCount: 16)
        return DerivedVaultKeys(
            contentEncryptionKey32: cek,
            integrityCommitmentKey: icKey,
            keyFingerprint16: fp
        )
    }

    @inline(__always)
    private static func readBE32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
    }
}

// MARK: - Galois Field GF(2^8) Arithmetic Modulo x^8 + x^4 + x^3 + x + 1 (0x11B)

public enum GF256Field {
    /// Irreducible polynomial low byte (`0x11B & 0xFF == 0x1B`).
    public static let reductionByte: UInt8 = 0x1B

    @inlinable
    public static func add(_ a: UInt8, _ b: UInt8) -> UInt8 {
        a ^ b
    }

    @inlinable
    public static func sub(_ a: UInt8, _ b: UInt8) -> UInt8 {
        a ^ b
    }

    /// Constant-time carryless multiplication in `GF(2^8) / (x^8 + x^4 + x^3 + x + 1)`.
    @inlinable
    public static func mul(_ a: UInt8, _ b: UInt8) -> UInt8 {
        var product: UInt8 = 0
        var x = a
        var y = b
        for _ in 0..<8 {
            let lowBitMask = UInt8(0) &- (y & 1)
            product ^= x & lowBitMask
            let highBit = (x >> 7) & 1
            let reduceMask = UInt8(0) &- highBit
            x = (x << 1) ^ (reductionByte & reduceMask)
            y >>= 1
        }
        return product
    }

    /// Constant-time multiplicative inverse in `GF(2^8)` via Fermat's Little Theorem (`a^254`, `inv(0) = 0`).
    @inlinable
    public static func inverse(_ a: UInt8) -> UInt8 {
        // 254 = 0b1111_1110 = 2 + 4 + 8 + 16 + 32 + 64 + 128
        let a2 = mul(a, a)
        let a3 = mul(a2, a)
        let a6 = mul(a3, a3)
        let a7 = mul(a6, a)
        let a14 = mul(a7, a7)
        let a15 = mul(a14, a)
        let a30 = mul(a15, a15)
        let a60 = mul(a30, a30)
        let a63 = mul(a60, a3)
        let a126 = mul(a63, a63)
        let a127 = mul(a126, a)
        return mul(a127, a127)
    }

    @inlinable
    public static func div(_ numerator: UInt8, _ denominator: UInt8) -> UInt8 {
        mul(numerator, inverse(denominator))
    }

    /// Evaluates polynomial `coeffs[0] + coeffs[1]*x + ... + coeffs[d]*x^d` at `x` using Horner's scheme.
    public static func evaluatePolynomial(coefficients: [UInt8], at x: UInt8) -> UInt8 {
        guard !coefficients.isEmpty else { return 0 }
        var acc: UInt8 = 0
        for idx in stride(from: coefficients.count - 1, through: 0, by: -1) {
            acc = add(mul(acc, x), coefficients[idx])
        }
        return acc
    }
}

// MARK: - GF(256) Shamir's Secret Sharing & XOR Split Recovery Helpers

public struct ShamirSecretShare: Codable, Equatable, Hashable, Sendable {
    public let indexX: UInt8
    public let threshold: Int
    public let totalShares: Int
    public let yValues: [UInt8]
    /// 16-byte SHA-256 truncated commitment over `(threshold || secret)` to detect bad share combinations.
    public let secretCommitment16: [UInt8]

    public init(
        indexX: UInt8,
        threshold: Int,
        totalShares: Int,
        yValues: [UInt8],
        secretCommitment16: [UInt8]
    ) {
        self.indexX = indexX
        self.threshold = threshold
        self.totalShares = totalShares
        self.yValues = yValues
        self.secretCommitment16 = secretCommitment16
    }

    /// Encodes share into a portable human-copiable string:
    /// `CKS3-S<xx>N<nn>T<kk>-<commitmentHex>-<yValuesBase64URL>`.
    public func formattedRecoveryToken() -> String {
        let idxHex = HexCodec.encode([indexX], uppercase: true)
        let totalHex = HexCodec.encode([UInt8(truncatingIfNeeded: totalShares)], uppercase: true)
        let threshHex = HexCodec.encode([UInt8(truncatingIfNeeded: threshold)], uppercase: true)
        let commitHex = HexCodec.encode(secretCommitment16, uppercase: true)
        let bodyB64 = Base64URLCodec.encode(yValues, padded: false, urlSafe: true)
        return "CKS3-S\(idxHex)N\(totalHex)T\(threshHex)-\(commitHex)-\(bodyB64)"
    }

    public static func parseRecoveryToken(_ token: String) throws -> ShamirSecretShare {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count >= 4, parts[0] == "CKS3" else {
            throw VaultCryptoError.malformedShareMnemonic("Missing CKS3 prefix")
        }
        let meta = String(parts[1])
        guard meta.count == 9,
              meta.hasPrefix("S"),
              meta.dropFirst(3).hasPrefix("N"),
              meta.dropFirst(6).hasPrefix("T")
        else {
            throw VaultCryptoError.malformedShareMnemonic("Invalid SxxNnnTkk metadata header")
        }
        let sHex = String(meta.dropFirst(1).prefix(2))
        let nHex = String(meta.dropFirst(4).prefix(2))
        let tHex = String(meta.dropFirst(7).prefix(2))
        let xByte = try HexCodec.decode(sHex)[0]
        let nVal = Int(try HexCodec.decode(nHex)[0])
        let kVal = Int(try HexCodec.decode(tHex)[0])
        let commitBytes = try HexCodec.decode(String(parts[2]))
        let bodyJoined = parts.dropFirst(3).joined(separator: "-")
        let yBytes = try Base64URLCodec.decode(bodyJoined)
        guard commitBytes.count == 16, !yBytes.isEmpty else {
            throw VaultCryptoError.malformedShareMnemonic("Invalid commitment or share payload length")
        }
        return ShamirSecretShare(
            indexX: xByte,
            threshold: kVal,
            totalShares: nVal,
            yValues: yBytes,
            secretCommitment16: commitBytes
        )
    }
}

public enum ShamirSecretSharing {
    /// Splits `secret` into `shareCount` shares over `GF(2^8)` (`0x11B`) where any `threshold` shares
    /// reconstruct `secret` exactly and any `threshold - 1` shares leak zero information-theoretic bits.
    public static func splitSecret(
        _ secret: [UInt8],
        threshold: Int,
        shareCount: Int,
        deterministicSeed: [UInt8]? = nil
    ) throws -> [ShamirSecretShare] {
        guard !secret.isEmpty else {
            throw VaultCryptoError.emptySecretForSplitting
        }
        guard threshold >= 1 && shareCount >= threshold && shareCount <= 255 else {
            throw VaultCryptoError.invalidShamirParameters(threshold: threshold, shareCount: shareCount)
        }

        let commitment = computeCommitment16(secret: secret, threshold: threshold)

        var drbg: ChaCha20DRBG
        if let seed = deterministicSeed {
            drbg = ChaCha20DRBG(
                seedMaterial: seed + commitment,
                personalization: Array("ChiefKit.ShamirGF256.v3".utf8)
            )
        } else {
            drbg = ChaCha20DRBG.seededFromSystemEntropy(additionalEntropy: commitment)
        }

        var shareBuffers = Array(
            repeating: [UInt8](repeating: 0, count: secret.count),
            count: shareCount
        )

        for byteOffset in 0..<secret.count {
            var coeffs = [UInt8](repeating: 0, count: threshold)
            coeffs[0] = secret[byteOffset]
            if threshold > 1 {
                let randomTail = drbg.generateBytes(count: threshold - 1)
                for degIdx in 1..<threshold {
                    coeffs[degIdx] = randomTail[degIdx - 1]
                }
            }
            for shareIdx in 0..<shareCount {
                let x = UInt8(shareIdx + 1)
                shareBuffers[shareIdx][byteOffset] = GF256Field.evaluatePolynomial(
                    coefficients: coeffs,
                    at: x
                )
            }
        }

        return (0..<shareCount).map { idx in
            ShamirSecretShare(
                indexX: UInt8(idx + 1),
                threshold: threshold,
                totalShares: shareCount,
                yValues: shareBuffers[idx],
                secretCommitment16: commitment
            )
        }
    }

    /// Reconstructs the original secret from `>= threshold` distinct `ShamirSecretShare` records via
    /// Lagrange polynomial interpolation at `x = 0` over `GF(2^8)` (`0x11B`).
    public static func combineShares(_ shares: [ShamirSecretShare]) throws -> [UInt8] {
        guard let first = shares.first else {
            throw VaultCryptoError.insufficientShamirShares(provided: 0, required: 1)
        }
        let k = first.threshold
        guard shares.count >= k else {
            throw VaultCryptoError.insufficientShamirShares(provided: shares.count, required: k)
        }

        let activeShares = Array(shares.prefix(k))
        let byteLength = first.yValues.count
        var seenCoordinates = Set<UInt8>()

        for sh in activeShares {
            guard sh.indexX != 0, !seenCoordinates.contains(sh.indexX) else {
                throw VaultCryptoError.duplicateOrZeroShareCoordinate(sh.indexX)
            }
            seenCoordinates.insert(sh.indexX)
            guard sh.threshold == k,
                  sh.yValues.count == byteLength,
                  ConstantTime.equal(sh.secretCommitment16, first.secretCommitment16)
            else {
                throw VaultCryptoError.mismatchedShamirShareMetadata
            }
        }

        if k == 1 {
            let candidate = activeShares[0].yValues
            let verifyCommit = computeCommitment16(secret: candidate, threshold: 1)
            guard ConstantTime.equal(verifyCommit, first.secretCommitment16) else {
                throw VaultCryptoError.shamirCommitmentVerificationFailed
            }
            return candidate
        }

        // Precompute Lagrange basis weights L_j(0) = prod_{m != j} x_m / (x_j ^ x_m) in GF(2^8)
        var lagrangeAtZero = [UInt8](repeating: 0, count: k)
        for j in 0..<k {
            let xj = activeShares[j].indexX
            var numerator: UInt8 = 1
            var denominator: UInt8 = 1
            for m in 0..<k where m != j {
                let xm = activeShares[m].indexX
                numerator = GF256Field.mul(numerator, xm)
                denominator = GF256Field.mul(denominator, GF256Field.sub(xj, xm))
            }
            lagrangeAtZero[j] = GF256Field.div(numerator, denominator)
        }

        var recovered = [UInt8](repeating: 0, count: byteLength)
        for byteOffset in 0..<byteLength {
            var acc: UInt8 = 0
            for j in 0..<k {
                let term = GF256Field.mul(activeShares[j].yValues[byteOffset], lagrangeAtZero[j])
                acc = GF256Field.add(acc, term)
            }
            recovered[byteOffset] = acc
        }

        let recomputedCommit = computeCommitment16(secret: recovered, threshold: k)
        guard ConstantTime.equal(recomputedCommit, first.secretCommitment16) else {
            throw VaultCryptoError.shamirCommitmentVerificationFailed
        }
        return recovered
    }

    /// Lightweight `N-of-N` unconditional XOR secret splitter.
    public static func splitXORAllRequired(
        _ secret: [UInt8],
        partCount: Int,
        deterministicSeed: [UInt8]? = nil
    ) throws -> [[UInt8]] {
        guard !secret.isEmpty else {
            throw VaultCryptoError.emptySecretForSplitting
        }
        guard partCount >= 2 && partCount <= 64 else {
            throw VaultCryptoError.invalidShamirParameters(threshold: partCount, shareCount: partCount)
        }

        var drbg = deterministicSeed.map { ChaCha20DRBG(seedMaterial: $0) }
            ?? ChaCha20DRBG.seededFromSystemEntropy()
        var parts = [[UInt8]]()
        parts.reserveCapacity(partCount)

        var finalPart = secret
        for _ in 0..<(partCount - 1) {
            let mask = drbg.generateBytes(count: secret.count)
            for i in 0..<secret.count {
                finalPart[i] ^= mask[i]
            }
            parts.append(mask)
        }
        parts.append(finalPart)
        return parts
    }

    public static func combineXORAllRequired(_ parts: [[UInt8]]) throws -> [UInt8] {
        guard let first = parts.first, !first.isEmpty, parts.count >= 2 else {
            throw VaultCryptoError.insufficientShamirShares(provided: parts.count, required: 2)
        }
        var acc = [UInt8](repeating: 0, count: first.count)
        for part in parts {
            guard part.count == first.count else {
                throw VaultCryptoError.mismatchedShamirShareMetadata
            }
            for i in 0..<first.count {
                acc[i] ^= part[i]
            }
        }
        return acc
    }

    private static func computeCommitment16(secret: [UInt8], threshold: Int) -> [UInt8] {
        var input = Array("ChiefKit.ShamirCommit.v3".utf8)
        input.append(UInt8(truncatingIfNeeded: threshold))
        input.append(contentsOf: secret)
        return Array(SHA256Engine.hash(input).prefix(16))
    }
}
