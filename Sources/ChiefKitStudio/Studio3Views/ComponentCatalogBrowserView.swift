#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitDesignSystem
import ChiefKitStudioCore
import SwiftUI

struct ComponentCatalogBrowserView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    @State private var searchQuery = ""
    @State private var selectedCategory: SwiftBlockCategory?
    @State private var liquidGlassOnly = false
    @State private var selectedBlockID: SwiftBlockID = .virtualCardGlassView
    @State private var selectedVariant = "glass"
    @State private var selectedInteractiveState: SwiftBlockInteractiveState = .idle
    @State private var selectedTokenTarget: DesignTokenTarget = .swiftUITheme

    private var matchingSpecs: [SwiftBlockSpec] {
        SwiftBlockCatalog.search(
            query: searchQuery,
            category: selectedCategory,
            liquidGlassOnly: liquidGlassOnly
        )
    }

    private var activeSpec: SwiftBlockSpec {
        SwiftBlockCatalog.spec(for: selectedBlockID)
    }

    var body: some View {
        let audit = SwiftBlockCatalog.auditCatalog(theme: theme)

        VStack(alignment: .leading, spacing: 16) {
            catalogFilterAndGridCard(audit: audit)
            interactiveSpecInspectorCard(spec: activeSpec)
            perceptualColorScienceCard
            multiTargetTokenCompilerCard
        }
        .onChange(of: selectedBlockID) { newID in
            let nextSpec = SwiftBlockCatalog.spec(for: newID)
            if !nextSpec.variants.contains(selectedVariant) {
                selectedVariant = nextSpec.defaultVariant
            }
            if !nextSpec.supportedStates.contains(selectedInteractiveState) {
                selectedInteractiveState = .idle
            }
        }
    }

    // MARK: - 1. 64-Component Searchable Browser

    private func catalogFilterAndGridCard(audit: SwiftBlockCatalogAuditReport) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "SwiftBlocks 3.0 Component Catalog (\(audit.totalComponentCount) Components)",
                        subtitle: "Browse 8 categories of tokenized, AX5-compliant, Liquid Glass-ready SwiftUI components."
                    )
                    Spacer()
                    PillLabel(
                        title: "\(audit.liquidGlassCapableCount)/64 Glass · Lc \(String(format: "%.0f", audit.primarySurfaceAPCALc))",
                        systemImage: "square.grid.3x3.fill"
                    )
                }

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search 64 SwiftBlocks by title, prop, or keyword…", text: $searchQuery)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.separator.opacity(0.45), lineWidth: 1)
                    }

                    Toggle("Liquid Glass Only", isOn: $liquidGlassOnly)
                        .toggleStyle(.switch)
                        .font(.caption)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        categoryFilterPill(label: "All (64)", symbol: "square.grid.2x2", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(SwiftBlockCategory.allCases) { category in
                            categoryFilterPill(
                                label: "\(category.rawValue) (8)",
                                symbol: category.sfSymbol,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], spacing: 8) {
                        ForEach(matchingSpecs) { spec in
                            let isCurrent = spec.id == selectedBlockID
                            Button {
                                selectedBlockID = spec.id
                                viewModel.statusMessage = "Inspecting \(spec.id.structName) (\(spec.category.rawValue))"
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: spec.sfSymbol)
                                        .foregroundStyle(isCurrent ? .white : theme.primary.swiftUIColor)
                                        .frame(width: 18)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(spec.title)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(isCurrent ? .white : .primary)
                                            .lineLimit(1)
                                        Text(spec.id.structName)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(isCurrent ? .white.opacity(0.84) : .secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(9)
                                .background(
                                    isCurrent ? theme.primary.swiftUIColor : Color.secondary.opacity(0.09),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 215)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 2. Interactive Component State, Props & Code Synthesizer

    private func interactiveSpecInspectorCard(spec: SwiftBlockSpec) -> some View {
        let resolvedVariant = spec.variants.contains(selectedVariant) ? selectedVariant : spec.defaultVariant
        let synthesized = SwiftBlockCatalog.synthesizeCode(
            for: spec.id,
            theme: theme,
            variant: resolvedVariant,
            state: selectedInteractiveState
        )

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Label(spec.title, systemImage: spec.sfSymbol)
                                .font(.title3.weight(.bold))
                            Text(spec.id.structName)
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(theme.primary.swiftUIColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(theme.primary.swiftUIColor)
                        }
                        Text(spec.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        viewModel.aiOverriddenCode[viewModel.selection] = synthesized
                        viewModel.rightInspectorTab = .code
                        viewModel.codePreviewMode = .swiftUI
                        viewModel.statusMessage = "Loaded \(spec.id.structName) (\(resolvedVariant), \(selectedInteractiveState.rawValue)) into Live Code"
                    } label: {
                        Label("Load into Inspector", systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                HStack(spacing: 12) {
                    Picker("Variant", selection: $selectedVariant) {
                        ForEach(spec.variants, id: \.self) { variant in
                            Text(variant.capitalized).tag(variant)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 270)

                    Picker("Interactive State", selection: $selectedInteractiveState) {
                        ForEach(spec.supportedStates) { state in
                            Text(state.displayLabel).tag(state)
                        }
                    }
                    .frame(width: 210)
                    .controlSize(.small)

                    Spacer()
                }

                // Live Interactive State Preview Banner
                HStack(spacing: 14) {
                    Image(systemName: spec.sfSymbol)
                        .font(.title2)
                        .foregroundStyle(stateAccentColor(selectedInteractiveState))
                        .frame(width: 42, height: 42)
                        .background(stateAccentColor(selectedInteractiveState).opacity(0.14), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(spec.title) — \(resolvedVariant.uppercased()) · \(selectedInteractiveState.displayLabel)")
                            .font(.subheadline.weight(.semibold))
                        Text("VoiceOver Role: \(spec.accessibility.voiceOverRole) · Min APCA Lc \(Int(spec.accessibility.minimumAPCALc)) · AX5 \(spec.accessibility.supportsDynamicTypeAX5 ? "Ready" : "Standard")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedInteractiveState == .loading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(12)
                .opacity(selectedInteractiveState == .disabled ? 0.48 : 1.0)
                .scaleEffect(selectedInteractiveState == .pressed ? 0.985 : 1.0)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium)))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium))
                        .stroke(
                            selectedInteractiveState == .focused || selectedInteractiveState == .error
                                ? stateAccentColor(selectedInteractiveState)
                                : Color.secondary.opacity(0.22),
                            lineWidth: selectedInteractiveState == .focused ? 2.0 : 1.0
                        )
                }

                if !spec.props.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Typed Component Props (\(spec.props.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(spec.props) { prop in
                            HStack(spacing: 8) {
                                Text(prop.name)
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                Text(prop.kind.rawValue)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(theme.primary.swiftUIColor)
                                Text("= \(prop.defaultValue)")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(prop.summary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(9)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                CodeBlockView(text: synthesized)
                    .frame(minHeight: 175, maxHeight: 245)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. OKLCH 50–950 Tonal Scale, APCA Contrast & 7-Mode CVD Simulator

    private var perceptualColorScienceCard: some View {
        let ramp = theme.primary.tonalScale(named: "primary")
        let apca = theme.primary.apcaEvaluation(against: theme.surface)
        let safetyReport = PerceptualColorScience.auditPaletteDistinguishability(
            colors: [theme.primary, theme.success, theme.warning, theme.danger]
        )

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "OKLCH Perceptual Tonal Scale, APCA Lc & 7-Mode Color Blindness Lab",
                        subtitle: "Gamut-mapped sRGB/OKLCH 50–950 ramp + Brettel/Viénot dichromacy & ΔE2000 distinguishability."
                    )
                    Spacer()
                    PillLabel(
                        title: String(format: "APCA Lc %.1f · WCAG %.2f:1", apca.magnitudeLc, apca.wcag2Ratio),
                        systemImage: apca.passesContentText ? "eye.fill" : "exclamationmark.triangle"
                    )
                }

                HStack(spacing: 4) {
                    ForEach(ramp.swatches) { swatch in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(swatch.srgb.swiftUIColor)
                                .frame(height: 38)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(.black.opacity(0.08), lineWidth: 0.6)
                                }
                            Text("\(swatch.stop.rawValue)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            Text(swatch.srgb.hexString)
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                HStack {
                    Text("7-Condition Color Vision Deficiency Simulation (Primary Accent)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(
                        safetyReport.isUniversalSafe
                            ? String(format: "Status Palette Safe (min ΔE00 %.1f)", safetyReport.minimumDeltaEAcrossAllConditions)
                            : "\(safetyReport.confusablePairs.count) Confusable Status Pair(s)"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(safetyReport.isUniversalSafe ? theme.success.swiftUIColor : theme.warning.swiftUIColor)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
                    ForEach(ColorBlindnessKind.allCases) { condition in
                        let sim = theme.primary.simulated(for: condition)
                        HStack(spacing: 8) {
                            Circle()
                                .fill(sim.swiftUIColor)
                                .frame(width: 20, height: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(condition.rawValue.components(separatedBy: " ").first ?? condition.rawValue)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                Text(sim.hexString)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(7)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 4. 8-Target Design Token Compiler

    private var multiTargetTokenCompilerCard: some View {
        let bundle = DesignTokenCompiler.compileAllTargets(tokens: theme, namespace: "ChiefKit")
        let selectedFile = bundle.file(for: selectedTokenTarget) ?? bundle.files.first

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(
                        "8-Target Design Token Compiler",
                        subtitle: "Compile Light, Dark & High-Contrast semantic tokens for Apple, Web, Tailwind v4 & Jetpack Compose."
                    )
                    Spacer()
                    Picker("Target", selection: $selectedTokenTarget) {
                        ForEach(DesignTokenTarget.allCases) { target in
                            Text(target.displayTitle).tag(target)
                        }
                    }
                    .frame(width: 235)
                    .controlSize(.small)
                }

                if let file = selectedFile {
                    HStack(spacing: 10) {
                        Text(file.filename)
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        Text("\(file.exportedTokenCount) tokens · \(file.lineCount) lines · SHA \(file.checksumHex.prefix(12))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Export \(file.filename)…") {
                            if let url = try? ExportService.export(
                                text: file.sourceCode,
                                suggestedFileName: file.filename,
                                panelTitle: "Export \(file.target.displayTitle) Design Tokens"
                            ) {
                                viewModel.statusMessage = "Exported \(url.lastPathComponent)"
                            }
                        }
                        .controlSize(.small)
                    }

                    CodeBlockView(text: file.sourceCode)
                        .frame(minHeight: 165, maxHeight: 235)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func categoryFilterPill(
        label: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .font(.caption2.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    isSelected ? theme.primary.swiftUIColor : Color.secondary.opacity(0.11),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func stateAccentColor(_ state: SwiftBlockInteractiveState) -> Color {
        switch state {
        case .error: theme.danger.swiftUIColor
        case .focused, .hovered: theme.primary.swiftUIColor
        case .pressed: theme.secondary.swiftUIColor
        case .loading: theme.warning.swiftUIColor
        case .idle, .disabled: theme.primary.swiftUIColor
        }
    }
}
#endif
