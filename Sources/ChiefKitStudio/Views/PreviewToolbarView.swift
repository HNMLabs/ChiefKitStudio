#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct PreviewToolbarView: View {
    @ObservedObject var viewModel: PlaygroundViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Appearance Picker
                    Menu {
                        ForEach(PreviewAppearance.allCases) { mode in
                            Button {
                                viewModel.previewConfig.appearance = mode
                            } label: {
                                Label(mode.rawValue, systemImage: mode.symbolName)
                            }
                        }
                    } label: {
                        Label(
                            "Appearance: \(viewModel.previewConfig.appearance.rawValue)",
                            systemImage: viewModel.previewConfig.appearance.symbolName
                        )
                        .font(.caption.weight(.medium))
                    }
                    .controlSize(.small)

                    // Viewport Preset Picker
                    Menu {
                        ForEach(PreviewViewport.allCases) { vp in
                            Button {
                                viewModel.previewConfig.viewport = vp
                            } label: {
                                Label(vp.rawValue, systemImage: vp.symbolName)
                            }
                        }
                    } label: {
                        Label(
                            viewModel.previewConfig.viewport.rawValue,
                            systemImage: viewModel.previewConfig.viewport.symbolName
                        )
                        .font(.caption.weight(.medium))
                    }
                    .controlSize(.small)

                    // Dynamic Type Scale Picker
                    Menu {
                        ForEach(PreviewDynamicType.allCases) { dt in
                            Button {
                                viewModel.previewConfig.dynamicType = dt
                            } label: {
                                Text("Dynamic Type: \(dt.rawValue)")
                            }
                        }
                    } label: {
                        Label(
                            "Type: \(viewModel.previewConfig.dynamicType.rawValue)",
                            systemImage: "textformat.size"
                        )
                        .font(.caption.weight(.medium))
                    }
                    .controlSize(.small)

                    // Accessibility X-Ray Toggle
                    Button {
                        viewModel.previewConfig.showAccessibilityOverlay.toggle()
                    } label: {
                        Label(
                            "Accessibility",
                            systemImage: viewModel.previewConfig.showAccessibilityOverlay
                                ? "figure.roll.runningpace"
                                : "figure.roll"
                        )
                        .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.previewConfig.showAccessibilityOverlay ? .indigo : nil)
                    .controlSize(.small)

                    Divider()
                        .frame(height: 16)

                    // Time-Travel Debugger Toggle
                    Button {
                        viewModel.isTimeTravelVisible.toggle()
                    } label: {
                        Label("Time-Travel (⌘T)", systemImage: "clock.arrow.circlepath")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.isTimeTravelVisible ? viewModel.themeTokens.primary.swiftUIColor : nil)
                    .controlSize(.small)

                    // Command Palette Trigger
                    Button {
                        viewModel.isCommandPalettePresented = true
                    } label: {
                        Label("Command Palette (⌘K)", systemImage: "command")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.bar)

            Divider()
        }
    }
}
#endif
