#if canImport(CoreGraphics)
import CoreGraphics
#endif
import ChiefKitStudioCore
import Foundation

// MARK: - Industry Verticals

/// High-level industry verticals covered by ChiefKit Studio 3.0 Enterprise Blueprints.
public enum EnterpriseVertical: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case fintechBanking
    case aiDeveloperTools
    case healthBiometrics
    case commerceLogistics
    case productivityCollab
    case mediaCreator
    case educationScience
    case smartHomeMobility
    case enterpriseSecurity

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fintechBanking:
            return "Fintech & Multi-Currency Banking"
        case .aiDeveloperTools:
            return "AI & Developer Engineering Tools"
        case .healthBiometrics:
            return "Clinical Health & Biometrics"
        case .commerceLogistics:
            return "Spatial Commerce & Cold-Chain Logistics"
        case .productivityCollab:
            return "Multiplayer Productivity & Zero-Knowledge Vaults"
        case .mediaCreator:
            return "Pro Audio, RAW Darkroom & Broadcast"
        case .educationScience:
            return "Cognitive Learning & Scientific Labs"
        case .smartHomeMobility:
            return "Smart Microgrids & Autonomous Mobility"
        case .enterpriseSecurity:
            return "Enterprise Security, Legal & SaaS Governance"
        }
    }

    public var turkishTitle: String {
        switch self {
        case .fintechBanking:
            return "Fintek ve Çok Para Birimli Hazine"
        case .aiDeveloperTools:
            return "Yapay Zeka ve Geliştirici Araçları"
        case .healthBiometrics:
            return "Klinik Sağlık ve Biyometrik Analiz"
        case .commerceLogistics:
            return "Uzamsal Ticaret ve Soğuk Zincir Lojistik"
        case .productivityCollab:
            return "Çok Oyunculu Üretkenlik ve Şifreli Kasalar"
        case .mediaCreator:
            return "Profesyonel Ses, Fotoğraf ve Canlı Yayın"
        case .educationScience:
            return "Bilişsel Eğitim ve Bilimsel Laboratuvar"
        case .smartHomeMobility:
            return "Akıllı Enerji Şebekesi ve Otonom Mobilite"
        case .enterpriseSecurity:
            return "Kurumsal Güvenlik, Hukuk ve SaaS Yönetişimi"
        }
    }

    public var subtitle: String {
        switch self {
        case .fintechBanking:
            return "Real-time FX treasury desks, quantitative order books, and multi-party escrow ledgers."
        case .aiDeveloperTools:
            return "Local-first vector RAG workbenches, CI/CD incident command, and AST-aware PR review studios."
        case .healthBiometrics:
            return "Longevity biomarker tracking, circadian HRV coaching, and encrypted telemedicine vaults."
        case .commerceLogistics:
            return "visionOS luxury AR configurators, cold-chain IoT fleet monitors, and high-throughput kitchen displays."
        case .productivityCollab:
            return "CRDT block wikis, velocity-modeled OKR roadmaps, and WebAuthn zero-knowledge passkey vaults."
        case .mediaCreator:
            return "ITU-R LUFS podcast mastering DAWs, non-destructive RAW LUT darkrooms, and multi-cam live switchers."
        case .educationScience:
            return "FSRS-5 spaced repetition academies, celestial ephemeris planners, and wet-lab protocol notebooks."
        case .smartHomeMobility:
            return "Matter 1.3 solar microgrids, EV charging curve planners, and geofenced autonomous drone stations."
        case .enterpriseSecurity:
            return "MITRE ATT&CK SIEM consoles, Zero-Trust MDM posture managers, contract redliners, and SaaS billing engines."
        }
    }

    public var sfSymbol: String {
        switch self {
        case .fintechBanking:
            return "banknote.fill"
        case .aiDeveloperTools:
            return "terminal.fill"
        case .healthBiometrics:
            return "waveform.path.ecg.rectangle.fill"
        case .commerceLogistics:
            return "shippingbox.and.arrow.backward.fill"
        case .productivityCollab:
            return "person.2.crop.square.stack.fill"
        case .mediaCreator:
            return "slider.vertical.3"
        case .educationScience:
            return "atom"
        case .smartHomeMobility:
            return "bolt.car.fill"
        case .enterpriseSecurity:
            return "lock.shield.fill"
        }
    }

    public var recommendedThemePreset: StudioThemePreset {
        switch self {
        case .fintechBanking:
            return .emeraldMint
        case .aiDeveloperTools:
            return .midnightViolet
        case .healthBiometrics:
            return .liquidGlass26
        case .commerceLogistics:
            return .sunsetAmber
        case .productivityCollab:
            return .chiefKitBlue
        case .mediaCreator:
            return .monochromePro
        case .educationScience:
            return .midnightViolet
        case .smartHomeMobility:
            return .emeraldMint
        case .enterpriseSecurity:
            return .monochromePro
        }
    }

    public var complianceStandards: [String] {
        switch self {
        case .fintechBanking:
            return ["ISO 20022", "PCI-DSS v4.0", "SEPA Instant", "Double-Entry GAAP"]
        case .aiDeveloperTools:
            return ["SOC 2 Type II", "OpenTelemetry 1.27", "Zero Cloud Egress", "SLSA Level 3"]
        case .healthBiometrics:
            return ["HIPAA Security Rule", "HL7 FHIR R4", "GDPR Art. 9", "On-Device Enclave"]
        case .commerceLogistics:
            return ["FDA 21 CFR Part 11", "GDP Cold-Chain", "GS1 EPCIS 2.0", "EMV Contactless"]
        case .productivityCollab:
            return ["FIDO2 / WebAuthn", "RFC 9180 HPKE", "CRDT Causal Order", "WCAG 2.2 AA"]
        case .mediaCreator:
            return ["ITU-R BS.1770-4", "ACEScg Linear Color", "SMPTE Timecode", "NDI / SRT Low-Latency"]
        case .educationScience:
            return ["FSRS-5 Memory Model", "IAU J2000 Ephemeris", "GLP Audit Trail", "FAIR Data"]
        case .smartHomeMobility:
            return ["CSA Matter 1.3", "OCPI 2.2.1 EV", "FAA Part 107 / U-Space", "MAVLink v2"]
        case .enterpriseSecurity:
            return ["MITRE ATT&CK v15", "NIST SP 800-207 ZTA", "CIS Apple Benchmarks", "ASC 606 Metering"]
        }
    }

    public var blueprintIDs: [EnterpriseBlueprintID] {
        EnterpriseBlueprintID.allCases.filter { $0.vertical == self }
    }
}

// MARK: - 28 Canonical Enterprise Blueprint Identifiers

/// Strongly-typed identifier for each of the 28 full-stack enterprise blueprints.
public enum EnterpriseBlueprintID: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    // 1. Fintech & Banking (3)
    case neobankMultiCurrencyTreasury
    case quantPortfolioAndOrderBook
    case escrowSplitBillingLedger

    // 2. AI & Developer Tools (3)
    case localRAGKnowledgeWorkbench
    case cicdFleetIncidentCommander
    case gitDiffPullRequestStudio

    // 3. Health & Biometrics (3)
    case clinicalVitalsLongevityLab
    case circadianSleepHRVCoach
    case telemedicinePrescriptionVault

    // 4. Commerce & Logistics (3)
    case spatialLuxuryStorefrontAR
    case coldChainFleetTelemetry
    case posKitchenDisplaySystem

    // 5. Productivity & Collaboration (3)
    case multiplayerBlockWikiDocs
    case agileSprintOKRRoadmap
    case zeroKnowledgePasskeyVault

    // 6. Media & Creator (3)
    case nonlinearPodcastMasteringDAW
    case rawPhotoColorGradingDarkroom
    case liveStreamSceneSwitcher

    // 7. Education & Science (3)
    case fsrsSpacedRepetitionAcademy
    case celestialObservatoryPlanner
    case molecularProtocolLabNotebook

    // 8. Smart Home & Mobility (3)
    case matterSolarEnergyMicrogrid
    case evCockpitChargingPlanner
    case autonomousDroneMissionControl

    // 9. Enterprise & Security (4)
    case socSIEMThreatHuntingConsole
    case zeroTrustMDMFleetManager
    case legalContractRedlineCopilot
    case multiTenantSaaSBillingFlags

    public var id: String { rawValue }

    public var vertical: EnterpriseVertical {
        switch self {
        case .neobankMultiCurrencyTreasury, .quantPortfolioAndOrderBook, .escrowSplitBillingLedger:
            return .fintechBanking
        case .localRAGKnowledgeWorkbench, .cicdFleetIncidentCommander, .gitDiffPullRequestStudio:
            return .aiDeveloperTools
        case .clinicalVitalsLongevityLab, .circadianSleepHRVCoach, .telemedicinePrescriptionVault:
            return .healthBiometrics
        case .spatialLuxuryStorefrontAR, .coldChainFleetTelemetry, .posKitchenDisplaySystem:
            return .commerceLogistics
        case .multiplayerBlockWikiDocs, .agileSprintOKRRoadmap, .zeroKnowledgePasskeyVault:
            return .productivityCollab
        case .nonlinearPodcastMasteringDAW, .rawPhotoColorGradingDarkroom, .liveStreamSceneSwitcher:
            return .mediaCreator
        case .fsrsSpacedRepetitionAcademy, .celestialObservatoryPlanner, .molecularProtocolLabNotebook:
            return .educationScience
        case .matterSolarEnergyMicrogrid, .evCockpitChargingPlanner, .autonomousDroneMissionControl:
            return .smartHomeMobility
        case .socSIEMThreatHuntingConsole, .zeroTrustMDMFleetManager, .legalContractRedlineCopilot, .multiTenantSaaSBillingFlags:
            return .enterpriseSecurity
        }
    }

    /// Clean PascalCase SwiftPM executable/module name for generated workspaces.
    public var defaultAppTargetName: String {
        switch self {
        case .neobankMultiCurrencyTreasury: return "NeobankTreasuryDesk"
        case .quantPortfolioAndOrderBook: return "QuantOrderBookPro"
        case .escrowSplitBillingLedger: return "EscrowSplitLedger"
        case .localRAGKnowledgeWorkbench: return "LocalRAGWorkbench"
        case .cicdFleetIncidentCommander: return "CICDIncidentCommander"
        case .gitDiffPullRequestStudio: return "GitDiffPRStudio"
        case .clinicalVitalsLongevityLab: return "LongevityVitalsLab"
        case .circadianSleepHRVCoach: return "CircadianHRVCoach"
        case .telemedicinePrescriptionVault: return "TelemedicineRxVault"
        case .spatialLuxuryStorefrontAR: return "SpatialLuxuryAtelier"
        case .coldChainFleetTelemetry: return "ColdChainTelemetry"
        case .posKitchenDisplaySystem: return "KitchenCourseKDS"
        case .multiplayerBlockWikiDocs: return "MultiplayerBlockWiki"
        case .agileSprintOKRRoadmap: return "AgileOKRRoadmap"
        case .zeroKnowledgePasskeyVault: return "ZeroKnowledgeVault"
        case .nonlinearPodcastMasteringDAW: return "PodcastMasteringDAW"
        case .rawPhotoColorGradingDarkroom: return "RAWColorDarkroom"
        case .liveStreamSceneSwitcher: return "LiveSceneDirector"
        case .fsrsSpacedRepetitionAcademy: return "FSRSMemoryAcademy"
        case .celestialObservatoryPlanner: return "CelestialPlanner"
        case .molecularProtocolLabNotebook: return "MolecularLabNotebook"
        case .matterSolarEnergyMicrogrid: return "MatterSolarMicrogrid"
        case .evCockpitChargingPlanner: return "EVCockpitPlanner"
        case .autonomousDroneMissionControl: return "DroneMissionControl"
        case .socSIEMThreatHuntingConsole: return "SOCThreatHunter"
        case .zeroTrustMDMFleetManager: return "ZeroTrustMDMFleet"
        case .legalContractRedlineCopilot: return "ContractRedlineStudio"
        case .multiTenantSaaSBillingFlags: return "MultiTenantSaaSControl"
        }
    }

    public var defaultBundleIdentifier: String {
        let kebab = rawValue.reduce(into: "") { acc, ch in
            if ch.isUppercase {
                acc.append("-")
                acc.append(ch.lowercased())
            } else {
                acc.append(ch)
            }
        }
        return "com.hnmlabs.chiefkit.\(kebab)"
    }
}

// MARK: - Toggleable Architectural Layers & Target Platforms

/// Toggleable full-stack architectural layers synthesized into generated ChiefKit workspaces.
public enum EnterpriseLayerKind: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case swiftBlocksUI
    case swiftStateReducer
    case swiftDataPersistence
    case restAPIClient
    case notebookOnboarding
    case localAICopilot
    case securityPrivacy
    case swiftTestingSuite

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .swiftBlocksUI:
            return "SwiftBlocks Liquid Glass UI"
        case .swiftStateReducer:
            return "SwiftState Deterministic Reducer"
        case .swiftDataPersistence:
            return "SwiftData + SQLite Persistence"
        case .restAPIClient:
            return "Typed Async REST API Client"
        case .notebookOnboarding:
            return "NotebookFlowKit JSON Onboarding"
        case .localAICopilot:
            return "CoreLocalAIKit On-Device Copilot"
        case .securityPrivacy:
            return "CryptoKit Vault & Privacy Manifest"
        case .swiftTestingSuite:
            return "Swift Testing (@Test) Verification"
        }
    }

    public var subtitle: String {
        switch self {
        case .swiftBlocksUI:
            return "Tokenized EDKSurface cards, WCAG-checked colors, Dynamic Type scaling, and specular glass."
        case .swiftStateReducer:
            return "Pure value-type state transitions, undo/time-travel compatibility, and structured async effects."
        case .swiftDataPersistence:
            return "@Model persistence schema paired with portable SQLite DDL migrations and repository actors."
        case .restAPIClient:
            return "Sendable URLSession actor with retry backoff, idempotency headers, and offline preview stubs."
        case .notebookOnboarding:
            return "Validated multi-step first-run onboarding topology encoded as portable NotebookFlowKit JSON."
        case .localAICopilot:
            return "Zero-cloud NaturalLanguage & FoundationModels copilot heuristics running locally on Apple Silicon."
        case .securityPrivacy:
            return "Keychain/AES-GCM field sealing, App Store PrivacyInfo.xcprivacy declarations, and audit logs."
        case .swiftTestingSuite:
            return "Deterministic @Suite and @Test specifications verifying reducers, domain math, and invariants."
        }
    }

    public var sfSymbol: String {
        switch self {
        case .swiftBlocksUI: return "square.grid.3x3.topleft.filled"
        case .swiftStateReducer: return "point.3.connected.trianglepath.dotted"
        case .swiftDataPersistence: return "cylinder.split.1x2.fill"
        case .restAPIClient: return "network"
        case .notebookOnboarding: return "rectangle.on.rectangle.angled"
        case .localAICopilot: return "cpu.fill"
        case .securityPrivacy: return "checkmark.shield.fill"
        case .swiftTestingSuite: return "checkmark.seal.fill"
        }
    }

    public var packageDemo: PackageDemo? {
        switch self {
        case .swiftBlocksUI: return .swiftBlocks
        case .swiftStateReducer: return .swiftState
        case .notebookOnboarding: return .notebookFlowKit
        case .localAICopilot: return .coreLocalAIKit
        case .swiftDataPersistence, .restAPIClient, .securityPrivacy, .swiftTestingSuite:
            return nil
        }
    }
}

/// Target Apple OS deployment platforms supported by a blueprint.
public enum TargetApplePlatform: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case macOS
    case iOS
    case iPadOS
    case visionOS
    case watchOS

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .macOS: return "macOS 14+"
        case .iOS: return "iOS 17+"
        case .iPadOS: return "iPadOS 17+"
        case .visionOS: return "visionOS 2+"
        case .watchOS: return "watchOS 10+"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .macOS: return "laptopcomputer"
        case .iOS: return "iphone"
        case .iPadOS: return "ipad.landscape"
        case .visionOS: return "visionpro"
        case .watchOS: return "applewatch"
        }
    }

    /// SwiftPM `SupportedPlatform` clause (note: iPadOS shares `.iOS(.v17)` in `Package.swift`).
    public var spmPlatformClause: String? {
        switch self {
        case .macOS: return ".macOS(.v14)"
        case .iOS, .iPadOS: return ".iOS(.v17)"
        case .visionOS: return ".visionOS(.v2)"
        case .watchOS: return ".watchOS(.v10)"
        }
    }
}

/// Engineering depth & operational criticality tier of a blueprint.
public enum BlueprintComplexityTier: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case professional = "Professional"
    case enterprise = "Enterprise"
    case missionCritical = "Mission-Critical"

    public var id: String { rawValue }

    public var estimatedWeeksSaved: Int {
        switch self {
        case .professional: return 4
        case .enterprise: return 7
        case .missionCritical: return 11
        }
    }
}

// MARK: - Domain, State, Persistence, API & Localization Sub-Models

public struct BlueprintEntityField: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let swiftType: String
    public let sqlType: String
    public let defaultValueLiteral: String
    public let isIndexed: Bool
    public let summary: String

    public init(
        name: String,
        swiftType: String,
        sqlType: String = "TEXT NOT NULL",
        defaultValueLiteral: String,
        isIndexed: Bool = false,
        summary: String
    ) {
        self.name = name
        self.swiftType = swiftType
        self.sqlType = sqlType
        self.defaultValueLiteral = defaultValueLiteral
        self.isIndexed = isIndexed
        self.summary = summary
    }
}

public struct BlueprintDomainEntity: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let tableName: String
    public let summary: String
    public let fields: [BlueprintEntityField]
    public let computedHelpersSwift: String

    public init(
        name: String,
        tableName: String,
        summary: String,
        fields: [BlueprintEntityField],
        computedHelpersSwift: String
    ) {
        self.name = name
        self.tableName = tableName
        self.summary = summary
        self.fields = fields
        self.computedHelpersSwift = computedHelpersSwift
    }
}

public struct BlueprintStateProperty: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let swiftType: String
    public let initialValueLiteral: String
    public let summary: String

    public init(
        name: String,
        swiftType: String,
        initialValueLiteral: String,
        summary: String
    ) {
        self.name = name
        self.swiftType = swiftType
        self.initialValueLiteral = initialValueLiteral
        self.summary = summary
    }
}

public struct BlueprintReducerAction: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { caseDeclaration }
    public let caseDeclaration: String
    public let matchPattern: String
    public let buttonTitle: String?
    public let sampleDispatchLiteral: String?
    public let summary: String
    public let mutationBodySwift: String

    public init(
        caseDeclaration: String,
        matchPattern: String,
        buttonTitle: String? = nil,
        sampleDispatchLiteral: String? = nil,
        summary: String,
        mutationBodySwift: String
    ) {
        self.caseDeclaration = caseDeclaration
        self.matchPattern = matchPattern
        self.buttonTitle = buttonTitle
        self.sampleDispatchLiteral = sampleDispatchLiteral
        self.summary = summary
        self.mutationBodySwift = mutationBodySwift
    }
}

public enum BlueprintHTTPMethod: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public struct BlueprintAPIEndpoint: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { "\(method.rawValue) \(path)" }
    public let methodName: String
    public let method: BlueprintHTTPMethod
    public let path: String
    public let requestPayloadType: String?
    public let responseType: String
    public let requiresIdempotencyKey: Bool
    public let timeoutSeconds: Int
    public let offlineStubSwift: String
    public let summary: String

    public init(
        methodName: String,
        method: BlueprintHTTPMethod,
        path: String,
        requestPayloadType: String? = nil,
        responseType: String,
        requiresIdempotencyKey: Bool = false,
        timeoutSeconds: Int = 15,
        offlineStubSwift: String,
        summary: String
    ) {
        self.methodName = methodName
        self.method = method
        self.path = path
        self.requestPayloadType = requestPayloadType
        self.responseType = responseType
        self.requiresIdempotencyKey = requiresIdempotencyKey
        self.timeoutSeconds = timeoutSeconds
        self.offlineStubSwift = offlineStubSwift
        self.summary = summary
    }
}

public struct BlueprintKPIMetric: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { key }
    public let key: String
    public let label: String
    public let value: String
    public let delta: String
    public let sfSymbol: String
    public let isFavorable: Bool

    public init(
        key: String,
        label: String,
        value: String,
        delta: String,
        sfSymbol: String,
        isFavorable: Bool = true
    ) {
        self.key = key
        self.label = label
        self.value = value
        self.delta = delta
        self.sfSymbol = sfSymbol
        self.isFavorable = isFavorable
    }
}

public struct BlueprintSampleRecord: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let headline: String
    public let subheadline: String
    public let trailingMetric: String
    public let statusTag: String

    public init(
        id: String,
        headline: String,
        subheadline: String,
        trailingMetric: String,
        statusTag: String
    ) {
        self.id = id
        self.headline = headline
        self.subheadline = subheadline
        self.trailingMetric = trailingMetric
        self.statusTag = statusTag
    }
}

public struct BlueprintLocalizedKey: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { key }
    public let key: String
    public let en: String
    public let tr: String

    public init(key: String, en: String, tr: String) {
        self.key = key
        self.en = en
        self.tr = tr
    }
}

public struct BlueprintPrivacyAPICategory: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { categoryIdentifier }
    public let categoryIdentifier: String
    public let reasonCodes: [String]
    public let purposeSummary: String

    public init(categoryIdentifier: String, reasonCodes: [String], purposeSummary: String) {
        self.categoryIdentifier = categoryIdentifier
        self.reasonCodes = reasonCodes
        self.purposeSummary = purposeSummary
    }
}

// MARK: - Complete Enterprise Blueprint Descriptor & Multi-Layer Synthesizers

/// Complete strongly-typed full-stack specification for a production ChiefKit 3.0 Enterprise Blueprint.
public struct EnterpriseBlueprintSpec: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: EnterpriseBlueprintID
    public let vertical: EnterpriseVertical
    public let title: String
    public let subtitle: String
    public let sfSymbol: String
    public let complexityTier: BlueprintComplexityTier
    public let supportedPlatforms: [TargetApplePlatform]
    public let domainEntities: [BlueprintDomainEntity]
    public let stateProperties: [BlueprintStateProperty]
    public let reducerActions: [BlueprintReducerAction]
    public let apiEndpoints: [BlueprintAPIEndpoint]
    public let kpiMetrics: [BlueprintKPIMetric]
    public let sampleRecords: [BlueprintSampleRecord]
    public let onboardingPages: [FlowPage]
    public let localizationKeysTR_EN: [BlueprintLocalizedKey]
    public let privacyAPICategories: [BlueprintPrivacyAPICategory]

    /// Authentic domain-specific computed properties synthesized directly onto `<App>State`.
    public let customStateComputedSwift: String
    /// Authentic domain-specific SwiftUI inspector/control section embedded in `RootWorkbenchView`.
    public let customSwiftUIInspectorSwift: String
    /// Authentic domain-specific on-device copilot routine using Apple frameworks with zero cloud calls.
    public let localAICopilotRoutineSwift: String
    /// Authentic domain-specific `@Test` methods verifying domain math, state transitions, and edge cases.
    public let customUnitTestsSwift: String
    /// Security & encryption architecture notes included in generated security layer & README.
    public let securityPostureHighlights: [String]

    public init(
        id: EnterpriseBlueprintID,
        vertical: EnterpriseVertical,
        title: String,
        subtitle: String,
        sfSymbol: String,
        complexityTier: BlueprintComplexityTier,
        supportedPlatforms: [TargetApplePlatform],
        domainEntities: [BlueprintDomainEntity],
        stateProperties: [BlueprintStateProperty],
        reducerActions: [BlueprintReducerAction],
        apiEndpoints: [BlueprintAPIEndpoint],
        kpiMetrics: [BlueprintKPIMetric],
        sampleRecords: [BlueprintSampleRecord],
        onboardingPages: [FlowPage],
        localizationKeysTR_EN: [BlueprintLocalizedKey],
        privacyAPICategories: [BlueprintPrivacyAPICategory],
        customStateComputedSwift: String,
        customSwiftUIInspectorSwift: String,
        localAICopilotRoutineSwift: String,
        customUnitTestsSwift: String,
        securityPostureHighlights: [String]
    ) {
        self.id = id
        self.vertical = vertical
        self.title = title
        self.subtitle = subtitle
        self.sfSymbol = sfSymbol
        self.complexityTier = complexityTier
        self.supportedPlatforms = supportedPlatforms
        self.domainEntities = domainEntities
        self.stateProperties = stateProperties
        self.reducerActions = reducerActions
        self.apiEndpoints = apiEndpoints
        self.kpiMetrics = kpiMetrics
        self.sampleRecords = sampleRecords
        self.onboardingPages = onboardingPages
        self.localizationKeysTR_EN = localizationKeysTR_EN
        self.privacyAPICategories = privacyAPICategories
        self.customStateComputedSwift = customStateComputedSwift
        self.customSwiftUIInspectorSwift = customSwiftUIInspectorSwift
        self.localAICopilotRoutineSwift = localAICopilotRoutineSwift
        self.customUnitTestsSwift = customUnitTestsSwift
        self.securityPostureHighlights = securityPostureHighlights
    }

    /// PascalCase prefix used across generated types for this blueprint.
    public var typePrefix: String {
        id.defaultAppTargetName
    }

    /// Strongly-typed `FlowDefinition` ready for validation or serialization.
    public var onboardingFlowDefinition: FlowDefinition {
        FlowDefinition(title: "\(title) Onboarding", pages: onboardingPages)
    }

    /// Required HNMLabs SwiftPM packages for a selected set of layers.
    public func requiredPackages(for layers: [EnterpriseLayerKind] = EnterpriseLayerKind.allCases) -> [PackageDemo] {
        var result: [PackageDemo] = []
        for layer in EnterpriseLayerKind.allCases where layers.contains(layer) {
            if let pkg = layer.packageDemo, !result.contains(pkg) {
                result.append(pkg)
            }
        }
        return result
    }

    // MARK: Synthesizer 1 — Domain Models (`DomainModels.swift`)

    public func synthesizeDomainModels(includeSecurityHelpers: Bool = true) -> String {
        let entityBlocks = domainEntities.map { entity -> String in
            let storedProperties = entity.fields.map { field in
                "    /// \(field.summary)\n    public var \(field.name): \(field.swiftType)"
            }.joined(separator: "\n")

            let initParameters = entity.fields.map { field in
                "        \(field.name): \(field.swiftType) = \(field.defaultValueLiteral)"
            }.joined(separator: ",\n")

            let initAssignments = entity.fields.map { field in
                "        self.\(field.name) = \(field.name)"
            }.joined(separator: "\n")

            return """
            /// \(entity.summary)
            public struct \(entity.name): Identifiable, Codable, Equatable, Hashable, Sendable {
            \(storedProperties)

                public init(
            \(initParameters)
                ) {
            \(initAssignments)
                }

            \(entity.computedHelpersSwift.indented(by: 4))
            }
            """
        }.joined(separator: "\n\n")

        let kpiRecords = kpiMetrics.map { metric in
            """
                    WorkbenchKPISnapshot(
                        key: "\(metric.key)",
                        label: "\(escapedSwiftString(metric.label))",
                        value: "\(escapedSwiftString(metric.value))",
                        delta: "\(escapedSwiftString(metric.delta))",
                        sfSymbol: "\(metric.sfSymbol)",
                        isFavorable: \(metric.isFavorable)
                    )
            """
        }.joined(separator: ",\n")

        let sampleSeed = sampleRecords.map { rec in
            """
                    WorkbenchPreviewRow(
                        id: "\(escapedSwiftString(rec.id))",
                        headline: "\(escapedSwiftString(rec.headline))",
                        subheadline: "\(escapedSwiftString(rec.subheadline))",
                        trailingMetric: "\(escapedSwiftString(rec.trailingMetric))",
                        statusTag: "\(escapedSwiftString(rec.statusTag))"
                    )
            """
        }.joined(separator: ",\n")

        let securityVaultBlock = includeSecurityHelpers ? """

        // MARK: - Zero-Trust Field Integrity & Audit Envelope

        public struct \(typePrefix)AuditSeal: Codable, Equatable, Hashable, Sendable {
            public let blueprintID: String
            public let actorRole: String
            public let recordedAtISO8601: String
            public let payloadChecksumHex: String

            public init(actorRole: String = "system", payload: String) {
                self.blueprintID = "\(id.rawValue)"
                self.actorRole = actorRole
                self.recordedAtISO8601 = ISO8601DateFormatter().string(from: Date())
                var fnv: UInt64 = 14695981039346656037
                for byte in payload.utf8 {
                    fnv ^= UInt64(byte)
                    fnv &*= 1099511628211
                }
                self.payloadChecksumHex = String(format: "%016llx", fnv)
            }
        }
        """ : ""

        return """
        import Foundation

        // MARK: - \(title) — Domain Value Models
        // Vertical: \(vertical.title) | Complexity: \(complexityTier.rawValue)

        \(entityBlocks)

        public struct WorkbenchKPISnapshot: Identifiable, Codable, Equatable, Hashable, Sendable {
            public var id: String { key }
            public let key: String
            public var label: String
            public var value: String
            public var delta: String
            public let sfSymbol: String
            public var isFavorable: Bool

            public static let defaultMetrics: [WorkbenchKPISnapshot] = [
        \(kpiRecords)
            ]
        }

        public struct WorkbenchPreviewRow: Identifiable, Codable, Equatable, Hashable, Sendable {
            public let id: String
            public var headline: String
            public var subheadline: String
            public var trailingMetric: String
            public var statusTag: String

            public static let seededRows: [WorkbenchPreviewRow] = [
        \(sampleSeed)
            ]
        }\(securityVaultBlock)
        """
    }

    // MARK: Synthesizer 2 — Unidirectional Reducer & Store (`AppReducer.swift`)

    public func synthesizeReducerAndStore() -> String {
        let stateProps = stateProperties.map { prop in
            "    /// \(prop.summary)\n    public var \(prop.name): \(prop.swiftType) = \(prop.initialValueLiteral)"
        }.joined(separator: "\n")

        let actionCases = reducerActions.map { act in
            "    /// \(act.summary)\n    case \(act.caseDeclaration)"
        }.joined(separator: "\n")

        let switchBranches = reducerActions.map { act in
            """
                    case \(act.matchPattern):
            \(act.mutationBodySwift.indented(by: 12))
            """
        }.joined(separator: "\n")

        return """
        import Foundation
        import Observation

        // MARK: - \(title) — Deterministic Swift 6 State & Reducer

        public struct \(typePrefix)State: Codable, Equatable, Sendable {
        \(stateProps)
            public var kpiSnapshots: [WorkbenchKPISnapshot] = WorkbenchKPISnapshot.defaultMetrics
            public var previewRows: [WorkbenchPreviewRow] = WorkbenchPreviewRow.seededRows
            public var hasCompletedOnboarding: Bool = false
            public var isSyncingRemote: Bool = false
            public var lastAuditMessage: String = "Initialized deterministic store"
            public var mutationCounter: Int = 0

            public init() {}

        \(customStateComputedSwift.indented(by: 4))
        }

        public enum \(typePrefix)Action: Equatable, Sendable {
        \(actionCases)
            case completeOnboarding
            case setSyncing(Bool)
            case recordAudit(String)
        }

        public enum \(typePrefix)Reducer: Sendable {
            @discardableResult
            public static func reduce(
                state: inout \(typePrefix)State,
                action: \(typePrefix)Action
            ) -> \(typePrefix)AuditSeal {
                state.mutationCounter += 1
                switch action {
        \(switchBranches)
                case .completeOnboarding:
                    state.hasCompletedOnboarding = true
                    state.lastAuditMessage = "Completed onboarding flow"
                case .setSyncing(let flag):
                    state.isSyncingRemote = flag
                    state.lastAuditMessage = flag ? "Started remote sync" : "Completed remote sync"
                case .recordAudit(let note):
                    state.lastAuditMessage = note
                }
                return \(typePrefix)AuditSeal(payload: "\\(state.mutationCounter):\\(state.lastAuditMessage)")
            }
        }

        @MainActor
        @Observable
        public final class \(typePrefix)Store {
            public private(set) var state: \(typePrefix)State
            public private(set) var history: [\(typePrefix)State] = []
            public private(set) var auditTrail: [\(typePrefix)AuditSeal] = []

            public init(initialState: \(typePrefix)State = \(typePrefix)State()) {
                self.state = initialState
            }

            public func send(_ action: \(typePrefix)Action) {
                history.append(state)
                if history.count > 64 {
                    history.removeFirst()
                }
                let seal = \(typePrefix)Reducer.reduce(state: &state, action: action)
                auditTrail.append(seal)
            }

            public func undoLastTransition() {
                guard let previous = history.popLast() else { return }
                state = previous
            }
        }
        """
    }

    // MARK: Synthesizer 3 — SwiftData & SQLite Schema (`PersistenceSchema.swift`)

    public func synthesizeSwiftDataModels() -> String {
        let modelClasses = domainEntities.map { entity -> String in
            let fieldsCode = entity.fields.map { field -> String in
                let attr = field.name == "id" ? "    @Attribute(.unique)\n" : ""
                return "\(attr)    public var \(field.name): \(field.swiftType)"
            }.joined(separator: "\n")

            let initArgs = entity.fields.map { field in
                "        \(field.name): \(field.swiftType) = \(field.defaultValueLiteral)"
            }.joined(separator: ",\n")

            let initBody = entity.fields.map { field in
                "        self.\(field.name) = \(field.name)"
            }.joined(separator: "\n")

            let toDomainArgs = entity.fields.map { field in
                "            \(field.name): \(field.name)"
            }.joined(separator: ",\n")

            return """
            #if canImport(SwiftData)
            @Model
            public final class Persistent\(entity.name) {
            \(fieldsCode)

                public init(
            \(initArgs)
                ) {
            \(initBody)
                }

                public func toValueModel() -> \(entity.name) {
                    \(entity.name)(
            \(toDomainArgs)
                    )
                }
            }
            #endif
            """
        }.joined(separator: "\n\n")

        let ddlStatements = domainEntities.map { entity -> String in
            let cols = entity.fields.map { field -> String in
                let pk = field.name == "id" ? " PRIMARY KEY" : ""
                return "        \(field.name) \(field.sqlType)\(pk)"
            }.joined(separator: ",\n")

            let idxStatements = entity.fields.filter(\.isIndexed).map { field in
                "    CREATE INDEX IF NOT EXISTS idx_\(entity.tableName)_\(field.name) ON \(entity.tableName)(\(field.name));"
            }.joined(separator: "\n")

            return """
                CREATE TABLE IF NOT EXISTS \(entity.tableName) (
            \(cols)
                );
            \(idxStatements)
            """
        }.joined(separator: "\n\n")

        let entityNamesList = domainEntities.map { "Persistent\($0.name).self" }.joined(separator: ", ")

        return """
        import Foundation
        #if canImport(SwiftData)
        import SwiftData
        #endif

        // MARK: - \(title) — SwiftData @Model & Portable SQLite Schema

        \(modelClasses)

        public enum \(typePrefix)PersistenceSchema: Sendable {
            public static let schemaVersion = "3.0.0"

            /// Portable SQLite WAL migration script for cross-platform local-first storage.
            public static let sqliteMigrationDDL: String = \"\"\"
            PRAGMA journal_mode = WAL;
            PRAGMA foreign_keys = ON;

        \(ddlStatements)
            \"\"\"

            #if canImport(SwiftData)
            public static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
                let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
                return try ModelContainer(
                    for: \(entityNamesList),
                    configurations: configuration
                )
            }
            #endif
        }

        /// Thread-safe in-memory & JSON snapshot repository actor for offline-first workflows.
        public actor \(typePrefix)LocalRepository {
            private var snapshotsByKey: [String: Data] = [:]
            private let encoder = JSONEncoder()
            private let decoder = JSONDecoder()

            public init() {}

            public func save<T: Codable & Sendable>(_ value: T, key: String) throws {
                snapshotsByKey[key] = try encoder.encode(value)
            }

            public func load<T: Codable & Sendable>(_ type: T.Type, key: String) throws -> T? {
                guard let data = snapshotsByKey[key] else { return nil }
                return try decoder.decode(T.self, from: data)
            }

            public func storedKeys() -> [String] {
                snapshotsByKey.keys.sorted()
            }
        }
        """
    }

    // MARK: Synthesizer 4 — Typed Async REST API Client (`APIClient.swift`)

    public func synthesizeAPIClient() -> String {
        let endpointMethods = apiEndpoints.map { ep -> String in
            let paramSig: String
            let bodyEncodingBlock: String
            if let payload = ep.requestPayloadType {
                paramSig = "payload: \(payload), idempotencyKey: String? = nil"
                bodyEncodingBlock = """
                        request.httpBody = try encoder.encode(payload)
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                """
            } else {
                paramSig = "idempotencyKey: String? = nil"
                bodyEncodingBlock = ""
            }

            let idemLine = ep.requiresIdempotencyKey ? """
                    let resolvedKey = idempotencyKey ?? UUID().uuidString
                    request.setValue(resolvedKey, forHTTPHeaderField: "Idempotency-Key")
            """ : """
                    if let idempotencyKey {
                        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
                    }
            """

            return """
                /// \(ep.summary) (`\(ep.method.rawValue) \(ep.path)`)
                public func \(ep.methodName)(\(paramSig)) async throws -> \(ep.responseType) {
                    if useOfflinePreviewStubs {
                        return \(ep.offlineStubSwift)
                    }
                    let endpointURL = baseURL.appendingPathComponent("\(ep.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")
                    var request = URLRequest(url: endpointURL, timeoutInterval: \(ep.timeoutSeconds))
                    request.httpMethod = "\(ep.method.rawValue)"
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    if let bearerToken = bearerTokenProvider?() {
                        request.setValue("Bearer \\(bearerToken)", forHTTPHeaderField: "Authorization")
                    }
            \(idemLine)
            \(bodyEncodingBlock)
                    let (data, response) = try await session.data(for: request)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw \(typePrefix)APIError.unexpectedStatusCode((response as? HTTPURLResponse)?.statusCode ?? -1)
                    }
                    return try decoder.decode(\(ep.responseType).self, from: data)
                }
            """
        }.joined(separator: "\n\n")

        return """
        import Foundation
        #if canImport(FoundationNetworking)
        import FoundationNetworking
        #endif

        // MARK: - \(title) — Sendable Async REST API Client

        public enum \(typePrefix)APIError: Error, Equatable, Sendable {
            case invalidEndpoint(String)
            case unexpectedStatusCode(Int)
            case transportFailure(String)
        }

        public actor \(typePrefix)APIClient {
            public let baseURL: URL
            public let useOfflinePreviewStubs: Bool
            private let session: URLSession
            private let encoder: JSONEncoder
            private let decoder: JSONDecoder
            private let bearerTokenProvider: (@Sendable () -> String?)?

            public init(
                baseURL: URL = URL(string: "https://api.chiefkit.example")!,
                useOfflinePreviewStubs: Bool = true,
                session: URLSession = .shared,
                bearerTokenProvider: (@Sendable () -> String?)? = nil
            ) {
                self.baseURL = baseURL
                self.useOfflinePreviewStubs = useOfflinePreviewStubs
                self.session = session
                self.bearerTokenProvider = bearerTokenProvider
                let enc = JSONEncoder()
                enc.dateEncodingStrategy = .iso8601
                self.encoder = enc
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .iso8601
                self.decoder = dec
            }

        \(endpointMethods)
        }
        """
    }

    // MARK: Synthesizer 5 — SwiftUI Tokenized Workbench View (`RootWorkbenchView.swift`)

    public func synthesizeSwiftUIView(
        theme: StudioThemeTokens = StudioThemeTokens(),
        layers: [EnterpriseLayerKind] = EnterpriseLayerKind.allCases
    ) -> String {
        let radiusMedium = Int(theme.radiusMedium.rounded())
        let spacingMD = Int(Double(theme.spacingMD).rounded())
        let hasOnboarding = layers.contains(.notebookOnboarding)
        let hasAI = layers.contains(.localAICopilot)

        let actionButtons = reducerActions.compactMap { act -> String? in
            guard let title = act.buttonTitle, let dispatch = act.sampleDispatchLiteral else {
                return nil
            }
            return """
                            Button("\(escapedSwiftString(title))") {
                                store.send(\(dispatch))
                            }
                            .buttonStyle(.borderedProminent)
            """
        }.joined(separator: "\n")

        let onboardingBanner = hasOnboarding ? """
                    if !store.state.hasCompletedOnboarding {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("\(escapedSwiftString(title)) Setup Flow", systemImage: "sparkles.rectangle.stack")
                                .font(.headline)
                            Text("\(escapedSwiftString(onboardingPages.first?.body ?? subtitle))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Complete Guided Setup") {
                                store.send(.completeOnboarding)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(\(spacingMD))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: \(radiusMedium), style: .continuous))
                    }
        """ : ""

        let copilotBar = hasAI ? """
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("On-Device Copilot (0 Cloud Calls)", systemImage: "cpu.fill")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Analyze Workspace") {
                                copilotOutput = runOnDeviceCopilot(state: store.state)
                            }
                            .controlSize(.small)
                        }
                        Text(copilotOutput)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(\(spacingMD))
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: \(radiusMedium), style: .continuous))
        """ : ""

        let copilotHelperFunc = hasAI ? """

            private func runOnDeviceCopilot(state: \(typePrefix)State) -> String {
        \(localAICopilotRoutineSwift.indented(by: 8))
            }
        """ : ""

        return """
        import SwiftUI
        #if canImport(NaturalLanguage)
        import NaturalLanguage
        #endif

        // MARK: - \(title) — Tokenized Root Workbench View
        // Theme Primary: \(theme.primary.hexString) | Liquid Glass: \(theme.isLiquidGlassEnabled ? "Enabled" : "Standard")

        public struct \(typePrefix)WorkbenchView: View {
            @State private var store = \(typePrefix)Store()
            @State private var searchQuery: String = ""
            @State private var copilotOutput: String = "Local copilot idle — deterministic state ready."
            @ScaledMetric(relativeTo: .body) private var sectionSpacing: CGFloat = \(spacingMD)

            private let accentTint = \(theme.primary.swiftInitializer)

            public init() {}

            public var body: some View {
                ScrollView {
                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        headerBar
        \(onboardingBanner)
                        kpiGrid
        \(customSwiftUIInspectorSwift.indented(by: 16))
                        recordsSection
        \(copilotBar)
                    }
                    .padding(\(spacingMD))
                }
                .tint(accentTint)
                .searchable(text: $searchQuery, prompt: "Filter \(escapedSwiftString(title))")
            }

            private var headerBar: some View {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "\(sfSymbol)")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(accentTint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(escapedSwiftString(title))")
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("\(escapedSwiftString(subtitle))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Undo") {
                        store.undoLastTransition()
                    }
                    .disabled(store.history.isEmpty)
                }
            }

            private var kpiGrid: some View {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    ForEach(store.state.kpiSnapshots) { metric in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: metric.sfSymbol)
                                    .foregroundStyle(accentTint)
                                Spacer()
                                Text(metric.delta)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }
                            Text(metric.value)
                                .font(.title3.monospacedDigit().bold())
                            Text(metric.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: \(radiusMedium), style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            private var recordsSection: some View {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Live Domain Records")
                            .font(.headline)
                        Spacer()
        \(actionButtons)
                    }

                    ForEach(filteredRows) { row in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.headline)
                                    .font(.subheadline.weight(.semibold))
                                Text(row.subheadline)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(row.trailingMetric)
                                    .font(.subheadline.monospacedDigit().weight(.medium))
                                Text(row.statusTag)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: \(radiusMedium), style: .continuous))
                    }
                }
            }

            private var filteredRows: [WorkbenchPreviewRow] {
                let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !q.isEmpty else { return store.state.previewRows }
                return store.state.previewRows.filter {
                    $0.headline.localizedCaseInsensitiveContains(q) ||
                    $0.subheadline.localizedCaseInsensitiveContains(q) ||
                    $0.statusTag.localizedCaseInsensitiveContains(q)
                }
            }\(copilotHelperFunc)
        }
        """
    }

    // MARK: Synthesizer 6 — Onboarding Flow JSON (`onboarding-flow.json`)

    public func synthesizeOnboardingFlowJSON() -> String {
        onboardingFlowDefinition.encodedPrettyJSON()
    }

    // MARK: Synthesizer 7 — Swift Testing Suite (`<App>Tests.swift`)

    public func synthesizeSwiftTests() -> String {
        return """
        import Foundation
        import Testing
        @testable import \(typePrefix)

        @Suite("\(escapedSwiftString(title)) Verification Suite")
        struct \(typePrefix)Tests {
            @Test("Initial store state seeds KPIs and domain preview rows")
            func initialSeedStateIntegrity() {
                let state = \(typePrefix)State()
                #expect(state.kpiSnapshots.count == \(kpiMetrics.count))
                #expect(state.previewRows.count == \(sampleRecords.count))
                #expect(state.hasCompletedOnboarding == false)
                #expect(state.mutationCounter == 0)
            }

            @Test("Onboarding completion and audit seal determinism")
            func onboardingTransitionProducesAuditSeal() {
                var state = \(typePrefix)State()
                let seal = \(typePrefix)Reducer.reduce(state: &state, action: .completeOnboarding)
                #expect(state.hasCompletedOnboarding == true)
                #expect(state.mutationCounter == 1)
                #expect(seal.blueprintID == "\(id.rawValue)")
                #expect(seal.payloadChecksumHex.count == 16)
            }

            @Test("Offline preview API client and local repository round-trip")
            func repositorySnapshotRoundTrip() async throws {
                let repo = \(typePrefix)LocalRepository()
                let initial = \(typePrefix)State()
                try await repo.save(initial, key: "primary-state")
                let restored = try await repo.load(\(typePrefix)State.self, key: "primary-state")
                #expect(restored == initial)
            }

        \(customUnitTestsSwift.indented(by: 4))
        }
        """
    }

    // MARK: Synthesizer 8 — Mermaid Architecture Graph

    public func synthesizeMermaidArchitecture() -> String {
        let entityNodeLines = domainEntities.enumerated().map { idx, ent in
            "    E\(idx)[\"\(ent.name) (\(ent.tableName))\"]"
        }.joined(separator: "\n")

        let entityLinks = domainEntities.indices.map { idx in
            "    Reducer --> E\(idx)\n    E\(idx) --> SwiftData"
        }.joined(separator: "\n")

        let endpointNodeLines = apiEndpoints.enumerated().map { idx, ep in
            "    API --> EP\(idx)[\"\(ep.method.rawValue) \(ep.path)\"]"
        }.joined(separator: "\n")

        return """
        flowchart TD
            UI["\(title) WorkbenchView (SwiftBlocks)"]
            Flow["NotebookFlowKit (\(onboardingPages.count) Onboarding Screens)"]
            Store["\(typePrefix)Store (@Observable)"]
            Reducer["\(typePrefix)Reducer (\(reducerActions.count) Actions)"]
            AI["CoreLocalAIKit On-Device Copilot"]
            SwiftData["SwiftData + SQLite WAL Schema"]
            API["\(typePrefix)APIClient (URLSession Actor)"]
        \(entityNodeLines)

            Flow --> Store
            UI --> Store
            Store --> Reducer
            UI --> AI
            AI --> Store
            Reducer --> API
        \(entityLinks)
        \(endpointNodeLines)
        """
    }

    // MARK: Synthesizer 9 — Unified Multi-Layer Preview

    public func synthesizeUnifiedPreview(
        theme: StudioThemeTokens = StudioThemeTokens(),
        layers: [EnterpriseLayerKind] = EnterpriseLayerKind.allCases
    ) -> String {
        var chunks: [String] = [
            "// ============================================================================",
            "// ChiefKit Studio 3.0 — Enterprise Full-Stack Blueprint Preview",
            "// Blueprint: \(title) (\(id.rawValue))",
            "// Vertical:  \(vertical.title)",
            "// Platforms: \(supportedPlatforms.map(\.displayName).joined(separator: ", "))",
            "// Layers:    \(layers.map(\.title).joined(separator: " · "))",
            "// ============================================================================",
            synthesizeDomainModels(includeSecurityHelpers: layers.contains(.securityPrivacy))
        ]

        if layers.contains(.swiftStateReducer) {
            chunks.append(synthesizeReducerAndStore())
        }
        if layers.contains(.swiftDataPersistence) {
            chunks.append(synthesizeSwiftDataModels())
        }
        if layers.contains(.restAPIClient) {
            chunks.append(synthesizeAPIClient())
        }
        if layers.contains(.swiftBlocksUI) {
            chunks.append(synthesizeSwiftUIView(theme: theme, layers: layers))
        }
        if layers.contains(.swiftTestingSuite) {
            chunks.append(synthesizeSwiftTests())
        }

        return chunks.joined(separator: "\n\n")
    }

    // MARK: Supporting Resource Generators (PrivacyInfo & Localizable.xcstrings)

    public func synthesizePrivacyManifestXML() -> String {
        let entries = privacyAPICategories.map { cat -> String in
            let reasons = cat.reasonCodes.map { "                <string>\($0)</string>" }.joined(separator: "\n")
            return """
                    <dict>
                        <key>NSPrivacyAccessedAPIType</key>
                        <string>\(cat.categoryIdentifier)</string>
                        <key>NSPrivacyAccessedAPITypeReasons</key>
                        <array>
            \(reasons)
                        </array>
                    </dict>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>NSPrivacyTracking</key>
            <false/>
            <key>NSPrivacyTrackingDomains</key>
            <array/>
            <key>NSPrivacyCollectedDataTypes</key>
            <array/>
            <key>NSPrivacyAccessedAPITypes</key>
            <array>
        \(entries)
            </array>
        </dict>
        </plist>
        """
    }

    public func synthesizeLocalizableStringsCatalogJSON() -> String {
        let stringEntries = localizationKeysTR_EN.sorted { $0.key < $1.key }.map { pair -> String in
            let enEsc = escapedJSONString(pair.en)
            let trEsc = escapedJSONString(pair.tr)
            let keyEsc = escapedJSONString(pair.key)
            return """
                "\(keyEsc)" : {
                  "extractionState" : "manual",
                  "localizations" : {
                    "en" : {
                      "stringUnit" : {
                        "state" : "translated",
                        "value" : "\(enEsc)"
                      }
                    },
                    "tr" : {
                      "stringUnit" : {
                        "state" : "translated",
                        "value" : "\(trEsc)"
                      }
                    }
                  }
                }
            """
        }.joined(separator: ",\n")

        return """
        {
          "sourceLanguage" : "en",
          "strings" : {
        \(stringEntries)
          },
          "version" : "1.0"
        }
        """
    }

    private func escapedSwiftString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func escapedJSONString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

// MARK: - Central Blueprint Registry & Query Engine

public struct BlueprintCatalogSummary: Codable, Equatable, Sendable {
    public let verticalCount: Int
    public let blueprintCount: Int
    public let totalDomainEntities: Int
    public let totalReducerActions: Int
    public let totalAPIEndpoints: Int
    public let totalOnboardingScreens: Int
    public let totalLocalizedKeys: Int

    public init(specs: [EnterpriseBlueprintSpec]) {
        self.verticalCount = EnterpriseVertical.allCases.count
        self.blueprintCount = specs.count
        self.totalDomainEntities = specs.reduce(0) { $0 + $1.domainEntities.count }
        self.totalReducerActions = specs.reduce(0) { $0 + $1.reducerActions.count }
        self.totalAPIEndpoints = specs.reduce(0) { $0 + $1.apiEndpoints.count }
        self.totalOnboardingScreens = specs.reduce(0) { $0 + $1.onboardingPages.count }
        self.totalLocalizedKeys = specs.reduce(0) { $0 + $1.localizationKeysTR_EN.count }
    }
}

/// Central thread-safe catalog exposing all 28 ChiefKit 3.0 Enterprise Blueprints.
public enum EnterpriseBlueprintCatalog: Sendable {
    /// Complete ordered list of all 28 industry blueprints across 9 verticals.
    public static let allSpecs: [EnterpriseBlueprintSpec] = {
        var specs: [EnterpriseBlueprintSpec] = []
        specs.append(contentsOf: FintechAndBankingBlueprints.specs)
        specs.append(contentsOf: AIAndDeveloperToolsBlueprints.specs)
        specs.append(contentsOf: HealthAndBiometricsBlueprints.specs)
        specs.append(contentsOf: CommerceAndLogisticsBlueprints.specs)
        specs.append(contentsOf: ProductivityAndCollabBlueprints.specs)
        specs.append(contentsOf: MediaAndCreatorBlueprints.specs)
        specs.append(contentsOf: EducationAndScienceBlueprints.specs)
        specs.append(contentsOf: SmartHomeAndAutomotiveBlueprints.specs)
        specs.append(contentsOf: EnterpriseAndSecurityBlueprints.specs)
        return specs
    }()

    private static let specsByID: [EnterpriseBlueprintID: EnterpriseBlueprintSpec] = {
        Dictionary(uniqueKeysWithValues: allSpecs.map { ($0.id, $0) })
    }()

    /// Looks up the strongly-typed specification for a given `EnterpriseBlueprintID`.
    public static func spec(for id: EnterpriseBlueprintID) -> EnterpriseBlueprintSpec {
        guard let found = specsByID[id] else {
            preconditionFailure("Missing EnterpriseBlueprintSpec registration for \(id.rawValue)")
        }
        return found
    }

    /// Returns all blueprints belonging to a specific industry vertical.
    public static func specs(in vertical: EnterpriseVertical) -> [EnterpriseBlueprintSpec] {
        allSpecs.filter { $0.vertical == vertical }
    }

    /// Returns all blueprints supporting a target Apple OS platform.
    public static func specs(supporting platform: TargetApplePlatform) -> [EnterpriseBlueprintSpec] {
        allSpecs.filter { $0.supportedPlatforms.contains(platform) }
    }

    /// Searches and filters blueprints across vertical, platform, complexity tier, and bilingual text query.
    public static func search(
        vertical: EnterpriseVertical? = nil,
        platform: TargetApplePlatform? = nil,
        complexity: BlueprintComplexityTier? = nil,
        query: String = ""
    ) -> [EnterpriseBlueprintSpec] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allSpecs.filter { spec in
            if let vertical, spec.vertical != vertical { return false }
            if let platform, !spec.supportedPlatforms.contains(platform) { return false }
            if let complexity, spec.complexityTier != complexity { return false }
            guard !trimmed.isEmpty else { return true }

            if spec.title.lowercased().contains(trimmed) { return true }
            if spec.subtitle.lowercased().contains(trimmed) { return true }
            if spec.id.rawValue.lowercased().contains(trimmed) { return true }
            if spec.vertical.title.lowercased().contains(trimmed) { return true }
            if spec.vertical.turkishTitle.lowercased().contains(trimmed) { return true }
            if spec.domainEntities.contains(where: { $0.name.lowercased().contains(trimmed) }) { return true }
            if spec.localizationKeysTR_EN.contains(where: {
                $0.en.lowercased().contains(trimmed) || $0.tr.lowercased().contains(trimmed)
            }) {
                return true
            }
            return false
        }
    }

    /// Alias for `search(vertical:platform:complexity:query:)` supporting declarative filtering.
    public static func filter(
        vertical: EnterpriseVertical? = nil,
        platform: TargetApplePlatform? = nil,
        complexity: BlueprintComplexityTier? = nil,
        query: String = ""
    ) -> [EnterpriseBlueprintSpec] {
        search(vertical: vertical, platform: platform, complexity: complexity, query: query)
    }

    /// Aggregate architectural telemetry across all 28 registered blueprints.
    public static var summary: BlueprintCatalogSummary {
        BlueprintCatalogSummary(specs: allSpecs)
    }
}
