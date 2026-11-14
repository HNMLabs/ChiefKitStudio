#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitBlueprints
import ChiefKitStudioCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: PlaygroundViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ChiefKitLogoView(size: 34, cornerRadius: 8)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("ChiefKit Studio 3.0")
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                        Text("Workbenches · AST · 28 Blueprints")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Button {
                        viewModel.isCommandPalettePresented = true
                    } label: {
                        Text("⌘K")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Open Command Palette (⌘K)")
                }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField("Search workbenches, 28 blueprints, APIs…", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(.separator.opacity(0.45), lineWidth: 1)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(ExampleCategory.allCases) { category in
                            let active = viewModel.selectedCategory == category
                            Button {
                                viewModel.selectedCategory = category
                            } label: {
                                Text(category.rawValue)
                                    .font(.caption2.weight(active ? .bold : .medium))
                                    .foregroundStyle(active ? .white : .primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        active
                                            ? viewModel.themeTokens.primary.swiftUIColor
                                            : Color.secondary.opacity(0.12),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding([.horizontal, .top], 14)
            .padding(.bottom, 8)

            List {
                if !viewModel.filteredPinnedSnippets.isEmpty {
                    Section("My Pinned Snippets (\(viewModel.filteredPinnedSnippets.count))") {
                        ForEach(viewModel.filteredPinnedSnippets) { snippet in
                            SidebarRow(
                                title: snippet.title,
                                subtitle: snippet.notes,
                                badge: "Pinned",
                                systemImage: "pin.fill",
                                accent: viewModel.themeTokens.primary.swiftUIColor,
                                isSelected: viewModel.selection == .savedSnippet(snippet.id)
                            ) {
                                viewModel.select(.savedSnippet(snippet.id))
                            }
                        }
                    }
                }

                if !viewModel.filteredWorkbenches.isEmpty {
                    Section("Studio 3.0 Workbenches (\(viewModel.filteredWorkbenches.count))") {
                        ForEach(viewModel.filteredWorkbenches) { wb in
                            SidebarRow(
                                title: wb.title,
                                subtitle: wb.subtitle,
                                badge: "3.0 Lab",
                                systemImage: wb.symbolName,
                                accent: viewModel.themeTokens.primary.swiftUIColor,
                                isSelected: viewModel.selection == .workbench(wb)
                            ) {
                                viewModel.select(.workbench(wb))
                            }
                        }
                    }
                }

                if !viewModel.filteredPackages.isEmpty {
                    Section("Core Packages (\(viewModel.filteredPackages.count))") {
                        ForEach(viewModel.filteredPackages) { package in
                            SidebarRow(
                                title: package.title,
                                subtitle: package.purpose,
                                badge: package.category.rawValue,
                                systemImage: package.symbolName,
                                accent: viewModel.themeTokens.primary.swiftUIColor,
                                isSelected: viewModel.selection == .package(package)
                            ) {
                                viewModel.select(.package(package))
                            }
                        }
                    }
                }

                if !viewModel.filteredEnterpriseBlueprints.isEmpty {
                    Section("Enterprise Blueprints (\(viewModel.filteredEnterpriseBlueprints.count))") {
                        ForEach(viewModel.filteredEnterpriseBlueprints) { spec in
                            SidebarRow(
                                title: spec.title,
                                subtitle: "\(spec.vertical.title) — \(spec.subtitle)",
                                badge: "14-File",
                                systemImage: spec.sfSymbol,
                                accent: viewModel.themeTokens.primary.swiftUIColor,
                                isSelected: viewModel.selection == .enterpriseBlueprint(spec.id.rawValue)
                            ) {
                                viewModel.select(.enterpriseBlueprint(spec.id.rawValue))
                            }
                        }
                    }
                }

                if !viewModel.filteredBlueprints.isEmpty {
                    Section("Classic Full-Stack Blueprints (\(viewModel.filteredBlueprints.count))") {
                        ForEach(viewModel.filteredBlueprints) { blueprint in
                            SidebarRow(
                                title: blueprint.title,
                                subtitle: blueprint.summary,
                                badge: "Blueprint",
                                systemImage: blueprint.symbolName,
                                accent: viewModel.themeTokens.primary.swiftUIColor,
                                isSelected: viewModel.selection == .blueprint(blueprint)
                            ) {
                                viewModel.select(.blueprint(blueprint))
                            }
                        }
                    }
                }

                if !viewModel.filteredTemplates.isEmpty {
                    Section("Categorized Examples (\(viewModel.filteredTemplates.count))") {
                        ForEach(viewModel.filteredTemplates) { template in
                            SidebarRow(
                                title: template.title,
                                subtitle: template.summary,
                                badge: template.category.rawValue,
                                systemImage: template.symbolName,
                                accent: viewModel.themeTokens.primary.swiftUIColor,
                                isSelected: viewModel.selection == .template(template)
                            ) {
                                viewModel.select(.template(template))
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 10) {
                Button {
                    viewModel.saveWorkspaceToDisk()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Save Workspace (.chiefkit) — ⌘S")

                Button {
                    viewModel.loadWorkspaceFromDisk()
                } label: {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Open Workspace (.chiefkit) — ⌘O")

                Divider()
                    .frame(height: 12)

                Button {
                    viewModel.openInXcode()
                } label: {
                    Label("Xcode", systemImage: "hammer")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    viewModel.openDMGDownload()
                } label: {
                    Label("DMG", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Download latest macOS DMG setup")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
    }
}

private struct SidebarRow: View {
    let title: String
    let subtitle: String
    let badge: String
    let systemImage: String
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? accent : Color.secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.callout.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 2)

                        Text(badge)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? accent.opacity(0.16) : Color.clear)
    }
}
#endif
