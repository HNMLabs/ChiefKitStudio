#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - On-Device AI, Media & Spatial Component Specs + Synthesizers (16 Components)

internal enum ComponentSynthesizerAIAndSpatial {

    static let specs: [SwiftBlockSpec] = [
        // MARK: 8 On-Device AI & Agent Specs
        SwiftBlockSpec(
            id: .streamingPromptBar,
            title: "Streaming Prompt Bar",
            summary: "Multimodal on-device prompt composer with context attachment pill, stop/send button, and token counter.",
            sfSymbol: "apple.intelligence",
            vectorIcon: .sparklesAI,
            props: [
                SwiftBlockPropSpec(name: "prompt", kind: .binding, defaultValue: "\"\"", summary: "User prompt draft", isRequired: true),
                SwiftBlockPropSpec(name: "isStreaming", kind: .bool, defaultValue: "false", summary: "Active generation flag")
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 460, height: 92),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "textField", minimumAPCALc: 75, keyboardNavigationShortcut: "⌘↩"),
            searchKeywords: ["ai", "prompt", "chat", "streaming", "llm"]
        ),
        SwiftBlockSpec(
            id: .tokenThroughputGauge,
            title: "Token Throughput Gauge",
            summary: "Neural Engine telemetry meter displaying tok/s decode speed, TTFT latency, and thermal state.",
            sfSymbol: "bolt.horizontal.circle.fill",
            vectorIcon: .neuralChip,
            props: [
                SwiftBlockPropSpec(name: "tokensPerSecond", kind: .double, defaultValue: "94.6", summary: "Decode rate tok/s", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 320, height: 118),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "levelIndicator", minimumAPCALc: 70),
            searchKeywords: ["throughput", "tokens", "ane", "benchmark", "ai"]
        ),
        SwiftBlockSpec(
            id: .groundingCitationRow,
            title: "Grounding Citation Row",
            summary: "Source attribution pill linking synthesized answers back to verified Swift file & line spans.",
            sfSymbol: "quote.opening",
            vectorIcon: .tokenCompiler,
            props: [
                SwiftBlockPropSpec(name: "sourceFile", kind: .string, defaultValue: "\"PerceptualColorScience.swift:412\"", summary: "Cited symbol/line", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 400, height: 68),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "link", minimumAPCALc: 75),
            searchKeywords: ["citation", "rag", "grounding", "source"]
        ),
        SwiftBlockSpec(
            id: .localModelPickerCard,
            title: "Local Model Picker Card",
            summary: "Quantized on-device model selector displaying VRAM footprint, quantization bits, and offline badge.",
            sfSymbol: "cpu.fill",
            vectorIcon: .neuralChip,
            props: [
                SwiftBlockPropSpec(name: "selectedModel", kind: .binding, defaultValue: "\"Foundation-3B-4bit\"", summary: "Active local model", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 164),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "radioGroup", minimumAPCALc: 75),
            searchKeywords: ["model", "local", "mlx", "quantized", "offline"]
        ),
        SwiftBlockSpec(
            id: .aiInlineDiffCard,
            title: "AI Inline Diff Card",
            summary: "Reviewable code suggestion card with Accept / Reject actions and unified token diff preview.",
            sfSymbol: "wand.and.stars",
            vectorIcon: .unifiedDiff,
            props: [
                SwiftBlockPropSpec(name: "onAccept", kind: .actionClosure, defaultValue: "{ }", summary: "Apply patch callback", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 440, height: 168),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "group", minimumAPCALc: 75, keyboardNavigationShortcut: "⌘Y"),
            searchKeywords: ["refactor", "inline", "diff", "suggestion"]
        ),
        SwiftBlockSpec(
            id: .voiceSpectrogramBar,
            title: "Voice Spectrogram Bar",
            summary: "Real-time multi-band microphone level visualizer for local Whisper / Speech dictation.",
            sfSymbol: "waveform.badge.mic",
            vectorIcon: .microphonePulse,
            props: [
                SwiftBlockPropSpec(name: "isRecording", kind: .binding, defaultValue: "true", summary: "Capture active state", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 76),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "status", minimumAPCALc: 70),
            searchKeywords: ["voice", "spectrogram", "audio", "dictation", "mic"]
        ),
        SwiftBlockSpec(
            id: .agentToolTraceCard,
            title: "Agent Tool Trace Card",
            summary: "Collapsible step trace displaying autonomous tool invocation arguments, duration, and exit status.",
            sfSymbol: "terminal.fill",
            vectorIcon: .terminalPrompt,
            props: [
                SwiftBlockPropSpec(name: "toolName", kind: .string, defaultValue: "\"DesignTokenCompiler.compileAll\"", summary: "Executed tool", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 420, height: 128),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "disclosureGroup", minimumAPCALc: 75),
            searchKeywords: ["agent", "tool", "trace", "reasoning"]
        ),
        SwiftBlockSpec(
            id: .contextWindowRing,
            title: "Context Window Ring",
            summary: "Circular KV-cache token budget indicator showing system, conversation, and free context slices.",
            sfSymbol: "circle.hexagongrid.fill",
            vectorIcon: .chartDonutGauge,
            props: [
                SwiftBlockPropSpec(name: "usedTokens", kind: .int, defaultValue: "18400", summary: "Occupied KV tokens", isRequired: true),
                SwiftBlockPropSpec(name: "maxTokens", kind: .int, defaultValue: "32768", summary: "Context window cap", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 300, height: 112),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "progressIndicator", minimumAPCALc: 70),
            searchKeywords: ["context", "kv", "tokens", "memory"]
        ),

        // MARK: 8 Spatial, Media & System Specs
        SwiftBlockSpec(
            id: .visionGlassOrnament,
            title: "Vision Glass Ornament",
            summary: "visionOS spatial window bottom ornament with 60pt gaze-friendly targets and specular glass rim.",
            sfSymbol: "visionpro",
            vectorIcon: .spatialVisionGoggles,
            props: [
                SwiftBlockPropSpec(name: "selectedMode", kind: .binding, defaultValue: "0", summary: "Active spatial tab", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 76),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "toolbar", minimumAPCALc: 65),
            tokenCompliance: SwiftBlockTokenCompliance(supportsVisionOSDepthHover: true, recommendedSpring: .smooth),
            searchKeywords: ["visionos", "ornament", "spatial", "gaze"]
        ),
        SwiftBlockSpec(
            id: .spatialCardStack,
            title: "Spatial Card Stack",
            summary: "3D z-depth layered card deck with spring peel interaction and perspective scale falloff.",
            sfSymbol: "square.3.layers.3d",
            vectorIcon: .depthLayers3D,
            props: [
                SwiftBlockPropSpec(name: "topIndex", kind: .binding, defaultValue: "0", summary: "Front card index", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 340, height: 184),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "group", minimumAPCALc: 70),
            tokenCompliance: SwiftBlockTokenCompliance(supportsVisionOSDepthHover: true, recommendedSpring: .bouncy),
            searchKeywords: ["spatial", "stack", "3d", "deck", "cards"]
        ),
        SwiftBlockSpec(
            id: .parallaxHeroSurface,
            title: "Parallax Hero Surface",
            summary: "Interactive pointer/tilt-reactive showcase banner with multi-plane specular lighting.",
            sfSymbol: "sparkles.tv.fill",
            vectorIcon: .liquidGlassCube,
            props: [
                SwiftBlockPropSpec(name: "headline", kind: .string, defaultValue: "\"ChiefKit Studio 3.0\"", summary: "Hero title", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 460, height: 188),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "banner", minimumAPCALc: 75),
            searchKeywords: ["parallax", "hero", "tilt", "showcase"]
        ),
        SwiftBlockSpec(
            id: .miniWaveformPlayer,
            title: "Mini Waveform Player",
            summary: "Compact audio preview bar with play/pause toggle, discrete amplitude bars, and timecode readout.",
            sfSymbol: "waveform",
            vectorIcon: .waveformAudio,
            props: [
                SwiftBlockPropSpec(name: "isPlaying", kind: .binding, defaultValue: "false", summary: "Playback state", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 78),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "audio", minimumAPCALc: 70, keyboardNavigationShortcut: "Space"),
            searchKeywords: ["audio", "player", "waveform", "media"]
        ),
        SwiftBlockSpec(
            id: .chapterVideoScrubber,
            title: "Chapter Video Scrubber",
            summary: "Segmented timeline scrubber marking tutorial chapters, current playhead, and playback rate badge.",
            sfSymbol: "film.stack",
            vectorIcon: .videoChapterPlay,
            props: [
                SwiftBlockPropSpec(name: "progress", kind: .binding, defaultValue: "0.42", summary: "Normalized scrubhead", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 440, height: 96),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "slider", minimumAPCALc: 70),
            searchKeywords: ["video", "scrubber", "chapters", "player"]
        ),
        SwiftBlockSpec(
            id: .toastNotificationStack,
            title: "Toast Notification Stack",
            summary: "Non-blocking floating alert banner with semantic status icon, undo action, and auto-dismiss bar.",
            sfSymbol: "bell.badge.fill",
            vectorIcon: .bellNotification,
            props: [
                SwiftBlockPropSpec(name: "message", kind: .string, defaultValue: "\"Exported 8 token files\"", summary: "Toast copy", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 74),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "alert", minimumAPCALc: 75),
            searchKeywords: ["toast", "snackbar", "notification", "alert"]
        ),
        SwiftBlockSpec(
            id: .systemPermissionCard,
            title: "System Permission Card",
            summary: "Pre-prompt privacy explainer card detailing local-only microphone, camera, or folder access.",
            sfSymbol: "hand.raised.fill",
            vectorIcon: .passkeyShield,
            props: [
                SwiftBlockPropSpec(name: "capability", kind: .string, defaultValue: "\"Local Project Folder\"", summary: "Requested scope", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 360, height: 156),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "dialog", minimumAPCALc: 75),
            searchKeywords: ["permission", "privacy", "onboarding", "access"]
        ),
        SwiftBlockSpec(
            id: .actionableEmptyState,
            title: "Actionable Empty State",
            summary: "Zero-data placeholder card with vector icon badge, concise guidance, and primary creation CTA.",
            sfSymbol: "tray",
            vectorIcon: .artboardDevices,
            props: [
                SwiftBlockPropSpec(name: "actionTitle", kind: .string, defaultValue: "\"Create First Artboard\"", summary: "CTA button title", isRequired: true)
            ],
            defaultFrame: CanvasFrame(x: 24, y: 24, width: 380, height: 184),
            accessibility: SwiftBlockAccessibilityMetadata(voiceOverRole: "group", minimumAPCALc: 70),
            searchKeywords: ["empty", "placeholder", "zero", "starter"]
        )
    ]

    // MARK: - Component Code Synthesis

    static func synthesize(context ctx: SwiftBlockSynthesisContext) -> String {
        let accent = ctx.accentSwiftUI
        let okColor = ctx.theme.success.swiftInitializer

        switch ctx.id {
        case .streamingPromptBar:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var prompt: String = \"\"\n    @State private var isGenerating = false",
                bodyCore: """
                        HStack(spacing: 8) {
                            Label("CanvasSelection.swift", systemImage: "paperclip")
                                .font(.caption2.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(\(accent).opacity(0.14), in: Capsule())
                            Spacer()
                            Text("100% On-Device").font(.caption2).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 10) {
                            TextField("Ask ChiefKit Local AI to refactor or synthesize blocks…", text: $prompt)
                                .textFieldStyle(.plain)
                            Button {
                                isGenerating.toggle()
                            } label: {
                                Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(\(accent))
                            }
                            .buttonStyle(.plain)
                        }
                """
            )

        case .tokenThroughputGauge:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack {
                            Label("Apple Neural Engine", systemImage: "cpu.fill").font(.caption.weight(.semibold))
                            Spacer()
                            Text("NOMINAL").font(.caption2.monospaced().weight(.bold)).foregroundStyle(\(okColor))
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("94.6").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(\(accent))
                            Text("tok/s · TTFT 42ms").font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                """
            )

        case .groundingCitationRow:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack(spacing: 10) {
                            Text("[1]")
                                .font(.caption.monospaced().weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(\(accent).opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                                .foregroundStyle(\(accent))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PerceptualColorScience.swift · L412–L468").font(.caption.monospaced().weight(.semibold))
                                Text("APCA W3 0.0.98G-4g polarity & soft-black clamp").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                """
            )

        case .localModelPickerCard:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var selectedModel = \"ChiefKit-Coder-3B-4bit\"",
                bodyCore: """
                        HStack {
                            Text("On-Device Inference Model").font(.subheadline.weight(.semibold))
                            Spacer()
                            Label("Offline Ready", systemImage: "checkmark.circle.fill").font(.caption2).foregroundStyle(\(okColor))
                        }
                        ForEach([("ChiefKit-Coder-3B-4bit", "1.9 GB VRAM"), ("Apple-Foundation-3B", "System Shared")], id: \\.0) { model, mem in
                            Button { selectedModel = model } label: {
                                HStack {
                                    Image(systemName: selectedModel == model ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(\(accent))
                                    Text(model).font(.caption.monospaced())
                                    Spacer()
                                    Text(mem).font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                        }
                """
            )

        case .aiInlineDiffCard:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack {
                            Label("Suggested Accessibility Fix", systemImage: "wand.and.stars").font(.caption.weight(.bold)).foregroundStyle(\(accent))
                            Spacer()
                            HStack(spacing: 6) {
                                Button("Reject") { }.font(.caption).buttonStyle(.plain)
                                Button("Apply ⌘Y") { }
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(\(accent), in: Capsule())
                                    .foregroundStyle(.white)
                                    .buttonStyle(.plain)
                            }
                        }
                        Text("+ .accessibilityLabel(\"Primary Checkout Action\")")
                            .font(.caption.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(\(okColor).opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                """
            )

        case .voiceSpectrogramBar:
            return ctx.wrapComponentView(
                stateProperties: "    private let bins: [CGFloat] = [10, 22, 16, 30, 26, 14, 28, 18, 24, 12]",
                bodyCore: """
                        HStack(spacing: 12) {
                            Image(systemName: "mic.fill").foregroundStyle(\(accent))
                            HStack(spacing: 4) {
                                ForEach(Array(bins.enumerated()), id: \\.offset) { _, amp in
                                    Capsule().fill(\(accent)).frame(width: 4, height: amp)
                                }
                            }
                            Spacer()
                            Text("00:08 · Local Speech").font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                """
            )

        case .agentToolTraceCard:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var showDetails = true",
                bodyCore: """
                        Button { showDetails.toggle() } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(\(okColor))
                                Text("DesignTokenCompiler.compileAllTargets").font(.caption.monospaced().weight(.semibold))
                                Spacer()
                                Text("12 ms").font(.caption2.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        if showDetails {
                            Text("Emitted 8 artifacts (SwiftUI, NSColor, UIColor, DTCG, OKLCH CSS, Tailwind v4, Compose, xcassets)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                """
            )

        case .contextWindowRing:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                                Circle().trim(from: 0, to: 0.56).stroke(\(accent), style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                            }
                            .frame(width: 38, height: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Context Window · 56%").font(.subheadline.weight(.semibold))
                                Text("18,400 / 32,768 tokens cached").font(.caption2.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                """
            )

        case .visionGlassOrnament:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var selectedIndex = 0",
                bodyCore: """
                        HStack(spacing: 16) {
                            ForEach(Array(["Canvas", "3D Layers", "Inspector"].enumerated()), id: \\.offset) { idx, title in
                                Button {
                                    selectedIndex = idx
                                } label: {
                                    Text(title)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(selectedIndex == idx ? \(accent) : .clear, in: Capsule())
                                        .foregroundStyle(selectedIndex == idx ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                """
            )

        case .spatialCardStack:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var activeDeckIndex = 0",
                bodyCore: """
                        ZStack {
                            RoundedRectangle(cornerRadius: \(ctx.radSM))
                                .fill(\(accent).opacity(0.18))
                                .frame(height: 68)
                                .scaleEffect(0.92)
                                .offset(y: -12)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Spatial Layer #\\(activeDeckIndex + 1)").font(.subheadline.weight(.bold))
                                    Text("Tap to cycle z-depth card stack").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "square.3.layers.3d").foregroundStyle(\(accent))
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: \(ctx.radSM)))
                            .onTapGesture { activeDeckIndex = (activeDeckIndex + 1) % 3 }
                        }
                """
            )

        case .parallaxHeroSurface:
            return ctx.wrapComponentView(
                bodyCore: """
                        VStack(alignment: .leading, spacing: 8) {
                            Label("LIQUID GLASS 3.0", systemImage: "sparkles")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(\(accent))
                            Text("Design, Simulate & Compile Native Apple UI")
                                .font(.title3.weight(.bold))
                            Text("Perceptual OKLCH color math, RK4 spring physics, and 64 zero-lock-in SwiftBlocks.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                """
            )

        case .miniWaveformPlayer:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var isPlaying = false",
                bodyCore: """
                        HStack(spacing: 12) {
                            Button { isPlaying.toggle() } label: {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(\(accent))
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Haptic Spring Acoustic Preview").font(.caption.weight(.semibold))
                                Text("00:04 / 00:12 · 48 kHz PCM").font(.caption2.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                """
            )

        case .chapterVideoScrubber:
            return ctx.wrapComponentView(
                stateProperties: "    @State private var scrub: Double = 0.42",
                bodyCore: """
                        HStack {
                            Text("Chapter 2 · OKLCH Gamut Compression").font(.caption.weight(.semibold))
                            Spacer()
                            Text("04:18 / 10:12").font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                        Slider(value: $scrub, in: 0...1)
                            .tint(\(accent))
                """
            )

        case .toastNotificationStack:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(\(okColor))
                            Text("Compiled 8 platform token files cleanly").font(.subheadline.weight(.medium))
                            Spacer()
                            Button("Show") { }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(\(accent))
                                .buttonStyle(.plain)
                        }
                """
            )

        case .systemPermissionCard:
            return ctx.wrapComponentView(
                bodyCore: """
                        HStack(spacing: 12) {
                            Image(systemName: "folder.badge.gearshape").font(.title2).foregroundStyle(\(accent))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Workspace Directory Access").font(.subheadline.weight(.bold))
                                Text("ChiefKit writes SwiftUI and .xcassets files strictly inside your chosen folder.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        EDKButton("Grant Folder Access", variant: .primary, size: .small) { }
                """
            )

        default: // .actionableEmptyState
            return ctx.wrapComponentView(
                bodyCore: """
                        VStack(spacing: 8) {
                            Image(systemName: "square.dashed.inset.filled")
                                .font(.largeTitle)
                                .foregroundStyle(\(accent))
                            Text("No Custom Artboards Yet").font(.headline)
                            Text("Start from an iPhone 16 Pro, MacBook Pro 16\", or Vision Pro preset.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            EDKButton("Create Device Artboard", variant: .primary, size: .small) { }
                        }
                        .frame(maxWidth: .infinity)
                """
            )
        }
    }
}
