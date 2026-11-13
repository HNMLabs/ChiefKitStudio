#if canImport(SwiftUI) && canImport(AppKit)
import ChiefKitStudioCore
import Foundation

enum CommandPaletteSection: String, CaseIterable, Sendable {
    case navigation = "Playgrounds, Blueprints & Examples"
    case localAI = "CoreLocalAIKit Commands"
    case workspace = "Canvas, Theme & Debugger"
    case export = "Workspace, Export & Xcode"
}

enum CommandActionKind: Hashable, Sendable {
    case navigate(NavigationSelection)
    case runAIPreset(LocalAITaskKind)
    case openInspectorTab(RightInspectorTab)
    case toggleTimeTravel
    case toggleDarkAppearance
    case toggleAccessibilityOverlay
    case toggleLiquidGlass
    case autoFixContrast
    case undoCanvas
    case redoCanvas
    case pinCurrentSnippet
    case saveWorkspace
    case loadWorkspace
    case runSelfCheck
    case openProjectGenerator
    case copySwiftUICode
    case exportPackageSnippet
    case openInXcode
    case resetPlayground
}

struct CommandPaletteItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let shortcutHint: String?
    let section: CommandPaletteSection
    let action: CommandActionKind
}
#endif
