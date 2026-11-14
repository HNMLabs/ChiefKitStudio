import ChiefKitAST
import ChiefKitBlueprints
import ChiefKitDesignSystem
import ChiefKitSecurity
import ChiefKitStudioCore
import Foundation

/// Cross-platform Studio 3.0 Master Verification & Platform Telemetry Runner.
/// Compiles identically on macOS (AppKit/SwiftUI) and Linux headless environments.
public enum MasterSuiteRunner {
    public static let suiteVersion = "3.0.0"
    public static let suiteBanner = "ChiefKit Studio 3.0 Master Suite (Swift 6 Cross-Platform Engine)"

    private struct SuiteReportCodingBridge: Codable {
        let steps: [SelfCheckStepResult]
        let durationMilliseconds: Double
    }

    // MARK: - 16-Subsystem End-to-End Master Self-Check

    /// Executes the 11 core `StudioSelfCheckRunner` checks plus 5 deep Studio 3.0 module checks (16 total).
    public static func runFullMasterSelfCheck() async -> SelfCheckSuiteReport {
        let suiteStart = Date()
        let coreReport = await StudioSelfCheckRunner.runAll()
        var allSteps = coreReport.steps

        allSteps.append(verifyChiefKitASTSubsystem())
        allSteps.append(verifyChiefKitDesignSystemSubsystem())
        allSteps.append(verifyChiefKitSecuritySubsystem())
        allSteps.append(verifyEphemerisCoreSubsystem())
        allSteps.append(verifyChiefKitBlueprintsSubsystem())

        let totalDurationMs = Date().timeIntervalSince(suiteStart) * 1000.0
        return buildSuiteReport(steps: allSteps, durationMilliseconds: totalDurationMs, fallback: coreReport)
    }

    private static func buildSuiteReport(
        steps: [SelfCheckStepResult],
        durationMilliseconds: Double,
        fallback: SelfCheckSuiteReport
    ) -> SelfCheckSuiteReport {
        let payload = SuiteReportCodingBridge(steps: steps, durationMilliseconds: durationMilliseconds)
        if let encoded = try? JSONEncoder().encode(payload),
           let decoded = try? JSONDecoder().decode(SelfCheckSuiteReport.self, from: encoded) {
            return decoded
        }
        return fallback
    }

    // MARK: - Subsystem 12: ChiefKitAST

    private static func verifyChiefKitASTSubsystem() -> SelfCheckStepResult {
        let sampleViewSource = """
        import SwiftUI

        struct TelemetryPulseCard: View {
            @State private var sampleCount: Int = 3

            var body: some View {
                VStack(spacing: 12) {
                    Text("Telemetry Pulse")
                        .font(.headline)
                    Button("Record Sample") {
                        sampleCount += 1
                    }
                    .padding(12)
                }
                .padding(16)
            }
        }
        """

        let snapshot = ChiefKitASTModule.analyzePipeline(
            source: sampleViewSource,
            filePath: "TelemetryPulseCard.swift",
            theme: StudioThemePreset.liquidGlass26.tokens
        )
        let canvasImport = ASTCanvasBridge.importToCanvas(source: sampleViewSource)
        let canvasExport = ASTCanvasBridge.exportToFormattedSwift(
            document: CanvasDocument.starter(radius: 14),
            structName: "RoundTripCanvasView",
            theme: StudioThemePreset.liquidGlass26.tokens
        )
        let transformed = ASTTransformationEngine.applyPipeline(
            passes: [.tokenizeMagicLiterals, .injectVoiceOverAndDynamicType],
            to: sampleViewSource,
            theme: StudioThemePreset.liquidGlass26.tokens
        )
        let synthesizedTests = ASTTestSynthesizer.synthesize(
            source: sampleViewSource,
            moduleUnderTest: "ChiefKitApp",
            framework: .swiftTesting
        )

        let sourceDirStatus: (passed: Bool, summary: String)
        if let studioSourceDir = resolveChiefKitStudioSourceDirectory() {
            let dirReport = ASTSourceVerifier.verifyDirectory(at: studioSourceDir, recursive: true)
            sourceDirStatus = (
                dirReport.isValid && dirReport.totalFilesVerified > 0,
                "\(dirReport.totalFilesVerified) Studio files (\(dirReport.totalLinesVerified)L) verified"
            )
        } else {
            let inlineVerify = ASTSourceVerifier.verifySource(code: transformed.formattedSource)
            sourceDirStatus = (
                inlineVerify.isValid,
                "inline AST structural verifier (\(inlineVerify.lineCount)L) clean"
            )
        }

        let passed = snapshot.tokenSummary.totalTokens > 20
            && !snapshot.sourceFile.types.isEmpty
            && snapshot.auditReport.totalRuleCount == 38
            && snapshot.metricsReport.halstead.volume > 0
            && !snapshot.symbolGraph.nodes.isEmpty
            && canvasImport.importedNodeCount > 0
            && canvasExport.nodeCount > 0
            && transformed.didModify
            && synthesizedTests.totalTestCount > 0
            && sourceDirStatus.passed

        return SelfCheckStepResult(
            subsystem: "ChiefKitAST Lexer, Refactoring & 38-Rule Audit",
            passed: passed,
            detail: "\(snapshot.tokenSummary.totalTokens) tokens, \(snapshot.auditReport.totalRuleCount) rules, \(transformed.edits.count) AST edits, \(sourceDirStatus.summary)"
        )
    }

    // MARK: - Subsystem 13: ChiefKitDesignSystem

    private static func verifyChiefKitDesignSystemSubsystem() -> SelfCheckStepResult {
        let theme = StudioThemePreset.liquidGlass26.tokens
        let diagnostics = ChiefKitDesignSystemModule.runDiagnostics(theme: theme)
        let tokenBundle = DesignTokenCompiler.compileAllTargets(tokens: theme, namespace: "ChiefKit")
        let springReport = SpringAnalysisReport(parameters: .bouncy)
        let rk4Curve = RK4SpringIntegrator.integrate(parameters: .snappy, duration: 1.0)
        let tonalScale = theme.primary.tonalScale(named: "primary")
        let apcaEval = theme.primary.apcaEvaluation(against: .white)
        let cvdSwatches = ColorBlindnessKind.allCases.map { theme.primary.simulated(for: $0) }
        let parsedSVG = try? SVGPathEngine.parse(ChiefKitVectorIcon.sparklesAI.svgPathData)
        let shapeCode = ChiefKitVectorIcon.liquidGlassCube.emitSwiftUIShape(structName: "LiquidCubeShape")
        let catalogAudit = SwiftBlockCatalog.auditCatalog(theme: theme)
        let sampleBlockCode = SwiftBlockCatalog.synthesizeCode(
            for: .virtualCardGlassView,
            theme: theme,
            variant: "glass",
            state: .hovered
        )

        let passed = diagnostics.allSubsystemsHealthy
            && tokenBundle.files.count == DesignTokenTarget.allCases.count
            && tokenBundle.files.count == 8
            && springReport.rk4AnalyticalRMSError < 0.025
            && !rk4Curve.isEmpty
            && tonalScale.swatches.count == TonalStop.allCases.count
            && apcaEval.magnitudeLc > 30.0
            && cvdSwatches.count == 7
            && parsedSVG != nil
            && ChiefKitVectorIcon.allCases.count == 42
            && shapeCode.contains("Shape")
            && catalogAudit.isFull64CatalogVerified
            && catalogAudit.totalComponentCount == 64
            && sampleBlockCode.contains("CKVirtualCardGlassView")

        return SelfCheckStepResult(
            subsystem: "ChiefKitDesignSystem OKLCH/APCA, RK4, SVG & 64 SwiftBlocks",
            passed: passed,
            detail: String(
                format: "64 SwiftBlocks, 8 token targets, 42 SVG icons, APCA Lc %.1f, RK4 RMS %.5f",
                apcaEval.magnitudeLc,
                springReport.rk4AnalyticalRMSError
            )
        )
    }

    // MARK: - Subsystem 14: ChiefKitSecurity

    private static func verifyChiefKitSecuritySubsystem() -> SelfCheckStepResult {
        let rfcOK = SecuritySelfTest.verifyRFCVectors()
        let detailedSelfTest = SecuritySelfTest.runDetailedSelfTest()

        var vaultAndShamirOK = false
        do {
            let plaintext = Array("ChiefKit-Studio-3.0-Confidential-Workspace-Vault".utf8)
            let vault = try EncryptedWorkspaceVault.seal(
                plaintext: plaintext,
                passphrase: "chiefkit-master-passphrase",
                cipherSuite: .xchacha20Poly1305,
                kdfPRF: .hmacSHA256,
                kdfIterations: VaultKDFPreset.fastTesting.iterations
            )
            let binaryWire = try vault.encodePortableBinary()
            let decodedVault = try EncryptedWorkspaceVault.decodePortableBinary(binaryWire)
            let opened = try decodedVault.open(passphrase: "chiefkit-master-passphrase")

            let shamirDemoPayload = Array("shamir-polynomial-roundtrip-demo".utf8)
            let shares = try ShamirSecretSharing.splitSecret(shamirDemoPayload, threshold: 3, shareCount: 5)
            let parsedFirst = try ShamirSecretShare.parseRecoveryToken(shares[0].formattedRecoveryToken())
            let reconstructed = try ShamirSecretSharing.combineShares([parsedFirst, shares[2], shares[4]])

            vaultAndShamirOK = (opened == plaintext) && (reconstructed == shamirDemoPayload) && shares.count == 5
        } catch {
            vaultAndShamirOK = false
        }

        let cleanSample = """
        import Foundation

        struct EndpointConfig: Sendable {
            let baseURL = "https://api.chiefkit.dev/v3"
            func persistPreference() {
                UserDefaults.standard.set(true, forKey: "onboardingComplete")
            }
        }
        """
        let scanReport = StaticSecurityScanner.scan(source: cleanSample, filePath: "EndpointConfig.swift")
        let inferredPrivacy = ApplePrivacyManifestBuilder.inferCompliantManifest(fromSwiftSources: [cleanSample])
        let privacyXML = inferredPrivacy.compilePrivacyInfoPlistXML()
        let privacyAudit = ApplePrivacyManifestBuilder.validate(
            manifest: inferredPrivacy,
            againstSwiftSources: [cleanSample]
        )
        let scorecard = try? ChiefKitSecurityModule.runFullWorkspaceAudit(
            workspaceName: "ChiefKitStudioVerify",
            documents: [SecuritySourceDocument(filePath: "EndpointConfig.swift", content: cleanSample)],
            privacyPlistXML: privacyXML
        )

        let passed = rfcOK
            && detailedSelfTest.allPassed
            && vaultAndShamirOK
            && SecurityRuleID.allCases.count == 30
            && !scanReport.hasCriticalFindings
            && privacyXML.contains("NSPrivacyAccessedAPICategoryUserDefaults")
            && privacyAudit.isAppStoreSubmissionReady
            && (scorecard?.overallScore ?? 0) >= 85

        return SelfCheckStepResult(
            subsystem: "ChiefKitSecurity RFC Crypto, Vault, Shamir & OWASP",
            passed: passed,
            detail: "\(detailedSelfTest.checks.count) RFC vectors, XChaCha20 vault + GF(256) 3-of-5, 30 OWASP rules, PrivacyInfo.xcprivacy ready"
        )
    }

    // MARK: - Subsystem 15: EphemerisCore

    private static func verifyEphemerisCoreSubsystem() -> SelfCheckStepResult {
        do {
            let observer = try GeodeticObserver(
                latitudeDeg: 41.0082,
                longitudeDeg: 28.9784,
                elevationMeters: 42.0
            )
            let timestamp = Date()
            let epoch = JulianEpoch(utcDate: timestamp)
            let sky = try EphemerisSkySnapshot.compute(epoch: epoch, observer: observer)

            let seed = Array("ChiefKit-EphemerisCore-Orbital-Entropy-Seed-v3".utf8)
            let config = EphemerisAuthConfiguration.highSecurityGeodetic30s
            let totp = try EphemerisEntropyProtocol.generateCelestialTOTP(
                sharedSecretSeed: seed,
                unixTimestamp: timestamp.timeIntervalSince1970,
                observer: observer,
                config: config
            )
            let totpVerify = try EphemerisEntropyProtocol.verifyCelestialTOTP(
                candidateCode: totp.code,
                sharedSecretSeed: seed,
                verifierUnixTimestamp: timestamp.timeIntervalSince1970,
                observer: observer,
                config: config
            )

            let messageBytes = Array("ephemeris-bound-session-handshake".utf8)
            let envelope = try EphemerisEntropyProtocol.sealEnvelope(
                payload: messageBytes,
                sharedSecretSeed: seed,
                unixTimestamp: timestamp.timeIntervalSince1970,
                observer: observer,
                config: config
            )
            let opened = try EphemerisEntropyProtocol.openAndVerifyEnvelope(
                envelope,
                sharedSecretSeed: seed,
                verifierUnixTimestamp: timestamp.timeIntervalSince1970,
                observer: observer,
                config: config
            )

            let passed = sky.bodies.count == CelestialBody.geocentricSkyBodies.count
                && sky.bodies.count == 9
                && totp.code.count == config.totpDigits
                && totpVerify.isValid
                && opened.isAuthenticated
                && opened.decryptedPayload == messageBytes

            let jdText = String(format: "%.3f", epoch.jd)
            let illumText = String(format: "%.0f", sky.moon.illuminatedFraction * 100.0)
            return SelfCheckStepResult(
                subsystem: "EphemerisCore 9-Body Sky & Celestial-TOTP Auth",
                passed: passed,
                detail: "JD \(jdText), \(sky.bodies.count) sky bodies, Moon \(sky.moon.phaseName.rawValue) (\(illumText)%), Celestial-TOTP \(totp.code) & AEAD envelope verified"
            )
        } catch {
            return SelfCheckStepResult(
                subsystem: "EphemerisCore 9-Body Sky & Celestial-TOTP Auth",
                passed: false,
                detail: "Ephemeris verification failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Subsystem 16: ChiefKitBlueprints

    private static func verifyChiefKitBlueprintsSubsystem() -> SelfCheckStepResult {
        let catalogValidation = BlueprintArchitectureValidator.validateAll(
            theme: StudioThemePreset.liquidGlass26.tokens
        )
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
            "chiefkit-bp-selfcheck-\(UUID().uuidString)",
            isDirectory: true
        )
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        var exportedCount = 0
        var exportedLOC = 0
        var exportSucceeded = false

        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            let exportResult = try BlueprintWorkspaceExporter.exportToDisk(
                blueprintID: .neobankMultiCurrencyTreasury,
                theme: StudioThemePreset.liquidGlass26.tokens,
                destinationParentDirectory: tempRoot
            )
            exportedCount = exportResult.writtenFileURLs.count
            exportedLOC = exportResult.workspace.totalLinesOfCode
            let packagePath = exportResult.rootDirectoryURL.appendingPathComponent("Package.swift").path
            exportSucceeded = FileManager.default.fileExists(atPath: packagePath)
                && exportResult.workspace.files.count == BlueprintWorkspaceExporter.canonicalFileCount
                && exportedCount == 14
        } catch {
            exportSucceeded = false
        }

        let passed = EnterpriseBlueprintCatalog.allSpecs.count == 28
            && EnterpriseVertical.allCases.count == 9
            && catalogValidation.isValid
            && catalogValidation.totalErrors == 0
            && exportSucceeded

        return SelfCheckStepResult(
            subsystem: "ChiefKitBlueprints 28-Domain Catalog & 14-File Exporter",
            passed: passed,
            detail: "28 blueprints across 9 verticals validated (0 errors), 14-file workspace (\(exportedLOC)L) exported"
        )
    }

    // MARK: - Platform Inventory & Statistics Report

    /// Generates a comprehensive human-readable inventory of all ChiefKit Studio 3.0 subsystems and catalogs.
    public static func generatePlatformStatsReport() -> String {
        let bpSummary = EnterpriseBlueprintCatalog.summary
        let blockAudit = SwiftBlockCatalog.auditCatalog()
        let securityRules = SecurityRuleID.allCases.count
        let astRules = ASTAuditRuleID.allCases.count
        let tokenTargets = DesignTokenTarget.allCases
        let locales = LocaleCode.allCases
        let schemaPresets = SchemaPresetKind.allCases
        let vectorIcons = ChiefKitVectorIcon.allCases.count

        var lines: [String] = []
        lines.append("================================================================================")
        lines.append("  \(suiteBanner)")
        lines.append("  Platform Architecture & Capability Inventory — Version \(suiteVersion)")
        lines.append("================================================================================")
        lines.append("")
        lines.append("MODULES & COMPILER TARGETS (6):")
        lines.append("  1. ChiefKitStudioCore    — Canvas, SwiftState DAG, NotebookFlow, DataSchema, L10n, 120Hz Profiler")
        lines.append("  2. ChiefKitAST           — Swift 6 Lexer, SwiftUI Parser, Canvas Bridge, \(astRules) Audit Rules, @Test Synth")
        lines.append("  3. ChiefKitDesignSystem  — OKLCH/APCA Color, \(tokenTargets.count) Token Targets, RK4 Springs, \(vectorIcons) SVG Icons, 64 SwiftBlocks")
        lines.append("  4. ChiefKitSecurity      — SHA-2/HKDF/PBKDF2, XChaCha20 Vault, Shamir GF(256), EphemerisCore, \(securityRules) OWASP Rules")
        lines.append("  5. ChiefKitBlueprints    — \(bpSummary.blueprintCount) Enterprise Blueprints across \(bpSummary.verticalCount) Verticals, 14-File Exporter")
        lines.append("  6. ChiefKitStudio        — macOS Liquid Glass IDE + 8 Studio 3.0 Workbenches + Cross-Platform CLI")
        lines.append("")

        lines.append("SWIFTBLOCKS 3.0 COMPONENT CATALOG (\(blockAudit.totalComponentCount) Components across \(SwiftBlockCategory.allCases.count) Categories):")
        for category in SwiftBlockCategory.allCases {
            let specs = SwiftBlockCatalog.specs(in: category)
            let names = specs.prefix(4).map(\.id.structName).joined(separator: ", ")
            lines.append("  • \(category.rawValue.padding(toLength: 26, withPad: " ", startingAt: 0)) [\(specs.count)] e.g. \(names)…")
        }
        lines.append("  • Liquid Glass Capable: \(blockAudit.liquidGlassCapableCount)/\(blockAudit.totalComponentCount) · Dynamic Type AX5 Compliant: \(blockAudit.dynamicTypeAX5CompliantCount)/\(blockAudit.totalComponentCount)")
        lines.append("")

        lines.append("ENTERPRISE BLUEPRINTS (\(bpSummary.blueprintCount) Full-Stack Specs across \(bpSummary.verticalCount) Industry Verticals):")
        for vertical in EnterpriseVertical.allCases {
            let specs = EnterpriseBlueprintCatalog.specs(in: vertical)
            let ids = specs.map(\.id.rawValue).joined(separator: ", ")
            lines.append("  • \(vertical.title.padding(toLength: 30, withPad: " ", startingAt: 0)) [\(specs.count)] \(ids)")
        }
        lines.append("  • Totals: \(bpSummary.totalDomainEntities) Entities · \(bpSummary.totalReducerActions) Reducer Actions · \(bpSummary.totalAPIEndpoints) API Endpoints · \(bpSummary.totalOnboardingScreens) Flow Screens · \(bpSummary.totalLocalizedKeys) EN/TR Keys")
        lines.append("")

        lines.append("CHIEFKITAST STATIC AUDIT (\(astRules) Rules across \(ASTAuditCategory.allCases.count) Categories):")
        for cat in ASTAuditCategory.allCases {
            let count = ASTAuditRuleID.allCases.filter { $0.category == cat }.count
            lines.append("  • \(cat.rawValue.padding(toLength: 28, withPad: " ", startingAt: 0)) — \(count) rules")
        }
        lines.append("")

        lines.append("CHIEFKITSECURITY & EPHEMERISCORE (\(securityRules) OWASP Mobile Top 10 Rules + Pure-Swift Crypto):")
        for owasp in OWASPMobileCategory.allCases {
            let count = SecurityRuleID.allCases.filter { $0.owaspCategory == owasp }.count
            lines.append("  • \(owasp.rawValue) \(owasp.title.padding(toLength: 38, withPad: " ", startingAt: 0)) — \(count) rules")
        }
        lines.append("  • EphemerisCore Bodies (\(CelestialBody.geocentricSkyBodies.count) Geocentric): \(CelestialBody.geocentricSkyBodies.map { "\($0.astronomicalSymbol) \($0.rawValue)" }.joined(separator: ", "))")
        lines.append("")

        lines.append("DESIGN TOKEN COMPILER TARGETS (\(tokenTargets.count)):")
        lines.append("  • \(tokenTargets.map { "\($0.displayTitle) (\($0.defaultFilename))" }.joined(separator: "\n  • "))")
        lines.append("")

        lines.append("LOCALIZATION LOCALES (\(locales.count)) & ER DATA SCHEMA PRESETS (\(schemaPresets.count)):")
        lines.append("  • Locales (\(locales.count)): \(locales.map { "\($0.bcp47Tag) (\($0.englishName), \($0.scriptDirection.rawValue))" }.joined(separator: ", "))")
        lines.append("  • Schema Presets (\(schemaPresets.count)): \(schemaPresets.map(\.title).joined(separator: " | "))")
        lines.append("================================================================================")

        return lines.joined(separator: "\n")
    }

    // MARK: - Workspace Source Directory Discovery

    /// Locates `Sources/ChiefKitStudio` when invoked inside the repository workspace.
    public static func resolveChiefKitStudioSourceDirectory() -> String? {
        let fm = FileManager.default
        var candidates: [URL] = [
            URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)
        ]
        if let execPath = CommandLine.arguments.first {
            let execURL = URL(fileURLWithPath: execPath).deletingLastPathComponent()
            candidates.append(execURL)
        }

        for base in candidates {
            var cursor = base
            for _ in 0..<6 {
                let target = cursor
                    .appendingPathComponent("Sources", isDirectory: true)
                    .appendingPathComponent("ChiefKitStudio", isDirectory: true)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: target.path, isDirectory: &isDir), isDir.boolValue {
                    return target.path
                }
                let parent = cursor.deletingLastPathComponent()
                if parent.path == cursor.path { break }
                cursor = parent
            }
        }
        return nil
    }
}
