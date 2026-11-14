#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitAST
import ChiefKitStudioCore
import SwiftUI

struct ASTWorkbenchView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    private enum ASTInspectorSubtab: String, CaseIterable, Identifiable {
        case audit = "38-Rule Static Audit"
        case hierarchy = "AST & Symbol Graph"
        case complexity = "Halstead & McCabe"
        case mermaid = "Mermaid & Formatted"

        var id: String { rawValue }
    }

    @State private var useWorkspaceSelectionCode = true
    @State private var customSourceBuffer: String = ASTWorkbenchView.defaultSampleSwiftUICode
    @State private var selectedSubtab: ASTInspectorSubtab = .audit
    @State private var selectedCategoryFilter: ASTAuditCategory?
    @State private var extractTargetComponent = "VStack"
    @State private var extractStructName = "ExtractedPulseHeader"
    @State private var selectedTestFramework: ASTTestFrameworkTarget = .both
    @State private var lastEditLog: [ASTTransformEdit] = []
    @State private var lastCanvasImportNote: String?

    private static let defaultSampleSwiftUICode = """
    import SwiftUI

    class LegacyDashboardModel: ObservableObject {
        @Published var activeUsers: Int = 1280
        @Published var syncHealthy: Bool = true
    }

    struct RawTelemetryDashboardView: View {
        @ObservedObject var model = LegacyDashboardModel()
        @State var expandedCard = false

        var body: some View {
            ScrollView {
                VStack(spacing: 14) {
                    Text("Fleet Operations Pulse")
                        .font(.system(size: 22, weight: .bold))

                    HStack(spacing: 12) {
                        Button("Refresh Metrics") {
                            model.activeUsers += 12
                        }
                        .padding(10)

                        Toggle("Realtime Sync", isOn: $model.syncHealthy)
                    }
                    .padding(16)
                    .background(.regularMaterial)
                    .cornerRadius(14)
                }
                .padding(20)
            }
        }
    }
    """

    private var activeSource: String {
        useWorkspaceSelectionCode ? viewModel.selectedSwiftUICode : customSourceBuffer
    }

    private var compilationSnapshot: ChiefKitASTCompilationSnapshot {
        ChiefKitASTModule.analyzePipeline(
            source: activeSource,
            filePath: "\(viewModel.selectionDisplayTitle.replacingOccurrences(of: " ", with: "")).swift",
            theme: theme
        )
    }

    var body: some View {
        let snapshot = compilationSnapshot

        VStack(alignment: .leading, spacing: 16) {
            sourceModeAndTokenHeader(snapshot: snapshot)
            refactoringPassToolbar(snapshot: snapshot)
            inspectorContentCard(snapshot: snapshot)
            testSynthesisCard(snapshot: snapshot)
        }
    }

    // MARK: - 1. Source Buffer & Token Telemetry Card

    private func sourceModeAndTokenHeader(snapshot: ChiefKitASTCompilationSnapshot) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    SectionTitle(
                        "Swift 6 Lexer, SwiftUI Parser & Structural Verifier",
                        subtitle: "Tokenize, parse, verify balanced delimiters/#if directives, and inspect live SwiftUI AST nodes."
                    )
                    Spacer()
                    PillLabel(
                        title: snapshot.verificationReport.isValid
                            ? "Verified · \(snapshot.tokenSummary.totalTokens) Tokens"
                            : "Syntax Fault Detected",
                        systemImage: snapshot.verificationReport.isValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                    )
                }

                HStack(spacing: 10) {
                    Picker("Source Origin", selection: $useWorkspaceSelectionCode) {
                        Text("Live Workspace Selection").tag(true)
                        Text("Custom Lab Buffer").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 360)

                    if !useWorkspaceSelectionCode {
                        Button("Load Selection into Buffer") {
                            customSourceBuffer = viewModel.selectedSwiftUICode
                            viewModel.statusMessage = "Copied active SwiftUI code into AST Lab buffer"
                        }
                        .controlSize(.small)

                        Button("Reset Sample") {
                            customSourceBuffer = Self.defaultSampleSwiftUICode
                            lastEditLog.removeAll()
                        }
                        .controlSize(.small)
                    }

                    Spacer()

                    Button {
                        importCurrentASTToCanvas()
                    } label: {
                        Label("Import AST → SwiftBlocks Canvas", systemImage: "square.and.arrow.down.on.square")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                if !useWorkspaceSelectionCode {
                    TextEditor(text: $customSourceBuffer)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 150)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.separator.opacity(0.45), lineWidth: 1)
                        }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], spacing: 8) {
                    astMetricBadge("Tokens", value: "\(snapshot.tokenSummary.totalTokens)", detail: "\(snapshot.tokenSummary.totalLines) lines")
                    astMetricBadge("Keywords / IDs", value: "\(snapshot.tokenSummary.keywordCount) / \(snapshot.tokenSummary.identifierCount)", detail: "\(snapshot.tokenSummary.attributeCount) @attrs")
                    astMetricBadge("View Nodes", value: "\(snapshot.sourceFile.allViewNodes().count)", detail: "Depth \(snapshot.metricsReport.viewTreeDepth)")
                    astMetricBadge("Audit Score", value: "\(snapshot.auditReport.overallScore)/100", detail: "\(snapshot.auditReport.passedRuleCount)/\(snapshot.auditReport.totalRuleCount) rules")
                    astMetricBadge("Maintainability", value: snapshot.metricsReport.maintainabilityGrade, detail: String(format: "MI %.1f", snapshot.metricsReport.maintainabilityIndex))
                    astMetricBadge("Brace / #if Pairs", value: "\(snapshot.verificationReport.matchedBracePairs) / \(snapshot.verificationReport.conditionalCompilationBlockCount)", detail: "\(snapshot.verificationReport.verifiedSwiftUIViews.count) Views OK")
                }

                if let importNote = lastCanvasImportNote {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundStyle(theme.success.swiftUIColor)
                        Text(importNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open SwiftBlocks Canvas") {
                            viewModel.select(.package(.swiftBlocks))
                        }
                        .font(.caption.weight(.semibold))
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(theme.success.swiftUIColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 2. 1-Click AST Refactoring Passes

    private func refactoringPassToolbar(snapshot: ChiefKitASTCompilationSnapshot) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Deterministic AST Refactoring Engine",
                        subtitle: "Apply semantic syntax-tree passes directly to your workspace selection or lab buffer."
                    )
                    Spacer()
                    Button {
                        runFullCleanUpPipeline()
                    } label: {
                        Label("Run Full Clean-Up Pipeline", systemImage: "wand.and.stars")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                let quickPasses: [ASTTransformPass] = [
                    .migrateToObservableMacro,
                    .tokenizeMagicLiterals,
                    .injectVoiceOverAndDynamicType,
                    .liftStateToSwiftStateReducer,
                    .instrumentTimelineTelemetry
                ]

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 8)], spacing: 8) {
                    ForEach(Array(quickPasses.enumerated()), id: \.offset) { _, pass in
                        Button {
                            applyRefactorPass(pass)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .foregroundStyle(theme.primary.swiftUIColor)
                                Text(pass.displayName)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(theme.primary.swiftUIColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        formatActiveSource()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "text.alignleft")
                                .foregroundStyle(theme.secondary.swiftUIColor)
                            Text("Format (SwiftFormatterEngine)")
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Text("Extract Subview:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Container (e.g. HStack)", text: $extractTargetComponent)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 135)
                        .controlSize(.small)
                    TextField("New Struct Name", text: $extractStructName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 175)
                        .controlSize(.small)
                    Button("Extract Struct") {
                        applyRefactorPass(
                            .extractSubview(
                                targetNodeName: extractTargetComponent,
                                newStructName: extractStructName
                            )
                        )
                    }
                    .controlSize(.small)
                    Spacer()
                }

                if !lastEditLog.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent AST Transformations (\(lastEditLog.count)):")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(lastEditLog.prefix(4)) { edit in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(theme.success.swiftUIColor)
                                Text("[\(edit.passName)] \(edit.symbolName): \(edit.summary)")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. Multi-Tab Deep AST Inspector

    private func inspectorContentCard(snapshot: ChiefKitASTCompilationSnapshot) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Inspector Mode", selection: $selectedSubtab) {
                    ForEach(ASTInspectorSubtab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedSubtab {
                case .audit:
                    auditDiagnosticsSection(audit: snapshot.auditReport)
                case .hierarchy:
                    astHierarchyAndSymbolsSection(snapshot: snapshot)
                case .complexity:
                    complexityMetricsSection(metrics: snapshot.metricsReport)
                case .mermaid:
                    mermaidAndFormattedSection(snapshot: snapshot)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func auditDiagnosticsSection(audit: ASTAuditReport) -> some View {
        let filteredDiagnostics = audit.diagnostics.filter { diag in
            selectedCategoryFilter == nil || diag.category == selectedCategoryFilter
        }

        return VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryChip(title: "All Categories (\(audit.diagnostics.count))", isSelected: selectedCategoryFilter == nil) {
                        selectedCategoryFilter = nil
                    }
                    ForEach(ASTAuditCategory.allCases, id: \.self) { category in
                        let catScore = audit.score(for: category)
                        categoryChip(
                            title: "\(category.rawValue) · \(catScore)",
                            isSelected: selectedCategoryFilter == category
                        ) {
                            selectedCategoryFilter = category
                        }
                    }
                }
            }

            if filteredDiagnostics.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(theme.success.swiftUIColor)
                    Text("Zero diagnostics triggered across all selected ChiefKitAST static audit rules.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredDiagnostics.prefix(12)) { diag in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(diag.ruleID.rawValue)
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(severityColor(diag.severity).opacity(0.16), in: Capsule())
                                    .foregroundStyle(severityColor(diag.severity))

                                Text(diag.title)
                                    .font(.callout.weight(.semibold))

                                Spacer()

                                Text("Line \(diag.span.start.line)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Text(diag.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Fix: \(diag.remediation)")
                                .font(.caption2)
                                .foregroundStyle(theme.primary.swiftUIColor)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func astHierarchyAndSymbolsSection(snapshot: ChiefKitASTCompilationSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Declared Nominal Types & Symbol Graph (\(snapshot.symbolGraph.nodes.count) nodes, \(snapshot.symbolGraph.edges.count) edges)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(snapshot.symbolGraph.nodes) { node in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: node.kind == .swiftUIView ? "macwindow" : "cube.box")
                        .foregroundStyle(theme.primary.swiftUIColor)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(node.name)
                                .font(.callout.weight(.semibold))
                            Text(node.kind.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.14), in: Capsule())
                            if node.isSendable {
                                Text("Sendable")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(theme.success.swiftUIColor)
                            }
                            if node.isMainActor {
                                Text("@MainActor")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(theme.primary.swiftUIColor)
                            }
                        }
                        if !node.conformances.isEmpty {
                            Text("Conforms to: \(node.conformances.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !node.propertySignatures.isEmpty {
                            Text("Properties: \(node.propertySignatures.prefix(4).joined(separator: " · "))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(9)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func complexityMetricsSection(metrics: ASTMetricsReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                astMetricBadge("McCabe Total", value: "\(metrics.cyclomaticComplexityTotal)", detail: String(format: "Avg %.2f", metrics.cyclomaticComplexityAverage))
                astMetricBadge("Cognitive Total", value: "\(metrics.cognitiveComplexityTotal)", detail: "\(metrics.logicalCodeLines) logical LOC")
                astMetricBadge("Halstead Volume", value: String(format: "%.0f", metrics.halstead.volume), detail: "Vocab \(metrics.halstead.vocabulary)")
                astMetricBadge("Halstead Effort", value: String(format: "%.0f", metrics.halstead.effort), detail: String(format: "Diff %.1f", metrics.halstead.difficulty))
                astMetricBadge("Est. Defects", value: String(format: "%.3f", metrics.halstead.estimatedBugs), detail: "Halstead B")
                astMetricBadge("Modifier / View", value: String(format: "%.2f", metrics.modifierPerViewRatio), detail: String(format: "Coupling %.1f", metrics.stateCouplingScore))
            }

            if !metrics.viewProfiles.isEmpty {
                Text("SwiftUI View Complexity Profiles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(metrics.viewProfiles) { vp in
                    HStack {
                        Text(vp.viewName)
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Text("\(vp.totalViewNodes) nodes · depth \(vp.maxViewTreeDepth) · \(vp.totalModifiers) modifiers · @State \(vp.statePropertyCount)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7))
                }
            }
        }
    }

    private func mermaidAndFormattedSection(snapshot: ChiefKitASTCompilationSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Symbol Graph Mermaid Class Diagram")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            CodeBlockView(text: snapshot.symbolGraph.exportMermaidClassDiagram(), showLineNumbers: false)
                .frame(minHeight: 150, maxHeight: 220)
        }
    }

    // MARK: - 4. Automated @Test / XCTest Synthesis Card

    private func testSynthesisCard(snapshot: ChiefKitASTCompilationSnapshot) -> some View {
        let testResult = ASTTestSynthesizer.synthesize(
            ast: snapshot.sourceFile,
            moduleUnderTest: "ChiefKitApp",
            framework: selectedTestFramework
        )

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(
                        "AST-Driven Unit Test Synthesizer",
                        subtitle: "\(testResult.totalTestCount) tests (\(testResult.totalAssertionCount) assertions) covering \(max(1, testResult.coveredSymbols.count)) symbol(s)."
                    )
                    Spacer()
                    Picker("Framework", selection: $selectedTestFramework) {
                        ForEach(ASTTestFrameworkTarget.allCases, id: \.self) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                    .frame(width: 240)
                    .controlSize(.small)

                    Button {
                        viewModel.generatedUnitTestsBySelection[viewModel.selection] = testResult.generatedCode
                        viewModel.rightInspectorTab = .code
                        viewModel.codePreviewMode = .tests
                        viewModel.statusMessage = "Loaded \(testResult.totalTestCount) AST-synthesized tests into Live Code → Tests"
                    } label: {
                        Label("Push to Inspector Tests", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                CodeBlockView(text: testResult.generatedCode)
                    .frame(minHeight: 180, maxHeight: 260)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions & UI Helpers

    private func applyRefactorPass(_ pass: ASTTransformPass) {
        let result = ASTTransformationEngine.apply(pass: pass, to: activeSource, theme: theme)
        commitRefactoredCode(result.formattedSource, edits: result.edits, label: pass.displayName)
    }

    private func runFullCleanUpPipeline() {
        let result = ASTTransformationEngine.applyPipeline(
            passes: [
                .migrateToObservableMacro,
                .tokenizeMagicLiterals,
                .injectVoiceOverAndDynamicType
            ],
            to: activeSource,
            theme: theme
        )
        commitRefactoredCode(result.formattedSource, edits: result.edits, label: "Clean-Up Pipeline")
    }

    private func formatActiveSource() {
        let formatted = SwiftFormatterEngine.format(source: activeSource, config: .chiefKitStandard)
        let syntheticEdit = ASTTransformEdit(
            passName: "SwiftFormatterEngine",
            symbolName: "File",
            summary: "Formatted \(formatted.changedLineCount) line(s), wrapped \(formatted.wrappedModifierChains) modifier chain(s)"
        )
        commitRefactoredCode(formatted.formattedSource, edits: [syntheticEdit], label: "SwiftFormatterEngine")
    }

    private func commitRefactoredCode(_ updatedCode: String, edits: [ASTTransformEdit], label: String) {
        if useWorkspaceSelectionCode {
            viewModel.aiOverriddenCode[viewModel.selection] = updatedCode
            viewModel.rightInspectorTab = .code
            viewModel.codePreviewMode = .diff
        } else {
            customSourceBuffer = updatedCode
        }
        lastEditLog = edits + lastEditLog
        viewModel.statusMessage = "Applied AST pass '\(label)' (\(edits.count) edit(s))"
    }

    private func importCurrentASTToCanvas() {
        let imported = ASTCanvasBridge.importToCanvas(source: activeSource, canvasWidth: 640)
        guard imported.importedNodeCount > 0 else {
            lastCanvasImportNote = "No mappable SwiftBlocks views found in current source."
            return
        }
        viewModel.recordCanvasUndoCheckpoint()
        viewModel.canvasDocument = imported.document
        viewModel.canvasLayoutMode = imported.detectedLayoutMode
        viewModel.selectedCanvasNodeID = imported.document.nodes.first?.id
        lastCanvasImportNote = "Imported \(imported.importedNodeCount) blocks from '\(imported.structName)' (\(imported.detectedLayoutMode.rawValue))."
        viewModel.statusMessage = "Imported \(imported.importedNodeCount) AST view nodes onto SwiftBlocks Canvas"
    }

    private func severityColor(_ severity: ASTDiagnosticSeverity) -> Color {
        switch severity {
        case .error: theme.danger.swiftUIColor
        case .warning: theme.warning.swiftUIColor
        case .info: theme.primary.swiftUIColor
        }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    isSelected ? theme.primary.swiftUIColor : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func astMetricBadge(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(detail)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
#endif
