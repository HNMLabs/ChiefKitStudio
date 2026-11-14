#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Charts, KPI & Data Grid Component Specs + Synthesizers (16 Components)

internal enum ComponentSynthesizerDataAndCharts {

    static let specs: [SwiftBlockSpec] = [
        // MARK: 8 Charts & Metrics Specs
        SwiftBlockSpec(
            id: .sparklineMetricCard,
            title: "Sparkline Metric Card",
            summary: "Compact KPI headline card paired with a normalized vector polyline sparkline and delta badge.",
            sfSymbol: "chart.line.uptrend.xyaxis",
            vectorIcon: .chartSparkline,
            props: [
                SwiftBlockPropSpec(name: "headlineValue", kind: .string, defaultValue: "\"$128.4k\"", summary: "Primary KPI figure", isRequired: true),
                SwiftBlockPropSpec(name: "samples", kind: .dataArray, defaultValue: "[0.32, 0.45, 0.41, 0.68, 0.74, 0.92]", summary: "Normalized sparkline series")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 280, height: 132),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "summary", minimumAPCALc: 75),
            searchKeywords: ["sparkline", "kpi", "metric", "trend"]
        ),
        SwiftBlockSpec(
            id: .smoothAreaTrendChart,
            title: "Smooth Area Trend Chart",
            summary: "Catmull-Rom / cubic Bezier area trend visualization with gradient fill and hover crosshair.",
            sfSymbol: "chart.xyaxis.line",
            vectorIcon: .chartSparkline,
            props: [
                SwiftBlockPropSpec(name: "seriesTitle", kind: .string, defaultValue: "\"Active Sessions\"", summary: "Chart header", isRequired: true),
                SwiftBlockPropSpec(name: "points", kind: .dataArray, defaultValue: "[18, 29, 25, 42, 51, 64]", summary: "Data points")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 188),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "image", minimumAPCALc: 65),
            searchKeywords: ["area", "chart", "curve", "timeseries"]
        ),
        SwiftBlockSpec(
            id: .stackedBarComparison,
            title: "Stacked Bar Comparison",
            summary: "Multi-cohort vertical or horizontal stacked bar breakdown with dichromat-safe legend.",
            sfSymbol: "chart.bar.xaxis",
            vectorIcon: .chartCandlestick,
            props: [
                SwiftBlockPropSpec(name: "cohorts", kind: .dataArray, defaultValue: "[\"Q1\", \"Q2\", \"Q3\", \"Q4\"]", summary: "Bucket labels", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 184),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "chart", minimumAPCALc: 65),
            searchKeywords: ["bar", "stacked", "cohort", "comparison"]
        ),
        SwiftBlockSpec(
            id: .donutRingGauge,
            title: "Donut Ring Gauge",
            summary: "Concentric angular ring chart displaying proportional share and center summary metric.",
            sfSymbol: "chart.pie.fill",
            vectorIcon: .chartDonutGauge,
            props: [
                SwiftBlockPropSpec(name: "completion", kind: .double, defaultValue: "0.78", summary: "Normalized ring fraction [0, 1]", isRequired: true),
                SwiftBlockPropSpec(name: "centerLabel", kind: .string, defaultValue: "\"78%\"", summary: "Inner readout")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 240, height: 196),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "progressIndicator", minimumAPCALc: 70),
            searchKeywords: ["donut", "ring", "pie", "gauge"]
        ),
        SwiftBlockSpec(
            id: .contributionHeatmap,
            title: "Contribution Heatmap",
            summary: "7x12 perceptual tonal matrix visualizing daily commit, build, or workout intensity.",
            sfSymbol: "square.grid.4x3.fill",
            vectorIcon: .layoutGrid12,
            props: [
                SwiftBlockPropSpec(name: "weeks", kind: .int, defaultValue: "12", summary: "Column count", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 148),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "grid", minimumAPCALc: 60),
            searchKeywords: ["heatmap", "calendar", "matrix", "contributions"]
        ),
        SwiftBlockSpec(
            id: .conversionFunnelCard,
            title: "Conversion Funnel Card",
            summary: "Stage-by-stage funnel drop-off bars showing conversion percentage between sequential steps.",
            sfSymbol: "line.3.horizontal.decrease",
            vectorIcon: .filterSliders,
            props: [
                SwiftBlockPropSpec(name: "stages", kind: .dataArray, defaultValue: "[(\"Visited\", 1.0), (\"Trial\", 0.46), (\"Paid\", 0.19)]", summary: "Funnel tuples", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 172),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "list", minimumAPCALc: 70),
            searchKeywords: ["funnel", "conversion", "retention", "analytics"]
        ),
        SwiftBlockSpec(
            id: .latencyPercentileChart,
            title: "Latency Percentile Chart",
            summary: "Observability P50 / P95 / P99 response-time band chart with SLO threshold indicator.",
            sfSymbol: "waveform.path.ecg",
            vectorIcon: .springOscillator,
            props: [
                SwiftBlockPropSpec(name: "p50Ms", kind: .double, defaultValue: "14.2", summary: "Median latency ms"),
                SwiftBlockPropSpec(name: "p99Ms", kind: .double, defaultValue: "86.5", summary: "Tail P99 latency ms", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 164),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "chart", minimumAPCALc: 70),
            searchKeywords: ["latency", "p99", "p95", "slo", "telemetry"]
        ),
        SwiftBlockSpec(
            id: .flamegraphSpanView,
            title: "Flamegraph Span View",
            summary: "Hierarchical profiling call-stack trace bars with millisecond duration labels.",
            sfSymbol: "flame.fill",
            vectorIcon: .boltThroughput,
            props: [
                SwiftBlockPropSpec(name: "totalFrameMs", kind: .double, defaultValue: "8.3", summary: "Total trace budget ms", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 440, height: 168),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "outline", minimumAPCALc: 70),
            searchKeywords: ["flamegraph", "profiler", "trace", "spans"]
        ),

        // MARK: 8 Data Grids & Workflows Specs
        SwiftBlockSpec(
            id: .sortableDataGrid,
            title: "Sortable Data Grid",
            summary: "Multi-column tabular data grid with interactive sort chevrons, zebra tint, and row selection.",
            sfSymbol: "tablecells",
            vectorIcon: .layoutGrid12,
            props: [
                SwiftBlockPropSpec(name: "sortColumn", kind: .binding, defaultValue: "\"latency\"", summary: "Sorted column key", isRequired: true),
                SwiftBlockPropSpec(name: "ascending", kind: .bool, defaultValue: "true", summary: "Sort direction")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 480, height: 210),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "table", minimumAPCALc: 75),
            searchKeywords: ["table", "grid", "rows", "sort"]
        ),
        SwiftBlockSpec(
            id: .kanbanBoardColumn,
            title: "Kanban Board Column",
            summary: "Swimlane task column with WIP limit pill, draggable issue cards, and quick-add footer.",
            sfSymbol: "rectangle.split.3x1.fill",
            vectorIcon: .kanbanColumns,
            props: [
                SwiftBlockPropSpec(name: "columnTitle", kind: .string, defaultValue: "\"In Review\"", summary: "Lane title", isRequired: true),
                SwiftBlockPropSpec(name: "wipLimit", kind: .int, defaultValue: "4", summary: "Max work-in-progress")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 290, height: 240),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "list", minimumAPCALc: 75),
            searchKeywords: ["kanban", "board", "tasks", "agile"]
        ),
        SwiftBlockSpec(
            id: .activityTimelineFeed,
            title: "Activity Timeline Feed",
            summary: "Vertical chronological event stream with vertical rail connector, actor badges, and relative timestamps.",
            sfSymbol: "clock.arrow.circlepath",
            vectorIcon: .timelineClock,
            props: [
                SwiftBlockPropSpec(name: "events", kind: .dataArray, defaultValue: "[\"Tokens compiled\", \"APCA passed\"]", summary: "Feed entries", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 200),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "list", minimumAPCALc: 70),
            searchKeywords: ["timeline", "activity", "feed", "history"]
        ),
        SwiftBlockSpec(
            id: .unifiedDiffBlock,
            title: "Unified Diff Block",
            summary: "Monospaced side-by-side / unified code diff viewer with green/red line gutter highlights.",
            sfSymbol: "plusminus",
            vectorIcon: .unifiedDiff,
            props: [
                SwiftBlockPropSpec(name: "filename", kind: .string, defaultValue: "\"ChiefKitTheme.swift\"", summary: "Header file path", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 460, height: 188),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "code", minimumAPCALc: 75),
            searchKeywords: ["diff", "git", "patch", "code"]
        ),
        SwiftBlockSpec(
            id: .jsonTreeExplorer,
            title: "JSON Tree Explorer",
            summary: "Collapsible hierarchical key-value inspector for W3C Design Token payloads and state snapshots.",
            sfSymbol: "curlybraces",
            vectorIcon: .tokenCompiler,
            props: [
                SwiftBlockPropSpec(name: "rootKey", kind: .string, defaultValue: "\"chiefkit.tokens\"", summary: "Root node name", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 190),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "outline", minimumAPCALc: 75),
            searchKeywords: ["json", "tree", "inspector", "payload"]
        ),
        SwiftBlockSpec(
            id: .heroKPIDeltaBanner,
            title: "Hero KPI Delta Banner",
            summary: "Wide executive summary strip pairing 3 headline metrics with positive/negative semantic pills.",
            sfSymbol: "sparkles.rectangle.stack.fill",
            vectorIcon: .boltThroughput,
            props: [
                SwiftBlockPropSpec(name: "primaryMetric", kind: .string, defaultValue: "\"99.98%\"", summary: "Hero number", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 520, height: 112),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "summary", minimumAPCALc: 75),
            searchKeywords: ["kpi", "banner", "executive", "delta"]
        ),
        SwiftBlockSpec(
            id: .quotaUsageRing,
            title: "Quota Usage Ring",
            summary: "Resource consumption meter with warning threshold tinting and upgrade callout.",
            sfSymbol: "gauge.with.dots.needle.67percent",
            vectorIcon: .chartDonutGauge,
            props: [
                SwiftBlockPropSpec(name: "usedUnits", kind: .double, defaultValue: "82.0", summary: "Consumed quota", isRequired: true),
                SwiftBlockPropSpec(name: "limitUnits", kind: .double, defaultValue: "100.0", summary: "Quota ceiling", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 300, height: 124),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "levelIndicator", minimumAPCALc: 70),
            searchKeywords: ["quota", "storage", "meter", "usage"]
        ),
        SwiftBlockSpec(
            id: .realtimeTickerBar,
            title: "Realtime Ticker Bar",
            summary: "Live streaming telemetry ribbon showing symbol/metric pulses with directional color flashes.",
            sfSymbol: "dot.radiowaves.left.and.right",
            vectorIcon: .webhookSignal,
            props: [
                SwiftBlockPropSpec(name: "isLive", kind: .bool, defaultValue: "true", summary: "Live stream status", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 480, height: 56),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "status", minimumAPCALc: 70),
            searchKeywords: ["ticker", "live", "stream", "telemetry"]
        )
    ]

    // MARK: - Component Code Synthesis

    static func synthesize(context ctx: SwiftBlockSynthesisContext) -> String {
        let accent = ctx.accentSwiftUI
        let okColor = ctx.theme.success.swiftInitializer
        let warnColor = ctx.theme.warning.swiftInitializer
        let errColor = ctx.theme.danger.swiftInitializer

        switch ctx.id {
        case .sparklineMetricCard:
            return ctx.wrapComponentView(
                stateProperties: "    public var values: [Double] = [0.25, 0.42, 0.38, 0.64, 0.72, 0.94]",
                bodyCore: """
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NET REVENUE").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                                Text("$128.4k").font(.system(size: 26, weight: .bold, design: .rounded))
                            }
                            Spacer()
                            Text("+18.4%")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(\(okColor).opacity(0.16), in: Capsule())
                                .foregroundStyle(\(okColor))
                        }
                        GeometryReader { geo in
                            Path { path in
                                for (idx, val) in values.enumerated() {
                                    let x = geo.size.width * CGFloat(idx) / CGFloat(max(1, values.count - 1))
                                    let y = geo.size.height * CGFloat(1.0 - val)
                                    if idx == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(\(accent), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        }
                        .frame(height: 36)
                """
            )

        case .smoothAreaTrendChart:
            return ctx.wrapComponentView(
                stateProperties: "    public var samples: [Double] = [0.20, 0.48, 0.40, 0.76, 0.68, 0.92]",
                bodyCore: """
                        HStack {
                            Text("Active Studio Sessions").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("Peak: 4,820").font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack {
                                Path { p in
                                    p.move(to: CGPoint(x: 0, y: geo.size.height))
                                    for (i, s) in samples.enumerated() {
                                        let x = geo.size.width * CGFloat(i) / CGFloat(max(1, samples.count - 1))
                                        p.addLine(to: CGPoint(x: x, y: geo.size.height * CGFloat(1.0 - s)))
                                    }
                                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                                    p.closeSubpath()
                                }
                                .fill(LinearGradient(colors: [\(accent).opacity(0.34), .clear], startPoint: .top, endPoint: .bottom))
                            }
                        }
                        .frame(height: 88)
                """
            )

        case .stackedBarComparison:
            return ctx.wrapComponentView(
                stateProperties: "    private let quarters: [(String, Double, Double)] = [(\"Q1\", 0.45, 0.22), (\"Q2\", 0.56, 0.24), (\"Q3\", 0.64, 0.20), (\"Q4\", 0.72, 0.22)]",
                bodyCore: """
                        Text("Platform Target Mix").font(.subheadline.weight(.semibold))
                        HStack(alignment: .bottom, spacing: 18) {
                            ForEach(quarters, id: \\.0) { label, primaryShare, secondaryShare in
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4).fill(\(okColor)).frame(width: 28, height: secondaryShare * 84)
                                    RoundedRectangle(cornerRadius: 4).fill(\(accent)).frame(width: 28, height: primaryShare * 84)
                                    Text(label).font(.caption2.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                """
            )

        case .donutRingGauge:
            return ctx.wrapComponentView(
                stateProperties: "    public var progress: Double = 0.78",
                bodyCore: """
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().stroke(Color.secondary.opacity(0.18), lineWidth: 10)
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(\(accent), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\\(Int(progress * 100))%")
                                    .font(.headline.monospaced())
                            }
                            .frame(width: 76, height: 76)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("APCA Contrast Pass Rate").font(.subheadline.weight(.semibold))
                                Text("50 of 64 blocks exceed 75 Lc").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                """
            )

        case .contributionHeatmap:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack {
                            Text("Token Build Cadence").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("12 Weeks").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(spacing: 4) {
                            ForEach(0..<4, id: \\.self) { row in
                                HStack(spacing: 4) {
                                    ForEach(0..<12, id: \\.self) { col in
                                        let intensity = Double(((row * 7 + col * 3) % 5) + 1) / 5.0
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(\(accent).opacity(intensity))
                                            .frame(width: 16, height: 16)
                                    }
                                }
                            }
                        }
                """
            )

        case .conversionFunnelCard:
            return ctx.wrapComponentView(
                stateProperties: "    private let stages: [(String, Double)] = [(\"Artboard Created\", 1.0), (\"Tokens Compiled\", 0.68), (\"Xcode Exported\", 0.44)]",
                bodyCore: """
                        Text("Activation Funnel").font(.subheadline.weight(.semibold))
                        ForEach(stages, id: \\.0) { name, ratio in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(name).font(.caption.weight(.medium))
                                    Spacer()
                                    Text("\\(Int(ratio * 100))%").font(.caption.monospaced())
                                }
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(\(accent).opacity(0.35 + ratio * 0.65))
                                        .frame(width: geo.size.width * ratio, height: 10)
                                }
                                .frame(height: 10)
                            }
                        }
                """
            )

        case .latencyPercentileChart:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack {
                            Text("Solver Frame Latency").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("SLO < 16.6ms").font(.caption2.monospaced()).foregroundStyle(\(okColor))
                        }
                        HStack(spacing: 14) {
                            VStack(alignment: .leading) { Text("P50").font(.caption2).foregroundStyle(.secondary); Text("1.4ms").font(.headline.monospaced()) }
                            Divider().frame(height: 28)
                            VStack(alignment: .leading) { Text("P95").font(.caption2).foregroundStyle(.secondary); Text("4.8ms").font(.headline.monospaced()).foregroundStyle(\(accent)) }
                            Divider().frame(height: 28)
                            VStack(alignment: .leading) { Text("P99").font(.caption2).foregroundStyle(.secondary); Text("9.2ms").font(.headline.monospaced()).foregroundStyle(\(warnColor)) }
                        }
                """
            )

        case .flamegraphSpanView:
            return ctx.wrapComponentView(
                bodyCore: """
                        Text("Frame Trace · 4.20 ms").font(.subheadline.weight(.semibold))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AutoLayoutConstraintSolver.solve (4.2ms)")
                                .font(.caption2.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(4)
                                .background(\(accent).opacity(0.24), in: RoundedRectangle(cornerRadius: 4))
                            HStack(spacing: 4) {
                                Text("measureIntrinsic (1.6ms)")
                                    .font(.caption2.monospaced())
                                    .padding(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(\(okColor).opacity(0.24), in: RoundedRectangle(cornerRadius: 4))
                                Text("distributeMainAxis (2.1ms)")
                                    .font(.caption2.monospaced())
                                    .padding(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(\(warnColor).opacity(0.24), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                """
            )

        case .sortableDataGrid:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var ascending = true",
                bodyCore: """
                        HStack {
                            Text("Token").font(.caption.weight(.bold)).frame(maxWidth: .infinity, alignment: .leading)
                            Button { ascending.toggle() } label: {
                                Label("APCA Lc", systemImage: ascending ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.plain)
                        }
                        Divider()
                        ForEach([("textPrimary", "94.2 Lc"), ("brandPrimary", "68.5 Lc"), ("textSecondary", "63.8 Lc")], id: \\.0) { role, lc in
                            HStack {
                                Text(role).font(.caption.monospaced()).frame(maxWidth: .infinity, alignment: .leading)
                                Text(lc).font(.caption.monospaced()).foregroundStyle(\(accent))
                            }
                            .padding(.vertical, 3)
                        }
                """
            )

        case .kanbanBoardColumn:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack {
                            Text("READY FOR QA").font(.caption.weight(.bold))
                            Spacer()
                            Text("2 / 4")
                                .font(.caption2.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(\(accent).opacity(0.16), in: Capsule())
                        }
                        ForEach(["Verify High-Contrast Dark", "Audit VisionOS Gaze Targets"], id: \\.self) { card in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card).font(.subheadline.weight(.medium))
                                Text("DesignSystem · P1").font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: \(ctx.radSM)))
                        }
                """
            )

        case .activityTimelineFeed:
            return ctx.wrapComponentView(
                bodyCore: """
                        Text("Workspace Audit Stream").font(.subheadline.weight(.semibold))
                        ForEach([("Compiled 8 token targets", "Just now"), ("Synced Master CTA across 5 artboards", "4m ago")], id: \\.0) { event, time in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(\(accent)).frame(width: 8, height: 8).padding(.top, 5)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event).font(.caption.weight(.medium))
                                    Text(time).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                """
            )

        case .unifiedDiffBlock:
            return ctx.wrapComponentView(
                bodyCore: """
                        Text("ChiefKitSemanticTheme.swift").font(.caption.monospaced().weight(.semibold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("- let radiusMedium: CGFloat = 10")
                                .font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .background(\(errColor).opacity(0.15))
                            Text("+ let radiusMedium: CGFloat = \(ctx.radMD)")
                                .font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .background(\(okColor).opacity(0.15))
                        }
                """
            )

        case .jsonTreeExplorer:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var isExpanded = true",
                bodyCore: """
                        Button { isExpanded.toggle() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.caption2)
                                Text("\"chiefkit\" : { 3 keys }").font(.caption.monospaced().weight(.semibold))
                            }
                        }
                        .buttonStyle(.plain)
                        if isExpanded {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("  \"primary\": \"\(ctx.theme.primary.hexString)\"").font(.caption.monospaced()).foregroundStyle(\(accent))
                                Text("  \"liquidGlass\": \(ctx.theme.isLiquidGlassEnabled ? "true" : "false")").font(.caption.monospaced())
                            }
                        }
                """
            )

        case .heroKPIDeltaBanner:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack(spacing: 20) {
                            ForEach([("64", "SwiftBlocks", "+100%"), ("8", "Token Targets", "DTCG"), ("0ms", "Cloud Calls", "Local")], id: \\.1) { val, label, pill in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(val).font(.title3.weight(.bold))
                                        Text(pill).font(.caption2.weight(.bold)).foregroundStyle(\(okColor))
                                    }
                                    Text(label).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                """
            )

        case .quotaUsageRing:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack(spacing: 12) {
                            Gauge(value: 0.68) { EmptyView() }
                                .gaugeStyle(.accessoryCircularCapacity)
                                .tint(\(accent))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Local Neural Cache").font(.subheadline.weight(.semibold))
                                Text("6.8 GB of 10.0 GB allocated").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                """
            )

        default: // .realtimeTickerBar
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack(spacing: 14) {
                            HStack(spacing: 5) {
                                Circle().fill(\(okColor)).frame(width: 7, height: 7)
                                Text("LIVE").font(.caption2.weight(.bold)).foregroundStyle(\(okColor))
                            }
                            Text("FPS 120.0").font(.caption.monospaced())
                            Text("•").foregroundStyle(.tertiary)
                            Text("RK4 Δ 0.0002").font(.caption.monospaced()).foregroundStyle(\(accent))
                            Spacer()
                            Text("OKLCH D65").font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                """
            )
        }
    }
}
