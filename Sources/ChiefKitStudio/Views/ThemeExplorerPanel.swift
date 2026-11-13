#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct ThemeExplorerPanel: View {
    @ObservedObject var viewModel: PlaygroundViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                presetsSection
                wcagContrastSection
                liquidGlassSection
                colorsSection
                geometrySection
                exportThemeSection
            }
            .padding(14)
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme Presets")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 6)], spacing: 6) {
                ForEach(StudioThemePreset.allCases) { preset in
                    let isSelected = viewModel.activeThemePreset == preset
                    Button {
                        viewModel.applyThemePreset(preset)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(preset.tokens.primary.swiftUIColor)
                                .frame(width: 10, height: 10)
                            Text(preset.rawValue)
                                .font(.caption.weight(isSelected ? .bold : .medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(
                            isSelected
                                ? viewModel.themeTokens.primary.swiftUIColor.opacity(0.16)
                                : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var wcagContrastSection: some View {
        let report = viewModel.themeTokens.contrastReport
        let passes = report.primaryOnSurfaceLevel.passesAA

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("WCAG 2.1 Contrast Audit", systemImage: passes ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(passes ? viewModel.themeTokens.success.swiftUIColor : viewModel.themeTokens.warning.swiftUIColor)
                Spacer()
                if !passes {
                    Button("Auto-Fix AA") {
                        viewModel.autoFixThemeContrast()
                    }
                    .font(.caption2.weight(.semibold))
                    .controlSize(.mini)
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.themeTokens.primary.swiftUIColor)
                }
            }

            contrastRow(
                label: "Primary on Surface",
                ratio: report.primaryOnSurfaceRatio,
                level: report.primaryOnSurfaceLevel
            )
            contrastRow(
                label: "White on Primary CTA",
                ratio: report.whiteOnPrimaryRatio,
                level: report.whiteOnPrimaryLevel
            )
            contrastRow(
                label: "Primary on Dark",
                ratio: report.primaryOnDarkRatio,
                level: report.primaryOnDarkLevel
            )
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func contrastRow(label: String, ratio: Double, level: WCAGComplianceLevel) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.2f:1", ratio))
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            Text(level.passesAA ? "AA" : "Low")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(level.passesAA ? .green : .orange)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background((level.passesAA ? Color.green : Color.orange).opacity(0.14), in: Capsule())
        }
    }

    private var liquidGlassSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Liquid Glass Engine", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                Spacer()
                Toggle("", isOn: $viewModel.themeTokens.isLiquidGlassEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if viewModel.themeTokens.isLiquidGlassEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Frost Wash: \(Int((viewModel.themeTokens.glassFrost * 100).rounded()))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.themeTokens.glassFrost, in: 0.15...0.95)
                        .tint(viewModel.themeTokens.primary.swiftUIColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Specular Rim: \(Int((viewModel.themeTokens.specularRim * 100).rounded()))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.themeTokens.specularRim, in: 0.0...1.0)
                        .tint(viewModel.themeTokens.primary.swiftUIColor)
                }
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Semantic Color Tokens")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            colorTokenRow("Primary Accent", rgba: $viewModel.themeTokens.primary)
            colorTokenRow("Secondary", rgba: $viewModel.themeTokens.secondary)
            colorTokenRow("Success", rgba: $viewModel.themeTokens.success)
            colorTokenRow("Warning", rgba: $viewModel.themeTokens.warning)
            colorTokenRow("Danger", rgba: $viewModel.themeTokens.danger)
            colorTokenRow("Canvas Surface", rgba: $viewModel.themeTokens.surface)
        }
    }

    private func colorTokenRow(_ label: String, rgba: Binding<RGBAColor>) -> some View {
        HStack {
            ColorPicker(
                label,
                selection: Binding(
                    get: { rgba.wrappedValue.swiftUIColor },
                    set: { rgba.wrappedValue = RGBAColor.from($0) }
                ),
                supportsOpacity: false
            )
            .font(.caption)

            Spacer()

            Text(rgba.wrappedValue.hexString)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private var geometrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spacing & Radius Scale")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Spacing Multiplier: \(String(format: "%.2fx", viewModel.themeTokens.spacingScale)) (\(Int(viewModel.themeTokens.spacingMD))pt md)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: $viewModel.themeTokens.spacingScale, in: 0.75...1.45, step: 0.05)
                    .tint(viewModel.themeTokens.primary.swiftUIColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Small Radius: \(Int(viewModel.themeTokens.radiusSmall.rounded())) pt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: $viewModel.themeTokens.radiusSmall, in: 0...18, step: 1)
                    .tint(viewModel.themeTokens.primary.swiftUIColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Medium Surface Radius: \(Int(viewModel.themeTokens.radiusMedium.rounded())) pt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: $viewModel.themeTokens.radiusMedium, in: 0...28, step: 1)
                    .tint(viewModel.themeTokens.primary.swiftUIColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Large Hero Radius: \(Int(viewModel.themeTokens.radiusLarge.rounded())) pt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: $viewModel.themeTokens.radiusLarge, in: 4...36, step: 1)
                    .tint(viewModel.themeTokens.primary.swiftUIColor)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var exportThemeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Format", selection: $viewModel.tokenExportFormat) {
                ForEach(TokenExportFormat.allCases) { fmt in
                    Text(fmt.rawValue).tag(fmt)
                }
            }
            .controlSize(.small)

            HStack(spacing: 8) {
                Button {
                    let snippet = viewModel.themeTokens.exportedCode(in: viewModel.tokenExportFormat)
                    ExportService.copyToClipboard(snippet)
                    viewModel.statusMessage = "Copied \(viewModel.tokenExportFormat.rawValue) tokens"
                } label: {
                    Label("Copy \(viewModel.tokenExportFormat.fileExtension.uppercased()) Tokens", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.themeTokens.primary.swiftUIColor)

                Button {
                    viewModel.applyThemePreset(.chiefKitBlue)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset tokens to default")
            }
        }
    }
}
#endif
