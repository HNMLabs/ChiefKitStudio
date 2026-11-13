#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import SwiftUI

extension Notification.Name {
    static let studioToggleCommandPalette = Notification.Name("studioToggleCommandPalette")
    static let studioToggleTimeTravel = Notification.Name("studioToggleTimeTravel")
    static let studioOpenLocalAI = Notification.Name("studioOpenLocalAI")
    static let studioOpenProjectGenerator = Notification.Name("studioOpenProjectGenerator")
    static let studioCopySwiftUICode = Notification.Name("studioCopySwiftUICode")
    static let studioSaveWorkspace = Notification.Name("studioSaveWorkspace")
    static let studioLoadWorkspace = Notification.Name("studioLoadWorkspace")
    static let studioUndoCanvas = Notification.Name("studioUndoCanvas")
    static let studioRedoCanvas = Notification.Name("studioRedoCanvas")
    static let studioPinCurrentSnippet = Notification.Name("studioPinCurrentSnippet")
}

struct ContentView: View {
    @StateObject private var viewModel = PlaygroundViewModel()

    var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 225, ideal: 278, max: 350)
            } detail: {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        GeometryReader { proxy in
                            if proxy.size.width >= 780 {
                                HSplitView {
                                    DemoDetailView(viewModel: viewModel)
                                        .frame(minWidth: 380)

                                    CodePreviewPanel(viewModel: viewModel)
                                        .frame(
                                            minWidth: 320,
                                            idealWidth: min(465, proxy.size.width * 0.39),
                                            maxWidth: 620
                                        )
                                }
                            } else {
                                VSplitView {
                                    DemoDetailView(viewModel: viewModel)
                                        .frame(minHeight: 320)

                                    CodePreviewPanel(viewModel: viewModel)
                                        .frame(minHeight: 250, idealHeight: 340)
                                }
                            }
                        }

                        ActionBarView(viewModel: viewModel)
                    }

                    if viewModel.isTimeTravelVisible {
                        FloatingTimeTravelView(viewModel: viewModel)
                            .padding(.trailing, 24)
                            .padding(.bottom, 56)
                    }
                }
            }

            if viewModel.isCommandPalettePresented {
                CommandPaletteView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.isProjectGeneratorPresented) {
            ProjectGeneratorSheet(viewModel: viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioToggleCommandPalette)) { _ in
            viewModel.isCommandPalettePresented.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioToggleTimeTravel)) { _ in
            viewModel.isTimeTravelVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioOpenLocalAI)) { _ in
            viewModel.rightInspectorTab = .assistant
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioOpenProjectGenerator)) { _ in
            viewModel.isProjectGeneratorPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioCopySwiftUICode)) { _ in
            viewModel.copySwiftUICode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioSaveWorkspace)) { _ in
            viewModel.saveWorkspaceToDisk()
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioLoadWorkspace)) { _ in
            viewModel.loadWorkspaceFromDisk()
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioUndoCanvas)) { _ in
            viewModel.undoCanvas()
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioRedoCanvas)) { _ in
            viewModel.redoCanvas()
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioPinCurrentSnippet)) { _ in
            viewModel.pinCurrentSnippet()
        }
    }
}
#endif
