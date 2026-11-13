import Foundation

public struct WorkspaceSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = "2.5"

    public var schemaVersion: String
    public var savedAtTimestamp: Double
    public var selection: NavigationSelection
    public var canvasDocument: CanvasDocument
    public var themeTokens: StudioThemeTokens
    public var activeThemePreset: StudioThemePreset
    public var flowJSON: String
    public var counter: Int
    public var cartItems: [CartDemoItem]
    public var promoApplied: Bool
    public var blueprintConfig: BlueprintConfiguration
    public var pinnedSnippets: [SavedSnippet]

    public init(
        schemaVersion: String = WorkspaceSnapshot.currentSchemaVersion,
        savedAtTimestamp: Double = Date().timeIntervalSince1970,
        selection: NavigationSelection,
        canvasDocument: CanvasDocument,
        themeTokens: StudioThemeTokens,
        activeThemePreset: StudioThemePreset,
        flowJSON: String,
        counter: Int,
        cartItems: [CartDemoItem],
        promoApplied: Bool,
        blueprintConfig: BlueprintConfiguration,
        pinnedSnippets: [SavedSnippet]
    ) {
        self.schemaVersion = schemaVersion
        self.savedAtTimestamp = savedAtTimestamp
        self.selection = selection
        self.canvasDocument = canvasDocument
        self.themeTokens = themeTokens
        self.activeThemePreset = activeThemePreset
        self.flowJSON = flowJSON
        self.counter = counter
        self.cartItems = cartItems
        self.promoApplied = promoApplied
        self.blueprintConfig = blueprintConfig
        self.pinnedSnippets = pinnedSnippets
    }

    public func encodedJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public func encodedJSONString() throws -> String {
        let data = try encodedJSONData()
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return text
    }

    public func save(to url: URL) throws {
        let data = try encodedJSONData()
        try data.write(to: url, options: .atomic)
    }

    public static func decode(from data: Data) throws -> WorkspaceSnapshot {
        try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
    }

    public static func load(from url: URL) throws -> WorkspaceSnapshot {
        let data = try Data(contentsOf: url)
        return try decode(from: data)
    }
}
