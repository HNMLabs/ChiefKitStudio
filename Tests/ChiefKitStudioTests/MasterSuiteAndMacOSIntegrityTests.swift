import ChiefKitAST
import ChiefKitBlueprints
import ChiefKitDesignSystem
import ChiefKitSecurity
@testable import ChiefKitStudio
import ChiefKitStudioCore
import Foundation
import Testing
import XCTest

final class MasterSuiteAndMacOSIntegrityXCTests: XCTestCase {
    private var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testMasterSuiteRunnerPassesAll16EndToEndSubsystems() async {
        let report = await MasterSuiteRunner.runFullMasterSelfCheck()
        XCTAssertEqual(report.steps.count, 16, "Expected all 16 Studio 3.0 Master Suite subsystems")
        for step in report.steps {
            XCTAssertTrue(step.passed, "Subsystem '\(step.subsystem)' failed: \(step.detail)")
        }
        XCTAssertTrue(report.allPassed)
        XCTAssertTrue(report.formattedSummary.contains("16/16 passed"))
    }

    func testPlatformStatsReportIncludesAllStudio3Capabilities() {
        let stats = MasterSuiteRunner.generatePlatformStatsReport()
        XCTAssertTrue(stats.contains("ChiefKit Studio 3.0"))
        XCTAssertTrue(stats.contains("64"))
        XCTAssertTrue(stats.contains("28"))
        XCTAssertTrue(stats.contains("38"))
    }

    func testStaticSourceVerificationAcrossAllMacOSViewsAndLibraryModules() {
        let modulePaths = [
            "Sources/ChiefKitStudio",
            "Sources/ChiefKitStudioCore",
            "Sources/ChiefKitAST",
            "Sources/ChiefKitDesignSystem",
            "Sources/ChiefKitSecurity",
            "Sources/ChiefKitBlueprints"
        ]

        for relativePath in modulePaths {
            let dirURL = repositoryRootURL.appendingPathComponent(relativePath, isDirectory: true)
            let verification = ASTSourceVerifier.verifyDirectory(at: dirURL, recursive: true)
            XCTAssertTrue(
                verification.isValid,
                "Directory \(relativePath) failed structural source verification: \(verification.crossFileDuplicateTypes)"
            )
            XCTAssertGreaterThan(verification.totalFilesVerified, 0, "Expected Swift files in \(relativePath)")
        }
    }

    func testAllStudio3WorkbenchViewsExistAndDeclareConditionalSwiftUIGuards() throws {
        let studio3ViewsDir = repositoryRootURL.appendingPathComponent("Sources/ChiefKitStudio/Studio3Views", isDirectory: true)
        let expectedViews = [
            "ASTWorkbenchView.swift",
            "AnimationTimelineStudioView.swift",
            "MultiArtboardStudioView.swift",
            "ComponentCatalogBrowserView.swift",
            "DataAPISchemaStudioView.swift",
            "LocalizationCatalogStudioView.swift",
            "SecurityEphemerisStudioView.swift",
            "PerformanceProfilerStudioView.swift",
            "EnterpriseBlueprintExplorerView.swift"
        ]

        for viewFile in expectedViews {
            let fileURL = studio3ViewsDir.appendingPathComponent(viewFile)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Missing \(viewFile)")
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertTrue(content.contains("#if canImport(SwiftUI) && canImport(AppKit)"), "\(viewFile) missing macOS SwiftUI guard")
            XCTAssertTrue(content.contains(": View"), "\(viewFile) missing SwiftUI View conformance")

            let sourceCheck = ASTSourceVerifier.verifySource(code: content, filePath: viewFile)
            XCTAssertTrue(sourceCheck.isValid, "\(viewFile) failed ASTSourceVerifier: \(sourceCheck.issues)")
            XCTAssertGreaterThanOrEqual(sourceCheck.conditionalCompilationBlockCount, 1)
        }
    }
}

@Suite("ChiefKit Studio 3.0 — Master Integration & Source Integrity")
struct MasterSuiteIntegrationSwiftTests {
    @Test("All 8 StudioWorkbenchKind cases map cleanly to NavigationSelection")
    func workbenchNavigationInvariants() {
        for kind in StudioWorkbenchKind.allCases {
            let nav = NavigationSelection.workbench(kind)
            #expect(!nav.title.isEmpty)
            #expect(!nav.subtitle.isEmpty)
            #expect(!nav.symbolName.isEmpty)
            #expect(!DemoLibrary.requiredPackages(for: nav).isEmpty)
        }
    }

    @Test("All 28 EnterpriseBlueprintID cases map cleanly to NavigationSelection and Catalog")
    func enterpriseBlueprintNavigationInvariants() {
        #expect(EnterpriseBlueprintID.allCases.count == 28)
        for id in EnterpriseBlueprintID.allCases {
            let spec = EnterpriseBlueprintCatalog.spec(for: id)
            let nav = NavigationSelection.enterpriseBlueprint(id.rawValue)
            #expect(spec.id == id)
            #expect(!spec.title.isEmpty)
            #expect(DemoLibrary.requiredPackages(for: nav).count == PackageDemo.allCases.count)
        }
    }
}
