#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitSecurity
import ChiefKitStudioCore
import SwiftUI

struct SecurityEphemerisStudioView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    private enum SecurityArtifactTab: String, CaseIterable, Identifiable {
        case ephemerisActor = "Celestial Auth Actor"
        case privacyPlist = "PrivacyInfo.xcprivacy"
        case keychainActor = "Hardware Keychain Actor"
        case regressionTests = "Security @Test Suite"

        var id: String { rawValue }
    }

    @State private var latitudeDeg: Double = 41.0082
    @State private var longitudeDeg: Double = 28.9784
    @State private var elevationMeters: Double = 40.0
    @State private var snapshotDate = Date()
    @State private var bindGeodeticCell = true

    @State private var vaultPassphrase = "chiefkit-quantum-safe-vault"
    @State private var vaultPlaintext = "master_signing_seed=CK3-EPHEMERIS-VAULT-2026"
    @State private var selectedCipherSuite: VaultCipherSuite = .xchacha20Poly1305
    @State private var vaultStatusSummary = "Ready to seal XChaCha20-Poly1305 .chiefkit.vault & split GF(256) Shamir shares."
    @State private var generatedShamirTokens: [String] = []
    @State private var selectedArtifactTab: SecurityArtifactTab = .ephemerisActor

    private var activeAuthConfig: EphemerisAuthConfiguration {
        bindGeodeticCell ? .highSecurityGeodetic30s : .standardGeocentric60s
    }

    private var resolvedObserver: GeodeticObserver {
        let clampedLat = min(89.9, max(-89.9, latitudeDeg))
        let clampedLon = min(180.0, max(-180.0, longitudeDeg))
        return (try? GeodeticObserver(
            latitudeDeg: clampedLat,
            longitudeDeg: clampedLon,
            elevationMeters: elevationMeters
        )) ?? .greenwichPrimeMeridian
    }

    var body: some View {
        let selfTest = SecuritySelfTest.runDetailedSelfTest()

        VStack(alignment: .leading, spacing: 16) {
            ephemerisObservatoryAndTOTPCard
            vaultAndShamirLabCard(selfTest: selfTest)
            owaspScorecardAndPrivacyCard
            synthesizedSecurityArtifactsCard
        }
    }

    // MARK: - 1. EphemerisCore Planetary Observatory & Celestial-TOTP

    private var ephemerisObservatoryAndTOTPCard: some View {
        let observer = resolvedObserver
        let epoch = JulianEpoch(utcDate: snapshotDate)
        let sky = try? EphemerisSkySnapshot.compute(epoch: epoch, observer: observer)
        let seedBytes = Array("ChiefKit-Studio-3.0-Celestial-Shared-Seed".utf8)
        let totp = try? EphemerisEntropyProtocol.generateCelestialTOTP(
            sharedSecretSeed: seedBytes,
            unixTimestamp: snapshotDate.timeIntervalSince1970,
            observer: observer,
            config: activeAuthConfig
        )
        let envelopeCheck: Bool = {
            guard let env = try? EphemerisEntropyProtocol.sealEnvelope(
                payload: Array("ephemeris-handshake-ok".utf8),
                sharedSecretSeed: seedBytes,
                unixTimestamp: snapshotDate.timeIntervalSince1970,
                observer: observer,
                config: activeAuthConfig
            ),
            let outcome = try? EphemerisEntropyProtocol.openAndVerifyEnvelope(
                env,
                sharedSecretSeed: seedBytes,
                verifierUnixTimestamp: snapshotDate.timeIntervalSince1970,
                observer: observer,
                config: activeAuthConfig
            ) else {
                return false
            }
            return outcome.isAuthenticated
        }()

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "EphemerisCore 9-Body Sky Snapshot & Celestial-TOTP Protocol",
                        subtitle: "JPL orbital mechanics + geodetic topocentric coordinates bound into SHA-512 session keys."
                    )
                    Spacer()
                    Button {
                        snapshotDate = Date()
                        viewModel.statusMessage = "Refreshed EphemerisCore sky snapshot & Celestial-TOTP frame"
                    } label: {
                        Label("Refresh UTC Epoch", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                HStack(spacing: 8) {
                    cityPresetButton("Istanbul", lat: 41.0082, lon: 28.9784)
                    cityPresetButton("Greenwich", lat: 51.4769, lon: 0.0000)
                    cityPresetButton("Cupertino", lat: 37.3346, lon: -122.0090)
                    cityPresetButton("Tokyo", lat: 35.6762, lon: 139.6503)

                    Spacer()

                    Toggle("Bind 0.25° Geodetic Cell", isOn: $bindGeodeticCell)
                        .font(.caption)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("Lat")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $latitudeDeg, in: -65.0...65.0)
                            .frame(width: 110)
                        Text(String(format: "%.2f°", latitudeDeg))
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 52, alignment: .trailing)
                    }
                    HStack(spacing: 4) {
                        Text("Lon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $longitudeDeg, in: -180.0...180.0)
                            .frame(width: 110)
                        Text(String(format: "%.2f°", longitudeDeg))
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 58, alignment: .trailing)
                    }
                    Spacer()
                    Text(String(format: "JD %.4f · ΔT %.1fs", epoch.jd, epoch.deltaTSeconds))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if let totp {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CELESTIAL-TOTP (\(totp.digits)-DIGIT)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(totp.code)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundStyle(theme.primary.swiftUIColor)
                        }
                        Divider().frame(height: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Session Key ID: \(totp.sessionKeyID)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Text("Sky SHA-512 Prefix: \(totp.skyCommitmentPrefixHex)")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        PillLabel(
                            title: envelopeCheck ? "AEAD Envelope Verified" : "Envelope Error",
                            systemImage: envelopeCheck ? "lock.shield.fill" : "xmark.octagon"
                        )
                    }
                    .padding(10)
                    .background(theme.primary.swiftUIColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                }

                if let sky {
                    HStack {
                        Text("\(sky.moon.phaseName.emojiSymbol) Moon: \(sky.moon.phaseName.rawValue) (\(Int(sky.moon.illuminatedFraction * 100))% lit, \(Int(sky.moon.geocentricDistanceKm)) km)")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text(String(format: "GMST %.2f° · LMST %.2f° · Aspects: %d", sky.gmstDegrees, sky.lmstDegrees, sky.activeAspects.count))
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(sky.bodies, id: \.body) { item in
                            HStack(spacing: 8) {
                                Text("\(item.body.astronomicalSymbol) \(item.body.rawValue)")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .frame(width: 155, alignment: .leading)
                                Text(String(format: "λ %6.2f°", item.geocentricEcliptic.longitudeDeg))
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 82, alignment: .leading)
                                Text("RA \(item.apparentEquatorial.hms.formatted)")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "Alt %+5.1f° · Az %5.1f°", item.topocentricHorizontal.apparentAltitudeDeg, item.topocentricHorizontal.azimuthDeg))
                                    .font(.system(size: 11, design: .monospaced))
                                Text(item.topocentricHorizontal.isAboveApparentHorizon ? "ABOVE" : "BELOW")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(item.topocentricHorizontal.isAboveApparentHorizon ? theme.success.swiftUIColor : .secondary)
                                    .frame(width: 44, alignment: .trailing)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 2. ChaCha20-Poly1305 `.chiefkit.vault` & Shamir GF(256) 3-of-5 Lab

    private func vaultAndShamirLabCard(selfTest: SecuritySelfTestReport) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "XChaCha20-Poly1305 `.chiefkit.vault` & Shamir GF(256) 3-of-5 Recovery",
                        subtitle: "Pure-Swift RFC 8439 AEAD encryption, PBKDF2 key stretching, and Galois Field secret splitting."
                    )
                    Spacer()
                    PillLabel(
                        title: selfTest.allPassed ? "RFC Vectors \(selfTest.checks.count)/\(selfTest.checks.count) PASS" : "Vector Fault",
                        systemImage: "checkmark.shield.fill"
                    )
                }

                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        Text("Cipher Suite")
                            .font(.caption.weight(.semibold))
                        Picker("Cipher", selection: $selectedCipherSuite) {
                            ForEach(VaultCipherSuite.allCases, id: \.self) { suite in
                                Text(suite.rawValue).tag(suite)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                    }
                    GridRow {
                        Text("Passphrase")
                            .font(.caption.weight(.semibold))
                        TextField("Vault passphrase…", text: $vaultPassphrase)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    GridRow {
                        Text("Secret Payload")
                            .font(.caption.weight(.semibold))
                        TextField("Confidential secret…", text: $vaultPlaintext)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        runSealOpenAndShamirDemo()
                    } label: {
                        Label("Seal Vault + Split 3-of-5 Shamir Shares", systemImage: "key.radiowaves.forward.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)

                    Text(vaultStatusSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !generatedShamirTokens.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shamir GF(256) Recovery Shares (Any 3 of 5 Reconstruct Exact Secret):")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(generatedShamirTokens.enumerated()), id: \.offset) { idx, token in
                            HStack {
                                Text("Share #\(idx + 1)")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(theme.primary.swiftUIColor)
                                Text(token)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                        }
                    }
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. 30-Rule Static Security Scanner & OWASP Mobile Top 10 Scorecard

    private var owaspScorecardAndPrivacyCard: some View {
        let codeToScan = viewModel.selectedSwiftUICode
        let scanReport = StaticSecurityScanner.scan(source: codeToScan, filePath: "ActiveSelection.swift")
        let inferredManifest = ApplePrivacyManifestBuilder.inferCompliantManifest(fromSwiftSources: [codeToScan])
        let privacyAudit = ApplePrivacyManifestBuilder.validate(
            manifest: inferredManifest,
            againstSwiftSources: [codeToScan]
        )
        let scorecard = SecurityAuditReportSynthesizer.evaluateScorecard(
            workspaceName: viewModel.selectionDisplayTitle,
            scanReport: scanReport,
            privacyAudit: privacyAudit
        )

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "30-Rule Static Security Scanner & OWASP Mobile Top 10 (2024)",
                        subtitle: "Auditing '\(viewModel.selectionDisplayTitle)' for secrets, ATS, crypto hazards & App Store privacy compliance."
                    )
                    Spacer()
                    PillLabel(
                        title: "Grade \(scorecard.letterGrade) · \(scorecard.overallScore)/100",
                        systemImage: scorecard.isReleaseGatePassing ? "checkmark.seal.fill" : "exclamationmark.shield.fill"
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 8)], spacing: 8) {
                    ForEach(scorecard.categoryScores) { cat in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.category.rawValue)
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(theme.primary.swiftUIColor)
                                Text(cat.category.title)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(cat.score)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(cat.score >= 90 ? theme.success.swiftUIColor : theme.warning.swiftUIColor)
                        }
                        .padding(7)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7))
                    }
                }

                HStack(spacing: 12) {
                    Label(
                        privacyAudit.isAppStoreSubmissionReady
                            ? "PrivacyInfo.xcprivacy Ready (\(privacyAudit.declaredCategories.count) Required-Reason APIs)"
                            : "Privacy Manifest Needs Review",
                        systemImage: "hand.raised.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(privacyAudit.isAppStoreSubmissionReady ? theme.success.swiftUIColor : theme.warning.swiftUIColor)

                    Spacer()

                    Text("Findings: \(scanReport.findings.count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 4. Synthesized Security & Privacy Artifacts

    private var synthesizedSecurityArtifactsCard: some View {
        let inferredManifest = ApplePrivacyManifestBuilder.inferCompliantManifest(
            fromSwiftSources: [viewModel.selectedSwiftUICode]
        )
        let artifactText: String = {
            switch selectedArtifactTab {
            case .ephemerisActor:
                return EphemerisAuthenticatorCodeSynthesizer.synthesizeSwift6ActorSource(
                    actorName: "CelestialSessionAuthenticator",
                    config: activeAuthConfig
                )
            case .privacyPlist:
                return inferredManifest.compilePrivacyInfoPlistXML()
            case .keychainActor:
                return KeychainSecureEnclaveSynthesizer.synthesizeKeychainActorSource()
            case .regressionTests:
                return SecurityAuditReportSynthesizer.synthesizeSecurityRegressionTestSuite(
                    workspaceName: viewModel.selectionDisplayTitle,
                    ephemerisConfig: activeAuthConfig
                )
            }
        }()

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(
                        "Security & Privacy Artifact Synthesizer",
                        subtitle: "Export Swift 6 Celestial Authenticator actors, Secure Enclave Keychain wrappers, or PrivacyInfo.xcprivacy."
                    )
                    Spacer()
                    Picker("Artifact", selection: $selectedArtifactTab) {
                        ForEach(SecurityArtifactTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .frame(width: 235)
                    .controlSize(.small)
                }

                CodeBlockView(text: artifactText)
                    .frame(minHeight: 185, maxHeight: 260)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func cityPresetButton(_ name: String, lat: Double, lon: Double) -> some View {
        Button(name) {
            latitudeDeg = lat
            longitudeDeg = lon
            snapshotDate = Date()
            viewModel.statusMessage = "Set EphemerisCore geodetic observer to \(name)"
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func runSealOpenAndShamirDemo() {
        do {
            let inputData = Data(vaultPlaintext.utf8)
            let sealed = try EncryptedWorkspaceVault.sealData(
                inputData,
                passphrase: vaultPassphrase,
                preset: .fastTesting,
                cipherSuite: selectedCipherSuite
            )
            let binaryWire = try sealed.encodePortableBinary()
            let reopened = try EncryptedWorkspaceVault.decodePortableBinary(binaryWire).openData(passphrase: vaultPassphrase)

            let shares = try ShamirSecretSharing.splitSecret(
                Array(inputData),
                threshold: 3,
                shareCount: 5
            )
            generatedShamirTokens = shares.map { $0.formattedRecoveryToken() }
            let combined = try ShamirSecretSharing.combineShares([shares[0], shares[2], shares[4]])
            let ok = (reopened == inputData) && (Data(combined) == inputData)

            vaultStatusSummary = ok
                ? "Verified \(binaryWire.count)B .chiefkit.vault (FP \(sealed.header.keyFingerprintHex.prefix(12))) + 3-of-5 Shamir reconstruction."
                : "Integrity mismatch."
            viewModel.statusMessage = "Sealed XChaCha20 vault & verified 3-of-5 Shamir GF(256) reconstruction"
        } catch {
            vaultStatusSummary = "Vault error: \(error.localizedDescription)"
        }
    }
}
#endif
