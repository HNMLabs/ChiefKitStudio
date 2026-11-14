#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitStudioCore
import SwiftUI

struct PerformanceProfilerStudioView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    @State private var selectedTarget: DisplayRefreshTarget = .proMotion120Hz
    @State private var showMermaidInvalidationGraph = false
    @State private var expandedFindingID: String?

    var body: some View {
        let code = viewModel.selectedSwiftUICode
        let report = FrameBudgetProfiler.profile(
            swiftUISource: code,
            canvas: viewModel.canvasDocument,
            theme: theme,
            target: selectedTarget
        )
        let targetComparison = FrameBudgetProfiler.compareAcrossTargets(
            swiftUISource: code,
            canvas: viewModel.canvasDocument,
            theme: theme
        )
        let invalidationReport = StateInvalidationAnalyzer.analyze(swiftSource: code)

        VStack(alignment: .leading, spacing: 16) {
            refreshTargetAndPhaseBreakdownCard(report: report, comparison: targetComparison)
            flamegraphTreeCard(report: report)
            gpuHazardsAndAutoPatcherCard(report: report)
            stateInvalidationAnalyzerCard(invalidation: invalidationReport)
        }
    }

    // MARK: - 1. Display Refresh Target & CPU/GPU Render Pipeline Breakdown

    private func refreshTargetAndPhaseBreakdownCard(
        report: FrameBudgetProfileReport,
        comparison: [FrameBudgetProfileReport]
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "120Hz ProMotion Frame-Budget & Render Pipeline Profiler",
                        subtitle: "Simulate SwiftUI view diffing, CPU layout, CoreAnimation commit, and Metal GPU offscreen compositing."
                    )
                    Spacer()
                    PillLabel(
                        title: "Grade \(report.performanceGrade) · \(String(format: "%.2f / %.2f ms", report.totalFrameTimeMs, report.budgetMs))",
                        systemImage: report.meetsFrameBudget ? "gauge.with.needle.fill" : "exclamationmark.triangle.fill"
                    )
                }

                Picker("Display Target", selection: $selectedTarget) {
                    ForEach(DisplayRefreshTarget.allCases) { target in
                        Text("\(target.rawValue) (\(String(format: "%.2f", target.frameBudgetMs))ms)").tag(target)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    ForEach(comparison, id: \.target) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.meetsFrameBudget ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(item.meetsFrameBudget ? theme.success.swiftUIColor : theme.danger.swiftUIColor)
                            Text("\(item.target.refreshRateHz)Hz: \(String(format: "%.2fms", item.totalFrameTimeMs)) (\(Int(item.estimatedSustainedFPS)) FPS)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: Capsule())
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 7) {
                    phaseProgressBar(
                        label: "SwiftUI View Diffing",
                        durationMs: report.cpuViewDiffingMs,
                        budgetMs: report.budgetMs,
                        tint: theme.primary.swiftUIColor
                    )
                    phaseProgressBar(
                        label: "CPU Layout Measurement",
                        durationMs: report.cpuLayoutPassMs,
                        budgetMs: report.budgetMs,
                        tint: theme.secondary.swiftUIColor
                    )
                    phaseProgressBar(
                        label: "CoreAnimation Commit",
                        durationMs: report.coreAnimationCommitMs,
                        budgetMs: report.budgetMs,
                        tint: theme.warning.swiftUIColor
                    )
                    phaseProgressBar(
                        label: "Metal GPU Offscreen",
                        durationMs: report.metalGPUCompositeMs,
                        budgetMs: report.budgetMs,
                        tint: theme.danger.swiftUIColor
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 8)], spacing: 8) {
                    profilerMetricTile("Headroom", String(format: "%+.2f ms", report.headroomMs))
                    profilerMetricTile("Sustained FPS", String(format: "%.0f FPS", report.estimatedSustainedFPS))
                    profilerMetricTile("Offscreen Passes", "\(report.metalOffscreenPassCount)")
                    profilerMetricTile("Hitch Risk", String(format: "%.1f%%", report.hitchRatioPercent))
                    profilerMetricTile("Peak Frame RAM", "\(report.estimatedPeakRAMKB) KB")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 2. Hierarchical Render Flamegraph Inspector

    private func flamegraphTreeCard(report: FrameBudgetProfileReport) -> some View {
        let rows = report.flamegraphRoot.flattenedRows()

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(
                        "Hierarchical Frame Flamegraph (\(rows.count) Spans)",
                        subtitle: "Inspect self vs inclusive render cost, offscreen texture passes, and transient backing-store KB."
                    )
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, entry in
                        let pct = min(100.0, max(2.0, entry.node.percentage(ofBudget: report.budgetMs)))
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                if entry.depth > 0 {
                                    Text(String(repeating: "│ ", count: entry.depth))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                                Text(entry.node.label)
                                    .font(.system(size: 11.5, weight: entry.depth == 0 ? .bold : .medium, design: .monospaced))
                                    .lineLimit(1)
                            }
                            .frame(minWidth: 210, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.12))
                                    Capsule()
                                        .fill(pct > 75 ? theme.danger.swiftUIColor : theme.primary.swiftUIColor)
                                        .frame(width: geo.size.width * CGFloat(pct / 100.0))
                                }
                            }
                            .frame(height: 8)

                            Text(String(format: "%.2fms (%.0f%%)", entry.node.totalTimeMs, pct))
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .frame(width: 98, alignment: .trailing)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. GPU Offscreen Hazard Detector & 1-Click Auto-Patcher

    private func gpuHazardsAndAutoPatcherCard(report: FrameBudgetProfileReport) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(
                        "GPU Offscreen Hazard Detector (\(report.hazards.count) Found)",
                        subtitle: "Automatically rewrite unbatched shadows, eager scroll stacks, and offscreen masks."
                    )
                    Spacer()
                    if !report.hazards.isEmpty {
                        Button {
                            let optimized = FrameBudgetProfiler.applyOptimizationPatches(
                                to: viewModel.selectedSwiftUICode,
                                hazards: report.hazards
                            )
                            viewModel.aiOverriddenCode[viewModel.selection] = optimized
                            viewModel.rightInspectorTab = .code
                            viewModel.codePreviewMode = .diff
                            viewModel.statusMessage = "Applied \(report.hazards.count) ProMotion GPU optimization patch(es)"
                        } label: {
                            Label("Apply Optimization Patches", systemImage: "bolt.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.primary.swiftUIColor)
                        .controlSize(.small)
                    }
                }

                if report.hazards.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(theme.success.swiftUIColor)
                        Text("Zero offscreen GPU compositing or layout feedback hazards detected in current SwiftUI view.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(report.hazards) { hazard in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(hazard.patch.title)
                                    .font(.callout.weight(.semibold))
                                Spacer()
                                Text(String(format: "-%.2f ms · %d pass(es) · %d KB", hazard.patch.expectedSavingsMs, hazard.estimatedOffscreenPasses, hazard.estimatedExtraRAMKB))
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(theme.success.swiftUIColor)
                            }
                            Text(hazard.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("After: \(hazard.patch.afterSnippet)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(theme.primary.swiftUIColor)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 4. `@Observable` State Invalidation & Blast-Radius Analyzer

    private func stateInvalidationAnalyzerCard(invalidation: StateInvalidationReport) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "`@Observable` State Invalidation & Blast-Radius Inspector",
                        subtitle: String(
                            format: "%d view(s) · Avg blast radius %.1f%% · Worst-case %.1f%%",
                            invalidation.views.count,
                            invalidation.averageBlastRadiusPercent,
                            invalidation.worstBlastRadiusPercent
                        )
                    )
                    Spacer()
                    Toggle("Mermaid Dependency Graph", isOn: $showMermaidInvalidationGraph)
                        .font(.caption)
                }

                if !invalidation.blastRadiusMetrics.isEmpty {
                    ForEach(invalidation.blastRadiusMetrics.prefix(6)) { metric in
                        HStack(spacing: 10) {
                            Text("\(metric.kind.rawValue) \(metric.triggerSymbol)")
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .frame(width: 210, alignment: .leading)
                            Text("→ \(metric.invalidatedViews.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.0f%% blast", metric.blastRadiusPercent))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(metric.isCoarseBroadcast ? theme.warning.swiftUIColor : theme.success.swiftUIColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                }

                ForEach(invalidation.findings.prefix(4)) { finding in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(finding.viewName) · \(finding.kind.rawValue)")
                                .font(.caption.weight(.bold))
                            Spacer()
                            Text("-\(String(format: "%.0f", finding.suggestion.expectedBlastRadiusReductionPercent))% invalidations via \(finding.suggestion.suggestedSubviewName)")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(theme.primary.swiftUIColor)

                            Button(expandedFindingID == finding.id ? "Hide Fix" : "Preview Fix") {
                                expandedFindingID = (expandedFindingID == finding.id) ? nil : finding.id
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }

                        Text(finding.explanation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if !finding.suggestion.isolatedProperties.isEmpty {
                            Text("Isolated properties: \(finding.suggestion.isolatedProperties.joined(separator: ", "))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        if expandedFindingID == finding.id {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Suggested @Observable / Equatable Subview Decomposition")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Copy Refactored Subview") {
                                        ExportService.copyToClipboard(finding.suggestion.refactoredSwiftSnippet)
                                        viewModel.statusMessage = "Copied \(finding.suggestion.suggestedSubviewName) decomposition snippet"
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(theme.primary.swiftUIColor)
                                    .controlSize(.mini)
                                }
                                CodeBlockView(text: finding.suggestion.refactoredSwiftSnippet, showLineNumbers: false)
                                    .frame(minHeight: 95, maxHeight: 155)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.warning.swiftUIColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                if showMermaidInvalidationGraph {
                    CodeBlockView(text: invalidation.mermaidFlowchartLR, showLineNumbers: false)
                        .frame(minHeight: 145, maxHeight: 210)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func phaseProgressBar(label: String, durationMs: Double, budgetMs: Double, tint: Color) -> some View {
        let ratio = min(1.0, max(0.02, durationMs / max(0.1, budgetMs)))
        return HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(width: 165, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule().fill(tint).frame(width: geo.size.width * CGFloat(ratio))
                }
            }
            .frame(height: 9)
            Text(String(format: "%.2f ms", durationMs))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(width: 64, alignment: .trailing)
        }
    }

    private func profilerMetricTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13.5, weight: .bold, design: .monospaced))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
#endif
