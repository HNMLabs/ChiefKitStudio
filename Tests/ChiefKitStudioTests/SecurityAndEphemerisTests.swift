import ChiefKitAST
import ChiefKitSecurity
import ChiefKitStudioCore
import Foundation
import Testing
import XCTest

// MARK: - Swift 6 Testing (@Suite / @Test) for ChiefKitSecurity & EphemerisCore 3.0

@Suite("ChiefKitSecurity 3.0 — NIST/RFC Cryptography, EphemerisCore Astrodynamics & OWASP Security Suite")
struct SecurityAndEphemerisSwiftTestingSuite {
    @Test("SecuritySelfTest verifies all built-in NIST, RFC, Shamir GF(256), and EphemerisCore J2000 vectors")
    func rfcSelfVerificationSuite() {
        #expect(ChiefKitSecurityModule.version == "3.0.0")
        #expect(SecuritySelfTest.verifyRFCVectors())

        let detailed = SecuritySelfTest.runDetailedSelfTest()
        #expect(detailed.allPassed)
        #expect(detailed.failedCheckNames.isEmpty)
        #expect(detailed.checks.count == 6)
    }

    @Test(
        "Streaming SHA-2 engines produce identical digests across arbitrary chunk boundaries",
        arguments: [1, 3, 7, 31, 55, 56, 63, 64, 65, 127, 128, 129, 257]
    )
    func sha2StreamingChunkBoundaryInvariance(chunkSize: Int) {
        let payload = Array(repeating: Array("ChiefKitStudio-3.0-SHA2-Streaming-Boundary-Vector|".utf8), count: 9)
            .flatMap { $0 }

        let oneShot256 = SHA256Engine.hash(payload)
        let oneShot224 = SHA224Engine.hash(payload)
        let oneShot384 = SHA384Engine.hash(payload)
        let oneShot512 = SHA512Engine.hash(payload)
        let oneShot512_256 = SHA512_256Engine.hash(payload)

        var stream256 = SHA256Engine()
        var stream224 = SHA224Engine()
        var stream384 = SHA384Engine()
        var stream512 = SHA512Engine()
        var stream512_256 = SHA512_256Engine()

        var offset = 0
        while offset < payload.count {
            let end = min(offset + chunkSize, payload.count)
            let slice = Array(payload[offset..<end])
            stream256.update(slice)
            stream224.update(slice)
            stream384.update(slice)
            stream512.update(slice)
            stream512_256.update(slice)
            offset = end
        }

        #expect(stream256.finalize() == oneShot256)
        #expect(stream224.finalize() == oneShot224)
        #expect(stream384.finalize() == oneShot384)
        #expect(stream512.finalize() == oneShot512)
        #expect(stream512_256.finalize() == oneShot512_256)
    }

    @Test(
        "KeplerSolver converges below 1e-11 rad residual across circular, elliptic, high-e, and hyperbolic orbits",
        arguments: [
            (0.0, 0.0, OrbitRegime.circular),
            (0.85, 0.01671022, OrbitRegime.elliptic),
            (1.42, 0.20563593, OrbitRegime.elliptic),
            (2.75, 0.96714, OrbitRegime.elliptic),
            (1.10, 1.35, OrbitRegime.hyperbolic)
        ]
    )
    func keplerSolverPrecisionAcrossRegimes(meanAnomalyRad: Double, eccentricity: Double, expectedRegime: OrbitRegime) throws {
        let sol = try KeplerSolver.solve(
            meanAnomalyRad: meanAnomalyRad,
            eccentricity: eccentricity,
            semiMajorAxisAU: 1.523679,
            toleranceRad: 1.0e-12
        )
        #expect(sol.regime == expectedRegime)
        #expect(sol.residualRad < 1.0e-11)
        #expect(sol.radiusAU > 0.0)
        #expect(sol.iterationsUsed <= KeplerSolver.maxIterations)
    }

    @Test(
        "EncryptedWorkspaceVault seals and opens across both AEAD cipher suites and KDF presets",
        arguments: VaultCipherSuite.allCases
    )
    func workspaceVaultCipherSuites(suite: VaultCipherSuite) throws {
        let original = Array("Confidential ChiefKit 3.0 Design & Security Vault Payload".utf8)
        let detContext = Array("ChiefKitVaultTestContext-v3-\(suite.rawValue)".utf8)

        let vault = try EncryptedWorkspaceVault.seal(
            plaintext: original,
            passphrase: "correct-horse-battery-staple-chiefkit",
            cipherSuite: suite,
            kdfPRF: .hmacSHA256,
            kdfIterations: 1_024,
            deterministicContext: detContext
        )

        // Portable binary wire format round-trip
        let wireData = try vault.encodePortableBinary()
        #expect(wireData.count > original.count + 32)

        let decodedVault = try EncryptedWorkspaceVault.decodePortableBinary(wireData)
        #expect(decodedVault == vault)

        let opened = try decodedVault.open(passphrase: "correct-horse-battery-staple-chiefkit")
        #expect(opened == original)

        // Wrong passphrase must fail cleanly
        #expect(throws: VaultCryptoError.self) {
            _ = try decodedVault.open(passphrase: "wrong-passphrase-attempt")
        }
    }
}

// MARK: - XCTest Suite for NIST/RFC Vectors, Ephemeris Astronomy, Entropy Protocol, Shamir, Scanner & Privacy

final class SecurityAndEphemerisXCTests: XCTestCase {
    func testNISTFIPS180_4SHA2FamilyVectorsAndMerkleTreeInclusionAndTamperRejection() throws {
        // Explicit NIST FIPS 180-4 empty-string vectors
        XCTAssertEqual(
            SHA224Engine.hexDigest(""),
            "d14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f"
        )
        XCTAssertEqual(
            SHA256Engine.hexDigest(""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
        XCTAssertEqual(
            SHA384Engine.hexDigest(""),
            "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b"
        )
        XCTAssertEqual(
            SHA512Engine.hexDigest(""),
            "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
        )
        XCTAssertEqual(
            SHA512_256Engine.hexDigest([]),
            "c672b8d1ef56ed28ab87c3622c5114069bdd3ad7b8f9737498d0c01ecef0967a"
        )

        // Explicit NIST FIPS 180-4 "abc" vectors across all 5 SHA-2 variants
        let abcBytes = Array("abc".utf8)
        XCTAssertEqual(
            SHA224Engine.hexDigest("abc"),
            "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7"
        )
        XCTAssertEqual(
            SHA256Engine.hexDigest("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        XCTAssertEqual(
            SHA384Engine.hexDigest("abc"),
            "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7"
        )
        XCTAssertEqual(
            SHA512Engine.hexDigest("abc"),
            "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
        )
        XCTAssertEqual(
            SHA512_256Engine.hexDigest(abcBytes),
            "53048e2681941ef99b2e29b76b4c7dabe4c2d0c634fc6d46e0e2f13107e7af23"
        )

        // Multi-block 896-bit NIST vector for SHA-512
        let longNIST = "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
        XCTAssertEqual(
            SHA512Engine.hexDigest(longNIST),
            "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909"
        )

        // SHA2MerkleTree inclusion proofs across odd leaf count (7 leaves) + tamper rejection
        let leaves = (0..<7).map { idx in Array("AuditRecord-\(idx)".utf8) }
        let tree = try SHA2MerkleTree(leaves: leaves, variant: .sha256)
        XCTAssertEqual(tree.variant.digestByteCount, 32)
        XCTAssertEqual(tree.rootHex.count, 64)

        for idx in 0..<leaves.count {
            let proof = try tree.inclusionProof(forLeafAt: idx)
            XCTAssertTrue(SHA2MerkleTree.verify(leafPayload: leaves[idx], proof: proof))
            // Mutating leaf payload must fail proof verification
            var tamperedLeaf = leaves[idx]
            tamperedLeaf[0] ^= 0x01
            XCTAssertFalse(SHA2MerkleTree.verify(leafPayload: tamperedLeaf, proof: proof))
        }

        XCTAssertThrowsError(try SHA2MerkleTree(leaves: []))
    }

    func testRFC4231HMACRFC5869HKDFRFC8018PBKDF2Base32AndRFC6238TOTP() throws {
        // 1. RFC 4231 Test Case 2 ("Jefe" / "what do ya want for nothing?")
        let jefeKey = Array("Jefe".utf8)
        let jefeMsg = Array("what do ya want for nothing?".utf8)
        let hmac256 = HMACSHA256.authenticate(message: jefeMsg, key: jefeKey)
        let hmac512 = HMACSHA512.authenticate(message: jefeMsg, key: jefeKey)
        XCTAssertEqual(
            HexCodec.encode(hmac256),
            "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
        )
        XCTAssertEqual(
            HexCodec.encode(hmac512),
            "164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea2505549758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737"
        )
        XCTAssertTrue(HMACSHA256.verify(tag: hmac256, message: jefeMsg, key: jefeKey))
        var flippedTag = hmac256
        flippedTag[15] ^= 0x80
        XCTAssertFalse(HMACSHA256.verify(tag: flippedTag, message: jefeMsg, key: jefeKey))

        // 2. RFC 5869 HKDF-SHA256 Test Case 1 & HKDFKeyHierarchy domain separation
        let ikm = [UInt8](repeating: 0x0B, count: 22)
        let salt = Array(UInt8(0x00)...UInt8(0x0C))
        let info = Array(UInt8(0xF0)...UInt8(0xF9))
        let okm = try HKDFSHA256.deriveKey(ikm: ikm, salt: salt, info: info, outputByteCount: 42)
        XCTAssertEqual(
            HexCodec.encode(okm),
            "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"
        )

        let hierarchy = HKDFKeyHierarchy(ikm: ikm, salt: salt, prf: .hmacSHA512)
        let subkeyA = try hierarchy.expandLabeled(label: "vault-enc", outputByteCount: 32)
        let subkeyB = try hierarchy.expandLabeled(label: "vault-mac", outputByteCount: 32)
        XCTAssertNotEqual(subkeyA, subkeyB)

        // 3. RFC 8018 / 7914 PBKDF2-HMAC-SHA256 & PHC password record serialization
        let dk2 = try PBKDF2Engine.deriveKeySHA256(
            password: Array("password".utf8),
            salt: Array("salt".utf8),
            iterations: 2,
            derivedKeyLength: 32
        )
        XCTAssertEqual(
            HexCodec.encode(dk2),
            "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43"
        )

        let record = try PBKDF2PasswordRecord.create(
            password: "S3cureChiefKitPass!",
            salt: Array("0123456789abcdef".utf8),
            iterations: 2_048,
            prf: .hmacSHA256
        )
        XCTAssertTrue(record.verify(password: "S3cureChiefKitPass!"))
        XCTAssertFalse(record.verify(password: "WrongPass!"))
        let phc = record.serializedPHCString()
        let parsedRecord = try PBKDF2PasswordRecord.parse(phcString: phc)
        XCTAssertEqual(parsedRecord, record)

        // 4. RFC 4648 Base32 encode/decode vectors
        XCTAssertEqual(Base32Codec.encode(Array("foobar".utf8), padded: true), "MZXW6YTBOI======")
        XCTAssertEqual(try Base32Codec.decode("MZXW6YTBOI======"), Array("foobar".utf8))
        XCTAssertEqual(try Base32Codec.decode("mzxw-6ytb-oi"), Array("foobar".utf8))

        // 5. RFC 6238 Appendix B TOTP SHA-256 & SHA-512 8-digit test vectors
        let seed256 = Array("12345678901234567890123456789012".utf8)
        let seed512 = Array("1234567890123456789012345678901234567890123456789012345678901234".utf8)

        let code256_59 = try TOTPGenerator.generateAtUnixTime(
            secret: seed256,
            unixTimestamp: 59,
            periodSeconds: 30,
            epochT0: 0,
            digits: 8,
            prf: .hmacSHA256
        )
        XCTAssertEqual(code256_59, "46119246")

        let code256_1234567890 = try TOTPGenerator.generateAtUnixTime(
            secret: seed256,
            unixTimestamp: 1_234_567_890,
            periodSeconds: 30,
            epochT0: 0,
            digits: 8,
            prf: .hmacSHA256
        )
        XCTAssertEqual(code256_1234567890, "91819424")

        let code512_59 = try TOTPGenerator.generateAtUnixTime(
            secret: seed512,
            unixTimestamp: 59,
            periodSeconds: 30,
            epochT0: 0,
            digits: 8,
            prf: .hmacSHA512
        )
        XCTAssertEqual(code512_59, "90693936")

        let verifiedMatch = try TOTPGenerator.verify(
            code: "46119246",
            secret: seed256,
            unixTimestamp: 88, // +1 drift step from t=59
            driftSteps: 1,
            periodSeconds: 30,
            epochT0: 0,
            digits: 8,
            prf: .hmacSHA256
        )
        XCTAssertTrue(verifiedMatch.isValid)
        XCTAssertEqual(verifiedMatch.stepOffset, -1)

        let otpURI = OTPAuthProvisioningURI(
            issuer: "ChiefKitStudio",
            accountName: "secops@hnmlabs.io",
            secret: seed256
        ).buildURIString()
        XCTAssertTrue(otpURI.hasPrefix("otpauth://totp/"))
    }

    func testRFC8439ChaCha20Poly1305XChaCha20ChunkedStreamAndBitFlipRejection() throws {
        // RFC 8439 Section 2.8.2 Sunscreen AEAD test vector
        let rfcKey = try HexCodec.decode("808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f")
        let rfcNonce = try HexCodec.decode("070000004041424344454647")
        let rfcAAD = try HexCodec.decode("50515253c0c1c2c3c4c5c6c7")
        let sunscreenPlain = Array(
            "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.".utf8
        )

        let sealedSunscreen = try ChaCha20Poly1305AEAD.seal(
            plaintext: sunscreenPlain,
            key: rfcKey,
            nonce: rfcNonce,
            aad: rfcAAD
        )
        XCTAssertEqual(
            HexCodec.encode(sealedSunscreen.ciphertext),
            "d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b6116"
        )
        XCTAssertEqual(HexCodec.encode(sealedSunscreen.tag), "1ae10b594f09e26a7e902ecbd0600691")

        let openedSunscreen = try ChaCha20Poly1305AEAD.open(
            sealedBox: sealedSunscreen,
            key: rfcKey,
            aad: rfcAAD
        )
        XCTAssertEqual(openedSunscreen, sunscreenPlain)

        // Single bit-flip in authentication tag, ciphertext, or AAD MUST reject decryption
        var badTag = sealedSunscreen.tag
        badTag[0] ^= 0x01
        let forgedBox = try SealedBox(nonce: sealedSunscreen.nonce, ciphertext: sealedSunscreen.ciphertext, tag: badTag)
        XCTAssertThrowsError(try ChaCha20Poly1305AEAD.open(sealedBox: forgedBox, key: rfcKey, aad: rfcAAD))
        XCTAssertThrowsError(try ChaCha20Poly1305AEAD.open(sealedBox: sealedSunscreen, key: rfcKey, aad: [0x00]))

        // XChaCha20-Poly1305 192-bit nonce seal & open
        let nonce24 = Array(UInt8(1)...UInt8(24))
        let xSealed = try XChaCha20Poly1305AEAD.seal(
            plaintext: sunscreenPlain,
            key: rfcKey,
            nonce24: nonce24,
            aad: rfcAAD
        )
        let xOpened = try XChaCha20Poly1305AEAD.open(sealedBox: xSealed, key: rfcKey, aad: rfcAAD)
        XCTAssertEqual(xOpened, sunscreenPlain)

        // ChunkedAEADStream multi-chunk encryption, decryption, and truncation defense
        let largeStreamPlain = Array(repeating: UInt8(0x5A), count: 1_500)
        let streamWire = try ChunkedAEADStream.encryptStream(
            plaintext: largeStreamPlain,
            key: rfcKey,
            streamPrefix4: [0xCA, 0xFE, 0xBA, 0xBE],
            chunkByteSize: 512,
            streamAAD: rfcAAD
        )
        let streamRecovered = try ChunkedAEADStream.decryptStream(
            encryptedWire: streamWire,
            key: rfcKey,
            streamAAD: rfcAAD
        )
        XCTAssertEqual(streamRecovered, largeStreamPlain)

        // Truncating the final chunk triggers premature truncation detection
        let truncatedWire = Array(streamWire.dropLast(40))
        XCTAssertThrowsError(
            try ChunkedAEADStream.decryptStream(encryptedWire: truncatedWire, key: rfcKey, streamAAD: rfcAAD)
        )
    }

    func testEphemerisAstronomyMathJ2000SiderealTimeNineBodySnapshotSolarEventsAndLunarPhases() throws {
        // 1. J2000.0 exact epoch (2000-01-01 12:00:00 UTC -> JD == 2451545.0) & CivilDateTime round-trip
        let j2000Civil = try CivilDateTime(year: 2000, month: 1, day: 1, hour: 12, minute: 0, second: 0.0)
        XCTAssertEqual(j2000Civil.toJulianDate(), 2_451_545.0, accuracy: 1e-10)
        let roundTripCivil = CivilDateTime.fromJulianDate(2_451_545.0)
        XCTAssertEqual(roundTripCivil.year, 2000)
        XCTAssertEqual(roundTripCivil.month, 1)
        XCTAssertEqual(roundTripCivil.day, 1)
        XCTAssertEqual(roundTripCivil.hour, 12)

        let j2000Epoch = JulianEpoch(civil: j2000Civil)
        XCTAssertEqual(j2000Epoch.jd, 2_451_545.0, accuracy: 1e-10)
        XCTAssertEqual(j2000Epoch.julianCenturiesUT, 0.0, accuracy: 1e-12)

        // IAU GMST at J2000.0 (JD 2451545.0) is ~280.46061837 deg; LMST shifts by east longitude
        let gmstJ2000 = EarthOrientationModel.gmstDegrees(for: j2000Epoch)
        XCTAssertEqual(gmstJ2000, 280.46061837, accuracy: 1e-4)
        let istanbulObserver = try GeodeticObserver(latitudeDeg: 41.0082, longitudeDeg: 28.9784, elevationMeters: 40.0)
        let lmstIstanbul = EarthOrientationModel.lmstDegrees(for: j2000Epoch, eastLongitudeDeg: istanbulObserver.longitudeDeg)
        let expectedLMST = (gmstJ2000 + 28.9784).truncatingRemainder(dividingBy: 360.0)
        XCTAssertEqual(lmstIstanbul, expectedLMST, accuracy: 1e-6)

        let nutation = EarthOrientationModel.nutationAndObliquity(for: j2000Epoch)
        XCTAssertEqual(nutation.meanObliquityDeg, 23.43929, accuracy: 0.01)

        // 2. Full 9-body EphemerisSkySnapshot (Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune)
        let vernalEpoch = JulianEpoch(civil: try CivilDateTime(year: 2026, month: 3, day: 20, hour: 12, minute: 0, second: 0))
        let snapshot = try EphemerisSkySnapshot.compute(epoch: vernalEpoch, observer: istanbulObserver)
        XCTAssertEqual(snapshot.bodies.count, 9)
        for body in [
            CelestialBody.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune
        ] {
            let eph = snapshot.ephemeris(for: body)
            XCTAssertNotNil(eph, "Missing ephemeris for \(body.rawValue)")
            if let eph {
                XCTAssertGreaterThanOrEqual(eph.apparentEquatorial.rightAscensionDeg, 0.0)
                XCTAssertLessThan(eph.apparentEquatorial.rightAscensionDeg, 360.0)
                XCTAssertGreaterThanOrEqual(eph.apparentEquatorial.declinationDeg, -90.0)
                XCTAssertLessThanOrEqual(eph.apparentEquatorial.declinationDeg, 90.0)
            }
        }

        // 3. Solar sunrise/sunset & daylight hours near equinox at mid-latitude (~12 hours daylight)
        let solarEvents = try SolarEphemeris.computeSolarDayEvents(
            year: 2026,
            month: 3,
            day: 20,
            observer: istanbulObserver
        )
        XCTAssertNotNil(solarEvents.sunriseUTC)
        XCTAssertNotNil(solarEvents.sunsetUTC)
        if let rise = solarEvents.sunriseUTC, let set = solarEvents.sunsetUTC {
            XCTAssertLessThan(rise, set)
        }
        XCTAssertEqual(solarEvents.daylightDurationHours, 12.15, accuracy: 0.5)

        // 4. Lunar phase summary illumination in [0, 1] and valid phase name
        let moonSummary = LunarEphemeris.computeMoonSummary(epoch: vernalEpoch, observer: istanbulObserver)
        XCTAssertTrue(MoonPhaseName.allCases.contains(moonSummary.phaseName))
        XCTAssertGreaterThan(moonSummary.lunarAgeDays, -0.1)
        XCTAssertLessThan(moonSummary.lunarAgeDays, 30.0)
    }

    func testEphemerisEntropyProtocolSessionKeysCelestialTOTPSkewWindowAndSealedEnvelopes() throws {
        let sharedSeed = Array("ChiefKit-3.0-Shared-Celestial-Root-Secret-Seed!".utf8)
        let ts: TimeInterval = 1_774_000_020 // Inside 60s window
        let observer = try GeodeticObserver(latitudeDeg: 37.3346, longitudeDeg: -122.0090, elevationMeters: 55.0)

        // Same 60s step produces identical session key; next 60s step rotates session key
        let key1 = try EphemerisEntropyProtocol.deriveSessionKey(
            sharedSecretSeed: sharedSeed,
            unixTimestamp: ts,
            observer: observer,
            config: .standardGeocentric60s
        )
        let keySameStep = try EphemerisEntropyProtocol.deriveSessionKey(
            sharedSecretSeed: sharedSeed,
            unixTimestamp: ts + 15,
            observer: observer,
            config: .standardGeocentric60s
        )
        let keyNextStep = try EphemerisEntropyProtocol.deriveSessionKey(
            sharedSecretSeed: sharedSeed,
            unixTimestamp: ts + 60,
            observer: observer,
            config: .standardGeocentric60s
        )
        XCTAssertEqual(key1, keySameStep)
        XCTAssertNotEqual(key1.encryptionKey32, keyNextStep.encryptionKey32)
        XCTAssertEqual(key1.encryptionKey32.count, 32)
        XCTAssertEqual(key1.authenticationKey64.count, 64)

        // Celestial-TOTP generation, skew-window verification (+1 step), and out-of-window rejection (+5 steps)
        let totp = try EphemerisEntropyProtocol.generateCelestialTOTP(
            sharedSecretSeed: sharedSeed,
            unixTimestamp: ts,
            observer: observer,
            config: .standardGeocentric60s
        )
        XCTAssertEqual(totp.code.count, 8)

        let exactVerify = try EphemerisEntropyProtocol.verifyCelestialTOTP(
            candidateCode: totp.code,
            sharedSecretSeed: sharedSeed,
            verifierUnixTimestamp: ts + 5,
            observer: observer,
            config: .standardGeocentric60s
        )
        XCTAssertTrue(exactVerify.isValid)
        XCTAssertEqual(exactVerify.stepOffset, 0)

        let skewVerify = try EphemerisEntropyProtocol.verifyCelestialTOTP(
            candidateCode: totp.code,
            sharedSecretSeed: sharedSeed,
            verifierUnixTimestamp: ts + 60,
            observer: observer,
            config: .standardGeocentric60s
        )
        XCTAssertTrue(skewVerify.isValid)

        let expiredVerify = try EphemerisEntropyProtocol.verifyCelestialTOTP(
            candidateCode: totp.code,
            sharedSecretSeed: sharedSeed,
            verifierUnixTimestamp: ts + 360,
            observer: observer,
            config: .standardGeocentric60s
        )
        XCTAssertFalse(expiredVerify.isValid)

        // CelestialAuthEnvelope seal & open with highSecurityGeodetic30s location binding
        let commandPayload = Array("AUTHORIZE_WIRE_TRANSFER:USD:250000".utf8)
        let aad = Array("tenant=hnmlabs;channel=ios".utf8)
        let envelope = try EphemerisEntropyProtocol.sealEnvelope(
            payload: commandPayload,
            sharedSecretSeed: sharedSeed,
            unixTimestamp: ts,
            observer: observer,
            clientSalt12: Array(repeating: 0x33, count: 12),
            contextAAD: aad,
            config: .highSecurityGeodetic30s
        )

        let outcome = try EphemerisEntropyProtocol.openAndVerifyEnvelope(
            envelope,
            sharedSecretSeed: sharedSeed,
            verifierUnixTimestamp: ts + 10,
            observer: observer,
            contextAAD: aad,
            config: .highSecurityGeodetic30s
        )
        XCTAssertTrue(outcome.isAuthenticated)
        XCTAssertEqual(outcome.decryptedPayload, commandPayload)
        XCTAssertEqual(outcome.decryptedUTF8, "AUTHORIZE_WIRE_TRANSFER:USD:250000")

        // Wrong observer city (Tokyo vs Cupertino) must reject location-bound envelope!
        let tokyoObserver = try GeodeticObserver(latitudeDeg: 35.6762, longitudeDeg: 139.6503)
        XCTAssertThrowsError(
            try EphemerisEntropyProtocol.openAndVerifyEnvelope(
                envelope,
                sharedSecretSeed: sharedSeed,
                verifierUnixTimestamp: ts + 10,
                observer: tokyoObserver,
                contextAAD: aad,
                config: .highSecurityGeodetic30s
            )
        )

        // Entropy estimator & Swift 6 actor code synthesis
        let entropyReport = try EphemerisEntropyEstimator.benchmarkCelestialKeyStream(
            sharedSecretSeed: sharedSeed,
            startUnixTimestamp: ts,
            epochCount: 64
        )
        XCTAssertGreaterThan(entropyReport.shannonBitsPerByte, 7.5)
        XCTAssertTrue(entropyReport.passesCryptographicUniformityHeuristic)

        let actorSource = EphemerisAuthenticatorCodeSynthesizer.synthesizeSwift6ActorSource()
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: actorSource).isValid)
    }

    func testVaultPassphraseRotationAndShamirGF256SecretSharingThresholds() throws {
        // 1. EncryptedWorkspaceVault passphrase rotation
        let snapshotData = Array("{\"workspace\":\"ChiefKit3\",\"version\":3}".utf8)
        let initialVault = try EncryptedWorkspaceVault.seal(
            plaintext: snapshotData,
            passphrase: "old-vault-passphrase",
            cipherSuite: .chacha20Poly1305,
            kdfIterations: 1_024
        )
        let rotatedVault = try initialVault.rotatePassphrase(
            currentPassphrase: "old-vault-passphrase",
            newPassphrase: "new-rotated-passphrase-2026",
            newCipherSuite: .xchacha20Poly1305,
            newKDFIterations: 1_024
        )
        XCTAssertThrowsError(try rotatedVault.open(passphrase: "old-vault-passphrase"))
        XCTAssertEqual(try rotatedVault.open(passphrase: "new-rotated-passphrase-2026"), snapshotData)

        // 2. GF(2^8) field arithmetic identities: a * inv(a) == 1 for all 255 non-zero elements!
        for raw in UInt8(1)...UInt8(255) {
            let inv = GF256Field.inverse(raw)
            XCTAssertEqual(GF256Field.mul(raw, inv), 1, "Failed multiplicative inverse for \(raw)")
        }

        // 3. Shamir k-of-n (3-of-5) reconstruction across arbitrary 3-subsets & k-1 insufficiency
        let masterKey = Array("0123456789ABCDEF-MasterVaultKey!".utf8)
        let seed32 = Array(UInt8(0)..<UInt8(32))
        let shares = try ShamirSecretSharing.splitSecret(
            masterKey,
            threshold: 3,
            shareCount: 5,
            deterministicSeed: seed32
        )
        XCTAssertEqual(shares.count, 5)

        // Any 3 shares recover exact master key
        XCTAssertEqual(try ShamirSecretSharing.combineShares([shares[0], shares[1], shares[2]]), masterKey)
        XCTAssertEqual(try ShamirSecretSharing.combineShares([shares[1], shares[3], shares[4]]), masterKey)
        XCTAssertEqual(try ShamirSecretSharing.combineShares([shares[0], shares[2], shares[4]]), masterKey)

        // k - 1 (only 2 shares) must throw an error and refuse reconstruction
        XCTAssertThrowsError(try ShamirSecretSharing.combineShares([shares[0], shares[1]]))

        // Formatted recovery token string round-trip
        let tokenString = shares[0].formattedRecoveryToken()
        let parsedShare = try ShamirSecretShare.parseRecoveryToken(tokenString)
        XCTAssertEqual(parsedShare, shares[0])
    }

    func testStaticSecurityScannerPrivacyManifestBuilderAndOWASPTop10Scorecard() throws {
        // Construct vulnerable Swift source triggering secret, crypto, SQLi, HTTP, and UserDefaults rules
        let awsKey = "AKIA" + "IOSFODNN7EXAMPLE"
        let stripeKey = "sk_live_" + "51NabcDEFghiJKLmnoPQRstuVWX12"
        let vulnerableSwift = """
        import Foundation
        import CommonCrypto

        struct InsecurePaymentService {
            let cloudKey = "\(awsKey)"
            let paymentSecret = "\(stripeKey)"
            let endpoint = "http://api.insecure-payments.example.com/v1/charge"

            func saveToken(_ accessToken: String, userInput: String) {
                UserDefaults.standard.set(accessToken, forKey: "auth_access_token")
                let query = "SELECT * FROM accounts WHERE account_id = \\(userInput)"
                _ = query
                var digest = [UInt8](repeating: 0, count: 16)
                CC_MD5(accessToken, 4, &digest)
            }
        }
        """

        let scanReport = StaticSecurityScanner.scan(source: vulnerableSwift, filePath: "InsecurePaymentService.swift")
        let triggeredRules = Set(scanReport.findings.map(\.ruleID))
        XCTAssertTrue(triggeredRules.contains(.awsAccessKeyID))
        XCTAssertTrue(triggeredRules.contains(.stripeLiveSecretKey))
        XCTAssertTrue(triggeredRules.contains(.cleartextHTTPEndpoint))
        XCTAssertTrue(triggeredRules.contains(.userDefaultsSensitiveStorage))
        XCTAssertTrue(triggeredRules.contains(.sqlStringInterpolationInjection))
        XCTAssertTrue(triggeredRules.contains(.legacyBrokenHashMD5OrSHA1))

        // Inline pragma suppression (`// chiefkit-security:ignore`) suppresses targeted line
        let suppressedSwift = """
        let legacyEndpoint = "http://localhost-mock.internal/ping" // chiefkit-security:ignore
        """
        let suppressedScan = StaticSecurityScanner.scan(source: suppressedSwift)
        XCTAssertFalse(suppressedScan.findings.contains(where: { $0.ruleID == .cleartextHTTPEndpoint }))

        // ApplePrivacyManifestBuilder inference, XML round-trip, and ITMS validation
        let inferredManifest = ApplePrivacyManifestBuilder.inferCompliantManifest(fromSwiftSources: [vulnerableSwift])
        XCTAssertTrue(inferredManifest.accessedAPIDeclarations.contains(where: { $0.category == .userDefaults }))

        let plistXML = inferredManifest.compilePrivacyInfoPlistXML()
        XCTAssertTrue(plistXML.contains("NSPrivacyAccessedAPITypes"))
        let parsedManifest = try ApplePrivacyManifestBuilder.parsePlistXML(plistXML)
        XCTAssertEqual(parsedManifest, inferredManifest)

        let compliantAudit = ApplePrivacyManifestBuilder.validate(
            manifest: parsedManifest,
            againstSwiftSources: [vulnerableSwift]
        )
        XCTAssertTrue(compliantAudit.missingRequiredReasonCategories.isEmpty)
        XCTAssertTrue(compliantAudit.isAppStoreSubmissionReady)

        // Empty manifest against UserDefaults usage flags missing required-reason API
        let emptyManifestAudit = ApplePrivacyManifestBuilder.validate(
            manifest: PrivacyManifestSpec(),
            againstSwiftSources: [vulnerableSwift]
        )
        XCTAssertTrue(emptyManifestAudit.missingRequiredReasonCategories.contains(.userDefaults))
        XCTAssertFalse(emptyManifestAudit.isAppStoreSubmissionReady)

        // OWASP Mobile Top 10 Scorecard (vulnerable vs clean workspace)
        let vulnerableScorecard = SecurityAuditReportSynthesizer.evaluateScorecard(
            workspaceName: "VulnerableApp",
            scanReport: scanReport,
            privacyAudit: emptyManifestAudit,
            cryptoPosture: .hardenedDefault
        )
        XCTAssertEqual(vulnerableScorecard.categoryScores.count, 10)
        XCTAssertFalse(vulnerableScorecard.isReleaseGatePassing)

        let cleanScorecard = try ChiefKitSecurityModule.runFullWorkspaceAudit(
            workspaceName: "HardenedEnterpriseApp",
            documents: [
                SecuritySourceDocument(
                    filePath: "SafeService.swift",
                    content: "import Foundation\npublic struct SafeService: Sendable { public init() {} }\n"
                )
            ]
        )
        XCTAssertTrue(cleanScorecard.isReleaseGatePassing)
        XCTAssertGreaterThanOrEqual(cleanScorecard.overallScore, 90)

        let markdown = SecurityAuditReportSynthesizer.renderMarkdownReport(
            scorecard: cleanScorecard,
            scanReport: StaticSecurityScanner.scan(source: "struct Clean {}"),
            privacyAudit: compliantAudit
        )
        XCTAssertTrue(markdown.contains("OWASP"))
        XCTAssertTrue(markdown.contains("mermaid"))

        let regressionSuite = SecurityAuditReportSynthesizer.synthesizeSecurityRegressionTestSuite()
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: regressionSuite).isValid)
    }
}
