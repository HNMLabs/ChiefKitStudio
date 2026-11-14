#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitDesignSystem
import ChiefKitStudioCore
import SwiftUI

struct AnimationTimelineStudioView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    private enum ParameterInputMode: String, CaseIterable, Identifiable {
        case perceptual = "Perceptual (Duration / Bounce)"
        case physical = "Physical (Mass / Stiffness / Damping)"

        var id: String { rawValue }
    }

    private enum BezierPresetChoice: String, CaseIterable, Identifiable {
        case appleSpringLike = "Apple Fluid"
        case easeInOut = "Ease In-Out"
        case snappy = "Snappy"
        case fluidGlass = "Liquid Glass"
        case anticipate = "Anticipate"
        case linear = "Linear"

        var id: String { rawValue }

        var curve: CubicBezierCurve {
            switch self {
            case .appleSpringLike: .appleSpringLike
            case .easeInOut: .easeInOut
            case .snappy: .snappy
            case .fluidGlass: .fluidGlass
            case .anticipate: .anticipate
            case .linear: .linear
            }
        }
    }

    private enum AnimationCodeExportKind: String, CaseIterable, Identifiable {
        case phaseAnimator = "PhaseAnimator"
        case keyframeAnimator = "KeyframeAnimator"
        case springModifier = "Spring Modifier"

        var id: String { rawValue }
    }

    @State private var inputMode: ParameterInputMode = .perceptual
    @State private var perceptualDuration: Double = 0.55
    @State private var perceptualBounce: Double = 0.28
    @State private var mass: Double = 1.0
    @State private var stiffness: Double = 240.0
    @State private var damping: Double = 18.0
    @State private var initialVelocity: Double = 0.0
    @State private var quadraticDrag: Double = 0.05

    @State private var bezierPreset: BezierPresetChoice = .appleSpringLike
    @State private var timelineScrubSeconds: Double = 0.35
    @State private var isLivePreviewExpanded = false
    @State private var selectedExportKind: AnimationCodeExportKind = .phaseAnimator

    private var activeSpring: SpringParameters {
        switch inputMode {
        case .perceptual:
            return SpringParameters(
                duration: perceptualDuration,
                bounce: perceptualBounce,
                initialVelocity: initialVelocity
            )
        case .physical:
            return SpringParameters(
                mass: mass,
                stiffness: stiffness,
                damping: damping,
                initialVelocity: initialVelocity
            )
        }
    }

    private var demoTimeline: AnimationTimeline {
        AnimationTimeline(
            name: "LiquidGlassCardEntrance",
            tracks: [
                KeyframeTrack(
                    propertyName: "scale",
                    initialValue: 0.86,
                    keyframes: [
                        KeyframePoint(time: 0.35, value: 1.04, interpolation: .spring(activeSpring)),
                        KeyframePoint(time: 0.80, value: 1.00, interpolation: .cubicBezier(bezierPreset.curve)),
                        KeyframePoint(time: 1.20, value: 1.00, interpolation: .discreteHold)
                    ]
                ),
                KeyframeTrack(
                    propertyName: "opacity",
                    initialValue: 0.25,
                    keyframes: [
                        KeyframePoint(time: 0.30, value: 1.00, interpolation: .cubicBezier(.easeInOut)),
                        KeyframePoint(time: 1.20, value: 1.00, interpolation: .linear)
                    ]
                ),
                KeyframeTrack(
                    propertyName: "offsetY",
                    initialValue: 26.0,
                    keyframes: [
                        KeyframePoint(time: 0.45, value: -4.0, interpolation: .spring(activeSpring)),
                        KeyframePoint(time: 0.90, value: 0.0, interpolation: .cubicBezier(bezierPreset.curve)),
                        KeyframePoint(time: 1.20, value: 0.0, interpolation: .linear)
                    ]
                )
            ],
            isLooping: true
        )
    }

    var body: some View {
        let report = SpringAnalysisReport(parameters: activeSpring)
        let plotHorizon = max(0.8, min(3.2, report.settlingTimeSeconds * 1.25 + 0.25))
        let rk4Samples = RK4SpringIntegrator.integrate(
            parameters: activeSpring,
            duration: plotHorizon,
            dt: 1.0 / 240.0,
            quadraticDrag: quadraticDrag
        )

        VStack(alignment: .leading, spacing: 16) {
            springPhysicsControlsCard(report: report)
            oscillatorCurveCanvasCard(report: report, rk4Samples: rk4Samples, plotHorizon: plotHorizon)
            bezierAndMultiTrackCard
            codeSynthesisCard
        }
    }

    // MARK: - 1. Spring Parameters & Presets Card

    private func springPhysicsControlsCard(report: SpringAnalysisReport) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Harmonic Oscillator & RK4 Spring Physics",
                        subtitle: "Tune closed-form analytical springs alongside 4th-order Runge-Kutta numerical integration."
                    )
                    Spacer()
                    PillLabel(title: report.regime.rawValue, systemImage: "waveform.path.ecg")
                }

                HStack(spacing: 8) {
                    springPresetButton("Smooth", preset: .smooth)
                    springPresetButton("Snappy", preset: .snappy)
                    springPresetButton("Bouncy", preset: .bouncy)
                    springPresetButton("Interactive Glass", preset: .interactiveGlass)
                    springPresetButton("Gentle Float", preset: .gentleFloat)
                    Spacer()
                }

                Picker("Parameter Mode", selection: $inputMode) {
                    ForEach(ParameterInputMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if inputMode == .perceptual {
                    sliderRow("Perceptual Duration", value: $perceptualDuration, range: 0.15...1.60, unit: "s")
                    sliderRow("Bounce", value: $perceptualBounce, range: -0.35...0.75, unit: "")
                } else {
                    sliderRow("Mass (m)", value: $mass, range: 0.2...4.0, unit: "kg")
                    sliderRow("Stiffness (k)", value: $stiffness, range: 40.0...700.0, unit: "N/m")
                    sliderRow("Damping (c)", value: $damping, range: 2.0...80.0, unit: "Ns/m")
                }
                sliderRow("Initial Velocity (v₀)", value: $initialVelocity, range: -4.0...6.0, unit: "pt/s")
                sliderRow("RK4 Air Drag (c₂)", value: $quadraticDrag, range: 0.0...0.60, unit: "")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                    physicsStatTile("Damping Ratio ζ", String(format: "%.3f", report.dampingRatio))
                    physicsStatTile("Natural ωₙ", String(format: "%.2f rad/s", report.naturalFrequency))
                    physicsStatTile("Peak Overshoot", String(format: "%.1f%%", report.peakOvershootPercent))
                    physicsStatTile("Settling Time", String(format: "%.3f s", report.settlingTimeSeconds))
                    physicsStatTile("RK4 vs Exact RMS", String(format: "%.5f", report.rk4AnalyticalRMSError))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 2. SwiftUI Canvas Curve Plotter + Interactive Trigger

    private func oscillatorCurveCanvasCard(
        report: SpringAnalysisReport,
        rk4Samples: [SpringStateSample],
        plotHorizon: Double
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Analytical Trajectory (Solid) vs 240Hz RK4 + Drag (Dashed)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        let response = activeSpring.perceptualDuration
                        let dampingFraction = max(0.25, min(1.2, activeSpring.dampingRatio))
                        withAnimation(.spring(response: response, dampingFraction: dampingFraction)) {
                            isLivePreviewExpanded.toggle()
                        }
                    } label: {
                        Label(isLivePreviewExpanded ? "Reset Spring Puck" : "Trigger Live Spring", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                Canvas { context, size in
                    let padX: CGFloat = 24
                    let padY: CGFloat = 22
                    let plotW = max(10, size.width - padX * 2)
                    let plotH = max(10, size.height - padY * 2)
                    let minVal = -0.25
                    let maxVal = max(1.45, report.peakPosition + 0.12)
                    let spanVal = maxVal - minVal

                    func pointFor(time: Double, value: Double) -> CGPoint {
                        let nx = CGFloat(min(1.0, max(0.0, time / plotHorizon)))
                        let ny = CGFloat((value - minVal) / spanVal)
                        return CGPoint(x: padX + nx * plotW, y: size.height - padY - ny * plotH)
                    }

                    // Target equilibrium y = 1.0
                    let targetY = pointFor(time: 0, value: 1.0).y
                    var targetLine = Path()
                    targetLine.move(to: CGPoint(x: padX, y: targetY))
                    targetLine.addLine(to: CGPoint(x: size.width - padX, y: targetY))
                    context.stroke(
                        targetLine,
                        with: .color(theme.success.swiftUIColor.opacity(0.55)),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )

                    // Settling time vertical marker
                    if report.settlingTimeSeconds <= plotHorizon {
                        let settleX = pointFor(time: report.settlingTimeSeconds, value: 0).x
                        var settlePath = Path()
                        settlePath.move(to: CGPoint(x: settleX, y: padY))
                        settlePath.addLine(to: CGPoint(x: settleX, y: size.height - padY))
                        context.stroke(
                            settlePath,
                            with: .color(theme.warning.swiftUIColor.opacity(0.55)),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                    }

                    // Analytical curve
                    if let first = report.sampledCurve.first {
                        var exactPath = Path()
                        exactPath.move(to: pointFor(time: first.time, value: first.position))
                        for sample in report.sampledCurve.dropFirst() where sample.time <= plotHorizon {
                            exactPath.addLine(to: pointFor(time: sample.time, value: sample.position))
                        }
                        context.stroke(
                            exactPath,
                            with: .color(theme.primary.swiftUIColor),
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                        )
                    }

                    // RK4 curve with quadratic drag
                    if let firstRK = rk4Samples.first {
                        var rkPath = Path()
                        rkPath.move(to: pointFor(time: firstRK.time, value: firstRK.position))
                        for sample in rk4Samples.dropFirst().enumerated() where sample.offset.isMultiple(of: 2) {
                            rkPath.addLine(to: pointFor(time: sample.element.time, value: sample.element.position))
                        }
                        context.stroke(
                            rkPath,
                            with: .color(theme.danger.swiftUIColor.opacity(0.82)),
                            style: StrokeStyle(lineWidth: 1.6, dash: [6, 3])
                        )
                    }
                }
                .frame(height: 190)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator.opacity(0.40), lineWidth: 1)
                }

                // Live spring puck track
                ZStack(alignment: isLivePreviewExpanded ? .trailing : .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 36)
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(isLivePreviewExpanded ? "Equilibrium 1.0" : "Origin 0.0")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(theme.primary.swiftUIColor, in: Capsule())
                    .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. Cubic Bezier & Multi-Track Keyframe Timeline

    private var bezierAndMultiTrackCard: some View {
        let timeline = demoTimeline
        let clampedTime = min(timeline.duration, max(0, timelineScrubSeconds))
        let snap = timeline.evaluateSnapshot(at: clampedTime)
        let scaleVal = snap["scale"] ?? 1.0
        let opacityVal = snap["opacity"] ?? 1.0
        let offsetYVal = snap["offsetY"] ?? 0.0

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Cubic-Bezier Solver & Multi-Track Keyframe Timeline",
                        subtitle: bezierPreset.curve.swiftUITimingCurveString
                    )
                    Spacer()
                    Picker("Bezier Curve", selection: $bezierPreset) {
                        ForEach(BezierPresetChoice.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .frame(width: 190)
                    .controlSize(.small)
                }

                sliderRow("Timeline Scrubber", value: $timelineScrubSeconds, range: 0.0...timeline.duration, unit: "s")

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(timeline.tracks) { track in
                            let currentVal = track.evaluate(at: clampedTime)
                            HStack {
                                Text(track.propertyName)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .frame(width: 72, alignment: .leading)
                                Text("\(track.keyframes.count) keys")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.3f", currentVal))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(theme.primary.swiftUIColor)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 6) {
                        Label("Keyframe Stage", systemImage: "cube.transparent.fill")
                            .font(.callout.weight(.bold))
                        Text(String(format: "t = %.2fs · scale %.2f", clampedTime, scaleVal))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(width: 210, height: 108)
                    .background(
                        theme.primary.swiftUIColor.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium), style: .continuous)
                            .stroke(theme.primary.swiftUIColor.opacity(0.45), lineWidth: 1.2)
                    }
                    .scaleEffect(scaleVal)
                    .opacity(opacityVal)
                    .offset(y: offsetYVal * 0.45)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 4. SwiftUI Animation Code Synthesis

    private var codeSynthesisCard: some View {
        let generatedCode: String = {
            switch selectedExportKind {
            case .phaseAnimator:
                return AnimationTimeline.synthesizePhaseAnimatorCode(
                    structName: "LiquidGlassPhaseBanner",
                    spring: activeSpring
                )
            case .keyframeAnimator:
                return demoTimeline.synthesizeKeyframeAnimatorCode(structName: "TimelineAnimatedCard")
            case .springModifier:
                return AnimationTimeline.synthesizeSpringModifier(
                    parameters: activeSpring,
                    triggerIdentifier: "isExpanded"
                )
            }
        }()

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(
                        "Live SwiftUI Motion Code Synthesizer",
                        subtitle: "Export PhaseAnimator, KeyframeAnimator, or calibrated Spring modifiers directly to your workspace."
                    )
                    Spacer()
                    Picker("Export Target", selection: $selectedExportKind) {
                        ForEach(AnimationCodeExportKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)

                    Button {
                        viewModel.aiOverriddenCode[viewModel.selection] = generatedCode
                        viewModel.rightInspectorTab = .code
                        viewModel.codePreviewMode = .swiftUI
                        viewModel.statusMessage = "Loaded \(selectedExportKind.rawValue) SwiftUI code into inspector"
                    } label: {
                        Label("Send to Inspector", systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                CodeBlockView(text: generatedCode)
                    .frame(minHeight: 175, maxHeight: 250)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func springPresetButton(_ label: String, preset: SpringParameters) -> some View {
        Button(label) {
            mass = preset.mass
            stiffness = preset.stiffness
            damping = preset.damping
            initialVelocity = preset.initialVelocity
            perceptualDuration = preset.perceptualDuration
            perceptualBounce = preset.perceptualBounce
            viewModel.statusMessage = "Loaded '\(label)' spring preset"
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.medium))
                .frame(width: 155, alignment: .leading)
            Slider(value: value, in: range)
                .tint(theme.primary.swiftUIColor)
            Text("\(String(format: "%.2f", value.wrappedValue))\(unit)")
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .frame(width: 68, alignment: .trailing)
        }
    }

    private func physicsStatTile(_ title: String, _ value: String) -> some View {
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
