import Foundation

// MARK: - Display Refresh Targets & Pipeline Phases

public enum DisplayRefreshTarget: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case standard60Hz = "60Hz Standard"
    case visionOS90Hz = "90Hz Spatial (visionOS)"
    case proMotion120Hz = "120Hz ProMotion"

    public var id: String { rawValue }

    public var refreshRateHz: Int {
        switch self {
        case .standard60Hz: 60
        case .visionOS90Hz: 90
        case .proMotion120Hz: 120
        }
    }

    public var frameBudgetMs: Double {
        switch self {
        case .standard60Hz: 16.67
        case .visionOS90Hz: 11.11
        case .proMotion120Hz: 8.33
        }
    }

    public var backingScaleFactor: Double {
        switch self {
        case .standard60Hz: 2.0
        case .visionOS90Hz: 2.5
        case .proMotion120Hz: 3.0
        }
    }
}

public enum RenderPipelinePhase: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case swiftUIViewDiffing = "SwiftUI View Diffing"
    case cpuLayoutMeasurement = "CPU Layout Pass"
    case coreAnimationCommit = "CoreAnimation Commit"
    case metalOffscreenComposite = "Metal GPU Offscreen"

    public var id: String { rawValue }
}

public enum GPUOffscreenHazardKind: String, CaseIterable, Codable, Hashable, Sendable {
    case gaussianBlur
    case unbatchedDropShadow
    case alphaMaskComposite
    case complexClipShape
    case liquidGlassShader
    case translucentMaterialBackdrop
    case eagerStackInScrollView
    case geometryReaderFeedbackLoop
    case inlineFormatterAllocation
}

// MARK: - Optimization Patches, Hazards & Flamegraph Tree

public struct FrameOptimizationPatch: Codable, Hashable, Sendable {
    public var title: String
    public var beforeSnippet: String
    public var afterSnippet: String
    public var expectedSavingsMs: Double

    public init(
        title: String,
        beforeSnippet: String,
        afterSnippet: String,
        expectedSavingsMs: Double
    ) {
        self.title = title
        self.beforeSnippet = beforeSnippet
        self.afterSnippet = afterSnippet
        self.expectedSavingsMs = expectedSavingsMs
    }
}

public struct FrameProfilerHazard: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: GPUOffscreenHazardKind
    public var lineNumber: Int?
    public var snippet: String
    public var estimatedPenaltyMs: Double
    public var estimatedOffscreenPasses: Int
    public var estimatedExtraRAMKB: Int
    public var severity: SchemaDiagnosticSeverity
    public var explanation: String
    public var patch: FrameOptimizationPatch

    public init(
        id: String,
        kind: GPUOffscreenHazardKind,
        lineNumber: Int?,
        snippet: String,
        estimatedPenaltyMs: Double,
        estimatedOffscreenPasses: Int,
        estimatedExtraRAMKB: Int,
        severity: SchemaDiagnosticSeverity,
        explanation: String,
        patch: FrameOptimizationPatch
    ) {
        self.id = id
        self.kind = kind
        self.lineNumber = lineNumber
        self.snippet = snippet
        self.estimatedPenaltyMs = estimatedPenaltyMs
        self.estimatedOffscreenPasses = estimatedOffscreenPasses
        self.estimatedExtraRAMKB = estimatedExtraRAMKB
        self.severity = severity
        self.explanation = explanation
        self.patch = patch
    }
}

public struct FlamegraphNode: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var phase: RenderPipelinePhase
    public var selfTimeMs: Double
    public var totalTimeMs: Double
    public var offscreenPassCount: Int
    public var allocatedRAMKB: Int
    public var children: [FlamegraphNode]

    public init(
        id: String,
        label: String,
        phase: RenderPipelinePhase,
        selfTimeMs: Double,
        offscreenPassCount: Int = 0,
        allocatedRAMKB: Int = 0,
        children: [FlamegraphNode] = []
    ) {
        self.id = id
        self.label = label
        self.phase = phase
        self.selfTimeMs = (selfTimeMs * 1000.0).rounded() / 1000.0
        let childrenSum = children.reduce(0.0) { $0 + $1.totalTimeMs }
        self.totalTimeMs = ((selfTimeMs + childrenSum) * 1000.0).rounded() / 1000.0
        self.offscreenPassCount = offscreenPassCount + children.reduce(0) { $0 + $1.offscreenPassCount }
        self.allocatedRAMKB = allocatedRAMKB + children.reduce(0) { $0 + $1.allocatedRAMKB }
        self.children = children
    }

    public func percentage(ofBudget budgetMs: Double) -> Double {
        guard budgetMs > 0 else { return 0 }
        return ((totalTimeMs / budgetMs) * 1000.0).rounded() / 10.0
    }

    public func flattenedRows(depth: Int = 0) -> [(depth: Int, node: FlamegraphNode)] {
        var rows: [(depth: Int, node: FlamegraphNode)] = [(depth, self)]
        for child in children {
            rows.append(contentsOf: child.flattenedRows(depth: depth + 1))
        }
        return rows
    }
}

public struct FrameBudgetProfileReport: Codable, Hashable, Sendable {
    public var target: DisplayRefreshTarget
    public var budgetMs: Double
    public var cpuViewDiffingMs: Double
    public var cpuLayoutPassMs: Double
    public var coreAnimationCommitMs: Double
    public var metalGPUCompositeMs: Double
    public var totalFrameTimeMs: Double
    public var headroomMs: Double
    public var metalOffscreenPassCount: Int
    public var hitchRatioPercent: Double
    public var estimatedSustainedFPS: Double
    public var estimatedPeakRAMKB: Int
    public var meetsFrameBudget: Bool
    public var performanceGrade: String
    public var flamegraphRoot: FlamegraphNode
    public var hazards: [FrameProfilerHazard]

    public init(
        target: DisplayRefreshTarget,
        cpuViewDiffingMs: Double,
        cpuLayoutPassMs: Double,
        coreAnimationCommitMs: Double,
        metalGPUCompositeMs: Double,
        metalOffscreenPassCount: Int,
        hitchRatioPercent: Double,
        estimatedPeakRAMKB: Int,
        flamegraphRoot: FlamegraphNode,
        hazards: [FrameProfilerHazard]
    ) {
        self.target = target
        self.budgetMs = target.frameBudgetMs
        self.cpuViewDiffingMs = Self.round2(cpuViewDiffingMs)
        self.cpuLayoutPassMs = Self.round2(cpuLayoutPassMs)
        self.coreAnimationCommitMs = Self.round2(coreAnimationCommitMs)
        self.metalGPUCompositeMs = Self.round2(metalGPUCompositeMs)
        let total = cpuViewDiffingMs + cpuLayoutPassMs + coreAnimationCommitMs + metalGPUCompositeMs
        self.totalFrameTimeMs = Self.round2(total)
        self.headroomMs = Self.round2(target.frameBudgetMs - total)
        self.metalOffscreenPassCount = metalOffscreenPassCount
        self.hitchRatioPercent = Self.round2(min(100.0, max(0.0, hitchRatioPercent)))
        let rawFPS = total > 0 ? min(Double(target.refreshRateHz), 1000.0 / total) : Double(target.refreshRateHz)
        self.estimatedSustainedFPS = Self.round2(rawFPS)
        self.estimatedPeakRAMKB = estimatedPeakRAMKB
        self.meetsFrameBudget = total <= target.frameBudgetMs

        let utilization = total / target.frameBudgetMs
        if utilization <= 0.65 {
            self.performanceGrade = "A+ (Locked \(target.refreshRateHz)fps)"
        } else if utilization <= 0.90 {
            self.performanceGrade = "A (Within Frame Budget)"
        } else if utilization <= 1.05 {
            self.performanceGrade = "B (Tight Thermal Headroom)"
        } else if utilization <= 1.40 {
            self.performanceGrade = "C (Intermittent Hitch Risk)"
        } else {
            self.performanceGrade = "D (Sustained Frame Drops)"
        }

        self.flamegraphRoot = flamegraphRoot
        self.hazards = hazards
    }

    private static func round2(_ value: Double) -> Double {
        (value * 100.0).rounded() / 100.0
    }
}

// MARK: - FrameBudgetProfiler Engine

public enum FrameBudgetProfiler {

    public static func profile(
        swiftUISource: String,
        canvas: CanvasDocument? = nil,
        theme: StudioThemeTokens = StudioThemeTokens(),
        target: DisplayRefreshTarget = .proMotion120Hz
    ) -> FrameBudgetProfileReport {
        let lines = swiftUISource.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let hasDrawingGroup = swiftUISource.contains(".drawingGroup(")
        let hasCompositingGroup = swiftUISource.contains(".compositingGroup(")
        let scale = target.backingScaleFactor

        var hazards: [FrameProfilerHazard] = []
        var diffChildren: [FlamegraphNode] = []
        var layoutChildren: [FlamegraphNode] = []
        var commitChildren: [FlamegraphNode] = []
        var gpuChildren: [FlamegraphNode] = []

        var stackCount = 0
        var textAndLeafCount = 0
        var hasScrollView = false
        var hasEagerVStackInsideScroll = false
        var scrollIndentLevel: Int?

        for (idx, rawLine) in lines.enumerated() {
            let lineNum = idx + 1
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("//") { continue }
            let indent = rawLine.prefix(while: { $0 == " " || $0 == "\t" }).count

            if trimmed.contains("ScrollView") {
                hasScrollView = true
                scrollIndentLevel = indent
            }

            if hasScrollView, let sIndent = scrollIndentLevel, indent > sIndent {
                if (trimmed.hasPrefix("VStack") || trimmed.hasPrefix("HStack")) && !swiftUISource.contains("LazyVStack") && !swiftUISource.contains("LazyHStack") {
                    if !hasEagerVStackInsideScroll && lines.count > 18 {
                        hasEagerVStackInsideScroll = true
                        let penalty = 2.65
                        hazards.append(
                            FrameProfilerHazard(
                                id: "hazard-eager-scroll-\(lineNum)",
                                kind: .eagerStackInScrollView,
                                lineNumber: lineNum,
                                snippet: trimmed,
                                estimatedPenaltyMs: penalty,
                                estimatedOffscreenPasses: 0,
                                estimatedExtraRAMKB: 640,
                                severity: .warning,
                                explanation: "Eager `VStack`/`HStack` inside `ScrollView` instantiates and measures all child subviews up-front on the main thread.",
                                patch: FrameOptimizationPatch(
                                    title: "Convert eager stack to LazyVStack",
                                    beforeSnippet: "VStack(",
                                    afterSnippet: "LazyVStack(",
                                    expectedSavingsMs: 2.10
                                )
                            )
                        )
                        layoutChildren.append(
                            FlamegraphNode(
                                id: "fg-eager-scroll-\(lineNum)",
                                label: "Eager ScrollView Subtree Layout (L\(lineNum))",
                                phase: .cpuLayoutMeasurement,
                                selfTimeMs: penalty,
                                allocatedRAMKB: 640
                            )
                        )
                    }
                }
            }

            // Count structural containers & leaf views
            if trimmed.contains("VStack") || trimmed.contains("HStack") || trimmed.contains("ZStack") || trimmed.contains("Grid") {
                stackCount += 1
            }
            if trimmed.contains("Text(") || trimmed.contains("Label(") || trimmed.contains("Image(") || trimmed.contains("Button(") || trimmed.contains("EDKButton(") {
                textAndLeafCount += 1
            }

            // Detect large ForEach ranges e.g. ForEach(0..<500)
            if let largeCount = parseLargeForEachUpperBound(in: trimmed), largeCount >= 80 {
                let isLazy = swiftUISource.contains("LazyVStack") || swiftUISource.contains("LazyHStack") || swiftUISource.contains("List")
                let factor = isLazy ? 0.45 : min(9.5, Double(largeCount) * 0.018)
                diffChildren.append(
                    FlamegraphNode(
                        id: "fg-foreach-\(lineNum)",
                        label: "ForEach(\(largeCount) items, \(isLazy ? "lazy" : "eager"))",
                        phase: .swiftUIViewDiffing,
                        selfTimeMs: factor,
                        allocatedRAMKB: isLazy ? 96 : largeCount * 3
                    )
                )
            }

            // Detect GeometryReader layout double-pass hazard
            if trimmed.contains("GeometryReader") {
                let penalty = 0.95
                hazards.append(
                    FrameProfilerHazard(
                        id: "hazard-geom-\(lineNum)",
                        kind: .geometryReaderFeedbackLoop,
                        lineNumber: lineNum,
                        snippet: trimmed,
                        estimatedPenaltyMs: penalty,
                        estimatedOffscreenPasses: 0,
                        estimatedExtraRAMKB: 48,
                        severity: .advisory,
                        explanation: "`GeometryReader` forces secondary child measurement proposals and can trigger state feedback loops on resize.",
                        patch: FrameOptimizationPatch(
                            title: "Prefer SwiftUI `containerRelativeFrame` or `ViewThatFits`",
                            beforeSnippet: trimmed,
                            afterSnippet: "// Consider .containerRelativeFrame(.horizontal) instead of GeometryReader\n\(trimmed)",
                            expectedSavingsMs: 0.70
                        )
                    )
                )
                layoutChildren.append(
                    FlamegraphNode(
                        id: "fg-geom-\(lineNum)",
                        label: "GeometryReader Secondary Proposal (L\(lineNum))",
                        phase: .cpuLayoutMeasurement,
                        selfTimeMs: penalty,
                        allocatedRAMKB: 48
                    )
                )
            }

            // Detect inline DateFormatter / NumberFormatter allocation inside body
            if trimmed.contains("DateFormatter()") || trimmed.contains("NumberFormatter()") || trimmed.contains("ISO8601DateFormatter()") {
                let penalty = 0.85
                hazards.append(
                    FrameProfilerHazard(
                        id: "hazard-formatter-\(lineNum)",
                        kind: .inlineFormatterAllocation,
                        lineNumber: lineNum,
                        snippet: trimmed,
                        estimatedPenaltyMs: penalty,
                        estimatedOffscreenPasses: 0,
                        estimatedExtraRAMKB: 64,
                        severity: .warning,
                        explanation: "Allocating `Formatter` subclasses during `body` evaluation triggers ICU locale table lookups every frame.",
                        patch: FrameOptimizationPatch(
                            title: "Use `.formatted(...)` FormatStyle API",
                            beforeSnippet: trimmed,
                            afterSnippet: "// Replace inline Formatter() with Date.FormatStyle (.formatted(date: .abbreviated, time: .shortened))",
                            expectedSavingsMs: 0.78
                        )
                    )
                )
                diffChildren.append(
                    FlamegraphNode(
                        id: "fg-formatter-\(lineNum)",
                        label: "ICU Formatter Allocation (L\(lineNum))",
                        phase: .swiftUIViewDiffing,
                        selfTimeMs: penalty,
                        allocatedRAMKB: 64
                    )
                )
            }

            // GPU Offscreen Pass hazards: .blur, .shadow, .mask, .clipShape, .edkLiquidGlass, .ultraThinMaterial
            if trimmed.contains(".blur(") {
                let penalty = hasDrawingGroup ? 0.85 : 1.75
                let texKB = Int((320.0 * 180.0 * 4.0 * scale * scale / 1024.0).rounded())
                hazards.append(
                    FrameProfilerHazard(
                        id: "hazard-blur-\(lineNum)",
                        kind: .gaussianBlur,
                        lineNumber: lineNum,
                        snippet: trimmed,
                        estimatedPenaltyMs: penalty,
                        estimatedOffscreenPasses: 2,
                        estimatedExtraRAMKB: texKB,
                        severity: .warning,
                        explanation: "Separable horizontal + vertical Gaussian blur requires 2 Metal offscreen render targets.",
                        patch: FrameOptimizationPatch(
                            title: "Flatten static blurred layer with `.drawingGroup()`",
                            beforeSnippet: trimmed,
                            afterSnippet: "\(trimmed)\n    .drawingGroup()",
                            expectedSavingsMs: 0.80
                        )
                    )
                )
                gpuChildren.append(
                    FlamegraphNode(
                        id: "fg-blur-\(lineNum)",
                        label: "MPSImageGaussianBlur 2-Pass (L\(lineNum))",
                        phase: .metalOffscreenComposite,
                        selfTimeMs: penalty,
                        offscreenPassCount: 2,
                        allocatedRAMKB: texKB
                    )
                )
            }

            if trimmed.contains(".shadow(") && !hasCompositingGroup && !hasDrawingGroup {
                let penalty = 1.15
                let texKB = Int((280.0 * 120.0 * 4.0 * scale * scale / 1024.0).rounded())
                hazards.append(
                    FrameProfilerHazard(
                        id: "hazard-shadow-\(lineNum)",
                        kind: .unbatchedDropShadow,
                        lineNumber: lineNum,
                        snippet: trimmed,
                        estimatedPenaltyMs: penalty,
                        estimatedOffscreenPasses: 1,
                        estimatedExtraRAMKB: texKB,
                        severity: .advisory,
                        explanation: "Dynamic alpha-channel `.shadow(...)` rasterizes the entire subtree offscreen when `.compositingGroup()` is omitted.",
                        patch: FrameOptimizationPatch(
                            title: "Add `.compositingGroup()` before `.shadow(...)`",
                            beforeSnippet: trimmed,
                            afterSnippet: ".compositingGroup()\n\(trimmed)",
                            expectedSavingsMs: 0.65
                        )
                    )
                )
                gpuChildren.append(
                    FlamegraphNode(
                        id: "fg-shadow-\(lineNum)",
                        label: "CoreAnimation Dynamic Alpha Shadow (L\(lineNum))",
                        phase: .metalOffscreenComposite,
                        selfTimeMs: penalty,
                        offscreenPassCount: 1,
                        allocatedRAMKB: texKB
                    )
                )
            }

            if trimmed.contains(".mask(") || trimmed.contains(".mask {") {
                let penalty = 1.30
                let texKB = Int((260.0 * 140.0 * 4.0 * scale * scale / 1024.0).rounded())
                hazards.append(
                    FrameProfilerHazard(
                        id: "hazard-mask-\(lineNum)",
                        kind: .alphaMaskComposite,
                        lineNumber: lineNum,
                        snippet: trimmed,
                        estimatedPenaltyMs: penalty,
                        estimatedOffscreenPasses: 2,
                        estimatedExtraRAMKB: texKB,
                        severity: .warning,
                        explanation: "Alpha `.mask` allocates separate content and mask Metal textures composite-blended offscreen.",
                        patch: FrameOptimizationPatch(
                            title: "Prefer `.clipShape(RoundedRectangle(...))` over `.mask`",
                            beforeSnippet: trimmed,
                            afterSnippet: ".clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))",
                            expectedSavingsMs: 0.90
                        )
                    )
                )
                gpuChildren.append(
                    FlamegraphNode(
                        id: "fg-mask-\(lineNum)",
                        label: "CABackdropAlphaMask Composite (L\(lineNum))",
                        phase: .metalOffscreenComposite,
                        selfTimeMs: penalty,
                        offscreenPassCount: 2,
                        allocatedRAMKB: texKB
                    )
                )
            }

            if trimmed.contains(".edkLiquidGlass(") {
                let frostOverhead = 0.65 + (theme.glassFrost * 0.75) + (theme.specularRim * 0.35)
                let texKB = Int((300.0 * 140.0 * 4.0 * scale * scale / 1024.0).rounded())
                hazards.append(
                    FrameProfilerHazard(
                        id: "hazard-liquid-glass-\(lineNum)",
                        kind: .liquidGlassShader,
                        lineNumber: lineNum,
                        snippet: trimmed,
                        estimatedPenaltyMs: frostOverhead,
                        estimatedOffscreenPasses: 1,
                        estimatedExtraRAMKB: texKB,
                        severity: theme.glassFrost > 0.70 ? .warning : .info,
                        explanation: "Liquid Glass samples CABackdropLayer refraction + specular rim shader (frost: \(Int((theme.glassFrost * 100).rounded()))%).",
                        patch: FrameOptimizationPatch(
                            title: "Keep frost <= 0.55 on dense 120Hz scrolling cards",
                            beforeSnippet: trimmed,
                            afterSnippet: trimmed,
                            expectedSavingsMs: 0.35
                        )
                    )
                )
                gpuChildren.append(
                    FlamegraphNode(
                        id: "fg-glass-\(lineNum)",
                        label: "EDKLiquidGlass Refraction + Specular Shader (L\(lineNum))",
                        phase: .metalOffscreenComposite,
                        selfTimeMs: frostOverhead,
                        offscreenPassCount: 1,
                        allocatedRAMKB: texKB
                    )
                )
            } else if trimmed.contains("Material") && (trimmed.contains("ultraThinMaterial") || trimmed.contains("regularMaterial") || trimmed.contains("thickMaterial")) {
                let penalty = 0.72
                let texKB = Int((220.0 * 64.0 * 4.0 * scale * scale / 1024.0).rounded())
                gpuChildren.append(
                    FlamegraphNode(
                        id: "fg-material-\(lineNum)",
                        label: "CABackdropLayer Material Blur (L\(lineNum))",
                        phase: .metalOffscreenComposite,
                        selfTimeMs: penalty,
                        offscreenPassCount: 1,
                        allocatedRAMKB: texKB
                    )
                )
            }

            if trimmed.contains(".clipShape(") && !trimmed.contains("RoundedRectangle") && !trimmed.contains("Capsule") {
                let penalty = 0.58
                gpuChildren.append(
                    FlamegraphNode(
                        id: "fg-clip-\(lineNum)",
                        label: "Custom Bezier Stencil ClipShape (L\(lineNum))",
                        phase: .metalOffscreenComposite,
                        selfTimeMs: penalty,
                        offscreenPassCount: 1,
                        allocatedRAMKB: 128
                    )
                )
            }
        }

        // Incorporate CanvasDocument nodes if provided and not already double-counted
        if let canvas, swiftUISource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            for node in canvas.nodes {
                let areaKB = Int((node.frame.width * node.frame.height * 4.0 * scale * scale / 1024.0).rounded())
                layoutChildren.append(
                    FlamegraphNode(
                        id: "fg-canvas-node-\(node.id.uuidString.prefix(8))",
                        label: "\(node.kind.paletteTitle) ('\(node.title)')",
                        phase: .cpuLayoutMeasurement,
                        selfTimeMs: 0.14,
                        allocatedRAMKB: max(16, areaKB / 4)
                    )
                )
                if node.variant == .glass || (theme.isLiquidGlassEnabled && (node.kind == .card || node.kind == .metric)) {
                    let shaderCost = 0.55 + theme.glassFrost * 0.60
                    gpuChildren.append(
                        FlamegraphNode(
                            id: "fg-canvas-glass-\(node.id.uuidString.prefix(8))",
                            label: "Glass Surface '\(node.title)'",
                            phase: .metalOffscreenComposite,
                            selfTimeMs: shaderCost,
                            offscreenPassCount: 1,
                            allocatedRAMKB: areaKB
                        )
                    )
                }
            }
        }

        // Base pipeline stage costs
        let baseDiffMs = 0.32 + Double(stackCount) * 0.07 + Double(textAndLeafCount) * 0.05
        let baseLayoutMs = 0.40 + Double(stackCount) * 0.11 + Double(textAndLeafCount) * 0.06
        let baseCommitMs = 0.28 + Double(stackCount + textAndLeafCount) * 0.035
        let baseGPUMs = 0.45

        let diffNode = FlamegraphNode(
            id: "phase-diffing",
            label: "AttributeGraph View Diffing (\(stackCount + textAndLeafCount) nodes)",
            phase: .swiftUIViewDiffing,
            selfTimeMs: baseDiffMs,
            allocatedRAMKB: 128 + (stackCount + textAndLeafCount) * 6,
            children: diffChildren
        )

        let layoutNode = FlamegraphNode(
            id: "phase-layout",
            label: "SwiftUI Proposal & Placement Pass",
            phase: .cpuLayoutMeasurement,
            selfTimeMs: baseLayoutMs,
            allocatedRAMKB: 96 + stackCount * 8,
            children: layoutChildren
        )

        commitChildren.append(
            FlamegraphNode(
                id: "fg-ca-archive",
                label: "CALayer Tree Marshal & RenderServer IPC",
                phase: .coreAnimationCommit,
                selfTimeMs: 0.22,
                allocatedRAMKB: 84
            )
        )
        let commitNode = FlamegraphNode(
            id: "phase-commit",
            label: "CATransaction::commit()",
            phase: .coreAnimationCommit,
            selfTimeMs: baseCommitMs,
            allocatedRAMKB: 112,
            children: commitChildren
        )

        let gpuNode = FlamegraphNode(
            id: "phase-metal-gpu",
            label: "Metal CommandBuffer & Offscreen Compositor",
            phase: .metalOffscreenComposite,
            selfTimeMs: baseGPUMs,
            allocatedRAMKB: 1_024,
            children: gpuChildren
        )

        let rootFlamegraph = FlamegraphNode(
            id: "frame-root",
            label: "DisplayLink Frame (\(target.rawValue))",
            phase: .swiftUIViewDiffing,
            selfTimeMs: 0.0,
            allocatedRAMKB: 256,
            children: [diffNode, layoutNode, commitNode, gpuNode]
        )

        let totalMs = rootFlamegraph.totalTimeMs
        let budget = target.frameBudgetMs
        let hitchRatio: Double
        if totalMs <= budget * 0.75 {
            hitchRatio = max(0.0, (totalMs / budget) * 1.2)
        } else if totalMs <= budget {
            let tail = (totalMs - budget * 0.75) / (budget * 0.25)
            hitchRatio = 1.2 + tail * 7.5
        } else {
            let overrunRatio = (totalMs - budget) / budget
            hitchRatio = min(100.0, 12.0 + overrunRatio * 68.0)
        }

        return FrameBudgetProfileReport(
            target: target,
            cpuViewDiffingMs: diffNode.totalTimeMs,
            cpuLayoutPassMs: layoutNode.totalTimeMs,
            coreAnimationCommitMs: commitNode.totalTimeMs,
            metalGPUCompositeMs: gpuNode.totalTimeMs,
            metalOffscreenPassCount: rootFlamegraph.offscreenPassCount,
            hitchRatioPercent: hitchRatio,
            estimatedPeakRAMKB: rootFlamegraph.allocatedRAMKB,
            flamegraphRoot: rootFlamegraph,
            hazards: hazards
        )
    }

    public static func compareAcrossTargets(
        swiftUISource: String,
        canvas: CanvasDocument? = nil,
        theme: StudioThemeTokens = StudioThemeTokens()
    ) -> [FrameBudgetProfileReport] {
        DisplayRefreshTarget.allCases.map { refreshTarget in
            profile(swiftUISource: swiftUISource, canvas: canvas, theme: theme, target: refreshTarget)
        }
    }

    public static func applyOptimizationPatches(
        to swiftUISource: String,
        hazards: [FrameProfilerHazard]
    ) -> String {
        var patched = swiftUISource
        for hazard in hazards where hazard.patch.beforeSnippet != hazard.patch.afterSnippet {
            if let range = patched.range(of: hazard.patch.beforeSnippet) {
                patched.replaceSubrange(range, with: hazard.patch.afterSnippet)
            }
        }
        return patched
    }

    private static func parseLargeForEachUpperBound(in line: String) -> Int? {
        let pattern = #"ForEach\(\s*\d+\s*\.\.<\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: nsRange),
              let numRange = Range(match.range(at: 1), in: line) else { return nil }
        return Int(line[numRange])
    }
}
