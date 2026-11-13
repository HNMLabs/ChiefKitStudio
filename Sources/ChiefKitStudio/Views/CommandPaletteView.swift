#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var viewModel: PlaygroundViewModel
    @FocusState private var isSearchFocused: Bool

    private var groupedSections: [GroupedCommandSection] {
        let items = viewModel.filteredCommandItems
        return CommandPaletteSection.allCases.compactMap { section in
            let matches = items.filter { $0.section == section }
            return matches.isEmpty ? nil : GroupedCommandSection(section: section, items: matches)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 0) {
                // Search Header
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)

                    TextField(
                        "Type a command, package, example, or Local AI action…",
                        text: $viewModel.commandPaletteQuery
                    )
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit {
                        if let first = viewModel.filteredCommandItems.first {
                            viewModel.executeCommand(first)
                        }
                    }

                    Button("ESC") {
                        dismiss()
                    }
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)
                }
                .padding(16)

                Divider()

                // Filtered Results
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if groupedSections.isEmpty {
                            Text("No matching commands found for \"\(viewModel.commandPaletteQuery)\".")
                                .foregroundStyle(.secondary)
                                .padding(20)
                        } else {
                            ForEach(groupedSections) { group in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(group.section.rawValue.uppercased())
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)

                                    ForEach(group.items) { item in
                                        Button {
                                            viewModel.executeCommand(item)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: item.symbolName)
                                                    .frame(width: 20)
                                                    .foregroundStyle(viewModel.themeTokens.primary.swiftUIColor)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.title)
                                                        .font(.callout.weight(.semibold))
                                                        .foregroundStyle(.primary)
                                                    Text(item.subtitle)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }

                                                Spacer()

                                                if let shortcut = item.shortcutHint {
                                                    Text(shortcut)
                                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                                        .foregroundStyle(.secondary)
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 5))
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 380)

                Divider()

                HStack {
                    Text("Press Return to run top match · Click any row to execute")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.filteredCommandItems.count) commands")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(width: 580)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(viewModel.themeTokens.primary.swiftUIColor.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 14)
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private func dismiss() {
        viewModel.isCommandPalettePresented = false
        viewModel.commandPaletteQuery = ""
    }
}

private struct GroupedCommandSection: Identifiable {
    var id: CommandPaletteSection { section }
    let section: CommandPaletteSection
    let items: [CommandPaletteItem]
}
#endif
