import ChiefKitStudioCore
import Foundation

// MARK: - Ephemeris Cryptographic Protocol Errors & Configuration

public enum EphemerisProtocolError: Error, LocalizedError, Equatable, Sendable {
    case secretSeedTooShort(actualBytes: Int, minimumBytes: Int)
    case invalidEpochStepSeconds(Int)
    case emptyCelestialBodySelection
    case invalidObserverCellResolution(Double)
    case missingObserverForGeodeticBoundPolicy
    case clockSkewExceeded(envelopeStep: Int64, verifierStep: Int64, maxAllowedSkew: Int)
    case skyCommitmentMismatch
    case envelopeMACVerificationFailed
    case envelopeAEADDecryptionFailed
    case unsupportedProtocolVersion(UInt8)

    public var errorDescription: String? {
        switch self {
        case .secretSeedTooShort(let actual, let minBytes):
            return "Ephemeris shared secret seed (\(actual) bytes) must be at least \(minBytes) bytes."
        case .invalidEpochStepSeconds(let sec):
            return "Epoch step window (\(sec)s) must be between 5 and 86,400 seconds."
        case .emptyCelestialBodySelection:
            return "At least one celestial body must participate in the EphemerisCore state frame."
        case .invalidObserverCellResolution(let deg):
            return "Observer geodetic grid resolution (\(deg) deg) must lie within [0.01, 45.0]."
        case .missingObserverForGeodeticBoundPolicy:
            return "Geodetic observer coordinates are required when bindObserverGeodeticCell is enabled."
        case .clockSkewExceeded(let envStep, let verStep, let maxSkew):
            return "Envelope epoch step \(envStep) exceeds ±\(maxSkew) step window around verifier step \(verStep)."
        case .skyCommitmentMismatch:
            return "Computed multi-body celestial state commitment did not match the envelope header."
        case .envelopeMACVerificationFailed:
            return "Outer HMAC-SHA512 confirmation tag on CelestialAuthEnvelope failed verification."
        case .envelopeAEADDecryptionFailed:
            return "ChaCha20-Poly1305 AEAD opening failed on CelestialAuthEnvelope."
        case .unsupportedProtocolVersion(let ver):
            return "Unsupported EphemerisCore protocol wire version \(ver)."
        }
    }
}

public struct EphemerisAuthConfiguration: Codable, Equatable, Hashable, Sendable {
    public static let wireProtocolVersion: UInt8 = 3

    public var epochStepSeconds: Int
    public var allowedClockSkewSteps: Int
    public var participatingBodies: [CelestialBody]
    public var bindObserverGeodeticCell: Bool
    public var observerCellResolutionDeg: Double
    public var totpDigits: Int
    public var domainNamespace: String

    public init(
        epochStepSeconds: Int = 60,
        allowedClockSkewSteps: Int = 1,
        participatingBodies: [CelestialBody] = [
            .sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn
        ],
        bindObserverGeodeticCell: Bool = false,
        observerCellResolutionDeg: Double = 0.25,
        totpDigits: Int = 8,
        domainNamespace: String = "HNMLabs.EphemerisCore.v3"
    ) throws {
        guard (5...86_400).contains(epochStepSeconds) else {
            throw EphemerisProtocolError.invalidEpochStepSeconds(epochStepSeconds)
        }
        guard !participatingBodies.isEmpty else {
            throw EphemerisProtocolError.emptyCelestialBodySelection
        }
        guard observerCellResolutionDeg >= 0.01 && observerCellResolutionDeg <= 45.0 else {
            throw EphemerisProtocolError.invalidObserverCellResolution(observerCellResolutionDeg)
        }
        self.epochStepSeconds = epochStepSeconds
        self.allowedClockSkewSteps = max(0, min(10, allowedClockSkewSteps))
        self.participatingBodies = participatingBodies
        self.bindObserverGeodeticCell = bindObserverGeodeticCell
        self.observerCellResolutionDeg = observerCellResolutionDeg
        self.totpDigits = max(6, min(8, totpDigits))
        self.domainNamespace = domainNamespace
    }

    public static let standardGeocentric60s = try! EphemerisAuthConfiguration()

    public static let highSecurityGeodetic30s = try! EphemerisAuthConfiguration(
        epochStepSeconds: 30,
        allowedClockSkewSteps: 1,
        participatingBodies: CelestialBody.geocentricSkyBodies,
        bindObserverGeodeticCell: true,
        observerCellResolutionDeg: 0.25,
        totpDigits: 8,
        domainNamespace: "HNMLabs.EphemerisCore.Geo30s.v3"
    )
}

// MARK: - Deterministic Geodetic Cell & Multi-Body State Vector Quantization

public struct QuantizedGeodeticCell: Codable, Equatable, Hashable, Sendable {
    public let latCellIndex: Int32
    public let lonCellIndex: Int32
    public let cellCenterLatitudeDeg: Double
    public let cellCenterLongitudeDeg: Double
    public let resolutionDeg: Double

    public init(observer: GeodeticObserver, resolutionDeg: Double) {
        let clampedRes = max(0.01, resolutionDeg)
        let latIdx = Int32(floor((observer.latitudeDeg + 90.0) / clampedRes))
        let lonIdx = Int32(floor((observer.longitudeDeg + 180.0) / clampedRes))
        self.latCellIndex = latIdx
        self.lonCellIndex = lonIdx
        self.resolutionDeg = clampedRes
        self.cellCenterLatitudeDeg = min(90.0, max(-90.0, -90.0 + (Double(latIdx) + 0.5) * clampedRes))
        self.cellCenterLongitudeDeg = min(180.0, max(-180.0, -180.0 + (Double(lonIdx) + 0.5) * clampedRes))
    }

    public func canonicalObserver() -> GeodeticObserver {
        (try? GeodeticObserver(
            latitudeDeg: cellCenterLatitudeDeg,
            longitudeDeg: cellCenterLongitudeDeg,
            elevationMeters: 0.0,
            pressureHPa: 1_013.25,
            temperatureCelsius: 15.0
        )) ?? .greenwichPrimeMeridian
    }
}

public struct QuantizedBodyStateRecord: Codable, Equatable, Hashable, Sendable {
    public let body: CelestialBody
    /// Geocentric ecliptic longitude quantized in units of 0.1 arcsecond (`deg * 36_000`).
    public let eclipticLonDeciArcsec: Int64
    /// Geocentric ecliptic latitude quantized in units of 0.1 arcsecond (`deg * 36_000`).
    public let eclipticLatDeciArcsec: Int64
    /// Geocentric distance quantized in units of `1e-7 AU`.
    public let distanceSubAU: Int64
    /// Optional topocentric azimuth/altitude quantized in units of `0.01 deg` when geodetic cell is bound.
    public let topocentricAzCentideg: Int32?
    public let topocentricAltCentideg: Int32?
}

public struct CelestialStateFrame: Codable, Equatable, Sendable {
    public let protocolVersion: UInt8
    public let epochStepIndex: Int64
    public let quantizedUnixTimestamp: TimeInterval
    public let julianDateUTC: Double
    /// Greenwich Mean Sidereal Time quantized in units of 0.1 arcsecond (`deg * 36_000`).
    public let gmstDeciArcsec: Int64
    public let geodeticCell: QuantizedGeodeticCell?
    public let bodyRecords: [QuantizedBodyStateRecord]
    public let canonicalBinaryFrame: [UInt8]
    public let skyCommitmentSHA512: [UInt8]

    public var skyCommitmentHex: String {
        HexCodec.encode(skyCommitmentSHA512)
    }

    public static func capture(
        unixTimestamp: TimeInterval,
        observer: GeodeticObserver? = nil,
        config: EphemerisAuthConfiguration = .standardGeocentric60s
    ) throws -> CelestialStateFrame {
        let stepSec = Double(config.epochStepSeconds)
        let stepIndex = Int64(floor(unixTimestamp / stepSec))
        return try captureForStepIndex(stepIndex: stepIndex, observer: observer, config: config)
    }

    public static func captureForStepIndex(
        stepIndex: Int64,
        observer: GeodeticObserver? = nil,
        config: EphemerisAuthConfiguration = .standardGeocentric60s
    ) throws -> CelestialStateFrame {
        let qCell: QuantizedGeodeticCell?
        let effectiveObserver: GeodeticObserver
        if config.bindObserverGeodeticCell {
            guard let observer else {
                throw EphemerisProtocolError.missingObserverForGeodeticBoundPolicy
            }
            let cell = QuantizedGeodeticCell(observer: observer, resolutionDeg: config.observerCellResolutionDeg)
            qCell = cell
            effectiveObserver = cell.canonicalObserver()
        } else {
            qCell = nil
            effectiveObserver = .greenwichPrimeMeridian
        }

        let quantizedUnix = Double(stepIndex) * Double(config.epochStepSeconds)
        let jdUTC = EphemerisConstants.unixEpochJulianDate + (quantizedUnix / EphemerisConstants.secondsPerDay)
        // Use fixed analytical DeltaT from quantized JD so both peers evaluate identical TT
        let epoch = JulianEpoch(jdUTC: jdUTC)
        let snapshot = try EphemerisSkySnapshot.compute(epoch: epoch, observer: effectiveObserver)
        let gmstQuant = Int64((snapshot.gmstDegrees * 36_000.0).rounded())

        // Sort participating bodies canonically by case order for deterministic framing
        let orderedBodies = CelestialBody.allCases.filter { config.participatingBodies.contains($0) }
        var records = [QuantizedBodyStateRecord]()
        records.reserveCapacity(orderedBodies.count)

        for body in orderedBodies {
            guard let entry = snapshot.ephemeris(for: body) else { continue }
            let lonQ = Int64((entry.geocentricEcliptic.longitudeDeg * 36_000.0).rounded())
            let latQ = Int64((entry.geocentricEcliptic.latitudeDeg * 36_000.0).rounded())
            let distQ = Int64((entry.geocentricEcliptic.distanceAU * 10_000_000.0).rounded())

            let azQ: Int32?
            let altQ: Int32?
            if config.bindObserverGeodeticCell {
                azQ = Int32((entry.topocentricHorizontal.azimuthDeg * 100.0).rounded())
                altQ = Int32((entry.topocentricHorizontal.trueAltitudeDeg * 100.0).rounded())
            } else {
                azQ = nil
                altQ = nil
            }

            records.append(
                QuantizedBodyStateRecord(
                    body: body,
                    eclipticLonDeciArcsec: lonQ,
                    eclipticLatDeciArcsec: latQ,
                    distanceSubAU: distQ,
                    topocentricAzCentideg: azQ,
                    topocentricAltCentideg: altQ
                )
            )
        }

        let binary = encodeCanonicalFrame(
            version: EphemerisAuthConfiguration.wireProtocolVersion,
            namespace: config.domainNamespace,
            stepIndex: stepIndex,
            epochStepSeconds: config.epochStepSeconds,
            gmstDeciArcsec: gmstQuant,
            geodeticCell: qCell,
            records: records
        )
        let commitment = SHA512Engine.hash(binary)

        return CelestialStateFrame(
            protocolVersion: EphemerisAuthConfiguration.wireProtocolVersion,
            epochStepIndex: stepIndex,
            quantizedUnixTimestamp: quantizedUnix,
            julianDateUTC: jdUTC,
            gmstDeciArcsec: gmstQuant,
            geodeticCell: qCell,
            bodyRecords: records,
            canonicalBinaryFrame: binary,
            skyCommitmentSHA512: commitment
        )
    }

    private static func encodeCanonicalFrame(
        version: UInt8,
        namespace: String,
        stepIndex: Int64,
        epochStepSeconds: Int,
        gmstDeciArcsec: Int64,
        geodeticCell: QuantizedGeodeticCell?,
        records: [QuantizedBodyStateRecord]
    ) -> [UInt8] {
        var out = [UInt8]()
        out.reserveCapacity(128 + records.count * 36)
        out.append(contentsOf: [0x45, 0x50, 0x48, 0x33]) // "EPH3"
        out.append(version)

        let nsBytes = Array(namespace.utf8)
        appendBE32(UInt32(nsBytes.count), to: &out)
        out.append(contentsOf: nsBytes)

        appendBE64(UInt64(bitPattern: stepIndex), to: &out)
        appendBE32(UInt32(epochStepSeconds), to: &out)
        appendBE64(UInt64(bitPattern: gmstDeciArcsec), to: &out)

        if let cell = geodeticCell {
            out.append(0x01)
            appendBE32(UInt32(bitPattern: cell.latCellIndex), to: &out)
            appendBE32(UInt32(bitPattern: cell.lonCellIndex), to: &out)
        } else {
            out.append(0x00)
        }

        appendBE32(UInt32(records.count), to: &out)
        for rec in records {
            let nameUTF8 = Array(rec.body.rawValue.utf8)
            out.append(UInt8(truncatingIfNeeded: nameUTF8.count))
            out.append(contentsOf: nameUTF8)
            appendBE64(UInt64(bitPattern: rec.eclipticLonDeciArcsec), to: &out)
            appendBE64(UInt64(bitPattern: rec.eclipticLatDeciArcsec), to: &out)
            appendBE64(UInt64(bitPattern: rec.distanceSubAU), to: &out)
            if let az = rec.topocentricAzCentideg, let alt = rec.topocentricAltCentideg {
                out.append(0x01)
                appendBE32(UInt32(bitPattern: az), to: &out)
                appendBE32(UInt32(bitPattern: alt), to: &out)
            } else {
                out.append(0x00)
            }
        }
        return out
    }

    @inline(__always)
    internal static func appendBE32(_ value: UInt32, to buffer: inout [UInt8]) {
        buffer.append(UInt8(truncatingIfNeeded: value >> 24))
        buffer.append(UInt8(truncatingIfNeeded: value >> 16))
        buffer.append(UInt8(truncatingIfNeeded: value >> 8))
        buffer.append(UInt8(truncatingIfNeeded: value))
    }

    @inline(__always)
    internal static func appendBE64(_ value: UInt64, to buffer: inout [UInt8]) {
        for shift in stride(from: 56, through: 0, by: -8) {
            buffer.append(UInt8(truncatingIfNeeded: value >> shift))
        }
    }
}

// MARK: - Ephemeral Celestial Session Keys, Celestial-TOTP & Signed AEAD Envelopes

public struct CelestialSessionKey: Codable, Equatable, Sendable {
    public let sessionKeyID: String
    public let epochStepIndex: Int64
    public let expiresAtUnixTimestamp: TimeInterval
    public let encryptionKey32: [UInt8]
    public let authenticationKey64: [UInt8]
    public let baseNonce12: [UInt8]
    public let skyCommitmentSHA512: [UInt8]

    public var skyCommitmentHex: String {
        HexCodec.encode(skyCommitmentSHA512)
    }
}

public struct CelestialTOTPCode: Codable, Equatable, Hashable, Sendable {
    public let code: String
    public let digits: Int
    public let epochStepIndex: Int64
    public let validFromUnix: TimeInterval
    public let validUntilUnix: TimeInterval
    public let sessionKeyID: String
    public let skyCommitmentPrefixHex: String
}

public struct CelestialAuthEnvelope: Codable, Equatable, Hashable, Sendable {
    public let protocolVersion: UInt8
    public let epochStepIndex: Int64
    public let sessionKeyID: String
    public let skyCommitmentSHA512: [UInt8]
    public let clientSalt12: [UInt8]
    public let sealedPayload: SealedBox
    public let envelopeConfirmationMAC: [UInt8]

    public init(
        protocolVersion: UInt8,
        epochStepIndex: Int64,
        sessionKeyID: String,
        skyCommitmentSHA512: [UInt8],
        clientSalt12: [UInt8],
        sealedPayload: SealedBox,
        envelopeConfirmationMAC: [UInt8]
    ) {
        self.protocolVersion = protocolVersion
        self.epochStepIndex = epochStepIndex
        self.sessionKeyID = sessionKeyID
        self.skyCommitmentSHA512 = skyCommitmentSHA512
        self.clientSalt12 = clientSalt12
        self.sealedPayload = sealedPayload
        self.envelopeConfirmationMAC = envelopeConfirmationMAC
    }
}

public struct CelestialVerificationOutcome: Codable, Equatable, Sendable {
    public let isAuthenticated: Bool
    public let matchedEpochStepIndex: Int64
    public let clockSkewSteps: Int
    public let sessionKeyID: String
    public let decryptedPayload: [UInt8]

    public var decryptedUTF8: String? {
        String(bytes: decryptedPayload, encoding: .utf8)
    }
}

public enum EphemerisEntropyProtocol {
    public static let minimumSecretSeedBytes = 16

    /// Derives a forward-ephemeral `CelestialSessionKey` binding a shared secret seed to the
    /// multi-body quantized `CelestialStateFrame` via domain-separated `HKDF-SHA512`.
    public static func deriveSessionKey(
        sharedSecretSeed: [UInt8],
        unixTimestamp: TimeInterval,
        observer: GeodeticObserver? = nil,
        config: EphemerisAuthConfiguration = .standardGeocentric60s
    ) throws -> CelestialSessionKey {
        guard sharedSecretSeed.count >= minimumSecretSeedBytes else {
            throw EphemerisProtocolError.secretSeedTooShort(
                actualBytes: sharedSecretSeed.count,
                minimumBytes: minimumSecretSeedBytes
            )
        }
        let frame = try CelestialStateFrame.capture(
            unixTimestamp: unixTimestamp,
            observer: observer,
            config: config
        )
        return try deriveSessionKey(sharedSecretSeed: sharedSecretSeed, frame: frame, config: config)
    }

    public static func deriveSessionKey(
        sharedSecretSeed: [UInt8],
        frame: CelestialStateFrame,
        config: EphemerisAuthConfiguration = .standardGeocentric60s
    ) throws -> CelestialSessionKey {
        guard sharedSecretSeed.count >= minimumSecretSeedBytes else {
            throw EphemerisProtocolError.secretSeedTooShort(
                actualBytes: sharedSecretSeed.count,
                minimumBytes: minimumSecretSeedBytes
            )
        }

        // Mix shared secret with canonical celestial binary frame in IKM and commitment in HKDF salt
        var ikm = [UInt8]()
        ikm.reserveCapacity(sharedSecretSeed.count + frame.canonicalBinaryFrame.count)
        ikm.append(contentsOf: sharedSecretSeed)
        ikm.append(contentsOf: frame.canonicalBinaryFrame)

        let tree = HKDFKeyHierarchy(
            ikm: ikm,
            salt: frame.skyCommitmentSHA512,
            prf: .hmacSHA512,
            namespacePrefix: config.domainNamespace + "."
        )

        let encKey = try tree.expandLabeled(
            label: "aead.chacha20poly1305.key",
            context: frame.skyCommitmentSHA512,
            outputByteCount: 32
        )
        let authKey = try tree.expandLabeled(
            label: "mac.hmacsha512.key",
            context: frame.skyCommitmentSHA512,
            outputByteCount: 64
        )
        let baseNonce = try tree.expandLabeled(
            label: "aead.base.nonce12",
            context: [],
            outputByteCount: 12
        )
        let keyIDBytes = try tree.expandLabeled(
            label: "public.session.id",
            context: [],
            outputByteCount: 8
        )

        let expiresAt = Double(frame.epochStepIndex + 1) * Double(config.epochStepSeconds)

        return CelestialSessionKey(
            sessionKeyID: HexCodec.encode(keyIDBytes),
            epochStepIndex: frame.epochStepIndex,
            expiresAtUnixTimestamp: expiresAt,
            encryptionKey32: encKey,
            authenticationKey64: authKey,
            baseNonce12: baseNonce,
            skyCommitmentSHA512: frame.skyCommitmentSHA512
        )
    }

    /// Generates an 8-digit (or configured 6..8 digit) Celestial-TOTP token bound to the solar-system sky state.
    public static func generateCelestialTOTP(
        sharedSecretSeed: [UInt8],
        unixTimestamp: TimeInterval,
        observer: GeodeticObserver? = nil,
        config: EphemerisAuthConfiguration = .standardGeocentric60s
    ) throws -> CelestialTOTPCode {
        let frame = try CelestialStateFrame.capture(
            unixTimestamp: unixTimestamp,
            observer: observer,
            config: config
        )
        let session = try deriveSessionKey(sharedSecretSeed: sharedSecretSeed, frame: frame, config: config)
        let counter = UInt64(bitPattern: frame.epochStepIndex)
        let code = try HOTPGenerator.generate(
            secret: session.authenticationKey64,
            counter: counter,
            digits: config.totpDigits,
            prf: .hmacSHA512
        )
        let validFrom = Double(frame.epochStepIndex) * Double(config.epochStepSeconds)
        return CelestialTOTPCode(
            code: code,
            digits: config.totpDigits,
            epochStepIndex: frame.epochStepIndex,
            validFromUnix: validFrom,
            validUntilUnix: session.expiresAtUnixTimestamp,
            sessionKeyID: session.sessionKeyID,
            skyCommitmentPrefixHex: String(session.skyCommitmentHex.prefix(16))
        )
    }

    /// Verifies a Celestial-TOTP code across the `±allowedClockSkewSteps` celestial epoch window
    /// without early-exit timing leaks.
    public static func verifyCelestialTOTP(
        candidateCode: String,
        sharedSecretSeed: [UInt8],
        verifierUnixTimestamp: TimeInterval,
        observer: GeodeticObserver? = nil,
        config: EphemerisAuthConfiguration = .standardGeocentric60s
    ) throws -> OTPVerificationMatch {
        guard sharedSecretSeed.count >= minimumSecretSeedBytes else {
            throw EphemerisProtocolError.secretSeedTooShort(
                actualBytes: sharedSecretSeed.count,
                minimumBytes: minimumSecretSeedBytes
            )
        }
        let normalizedCode = candidateCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseStep = Int64(floor(verifierUnixTimestamp / Double(config.epochStepSeconds)))
        let skew = config.allowedClockSkewSteps

        var matchedStep: UInt64?
        var matchedDelta: Int?

        for delta in (-skew)...skew {
            let stepIdx = baseStep + Int64(delta)
            let frame = try CelestialStateFrame.captureForStepIndex(
                stepIndex: stepIdx,
                observer: observer,
                config: config
            )
            let session = try deriveSessionKey(sharedSecretSeed: sharedSecretSeed, frame: frame, config: config)
            let expected = try HOTPGenerator.generate(
                secret: session.authenticationKey64,
                counter: UInt64(bitPattern: stepIdx),
                digits: config.totpDigits,
                prf: .hmacSHA512
            )
            if ConstantTime.equalStrings(expected, normalizedCode) && matchedStep == nil {
                matchedStep = UInt64(bitPattern: stepIdx)
                matchedDelta = delta
            }
        }

        if let matchedStep {
            return OTPVerificationMatch(isValid: true, matchedCounter: matchedStep, stepOffset: matchedDelta)
        }
        return OTPVerificationMatch(isValid: false, matchedCounter: nil, stepOffset: nil)
    }

    /// Seals a challenge/command payload inside a `CelestialAuthEnvelope` protected by both
    /// ChaCha20-Poly1305 AEAD and an outer HMAC-SHA512 key-confirmation tag.
    public static func sealEnvelope(
        payload: [UInt8],
        sharedSecretSeed: [UInt8],
        unixTimestamp: TimeInterval,
        observer: GeodeticObserver? = nil,
        clientSalt12: [UInt8]? = nil,
        contextAAD: [UInt8] = [],
        config: EphemerisAuthConfiguration = .standardGeocentric60s
    ) throws -> CelestialAuthEnvelope {
        let frame = try CelestialStateFrame.capture(
            unixTimestamp: unixTimestamp,
            observer: observer,
            config: config
        )
        let session = try deriveSessionKey(sharedSecretSeed: sharedSecretSeed, frame: frame, config: config)

        let salt12: [UInt8]
        if let clientSalt12, clientSalt12.count == 12 {
            salt12 = clientSalt12
        } else {
            var drbg = ChaCha20DRBG.seededFromSystemEntropy(additionalEntropy: frame.skyCommitmentSHA512)
            salt12 = drbg.generateBytes(count: 12)
        }

        var effectiveNonce = [UInt8](repeating: 0, count: 12)
        for idx in 0..<12 {
            effectiveNonce[idx] = session.baseNonce12[idx] ^ salt12[idx]
        }

        let envelopeAAD = buildEnvelopeAAD(
            protocolVersion: EphemerisAuthConfiguration.wireProtocolVersion,
            epochStepIndex: frame.epochStepIndex,
            skyCommitment: frame.skyCommitmentSHA512,
            clientSalt12: salt12,
            contextAAD: contextAAD
        )

        let box = try ChaCha20Poly1305AEAD.seal(
            plaintext: payload,
            key: session.encryptionKey32,
            nonce: effectiveNonce,
            aad: envelopeAAD
        )

        var macInput = envelopeAAD
        macInput.append(contentsOf: box.combinedWireBytes())
        let confirmMAC = HMACSHA512.authenticate(message: macInput, key: session.authenticationKey64)

        return CelestialAuthEnvelope(
            protocolVersion: EphemerisAuthConfiguration.wireProtocolVersion,
            epochStepIndex: frame.epochStepIndex,
            sessionKeyID: session.sessionKeyID,
            skyCommitmentSHA512: frame.skyCommitmentSHA512,
            clientSalt12: salt12,
            sealedPayload: box,
            envelopeConfirmationMAC: confirmMAC
        )
    }

    /// Verifies clock-skew bounds, recomputes the multi-body celestial state for the envelope's epoch step,
    /// verifies the sky commitment + outer HMAC-SHA512 + ChaCha20-Poly1305 AEAD tag, and opens the payload.
    public static func openAndVerifyEnvelope(
        _ envelope: CelestialAuthEnvelope,
        sharedSecretSeed: [UInt8],
        verifierUnixTimestamp: TimeInterval,
        observer: GeodeticObserver? = nil,
        contextAAD: [UInt8] = [],
        config: EphemerisAuthConfiguration = .standardGeocentric60s
    ) throws -> CelestialVerificationOutcome {
        guard envelope.protocolVersion == EphemerisAuthConfiguration.wireProtocolVersion else {
            throw EphemerisProtocolError.unsupportedProtocolVersion(envelope.protocolVersion)
        }
        guard envelope.clientSalt12.count == 12 else {
            throw ChaChaPolyError.invalidNonceLength(expected: 12, actual: envelope.clientSalt12.count)
        }

        let verifierStep = Int64(floor(verifierUnixTimestamp / Double(config.epochStepSeconds)))
        let stepDiff64 = envelope.epochStepIndex - verifierStep
        guard abs(stepDiff64) <= Int64(config.allowedClockSkewSteps) else {
            throw EphemerisProtocolError.clockSkewExceeded(
                envelopeStep: envelope.epochStepIndex,
                verifierStep: verifierStep,
                maxAllowedSkew: config.allowedClockSkewSteps
            )
        }

        let recomputedFrame = try CelestialStateFrame.captureForStepIndex(
            stepIndex: envelope.epochStepIndex,
            observer: observer,
            config: config
        )
        guard ConstantTime.equal(recomputedFrame.skyCommitmentSHA512, envelope.skyCommitmentSHA512) else {
            throw EphemerisProtocolError.skyCommitmentMismatch
        }

        let session = try deriveSessionKey(
            sharedSecretSeed: sharedSecretSeed,
            frame: recomputedFrame,
            config: config
        )

        let envelopeAAD = buildEnvelopeAAD(
            protocolVersion: envelope.protocolVersion,
            epochStepIndex: envelope.epochStepIndex,
            skyCommitment: recomputedFrame.skyCommitmentSHA512,
            clientSalt12: envelope.clientSalt12,
            contextAAD: contextAAD
        )

        var macInput = envelopeAAD
        macInput.append(contentsOf: envelope.sealedPayload.combinedWireBytes())
        guard HMACSHA512.verify(
            tag: envelope.envelopeConfirmationMAC,
            message: macInput,
            key: session.authenticationKey64
        ) else {
            throw EphemerisProtocolError.envelopeMACVerificationFailed
        }

        let plaintext: [UInt8]
        do {
            plaintext = try ChaCha20Poly1305AEAD.open(
                sealedBox: envelope.sealedPayload,
                key: session.encryptionKey32,
                aad: envelopeAAD
            )
        } catch {
            throw EphemerisProtocolError.envelopeAEADDecryptionFailed
        }

        return CelestialVerificationOutcome(
            isAuthenticated: true,
            matchedEpochStepIndex: envelope.epochStepIndex,
            clockSkewSteps: Int(stepDiff64),
            sessionKeyID: session.sessionKeyID,
            decryptedPayload: plaintext
        )
    }

    private static func buildEnvelopeAAD(
        protocolVersion: UInt8,
        epochStepIndex: Int64,
        skyCommitment: [UInt8],
        clientSalt12: [UInt8],
        contextAAD: [UInt8]
    ) -> [UInt8] {
        var aad = [UInt8]()
        aad.reserveCapacity(1 + 8 + skyCommitment.count + clientSalt12.count + 4 + contextAAD.count)
        aad.append(protocolVersion)
        CelestialStateFrame.appendBE64(UInt64(bitPattern: epochStepIndex), to: &aad)
        aad.append(contentsOf: skyCommitment)
        aad.append(contentsOf: clientSalt12)
        CelestialStateFrame.appendBE32(UInt32(contextAAD.count), to: &aad)
        aad.append(contentsOf: contextAAD)
        return aad
    }
}

// MARK: - Shannon Bit-Density & NIST SP 800-90B Min-Entropy Estimator

public struct EntropyQualityReport: Codable, Equatable, Hashable, Sendable {
    public let sampleByteCount: Int
    /// Empirical Shannon entropy `H_1` in `[0.0, 8.0]` bits per byte.
    public let shannonBitsPerByte: Double
    /// Normalized bit density `H_1 / 8.0` in `[0.0, 1.0]`.
    public let normalizedBitDensity: Double
    /// NIST SP 800-90B min-entropy `H_inf = -log2(max_i p_i)` in `[0.0, 8.0]` bits per byte.
    public let minEntropyBitsPerByte: Double
    /// Fraction of `1` bits across the entire sample (`0.5` is ideal monobit balance).
    public let hammingOnesRatio: Double
    /// Lag-1 serial byte correlation coefficient in `[-1.0, +1.0]` (`0.0` is ideal independence).
    public let serialCorrelationLag1: Double
    /// Pearson Chi-Square statistic over 256 byte bins (`df = 255`, ideal mean `~255`).
    public let chiSquareStatistic: Double
    public let distinctByteSymbolsObserved: Int
    public let passesCryptographicUniformityHeuristic: Bool
}

public enum EphemerisEntropyEstimator {
    public static func analyzeBytes(_ bytes: [UInt8]) -> EntropyQualityReport {
        guard !bytes.isEmpty else {
            return EntropyQualityReport(
                sampleByteCount: 0,
                shannonBitsPerByte: 0.0,
                normalizedBitDensity: 0.0,
                minEntropyBitsPerByte: 0.0,
                hammingOnesRatio: 0.0,
                serialCorrelationLag1: 0.0,
                chiSquareStatistic: 0.0,
                distinctByteSymbolsObserved: 0,
                passesCryptographicUniformityHeuristic: false
            )
        }

        var counts = [Int](repeating: 0, count: 256)
        var totalOneBits = 0
        for b in bytes {
            counts[Int(b)] += 1
            totalOneBits += b.nonzeroBitCount
        }

        let n = Double(bytes.count)
        let expectedPerBin = n / 256.0
        var shannon = 0.0
        var maxProb = 0.0
        var chiSq = 0.0
        var distinct = 0

        for freq in counts {
            if freq > 0 {
                distinct += 1
                let p = Double(freq) / n
                shannon -= p * log2(p)
                if p > maxProb {
                    maxProb = p
                }
            }
            let diff = Double(freq) - expectedPerBin
            if expectedPerBin > 0 {
                chiSq += (diff * diff) / expectedPerBin
            }
        }

        let minEntropy = (maxProb > 0.0) ? max(0.0, -log2(maxProb)) : 0.0
        let onesRatio = Double(totalOneBits) / Double(bytes.count * 8)
        let serialCorr = computeLag1SerialCorrelation(bytes)

        let passes: Bool
        if bytes.count >= 256 {
            passes = (shannon >= 7.1)
                && (abs(onesRatio - 0.5) <= 0.06)
                && (abs(serialCorr) <= 0.15)
        } else {
            passes = (shannon >= 4.2)
                && (abs(onesRatio - 0.5) <= 0.12)
        }

        return EntropyQualityReport(
            sampleByteCount: bytes.count,
            shannonBitsPerByte: shannon,
            normalizedBitDensity: min(1.0, max(0.0, shannon / 8.0)),
            minEntropyBitsPerByte: minEntropy,
            hammingOnesRatio: onesRatio,
            serialCorrelationLag1: serialCorr,
            chiSquareStatistic: chiSq,
            distinctByteSymbolsObserved: distinct,
            passesCryptographicUniformityHeuristic: passes
        )
    }

    /// Samples `epochCount` consecutive celestial session keys and evaluates aggregate keystream entropy quality.
    public static func benchmarkCelestialKeyStream(
        sharedSecretSeed: [UInt8],
        startUnixTimestamp: TimeInterval,
        epochCount: Int = 16,
        observer: GeodeticObserver? = nil,
        config: EphemerisAuthConfiguration = .standardGeocentric60s
    ) throws -> EntropyQualityReport {
        let clampedEpochs = max(1, min(256, epochCount))
        var stream = [UInt8]()
        stream.reserveCapacity(clampedEpochs * 96)

        for idx in 0..<clampedEpochs {
            let ts = startUnixTimestamp + Double(idx * config.epochStepSeconds)
            let session = try EphemerisEntropyProtocol.deriveSessionKey(
                sharedSecretSeed: sharedSecretSeed,
                unixTimestamp: ts,
                observer: observer,
                config: config
            )
            stream.append(contentsOf: session.encryptionKey32)
            stream.append(contentsOf: session.authenticationKey64)
        }
        return analyzeBytes(stream)
    }

    private static func computeLag1SerialCorrelation(_ bytes: [UInt8]) -> Double {
        guard bytes.count >= 2 else { return 0.0 }
        let n = Double(bytes.count)
        var sumX = 0.0
        var sumX2 = 0.0
        var sumCross = 0.0

        for idx in 0..<bytes.count {
            let x = Double(bytes[idx])
            let y = Double(bytes[(idx + 1) % bytes.count])
            sumX += x
            sumX2 += x * x
            sumCross += x * y
        }

        let denom = n * sumX2 - sumX * sumX
        guard abs(denom) > 1.0e-12 else { return 0.0 }
        let numer = n * sumCross - sumX * sumX
        return max(-1.0, min(1.0, numer / denom))
    }
}

// MARK: - Production Swift 6 EphemerisAuthenticator Code Synthesizer

public enum EphemerisAuthenticatorCodeSynthesizer {
    /// Synthesizes production-ready Swift 6 strict-concurrency actor code implementing replay-protected
    /// `EphemerisAuthenticator` backed by `ChiefKitSecurity`.
    public static func synthesizeSwift6ActorSource(
        actorName: String = "CelestialSessionAuthenticator",
        config: EphemerisAuthConfiguration = .standardGeocentric60s
    ) -> String {
        let bodyLiterals = config.participatingBodies
            .map { ".\(swiftEnumCaseName(for: $0))" }
            .joined(separator: ", ")

        return """
        import ChiefKitSecurity
        import Foundation

        /// Generated by ChiefKit Studio 3.0 — HNMLabs EphemerisCore Celestial-Temporal Authenticator
        public actor \(actorName) {
            public enum VerificationFailure: Error, Sendable, Equatable {
                case invalidToken
                case replayedEpochStep(UInt64)
            }

            private let sharedSecretSeed: [UInt8]
            private let configuration: EphemerisAuthConfiguration
            private let defaultObserver: GeodeticObserver?
            private var consumedCounters: Set<UInt64> = []

            public init(
                sharedSecretSeed: [UInt8],
                defaultObserver: GeodeticObserver? = nil
            ) throws {
                self.sharedSecretSeed = sharedSecretSeed
                self.defaultObserver = defaultObserver
                self.configuration = try EphemerisAuthConfiguration(
                    epochStepSeconds: \(config.epochStepSeconds),
                    allowedClockSkewSteps: \(config.allowedClockSkewSteps),
                    participatingBodies: [\(bodyLiterals)],
                    bindObserverGeodeticCell: \(config.bindObserverGeodeticCell),
                    observerCellResolutionDeg: \(config.observerCellResolutionDeg),
                    totpDigits: \(config.totpDigits),
                    domainNamespace: "\(config.domainNamespace)"
                )
            }

            public func issueCurrentToken(now: Date = Date()) throws -> CelestialTOTPCode {
                try EphemerisEntropyProtocol.generateCelestialTOTP(
                    sharedSecretSeed: sharedSecretSeed,
                    unixTimestamp: now.timeIntervalSince1970,
                    observer: defaultObserver,
                    config: configuration
                )
            }

            public func verifyOneTimeToken(
                _ candidateCode: String,
                now: Date = Date()
            ) throws -> OTPVerificationMatch {
                let match = try EphemerisEntropyProtocol.verifyCelestialTOTP(
                    candidateCode: candidateCode,
                    sharedSecretSeed: sharedSecretSeed,
                    verifierUnixTimestamp: now.timeIntervalSince1970,
                    observer: defaultObserver,
                    config: configuration
                )
                guard match.isValid, let counter = match.matchedCounter else {
                    throw VerificationFailure.invalidToken
                }
                guard !consumedCounters.contains(counter) else {
                    throw VerificationFailure.replayedEpochStep(counter)
                }
                consumedCounters.insert(counter)
                pruneExpiredReplayWindow(currentUnix: now.timeIntervalSince1970)
                return match
            }

            public func sealCommand(
                _ payload: Data,
                contextAAD: Data = Data(),
                now: Date = Date()
            ) throws -> CelestialAuthEnvelope {
                try EphemerisEntropyProtocol.sealEnvelope(
                    payload: Array(payload),
                    sharedSecretSeed: sharedSecretSeed,
                    unixTimestamp: now.timeIntervalSince1970,
                    observer: defaultObserver,
                    contextAAD: Array(contextAAD),
                    config: configuration
                )
            }

            public func openCommand(
                _ envelope: CelestialAuthEnvelope,
                contextAAD: Data = Data(),
                now: Date = Date()
            ) throws -> Data {
                let outcome = try EphemerisEntropyProtocol.openAndVerifyEnvelope(
                    envelope,
                    sharedSecretSeed: sharedSecretSeed,
                    verifierUnixTimestamp: now.timeIntervalSince1970,
                    observer: defaultObserver,
                    contextAAD: Array(contextAAD),
                    config: configuration
                )
                return Data(outcome.decryptedPayload)
            }

            private func pruneExpiredReplayWindow(currentUnix: TimeInterval) {
                let minStep = Int64(floor(currentUnix / Double(configuration.epochStepSeconds)))
                    - Int64(configuration.allowedClockSkewSteps + 2)
                if minStep > 0 {
                    let threshold = UInt64(minStep)
                    consumedCounters = consumedCounters.filter { $0 >= threshold }
                }
            }
        }
        """
    }

    private static func swiftEnumCaseName(for body: CelestialBody) -> String {
        switch body {
        case .sun: return "sun"
        case .moon: return "moon"
        case .mercury: return "mercury"
        case .venus: return "venus"
        case .earthMoonBarycenter: return "earthMoonBarycenter"
        case .mars: return "mars"
        case .jupiter: return "jupiter"
        case .saturn: return "saturn"
        case .uranus: return "uranus"
        case .neptune: return "neptune"
        }
    }
}
