# Architecture

ChiefKit Studio 2.5 uses a clean two-target Swift 6 architecture with **zero external package dependencies**:

```text
Sources/ChiefKitStudioCore/   Cross-platform pure Swift 6 core (macOS & Linux CI)
  Models/
    RGBAColorCore.swift       sRGB color math, WCAG 2.1 luminance/contrast & Auto-Fix AA
    ThemeModels.swift         StudioThemeTokens, presets & SwiftBlocks / W3C JSON / CSS exporters
    CanvasModels.swift        Drag-and-drop nodes, 6-axis alignment, auto-tidy grid & SwiftUI synthesis
    FlowModels.swift          NotebookFlow JSON codec, topology edges & static flow validator
    CatalogModels.swift       PackageDemo, TemplateKind, SavedSnippet & NavigationSelection
    BlueprintModels.swift     Full-Stack Architecture Composer across 4 domains & 5 layers
    TimelineModels.swift      TimeTravelEngine history scrubber & CanvasHistoryStack undo/redo
    LocalAIModels.swift       On-device AI tasks (including @Test generation) & response payloads
    WorkspaceSnapshot.swift   Portable .chiefkit workspace persistence
  Engines/
    LocalAIEngine.swift       On-device NaturalLanguage + optional FoundationModels + AST synthesis
    CodeDiffEngine.swift      Exact LCS line-by-line diff & unified patch generator
    CodeQualityAnalyzer.swift Real-time 0–100 Accessibility, Swift 6, Token & Testability scorer
    DemoLibrary.swift         Live code & Package.swift dependency snippet catalog
    ProjectGeneratorCore.swift Runnable SwiftPM starter project + W3C tokens + unit test emitter
    StudioSelfCheckRunner.swift End-to-end 7-subsystem diagnostic runner (--self-check)

Sources/ChiefKitStudio/       macOS SwiftUI Studio App + Headless CLI entry point
  App/                        ChiefKitStudioApp (macOS GUI + shortcuts) & HeadlessMain (Linux/CI CLI)
  Components/                 GlassCard, CodeBlockView, WhatYouLearnCard, FloatingTimeTravelView, AccessibilityOverlayView
  Export/                     Clipboard, NSSavePanel/NSOpenPanel .chiefkit & Xcode launchers
  Models/                     SwiftUI color/environment bridges, PreviewConfiguration & CommandPalette
  Resources/                  App icon and ChiefKit brand assets
  ViewModels/                 @MainActor PlaygroundViewModel coordinating all studio subsystems
  Views/                      Sidebar, Preview Toolbar, Canvas, Blueprint Composer, Visual Flow Builder, Right Inspector

Tests/ChiefKitStudioTests/
  ChiefKitStudioTests.swift       19 XCTest unit & integration tests
  StudioSwiftTestingSuite.swift   Parameterized Swift 6 Testing (@Suite / @Test) verification
```

## Key Design Decisions

- **Zero External Build Dependencies:** ChiefKit Studio builds offline out of the box using system frameworks (`Foundation`, `SwiftUI`, `AppKit`, `NaturalLanguage`, and `#if canImport(FoundationModels)`), while synthesizing production code for `SwiftBlocks`, `SwiftState`, `NotebookFlowKit`, and `CoreLocalAIKit`.
- **Cross-Platform Verifiability:** Extracting pure synthesis, WCAG contrast math, flow validation, time-travel, LCS diffing, and project generation into `ChiefKitStudioCore` enables full `swift build`, `swift test`, and `swift run ChiefKitStudio --self-check` execution on both macOS and Linux CI.
- **Swift 6 Strict Concurrency:** Every model and engine conforms to `Sendable`, UI coordination is isolated to `@MainActor`, and on-device AI analysis executes asynchronously.
