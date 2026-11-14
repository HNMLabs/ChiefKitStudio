#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

public struct DesignSystemDiagnosticsReport: Codable, Hashable, Sendable {
    public let version: String
    public let compiledTokenTargetCount: Int
    public let dynamicTypeSpecCount: Int
    public let vectorIconCount: Int
    public let swiftBlockCount: Int
    public let rk4SpringRMSError: Double
    public let primaryOnWhiteAPCALc: Double
    public let allSubsystemsHealthy: Bool

    public init(
        version: String,
        compiledTokenTargetCount: Int,
        dynamicTypeSpecCount: Int,
        vectorIconCount: Int,
        swiftBlockCount: Int,
        rk4SpringRMSError: Double,
        primaryOnWhiteAPCALc: Double,
        allSubsystemsHealthy: Bool
    ) {
        self.version = version
        self.compiledTokenTargetCount = compiledTokenTargetCount
        self.dynamicTypeSpecCount = dynamicTypeSpecCount
        self.vectorIconCount = vectorIconCount
        self.swiftBlockCount = swiftBlockCount
        self.rk4SpringRMSError = rk4SpringRMSError
        self.primaryOnWhiteAPCALc = primaryOnWhiteAPCALc
        self.allSubsystemsHealthy = allSubsystemsHealthy
    }
}

public enum ChiefKitDesignSystemModule {
    public static let version = "3.0.0"

    /// Runs an end-to-end deterministic health verification across all ChiefKitDesignSystem 3.0 engines.
    public static func runDiagnostics(
        theme: StudioThemeTokens = StudioThemeTokens()
    ) -> DesignSystemDiagnosticsReport {
        let tokenBundle = DesignTokenCompiler.compileAllTargets(tokens: theme)
        let dtSpecCount = DynamicTypeSizeCategory.allCases.count * HIGTextStyle.allCases.count
        let iconCount = ChiefKitVectorIcon.allCases.count
        let catalogAudit = SwiftBlockCatalog.auditCatalog(theme: theme)
        let springReport = SpringAnalysisReport(parameters: .snappy)
        let apcaLc = abs(PerceptualColorScience.apcaContrast(text: theme.primary, background: .white))

        let layoutRoot = LayoutNode(
            name: "Root",
            axis: .horizontal,
            widthPolicy: .fillAvailable,
            heightPolicy: .fixed(120),
            padding: .all(16),
            spacing: 12,
            children: [
                LayoutNode(name: "Sidebar", widthPolicy: .fixed(200), heightPolicy: .fillAvailable),
                LayoutNode(name: "Detail", widthPolicy: .fillAvailable, heightPolicy: .fillAvailable)
            ]
        )
        let solved = AutoLayoutConstraintSolver.solve(root: layoutRoot, availableWidth: 800, availableHeight: 120)

        let healthy = tokenBundle.files.count == 8
            && dtSpecCount == 132
            && iconCount >= 40
            && catalogAudit.isFull64CatalogVerified
            && springReport.rk4AnalyticalRMSError < 1e-3
            && solved.children.count == 2

        return DesignSystemDiagnosticsReport(
            version: version,
            compiledTokenTargetCount: tokenBundle.files.count,
            dynamicTypeSpecCount: dtSpecCount,
            vectorIconCount: iconCount,
            swiftBlockCount: catalogAudit.totalComponentCount,
            rk4SpringRMSError: springReport.rk4AnalyticalRMSError,
            primaryOnWhiteAPCALc: apcaLc,
            allSubsystemsHealthy: healthy
        )
    }
}
