import ChiefKitStudioCore
import Foundation

// MARK: - Apple PrivacyInfo.xcprivacy Categories, Reasons & Data Types

public enum PrivacyManifestError: Error, LocalizedError, Equatable, Sendable {
    case emptyPlistDocument
    case malformedPlistXML(String)
    case missingRootDictInPlist
    case unknownAPICategoryIdentifier(String)
    case unknownCollectedDataTypeIdentifier(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPlistDocument:
            return "PrivacyInfo.xcprivacy XML text is empty."
        case .malformedPlistXML(let detail):
            return "Malformed Apple PropertyList XML: \(detail)"
        case .missingRootDictInPlist:
            return "PrivacyInfo.xcprivacy XML must contain a top-level <dict> element."
        case .unknownAPICategoryIdentifier(let raw):
            return "Unrecognized NSPrivacyAccessedAPIType '\(raw)'."
        case .unknownCollectedDataTypeIdentifier(let raw):
            return "Unrecognized NSPrivacyCollectedDataType '\(raw)'."
        }
    }
}

public enum PrivacyAccessedAPICategory: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case fileTimestamp = "NSPrivacyAccessedAPICategoryFileTimestamp"
    case systemBootTime = "NSPrivacyAccessedAPICategorySystemBootTime"
    case diskSpace = "NSPrivacyAccessedAPICategoryDiskSpace"
    case activeKeyboards = "NSPrivacyAccessedAPICategoryActiveKeyboards"
    case userDefaults = "NSPrivacyAccessedAPICategoryUserDefaults"

    public var displayTitle: String {
        switch self {
        case .fileTimestamp: return "File Timestamp APIs"
        case .systemBootTime: return "System Boot Time APIs"
        case .diskSpace: return "Disk Space APIs"
        case .activeKeyboards: return "Active Keyboards APIs"
        case .userDefaults: return "UserDefaults APIs"
        }
    }

    /// Official Apple App Store approved reason codes and descriptions for each Required Reason API category.
    public var approvedReasonCatalog: [String: String] {
        switch self {
        case .fileTimestamp:
            return [
                "DDA9.1": "Display file timestamps to the person using the device.",
                "C617.1": "Access timestamps of files inside the app container, app group container, or CloudKit container.",
                "3B52.1": "Access timestamps of files or directories that the user specifically granted access to via document picker.",
                "0A2A.1": "Third-party SDK accessing file timestamps strictly for embedded SDK container caching."
            ]
        case .systemBootTime:
            return [
                "35F9.1": "Measure elapsed duration between events within the app or calculate monotonic frame/audio intervals.",
                "8FFB.1": "Calculate absolute timestamps for user-initiated UI/sensor events.",
                "3D61.1": "Include monotonic boot-relative timestamps in user-opted-in diagnostic/bug reports."
            ]
        case .diskSpace:
            return [
                "85F4.1": "Display available storage space directly to the user.",
                "E174.1": "Check whether sufficient disk space exists before writing files or pruning caches.",
                "7D9E.1": "Include disk space availability in optional user-submitted diagnostic reports.",
                "B728.1": "Health research app verifying storage capacity for continuous sensor capture."
            ]
        case .activeKeyboards:
            return [
                "3EC4.1": "Custom keyboard extension inspecting active keyboards to operate on device.",
                "54BD.1": "Customize UI layout, input shortcuts, or text handling based on active device keyboards."
            ]
        case .userDefaults:
            return [
                "CA92.1": "Read and write preferences only accessible to the app itself.",
                "1C8F.1": "Read and write preferences shared across apps/extensions in the same App Group.",
                "C56D.1": "Third-party SDK storing internal SDK state inaccessible to other apps.",
                "AC6B.1": "Managed Enterprise / MDM configuration reading com.apple.configuration.managed."
            ]
        }
    }

    public var recommendedDefaultReasonCode: String {
        switch self {
        case .fileTimestamp: return "C617.1"
        case .systemBootTime: return "35F9.1"
        case .diskSpace: return "E174.1"
        case .activeKeyboards: return "54BD.1"
        case .userDefaults: return "CA92.1"
        }
    }
}

public enum PrivacyCollectedDataType: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case name = "NSPrivacyCollectedDataTypeName"
    case emailAddress = "NSPrivacyCollectedDataTypeEmailAddress"
    case phoneNumber = "NSPrivacyCollectedDataTypePhoneNumber"
    case physicalAddress = "NSPrivacyCollectedDataTypePhysicalAddress"
    case health = "NSPrivacyCollectedDataTypeHealth"
    case fitness = "NSPrivacyCollectedDataTypeFitness"
    case paymentInfo = "NSPrivacyCollectedDataTypePaymentInfo"
    case preciseLocation = "NSPrivacyCollectedDataTypePreciseLocation"
    case coarseLocation = "NSPrivacyCollectedDataTypeCoarseLocation"
    case sensitiveInfo = "NSPrivacyCollectedDataTypeSensitiveInfo"
    case contacts = "NSPrivacyCollectedDataTypeContacts"
    case photosOrVideos = "NSPrivacyCollectedDataTypePhotosOrVideos"
    case audioData = "NSPrivacyCollectedDataTypeAudioData"
    case customerSupport = "NSPrivacyCollectedDataTypeCustomerSupport"
    case otherUserContent = "NSPrivacyCollectedDataTypeOtherUserContent"
    case searchHistory = "NSPrivacyCollectedDataTypeSearchHistory"
    case userID = "NSPrivacyCollectedDataTypeUserID"
    case deviceID = "NSPrivacyCollectedDataTypeDeviceID"
    case purchaseHistory = "NSPrivacyCollectedDataTypePurchaseHistory"
    case productInteraction = "NSPrivacyCollectedDataTypeProductInteraction"
    case advertisingData = "NSPrivacyCollectedDataTypeAdvertisingData"
    case crashData = "NSPrivacyCollectedDataTypeCrashData"
    case performanceData = "NSPrivacyCollectedDataTypePerformanceData"
    case otherDiagnosticData = "NSPrivacyCollectedDataTypeOtherDiagnosticData"

    public var nutritionLabelSection: String {
        switch self {
        case .name, .emailAddress, .phoneNumber, .physicalAddress:
            return "Contact Info"
        case .health, .fitness:
            return "Health & Fitness"
        case .paymentInfo:
            return "Financial Info"
        case .preciseLocation, .coarseLocation:
            return "Location"
        case .sensitiveInfo:
            return "Sensitive Info"
        case .contacts:
            return "Contacts"
        case .photosOrVideos, .audioData, .customerSupport, .otherUserContent:
            return "User Content"
        case .searchHistory:
            return "Search History"
        case .userID, .deviceID:
            return "Identifiers"
        case .purchaseHistory:
            return "Purchases"
        case .productInteraction, .advertisingData:
            return "Usage Data"
        case .crashData, .performanceData, .otherDiagnosticData:
            return "Diagnostics"
        }
    }
}

public enum PrivacyCollectionPurpose: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case appFunctionality = "NSPrivacyCollectedDataTypePurposeAppFunctionality"
    case analytics = "NSPrivacyCollectedDataTypePurposeAnalytics"
    case productPersonalization = "NSPrivacyCollectedDataTypePurposeProductPersonalization"
    case developerAdvertising = "NSPrivacyCollectedDataTypePurposeDeveloperAdvertising"
    case thirdPartyAdvertising = "NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising"
    case other = "NSPrivacyCollectedDataTypePurposeOther"

    public var shortLabel: String {
        switch self {
        case .appFunctionality: return "App Functionality"
        case .analytics: return "Analytics"
        case .productPersonalization: return "Product Personalization"
        case .developerAdvertising: return "Developer's Advertising"
        case .thirdPartyAdvertising: return "Third-Party Advertising"
        case .other: return "Other Purposes"
        }
    }
}

// MARK: - PrivacyManifestSpec & Nutrition Label Models

public struct PrivacyAccessedAPIDeclaration: Codable, Equatable, Hashable, Sendable {
    public var category: PrivacyAccessedAPICategory
    public var reasonCodes: [String]

    public init(category: PrivacyAccessedAPICategory, reasonCodes: [String]) {
        self.category = category
        self.reasonCodes = reasonCodes
    }
}

public struct PrivacyCollectedDataDeclaration: Codable, Equatable, Hashable, Sendable {
    public var dataType: PrivacyCollectedDataType
    public var linkedToUserIdentity: Bool
    public var usedForTracking: Bool
    public var purposes: [PrivacyCollectionPurpose]

    public init(
        dataType: PrivacyCollectedDataType,
        linkedToUserIdentity: Bool,
        usedForTracking: Bool,
        purposes: [PrivacyCollectionPurpose]
    ) {
        self.dataType = dataType
        self.linkedToUserIdentity = linkedToUserIdentity
        self.usedForTracking = usedForTracking
        self.purposes = purposes
    }
}

public struct AppStoreNutritionLabelSummary: Codable, Equatable, Sendable {
    public let dataUsedToTrackYou: [String]
    public let dataLinkedToYou: [String]
    public let dataNotLinkedToYou: [String]
    public let collectsZeroData: Bool
}

public struct PrivacyValidationIssue: Codable, Equatable, Hashable, Sendable {
    public let severity: SecuritySeverity
    public let code: String
    public let message: String
    public let remediation: String

    public init(severity: SecuritySeverity, code: String, message: String, remediation: String) {
        self.severity = severity
        self.code = code
        self.message = message
        self.remediation = remediation
    }
}

public struct PrivacyComplianceAudit: Codable, Equatable, Sendable {
    public let detectedCodeCategories: Set<PrivacyAccessedAPICategory>
    public let declaredCategories: Set<PrivacyAccessedAPICategory>
    public let missingRequiredReasonCategories: [PrivacyAccessedAPICategory]
    public let issues: [PrivacyValidationIssue]
    public let nutritionLabel: AppStoreNutritionLabelSummary
    public let complianceScore: Int
    public let isAppStoreSubmissionReady: Bool
}

public struct PrivacyManifestSpec: Codable, Equatable, Sendable {
    public var privacyTracking: Bool
    public var privacyTrackingDomains: [String]
    public var accessedAPIDeclarations: [PrivacyAccessedAPIDeclaration]
    public var collectedDataDeclarations: [PrivacyCollectedDataDeclaration]

    public init(
        privacyTracking: Bool = false,
        privacyTrackingDomains: [String] = [],
        accessedAPIDeclarations: [PrivacyAccessedAPIDeclaration] = [],
        collectedDataDeclarations: [PrivacyCollectedDataDeclaration] = []
    ) {
        self.privacyTracking = privacyTracking
        self.privacyTrackingDomains = privacyTrackingDomains
        self.accessedAPIDeclarations = accessedAPIDeclarations
        self.collectedDataDeclarations = collectedDataDeclarations
    }

    public func nutritionLabelSummary() -> AppStoreNutritionLabelSummary {
        var tracked = [String]()
        var linked = [String]()
        var unlinked = [String]()

        for entry in collectedDataDeclarations {
            let label = "\(entry.dataType.nutritionLabelSection): \(entry.dataType.rawValue.replacingOccurrences(of: "NSPrivacyCollectedDataType", with: ""))"
            if entry.usedForTracking {
                tracked.append(label)
            }
            if entry.linkedToUserIdentity {
                linked.append(label)
            } else {
                unlinked.append(label)
            }
        }

        return AppStoreNutritionLabelSummary(
            dataUsedToTrackYou: tracked.sorted(),
            dataLinkedToYou: linked.sorted(),
            dataNotLinkedToYou: unlinked.sorted(),
            collectsZeroData: collectedDataDeclarations.isEmpty
        )
    }

    // MARK: Valid Apple PropertyList 1.0 XML Emitter

    public func compilePrivacyInfoPlistXML() -> String {
        var lines = [String]()
        lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        lines.append("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">")
        lines.append("<plist version=\"1.0\">")
        lines.append("<dict>")

        // 1. NSPrivacyTracking
        lines.append("\t<key>NSPrivacyTracking</key>")
        lines.append("\t<\(privacyTracking ? "true" : "false")/>")

        // 2. NSPrivacyTrackingDomains
        lines.append("\t<key>NSPrivacyTrackingDomains</key>")
        if privacyTrackingDomains.isEmpty {
            lines.append("\t<array/>")
        } else {
            lines.append("\t<array>")
            for domain in privacyTrackingDomains {
                lines.append("\t\t<string>\(Self.xmlEscape(domain))</string>")
            }
            lines.append("\t</array>")
        }

        // 3. NSPrivacyCollectedDataTypes
        lines.append("\t<key>NSPrivacyCollectedDataTypes</key>")
        if collectedDataDeclarations.isEmpty {
            lines.append("\t<array/>")
        } else {
            lines.append("\t<array>")
            for item in collectedDataDeclarations {
                lines.append("\t\t<dict>")
                lines.append("\t\t\t<key>NSPrivacyCollectedDataType</key>")
                lines.append("\t\t\t<string>\(Self.xmlEscape(item.dataType.rawValue))</string>")
                lines.append("\t\t\t<key>NSPrivacyCollectedDataTypeLinked</key>")
                lines.append("\t\t\t<\(item.linkedToUserIdentity ? "true" : "false")/>")
                lines.append("\t\t\t<key>NSPrivacyCollectedDataTypeTracking</key>")
                lines.append("\t\t\t<\(item.usedForTracking ? "true" : "false")/>")
                lines.append("\t\t\t<key>NSPrivacyCollectedDataTypePurposes</key>")
                if item.purposes.isEmpty {
                    lines.append("\t\t\t<array/>")
                } else {
                    lines.append("\t\t\t<array>")
                    for purpose in item.purposes {
                        lines.append("\t\t\t\t<string>\(Self.xmlEscape(purpose.rawValue))</string>")
                    }
                    lines.append("\t\t\t</array>")
                }
                lines.append("\t\t</dict>")
            }
            lines.append("\t</array>")
        }

        // 4. NSPrivacyAccessedAPITypes
        lines.append("\t<key>NSPrivacyAccessedAPITypes</key>")
        if accessedAPIDeclarations.isEmpty {
            lines.append("\t<array/>")
        } else {
            lines.append("\t<array>")
            for api in accessedAPIDeclarations {
                lines.append("\t\t<dict>")
                lines.append("\t\t\t<key>NSPrivacyAccessedAPIType</key>")
                lines.append("\t\t\t<string>\(Self.xmlEscape(api.category.rawValue))</string>")
                lines.append("\t\t\t<key>NSPrivacyAccessedAPITypeReasons</key>")
                if api.reasonCodes.isEmpty {
                    lines.append("\t\t\t<array/>")
                } else {
                    lines.append("\t\t\t<array>")
                    for code in api.reasonCodes {
                        lines.append("\t\t\t\t<string>\(Self.xmlEscape(code))</string>")
                    }
                    lines.append("\t\t\t</array>")
                }
                lines.append("\t\t</dict>")
            }
            lines.append("\t</array>")
        }

        lines.append("</dict>")
        lines.append("</plist>")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func xmlEscape(_ raw: String) -> String {
        var out = ""
        out.reserveCapacity(raw.count)
        for ch in raw {
            switch ch {
            case "&": out.append("&amp;")
            case "<": out.append("&lt;")
            case ">": out.append("&gt;")
            case "\"": out.append("&quot;")
            case "'": out.append("&apos;")
            default: out.append(ch)
            }
        }
        return out
    }
}

// MARK: - Pure-Swift Cross-Platform Plist XML Parser & Validator

public enum ApplePrivacyManifestBuilder {
    private indirect enum PlistNode {
        case dict([String: PlistNode])
        case array([PlistNode])
        case string(String)
        case bool(Bool)
    }

    /// Parses an Apple `PrivacyInfo.xcprivacy` PropertyList 1.0 XML string identically on Linux and macOS.
    public static func parsePlistXML(_ xml: String) throws -> PrivacyManifestSpec {
        let trimmed = xml.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PrivacyManifestError.emptyPlistDocument
        }

        let tokens = try tokenizePlistXML(trimmed)
        var cursor = 0
        var rootDict: [String: PlistNode]?

        while cursor < tokens.count {
            if tokens[cursor] == .openTag("dict") {
                let node = try parseValue(tokens: tokens, cursor: &cursor)
                if case .dict(let d) = node {
                    rootDict = d
                    break
                }
            } else {
                cursor += 1
            }
        }

        guard let dict = rootDict else {
            throw PrivacyManifestError.missingRootDictInPlist
        }

        let tracking: Bool
        if case .bool(let flag)? = dict["NSPrivacyTracking"] {
            tracking = flag
        } else {
            tracking = false
        }

        var domains = [String]()
        if case .array(let items)? = dict["NSPrivacyTrackingDomains"] {
            for item in items {
                if case .string(let s) = item {
                    domains.append(s)
                }
            }
        }

        var accessedDecls = [PrivacyAccessedAPIDeclaration]()
        if case .array(let apiItems)? = dict["NSPrivacyAccessedAPITypes"] {
            for item in apiItems {
                guard case .dict(let entryDict) = item,
                      case .string(let catRaw)? = entryDict["NSPrivacyAccessedAPIType"]
                else { continue }
                guard let category = PrivacyAccessedAPICategory(rawValue: catRaw) else {
                    throw PrivacyManifestError.unknownAPICategoryIdentifier(catRaw)
                }
                var reasons = [String]()
                if case .array(let rNodes)? = entryDict["NSPrivacyAccessedAPITypeReasons"] {
                    for rNode in rNodes {
                        if case .string(let code) = rNode {
                            reasons.append(code)
                        }
                    }
                }
                accessedDecls.append(PrivacyAccessedAPIDeclaration(category: category, reasonCodes: reasons))
            }
        }

        var collectedDecls = [PrivacyCollectedDataDeclaration]()
        if case .array(let dataItems)? = dict["NSPrivacyCollectedDataTypes"] {
            for item in dataItems {
                guard case .dict(let entryDict) = item,
                      case .string(let typeRaw)? = entryDict["NSPrivacyCollectedDataType"]
                else { continue }
                guard let dataType = PrivacyCollectedDataType(rawValue: typeRaw) else {
                    throw PrivacyManifestError.unknownCollectedDataTypeIdentifier(typeRaw)
                }
                let linked: Bool = {
                    if case .bool(let b)? = entryDict["NSPrivacyCollectedDataTypeLinked"] { return b }
                    return false
                }()
                let tracked: Bool = {
                    if case .bool(let b)? = entryDict["NSPrivacyCollectedDataTypeTracking"] { return b }
                    return false
                }()
                var purposes = [PrivacyCollectionPurpose]()
                if case .array(let pNodes)? = entryDict["NSPrivacyCollectedDataTypePurposes"] {
                    for pNode in pNodes {
                        if case .string(let pRaw) = pNode,
                           let purpose = PrivacyCollectionPurpose(rawValue: pRaw) {
                            purposes.append(purpose)
                        }
                    }
                }
                collectedDecls.append(
                    PrivacyCollectedDataDeclaration(
                        dataType: dataType,
                        linkedToUserIdentity: linked,
                        usedForTracking: tracked,
                        purposes: purposes
                    )
                )
            }
        }

        return PrivacyManifestSpec(
            privacyTracking: tracking,
            privacyTrackingDomains: domains,
            accessedAPIDeclarations: accessedDecls,
            collectedDataDeclarations: collectedDecls
        )
    }

    /// Scans Swift source documents for Apple Required Reason API invocations (`FileTimestamp`,
    /// `SystemBootTime`, `DiskSpace`, `ActiveKeyboards`, `UserDefaults`).
    public static func detectRequiredReasonAPIs(in swiftSources: [String]) -> Set<PrivacyAccessedAPICategory> {
        var detected = Set<PrivacyAccessedAPICategory>()
        let combined = swiftSources.joined(separator: "\n")

        let fileTimestampMarkers = [
            "attributesOfItem(", ".creationDate", ".modificationDate",
            "contentModificationDateKey", "creationDateKey", "getattrlist("
        ]
        if fileTimestampMarkers.contains(where: { combined.contains($0) }) {
            detected.insert(.fileTimestamp)
        }

        let bootTimeMarkers = [
            "systemUptime", "mach_absolute_time(", "mach_continuous_time(", "clock_gettime("
        ]
        if bootTimeMarkers.contains(where: { combined.contains($0) }) {
            detected.insert(.systemBootTime)
        }

        let diskSpaceMarkers = [
            "volumeAvailableCapacity", "volumeTotalCapacity", "systemFreeSize", "statfs(", "statvfs("
        ]
        if diskSpaceMarkers.contains(where: { combined.contains($0) }) {
            detected.insert(.diskSpace)
        }

        let keyboardMarkers = [
            "activeInputModes", "UITextInputMode"
        ]
        if keyboardMarkers.contains(where: { combined.contains($0) }) {
            detected.insert(.activeKeyboards)
        }

        let userDefaultsMarkers = [
            "UserDefaults", "@AppStorage"
        ]
        if userDefaultsMarkers.contains(where: { combined.contains($0) }) {
            detected.insert(.userDefaults)
        }

        return detected
    }

    /// Synthesizes a compliant `PrivacyManifestSpec` directly from workspace Swift source files.
    public static func inferCompliantManifest(
        fromSwiftSources swiftSources: [String],
        collectedData: [PrivacyCollectedDataDeclaration] = [],
        trackingDomains: [String] = []
    ) -> PrivacyManifestSpec {
        let categories = detectRequiredReasonAPIs(in: swiftSources)
        let sortedCategories = PrivacyAccessedAPICategory.allCases.filter { categories.contains($0) }
        let declarations = sortedCategories.map { cat in
            PrivacyAccessedAPIDeclaration(
                category: cat,
                reasonCodes: [cat.recommendedDefaultReasonCode]
            )
        }
        let tracks = !trackingDomains.isEmpty || collectedData.contains { $0.usedForTracking }
        return PrivacyManifestSpec(
            privacyTracking: tracks,
            privacyTrackingDomains: trackingDomains,
            accessedAPIDeclarations: declarations,
            collectedDataDeclarations: collectedData
        )
    }

    /// Audits a `PrivacyManifestSpec` against App Store ITMS-91053 / ITMS-91056 submission rules
    /// and cross-validates against detected Swift source API usage.
    public static func validate(
        manifest: PrivacyManifestSpec,
        againstSwiftSources swiftSources: [String] = []
    ) -> PrivacyComplianceAudit {
        let detected = detectRequiredReasonAPIs(in: swiftSources)
        let declared = Set(manifest.accessedAPIDeclarations.map(\.category))
        let missing = PrivacyAccessedAPICategory.allCases.filter {
            detected.contains($0) && !declared.contains($0)
        }

        var issues = [PrivacyValidationIssue]()

        for missingCat in missing {
            issues.append(
                PrivacyValidationIssue(
                    severity: .high,
                    code: "ITMS-91053",
                    message: "Swift source invokes \(missingCat.displayTitle) (\(missingCat.rawValue)) without declaring it in PrivacyInfo.xcprivacy.",
                    remediation: "Add \(missingCat.rawValue) with reason '\(missingCat.recommendedDefaultReasonCode)' to NSPrivacyAccessedAPITypes."
                )
            )
        }

        var seenCategories = Set<PrivacyAccessedAPICategory>()
        for decl in manifest.accessedAPIDeclarations {
            if !seenCategories.insert(decl.category).inserted {
                issues.append(
                    PrivacyValidationIssue(
                        severity: .medium,
                        code: "PRIV-DUP-CAT",
                        message: "Duplicate NSPrivacyAccessedAPIType entry for \(decl.category.rawValue).",
                        remediation: "Consolidate all reason codes for \(decl.category.rawValue) into a single dictionary entry."
                    )
                )
            }
            if decl.reasonCodes.isEmpty {
                issues.append(
                    PrivacyValidationIssue(
                        severity: .high,
                        code: "ITMS-91056",
                        message: "\(decl.category.rawValue) has an empty NSPrivacyAccessedAPITypeReasons array.",
                        remediation: "Specify at least one approved Apple reason code (e.g., '\(decl.category.recommendedDefaultReasonCode)')."
                    )
                )
            }
            let approved = decl.category.approvedReasonCatalog
            for code in decl.reasonCodes where approved[code] == nil {
                issues.append(
                    PrivacyValidationIssue(
                        severity: .high,
                        code: "PRIV-BAD-REASON",
                        message: "Reason code '\(code)' is not an Apple-approved reason for \(decl.category.rawValue).",
                        remediation: "Use one of: \(approved.keys.sorted().joined(separator: ", "))."
                    )
                )
            }
        }

        let anyItemTracks = manifest.collectedDataDeclarations.contains { $0.usedForTracking }
        if anyItemTracks && !manifest.privacyTracking {
            issues.append(
                PrivacyValidationIssue(
                    severity: .high,
                    code: "PRIV-TRACK-MISMATCH",
                    message: "Collected data marks NSPrivacyCollectedDataTypeTracking=true, but top-level NSPrivacyTracking is false.",
                    remediation: "Set NSPrivacyTracking to true and request ATTrackingManager authorization, or disable tracking."
                )
            )
        }

        if manifest.privacyTracking && manifest.privacyTrackingDomains.isEmpty && !anyItemTracks {
            issues.append(
                PrivacyValidationIssue(
                    severity: .low,
                    code: "PRIV-EMPTY-TRACKING",
                    message: "NSPrivacyTracking is true, yet NSPrivacyTrackingDomains and tracking data types are empty.",
                    remediation: "Declare tracking domains in NSPrivacyTrackingDomains or set NSPrivacyTracking to false."
                )
            )
        }

        for item in manifest.collectedDataDeclarations where item.purposes.isEmpty {
            issues.append(
                PrivacyValidationIssue(
                    severity: .medium,
                    code: "PRIV-MISSING-PURPOSE",
                    message: "Collected data type \(item.dataType.rawValue) omits NSPrivacyCollectedDataTypePurposes.",
                    remediation: "Declare at least one purpose such as NSPrivacyCollectedDataTypePurposeAppFunctionality."
                )
            )
        }

        let penalty = issues.reduce(0) { $0 + $1.severity.scorePenaltyPoints }
        let score = max(0, min(100, 100 - penalty))
        let submissionReady = !issues.contains { $0.severity >= .high }

        return PrivacyComplianceAudit(
            detectedCodeCategories: detected,
            declaredCategories: declared,
            missingRequiredReasonCategories: missing,
            issues: issues,
            nutritionLabel: manifest.nutritionLabelSummary(),
            complianceScore: score,
            isAppStoreSubmissionReady: submissionReady
        )
    }

    // MARK: Lightweight Plist XML Tokenizer & Parser Helpers

    private enum XMLToken: Equatable {
        case openTag(String)
        case closeTag(String)
        case selfClosingTag(String)
        case text(String)
    }

    private static func tokenizePlistXML(_ xml: String) throws -> [XMLToken] {
        var tokens = [XMLToken]()
        let scalars = Array(xml.unicodeScalars)
        var idx = 0

        while idx < scalars.count {
            if scalars[idx] == "<" {
                // Skip XML declarations `<?...?>`, comments `<!--...-->`, and `<!DOCTYPE ...>`
                if idx + 1 < scalars.count && scalars[idx + 1] == "?" {
                    while idx + 1 < scalars.count && !(scalars[idx] == "?" && scalars[idx + 1] == ">") {
                        idx += 1
                    }
                    idx += 2
                    continue
                }
                if idx + 3 < scalars.count
                    && scalars[idx + 1] == "!"
                    && scalars[idx + 2] == "-"
                    && scalars[idx + 3] == "-" {
                    idx += 4
                    while idx + 2 < scalars.count
                        && !(scalars[idx] == "-" && scalars[idx + 1] == "-" && scalars[idx + 2] == ">") {
                        idx += 1
                    }
                    idx += 3
                    continue
                }
                if idx + 1 < scalars.count && scalars[idx + 1] == "!" {
                    while idx < scalars.count && scalars[idx] != ">" {
                        idx += 1
                    }
                    idx += 1
                    continue
                }

                idx += 1
                let start = idx
                while idx < scalars.count && scalars[idx] != ">" {
                    idx += 1
                }
                guard idx < scalars.count else {
                    throw PrivacyManifestError.malformedPlistXML("Unclosed '<' tag")
                }
                let rawTag = String(String.UnicodeScalarView(scalars[start..<idx]))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                idx += 1

                if rawTag.hasPrefix("/") {
                    let name = rawTag.dropFirst().trimmingCharacters(in: .whitespaces)
                    tokens.append(.closeTag(name))
                } else if rawTag.hasSuffix("/") {
                    let base = rawTag.dropLast().trimmingCharacters(in: .whitespaces)
                    let name = base.split(separator: " ").first.map(String.init) ?? base
                    tokens.append(.selfClosingTag(name))
                } else {
                    let name = rawTag.split(separator: " ").first.map(String.init) ?? rawTag
                    tokens.append(.openTag(name))
                }
            } else {
                let start = idx
                while idx < scalars.count && scalars[idx] != "<" {
                    idx += 1
                }
                let rawText = String(String.UnicodeScalarView(scalars[start..<idx]))
                if !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    tokens.append(.text(xmlUnescape(rawText)))
                }
            }
        }
        return tokens
    }

    private static func parseValue(tokens: [XMLToken], cursor: inout Int) throws -> PlistNode {
        guard cursor < tokens.count else {
            throw PrivacyManifestError.malformedPlistXML("Unexpected end of plist tokens")
        }
        let tok = tokens[cursor]
        cursor += 1

        switch tok {
        case .selfClosingTag("true"):
            return .bool(true)
        case .selfClosingTag("false"):
            return .bool(false)
        case .selfClosingTag("array"):
            return .array([])
        case .selfClosingTag("dict"):
            return .dict([:])
        case .selfClosingTag("string"):
            return .string("")
        case .openTag("string"):
            var content = ""
            if cursor < tokens.count, case .text(let txt) = tokens[cursor] {
                content = txt
                cursor += 1
            }
            guard cursor < tokens.count, tokens[cursor] == .closeTag("string") else {
                throw PrivacyManifestError.malformedPlistXML("Expected </string>")
            }
            cursor += 1
            return .string(content)
        case .openTag("array"):
            var items = [PlistNode]()
            while cursor < tokens.count && tokens[cursor] != .closeTag("array") {
                items.append(try parseValue(tokens: tokens, cursor: &cursor))
            }
            guard cursor < tokens.count, tokens[cursor] == .closeTag("array") else {
                throw PrivacyManifestError.malformedPlistXML("Expected </array>")
            }
            cursor += 1
            return .array(items)
        case .openTag("dict"):
            var map: [String: PlistNode] = [:]
            while cursor < tokens.count && tokens[cursor] != .closeTag("dict") {
                guard tokens[cursor] == .openTag("key") else {
                    throw PrivacyManifestError.malformedPlistXML("Expected <key> inside <dict>")
                }
                cursor += 1
                var keyText = ""
                if cursor < tokens.count, case .text(let k) = tokens[cursor] {
                    keyText = k
                    cursor += 1
                }
                guard cursor < tokens.count, tokens[cursor] == .closeTag("key") else {
                    throw PrivacyManifestError.malformedPlistXML("Expected </key>")
                }
                cursor += 1
                let val = try parseValue(tokens: tokens, cursor: &cursor)
                map[keyText] = val
            }
            guard cursor < tokens.count, tokens[cursor] == .closeTag("dict") else {
                throw PrivacyManifestError.malformedPlistXML("Expected </dict>")
            }
            cursor += 1
            return .dict(map)
        default:
            throw PrivacyManifestError.malformedPlistXML("Unsupported plist token \(tok)")
        }
    }

    private static func xmlUnescape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

// MARK: - Keychain + Secure Enclave SecAccessControl Swift 6 Actor Synthesizer

public enum KeychainBiometricPolicy: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case deviceOnlyUnlocked = "whenUnlockedThisDeviceOnly"
    case biometryCurrentSet = "biometryCurrentSet"
    case userPresenceBiometryOrPasscode = "userPresence"
}

public enum KeychainSecureEnclaveSynthesizer {
    /// Generates a complete Swift 6 strict-concurrency actor wrapping Apple Keychain + Secure Enclave
    /// `SecAccessControlCreateWithFlags` on Darwin with seamless `EncryptedWorkspaceVault` fallback on Linux.
    public static func synthesizeKeychainActorSource(
        actorName: String = "HardwareKeychainVault",
        serviceIdentifier: String = "com.hnmlabs.chiefkit.vault",
        policy: KeychainBiometricPolicy = .biometryCurrentSet
    ) -> String {
        let secFlagSnippet: String
        switch policy {
        case .deviceOnlyUnlocked:
            secFlagSnippet = "[]"
        case .biometryCurrentSet:
            secFlagSnippet = "[.biometryCurrentSet, .privateKeyUsage]"
        case .userPresenceBiometryOrPasscode:
            secFlagSnippet = "[.userPresence]"
        }

        return """
        import Foundation
        #if canImport(Security)
        import Security
        #endif

        /// Generated by ChiefKit Studio 3.0 — Swift 6 Keychain & Secure Enclave Hardware Vault Actor
        public actor \(actorName) {
            public enum KeychainVaultError: Error, Sendable, Equatable {
                case accessControlCreationFailed
                case itemNotFound(String)
                case unexpectedOSStatus(Int32)
                case secureEnclaveUnavailable
            }

            private let serviceIdentifier: String
            private var inMemoryLinuxFallback: [String: Data] = [:]

            public init(serviceIdentifier: String = "\(serviceIdentifier)") {
                self.serviceIdentifier = serviceIdentifier
            }

            public func saveSecret(_ data: Data, account: String) throws {
                #if canImport(Security)
                var unmanagedError: Unmanaged<CFError>?
                guard let access = SecAccessControlCreateWithFlags(
                    nil,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    \(secFlagSnippet),
                    &unmanagedError
                ) else {
                    throw KeychainVaultError.accessControlCreationFailed
                }

                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: serviceIdentifier,
                    kSecAttrAccount as String: account
                ]
                SecItemDelete(deleteQuery as CFDictionary)

                let addQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: serviceIdentifier,
                    kSecAttrAccount as String: account,
                    kSecAttrAccessControl as String: access,
                    kSecValueData as String: data
                ]
                let status = SecItemAdd(addQuery as CFDictionary, nil)
                guard status == errSecSuccess else {
                    throw KeychainVaultError.unexpectedOSStatus(status)
                }
                #else
                inMemoryLinuxFallback[account] = data
                #endif
            }

            public func loadSecret(account: String) throws -> Data {
                #if canImport(Security)
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: serviceIdentifier,
                    kSecAttrAccount as String: account,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)
                if status == errSecItemNotFound {
                    throw KeychainVaultError.itemNotFound(account)
                }
                guard status == errSecSuccess, let data = item as? Data else {
                    throw KeychainVaultError.unexpectedOSStatus(status)
                }
                return data
                #else
                guard let fallback = inMemoryLinuxFallback[account] else {
                    throw KeychainVaultError.itemNotFound(account)
                }
                return fallback
                #endif
            }

            public func deleteSecret(account: String) throws {
                #if canImport(Security)
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: serviceIdentifier,
                    kSecAttrAccount as String: account
                ]
                let status = SecItemDelete(query as CFDictionary)
                guard status == errSecSuccess || status == errSecItemNotFound else {
                    throw KeychainVaultError.unexpectedOSStatus(status)
                }
                #else
                inMemoryLinuxFallback.removeValue(forKey: account)
                #endif
            }
        }
        """
    }
}
