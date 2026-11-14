import Foundation

// MARK: - Script Direction, Locales & CLDR Plural Categories

public enum ScriptLayoutDirection: String, CaseIterable, Codable, Hashable, Sendable {
    case leftToRight = "LTR"
    case rightToLeft = "RTL"

    public var isRTL: Bool { self == .rightToLeft }
}

public enum CLDRPluralCategory: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case zero
    case one
    case two
    case few
    case many
    case other

    public var id: String { rawValue }

    public var sampleIntegerExamples: [Int] {
        switch self {
        case .zero: [0]
        case .one: [1]
        case .two: [2]
        case .few: [3, 4, 10]
        case .many: [11, 25, 99]
        case .other: [5, 100, 102]
        }
    }
}

public enum LocaleCode: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case en = "en"
    case tr = "tr"
    case de = "de"
    case fr = "fr"
    case es = "es"
    case ja = "ja"
    case ar = "ar"
    case zhHans = "zh-Hans"
    case ptBR = "pt-BR"
    case ko = "ko"

    public var id: String { rawValue }
    public var bcp47Tag: String { rawValue }

    public var englishName: String {
        switch self {
        case .en: "English"
        case .tr: "Turkish"
        case .de: "German"
        case .fr: "French"
        case .es: "Spanish"
        case .ja: "Japanese"
        case .ar: "Arabic"
        case .zhHans: "Chinese (Simplified)"
        case .ptBR: "Portuguese (Brazil)"
        case .ko: "Korean"
        }
    }

    public var nativeDisplayName: String {
        switch self {
        case .en: "English"
        case .tr: "Türkçe"
        case .de: "Deutsch"
        case .fr: "Français"
        case .es: "Español"
        case .ja: "日本語"
        case .ar: "العربية"
        case .zhHans: "简体中文"
        case .ptBR: "Português (Brasil)"
        case .ko: "한국어"
        }
    }

    public var scriptDirection: ScriptLayoutDirection {
        switch self {
        case .ar: .rightToLeft
        default: .leftToRight
        }
    }

    /// Typical UI label width expansion/contraction multiplier relative to English (`1.0`).
    public var characterExpansionRatio: Double {
        switch self {
        case .en: 1.00
        case .tr: 1.16
        case .de: 1.34
        case .fr: 1.24
        case .es: 1.21
        case .ja: 0.76
        case .ar: 1.18
        case .zhHans: 0.64
        case .ptBR: 1.26
        case .ko: 0.80
        }
    }

    /// Cardinal CLDR plural categories required by Xcode String Catalogs for this locale.
    public var requiredPluralCategories: [CLDRPluralCategory] {
        switch self {
        case .ar:
            return [.zero, .one, .two, .few, .many, .other]
        case .ja, .zhHans, .ko:
            return [.other]
        case .en, .tr, .de, .es, .fr, .ptBR:
            return [.one, .other]
        }
    }
}

/// Evaluates Unicode CLDR v45 integer cardinal plural category for a given count and locale.
public func pluralCategory(for count: Int, locale: LocaleCode) -> CLDRPluralCategory {
    let n = abs(count)
    switch locale {
    case .ar:
        if n == 0 { return .zero }
        if n == 1 { return .one }
        if n == 2 { return .two }
        let mod100 = n % 100
        if mod100 >= 3 && mod100 <= 10 { return .few }
        if mod100 >= 11 && mod100 <= 99 { return .many }
        return .other
    case .ja, .zhHans, .ko:
        return .other
    case .fr, .ptBR:
        return (n == 0 || n == 1) ? .one : .other
    case .en, .tr, .de, .es:
        return n == 1 ? .one : .other
    }
}

// MARK: - Device Variations & Translation Units

public enum DeviceVariationKind: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case mac
    case iphone
    case ipad
    case applevision
    case applewatch

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .mac: "macOS"
        case .iphone: "iPhone"
        case .ipad: "iPad"
        case .applevision: "visionOS"
        case .applewatch: "Apple Watch"
        }
    }

    public var recommendedMaxButtonCharacters: Int {
        switch self {
        case .applewatch: 16
        case .iphone: 26
        case .ipad: 36
        case .applevision: 34
        case .mac: 44
        }
    }
}

public enum TranslationState: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case translated
    case needsReview = "needs_review"
    case new
    case stale

    public var id: String { rawValue }
}

public enum StringExtractionState: String, CaseIterable, Codable, Hashable, Sendable {
    case manual
    case migrated
    case extractedWithValue = "extracted_with_value"
    case stale
}

public struct TranslationUnit: Codable, Hashable, Sendable {
    public var state: TranslationState
    public var value: String

    public init(state: TranslationState = .translated, value: String) {
        self.state = state
        self.value = value
    }
}

public struct LocaleLocalizationValue: Codable, Hashable, Sendable {
    public var stringUnit: TranslationUnit?
    public var pluralVariations: [CLDRPluralCategory: TranslationUnit]
    public var deviceVariations: [DeviceVariationKind: TranslationUnit]

    public init(
        stringUnit: TranslationUnit? = nil,
        pluralVariations: [CLDRPluralCategory: TranslationUnit] = [:],
        deviceVariations: [DeviceVariationKind: TranslationUnit] = [:]
    ) {
        self.stringUnit = stringUnit
        self.pluralVariations = pluralVariations
        self.deviceVariations = deviceVariations
    }

    public static func simple(_ value: String, state: TranslationState = .translated) -> LocaleLocalizationValue {
        LocaleLocalizationValue(stringUnit: TranslationUnit(state: state, value: value))
    }

    public static func plural(
        _ forms: [CLDRPluralCategory: String],
        state: TranslationState = .translated
    ) -> LocaleLocalizationValue {
        let mapped = Dictionary(uniqueKeysWithValues: forms.map { ($0.key, TranslationUnit(state: state, value: $0.value)) })
        return LocaleLocalizationValue(pluralVariations: mapped)
    }

    public static func device(
        _ variants: [DeviceVariationKind: String],
        fallback: String? = nil,
        state: TranslationState = .translated
    ) -> LocaleLocalizationValue {
        let mapped = Dictionary(uniqueKeysWithValues: variants.map { ($0.key, TranslationUnit(state: state, value: $0.value)) })
        return LocaleLocalizationValue(
            stringUnit: fallback.map { TranslationUnit(state: state, value: $0) },
            deviceVariations: mapped
        )
    }

    public var allUnits: [TranslationUnit] {
        var list: [TranslationUnit] = []
        if let stringUnit { list.append(stringUnit) }
        for cat in CLDRPluralCategory.allCases {
            if let u = pluralVariations[cat] { list.append(u) }
        }
        for dev in DeviceVariationKind.allCases {
            if let u = deviceVariations[dev] { list.append(u) }
        }
        return list
    }

    public var effectiveState: TranslationState {
        let units = allUnits
        guard !units.isEmpty else { return .new }
        if units.contains(where: { $0.state == .stale }) { return .stale }
        if units.contains(where: { $0.state == .needsReview }) { return .needsReview }
        if units.contains(where: { $0.state == .new || $0.value.isEmpty }) { return .new }
        return .translated
    }

    public func resolvedTemplate(
        for locale: LocaleCode,
        count: Int? = nil,
        device: DeviceVariationKind? = nil
    ) -> String? {
        if let device, let devUnit = deviceVariations[device], !devUnit.value.isEmpty {
            return devUnit.value
        }
        if let count, !pluralVariations.isEmpty {
            let category = pluralCategory(for: count, locale: locale)
            if let exact = pluralVariations[category]?.value, !exact.isEmpty {
                return exact
            }
            if let fallbackOther = pluralVariations[.other]?.value, !fallbackOther.isEmpty {
                return fallbackOther
            }
        }
        if let base = stringUnit?.value, !base.isEmpty {
            return base
        }
        if let anyPlural = pluralVariations[.other]?.value ?? pluralVariations.values.first?.value {
            return anyPlural
        }
        return deviceVariations.values.first?.value
    }
}

// MARK: - StringCatalogEntry & Coverage Metrics

public struct StringCatalogEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: String { key }
    public var key: String
    public var comment: String?
    public var extractionState: StringExtractionState
    public var shouldTranslate: Bool
    public var maxCharacterBudget: Int?
    public var localizations: [LocaleCode: LocaleLocalizationValue]

    public init(
        key: String,
        comment: String? = nil,
        extractionState: StringExtractionState = .manual,
        shouldTranslate: Bool = true,
        maxCharacterBudget: Int? = nil,
        localizations: [LocaleCode: LocaleLocalizationValue] = [:]
    ) {
        self.key = key
        self.comment = comment
        self.extractionState = extractionState
        self.shouldTranslate = shouldTranslate
        self.maxCharacterBudget = maxCharacterBudget
        self.localizations = localizations
    }

    public var isPluralized: Bool {
        localizations.values.contains { !$0.pluralVariations.isEmpty }
    }

    public var hasDeviceVariations: Bool {
        localizations.values.contains { !$0.deviceVariations.isEmpty }
    }
}

public struct LocaleCoverageSummary: Identifiable, Codable, Hashable, Sendable {
    public var id: String { locale.rawValue }
    public var locale: LocaleCode
    public var totalTranslatableKeys: Int
    public var translatedCount: Int
    public var needsReviewCount: Int
    public var missingCount: Int
    public var completionRatio: Double

    public init(
        locale: LocaleCode,
        totalTranslatableKeys: Int,
        translatedCount: Int,
        needsReviewCount: Int,
        missingCount: Int
    ) {
        self.locale = locale
        self.totalTranslatableKeys = totalTranslatableKeys
        self.translatedCount = translatedCount
        self.needsReviewCount = needsReviewCount
        self.missingCount = missingCount
        if totalTranslatableKeys <= 0 {
            self.completionRatio = 1.0
        } else {
            self.completionRatio = Double(translatedCount) / Double(totalTranslatableKeys)
        }
    }

    public var completionPercentage: Int {
        Int((completionRatio * 100.0).rounded())
    }
}

// MARK: - StringCatalogDocument

public enum FormatArgumentValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
}

public struct StringCatalogDocument: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var catalogName: String
    public var sourceLanguage: LocaleCode
    public var version: String
    public var targetLocales: [LocaleCode]
    public var entries: [String: StringCatalogEntry]

    public init(
        id: UUID = UUID(),
        catalogName: String = "Localizable",
        sourceLanguage: LocaleCode = .en,
        version: String = "1.0",
        targetLocales: [LocaleCode] = [.en, .tr, .de, .fr, .es, .ja, .ar],
        entries: [String: StringCatalogEntry] = [:]
    ) {
        self.id = id
        self.catalogName = catalogName
        self.sourceLanguage = sourceLanguage
        self.version = version
        var locales = targetLocales
        if !locales.contains(sourceLanguage) {
            locales.insert(sourceLanguage, at: 0)
        }
        self.targetLocales = locales
        self.entries = entries
    }

    public var sortedEntries: [StringCatalogEntry] {
        entries.keys.sorted().compactMap { entries[$0] }
    }

    public mutating func upsertSimpleTranslation(
        key: String,
        comment: String? = nil,
        locale: LocaleCode,
        value: String,
        state: TranslationState = .translated
    ) {
        if !targetLocales.contains(locale) {
            targetLocales.append(locale)
        }
        var entry = entries[key] ?? StringCatalogEntry(key: key, comment: comment)
        if let comment, !comment.isEmpty {
            entry.comment = comment
        }
        var locVal = entry.localizations[locale] ?? LocaleLocalizationValue()
        locVal.stringUnit = TranslationUnit(state: state, value: value)
        entry.localizations[locale] = locVal
        entries[key] = entry
    }

    public mutating func upsertPluralTranslation(
        key: String,
        comment: String? = nil,
        locale: LocaleCode,
        forms: [CLDRPluralCategory: String],
        state: TranslationState = .translated
    ) {
        if !targetLocales.contains(locale) {
            targetLocales.append(locale)
        }
        var entry = entries[key] ?? StringCatalogEntry(key: key, comment: comment)
        if let comment, !comment.isEmpty {
            entry.comment = comment
        }
        var locVal = entry.localizations[locale] ?? LocaleLocalizationValue()
        for (category, text) in forms {
            locVal.pluralVariations[category] = TranslationUnit(state: state, value: text)
        }
        entry.localizations[locale] = locVal
        entries[key] = entry
    }

    public mutating func upsertDeviceVariation(
        key: String,
        comment: String? = nil,
        locale: LocaleCode,
        device: DeviceVariationKind,
        value: String,
        state: TranslationState = .translated
    ) {
        if !targetLocales.contains(locale) {
            targetLocales.append(locale)
        }
        var entry = entries[key] ?? StringCatalogEntry(key: key, comment: comment)
        if let comment, !comment.isEmpty {
            entry.comment = comment
        }
        var locVal = entry.localizations[locale] ?? LocaleLocalizationValue()
        locVal.deviceVariations[device] = TranslationUnit(state: state, value: value)
        entry.localizations[locale] = locVal
        entries[key] = entry
    }

    /// Resolves a localized string on all platforms (Linux & macOS) with plural, device, and placeholder interpolation.
    public func resolve(
        key: String,
        locale: LocaleCode,
        count: Int? = nil,
        device: DeviceVariationKind? = nil,
        arguments: [FormatArgumentValue] = []
    ) -> String {
        guard let entry = entries[key] else { return key }
        let template = entry.localizations[locale]?.resolvedTemplate(for: locale, count: count, device: device)
            ?? entry.localizations[sourceLanguage]?.resolvedTemplate(for: sourceLanguage, count: count, device: device)
            ?? key

        var effectiveArgs = arguments
        if effectiveArgs.isEmpty, let count {
            effectiveArgs = [.int(count)]
        }
        return Self.interpolateFormatSpecifiers(in: template, arguments: effectiveArgs)
    }

    public func coverageReport() -> [LocaleCoverageSummary] {
        let translatable = entries.values.filter(\.shouldTranslate)
        let total = translatable.count

        return targetLocales.map { locale in
            var translated = 0
            var needsReview = 0
            var missing = 0

            for entry in translatable {
                guard let locVal = entry.localizations[locale] else {
                    missing += 1
                    continue
                }
                switch locVal.effectiveState {
                case .translated:
                    translated += 1
                case .needsReview:
                    needsReview += 1
                case .new, .stale:
                    missing += 1
                }
            }

            return LocaleCoverageSummary(
                locale: locale,
                totalTranslatableKeys: total,
                translatedCount: translated,
                needsReviewCount: needsReview,
                missingCount: missing
            )
        }
    }

    public func merging(_ other: StringCatalogDocument) -> StringCatalogDocument {
        var merged = self
        for loc in other.targetLocales where !merged.targetLocales.contains(loc) {
            merged.targetLocales.append(loc)
        }
        for (key, incomingEntry) in other.entries {
            if var existing = merged.entries[key] {
                if existing.comment == nil { existing.comment = incomingEntry.comment }
                for (loc, val) in incomingEntry.localizations {
                    existing.localizations[loc] = val
                }
                merged.entries[key] = existing
            } else {
                merged.entries[key] = incomingEntry
            }
        }
        return merged
    }

    /// Safe cross-platform printf-style placeholder substitution supporting positional (`%1$@`) and sequential (`%@`, `%lld`, `%d`, `%.2f`).
    public static func interpolateFormatSpecifiers(
        in template: String,
        arguments: [FormatArgumentValue]
    ) -> String {
        guard !arguments.isEmpty else { return template }
        let pattern = #"%(\d+\$)?(\.\d+)?(lld|ld|[dDuUxXoOfeEgGcCsS@%])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return template }

        let nsRange = NSRange(template.startIndex..<template.endIndex, in: template)
        let matches = regex.matches(in: template, range: nsRange)
        guard !matches.isEmpty else { return template }

        var result = ""
        var cursor = template.startIndex
        var sequentialIndex = 0

        for match in matches {
            guard let fullRange = Range(match.range, in: template) else { continue }
            result += template[cursor..<fullRange.lowerBound]
            let token = String(template[fullRange])

            if token == "%%" {
                result += "%"
                cursor = fullRange.upperBound
                continue
            }

            let argIndex: Int
            if let posRange = Range(match.range(at: 1), in: template) {
                let digits = template[posRange].dropLast() // drop '$'
                argIndex = max(0, (Int(digits) ?? 1) - 1)
            } else {
                argIndex = sequentialIndex
                sequentialIndex += 1
            }

            let precisionDigits: Int?
            if let precRange = Range(match.range(at: 2), in: template) {
                precisionDigits = Int(template[precRange].dropFirst()) // drop '.'
            } else {
                precisionDigits = nil
            }

            if argIndex < arguments.count {
                switch arguments[argIndex] {
                case .string(let str):
                    result += str
                case .int(let intVal):
                    result += "\(intVal)"
                case .double(let dblVal):
                    let p = precisionDigits ?? 2
                    result += String(format: "%.\(p)f", dblVal)
                }
            } else {
                result += token
            }

            cursor = fullRange.upperBound
        }

        result += template[cursor...]
        return result
    }
}
