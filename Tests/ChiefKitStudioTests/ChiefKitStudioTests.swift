import Foundation
import XCTest
@testable import ChiefKitStudioCore
@testable import ChiefKitStudio

final class ChiefKitStudioTests: XCTestCase {
    // MARK: - 1. SwiftBlocks Canvas, Alignment, Tidy Grid & Undo/Redo

    func testCanvasSwiftUIGenerationAdaptiveAndPositionedAndFocusedNode() {
        let doc = CanvasDocument.starter(radius: 14)
        let theme = StudioThemePreset.liquidGlass26.tokens
        XCTAssertFalse(doc.nodes.isEmpty)

        let adaptive = doc.generateSwiftUICode(
            theme: theme,
            layoutMode: .adaptiveStacks,
            focusedNodeID: nil,
            focusSelectedOnly: false
        )
        XCTAssertTrue(adaptive.contains("struct CustomBlocksCanvasView: View"))
        XCTAssertTrue(adaptive.contains("VStack"))
        XCTAssertTrue(adaptive.contains(".edkLiquidGlass"))

        let positioned = doc.generateSwiftUICode(
            theme: theme,
            layoutMode: .positionedCanvas,
            focusedNodeID: nil,
            focusSelectedOnly: false
        )
        XCTAssertTrue(positioned.contains("ZStack(alignment: .topLeading)"))
        XCTAssertTrue(positioned.contains(".offset("))

        let focused = doc.generateSwiftUICode(
            theme: theme,
            layoutMode: .adaptiveStacks,
            focusedNodeID: doc.nodes.first?.id,
            focusSelectedOnly: true
        )
        XCTAssertTrue(focused.contains("struct SelectedBlockPreview: View"))
    }

    func testCanvasAlignmentAxesAndLockInvariants() throws {
        var doc = CanvasDocument.starter(radius: 12)
        let id = try XCTUnwrap(doc.nodes.first?.id)
        let canvas = CGSize(width: 640, height: 480)

        doc.alignNode(id: id, axis: .right, canvasSize: canvas, margin: 24)
        let alignedRight = try XCTUnwrap(doc.nodes.first)
        XCTAssertEqual(alignedRight.frame.x, 640 - alignedRight.frame.width - 24, accuracy: 0.01)

        doc.alignNode(id: id, axis: .centerV, canvasSize: canvas, margin: 24)
        let alignedMid = try XCTUnwrap(doc.nodes.first)
        let expectedGridSnappedY = (((480.0 - alignedMid.frame.height) / 2.0) / 16.0).rounded() * 16.0
        XCTAssertEqual(alignedMid.frame.y, expectedGridSnappedY, accuracy: 0.01)

        // Locking a node prevents alignment mutations
        doc.nodes[0].isLocked = true
        let lockedX = doc.nodes[0].frame.x
        doc.alignNode(id: id, axis: .left, canvasSize: canvas, margin: 24)
        XCTAssertEqual(doc.nodes[0].frame.x, lockedX, accuracy: 0.01)
    }

    func testCanvasAutoTidyGridArrangesUnlockedNodes() {
        var doc = CanvasDocument(nodes: CanvasAutoCraftPreset.glassDashboard.buildNodes(radius: 14))
        // Scramble coordinates intentionally
        for idx in doc.nodes.indices {
            doc.nodes[idx].frame.x = 300
            doc.nodes[idx].frame.y = 300
        }
        doc.autoTidyGrid(maxWidth: 640, spacing: 16)
        XCTAssertEqual(doc.nodes[0].frame.x, 24, accuracy: 0.01)
        XCTAssertEqual(doc.nodes[0].frame.y, 24, accuracy: 0.01)
        XCTAssertNotEqual(doc.nodes[0].frame, doc.nodes[1].frame)
    }

    func testCanvasHistoryStackUndoRedoAndBranching() {
        var stack = CanvasHistoryStack(maxDepth: 10)
        let doc1 = CanvasDocument(nodes: [])
        let doc2 = CanvasDocument.starter(radius: 12)
        let doc3 = CanvasDocument(nodes: CanvasAutoCraftPreset.authCard.buildNodes(radius: 12))

        XCTAssertFalse(stack.canUndo)
        stack.recordBeforeMutation(doc1)
        stack.recordBeforeMutation(doc2)
        XCTAssertEqual(stack.undoCount, 2)

        let backTo2 = stack.undo(current: doc3)
        XCTAssertEqual(backTo2, doc2)
        XCTAssertTrue(stack.canRedo)

        let forwardTo3 = stack.redo(current: doc2)
        XCTAssertEqual(forwardTo3, doc3)

        // Recording a new edit after undo clears redo branch
        _ = stack.undo(current: doc3)
        stack.recordBeforeMutation(doc2)
        XCTAssertFalse(stack.canRedo)
    }

    // MARK: - 2. WCAG 2.1 Contrast Math & Multi-Format Token Exporters

    func testWCAGContrastMathComplianceLevelsAndAutoFix() {
        let black = RGBAColor(red: 0, green: 0, blue: 0)
        let white = RGBAColor.white
        XCTAssertEqual(black.contrastRatio(against: white), 21.0, accuracy: 0.05)
        XCTAssertEqual(WCAGComplianceLevel.evaluate(ratio: 21.0), .aaa)
        XCTAssertEqual(WCAGComplianceLevel.evaluate(ratio: 5.0), .aa)
        XCTAssertEqual(WCAGComplianceLevel.evaluate(ratio: 3.4), .aaLarge)
        XCTAssertEqual(WCAGComplianceLevel.evaluate(ratio: 1.5), .fail)

        var washedOutTheme = StudioThemeTokens(
            primary: RGBAColor(red: 0.86, green: 0.88, blue: 0.92),
            surface: RGBAColor(red: 0.97, green: 0.98, blue: 0.99)
        )
        XCTAssertFalse(washedOutTheme.contrastReport.primaryOnSurfaceLevel.passesAA)
        washedOutTheme.autoFixPrimaryContrast()
        XCTAssertTrue(washedOutTheme.contrastReport.primaryOnSurfaceLevel.passesAA)
        XCTAssertGreaterThanOrEqual(washedOutTheme.contrastReport.primaryOnSurfaceRatio, 4.5)
    }

    func testThemeTokenExportersSwiftBlocksW3CJSONAndCSSVariables() throws {
        let tokens = StudioThemePreset.emeraldMint.tokens

        let swiftOut = tokens.exportedCode(in: .swiftBlocks)
        XCTAssertTrue(swiftOut.contains("EDKTheme("))
        XCTAssertTrue(swiftOut.contains(tokens.primary.hexString))

        let w3cOut = tokens.exportedCode(in: .w3cDesignTokens)
        let parsed = try JSONSerialization.jsonObject(with: Data(w3cOut.utf8)) as? [String: Any]
        XCTAssertNotNil(parsed?["chiefkit"])

        let cssOut = tokens.exportedCode(in: .cssVariables)
        XCTAssertTrue(cssOut.contains("--ck-color-primary: \(tokens.primary.hexString);"))
        XCTAssertTrue(cssOut.contains("--ck-radius-md:"))
    }

    // MARK: - 3. NotebookFlowKit Decoder, Topology & Static Validator

    func testFlowDefinitionDecodingPrettyEncodingAndTopologyEdges() throws {
        let flow = try FlowDefinition.decode(DemoLibrary.defaultFlowJSON).get()
        XCTAssertEqual(flow.pages.count, 4)
        XCTAssertEqual(flow.topologyEdges.count, 3)
        XCTAssertEqual(flow.topologyEdges.first?.fromID, "welcome")
        XCTAssertEqual(flow.topologyEdges.first?.toID, "personalize")

        let reencoded = flow.encodedPrettyJSON()
        let roundTrip = try FlowDefinition.decode(reencoded).get()
        XCTAssertEqual(roundTrip, flow)
    }

    func testFlowStaticValidatorDetectsErrorsAndWarnings() {
        let broken = FlowDefinition(
            title: "   ",
            pages: [
                FlowPage(id: "dup", title: "First", body: "Body", style: "hero", actions: ["Go"]),
                FlowPage(id: "dup", title: "", body: "Body 2", style: "custom_unknown", actions: [])
            ]
        )
        let diagnostics = broken.validate()
        XCTAssertTrue(diagnostics.contains { $0.severity == .error && $0.message.contains("Duplicate") })
        XCTAssertTrue(diagnostics.contains { $0.severity == .error && $0.message.contains("no action buttons") })
        XCTAssertTrue(diagnostics.contains { $0.severity == .warning })
    }

    // MARK: - 4. SwiftState Time-Travel Engine

    func testTimeTravelEngineScrubbingStepNavigationAndBranchTruncation() {
        let base = StateSnapshot(
            index: 0,
            action: ".initial",
            summary: "count: 0",
            counter: 0,
            isLoading: false,
            loadedMessage: nil,
            cartItems: [],
            promoApplied: false,
            activeFlowStepIndex: 0
        )
        var engine = TimeTravelEngine(initialSnapshot: base)
        XCTAssertFalse(engine.canStepBackward)

        engine.record(action: ".inc", summary: "1", counter: 1, isLoading: false, loadedMessage: nil, cartItems: [], promoApplied: false, activeFlowStepIndex: 0)
        engine.record(action: ".inc", summary: "2", counter: 2, isLoading: false, loadedMessage: nil, cartItems: [], promoApplied: false, activeFlowStepIndex: 0)
        engine.record(action: ".inc", summary: "3", counter: 3, isLoading: false, loadedMessage: nil, cartItems: [], promoApplied: false, activeFlowStepIndex: 0)
        XCTAssertEqual(engine.snapshots.count, 4)
        XCTAssertEqual(engine.currentSnapshot.counter, 3)

        let steppedBack = engine.stepBackward()
        XCTAssertEqual(steppedBack?.counter, 2)

        let scrubbed = engine.scrub(to: 1)
        XCTAssertEqual(scrubbed.counter, 1)

        // Dispatching from historical index truncates future snapshots cleanly
        engine.record(action: ".jump", summary: "42", counter: 42, isLoading: false, loadedMessage: "Synced", cartItems: [], promoApplied: true, activeFlowStepIndex: 2)
        XCTAssertEqual(engine.snapshots.count, 3)
        XCTAssertEqual(engine.currentSnapshot.counter, 42)
        XCTAssertFalse(engine.canStepForward)
    }

    // MARK: - 5. CoreLocalAIKit Bilingual NLP, @Test Synthesis & Unified Diff

    func testLocalAIEngineTurkishAndEnglishIntentDetection() {
        let ai = LocalAIEngine()
        XCTAssertEqual(ai.detectLanguage(for: "Bu SwiftState örneğini daha iyi yaz"), "Turkish (TR)")
        XCTAssertEqual(ai.detectLanguage(for: "Bu ekran için birim testleri üret"), "Turkish (TR)")
        XCTAssertEqual(ai.detectLanguage(for: "Add VoiceOver labels to this button"), "English (EN)")

        XCTAssertEqual(ai.inferTask(from: "Bu view'a accessibility ekle", selectionTitle: "Card"), .addAccessibility)
        XCTAssertEqual(ai.inferTask(from: "Performance önerisi ver", selectionTitle: "Card"), .performanceAudit)
        XCTAssertEqual(ai.inferTask(from: "Yeni onboarding flow üret", selectionTitle: "Flow"), .generateOnboardingFlow)
        XCTAssertEqual(ai.inferTask(from: "Bu ekran için birim testleri üret", selectionTitle: "Counter"), .generateSwiftTests)
        XCTAssertEqual(ai.inferTask(from: "Compose a pricing dashboard", selectionTitle: "Canvas"), .composeCanvasBlocks)
    }

    func testLocalAIEngineAccessibilityInjectionAndDiffReport() async {
        let ai = LocalAIEngine()
        let original = """
        import SwiftUI

        struct SimpleCard: View {
            var body: some View {
                VStack {
                    Text(title)
                    Button("Continue") { }
                }
            }
        }
        """
        let response = await ai.run(
            prompt: "Bu view'a accessibility ekle",
            preferredTask: nil,
            backend: .naturalLanguageAST,
            currentCode: original,
            selectionTitle: "SimpleCard",
            theme: StudioThemeTokens(),
            simulateLatency: false
        )
        XCTAssertEqual(response.taskKind, .addAccessibility)
        XCTAssertEqual(response.detectedLanguage, "Turkish (TR)")
        XCTAssertTrue(response.generatedCode.contains("@ScaledMetric"))
        XCTAssertTrue(response.generatedCode.contains(".accessibilityLabel(\"Continue\")"))
        XCTAssertTrue(response.diffReport.hasChanges)
        XCTAssertGreaterThan(response.diffReport.addedCount, 3)
    }

    func testLocalAIEngineGeneratesValidNotebookFlowJSONAndSwiftTests() async throws {
        let ai = LocalAIEngine()
        let theme = StudioThemeTokens()
        let baseCode = DemoLibrary.liveSwiftStateCode(counter: 2, isLoading: false, loadedMessage: nil)

        let flowResp = await ai.run(
            prompt: "Yeni fintech onboarding flow üret",
            preferredTask: nil,
            backend: .naturalLanguageAST,
            currentCode: baseCode,
            selectionTitle: "NotebookFlowKit",
            theme: theme,
            simulateLatency: false
        )
        if case .notebookFlowJSON(let json, _) = flowResp.applyPayload {
            let decoded = try FlowDefinition.decode(json).get()
            XCTAssertTrue(decoded.title.contains("Fintech"))
            XCTAssertEqual(decoded.pages.count, 4)
        } else {
            XCTFail("Expected notebookFlowJSON payload")
        }

        let testResp = await ai.run(
            prompt: "Generate @Test unit tests for this reducer",
            preferredTask: nil,
            backend: .naturalLanguageAST,
            currentCode: baseCode,
            selectionTitle: "CounterReducer",
            theme: theme,
            simulateLatency: false
        )
        XCTAssertEqual(testResp.taskKind, .generateSwiftTests)
        XCTAssertTrue(testResp.generatedCode.contains("import Testing"))
        XCTAssertTrue(testResp.generatedCode.contains("@Suite"))
        XCTAssertTrue(testResp.generatedCode.contains("#expect("))
    }

    // MARK: - 6. CodeDiffEngine & CodeQualityAnalyzer

    func testCodeDiffEngineExactLCSAdditionsRemovalsAndUnchanged() {
        let before = "line1\nline2\nline3"
        let after = "line1\nline2_updated\nline3\nline4"
        let report = CodeDiffEngine.diff(original: before, updated: after)

        XCTAssertTrue(report.hasChanges)
        XCTAssertEqual(report.removedCount, 1)
        XCTAssertEqual(report.addedCount, 2)
        XCTAssertEqual(report.unchangedCount, 2)
        XCTAssertTrue(report.unifiedPatch.contains("- line2"))
        XCTAssertTrue(report.unifiedPatch.contains("+ line2_updated"))
        XCTAssertTrue(report.unifiedPatch.contains("+ line4"))
    }

    func testCodeQualityAnalyzerGradesAndRecommendations() {
        let minimalCode = "struct Bare { let x: Int! }"
        let lowReport = CodeQualityAnalyzer.analyze(code: minimalCode)
        XCTAssertFalse(lowReport.recommendations.isEmpty)

        let blueprintCode = BlueprintConfiguration(domain: .aiNotesWorkspace)
            .synthesizeSwiftUICode(theme: StudioThemeTokens())
        let highReport = CodeQualityAnalyzer.analyze(code: blueprintCode)
        XCTAssertGreaterThan(highReport.overallScore, lowReport.overallScore)
        XCTAssertGreaterThanOrEqual(highReport.overallScore, 85)
    }

    // MARK: - 7. Blueprints, DemoLibrary, Workspace Persistence & Project Generator

    func testBlueprintComposerSynthesizesAllDomainsAndTogglesLayers() {
        var config = BlueprintConfiguration(domain: .developerSaaSDashboard)
        for domain in BlueprintDomain.allCases {
            let code = config.synthesizeSwiftUICode(for: domain, theme: StudioThemeTokens())
            XCTAssertTrue(code.contains(domain.entityName))
            XCTAssertTrue(code.contains("Reducer<"))
            XCTAssertTrue(code.contains("EDKSurface"))
        }

        config.toggle(.swiftStateStore)
        XCTAssertFalse(config.isEnabled(.swiftStateStore))
        let withoutReducer = config.synthesizeSwiftUICode(theme: StudioThemeTokens())
        XCTAssertFalse(withoutReducer.contains("Reducer<"))
    }

    func testDemoLibraryTemplatesCoverAllKinds() {
        let theme = StudioThemePreset.midnightViolet.tokens
        for kind in TemplateKind.allCases {
            let example = DemoLibrary.templateExample(for: kind, theme: theme)
            XCTAssertEqual(example.kind, kind)
            XCTAssertFalse(example.swiftUICode.isEmpty)
            XCTAssertFalse(example.learningPoints.isEmpty)
            XCTAssertFalse(example.dependencySnippet.isEmpty)
        }
    }

    func testWorkspaceSnapshotRoundTripFilePersistence() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChiefKitWorkspaceTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("team.chiefkit")
        let original = WorkspaceSnapshot(
            selection: .blueprint(.habitHealthCoach),
            canvasDocument: .starter(radius: 16),
            themeTokens: StudioThemePreset.sunsetAmber.tokens,
            activeThemePreset: .sunsetAmber,
            flowJSON: DemoLibrary.defaultFlowJSON,
            counter: 12,
            cartItems: [CartDemoItem(id: "pro", name: "Pro Plan", price: 49, quantity: 3)],
            promoApplied: true,
            blueprintConfig: BlueprintConfiguration(domain: .habitHealthCoach),
            pinnedSnippets: [
                SavedSnippet(title: "Custom Glass CTA", notes: "Saved test snippet", swiftUICode: "Button(\"Ship\") {}")
            ]
        )

        try original.save(to: fileURL)
        let loaded = try WorkspaceSnapshot.load(from: fileURL)
        XCTAssertEqual(loaded, original)
        XCTAssertEqual(loaded.pinnedSnippets.first?.title, "Custom Glass CTA")
    }

    func testProjectGeneratorWritesStandaloneAndFullSPMPackagesWithTestsAndW3CTokens() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChiefKitGenTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let standaloneConfig = ProjectGenerationConfig(
            projectName: "MyStandaloneApp",
            bundleIdentifier: "com.hnmlabs.standalone",
            dependencyMode: .standaloneReady,
            includeUnitTests: true,
            openInXcodeAfterExport: false,
            selection: .package(.swiftBlocks),
            requiredPackages: [.swiftBlocks],
            swiftUICode: CanvasDocument.starter().generateSwiftUICode(
                theme: StudioThemeTokens(),
                layoutMode: .adaptiveStacks,
                focusedNodeID: nil,
                focusSelectedOnly: false
            ),
            themeTokens: StudioThemeTokens(),
            flowJSON: DemoLibrary.defaultFlowJSON
        )

        let outStandalone = try ProjectGeneratorCore.writeProject(config: standaloneConfig, inside: tempRoot)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outStandalone.appendingPathComponent("Package.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outStandalone.appendingPathComponent("Sources/MyStandaloneApp/MyStandaloneAppApp.swift").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outStandalone.appendingPathComponent("Sources/MyStandaloneApp/Resources/flow.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outStandalone.appendingPathComponent("Sources/MyStandaloneApp/Resources/design-tokens.w3c.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outStandalone.appendingPathComponent("Tests/MyStandaloneAppTests/MyStandaloneAppTests.swift").path))

        let fullSPMConfig = ProjectGenerationConfig(
            projectName: "MyFullSPMApp",
            bundleIdentifier: "com.hnmlabs.fullspm",
            dependencyMode: .fullSPM,
            includeUnitTests: false,
            openInXcodeAfterExport: false,
            selection: .blueprint(.fintechExpenseTracker),
            requiredPackages: [.swiftBlocks, .swiftState, .notebookFlowKit],
            swiftUICode: BlueprintConfiguration(domain: .fintechExpenseTracker).synthesizeSwiftUICode(theme: StudioThemeTokens()),
            themeTokens: StudioThemeTokens(),
            flowJSON: nil
        )
        let outSPM = try ProjectGeneratorCore.writeProject(config: fullSPMConfig, inside: tempRoot)
        let manifest = try String(contentsOf: outSPM.appendingPathComponent("Package.swift"), encoding: .utf8)
        XCTAssertTrue(manifest.contains("HNMLabs/SwiftBlocks.git"))
        XCTAssertTrue(manifest.contains("HNMLabs/SwiftState.git"))
        XCTAssertTrue(manifest.contains("HNMLabs/NotebookFlowKit.git"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outSPM.appendingPathComponent("Tests").path))
    }

    func testStudioSelfCheckRunnerPassesAllSubsystems() async {
        let report = await StudioSelfCheckRunner.runAll()
        XCTAssertTrue(report.allPassed, report.formattedSummary)
        XCTAssertEqual(report.steps.count, 11)
    }

    #if canImport(SwiftUI) && canImport(AppKit)
    @MainActor
    func testMacOSPlaygroundViewModelIntegration() {
        let vm = PlaygroundViewModel()
        vm.pinCurrentSnippet()
        XCTAssertEqual(vm.pinnedSnippets.count, 1)

        vm.incrementCounter()
        vm.undoHistory()
        XCTAssertEqual(vm.counter, 0)

        let snap = vm.makeWorkspaceSnapshot()
        vm.resetDemo()
        vm.applyWorkspaceSnapshot(snap)
        XCTAssertEqual(vm.pinnedSnippets.count, 1)
    }
    #endif
}
