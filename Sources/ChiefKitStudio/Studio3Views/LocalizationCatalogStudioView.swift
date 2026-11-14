#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitStudioCore
import SwiftUI

struct LocalizationCatalogStudioView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @Environment(\.studioTheme) private var theme

    private enum CatalogExportViewMode: String, CaseIterable, Identifiable {
        case l10nSwiftEnum = "Typed Swift `enum L10n`"
        case xcstringsJSON = "Apple `Localizable.xcstrings` JSON"

        var id: String { rawValue }
    }

    @State private var selectedDomain: LocalizationDomainPreset? = .studioCoreUI
    @State private var catalog: StringCatalogDocument = StudioBuiltInTranslations.catalog(for: .studioCoreUI)
    @State private var selectedKey: String = ""
    @State private var activePreviewLocale: LocaleCode = .tr
    @State private var selectedDevice: DeviceVariationKind = .iphone
    @State private var pluralSampleCount: Double = 3
    @State private var selectedPseudolocMode: PseudolocMode = .accentedExpanded
    @State private var enablePseudolocPreview = false
    @State private var exportViewMode: CatalogExportViewMode = .l10nSwiftEnum
    @State private var inlineTranslationDraft = ""

    private let matrixLocales: [LocaleCode] = StudioBuiltInTranslations.starterLocales

    private var currentEntry: StringCatalogEntry? {
        if let found = catalog.entries[selectedKey] {
            return found
        }
        return catalog.sortedEntries.first
    }

    var body: some View {
        let coverages = catalog.coverageReport()
        let diagnostics = StringCatalogCompiler.validateCatalog(catalog)

        VStack(alignment: .leading, spacing: 16) {
            domainAndCoverageHeader(coverages: coverages)
            translationMatrixAndEditorCard
            rtlPluralAndPseudolocCard(diagnostics: diagnostics)
            exportArtifactCard
        }
        .onAppear {
            syncSelectedKeyAndDraft()
        }
    }

    // MARK: - 1. Domain Switcher, SwiftUI Extractor & Coverage Strip

    private func domainAndCoverageHeader(coverages: [LocaleCoverageSummary]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Apple String Catalog (`.xcstrings`), CLDR Plurals & RTL Studio",
                        subtitle: "\(catalog.entries.count) localized keys across \(catalog.targetLocales.count) locales including Turkish (TR), Japanese (JA) & Arabic (RTL)."
                    )
                    Spacer()
                    Button {
                        catalog = StringCatalogCompiler.extractAndMergeIntoCatalog(
                            swiftSource: viewModel.selectedSwiftUICode,
                            into: catalog
                        )
                        syncSelectedKeyAndDraft()
                        viewModel.statusMessage = "Extracted SwiftUI strings into '\(catalog.catalogName).xcstrings' (\(catalog.entries.count) keys)"
                    } label: {
                        Label("Extract Active SwiftUI Strings", systemImage: "text.magnifyingglass")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        domainChip(title: "Unified Master (All)", isSelected: selectedDomain == nil) {
                            selectedDomain = nil
                            catalog = StudioBuiltInTranslations.unifiedMasterCatalog()
                            syncSelectedKeyAndDraft()
                        }
                        ForEach(LocalizationDomainPreset.allCases) { domain in
                            domainChip(title: domain.title, isSelected: selectedDomain == domain) {
                                selectedDomain = domain
                                catalog = StudioBuiltInTranslations.catalog(for: domain)
                                syncSelectedKeyAndDraft()
                            }
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                    ForEach(coverages) { summary in
                        let active = summary.locale == activePreviewLocale
                        Button {
                            activePreviewLocale = summary.locale
                            syncDraftForLocale(summary.locale)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(summary.locale.bcp47Tag.uppercased())
                                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    Spacer()
                                    Text("\(summary.completionPercentage)%")
                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(summary.completionPercentage == 100 ? theme.success.swiftUIColor : theme.warning.swiftUIColor)
                                }
                                Text("\(summary.locale.nativeDisplayName) · \(summary.locale.scriptDirection.rawValue)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(8)
                            .background(
                                active ? theme.primary.swiftUIColor.opacity(0.15) : Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(active ? theme.primary.swiftUIColor : .clear, lineWidth: 1.2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 2. Multi-Locale Translation Matrix & Live Editor

    private var translationMatrixAndEditorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("String Keys & Multi-Locale Matrix")
                    .font(.subheadline.weight(.semibold))

                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(catalog.sortedEntries) { entry in
                            let isSelected = currentEntry?.key == entry.key
                            Button {
                                selectedKey = entry.key
                                syncDraftForLocale(activePreviewLocale)
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(entry.key)
                                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                            if entry.isPluralized {
                                                Text("PLURAL")
                                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1.5)
                                                    .background(theme.primary.swiftUIColor.opacity(0.15), in: Capsule())
                                            }
                                            if entry.hasDeviceVariations {
                                                Text("DEVICE")
                                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1.5)
                                                    .background(theme.secondary.swiftUIColor.opacity(0.15), in: Capsule())
                                            }
                                        }
                                        Text(catalog.resolve(key: entry.key, locale: .en, count: Int(pluralSampleCount)))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(catalog.resolve(key: entry.key, locale: activePreviewLocale, count: Int(pluralSampleCount), device: selectedDevice))
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(theme.primary.swiftUIColor)
                                        .lineLimit(1)
                                }
                                .padding(8)
                                .background(
                                    isSelected ? theme.primary.swiftUIColor.opacity(0.12) : Color.secondary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 7)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 195)

                if let entry = currentEntry {
                    HStack(spacing: 8) {
                        Text("Edit [\(activePreviewLocale.bcp47Tag)]:")
                            .font(.caption.weight(.semibold))
                        TextField("Localized translation…", text: $inlineTranslationDraft)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                        Button("Save Unit") {
                            catalog.upsertSimpleTranslation(
                                key: entry.key,
                                comment: entry.comment,
                                locale: activePreviewLocale,
                                value: inlineTranslationDraft
                            )
                            viewModel.statusMessage = "Updated '\(entry.key)' for locale \(activePreviewLocale.bcp47Tag)"
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.primary.swiftUIColor)
                        .controlSize(.small)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 3. RTL Mirroring Preview, CLDR Plural Tester & Pseudolocalization

    private func rtlPluralAndPseudolocCard(diagnostics: [LocalizationDiagnostic]) -> some View {
        let countInt = Int(pluralSampleCount)
        let activeKey = currentEntry?.key ?? catalog.sortedEntries.first?.key ?? ""
        let rawResolved = catalog.resolve(
            key: activeKey,
            locale: activePreviewLocale,
            count: countInt,
            device: selectedDevice,
            arguments: [.string("Ada"), .int(countInt)]
        )
        let renderedText = enablePseudolocPreview
            ? StringCatalogCompiler.pseudolocalize(rawResolved, mode: selectedPseudolocMode)
            : rawResolved
        let cldrForm = pluralCategory(for: countInt, locale: activePreviewLocale)

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(
                        "Live RTL/LTR Surface Preview, CLDR Plurals & Pseudolocalization",
                        subtitle: "Test bidirectional layout mirroring, plural rules, and expansion clipping bounds."
                    )
                    Spacer()
                    PillLabel(
                        title: "\(activePreviewLocale.englishName) · \(activePreviewLocale.scriptDirection.rawValue) · CLDR .\(cldrForm.rawValue)",
                        systemImage: "globe"
                    )
                }

                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Text("Plural n = \(countInt)")
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .frame(width: 92, alignment: .leading)
                        Slider(value: $pluralSampleCount, in: 0...40, step: 1)
                            .frame(width: 130)
                    }

                    Picker("Device", selection: $selectedDevice) {
                        ForEach(DeviceVariationKind.allCases) { dev in
                            Text(dev.displayTitle).tag(dev)
                        }
                    }
                    .frame(width: 170)
                    .controlSize(.small)

                    Toggle("Pseudolocalize", isOn: $enablePseudolocPreview)
                        .font(.caption)

                    if enablePseudolocPreview {
                        Picker("Mode", selection: $selectedPseudolocMode) {
                            ForEach(PseudolocMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .frame(width: 210)
                        .controlSize(.small)
                    }
                    Spacer()
                }

                // Simulated Device Card respecting LayoutDirection
                HStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.title2)
                        .foregroundStyle(theme.primary.swiftUIColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(renderedText)
                            .font(.headline)
                        Text("Key: \(activeKey) · Max Button Budget: \(selectedDevice.recommendedMaxButtonCharacters) chars (actual \(renderedText.count))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: CGFloat(theme.radiusMedium)))
                .environment(
                    \.layoutDirection,
                    activePreviewLocale.scriptDirection.isRTL ? .rightToLeft : .leftToRight
                )

                HStack(spacing: 8) {
                    Image(systemName: diagnostics.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(diagnostics.isEmpty ? theme.success.swiftUIColor : theme.warning.swiftUIColor)
                    Text(
                        diagnostics.isEmpty
                            ? "Catalog Validation Clean: 0 missing placeholders, 0 missing plural categories across \(matrixLocales.count) locales."
                            : "\(diagnostics.count) localization diagnostic(s) — first: \(diagnostics[0].message)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 4. `.xcstrings` JSON & Typed `enum L10n` Code Exporter

    private var exportArtifactCard: some View {
        let codeOutput: String = {
            switch exportViewMode {
            case .l10nSwiftEnum:
                return StringCatalogCompiler.synthesizeL10nSwiftEnum(from: catalog, enumName: "L10n")
            case .xcstringsJSON:
                return (try? catalog.encodeXCStringsJSON()) ?? "{}"
            }
        }()

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(
                        "Type-Safe Swift `L10n` & `.xcstrings` Compiler",
                        subtitle: "Eliminate stringly-typed localization bugs or export Apple Xcode 15+ String Catalogs directly."
                    )
                    Spacer()
                    Picker("Artifact", selection: $exportViewMode) {
                        ForEach(CatalogExportViewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 340)

                    Button("Export File…") {
                        let suggested = exportViewMode == .xcstringsJSON ? "\(catalog.catalogName).xcstrings" : "L10n+Generated.swift"
                        if let url = try? ExportService.export(
                            text: codeOutput,
                            suggestedFileName: suggested,
                            panelTitle: "Export Localization Artifact"
                        ) {
                            viewModel.statusMessage = "Exported \(url.lastPathComponent)"
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary.swiftUIColor)
                    .controlSize(.small)
                }

                CodeBlockView(text: codeOutput)
                    .frame(minHeight: 185, maxHeight: 260)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func syncSelectedKeyAndDraft() {
        if selectedKey.isEmpty || catalog.entries[selectedKey] == nil {
            selectedKey = catalog.sortedEntries.first?.key ?? ""
        }
        syncDraftForLocale(activePreviewLocale)
    }

    private func syncDraftForLocale(_ locale: LocaleCode) {
        guard !selectedKey.isEmpty else { return }
        inlineTranslationDraft = catalog.resolve(
            key: selectedKey,
            locale: locale,
            count: Int(pluralSampleCount),
            device: selectedDevice
        )
    }

    private func domainChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected ? theme.primary.swiftUIColor : Color.secondary.opacity(0.11),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}
#endif
