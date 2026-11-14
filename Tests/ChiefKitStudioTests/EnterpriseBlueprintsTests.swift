import ChiefKitAST
import ChiefKitBlueprints
import ChiefKitSecurity
import ChiefKitStudioCore
import Foundation
import Testing
import XCTest

// MARK: - Swift 6 Testing (@Suite / @Test) for All 28 Enterprise Blueprints Across 9 Verticals

@Suite("ChiefKitBlueprints 3.0 — 28 Enterprise Blueprints, 9 Verticals, 8 Layers & 14-File SwiftPM Exporter")
struct EnterpriseBlueprintsSwiftTestingSuite {
    @Test("ChiefKitBlueprintsModule facade constants and full 28-blueprint architecture audit pass with 0 errors and 0 warnings")
    func fullCatalogArchitectureValidationZeroErrorsAndWarnings() {
        #expect(ChiefKitBlueprintsModule.version == "3.0.0")
        #expect(ChiefKitBlueprintsModule.canonicalVerticalCount == 9)
        #expect(ChiefKitBlueprintsModule.canonicalBlueprintCount == 28)
        #expect(ChiefKitBlueprintsModule.exportedWorkspaceFileCount == 14)

        let summary = ChiefKitBlueprintsModule.summary
        #expect(summary.verticalCount == 9)
        #expect(summary.blueprintCount == 28)
        #expect(summary.totalDomainEntities >= 56)
        #expect(summary.totalReducerActions >= 56)
        #expect(summary.totalAPIEndpoints >= 56)
        #expect(summary.totalOnboardingScreens >= 84)
        #expect(summary.totalLocalizedKeys >= 140)

        let report = BlueprintArchitectureValidator.validateAll()
        #expect(report.isValid)
        #expect(report.auditedBlueprintCount == 28)
        #expect(report.totalErrors == 0)
        #expect(report.totalWarnings == 0)
        #expect(report.catalogIssues.isEmpty)
        #expect(report.totalSynthesizedSwiftLines > 5_000)
        #expect(report.totalDetectedTests >= 84)

        let markdown = report.formattedMarkdownSummary()
        #expect(markdown.contains("PASS (0 Errors)"))
        #expect(markdown.contains("28 / 28"))
    }

    @Test(
        "Every one of the 9 EnterpriseVertical categories contains >= 3 blueprints and bilingual TR/EN metadata",
        arguments: EnterpriseVertical.allCases
    )
    func allNineEnterpriseVerticalsPopulated(vertical: EnterpriseVertical) {
        #expect(EnterpriseVertical.allCases.count == 9)
        #expect(!vertical.title.isEmpty)
        #expect(!vertical.turkishTitle.isEmpty)
        #expect(!vertical.subtitle.isEmpty)
        #expect(!vertical.sfSymbol.isEmpty)
        #expect(!vertical.complianceStandards.isEmpty)

        let specs = EnterpriseBlueprintCatalog.specs(in: vertical)
        #expect(specs.count >= 3)
        #expect(specs.map(\.id) == vertical.blueprintIDs)

        let filtered = EnterpriseBlueprintCatalog.filter(vertical: vertical)
        #expect(filtered.count == specs.count)
    }

    @Test(
        "All 28 EnterpriseBlueprintID specs decode valid onboarding flows and emit balanced Swift/XML/JSON/Mermaid across all 8 layers",
        arguments: EnterpriseBlueprintID.allCases
    )
    func allTwentyEightBlueprintSpecsSynthesizeValidArtifacts(blueprintID: EnterpriseBlueprintID) throws {
        #expect(EnterpriseBlueprintID.allCases.count == 28)
        let spec = EnterpriseBlueprintCatalog.spec(for: blueprintID)

        // 1. Metadata & schema completeness
        #expect(spec.id == blueprintID)
        #expect(spec.vertical == blueprintID.vertical)
        #expect(!spec.title.isEmpty)
        #expect(!spec.subtitle.isEmpty)
        #expect(!spec.supportedPlatforms.isEmpty)
        #expect(spec.domainEntities.count >= 2)
        #expect(spec.stateProperties.count >= 2)
        #expect(spec.reducerActions.count >= 2)
        #expect(spec.apiEndpoints.count >= 2)
        #expect(spec.kpiMetrics.count >= 3)
        #expect(spec.sampleRecords.count >= 2)
        #expect(spec.onboardingPages.count >= 3)
        #expect(spec.localizationKeysTR_EN.count >= 5)
        #expect(!spec.privacyAPICategories.isEmpty)

        // 2. Onboarding flow JSON decodes via FlowDefinition.decode with 0 validation errors
        let onboardingJSON = spec.synthesizeOnboardingFlowJSON()
        let decodedFlow = try FlowDefinition.decode(onboardingJSON).get()
        let flowDiagnostics = decodedFlow.validate()
        let flowErrors = flowDiagnostics.filter { $0.severity == .error }
        #expect(flowErrors.isEmpty, "Flow validation errors in \(blueprintID.rawValue): \(flowErrors)")

        let lastPrimaryTitle = decodedFlow.pages.last?.actions.first ?? ""
        #expect(
            BlueprintArchitectureValidator.terminalActionKeywords.contains(where: {
                lastPrimaryTitle.localizedCaseInsensitiveContains($0)
            }),
            "Terminal onboarding CTA '\(lastPrimaryTitle)' in \(blueprintID.rawValue) missing completion verb"
        )

        // 3. All Swift layer synthesizers emit delimiter-balanced, ASTSourceVerifier-clean Swift 6 code
        let domainCode = spec.synthesizeDomainModels(includeSecurityHelpers: true)
        let reducerCode = spec.synthesizeReducerAndStore()
        let persistenceCode = spec.synthesizeSwiftDataModels()
        let apiCode = spec.synthesizeAPIClient()
        let viewCode = spec.synthesizeSwiftUIView(
            theme: spec.vertical.recommendedThemePreset.tokens,
            layers: EnterpriseLayerKind.allCases
        )
        let testsCode = spec.synthesizeSwiftTests()
        let unifiedPreview = spec.synthesizeUnifiedPreview(
            theme: spec.vertical.recommendedThemePreset.tokens,
            layers: EnterpriseLayerKind.allCases
        )

        for (layerLabel, swiftSource) in [
            ("DomainModels", domainCode),
            ("ReducerAndStore", reducerCode),
            ("SwiftDataPersistence", persistenceCode),
            ("RESTAPIClient", apiCode),
            ("SwiftUIView", viewCode),
            ("SwiftTestingSuite", testsCode),
            ("UnifiedPreview", unifiedPreview)
        ] {
            let delim = BlueprintArchitectureValidator.auditSwiftDelimiterBalance(in: swiftSource)
            #expect(delim.isBalanced, "\(blueprintID.rawValue) \(layerLabel) delimiter imbalance: \(delim)")
            let astCheck = ASTSourceVerifier.verifySource(code: swiftSource, filePath: "\(layerLabel).swift")
            #expect(astCheck.isValid, "\(blueprintID.rawValue) \(layerLabel) AST verifier issues: \(astCheck.issues)")
        }

        // 4. PrivacyInfo.xcprivacy XML parses cleanly via ApplePrivacyManifestBuilder
        let privacyXML = spec.synthesizePrivacyManifestXML()
        #expect(privacyXML.contains("<plist version=\"1.0\">"))
        #expect(privacyXML.contains("NSPrivacyAccessedAPITypes"))
        let parsedPrivacy = try ApplePrivacyManifestBuilder.parsePlistXML(privacyXML)
        #expect(!parsedPrivacy.accessedAPIDeclarations.isEmpty)

        // 5. Localizable.xcstrings JSON parses as valid Apple String Catalog v1.0 JSON with TR + EN entries
        let xcstrings = spec.synthesizeLocalizableStringsCatalogJSON()
        let xcData = try #require(xcstrings.data(using: .utf8))
        let xcObj = try #require(JSONSerialization.jsonObject(with: xcData) as? [String: Any])
        #expect(xcObj["sourceLanguage"] as? String == "en")
        #expect(xcObj["version"] as? String == "1.0")
        let stringsDict = try #require(xcObj["strings"] as? [String: Any])
        #expect(stringsDict.count >= spec.localizationKeysTR_EN.count)

        // 6. Mermaid architecture diagram contains graph edges across layers
        let mermaid = spec.synthesizeMermaidArchitecture()
        #expect(mermaid.contains("flowchart") || mermaid.contains("graph"))
        #expect(mermaid.contains("-->"))
    }
}

// MARK: - XCTest Suite for Catalog Queries, Layer Permutations & 14-File Disk Export Verification

final class EnterpriseBlueprintsXCTests: XCTestCase {
    func testCatalogSearchPlatformFilteringComplexityTiersAndLegacyDomainBridge() {
        // Verify vertical blueprint counts sum to exactly 28
        let sumAcrossVerticals = EnterpriseVertical.allCases.reduce(0) { acc, vert in
            acc + EnterpriseBlueprintCatalog.specs(in: vert).count
        }
        XCTAssertEqual(sumAcrossVerticals, 28)

        // Enterprise & Security vertical has 4 blueprints; the other 8 verticals have 3 each (8*3 + 4 = 28)
        XCTAssertEqual(EnterpriseBlueprintCatalog.specs(in: .enterpriseSecurity).count, 4)
        XCTAssertEqual(EnterpriseBlueprintCatalog.specs(in: .fintechBanking).count, 3)

        // Platform support queries across all 5 Apple OS targets
        XCTAssertEqual(TargetApplePlatform.allCases.count, 5)
        for platform in TargetApplePlatform.allCases {
            let matching = EnterpriseBlueprintCatalog.specs(supporting: platform)
            XCTAssertFalse(matching.isEmpty, "Expected blueprints supporting \(platform.rawValue)")
        }

        // Complexity tier filtering across Professional, Enterprise, and Mission-Critical
        for tier in BlueprintComplexityTier.allCases {
            let matching = EnterpriseBlueprintCatalog.search(complexity: tier)
            XCTAssertFalse(matching.isEmpty, "Expected blueprints in complexity tier \(tier.rawValue)")
            XCTAssertGreaterThan(tier.estimatedWeeksSaved, 0)
        }

        // Bilingual English + Turkish full-text search
        let turkishSearch = EnterpriseBlueprintCatalog.search(query: "Hazine")
        XCTAssertFalse(turkishSearch.isEmpty)
        let ragSearch = EnterpriseBlueprintCatalog.search(query: "RAG")
        XCTAssertTrue(ragSearch.contains(where: { $0.id == .localRAGKnowledgeWorkbench }))

        // Legacy 4-case BlueprintDomain recommendation bridge
        for legacyDomain in BlueprintDomain.allCases {
            let recommended = ChiefKitBlueprintsModule.recommendedBlueprints(for: legacyDomain)
            XCTAssertGreaterThanOrEqual(recommended.count, 2)
        }
    }

    func testAllEightEnterpriseLayerKindMetadataAndSelectiveLayerPermutations() {
        XCTAssertEqual(EnterpriseLayerKind.allCases.count, 8)
        for layer in EnterpriseLayerKind.allCases {
            XCTAssertFalse(layer.subtitle.isEmpty)
            XCTAssertFalse(layer.sfSymbol.isEmpty)
        }

        // Test minimal UI + Reducer subset vs full 8-layer stack & both dependency strategies
        let minimalRequest = BlueprintExportRequest(
            blueprintID: .neobankMultiCurrencyTreasury,
            customAppName: "360 Treasury Desk!",
            bundleIdentifier: "io.hnmlabs.treasurydesk",
            enabledLayers: [.swiftBlocksUI, .swiftStateReducer],
            targetPlatforms: [.macOS, .iOS],
            dependencyStrategy: .standaloneOffline
        )
        // Leading digit sanitized to valid Swift identifier `App360TreasuryDesk`
        XCTAssertEqual(minimalRequest.resolvedTargetName, "App360TreasuryDesk")
        XCTAssertEqual(minimalRequest.resolvedBundleIdentifier, "io.hnmlabs.treasurydesk")
        XCTAssertTrue(minimalRequest.isLayerEnabled(.swiftBlocksUI))
        XCTAssertFalse(minimalRequest.isLayerEnabled(.restAPIClient))

        let minimalWorkspace = BlueprintWorkspaceExporter.generateWorkspace(request: minimalRequest)
        XCTAssertEqual(minimalWorkspace.files.count, 14)
        for swiftFile in minimalWorkspace.swiftSourceFiles where swiftFile.relativePath != "Package.swift" {
            let check = ASTSourceVerifier.verifySource(code: swiftFile.content, filePath: swiftFile.relativePath)
            XCTAssertTrue(check.isValid, "Minimal layer permutation broke \(swiftFile.relativePath): \(check.issues)")
        }

        let spmEcosystemWorkspace = BlueprintWorkspaceExporter.generateWorkspace(
            for: .localRAGKnowledgeWorkbench,
            layers: EnterpriseLayerKind.allCases,
            platforms: [.macOS, .iOS, .visionOS],
            dependencyStrategy: .chiefKitEcosystemSPM
        )
        XCTAssertEqual(spmEcosystemWorkspace.files.count, 14)
        let manifestContent = spmEcosystemWorkspace.file(at: "Package.swift")?.content ?? ""
        XCTAssertTrue(manifestContent.contains("swift-tools-version: 6.0"))
        XCTAssertTrue(manifestContent.contains("HNMLabs/SwiftBlocks"))
        XCTAssertTrue(manifestContent.contains("HNMLabs/SwiftState"))
        XCTAssertTrue(manifestContent.contains(".visionOS(.v2)"))
    }

    func testInMemoryFourteenFileWorkspaceGenerationAcrossEverySingleBlueprint() throws {
        // Verify all 28 blueprints generate complete 14-file in-memory workspaces with valid Swift & JSON/XML resources
        for id in EnterpriseBlueprintID.allCases {
            let req = BlueprintExportRequest(blueprintID: id)
            let expectedPaths = BlueprintWorkspaceExporter.previewFileTree(for: req)
            XCTAssertEqual(expectedPaths.count, 14)

            let ws = BlueprintWorkspaceExporter.generateWorkspace(request: req)
            XCTAssertEqual(ws.files.count, 14)
            XCTAssertEqual(ws.files.map(\.relativePath), expectedPaths)
            XCTAssertEqual(ws.resourceFiles.count, 4)
            XCTAssertGreaterThan(ws.totalLinesOfCode, 300)
            XCTAssertGreaterThan(ws.totalBytes, 8_000)

            let app = ws.targetName
            let w3cContent = try XCTUnwrap(ws.file(at: "Sources/\(app)/Resources/design-tokens.w3c.json")?.content)
            let w3cData = try XCTUnwrap(w3cContent.data(using: .utf8))
            XCTAssertNotNil(try JSONSerialization.jsonObject(with: w3cData) as? [String: Any])
        }
    }

    func testBlueprintWorkspaceExporterDiskWriteRepresentativeVerticalsAndOverwriteGuard() throws {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent(
            "ChiefKitBlueprintsExportTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer {
            try? fm.removeItem(at: tempRoot)
        }

        // Export one flagship blueprint from each of the 9 industry verticals to disk and verify all 14 files!
        let representativeIDs: [EnterpriseBlueprintID] = EnterpriseVertical.allCases.compactMap {
            $0.blueprintIDs.first
        }
        XCTAssertEqual(representativeIDs.count, 9)

        for blueprintID in representativeIDs {
            let receipt = try BlueprintWorkspaceExporter.exportToDisk(
                blueprintID: blueprintID,
                dependencyStrategy: .standaloneOffline,
                destinationParentDirectory: tempRoot,
                overwriteExisting: false
            )

            XCTAssertEqual(receipt.writtenFileURLs.count, 14)
            XCTAssertEqual(receipt.workspace.files.count, 14)
            XCTAssertTrue(fm.fileExists(atPath: receipt.rootDirectoryURL.path))

            for fileURL in receipt.writtenFileURLs {
                XCTAssertTrue(fm.fileExists(atPath: fileURL.path), "Expected exported file at \(fileURL.path)")
                let diskContent = try String(contentsOf: fileURL, encoding: .utf8)
                XCTAssertFalse(diskContent.isEmpty)
            }

            // Verify ASTSourceVerifier directory check over the exported Sources/<Target> folder!
            let sourcesDir = receipt.rootDirectoryURL
                .appendingPathComponent("Sources")
                .appendingPathComponent(receipt.workspace.targetName)
            let dirReport = ASTSourceVerifier.verifyDirectory(at: sourcesDir, recursive: true)
            XCTAssertTrue(
                dirReport.isValid,
                "Exported Sources directory for \(blueprintID.rawValue) failed ASTSourceVerifier: \(dirReport.fileReports.flatMap(\.issues))"
            )
            XCTAssertEqual(dirReport.totalFilesVerified, 6)
        }

        // Re-exporting an existing target with `overwriteExisting: false` must throw `.destinationAlreadyExists`
        let firstID = representativeIDs[0]
        XCTAssertThrowsError(
            try BlueprintWorkspaceExporter.exportToDisk(
                blueprintID: firstID,
                destinationParentDirectory: tempRoot,
                overwriteExisting: false
            )
        ) { error in
            guard case BlueprintExportError.destinationAlreadyExists = error else {
                XCTFail("Expected BlueprintExportError.destinationAlreadyExists, got \(error)")
                return
            }
        }

        // Re-exporting with `overwriteExisting: true` succeeds cleanly
        let overwrittenReceipt = try BlueprintWorkspaceExporter.exportToDisk(
            blueprintID: firstID,
            destinationParentDirectory: tempRoot,
            overwriteExisting: true
        )
        XCTAssertEqual(overwrittenReceipt.writtenFileURLs.count, 14)
    }

    func testValidatorDetectsMalformedDelimiterStringsCorrectly() {
        let balanced = BlueprintArchitectureValidator.auditSwiftDelimiterBalance(
            in: """
            public struct Example: Sendable {
                public let items: [String] = ["{not a brace}", "/* not a comment */"]
                /* Nested /* comment { [ ( */ end */
                public func compute() -> (Int, Int) { (1, 2) }
            }
            """
        )
        XCTAssertTrue(balanced.isBalanced)

        let unclosedBrace = BlueprintArchitectureValidator.auditSwiftDelimiterBalance(
            in: "public struct Broken {\n    let x = [1, 2]\n"
        )
        XCTAssertFalse(unclosedBrace.isBalanced)
        XCTAssertEqual(unclosedBrace.curlyDelta, 1)

        let negativeParen = BlueprintArchitectureValidator.auditSwiftDelimiterBalance(
            in: "let x = 1)\n"
        )
        XCTAssertFalse(negativeParen.isBalanced)
        XCTAssertTrue(negativeParen.hasNegativeNesting)

        let unterminatedString = BlueprintArchitectureValidator.auditSwiftDelimiterBalance(
            in: "let broken = \"unterminated\n"
        )
        XCTAssertFalse(unterminatedString.isBalanced)
        XCTAssertTrue(unterminatedString.hasUnterminatedLiteralOrComment)
    }

    func testAllNineVerticalRostersUniqueTargetNamesBundleIdentifiersAndFileCategories() {
        // Explicit verification of the 9 industry verticals and exact blueprint counts (3x8 + 4 = 28)
        let expectedCounts: [(EnterpriseVertical, Int)] = [
            (.fintechBanking, 3),
            (.aiDeveloperTools, 3),
            (.healthBiometrics, 3),
            (.commerceLogistics, 3),
            (.productivityCollab, 3),
            (.mediaCreator, 3),
            (.educationScience, 3),
            (.smartHomeMobility, 3),
            (.enterpriseSecurity, 4)
        ]

        var totalChecked = 0
        for (vertical, count) in expectedCounts {
            let verticalSpecs = EnterpriseBlueprintCatalog.specs(in: vertical)
            XCTAssertEqual(
                verticalSpecs.count,
                count,
                "Vertical \(vertical.rawValue) expected \(count) blueprints, got \(verticalSpecs.count)"
            )
            for spec in verticalSpecs {
                XCTAssertEqual(spec.vertical, vertical)
                XCTAssertFalse(spec.typePrefix.isEmpty)
                XCTAssertFalse(spec.securityPostureHighlights.isEmpty)
                totalChecked += 1
            }
        }
        XCTAssertEqual(totalChecked, 28)

        // Verify 100% unique defaultAppTargetName and defaultBundleIdentifier across all 28 blueprints
        let targetNames = Set(EnterpriseBlueprintID.allCases.map(\.defaultAppTargetName))
        let bundleIDs = Set(EnterpriseBlueprintID.allCases.map(\.defaultBundleIdentifier))
        XCTAssertEqual(targetNames.count, 28)
        XCTAssertEqual(bundleIDs.count, 28)

        // Verify every generated 14-file workspace covers all 11 BlueprintGeneratedFileCategory roles
        XCTAssertEqual(BlueprintGeneratedFileCategory.allCases.count, 11)
        let sampleWorkspace = BlueprintWorkspaceExporter.generateWorkspace(for: .neobankMultiCurrencyTreasury)
        let presentCategories = Set(sampleWorkspace.files.map(\.category))
        for category in BlueprintGeneratedFileCategory.allCases {
            XCTAssertTrue(
                presentCategories.contains(category),
                "Generated 14-file workspace missing category \(category.rawValue)"
            )
            XCTAssertFalse(category.displayTitle.isEmpty)
        }

        // Verify requiredPackages resolution scales with enabled layers
        let spec = EnterpriseBlueprintCatalog.spec(for: .neobankMultiCurrencyTreasury)
        let fullPackages = spec.requiredPackages(for: EnterpriseLayerKind.allCases)
        XCTAssertTrue(fullPackages.contains(.swiftBlocks))
        XCTAssertTrue(fullPackages.contains(.swiftState))
        XCTAssertTrue(fullPackages.contains(.notebookFlowKit))
        XCTAssertTrue(fullPackages.contains(.coreLocalAIKit))

        let uiOnlyPackages = spec.requiredPackages(for: [.swiftBlocksUI])
        XCTAssertEqual(uiOnlyPackages, [.swiftBlocks])
    }

    func testBlueprintArchitectureValidatorDetectsSyntheticInvalidBlueprintSpecs() {
        let validBase = EnterpriseBlueprintCatalog.spec(for: .neobankMultiCurrencyTreasury)
        let baseReport = BlueprintArchitectureValidator.validate(validBase)
        XCTAssertTrue(baseReport.isValid)
        XCTAssertEqual(baseReport.issues.count, 0)

        // Construct a deliberately broken spec with:
        // - mismatched vertical (.mediaCreator on a .fintechBanking ID)
        // - empty supportedPlatforms
        // - insufficient domain entities (0), actions (0), and endpoints (0)
        // - terminal onboarding page missing completion verb ("Next Step" instead of Finish/Complete/Start/Launch)
        // - empty Turkish translation string
        // - unbalanced curly brace inside customSwiftUIInspectorSwift
        let brokenSpec = EnterpriseBlueprintSpec(
            id: .neobankMultiCurrencyTreasury,
            vertical: .mediaCreator,
            title: "Broken Spec",
            subtitle: "Deliberately malformed for negative validator testing",
            sfSymbol: "exclamationmark.triangle",
            complexityTier: .professional,
            supportedPlatforms: [],
            domainEntities: [],
            stateProperties: [],
            reducerActions: [],
            apiEndpoints: [],
            kpiMetrics: validBase.kpiMetrics,
            sampleRecords: validBase.sampleRecords,
            onboardingPages: [
                FlowPage(
                    id: "welcome",
                    title: "Welcome",
                    body: "First screen",
                    style: "hero",
                    actions: ["Continue"]
                ),
                FlowPage(
                    id: "middle",
                    title: "Setup",
                    body: "Second screen",
                    style: "card",
                    actions: ["Next Step"]
                )
            ],
            localizationKeysTR_EN: [
                BlueprintLocalizedKey(key: "broken.key", en: "English Text", tr: "")
            ],
            privacyAPICategories: [],
            customStateComputedSwift: "",
            customSwiftUIInspectorSwift: "public func brokenHelper() { let x = [1, 2 ",
            localAICopilotRoutineSwift: "",
            customUnitTestsSwift: "",
            securityPostureHighlights: []
        )

        let brokenReport = BlueprintArchitectureValidator.validate(brokenSpec)
        XCTAssertFalse(brokenReport.isValid)
        XCTAssertGreaterThan(brokenReport.errorCount, 3)

        let issueCategories = Set(brokenReport.issues.map(\.category))
        XCTAssertTrue(issueCategories.contains(.catalogCoverage))
        XCTAssertTrue(issueCategories.contains(.domainSchema))
        XCTAssertTrue(issueCategories.contains(.onboardingFlow))
        XCTAssertTrue(issueCategories.contains(.swiftSyntaxBalance))
        XCTAssertTrue(issueCategories.contains(.localizationTR_EN))
    }

    func testEnterpriseBlueprintSpecAndValidationReportCodableRoundTrips() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()

        // Codable round-trip across all 28 EnterpriseBlueprintSpec definitions
        let allSpecs = EnterpriseBlueprintCatalog.allSpecs
        let encodedSpecs = try encoder.encode(allSpecs)
        let decodedSpecs = try decoder.decode([EnterpriseBlueprintSpec].self, from: encodedSpecs)
        XCTAssertEqual(decodedSpecs, allSpecs)

        // Codable round-trip of full BlueprintCatalogValidationReport across alternate StudioThemePreset
        let violetValidation = ChiefKitBlueprintsModule.validateCatalog(
            theme: StudioThemePreset.midnightViolet.tokens
        )
        XCTAssertTrue(violetValidation.isValid)
        let encodedReport = try encoder.encode(violetValidation)
        let decodedReport = try decoder.decode(BlueprintCatalogValidationReport.self, from: encodedReport)
        XCTAssertEqual(decodedReport, violetValidation)
        XCTAssertNotNil(decodedReport.report(for: .socSIEMThreatHuntingConsole))
    }
}
