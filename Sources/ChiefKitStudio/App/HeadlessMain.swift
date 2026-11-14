#if !(canImport(SwiftUI) && canImport(AppKit))
import ChiefKitAST
import ChiefKitBlueprints
import ChiefKitDesignSystem
import ChiefKitSecurity
import ChiefKitStudioCore
import Foundation

@main
struct ChiefKitStudioHeadlessCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.contains("--version") || args.contains("-v") {
            print(MasterSuiteRunner.suiteBanner)
            return
        }

        if args.contains("--help") || args.contains("-h") {
            printHelpUsage()
            return
        }

        if args.contains("--stats") {
            print(MasterSuiteRunner.generatePlatformStatsReport())
            return
        }

        if let astIdx = args.firstIndex(of: "--ast-inspect") {
            guard astIdx + 1 < args.count else {
                writeStderr("Error: --ast-inspect requires a <file> path.\n")
                Foundation.exit(1)
            }
            runASTInspect(filePath: args[astIdx + 1])
            return
        }

        if let secIdx = args.firstIndex(of: "--security-audit") {
            guard secIdx + 1 < args.count else {
                writeStderr("Error: --security-audit requires a <path> file or directory.\n")
                Foundation.exit(1)
            }
            runSecurityAudit(targetPath: args[secIdx + 1])
            return
        }

        if args.contains("--ephemeris") {
            let lat = parseDoubleOption(flag: "--lat", in: args) ?? 41.0082
            let lon = parseDoubleOption(flag: "--lon", in: args) ?? 28.9784
            runEphemerisDemo(latitudeDeg: lat, longitudeDeg: lon)
            return
        }

        if let exportIdx = args.firstIndex(of: "--export-demo") {
            guard exportIdx + 1 < args.count else {
                writeStderr("Error: --export-demo requires a destination <dir> path.\n")
                Foundation.exit(1)
            }
            runExportStarterDemo(destinationPath: args[exportIdx + 1])
            return
        }

        if let bpIdx = args.firstIndex(of: "--export-blueprint") {
            guard bpIdx + 2 < args.count else {
                writeStderr("Error: --export-blueprint requires <blueprintID> and <dir>.\n")
                Foundation.exit(1)
            }
            runExportEnterpriseBlueprint(rawID: args[bpIdx + 1], destinationPath: args[bpIdx + 2])
            return
        }

        // Default or --self-check: run complete 16-subsystem end-to-end master diagnostic suite
        let report = await MasterSuiteRunner.runFullMasterSelfCheck()
        print(report.formattedSummary)
        if !report.allPassed {
            Foundation.exit(1)
        }
    }

    // MARK: - CLI Subcommand Implementations

    private static func printHelpUsage() {
        let usage = """
        \(MasterSuiteRunner.suiteBanner)

        USAGE:
          ChiefKitStudio [SUBCOMMAND / OPTIONS]

        OPTIONS:
          --self-check                        Run all 16 end-to-end master subsystem checks (default)
          --version, -v                       Print version banner
          --help, -h                          Display this command-line reference table
          --stats                             Print full Studio 3.0 inventory (64 Blocks, 28 Blueprints, 38 AST & 30 Security Rules)
          --ast-inspect <file>                Run ChiefKitAST lexer, parser, complexity & 38-rule static audit on <file>
          --security-audit <path>             Scan <path> (file or directory) with StaticSecurityScanner & OWASP Mobile Top 10 scorecard
          --ephemeris [--lat <d>] [--lon <d>] Compute live 9-body EphemerisSkySnapshot + Celestial-TOTP & AEAD envelope demo
          --export-demo <dir>                 Export standalone SwiftPM starter app into <dir>
          --export-blueprint <id> <dir>       Export a 14-file enterprise blueprint workspace into <dir>

        EXAMPLE ENTERPRISE BLUEPRINT IDs:
          neobankMultiCurrencyTreasury, localRAGKnowledgeWorkbench, clinicalVitalsLongevityLab,
          spatialLuxuryStorefrontAR, zeroKnowledgePasskeyVault, celestialObservatoryPlanner,
          socSIEMThreatHuntingConsole, multiTenantSaaSBillingFlags
        """
        print(usage)
    }

    private static func runASTInspect(filePath: String) {
        guard let source = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            writeStderr("AST Inspect failed: Unable to read UTF-8 Swift source at '\(filePath)'.\n")
            Foundation.exit(1)
        }

        let snap = ChiefKitASTModule.analyzePipeline(source: source, filePath: filePath)
        let views = snap.sourceFile.allViewNodes()
        let m = snap.metricsReport
        let a = snap.auditReport

        print("=== ChiefKitAST Pipeline Inspection: \(filePath) ===")
        print("Tokens: \(snap.tokenSummary.totalTokens) (keywords: \(snap.tokenSummary.keywordCount), identifiers: \(snap.tokenSummary.identifierCount), attributes: \(snap.tokenSummary.attributeCount), directives: \(snap.tokenSummary.directiveCount))")
        print("Declarations: \(snap.sourceFile.allTypesFlattened().count) types · \(views.count) SwiftUI view nodes (max depth \(m.viewTreeDepth)) · \(snap.symbolGraph.edges.count) symbol edges")
        print(
            "Complexity: McCabe=\(m.cyclomaticComplexityTotal) (avg \(String(format: "%.2f", m.cyclomaticComplexityAverage))), "
                + "Cognitive=\(m.cognitiveComplexityTotal), Halstead Vol=\(String(format: "%.1f", m.halstead.volume)), "
                + "Maintainability=\(String(format: "%.1f", m.maintainabilityIndex)) (\(m.maintainabilityGrade))"
        )
        print("Structural Verification: \(snap.verificationReport.isValid ? "VALID" : "ISSUES DETECTED") (braces: \(snap.verificationReport.matchedBracePairs), parens: \(snap.verificationReport.matchedParenPairs), #if blocks: \(snap.verificationReport.conditionalCompilationBlockCount))")
        print("38-Rule Static Audit Score: \(a.overallScore)/100 (\(a.passedRuleCount)/\(a.totalRuleCount) rules clean — \(a.errorCount) errors, \(a.warningCount) warnings, \(a.infoCount) info)")

        if !a.diagnostics.isEmpty {
            print("\nDiagnostics:")
            for diag in a.diagnostics.prefix(20) {
                print("  [\(diag.severity.rawValue.uppercased())] \(diag.ruleID.rawValue) (L\(diag.span.start.line)): \(diag.title) — \(diag.message)")
            }
            if a.diagnostics.count > 20 {
                print("  ... and \(a.diagnostics.count - 20) additional diagnostics.")
            }
        }
    }

    private static func runSecurityAudit(targetPath: String) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: targetPath, isDirectory: &isDir) else {
            writeStderr("Security Audit failed: Path '\(targetPath)' does not exist.\n")
            Foundation.exit(1)
        }

        var documents: [SecuritySourceDocument] = []
        if isDir.boolValue {
            if let enumerator = fm.enumerator(atPath: targetPath) {
                while let rel = enumerator.nextObject() as? String {
                    if (rel.hasSuffix(".swift") || rel.hasSuffix(".plist") || rel.hasSuffix(".json")) && !rel.contains("/.build/") {
                        let fullPath = (targetPath as NSString).appendingPathComponent(rel)
                        if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                            documents.append(SecuritySourceDocument(filePath: rel, content: content))
                        }
                    }
                }
            }
        } else if let content = try? String(contentsOfFile: targetPath, encoding: .utf8) {
            documents.append(SecuritySourceDocument(filePath: targetPath, content: content))
        }

        guard !documents.isEmpty else {
            writeStderr("Security Audit failed: No readable source files found at '\(targetPath)'.\n")
            Foundation.exit(1)
        }

        let scanReport = StaticSecurityScanner.scan(documents: documents)
        let inferredManifest = ApplePrivacyManifestBuilder.inferCompliantManifest(
            fromSwiftSources: documents.map(\.content)
        )
        let privacyAudit = ApplePrivacyManifestBuilder.validate(
            manifest: inferredManifest,
            againstSwiftSources: documents.map(\.content)
        )
        let scorecard = SecurityAuditReportSynthesizer.evaluateScorecard(
            workspaceName: (targetPath as NSString).lastPathComponent,
            scanReport: scanReport,
            privacyAudit: privacyAudit
        )

        print("=== ChiefKitSecurity OWASP Mobile Top 10 Audit: \(targetPath) ===")
        print("Scanned: \(scanReport.scannedFileCount) file(s) (\(scanReport.scannedLineCount) lines)")
        print("Overall Security Score: \(scorecard.overallScore)/100 (Grade \(scorecard.letterGrade)) · Release Gate: \(scorecard.isReleaseGatePassing ? "PASS" : "BLOCKED")")
        print("Posture Breakdown: Static=\(scorecard.staticPostureScore) · Privacy=\(scorecard.privacyComplianceScore) · Crypto=\(scorecard.cryptographicPostureScore)")
        print("\nOWASP Mobile Top 10 (2024) Breakdown:")
        for catScore in scorecard.categoryScores {
            print("  \(catScore.category.rawValue) \(catScore.category.title.padding(toLength: 38, withPad: " ", startingAt: 0)) Score: \(catScore.score)/100 (\(catScore.grade)) · Findings: \(catScore.findingCount)")
        }

        if !scanReport.findings.isEmpty {
            print("\nFindings (\(scanReport.findings.count)):")
            for finding in scanReport.findings.prefix(20) {
                print("  [\(finding.severity.rawValue)] \(finding.ruleID.rawValue) (\(finding.cweIdentifier)) \(finding.filePath):\(finding.lineNumber) — \(finding.explanation)")
            }
        }
    }

    private static func runEphemerisDemo(latitudeDeg: Double, longitudeDeg: Double) {
        do {
            let observer = try GeodeticObserver(latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg, elevationMeters: 35.0)
            let now = Date()
            let epoch = JulianEpoch(utcDate: now)
            let sky = try EphemerisSkySnapshot.compute(epoch: epoch, observer: observer)

            print("=== EphemerisCore Live Sky Snapshot & Celestial-TOTP ===")
            print(String(format: "Observer: lat %.4f°, lon %.4f° · JD(UTC): %.5f · GMST: %.3f° · LMST: %.3f°", latitudeDeg, longitudeDeg, epoch.jd, sky.gmstDegrees, sky.lmstDegrees))
            print(
                "Sun:  RA \(sky.sun.equatorial.hms.formatted) · Dec \(sky.sun.equatorial.dms.formatted) · "
                    + String(format: "Alt %.2f° · Az %.2f° · EoT %.2f min", sky.sun.horizontal.apparentAltitudeDeg, sky.sun.horizontal.azimuthDeg, sky.sun.equationOfTimeMinutes)
            )
            print(
                "Moon: \(sky.moon.phaseName.emojiSymbol) \(sky.moon.phaseName.rawValue) "
                    + String(format: "(%.1f%% illuminated, age %.1fd, dist %.0f km)", sky.moon.illuminatedFraction * 100.0, sky.moon.lunarAgeDays, sky.moon.geocentricDistanceKm)
            )
            print("\nGeocentric Sky Bodies (\(sky.bodies.count)):")
            for body in sky.bodies {
                let horizonTag = body.topocentricHorizontal.isAboveApparentHorizon ? "VISIBLE" : "BELOW  "
                let retroTag = body.isApparentRetrograde ? " [R]" : ""
                let nameCol = body.body.rawValue.padding(toLength: 22, withPad: " ", startingAt: 0)
                let coords = String(
                    format: "EclLon %7.2f° · Alt %+6.2f° · Az %6.2f°",
                    body.geocentricEcliptic.longitudeDeg,
                    body.topocentricHorizontal.apparentAltitudeDeg,
                    body.topocentricHorizontal.azimuthDeg
                )
                print("  \(body.body.astronomicalSymbol) \(nameCol) \(coords) · \(horizonTag)\(retroTag)")
            }

            let seed = Array("ChiefKit-CLI-Celestial-Auth-Demo-Seed-2026".utf8)
            let config = EphemerisAuthConfiguration.highSecurityGeodetic30s
            let totp = try EphemerisEntropyProtocol.generateCelestialTOTP(
                sharedSecretSeed: seed,
                unixTimestamp: now.timeIntervalSince1970,
                observer: observer,
                config: config
            )
            let envelope = try EphemerisEntropyProtocol.sealEnvelope(
                payload: Array("ephemeris-cli-verified".utf8),
                sharedSecretSeed: seed,
                unixTimestamp: now.timeIntervalSince1970,
                observer: observer,
                config: config
            )
            let verified = try EphemerisEntropyProtocol.openAndVerifyEnvelope(
                envelope,
                sharedSecretSeed: seed,
                verifierUnixTimestamp: now.timeIntervalSince1970,
                observer: observer,
                config: config
            )

            print("\nCelestial-TOTP Demonstration:")
            print("  Code: \(totp.code) (\(totp.digits) digits, step #\(totp.epochStepIndex)) · SessionKeyID: \(totp.sessionKeyID)")
            print("  Sky SHA-512 Commitment Prefix: \(totp.skyCommitmentPrefixHex)")
            print("  AEAD Envelope Round-Trip: \(verified.isAuthenticated ? "AUTHENTICATED" : "FAILED") (payload: \"\(verified.decryptedUTF8 ?? "")\")")
        } catch {
            writeStderr("Ephemeris computation failed: \(error.localizedDescription)\n")
            Foundation.exit(1)
        }
    }

    private static func runExportStarterDemo(destinationPath: String) {
        let outURL = URL(fileURLWithPath: destinationPath, isDirectory: true)
        let theme = StudioThemePreset.liquidGlass26.tokens
        let canvas = CanvasDocument.starter(radius: theme.radiusMedium)
        let code = canvas.generateSwiftUICode(
            theme: theme,
            layoutMode: .adaptiveStacks,
            focusedNodeID: nil,
            focusSelectedOnly: false
        )
        let config = ProjectGenerationConfig(
            projectName: "ChiefKitExportedDemo",
            bundleIdentifier: "com.hnmlabs.exporteddemo",
            dependencyMode: .standaloneReady,
            includeUnitTests: true,
            openInXcodeAfterExport: false,
            selection: .package(.swiftBlocks),
            requiredPackages: [.swiftBlocks],
            swiftUICode: code,
            themeTokens: theme,
            flowJSON: DemoLibrary.defaultFlowJSON
        )
        do {
            let created = try ProjectGeneratorCore.writeProject(config: config, inside: outURL)
            print("Exported starter project to: \(created.path)")
        } catch {
            writeStderr("Export failed: \(error.localizedDescription)\n")
            Foundation.exit(1)
        }
    }

    private static func runExportEnterpriseBlueprint(rawID: String, destinationPath: String) {
        let matchedID = EnterpriseBlueprintID(rawValue: rawID)
            ?? EnterpriseBlueprintID.allCases.first { $0.rawValue.caseInsensitiveCompare(rawID) == .orderedSame }

        guard let blueprintID = matchedID else {
            let available = EnterpriseBlueprintID.allCases.map(\.rawValue).joined(separator: ", ")
            writeStderr("Unknown blueprint ID '\(rawID)'. Available 28 IDs:\n\(available)\n")
            Foundation.exit(1)
        }

        let destinationURL = URL(fileURLWithPath: destinationPath, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            let result = try BlueprintWorkspaceExporter.exportToDisk(
                blueprintID: blueprintID,
                theme: StudioThemePreset.liquidGlass26.tokens,
                destinationParentDirectory: destinationURL
            )
            print("Exported \(result.writtenFileURLs.count)-file enterprise workspace (\(result.workspace.totalLinesOfCode) lines) to: \(result.rootDirectoryURL.path)")
            for file in result.workspace.files {
                print("  • \(file.relativePath) (\(file.lineCount)L)")
            }
        } catch {
            writeStderr("Blueprint export failed: \(error.localizedDescription)\n")
            Foundation.exit(1)
        }
    }

    // MARK: - Helpers

    private static func parseDoubleOption(flag: String, in args: [String]) -> Double? {
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
        return Double(args[idx + 1])
    }

    private static func writeStderr(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }
}
#endif
