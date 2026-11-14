import ChiefKitStudioCore
import Foundation

/// Top-level entry point and metadata facade for the ChiefKit Studio 3.0 Enterprise Blueprints library.
public enum ChiefKitBlueprintsModule: Sendable {
    public static let version: String = "3.0.0"
    public static let canonicalVerticalCount: Int = EnterpriseVertical.allCases.count
    public static let canonicalBlueprintCount: Int = EnterpriseBlueprintID.allCases.count
    public static let exportedWorkspaceFileCount: Int = BlueprintWorkspaceExporter.canonicalFileCount

    /// Returns aggregate metrics across all 28 registered enterprise blueprints.
    public static var summary: BlueprintCatalogSummary {
        EnterpriseBlueprintCatalog.summary
    }

    /// Runs the full 28-blueprint static architecture, onboarding JSON, syntax balance, and TR/EN localization audit.
    public static func validateCatalog(
        theme: StudioThemeTokens = StudioThemeTokens()
    ) -> BlueprintCatalogValidationReport {
        BlueprintArchitectureValidator.validateAll(theme: theme)
    }

    /// Convenience helper bridging legacy 4-case `BlueprintDomain` into matching 3.0 `EnterpriseBlueprintSpec` items.
    public static func recommendedBlueprints(for legacyDomain: BlueprintDomain) -> [EnterpriseBlueprintSpec] {
        switch legacyDomain {
        case .aiNotesWorkspace:
            return [
                EnterpriseBlueprintCatalog.spec(for: .localRAGKnowledgeWorkbench),
                EnterpriseBlueprintCatalog.spec(for: .multiplayerBlockWikiDocs)
            ]
        case .fintechExpenseTracker:
            return EnterpriseBlueprintCatalog.specs(in: .fintechBanking)
        case .developerSaaSDashboard:
            return [
                EnterpriseBlueprintCatalog.spec(for: .cicdFleetIncidentCommander),
                EnterpriseBlueprintCatalog.spec(for: .multiTenantSaaSBillingFlags),
                EnterpriseBlueprintCatalog.spec(for: .socSIEMThreatHuntingConsole)
            ]
        case .habitHealthCoach:
            return EnterpriseBlueprintCatalog.specs(in: .healthBiometrics)
        }
    }
}
