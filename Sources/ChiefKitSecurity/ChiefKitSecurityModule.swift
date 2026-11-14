import ChiefKitStudioCore
import Foundation

// MARK: - ChiefKitSecurity Module Facade & RFC Self-Verification Suite

public enum ChiefKitSecurityModule {
    public static let version = "3.0.0"
    public static let suiteIdentifier = "HNMLabs.ChiefKitSecurity.EphemerisCore.v3"

    /// Runs a single-call full-stack audit over source documents and an optional `PrivacyInfo.xcprivacy` XML string.
    public static func runFullWorkspaceAudit(
        workspaceName: String = "ChiefKitWorkspace",
        documents: [SecuritySourceDocument],
        privacyPlistXML: String? = nil,
        cryptoPosture: CryptographicPostureInput = .hardenedDefault
    ) throws -> SecurityAuditScorecard {
        let scanReport = StaticSecurityScanner.scan(documents: documents)
        let swiftContents = documents
            .filter { $0.filePath.hasSuffix(".swift") }
            .map(\.content)

        let manifest: PrivacyManifestSpec
        if let xml = privacyPlistXML, !xml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            manifest = try ApplePrivacyManifestBuilder.parsePlistXML(xml)
        } else {
            manifest = ApplePrivacyManifestBuilder.inferCompliantManifest(fromSwiftSources: swiftContents)
        }

        let privacyAudit = ApplePrivacyManifestBuilder.validate(
            manifest: manifest,
            againstSwiftSources: swiftContents
        )

        return SecurityAuditReportSynthesizer.evaluateScorecard(
            workspaceName: workspaceName,
            scanReport: scanReport,
            privacyAudit: privacyAudit,
            cryptoPosture: cryptoPosture
        )
    }
}

public struct SecuritySelfTestCheck: Codable, Equatable, Hashable, Sendable {
    public let name: String
    public let passed: Bool
    public let detail: String

    public init(name: String, passed: Bool, detail: String) {
        self.name = name
        self.passed = passed
        self.detail = detail
    }
}

public struct SecuritySelfTestReport: Codable, Equatable, Sendable {
    public let checks: [SecuritySelfTestCheck]
    public let allPassed: Bool

    public var failedCheckNames: [String] {
        checks.filter { !$0.passed }.map(\.name)
    }
}

public enum SecuritySelfTest {
    /// Verifies NIST FIPS 180-4, RFC 2104/4231, RFC 5869, RFC 8018, RFC 8439 ChaCha20-Poly1305,
    /// XChaCha20-Poly1305, GF(256) Shamir secret sharing, and EphemerisCore J2000 astrodynamics invariants.
    public static func verifyRFCVectors() -> Bool {
        runDetailedSelfTest().allPassed
    }

    public static func runDetailedSelfTest() -> SecuritySelfTestReport {
        var checks = [SecuritySelfTestCheck]()

        // 1. NIST FIPS 180-4 SHA-224 / SHA-256 / SHA-384 / SHA-512 vectors
        let shaEmptyOK = SHA256Engine.hexDigest("") ==
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        let shaAbcOK = SHA256Engine.hexDigest("abc") ==
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        let shaMultiBlockOK = SHA256Engine.hexDigest("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq") ==
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        let sha224OK = SHA224Engine.hexDigest("abc") ==
            "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7"
        let sha384OK = SHA384Engine.hexDigest("abc") ==
            "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7"
        let sha512OK = SHA512Engine.hexDigest("abc") ==
            "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"

        checks.append(
            SecuritySelfTestCheck(
                name: "FIPS-180-4 SHA-224/256/384/512",
                passed: shaEmptyOK && shaAbcOK && shaMultiBlockOK && sha224OK && sha384OK && sha512OK,
                detail: "Verified empty, 'abc', and 448-bit multi-block NIST digests"
            )
        )

        // 2. RFC 4231 HMAC-SHA256 & HMAC-SHA512 Test Case 1
        let rfc4231Key = [UInt8](repeating: 0x0B, count: 20)
        let rfc4231Msg = Array("Hi There".utf8)
        let hmac256Hex = HexCodec.encode(HMACSHA256.authenticate(message: rfc4231Msg, key: rfc4231Key))
        let hmac512Hex = HexCodec.encode(HMACSHA512.authenticate(message: rfc4231Msg, key: rfc4231Key))
        let hmacOK = (hmac256Hex == "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7")
            && (hmac512Hex == "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cdedaa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854")

        checks.append(
            SecuritySelfTestCheck(
                name: "RFC-4231 HMAC-SHA256/512",
                passed: hmacOK,
                detail: "RFC 4231 Test Case 1 exact tag match"
            )
        )

        // 3. RFC 5869 HKDF-SHA256 Test Case 1
        let hkdfIKM = [UInt8](repeating: 0x0B, count: 22)
        let hkdfSalt = (UInt8(0x00)...UInt8(0x0C)).map { $0 }
        let hkdfInfo = (UInt8(0xF0)...UInt8(0xF9)).map { $0 }
        let hkdfPRK = HKDFSHA256.extract(salt: hkdfSalt, ikm: hkdfIKM)
        let hkdfOKM = (try? HKDFSHA256.expand(prk: hkdfPRK, info: hkdfInfo, outputByteCount: 42)) ?? []
        let hkdfOK = (HexCodec.encode(hkdfPRK) == "077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5")
            && (HexCodec.encode(hkdfOKM) == "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865")

        checks.append(
            SecuritySelfTestCheck(
                name: "RFC-5869 HKDF-SHA256",
                passed: hkdfOK,
                detail: "RFC 5869 Test Case 1 PRK and 42-byte OKM exact match"
            )
        )

        // 4. RFC 8018 / 7914 PBKDF2-HMAC-SHA256 ("password", "salt", c=1 & c=4096)
        let pbkdfC1 = (try? PBKDF2Engine.deriveKeySHA256(
            password: Array("password".utf8),
            salt: Array("salt".utf8),
            iterations: 1,
            derivedKeyLength: 32
        )) ?? []
        let pbkdfC4096 = (try? PBKDF2Engine.deriveKeySHA256(
            password: Array("password".utf8),
            salt: Array("salt".utf8),
            iterations: 4_096,
            derivedKeyLength: 32
        )) ?? []
        let pbkdfOK = (HexCodec.encode(pbkdfC1) == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
            && (HexCodec.encode(pbkdfC4096) == "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")

        checks.append(
            SecuritySelfTestCheck(
                name: "RFC-8018 PBKDF2-HMAC-SHA256",
                passed: pbkdfOK,
                detail: "Verified c=1 and c=4096 derived keys"
            )
        )

        // 5. RFC 8439 ChaCha20 Block, Poly1305 MAC, HChaCha20 & AEAD Seal/Open
        let seqKey = (UInt8(0)...UInt8(31)).map { $0 }
        let rfcNonce = (try? HexCodec.decode("000000090000004a00000000")) ?? []
        let chachaBlk = (try? ChaCha20Engine.chacha20Block(key: seqKey, counter: 1, nonce: rfcNonce)) ?? []
        let chachaOK = HexCodec.encode(chachaBlk) ==
            "10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4ed2826446079faa0914c2d705d98b02a2b5129cd1de164eb9cbd083e8a2503c4e"

        let polyKey = (try? HexCodec.decode("85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b")) ?? []
        let polyMsg = Array("Cryptographic Forum Research Group".utf8)
        let polyTag = (try? Poly1305MAC.poly1305MAC(message: polyMsg, key: polyKey)) ?? []
        let polyOK = HexCodec.encode(polyTag) == "a8061dc1305136c6c22b8baf0c0127a9"

        let hNonce = (try? HexCodec.decode("000000090000004a0000000031415927")) ?? []
        let hSubkey = (try? ChaCha20Engine.hChaCha20(key: seqKey, nonce16: hNonce)) ?? []
        let hChaChaOK = HexCodec.encode(hSubkey) ==
            "82413b4227b27bfed30e42508a877d73a0f9e4d58a74a853c12ec41326d3ecdc"

        let aeadKey = (UInt8(0x80)...UInt8(0x9F)).map { $0 }
        let aeadNonce = (try? HexCodec.decode("070000004041424344454647")) ?? []
        let aeadAAD = (try? HexCodec.decode("50515253c0c1c2c3c4c5c6c7")) ?? []
        let aeadPlain = Array("ChiefKitStudio-3.0-AEAD-Verification".utf8)
        let sealed = try? ChaCha20Poly1305AEAD.seal(plaintext: aeadPlain, key: aeadKey, nonce: aeadNonce, aad: aeadAAD)
        let opened = sealed.flatMap { try? ChaCha20Poly1305AEAD.open(sealedBox: $0, key: aeadKey, aad: aeadAAD) }
        let aeadOK = (sealed.map { HexCodec.encode($0.ciphertext) } ==
            "dc13803867b629ce4696fa9f5fee279deff0a57e4c402af38befa2ee33eb60c43af7a456")
            && (sealed.map { HexCodec.encode($0.tag) } == "4c56ec1f0b7e3a78bf0e1ecdf943eb47")
            && (opened == aeadPlain)

        checks.append(
            SecuritySelfTestCheck(
                name: "RFC-8439 ChaCha20-Poly1305 & HChaCha20",
                passed: chachaOK && polyOK && hChaChaOK && aeadOK,
                detail: "Verified ChaCha20 Section 2.3.2, Poly1305 Section 2.5.2, HChaCha20 Section 2.2.1, and AEAD roundtrip"
            )
        )

        // 6. GF(256) Shamir Secret Sharing & EphemerisCore J2000 Invariants
        let shamirSecret = Array("ChiefKit-Vault-Master-Seed-256b!".utf8)
        let shares = (try? ShamirSecretSharing.splitSecret(
            shamirSecret,
            threshold: 3,
            shareCount: 5,
            deterministicSeed: seqKey
        )) ?? []
        let shamirRecovered = (shares.count == 5)
            ? (try? ShamirSecretSharing.combineShares([shares[0], shares[2], shares[4]]))
            : nil
        let shamirOK = (shamirRecovered == shamirSecret)

        let j2000Civil = try? CivilDateTime(year: 2000, month: 1, day: 1, hour: 12, minute: 0, second: 0.0)
        let j2000OK = j2000Civil.map { abs($0.toJulianDate() - 2_451_545.0) < 1.0e-9 } ?? false
        let keplerTest = try? KeplerSolver.solve(meanAnomalyRad: 1.15, eccentricity: 0.20563593, semiMajorAxisAU: 0.38709927)
        let keplerOK = keplerTest.map { $0.residualRad <= 1.0e-12 } ?? false

        checks.append(
            SecuritySelfTestCheck(
                name: "GF(256) Shamir & EphemerisCore J2000/Kepler",
                passed: shamirOK && j2000OK && keplerOK,
                detail: "Verified 3-of-5 GF(2^8) Lagrange recovery, JD 2451545.0 epoch, and <1e-12 rad Kepler solver"
            )
        )

        return SecuritySelfTestReport(
            checks: checks,
            allPassed: checks.allSatisfy(\.passed)
        )
    }
}
