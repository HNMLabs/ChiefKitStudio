import ChiefKitStudioCore
import Foundation
import Testing

@Suite("ChiefKit Studio 2.5 — Modern Swift Testing (@Test) Suite")
struct StudioSwiftTestingSuite {
    @Test("All 6 StudioThemePreset palettes produce valid hex and positive spacing scales", arguments: StudioThemePreset.allCases)
    func presetTokenInvariants(preset: StudioThemePreset) {
        let tokens = preset.tokens
        #expect(tokens.primary.hexString.hasPrefix("#"))
        #expect(tokens.primary.hexString.count == 7)
        #expect(tokens.spacingXS <= tokens.spacingSM)
        #expect(tokens.spacingSM <= tokens.spacingMD)
        #expect(tokens.spacingMD <= tokens.spacingLG)
    }

    @Test("All 4 Auto-Craft presets build non-empty grid-aligned block layouts", arguments: CanvasAutoCraftPreset.allCases)
    func autoCraftPresetNodes(preset: CanvasAutoCraftPreset) {
        let nodes = preset.buildNodes(radius: 14)
        #expect(!nodes.isEmpty)
        let doc = CanvasDocument(nodes: nodes)
        let code = doc.generateSwiftUICode(
            theme: StudioThemeTokens(),
            layoutMode: .adaptiveStacks,
            focusedNodeID: nil,
            focusSelectedOnly: false
        )
        #expect(code.contains("import SwiftUI"))
        #expect(code.contains("struct CustomBlocksCanvasView: View"))
    }

    @Test("All 4 Full-Stack Blueprint domains synthesize code and @Test verification suites", arguments: BlueprintDomain.allCases)
    func fullStackBlueprintDomains(domain: BlueprintDomain) {
        let config = BlueprintConfiguration(domain: domain)
        let viewCode = config.synthesizeSwiftUICode(for: domain, theme: StudioThemeTokens())
        let testCode = config.synthesizeSwiftTests(for: domain)
        let flowJSON = config.synthesizeFlowJSON(for: domain)

        #expect(viewCode.contains(domain.entityName))
        #expect(testCode.contains("@Suite"))
        #expect((try? FlowDefinition.decode(flowJSON).get()) != nil)
    }

    @Test("LocalAIEngine generated @Test suite contains valid Swift Testing annotations")
    func localAIGeneratedSwiftTestingOutput() async {
        let engine = LocalAIEngine()
        let resp = await engine.run(
            prompt: "Bu ekran için birim testleri üret",
            preferredTask: nil,
            backend: .naturalLanguageAST,
            currentCode: DemoLibrary.defaultFlowJSON,
            selectionTitle: "OnboardingFlow",
            theme: StudioThemeTokens(),
            simulateLatency: false
        )
        #expect(resp.taskKind == .generateSwiftTests)
        #expect(resp.detectedLanguage == "Turkish (TR)")
        #expect(resp.generatedCode.contains("import Testing"))
        #expect(resp.generatedCode.contains("@Test"))
        #expect(resp.generatedCode.contains("#expect("))
    }
}
