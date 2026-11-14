import Foundation

// MARK: - Compiler Errors, Extraction & Diagnostics Models

public enum StringCatalogCompilerError: Error, LocalizedError, Equatable, Sendable {
    case invalidUTF8Payload
    case malformedRootJSONObject
    case serializationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8Payload:
            return "The .xcstrings input is not valid UTF-8 text."
        case .malformedRootJSONObject:
            return "Expected a root JSON dictionary conforming to Apple Xcode 15+ .xcstrings schema."
        case .serializationFailed:
            return "Failed to serialize StringCatalogDocument into JSON."
        }
    }
}

public enum FormatPlaceholderKind: String, CaseIterable, Codable, Hashable, Sendable {
    case objectString = "%@"
    case integer64 = "%lld"
    case integer32 = "%d"
    case floatingPoint = "%f"

    public var swiftParameterType: String {
        switch self {
        case .objectString: "String"
        case .integer64, .integer32: "Int"
        case .floatingPoint: "Double"
        }
    }
}

public struct ExtractedSourceString: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(lineNumber):\(key)" }
    public var key: String
    public var defaultValue: String
    public var callSiteConstruct: String
    public var lineNumber: Int
    public var placeholders: [FormatPlaceholderKind]
    public var inferredComment: String

    public init(
        key: String,
        defaultValue: String,
        callSiteConstruct: String,
        lineNumber: Int,
        placeholders: [FormatPlaceholderKind],
        inferredComment: String
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.callSiteConstruct = callSiteConstruct
        self.lineNumber = lineNumber
        self.placeholders = placeholders
        self.inferredComment = inferredComment
    }
}

public enum LocalizationDiagnosticKind: String, CaseIterable, Codable, Hashable, Sendable {
    case missingTranslation
    case missingPluralCategory
    case placeholderCountMismatch
    case placeholderTypeMismatch
    case rtlLayoutHazard
    case mobileTruncationHazard
    case whitespaceBoundaryMismatch
}

public struct LocalizationDiagnostic: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var key: String
    public var locale: LocaleCode?
    public var kind: LocalizationDiagnosticKind
    public var severity: SchemaDiagnosticSeverity
    public var message: String
    public var suggestion: String

    public init(
        id: String,
        key: String,
        locale: LocaleCode?,
        kind: LocalizationDiagnosticKind,
        severity: SchemaDiagnosticSeverity,
        message: String,
        suggestion: String
    ) {
        self.id = id
        self.key = key
        self.locale = locale
        self.kind = kind
        self.severity = severity
        self.message = message
        self.suggestion = suggestion
    }
}

public enum PseudolocMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case accentedExpanded = "Accented + 35% Width Expansion"
    case rtlMirroredBidi = "RTL BiDi Mirroring Simulation"
    case bracketedBounds = "Bracketed Clipping Bounds"
    case doubleLengthTruncationTest = "2x Double-Length Stress Test"

    public var id: String { rawValue }
}

// MARK: - StringCatalogDocument .xcstrings Extensions

public extension StringCatalogDocument {
    func encodeXCStringsJSON() throws -> String {
        try StringCatalogCompiler.encodeXCStringsJSON(self)
    }

    static func decodeXCStringsJSON(_ json: String, catalogName: String = "Localizable") throws -> StringCatalogDocument {
        try StringCatalogCompiler.decodeXCStringsJSON(json, catalogName: catalogName)
    }
}

// MARK: - StringCatalogCompiler

public enum StringCatalogCompiler {

    // MARK: - 1) Exact Apple Xcode 15+ .xcstrings JSON Serializer & Parser

    public static func encodeXCStringsJSON(_ document: StringCatalogDocument) throws -> String {
        var stringsMap: [String: Any] = [:]

        for entry in document.sortedEntries {
            var entryObj: [String: Any] = [:]
            if let comment = entry.comment, !comment.isEmpty {
                entryObj["comment"] = comment
            }
            if entry.extractionState != .manual {
                entryObj["extractionState"] = entry.extractionState.rawValue
            } else {
                entryObj["extractionState"] = "manual"
            }
            if !entry.shouldTranslate {
                entryObj["shouldTranslate"] = false
            }

            var localizationsObj: [String: Any] = [:]
            for locale in LocaleCode.allCases {
                guard let locVal = entry.localizations[locale] else { continue }
                var localeDict: [String: Any] = [:]

                if let unit = locVal.stringUnit {
                    localeDict["stringUnit"] = [
                        "state": unit.state.rawValue,
                        "value": unit.value
                    ]
                }

                var variationsDict: [String: Any] = [:]
                if !locVal.pluralVariations.isEmpty {
                    var pluralObj: [String: Any] = [:]
                    for category in CLDRPluralCategory.allCases {
                        if let unit = locVal.pluralVariations[category] {
                            pluralObj[category.rawValue] = [
                                "stringUnit": [
                                    "state": unit.state.rawValue,
                                    "value": unit.value
                                ]
                            ]
                        }
                    }
                    variationsDict["plural"] = pluralObj
                }

                if !locVal.deviceVariations.isEmpty {
                    var deviceObj: [String: Any] = [:]
                    for dev in DeviceVariationKind.allCases {
                        if let unit = locVal.deviceVariations[dev] {
                            deviceObj[dev.rawValue] = [
                                "stringUnit": [
                                    "state": unit.state.rawValue,
                                    "value": unit.value
                                ]
                            ]
                        }
                    }
                    variationsDict["device"] = deviceObj
                }

                if !variationsDict.isEmpty {
                    localeDict["variations"] = variationsDict
                }

                if !localeDict.isEmpty {
                    localizationsObj[locale.rawValue] = localeDict
                }
            }

            if !localizationsObj.isEmpty {
                entryObj["localizations"] = localizationsObj
            }
            stringsMap[entry.key] = entryObj
        }

        let rootObj: [String: Any] = [
            "sourceLanguage": document.sourceLanguage.rawValue,
            "strings": stringsMap,
            "version": document.version
        ]

        guard JSONSerialization.isValidJSONObject(rootObj),
              let data = try? JSONSerialization.data(withJSONObject: rootObj, options: [.prettyPrinted, .sortedKeys]),
              let jsonText = String(data: data, encoding: .utf8) else {
            throw StringCatalogCompilerError.serializationFailed
        }
        return jsonText
    }

    public static func decodeXCStringsJSON(
        _ json: String,
        catalogName: String = "Localizable"
    ) throws -> StringCatalogDocument {
        guard let data = json.data(using: .utf8) else {
            throw StringCatalogCompilerError.invalidUTF8Payload
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StringCatalogCompilerError.malformedRootJSONObject
        }

        let sourceLangRaw = (root["sourceLanguage"] as? String) ?? "en"
        let sourceLocale = LocaleCode(rawValue: sourceLangRaw) ?? .en
        let version = (root["version"] as? String) ?? "1.0"
        let stringsDict = (root["strings"] as? [String: Any]) ?? [:]

        var discoveredLocales: Set<LocaleCode> = [sourceLocale]
        var parsedEntries: [String: StringCatalogEntry] = [:]

        for (key, rawEntry) in stringsDict {
            guard let entryDict = rawEntry as? [String: Any] else { continue }
            let comment = entryDict["comment"] as? String
            let extractionRaw = (entryDict["extractionState"] as? String) ?? "manual"
            let extractionState = StringExtractionState(rawValue: extractionRaw) ?? .manual
            let shouldTranslate = (entryDict["shouldTranslate"] as? Bool) ?? true

            var localizations: [LocaleCode: LocaleLocalizationValue] = [:]
            if let locDict = entryDict["localizations"] as? [String: Any] {
                for (locTag, rawLocVal) in locDict {
                    guard let locale = LocaleCode(rawValue: locTag),
                          let locMap = rawLocVal as? [String: Any] else { continue }
                    discoveredLocales.insert(locale)

                    var unitObj: TranslationUnit?
                    if let su = locMap["stringUnit"] as? [String: Any],
                       let val = su["value"] as? String {
                        let st = TranslationState(rawValue: (su["state"] as? String) ?? "translated") ?? .translated
                        unitObj = TranslationUnit(state: st, value: val)
                    }

                    var pluralMap: [CLDRPluralCategory: TranslationUnit] = [:]
                    var deviceMap: [DeviceVariationKind: TranslationUnit] = [:]

                    if let variations = locMap["variations"] as? [String: Any] {
                        if let plurals = variations["plural"] as? [String: Any] {
                            for (catKey, rawCat) in plurals {
                                guard let cat = CLDRPluralCategory(rawValue: catKey),
                                      let catDict = rawCat as? [String: Any],
                                      let su = catDict["stringUnit"] as? [String: Any],
                                      let val = su["value"] as? String else { continue }
                                let st = TranslationState(rawValue: (su["state"] as? String) ?? "translated") ?? .translated
                                pluralMap[cat] = TranslationUnit(state: st, value: val)
                            }
                        }

                        if let devices = variations["device"] as? [String: Any] {
                            for (devKey, rawDev) in devices {
                                guard let dev = DeviceVariationKind(rawValue: devKey),
                                      let devDict = rawDev as? [String: Any],
                                      let su = devDict["stringUnit"] as? [String: Any],
                                      let val = su["value"] as? String else { continue }
                                let st = TranslationState(rawValue: (su["state"] as? String) ?? "translated") ?? .translated
                                deviceMap[dev] = TranslationUnit(state: st, value: val)
                            }
                        }
                    }

                    localizations[locale] = LocaleLocalizationValue(
                        stringUnit: unitObj,
                        pluralVariations: pluralMap,
                        deviceVariations: deviceMap
                    )
                }
            }

            parsedEntries[key] = StringCatalogEntry(
                key: key,
                comment: comment,
                extractionState: extractionState,
                shouldTranslate: shouldTranslate,
                localizations: localizations
            )
        }

        let orderedLocales = LocaleCode.allCases.filter { discoveredLocales.contains($0) }
        return StringCatalogDocument(
            catalogName: catalogName,
            sourceLanguage: sourceLocale,
            version: version,
            targetLocales: orderedLocales,
            entries: parsedEntries
        )
    }

    // MARK: - 2) SwiftUI Source String Extractor

    public static func extractSwiftUIStrings(from swiftSource: String) -> [ExtractedSourceString] {
        let constructs: [(name: String, pattern: String, budgetHint: String)] = [
            ("Text", #"\bText\(\s*"((?:[^"\\]|\\.)*)""#, "Display text element"),
            ("Label", #"\bLabel\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*systemImage:"#, "Icon + title label"),
            ("Button", #"\bButton\(\s*"((?:[^"\\]|\\.)*)""#, "Interactive button label"),
            ("EDKButton", #"\bEDKButton\(\s*"((?:[^"\\]|\\.)*)""#, "SwiftBlocks action button"),
            ("TextField", #"\bTextField\(\s*"((?:[^"\\]|\\.)*)""#, "Input placeholder prompt"),
            ("SecureField", #"\bSecureField\(\s*"((?:[^"\\]|\\.)*)""#, "Password field prompt"),
            ("Toggle", #"\bToggle\(\s*"((?:[^"\\]|\\.)*)""#, "Boolean switch label"),
            ("String(localized:)", #"\bString\(\s*localized:\s*"((?:[^"\\]|\\.)*)""#, "Programmatic localized string")
        ]

        let lines = swiftSource.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var results: [ExtractedSourceString] = []
        var seenKeys = Set<String>()

        for (lineIdx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") { continue }

            for item in constructs {
                guard let regex = try? NSRegularExpression(pattern: item.pattern) else { continue }
                let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                for match in regex.matches(in: line, range: nsRange) {
                    guard let capRange = Range(match.range(at: 1), in: line) else { continue }
                    let rawLiteral = String(line[capRange])
                    guard !rawLiteral.isEmpty else { continue }

                    let normalized = normalizeSwiftInterpolations(in: rawLiteral)
                    let placeholders = extractPlaceholders(from: normalized)
                    if seenKeys.insert(normalized).inserted {
                        results.append(
                            ExtractedSourceString(
                                key: normalized,
                                defaultValue: normalized,
                                callSiteConstruct: item.name,
                                lineNumber: lineIdx + 1,
                                placeholders: placeholders,
                                inferredComment: "\(item.budgetHint) (line \(lineIdx + 1))"
                            )
                        )
                    }
                }
            }
        }
        return results
    }

    public static func extractAndMergeIntoCatalog(
        swiftSource: String,
        into catalog: StringCatalogDocument
    ) -> StringCatalogDocument {
        var updated = catalog
        let extracted = extractSwiftUIStrings(from: swiftSource)
        for item in extracted where updated.entries[item.key] == nil {
            let isCompactControl = (item.callSiteConstruct == "Button" || item.callSiteConstruct == "EDKButton")
            updated.entries[item.key] = StringCatalogEntry(
                key: item.key,
                comment: item.inferredComment,
                extractionState: .extractedWithValue,
                shouldTranslate: true,
                maxCharacterBudget: isCompactControl ? 28 : nil,
                localizations: [
                    updated.sourceLanguage: .simple(item.defaultValue, state: .translated)
                ]
            )
        }
        return updated
    }

    private static func normalizeSwiftInterpolations(in raw: String) -> String {
        let pattern = #"\\\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return raw }
        let nsRange = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        let matches = regex.matches(in: raw, range: nsRange)
        guard !matches.isEmpty else { return raw }

        var output = ""
        var cursor = raw.startIndex
        for m in matches {
            guard let full = Range(m.range, in: raw),
                  let exprRange = Range(m.range(at: 1), in: raw) else { continue }
            output += raw[cursor..<full.lowerBound]
            let expr = raw[exprRange].lowercased()
            if expr.contains("count") || expr.contains("total") || expr.contains("index") || expr.contains("step") || expr.contains("num") {
                output += "%lld"
            } else if expr.contains("price") || expr.contains("amount") || expr.contains("score") || expr.contains("percent") || expr.contains("ms") {
                output += "%.2f"
            } else {
                output += "%@"
            }
            cursor = full.upperBound
        }
        output += raw[cursor...]
        return output
    }

    public static func extractPlaceholders(from template: String) -> [FormatPlaceholderKind] {
        let pattern = #"%(\d+\$)?(\.\d+)?(lld|ld|[dDuUxXoOfeEgGcCsS@])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(template.startIndex..<template.endIndex, in: template)
        let matches = regex.matches(in: template, range: nsRange)

        var indexed: [(pos: Int, kind: FormatPlaceholderKind)] = []
        var seq = 1
        for m in matches {
            guard let specRange = Range(m.range(at: 3), in: template) else { continue }
            let spec = String(template[specRange])
            let kind: FormatPlaceholderKind
            switch spec {
            case "@": kind = .objectString
            case "lld", "ld": kind = .integer64
            case "f", "e", "E", "g", "G": kind = .floatingPoint
            default: kind = .integer32
            }

            let position: Int
            if let posRange = Range(m.range(at: 1), in: template) {
                position = Int(template[posRange].dropLast()) ?? seq
            } else {
                position = seq
                seq += 1
            }
            indexed.append((position, kind))
        }
        return indexed.sorted { $0.pos < $1.pos }.map(\.kind)
    }

    // MARK: - 3) Static Localization Validator (Coverage, Placeholders, Plurals, RTL, Mobile Length)

    public static func validateCatalog(
        _ document: StringCatalogDocument,
        swiftUISource: String? = nil
    ) -> [LocalizationDiagnostic] {
        var diagnostics: [LocalizationDiagnostic] = []

        for entry in document.sortedEntries where entry.shouldTranslate {
            let sourceVal = entry.localizations[document.sourceLanguage]
            let sourceTemplate = sourceVal?.resolvedTemplate(for: document.sourceLanguage) ?? entry.key
            let expectedPlaceholders = extractPlaceholders(from: sourceTemplate)
            let isPluralEntry = entry.isPluralized

            for locale in document.targetLocales {
                guard let locVal = entry.localizations[locale] else {
                    diagnostics.append(
                        LocalizationDiagnostic(
                            id: "missing-\(locale.rawValue)-\(entry.key)",
                            key: entry.key,
                            locale: locale,
                            kind: .missingTranslation,
                            severity: .warning,
                            message: "Key '\(entry.key)' has no localization for \(locale.englishName) (\(locale.rawValue)).",
                            suggestion: "Provide a translated unit or run ChiefKit Pseudoloc / Built-In Domain Merge."
                        )
                    )
                    continue
                }

                // Plural category completeness check
                if isPluralEntry {
                    for requiredCat in locale.requiredPluralCategories where locVal.pluralVariations[requiredCat] == nil {
                        diagnostics.append(
                            LocalizationDiagnostic(
                                id: "plural-\(locale.rawValue)-\(requiredCat.rawValue)-\(entry.key)",
                                key: entry.key,
                                locale: locale,
                                kind: .missingPluralCategory,
                                severity: .error,
                                message: "\(locale.englishName) requires CLDR plural form '.\(requiredCat.rawValue)' for '\(entry.key)'.",
                                suggestion: "Add plural variation '\(requiredCat.rawValue)' (e.g. n in \(requiredCat.sampleIntegerExamples))."
                            )
                        )
                    }
                }

                // Inspect every concrete unit in this locale
                for unit in locVal.allUnits {
                    let actualPlaceholders = extractPlaceholders(from: unit.value)
                    if actualPlaceholders.count != expectedPlaceholders.count {
                        diagnostics.append(
                            LocalizationDiagnostic(
                                id: "ph-count-\(locale.rawValue)-\(entry.key)",
                                key: entry.key,
                                locale: locale,
                                kind: .placeholderCountMismatch,
                                severity: .error,
                                message: "Placeholder count mismatch in '\(locale.rawValue)' for '\(entry.key)': expected \(expectedPlaceholders.count), found \(actualPlaceholders.count).",
                                suggestion: "Ensure all \(expectedPlaceholders.map(\.rawValue).joined(separator: ", ")) specifiers are preserved."
                            )
                        )
                    } else if actualPlaceholders != expectedPlaceholders {
                        diagnostics.append(
                            LocalizationDiagnostic(
                                id: "ph-type-\(locale.rawValue)-\(entry.key)",
                                key: entry.key,
                                locale: locale,
                                kind: .placeholderTypeMismatch,
                                severity: .error,
                                message: "Placeholder specifier types in '\(locale.rawValue)' (\(actualPlaceholders.map(\.rawValue))) differ from source (\(expectedPlaceholders.map(\.rawValue))).",
                                suggestion: "Use positional specifiers like `%1$@` and `%2$lld` when reordering arguments across grammars."
                            )
                        )
                    }

                    // Mobile truncation check
                    let maxAllowed = entry.maxCharacterBudget ?? 96
                    if unit.value.count > maxAllowed {
                        diagnostics.append(
                            LocalizationDiagnostic(
                                id: "len-\(locale.rawValue)-\(entry.key)",
                                key: entry.key,
                                locale: locale,
                                kind: .mobileTruncationHazard,
                                severity: .advisory,
                                message: "Translation in '\(locale.rawValue)' is \(unit.value.count) chars (budget: \(maxAllowed)), risking compact iPhone truncation.",
                                suggestion: "Add an `.iphone` or `.applewatch` device variation with a shorter label."
                            )
                        )
                    }

                    // RTL directional glyph hazard inside Arabic translations
                    if locale.scriptDirection.isRTL && (unit.value.contains("->") || unit.value.contains("→")) {
                        diagnostics.append(
                            LocalizationDiagnostic(
                                id: "rtl-arrow-\(locale.rawValue)-\(entry.key)",
                                key: entry.key,
                                locale: locale,
                                kind: .rtlLayoutHazard,
                                severity: .warning,
                                message: "Hardcoded left-to-right arrow in RTL (\(locale.rawValue)) translation for '\(entry.key)'.",
                                suggestion: "Use bidirectional SF Symbols (`chevron.forward`) or RTL arrow `←` for Arabic."
                            )
                        )
                    }

                    // Leading/trailing whitespace preservation check
                    if sourceTemplate.hasSuffix(" ") != unit.value.hasSuffix(" ") {
                        diagnostics.append(
                            LocalizationDiagnostic(
                                id: "ws-\(locale.rawValue)-\(entry.key)",
                                key: entry.key,
                                locale: locale,
                                kind: .whitespaceBoundaryMismatch,
                                severity: .advisory,
                                message: "Trailing whitespace mismatch between '\(document.sourceLanguage.rawValue)' and '\(locale.rawValue)' on '\(entry.key)'.",
                                suggestion: "Match trailing space semantics or compose spacing via SwiftUI `HStack`."
                            )
                        )
                    }
                }
            }
        }

        // Source-level RTL layout hazard scan when catalog targets an RTL locale
        if let swiftUISource, document.targetLocales.contains(where: { $0.scriptDirection.isRTL }) {
            let rtlHazards: [(token: String, reason: String, fix: String)] = [
                (".padding(.left", "Absolute `.left` edge padding breaks RTL mirroring", "Replace `.left` with `.leading`."),
                (".padding(.right", "Absolute `.right` edge padding breaks RTL mirroring", "Replace `.right` with `.trailing`."),
                ("chevron.right", "Fixed `chevron.right` icon does not auto-mirror in Arabic RTL", "Use semantic `chevron.forward` instead."),
                ("arrow.right", "Fixed `arrow.right` icon points against reading order in RTL", "Use `arrow.forward` or `.flipsForRightToLeftLayoutDirection(true)`.")
            ]
            for hazard in rtlHazards where swiftUISource.contains(hazard.token) {
                diagnostics.append(
                    LocalizationDiagnostic(
                        id: "rtl-source-\(hazard.token)",
                        key: hazard.token,
                        locale: .ar,
                        kind: .rtlLayoutHazard,
                        severity: .warning,
                        message: "\(hazard.reason) while Arabic (`ar`) is enabled.",
                        suggestion: hazard.fix
                    )
                )
            }
        }

        return diagnostics
    }

    // MARK: - 4) Pseudolocalization Engine

    public static func pseudolocalize(_ text: String, mode: PseudolocMode) -> String {
        let placeholderPattern = #"%(\d+\$)?(\.\d+)?(lld|ld|[dDuUxXoOfeEgGcCsS@%])"#
        guard let regex = try? NSRegularExpression(pattern: placeholderPattern) else {
            return transformPlainSegment(text, mode: mode)
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)

        var segments: [(isPlaceholder: Bool, content: String)] = []
        var cursor = text.startIndex
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            if cursor < range.lowerBound {
                segments.append((false, String(text[cursor..<range.lowerBound])))
            }
            segments.append((true, String(text[range])))
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            segments.append((false, String(text[cursor...])))
        }

        switch mode {
        case .accentedExpanded:
            let mapped = segments.map { seg in
                seg.isPlaceholder ? seg.content : accentCharacters(seg.content)
            }.joined()
            let padCount = max(2, Int((Double(text.count) * 0.30).rounded()))
            let pad = String(repeating: "~", count: min(14, padCount))
            return "[\(mapped) \(pad)]"

        case .rtlMirroredBidi:
            let mapped = segments.map { seg in
                seg.isPlaceholder ? seg.content : "\u{202E}\(seg.content)\u{202C}"
            }.joined()
            return "\u{200F}⟪\(mapped)⟫\u{200F}"

        case .bracketedBounds:
            return "⟦\(text)⟧"

        case .doubleLengthTruncationTest:
            let plainCopy = segments.filter { !$0.isPlaceholder }.map(\.content).joined().trimmingCharacters(in: .whitespaces)
            return plainCopy.isEmpty ? text : "[\(text) · \(plainCopy)]"
        }
    }

    public static func generatePseudolocalizedCatalog(
        from document: StringCatalogDocument,
        mode: PseudolocMode,
        intoLocale targetLocale: LocaleCode
    ) -> StringCatalogDocument {
        var copy = document
        if !copy.targetLocales.contains(targetLocale) {
            copy.targetLocales.append(targetLocale)
        }

        for (key, var entry) in copy.entries where entry.shouldTranslate {
            let baseVal = entry.localizations[document.sourceLanguage] ?? LocaleLocalizationValue.simple(key)
            var pseudoVal = LocaleLocalizationValue()

            if let su = baseVal.stringUnit {
                pseudoVal.stringUnit = TranslationUnit(state: .needsReview, value: pseudolocalize(su.value, mode: mode))
            }
            for (cat, unit) in baseVal.pluralVariations {
                pseudoVal.pluralVariations[cat] = TranslationUnit(state: .needsReview, value: pseudolocalize(unit.value, mode: mode))
            }
            for (dev, unit) in baseVal.deviceVariations {
                pseudoVal.deviceVariations[dev] = TranslationUnit(state: .needsReview, value: pseudolocalize(unit.value, mode: mode))
            }

            if pseudoVal.allUnits.isEmpty {
                pseudoVal.stringUnit = TranslationUnit(state: .needsReview, value: pseudolocalize(key, mode: mode))
            }
            entry.localizations[targetLocale] = pseudoVal
            copy.entries[key] = entry
        }
        return copy
    }

    private static func transformPlainSegment(_ segment: String, mode: PseudolocMode) -> String {
        switch mode {
        case .accentedExpanded: return "[\(accentCharacters(segment)) ~~~]"
        case .rtlMirroredBidi: return "\u{202E}\(segment)\u{202C}"
        case .bracketedBounds: return "⟦\(segment)⟧"
        case .doubleLengthTruncationTest: return "[\(segment) · \(segment)]"
        }
    }

    private static func accentCharacters(_ input: String) -> String {
        let table: [Character: Character] = [
            "a": "å", "b": "ƀ", "c": "ç", "d": "ď", "e": "é", "f": "ƒ", "g": "ğ",
            "h": "ĥ", "i": "î", "j": "ĵ", "k": "ķ", "l": "ľ", "m": "ɱ", "n": "ñ",
            "o": "ø", "p": "þ", "q": "ɋ", "r": "ř", "s": "š", "t": "ŧ", "u": "ü",
            "v": "ṽ", "w": "ŵ", "x": "ẋ", "y": "ý", "z": "ž",
            "A": "Å", "B": "Ɓ", "C": "Ç", "D": "Ď", "E": "É", "F": "Ƒ", "G": "Ğ",
            "H": "Ĥ", "I": "Î", "J": "Ĵ", "K": "Ķ", "L": "Ľ", "M": "Μ", "N": "Ñ",
            "O": "Ø", "P": "Þ", "Q": "Ɋ", "R": "Ř", "S": "Š", "T": "Ŧ", "U": "Ü",
            "V": "Ṽ", "W": "Ŵ", "X": "Ẋ", "Y": "Ý", "Z": "Ž"
        ]
        return String(input.map { table[$0] ?? $0 })
    }

    // MARK: - 5) Strongly-Typed Swift 6 `enum L10n` Code Synthesizer

    public static func synthesizeL10nSwiftEnum(
        from document: StringCatalogDocument,
        enumName: String = "L10n"
    ) -> String {
        var lines: [String] = [
            "// Generated by ChiefKit Studio 3.0 — Strongly-Typed Swift 6 String Catalog Accessors",
            "// Source Catalog: \(document.catalogName).xcstrings (\(document.entries.count) keys)",
            "import Foundation",
            "",
            "public enum \(enumName): Sendable {"
        ]

        var usedIdentifiers = Set<String>()

        for entry in document.sortedEntries {
            let baseIdentifier = makeSafeSwiftAccessorIdentifier(from: entry.key, used: &usedIdentifiers)
            let sourceTemplate = entry.localizations[document.sourceLanguage]?.resolvedTemplate(for: document.sourceLanguage) ?? entry.key
            let placeholders = extractPlaceholders(from: sourceTemplate)
            let escapedKey = entry.key
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let escapedDefault = sourceTemplate
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let commentClause: String
            if let comment = entry.comment, !comment.isEmpty {
                let escapedComment = comment
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                commentClause = ", comment: \"\(escapedComment)\""
            } else {
                commentClause = ""
            }

            if let comment = entry.comment, !comment.isEmpty {
                lines.append("    /// \(comment)")
            }

            if placeholders.isEmpty {
                lines.append("    public static var \(baseIdentifier): String {")
                lines.append("        String(localized: \"\(escapedKey)\", defaultValue: \"\(escapedDefault)\", table: \"\(document.catalogName)\"\(commentClause))")
                lines.append("    }")
            } else {
                let params = placeholders.enumerated().map { idx, kind in
                    "_ arg\(idx + 1): \(kind.swiftParameterType)"
                }.joined(separator: ", ")
                let formatArgs = placeholders.enumerated().map { idx, _ in
                    "arg\(idx + 1)"
                }.joined(separator: ", ")

                lines.append("    public static func \(baseIdentifier)(\(params)) -> String {")
                lines.append("        let format = String(localized: \"\(escapedKey)\", defaultValue: \"\(escapedDefault)\", table: \"\(document.catalogName)\"\(commentClause))")
                lines.append("        return String.localizedStringWithFormat(format, \(formatArgs))")
                lines.append("    }")
            }
            lines.append("")
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private static func makeSafeSwiftAccessorIdentifier(from rawKey: String, used: inout Set<String>) -> String {
        let alnumReplaced = rawKey.unicodeScalars.map { scalar -> String in
            if CharacterSet.alphanumerics.contains(scalar) {
                return String(scalar)
            }
            return "_"
        }.joined()

        let candidateCamel = SchemaNamingHelpers.camelCase(alnumReplaced)
        var base = candidateCamel.isEmpty ? "localizedEntry" : candidateCamel
        if let first = base.first, first.isNumber {
            base = "key\(base)"
        }

        let swiftKeywords: Set<String> = [
            "continue", "return", "default", "switch", "case", "class", "struct",
            "enum", "protocol", "import", "true", "false", "nil", "in", "for", "self"
        ]
        if swiftKeywords.contains(base) {
            base = "\(base)Label"
        }

        var unique = base
        var suffix = 2
        while !used.insert(unique).inserted {
            unique = "\(base)\(suffix)"
            suffix += 1
        }
        return unique
    }
}
