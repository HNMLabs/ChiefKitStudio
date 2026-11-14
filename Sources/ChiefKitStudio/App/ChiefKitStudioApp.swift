#if canImport(SwiftUI) && canImport(AppKit)
import AppKit
import ChiefKitStudioCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = ChiefKitAssets.appIconImage() {
            NSApp.applicationIconImage = icon
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct ChiefKitStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if CommandLine.arguments.contains("--stats") {
            print(MasterSuiteRunner.generatePlatformStatsReport())
            Foundation.exit(0)
        }
        if CommandLine.arguments.contains("--self-check") {
            let semaphore = DispatchSemaphore(value: 0)
            nonisolated(unsafe) var allOK = true
            Task {
                let report = await MasterSuiteRunner.runFullMasterSelfCheck()
                print(report.formattedSummary)
                allOK = report.allPassed
                semaphore.signal()
            }
            semaphore.wait()
            Foundation.exit(allOK ? 0 : 1)
        }
    }

    var body: some Scene {
        WindowGroup("ChiefKit Studio 3.0") {
            ContentView()
                .frame(minWidth: 960, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Generate Xcode / SwiftPM Project…") {
                    NotificationCenter.default.post(name: .studioOpenProjectGenerator, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Save Workspace (.chiefkit)…") {
                    NotificationCenter.default.post(name: .studioSaveWorkspace, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Open Workspace (.chiefkit)…") {
                    NotificationCenter.default.post(name: .studioLoadWorkspace, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo Canvas Change") {
                    NotificationCenter.default.post(name: .studioUndoCanvas, object: nil)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo Canvas Change") {
                    NotificationCenter.default.post(name: .studioRedoCanvas, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandMenu("Studio") {
                Button("Command Palette…") {
                    NotificationCenter.default.post(name: .studioToggleCommandPalette, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button("SwiftUI AST & Refactoring Lab") {
                    NotificationCenter.default.post(name: .studioOpenASTLab, object: nil)
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button("SwiftBlocks 3.0 Catalog (64)") {
                    NotificationCenter.default.post(name: .studioOpenComponentCatalog, object: nil)
                }
                .keyboardShortcut("2", modifiers: [.command, .option])

                Button("EphemerisCore & ChaCha20 Security Vault") {
                    NotificationCenter.default.post(name: .studioOpenSecurityVault, object: nil)
                }
                .keyboardShortcut("3", modifiers: [.command, .option])

                Button("120Hz ProMotion & Invalidation Profiler") {
                    NotificationCenter.default.post(name: .studioOpenPerformanceProfiler, object: nil)
                }
                .keyboardShortcut("4", modifiers: [.command, .option])

                Button("Run 16-Subsystem Master Self-Check") {
                    NotificationCenter.default.post(name: .studioRunMasterSelfCheck, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .option])

                Divider()

                Button("Toggle State Time-Travel Debugger") {
                    NotificationCenter.default.post(name: .studioToggleTimeTravel, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Focus CoreLocalAIKit Assistant") {
                    NotificationCenter.default.post(name: .studioOpenLocalAI, object: nil)
                }
                .keyboardShortcut("j", modifiers: .command)

                Button("Pin Current Design to My Snippets") {
                    NotificationCenter.default.post(name: .studioPinCurrentSnippet, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)

                Divider()

                Button("Copy Live SwiftUI Code") {
                    NotificationCenter.default.post(name: .studioCopySwiftUICode, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Divider()

                Button("Download Latest macOS DMG…") {
                    ExportService.openURL(ExportService.dmgDownloadURLString)
                }
            }
        }
    }
}
#endif
