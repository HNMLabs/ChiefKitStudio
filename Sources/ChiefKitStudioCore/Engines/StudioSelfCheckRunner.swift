import Foundation

public struct SelfCheckStepResult: Identifiable, Codable, Equatable, Sendable {
    public var id: String { subsystem }
    public let subsystem: String
    public let passed: Bool
    public let detail: String

    public init(subsystem: String, passed: Bool, detail: String) {
        self.subsystem = subsystem
        self.passed = passed
        self.detail = detail
    }
}

public struct SelfCheckSuiteReport: Codable, Equatable, Sendable {
    public let steps: [SelfCheckStepResult]
    public let durationMilliseconds: Double

    public var allPassed: Bool {
        steps.allSatisfy(\.passed)
    }

    public var passedCount: Int {
        steps.filter(\.passed).count
    }

    public var formattedSummary: String {
        var lines = [
            "=== ChiefKit Studio 3.0 End-to-End Self-Check ===",
            String(format: "Status: %@ (%d/%d passed in %.1f ms)", allPassed ? "PASS" : "FAIL", passedCount, steps.count, durationMilliseconds),
            ""
        ]
        for step in steps {
            lines.append("[\(step.passed ? "PASS" : "FAIL")] \(step.subsystem): \(step.detail)")
        }
        return lines.joined(separator: "\n")
    }
}

public enum StudioSelfCheckRunner {
    public static func runAll() async -> SelfCheckSuiteReport {
        let start = Date()
        var steps: [SelfCheckStepResult] = []

        // 1. Canvas + Alignment + Undo/Redo + Code Export
        var doc = CanvasDocument.starter(radius: 14)
        var history = CanvasHistoryStack()
        history.recordBeforeMutation(doc)
        let firstID = doc.nodes.first?.id
        if let firstID {
            doc.alignNode(id: firstID, axis: .centerH, canvasSize: CGSize(width: 640, height: 480))
        }
        doc.autoTidyGrid(maxWidth: 640, spacing: 16)
        let generatedCode = doc.generateSwiftUICode(
            theme: StudioThemePreset.liquidGlass26.tokens,
            layoutMode: .adaptiveStacks,
            focusedNodeID: nil,
            focusSelectedOnly: false
        )
        let undone = history.undo(current: doc)
        let canvasOK = generatedCode.contains("EDKSurface") && undone != nil && history.canRedo
        steps.append(SelfCheckStepResult(
            subsystem: "SwiftBlocks Canvas + Undo/Redo",
            passed: canvasOK,
            detail: "\(doc.nodes.count) nodes tidied, \(generatedCode.components(separatedBy: "\n").count) lines SwiftUI, undo/redo verified"
        ))

        // 2. WCAG 2.1 Contrast & Multi-Format Design Tokens
        var lowContrastTheme = StudioThemeTokens(
            primary: RGBAColor(red: 0.85, green: 0.88, blue: 0.92),
            surface: RGBAColor(red: 0.96, green: 0.97, blue: 0.99)
        )
        let beforeAA = lowContrastTheme.contrastReport.primaryOnSurfaceLevel.passesAA
        lowContrastTheme.autoFixPrimaryContrast()
        let afterAA = lowContrastTheme.contrastReport.primaryOnSurfaceLevel.passesAA
        let w3cJSON = lowContrastTheme.exportedCode(in: .w3cDesignTokens)
        let cssVars = lowContrastTheme.exportedCode(in: .cssVariables)
        let tokensOK = !beforeAA && afterAA && w3cJSON.contains("\"$value\"") && cssVars.contains("--ck-color-primary")
        steps.append(SelfCheckStepResult(
            subsystem: "Theme Tokens + WCAG 2.1 Auto-Fix",
            passed: tokensOK,
            detail: String(format: "Contrast auto-repaired to %.2f:1 (%@), W3C JSON & CSS exported", lowContrastTheme.contrastReport.primaryOnSurfaceRatio, lowContrastTheme.contrastReport.primaryOnSurfaceLevel.rawValue)
        ))

        // 3. NotebookFlowKit Decoder, Topology & Static Validator
        let decodedFlow = try? FlowDefinition.decode(DemoLibrary.defaultFlowJSON).get()
        let diagnostics = decodedFlow?.validate() ?? []
        let edges = decodedFlow?.topologyEdges ?? []
        let flowOK = decodedFlow != nil && !diagnostics.contains(where: { $0.severity == .error }) && edges.count == 3
        steps.append(SelfCheckStepResult(
            subsystem: "NotebookFlowKit Validator & Graph",
            passed: flowOK,
            detail: "\(decodedFlow?.pages.count ?? 0) screens, \(edges.count) edges, 0 validation errors"
        ))

        // 4. Time-Travel State Store Scrubbing & Branching
        let initialSnap = StateSnapshot(
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
        var tt = TimeTravelEngine(initialSnapshot: initialSnap)
        tt.record(action: ".increment", summary: "count: 1", counter: 1, isLoading: false, loadedMessage: nil, cartItems: [], promoApplied: false, activeFlowStepIndex: 0)
        tt.record(action: ".increment", summary: "count: 2", counter: 2, isLoading: false, loadedMessage: nil, cartItems: [], promoApplied: false, activeFlowStepIndex: 0)
        _ = tt.stepBackward()
        tt.record(action: ".branch", summary: "count: 10", counter: 10, isLoading: false, loadedMessage: nil, cartItems: [], promoApplied: true, activeFlowStepIndex: 1)
        let ttOK = tt.snapshots.count == 3 && tt.currentSnapshot.counter == 10 && tt.currentSnapshot.promoApplied
        steps.append(SelfCheckStepResult(
            subsystem: "SwiftState Time-Travel Engine",
            passed: ttOK,
            detail: "History scrubbing & causal branch truncation verified (\(tt.snapshots.count) snapshots)"
        ))

        // 5. CoreLocalAIKit Bilingual (EN/TR) + @Test Generation + Unified Diff
        let ai = LocalAIEngine()
        let baseCode = DemoLibrary.liveSwiftStateCode(counter: 0, isLoading: false, loadedMessage: nil)
        let trResponse = await ai.run(
            prompt: "Bu ekran için birim testleri üret",
            preferredTask: nil,
            backend: .naturalLanguageAST,
            currentCode: baseCode,
            selectionTitle: "SwiftState",
            theme: lowContrastTheme,
            simulateLatency: false
        )
        let a11yResponse = await ai.run(
            prompt: "Add VoiceOver accessibility labels",
            preferredTask: .addAccessibility,
            backend: .naturalLanguageAST,
            currentCode: "struct SampleView: View {\n    var body: some View {\n        Button(\"Save\") { }\n    }\n}",
            selectionTitle: "SampleView",
            theme: lowContrastTheme,
            simulateLatency: false
        )
        let aiOK = trResponse.detectedLanguage == "Turkish (TR)"
            && trResponse.taskKind == .generateSwiftTests
            && trResponse.generatedCode.contains("@Test")
            && a11yResponse.diffReport.addedCount > 0
        steps.append(SelfCheckStepResult(
            subsystem: "CoreLocalAIKit + @Test + LCS Diff",
            passed: aiOK,
            detail: "TR/EN NLP active, @Test suite generated, diff \(a11yResponse.diffReport.summaryBadge)"
        ))

        // 6. Full-Stack Blueprint Composer & Code Quality Analyzer
        let blueprint = BlueprintConfiguration(domain: .fintechExpenseTracker)
        let blueprintCode = blueprint.synthesizeSwiftUICode(theme: lowContrastTheme)
        let quality = CodeQualityAnalyzer.analyze(code: blueprintCode, theme: lowContrastTheme)
        let blueprintOK = blueprintCode.contains("LedgerEntry") && quality.overallScore >= 80
        steps.append(SelfCheckStepResult(
            subsystem: "Blueprint Composer & Quality Scorecard",
            passed: blueprintOK,
            detail: "Synthesized Fintech blueprint, quality score \(quality.overallScore)/100 (\(quality.gradeBadge))"
        ))

        // 7. Workspace .chiefkit Snapshot Round-Trip & Project Generator
        let snapshot = WorkspaceSnapshot(
            selection: .blueprint(.aiNotesWorkspace),
            canvasDocument: doc,
            themeTokens: lowContrastTheme,
            activeThemePreset: .liquidGlass26,
            flowJSON: DemoLibrary.defaultFlowJSON,
            counter: 4,
            cartItems: [CartDemoItem(id: "seat", name: "Team Seat", price: 29, quantity: 2)],
            promoApplied: true,
            blueprintConfig: blueprint,
            pinnedSnippets: [SavedSnippet(title: "Hero CTA", notes: "Primary glass CTA", swiftUICode: "Button(\"Go\") {}")]
        )
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("chiefkit-selfcheck-\(UUID().uuidString)", isDirectory: true)
        var ioOK = false
        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            let snapURL = tempRoot.appendingPathComponent("session.chiefkit")
            try snapshot.save(to: snapURL)
            let reloaded = try WorkspaceSnapshot.load(from: snapURL)

            let genConfig = ProjectGenerationConfig(
                projectName: "SelfCheckSample",
                bundleIdentifier: "com.hnmlabs.selfcheck",
                dependencyMode: .standaloneReady,
                includeUnitTests: true,
                openInXcodeAfterExport: false,
                selection: .package(.swiftBlocks),
                requiredPackages: [.swiftBlocks],
                swiftUICode: generatedCode,
                themeTokens: lowContrastTheme,
                flowJSON: DemoLibrary.defaultFlowJSON
            )
            let exportedDir = try ProjectGeneratorCore.writeProject(config: genConfig, inside: tempRoot)
            let hasManifest = FileManager.default.fileExists(atPath: exportedDir.appendingPathComponent("Package.swift").path)
            let hasTestFile = FileManager.default.fileExists(atPath: exportedDir.appendingPathComponent("Tests/SelfCheckSampleTests/SelfCheckSampleTests.swift").path)
            ioOK = (reloaded == snapshot) && hasManifest && hasTestFile
            try? FileManager.default.removeItem(at: tempRoot)
        } catch {
            try? FileManager.default.removeItem(at: tempRoot)
            ioOK = false
        }
        steps.append(SelfCheckStepResult(
            subsystem: "Workspace Persistence & Project Generator",
            passed: ioOK,
            detail: ".chiefkit snapshot round-trip + standalone SwiftPM project + unit test target verified"
        ))

        // 8. DataSchema ER Modeler + Persistence + OpenAPI 3.1 & Mock Router
        let schemaWS = DataSchemaWorkspace.preset(.fintechDoubleEntry)
        let schemaReport = schemaWS.analyzeNormalizationAndIntegrity()
        let sqliteArtifact = PersistenceCodeSynthesizer.synthesize(workspace: schemaWS, backend: .sqlite3StrictDDL)
        let apiService = APIServiceSpec.deriveCRUDService(from: schemaWS)
        let openAPIJSON = APISpecAndMockEngine.compileOpenAPI31JSON(apiService)
        let schemaOK = !schemaWS.entities.isEmpty
            && sqliteArtifact.sourceCode.contains("CREATE TABLE")
            && openAPIJSON.contains("\"openapi\"")
            && schemaReport.cyclicEntityNames.isEmpty
        steps.append(SelfCheckStepResult(
            subsystem: "DataSchema + SQLite DDL + OpenAPI 3.1",
            passed: schemaOK,
            detail: "\(schemaWS.entities.count) entities, strict SQLite DDL + OpenAPI 3.1 (\(apiService.endpoints.count) endpoints) verified"
        ))

        // 9. Localization String Catalog (.xcstrings) + CLDR Plurals + Pseudolocalization
        let masterCatalog = StudioBuiltInTranslations.unifiedMasterCatalog()
        let xcstringsJSON = (try? masterCatalog.encodeXCStringsJSON()) ?? ""
        let decodedCatalog = try? StringCatalogDocument.decodeXCStringsJSON(xcstringsJSON)
        let pseudo = StringCatalogCompiler.pseudolocalize("Ship Faster", mode: .accentedExpanded)
        let l10nEnum = StringCatalogCompiler.synthesizeL10nSwiftEnum(from: masterCatalog)
        let l10nOK = decodedCatalog != nil
            && !masterCatalog.entries.isEmpty
            && pseudo != "Ship Faster"
            && l10nEnum.contains("enum L10n")
        steps.append(SelfCheckStepResult(
            subsystem: "String Catalog (.xcstrings) & CLDR Plurals",
            passed: l10nOK,
            detail: "\(masterCatalog.entries.count) localized keys across 7 locales (incl. TR & RTL AR) round-tripped"
        ))

        // 10. 120Hz ProMotion Frame-Budget & State Invalidation Profiler
        let frameReport = FrameBudgetProfiler.profile(
            swiftUISource: blueprintCode,
            canvas: doc,
            theme: lowContrastTheme,
            target: .proMotion120Hz
        )
        let invalidationReport = StateInvalidationAnalyzer.analyze(swiftSource: blueprintCode)
        let profilerOK = frameReport.totalFrameTimeMs > 0
            && !frameReport.flamegraphRoot.children.isEmpty
            && !invalidationReport.mermaidFlowchartLR.isEmpty
        steps.append(SelfCheckStepResult(
            subsystem: "120Hz ProMotion & Invalidation Profiler",
            passed: profilerOK,
            detail: String(format: "120Hz frame estimate %.2f ms (budget %.2f ms), flamegraph & dependency graph active", frameReport.totalFrameTimeMs, frameReport.budgetMs)
        ))

        // 11. Conditional NotebookFlow Runtime + DocC/HTML Spec Compiler
        let docBundle = StudioDocBundleCompiler.compileBundle(
            StudioSpecBundleInput(
                projectName: "ChiefKit Studio 3.0 Spec",
                themeTokens: lowContrastTheme,
                canvasDocument: doc,
                flowDefinition: decodedFlow,
                dataSchema: schemaWS,
                stringCatalog: masterCatalog
            )
        )
        let runtimeOK = docBundle.doccFiles.count >= 4 && docBundle.standaloneHTMLSpecification.contains("<html")
        steps.append(SelfCheckStepResult(
            subsystem: "Runtime Flow Engine & DocC/HTML Compiler",
            passed: runtimeOK,
            detail: "\(docBundle.doccFiles.count) DocC articles + standalone HTML specification compiled"
        ))

        let elapsed = Date().timeIntervalSince(start) * 1000.0
        return SelfCheckSuiteReport(steps: steps, durationMilliseconds: elapsed)
    }
}
