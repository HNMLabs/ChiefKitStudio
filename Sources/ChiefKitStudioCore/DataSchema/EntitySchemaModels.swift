import Foundation

// MARK: - Field Types & Default Values

public enum SchemaFieldTypeKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case uuid
    case string
    case text
    case int64
    case double
    case decimal
    case bool
    case timestamp
    case jsonBlob
    case enumCases
    case vectorEmbedding

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .uuid: "UUID"
        case .string: "Bounded String"
        case .text: "Long Text"
        case .int64: "Int64"
        case .double: "Double (Float64)"
        case .decimal: "Fixed Decimal"
        case .bool: "Boolean"
        case .timestamp: "UTC Timestamp"
        case .jsonBlob: "Structured JSON"
        case .enumCases: "Closed Enum"
        case .vectorEmbedding: "Vector Embedding"
        }
    }
}

public enum SchemaFieldType: Codable, Hashable, Sendable {
    case uuid
    case string(maxLength: Int?)
    case text
    case int64
    case double
    case decimal(precision: Int, scale: Int)
    case bool
    case timestamp
    case jsonBlob(schemaHint: String?)
    case enumCases([String])
    case vectorEmbedding(dimensions: Int)

    public var kind: SchemaFieldTypeKind {
        switch self {
        case .uuid: .uuid
        case .string: .string
        case .text: .text
        case .int64: .int64
        case .double: .double
        case .decimal: .decimal
        case .bool: .bool
        case .timestamp: .timestamp
        case .jsonBlob: .jsonBlob
        case .enumCases: .enumCases
        case .vectorEmbedding: .vectorEmbedding
        }
    }

    public var conciseLabel: String {
        switch self {
        case .uuid:
            return "uuid"
        case .string(let maxLength):
            if let maxLength {
                return "varchar(\(maxLength))"
            }
            return "varchar"
        case .text:
            return "text"
        case .int64:
            return "int64"
        case .double:
            return "double"
        case .decimal(let precision, let scale):
            return "decimal(\(precision),\(scale))"
        case .bool:
            return "bool"
        case .timestamp:
            return "timestamp"
        case .jsonBlob(let hint):
            if let hint, !hint.isEmpty {
                return "json<\(hint)>"
            }
            return "json"
        case .enumCases(let cases):
            return "enum[\(cases.count)]"
        case .vectorEmbedding(let dims):
            return "vector[\(dims)]"
        }
    }

    public var mermaidTypeToken: String {
        switch self {
        case .uuid: "UUID"
        case .string(let maxLength): maxLength.map { "VARCHAR_\($0)" } ?? "VARCHAR"
        case .text: "TEXT"
        case .int64: "BIGINT"
        case .double: "DOUBLE"
        case .decimal(let p, let s): "DECIMAL_\(p)_\(s)"
        case .bool: "BOOLEAN"
        case .timestamp: "TIMESTAMPTZ"
        case .jsonBlob: "JSONB"
        case .enumCases: "ENUM"
        case .vectorEmbedding(let dims): "VECTOR_\(dims)"
        }
    }

    public func swiftTypeName(entityName: String, attributeName: String, isOptional: Bool) -> String {
        let base: String
        switch self {
        case .uuid:
            base = "UUID"
        case .string, .text:
            base = "String"
        case .int64:
            base = "Int64"
        case .double:
            base = "Double"
        case .decimal:
            base = "Decimal"
        case .bool:
            base = "Bool"
        case .timestamp:
            base = "Date"
        case .jsonBlob:
            base = "Data"
        case .enumCases:
            base = "\(entityName)\(SchemaNamingHelpers.pascalCase(attributeName))"
        case .vectorEmbedding:
            base = "[Float]"
        }
        return isOptional ? "\(base)?" : base
    }

    /// Strict SQLite 3.37+ `STRICT` table column affinity (`TEXT`, `INTEGER`, `REAL`, `BLOB`, `ANY`).
    public var sqliteStrictColumnType: String {
        switch self {
        case .uuid, .string, .text, .timestamp, .jsonBlob, .enumCases, .decimal:
            return "TEXT"
        case .int64, .bool:
            return "INTEGER"
        case .double:
            return "REAL"
        case .vectorEmbedding:
            return "BLOB"
        }
    }

    public var coreDataAttributeType: String {
        switch self {
        case .uuid: "UUID"
        case .string, .text, .enumCases: "String"
        case .int64: "Integer 64"
        case .double: "Double"
        case .decimal: "Decimal"
        case .bool: "Boolean"
        case .timestamp: "Date"
        case .jsonBlob, .vectorEmbedding: "Binary"
        }
    }

    public var estimatedAverageBytes: Int {
        switch self {
        case .uuid: 16
        case .string(let maxLength): min(max(24, (maxLength ?? 64) / 2), 512)
        case .text: 640
        case .int64: 8
        case .double: 8
        case .decimal: 20
        case .bool: 1
        case .timestamp: 8
        case .jsonBlob: 512
        case .enumCases: 16
        case .vectorEmbedding(let dimensions): max(16, dimensions * 4)
        }
    }
}

public enum SchemaDefaultValue: Codable, Hashable, Sendable {
    case none
    case uuidV4
    case nowTimestamp
    case literalString(String)
    case literalInt(Int64)
    case literalDouble(Double)
    case literalBool(Bool)
    case emptyJSONObject
    case emptyJSONArray

    public var swiftExpression: String? {
        switch self {
        case .none:
            return nil
        case .uuidV4:
            return "UUID()"
        case .nowTimestamp:
            return "Date()"
        case .literalString(let value):
            let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        case .literalInt(let value):
            return "\(value)"
        case .literalDouble(let value):
            return "\(value)"
        case .literalBool(let value):
            return value ? "true" : "false"
        case .emptyJSONObject:
            return "Data(\"{}\".utf8)"
        case .emptyJSONArray:
            return "Data(\"[]\".utf8)"
        }
    }

    public var sqliteDefaultClause: String? {
        switch self {
        case .none:
            return nil
        case .uuidV4:
            return "DEFAULT (lower(hex(randomblob(16))))"
        case .nowTimestamp:
            return "DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))"
        case .literalString(let value):
            let escaped = value.replacingOccurrences(of: "'", with: "''")
            return "DEFAULT '\(escaped)'"
        case .literalInt(let value):
            return "DEFAULT \(value)"
        case .literalDouble(let value):
            return "DEFAULT \(value)"
        case .literalBool(let value):
            return "DEFAULT \(value ? 1 : 0)"
        case .emptyJSONObject:
            return "DEFAULT '{}'"
        case .emptyJSONArray:
            return "DEFAULT '[]'"
        }
    }
}

// MARK: - Attributes, Relationships, Indexes & Constraints

public struct SchemaAttribute: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var fieldType: SchemaFieldType
    public var isPrimaryKey: Bool
    public var isNullable: Bool
    public var isUnique: Bool
    public var isIndexed: Bool
    public var isSensitivePII: Bool
    public var isFullTextSearchable: Bool
    public var defaultValue: SchemaDefaultValue
    public var documentation: String

    public init(
        id: UUID = UUID(),
        name: String,
        fieldType: SchemaFieldType,
        isPrimaryKey: Bool = false,
        isNullable: Bool = false,
        isUnique: Bool = false,
        isIndexed: Bool = false,
        isSensitivePII: Bool = false,
        isFullTextSearchable: Bool = false,
        defaultValue: SchemaDefaultValue = .none,
        documentation: String = ""
    ) {
        self.id = id
        self.name = name
        self.fieldType = fieldType
        self.isPrimaryKey = isPrimaryKey
        self.isNullable = isPrimaryKey ? false : isNullable
        self.isUnique = isPrimaryKey ? true : isUnique
        self.isIndexed = isPrimaryKey ? true : isIndexed
        self.isSensitivePII = isSensitivePII
        self.isFullTextSearchable = isFullTextSearchable
        self.defaultValue = defaultValue
        self.documentation = documentation
    }
}

public enum SchemaRelationshipKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case oneToOne
    case oneToMany
    case manyToMany

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .oneToOne: "1 : 1 (One-to-One)"
        case .oneToMany: "1 : N (One-to-Many)"
        case .manyToMany: "M : N (Many-to-Many)"
        }
    }

    public func mermaidConnector(isOptional: Bool) -> String {
        switch self {
        case .oneToOne:
            return isOptional ? "||--o|" : "||--||"
        case .oneToMany:
            return isOptional ? "|o--o{" : "||--o{"
        case .manyToMany:
            return "}o--o{"
        }
    }
}

public enum SchemaDeleteRule: String, CaseIterable, Codable, Identifiable, Sendable {
    case cascade
    case nullify
    case deny

    public var id: String { rawValue }

    public var sqliteAction: String {
        switch self {
        case .cascade: "CASCADE"
        case .nullify: "SET NULL"
        case .deny: "RESTRICT"
        }
    }

    public var swiftDataRuleName: String {
        switch self {
        case .cascade: ".cascade"
        case .nullify: ".nullify"
        case .deny: ".deny"
        }
    }

    public var coreDataRuleName: String {
        switch self {
        case .cascade: "Cascade"
        case .nullify: "Nullify"
        case .deny: "Deny"
        }
    }
}

public struct SchemaRelationship: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var sourceEntityName: String
    public var targetEntityName: String
    public var inverseName: String?
    public var kind: SchemaRelationshipKind
    public var deleteRule: SchemaDeleteRule
    public var isOptional: Bool
    public var foreignKeyColumn: String
    public var joinTableName: String?
    public var documentation: String

    public init(
        id: UUID = UUID(),
        name: String,
        sourceEntityName: String,
        targetEntityName: String,
        inverseName: String? = nil,
        kind: SchemaRelationshipKind,
        deleteRule: SchemaDeleteRule = .nullify,
        isOptional: Bool = false,
        foreignKeyColumn: String? = nil,
        joinTableName: String? = nil,
        documentation: String = ""
    ) {
        self.id = id
        self.name = name
        self.sourceEntityName = sourceEntityName
        self.targetEntityName = targetEntityName
        self.inverseName = inverseName
        self.kind = kind
        self.deleteRule = deleteRule
        self.isOptional = isOptional
        let defaultFK = "\(SchemaNamingHelpers.snakeCase(sourceEntityName))_id"
        self.foreignKeyColumn = foreignKeyColumn ?? defaultFK
        if kind == .manyToMany {
            let fallbackJoin = "\(SchemaNamingHelpers.snakeCase(sourceEntityName))_\(SchemaNamingHelpers.snakeCase(targetEntityName))_links"
            self.joinTableName = joinTableName ?? fallbackJoin
        } else {
            self.joinTableName = joinTableName
        }
        self.documentation = documentation
    }
}

public enum SchemaIndexKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case btree
    case uniqueBTree
    case fts5FullText
    case partialConditional
    case vectorHNSW

    public var id: String { rawValue }
}

public struct SchemaIndex: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var columns: [String]
    public var kind: SchemaIndexKind
    public var wherePredicateSQL: String?
    public var rationale: String

    public init(
        id: UUID = UUID(),
        name: String,
        columns: [String],
        kind: SchemaIndexKind = .btree,
        wherePredicateSQL: String? = nil,
        rationale: String = ""
    ) {
        self.id = id
        self.name = name
        self.columns = columns
        self.kind = kind
        self.wherePredicateSQL = wherePredicateSQL
        self.rationale = rationale
    }
}

public enum SchemaConstraintKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case checkExpression
    case compositeUnique
    case nonEmptyTrimmed
    case numericBounds
    case immutableOnceSet

    public var id: String { rawValue }
}

public struct SchemaConstraint: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: SchemaConstraintKind
    public var columns: [String]
    public var expression: String
    public var errorMessage: String

    public init(
        id: UUID = UUID(),
        name: String,
        kind: SchemaConstraintKind,
        columns: [String],
        expression: String,
        errorMessage: String = ""
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.columns = columns
        self.expression = expression
        self.errorMessage = errorMessage
    }
}

public struct SchemaEntityCanvasPosition: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct SchemaEntity: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var tableName: String
    public var summary: String
    public var domainGroup: String
    public var accentHex: String
    public var isAuditedWithTimestamps: Bool
    public var isSoftDeletable: Bool
    public var isTenantScoped: Bool
    public var estimatedRowCount: Int
    public var position: SchemaEntityCanvasPosition
    public var attributes: [SchemaAttribute]
    public var indexes: [SchemaIndex]
    public var constraints: [SchemaConstraint]

    public init(
        id: UUID = UUID(),
        name: String,
        tableName: String? = nil,
        summary: String = "",
        domainGroup: String = "Core",
        accentHex: String = "#0D5CF0",
        isAuditedWithTimestamps: Bool = true,
        isSoftDeletable: Bool = false,
        isTenantScoped: Bool = false,
        estimatedRowCount: Int = 10_000,
        position: SchemaEntityCanvasPosition = SchemaEntityCanvasPosition(x: 48, y: 48),
        attributes: [SchemaAttribute] = [],
        indexes: [SchemaIndex] = [],
        constraints: [SchemaConstraint] = []
    ) {
        self.id = id
        self.name = name
        self.tableName = tableName ?? SchemaNamingHelpers.pluralSnakeCase(name)
        self.summary = summary
        self.domainGroup = domainGroup
        self.accentHex = accentHex
        self.isAuditedWithTimestamps = isAuditedWithTimestamps
        self.isSoftDeletable = isSoftDeletable
        self.isTenantScoped = isTenantScoped
        self.estimatedRowCount = max(1, estimatedRowCount)
        self.position = position
        self.attributes = attributes
        self.indexes = indexes
        self.constraints = constraints
    }

    public var primaryKeys: [SchemaAttribute] {
        attributes.filter(\.isPrimaryKey)
    }

    public var primaryKeyAttribute: SchemaAttribute? {
        attributes.first(where: \.isPrimaryKey)
    }

    public var estimatedRowStrideBytes: Int {
        let baseAttrs = attributes.reduce(0) { $0 + $1.fieldType.estimatedAverageBytes }
        let auditBytes = (isAuditedWithTimestamps ? 16 : 0) + (isSoftDeletable ? 8 : 0) + (isTenantScoped ? 16 : 0)
        return max(16, baseAttrs + auditBytes)
    }
}

// MARK: - Diagnostics, 3NF Normalization & Index Advisor Models

public enum SchemaDiagnosticSeverity: String, CaseIterable, Codable, Hashable, Sendable {
    case error
    case warning
    case advisory
    case info
}

public enum SchemaNormalizationViolationKind: String, CaseIterable, Codable, Hashable, Sendable {
    case missingPrimaryKey
    case firstNFRepeatingGroup
    case secondNFPartialDependency
    case thirdNFTransitiveDependency
    case mutableNaturalPrimaryKey
    case unboundedStringKey
    case denormalizedDerivedAggregate
}

public struct SchemaNormalizationFinding: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var entityName: String
    public var attributeNames: [String]
    public var kind: SchemaNormalizationViolationKind
    public var severity: SchemaDiagnosticSeverity
    public var explanation: String
    public var remediation: String

    public init(
        id: String,
        entityName: String,
        attributeNames: [String],
        kind: SchemaNormalizationViolationKind,
        severity: SchemaDiagnosticSeverity,
        explanation: String,
        remediation: String
    ) {
        self.id = id
        self.entityName = entityName
        self.attributeNames = attributeNames
        self.kind = kind
        self.severity = severity
        self.explanation = explanation
        self.remediation = remediation
    }
}

public enum SchemaForeignKeyGraphAnomalyKind: String, CaseIterable, Codable, Hashable, Sendable {
    case orphanSourceEntity
    case orphanTargetEntity
    case cascadeDeleteCycle
    case mandatoryCircularDependency
    case missingInverseName
    case manyToManyMissingJoinTable
    case nullifyOnMandatoryForeignKey
}

public struct SchemaGraphAnomaly: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var relationshipName: String
    public var involvedEntities: [String]
    public var kind: SchemaForeignKeyGraphAnomalyKind
    public var severity: SchemaDiagnosticSeverity
    public var message: String

    public init(
        id: String,
        relationshipName: String,
        involvedEntities: [String],
        kind: SchemaForeignKeyGraphAnomalyKind,
        severity: SchemaDiagnosticSeverity,
        message: String
    ) {
        self.id = id
        self.relationshipName = relationshipName
        self.involvedEntities = involvedEntities
        self.kind = kind
        self.severity = severity
        self.message = message
    }
}

public struct SchemaIndexRecommendation: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(entityName).\(suggestedIndex.name)" }
    public var entityName: String
    public var suggestedIndex: SchemaIndex
    public var estimatedSpeedupFactor: Double
    public var reason: String

    public init(
        entityName: String,
        suggestedIndex: SchemaIndex,
        estimatedSpeedupFactor: Double,
        reason: String
    ) {
        self.entityName = entityName
        self.suggestedIndex = suggestedIndex
        self.estimatedSpeedupFactor = estimatedSpeedupFactor
        self.reason = reason
    }
}

public struct SchemaAnalysisReport: Codable, Hashable, Sendable {
    public var normalFormScore: Int
    public var achievedNormalForm: String
    public var normalizationFindings: [SchemaNormalizationFinding]
    public var graphAnomalies: [SchemaGraphAnomaly]
    public var indexRecommendations: [SchemaIndexRecommendation]
    public var estimatedTotalStorageMB: Double
    public var piiAttributeCount: Int
    public var cyclicEntityNames: [String]

    public init(
        normalFormScore: Int,
        achievedNormalForm: String,
        normalizationFindings: [SchemaNormalizationFinding],
        graphAnomalies: [SchemaGraphAnomaly],
        indexRecommendations: [SchemaIndexRecommendation],
        estimatedTotalStorageMB: Double,
        piiAttributeCount: Int,
        cyclicEntityNames: [String]
    ) {
        self.normalFormScore = normalFormScore
        self.achievedNormalForm = achievedNormalForm
        self.normalizationFindings = normalizationFindings
        self.graphAnomalies = graphAnomalies
        self.indexRecommendations = indexRecommendations
        self.estimatedTotalStorageMB = estimatedTotalStorageMB
        self.piiAttributeCount = piiAttributeCount
        self.cyclicEntityNames = cyclicEntityNames
    }
}

// MARK: - Preset Catalog

public enum SchemaPresetKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case saasMultiTenant
    case fintechDoubleEntry
    case aiRAGKnowledgeBase
    case ecommerceInventory
    case healthBiometricsVault
    case socialCreatorFeed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .saasMultiTenant: "B2B SaaS Multi-Tenant Control Plane"
        case .fintechDoubleEntry: "Fintech Double-Entry Ledger & Treasury"
        case .aiRAGKnowledgeBase: "On-Device AI RAG & Vector Knowledge Vault"
        case .ecommerceInventory: "Omnichannel Commerce & SKU Inventory"
        case .healthBiometricsVault: "HealthKit Biometrics & Clinical Consent Vault"
        case .socialCreatorFeed: "Creator Subscription & Real-Time Media Feed"
        }
    }

    public var subtitle: String {
        switch self {
        case .saasMultiTenant:
            "Organizations, RBAC members, scoped workspaces, subscriptions, and immutable audit logs."
        case .fintechDoubleEntry:
            "Strict balanced journal postings, multi-currency accounts, counterparties, and daily snapshots."
        case .aiRAGKnowledgeBase:
            "Corpora, chunked documents with 768-d embeddings, hybrid FTS5 search, and citation spans."
        case .ecommerceInventory:
            "Catalog products, SKU variants, warehouse stock lots, orders, and line-item fulfillment."
        case .healthBiometricsVault:
            "Encrypted patient profiles, high-frequency biometric samples, workouts, and HIPAA consent."
        case .socialCreatorFeed:
            "Creator handles, media posts, threaded comments, memberships, and engagement reactions."
        }
    }
}

// MARK: - DataSchemaWorkspace & Analyzers

public struct DataSchemaWorkspace: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var schemaVersion: Int
    public var namespacePrefix: String
    public var entities: [SchemaEntity]
    public var relationships: [SchemaRelationship]
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        schemaVersion: Int = 1,
        namespacePrefix: String = "CK",
        entities: [SchemaEntity] = [],
        relationships: [SchemaRelationship] = [],
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.schemaVersion = max(1, schemaVersion)
        self.namespacePrefix = namespacePrefix
        self.entities = entities
        self.relationships = relationships
        self.notes = notes
    }

    public func entity(named entityName: String) -> SchemaEntity? {
        entities.first { $0.name == entityName }
    }

    public func outgoingRelationships(from entityName: String) -> [SchemaRelationship] {
        relationships.filter { $0.sourceEntityName == entityName }
    }

    public func incomingRelationships(to entityName: String) -> [SchemaRelationship] {
        relationships.filter { $0.targetEntityName == entityName }
    }

    public mutating func upsertEntity(_ entity: SchemaEntity) {
        if let idx = entities.firstIndex(where: { $0.id == entity.id || $0.name == entity.name }) {
            entities[idx] = entity
        } else {
            entities.append(entity)
        }
    }

    public mutating func removeEntity(named entityName: String) {
        entities.removeAll { $0.name == entityName }
        relationships.removeAll {
            $0.sourceEntityName == entityName || $0.targetEntityName == entityName
        }
    }

    public mutating func applyRecommendedIndexes(_ recommendations: [SchemaIndexRecommendation]) {
        for rec in recommendations {
            guard let idx = entities.firstIndex(where: { $0.name == rec.entityName }) else { continue }
            let alreadyExists = entities[idx].indexes.contains {
                $0.columns == rec.suggestedIndex.columns && $0.kind == rec.suggestedIndex.kind
            }
            if !alreadyExists {
                entities[idx].indexes.append(rec.suggestedIndex)
            }
        }
    }

    /// Computes topological DDL creation order (parents before children) using Kahn's algorithm.
    public func topologicalSortEntities() -> (sorted: [SchemaEntity], cyclicEntityNames: [String]) {
        let entityByName = Dictionary(uniqueKeysWithValues: entities.map { ($0.name, $0) })
        var indegree: [String: Int] = Dictionary(uniqueKeysWithValues: entities.map { ($0.name, 0) })
        var adjacency: [String: Set<String>] = Dictionary(uniqueKeysWithValues: entities.map { ($0.name, []) })

        for rel in relationships where rel.kind != .manyToMany {
            guard entityByName[rel.sourceEntityName] != nil,
                  entityByName[rel.targetEntityName] != nil,
                  rel.sourceEntityName != rel.targetEntityName else { continue }
            if adjacency[rel.sourceEntityName, default: []].insert(rel.targetEntityName).inserted {
                indegree[rel.targetEntityName, default: 0] += 1
            }
        }

        var queue: [String] = entities
            .map(\.name)
            .filter { indegree[$0, default: 0] == 0 }
            .sorted()
        var orderedNames: [String] = []

        while !queue.isEmpty {
            let current = queue.removeFirst()
            orderedNames.append(current)
            for neighbor in adjacency[current, default: []].sorted() {
                indegree[neighbor, default: 0] -= 1
                if indegree[neighbor] == 0 {
                    queue.append(neighbor)
                    queue.sort()
                }
            }
        }

        let orderedSet = Set(orderedNames)
        let cyclic = entities.map(\.name).filter { !orderedSet.contains($0) }
        let sortedEntities = (orderedNames + cyclic).compactMap { entityByName[$0] }
        return (sortedEntities, cyclic)
    }

    // MARK: - 3NF Normalization, Orphan/Cycle Detector & Index Coverage Advisor

    public func analyzeNormalizationAndIntegrity() -> SchemaAnalysisReport {
        var normFindings: [SchemaNormalizationFinding] = []
        var graphAnomalies: [SchemaGraphAnomaly] = []
        var indexRecs: [SchemaIndexRecommendation] = []

        let entityNames = Set(entities.map(\.name))

        for entity in entities {
            let pks = entity.primaryKeys
            if pks.isEmpty {
                normFindings.append(
                    SchemaNormalizationFinding(
                        id: "norm-missing-pk-\(entity.name)",
                        entityName: entity.name,
                        attributeNames: [],
                        kind: .missingPrimaryKey,
                        severity: .error,
                        explanation: "Entity '\(entity.name)' has no primary key attribute, violating 1NF tuple uniqueness.",
                        remediation: "Add an immutable surrogate primary key `id: .uuid` with `isPrimaryKey: true`."
                    )
                )
            }

            for pk in pks {
                if case .string(let maxLen) = pk.fieldType, maxLen == nil {
                    normFindings.append(
                        SchemaNormalizationFinding(
                            id: "norm-unbounded-pk-\(entity.name)-\(pk.name)",
                            entityName: entity.name,
                            attributeNames: [pk.name],
                            kind: .unboundedStringKey,
                            severity: .warning,
                            explanation: "Primary key '\(pk.name)' is an unbounded string, bloating secondary B-Tree indexes.",
                            remediation: "Use `.uuid` or bound the key length (e.g. `.string(maxLength: 64)`)."
                        )
                    )
                }
                let lowerPK = pk.name.lowercased()
                if lowerPK.contains("email") || lowerPK.contains("phone") || lowerPK.contains("username") {
                    normFindings.append(
                        SchemaNormalizationFinding(
                            id: "norm-mutable-pk-\(entity.name)-\(pk.name)",
                            entityName: entity.name,
                            attributeNames: [pk.name],
                            kind: .mutableNaturalPrimaryKey,
                            severity: .warning,
                            explanation: "Natural key '\(pk.name)' can change over user lifecycle, triggering expensive cascading FK updates.",
                            remediation: "Promote a surrogate `.uuid` primary key and mark '\(pk.name)' as `isUnique: true`."
                        )
                    )
                }
            }

            // 1NF check: numbered repeating groups (e.g., tag1, tag2 / phone_1, phone_2) or CSV list attributes
            var numberedStems: [String: [String]] = [:]
            for attr in entity.attributes {
                let trimmedDigits = attr.name.replacingOccurrences(
                    of: #"_?\d+$"#,
                    with: "",
                    options: .regularExpression
                )
                if trimmedDigits != attr.name && !trimmedDigits.isEmpty {
                    numberedStems[trimmedDigits, default: []].append(attr.name)
                }
                let lower = attr.name.lowercased()
                if (lower.hasSuffix("_csv") || lower.hasSuffix("_list")) && (attr.fieldType.kind == .string || attr.fieldType.kind == .text) {
                    normFindings.append(
                        SchemaNormalizationFinding(
                            id: "norm-1nf-csv-\(entity.name)-\(attr.name)",
                            entityName: entity.name,
                            attributeNames: [attr.name],
                            kind: .firstNFRepeatingGroup,
                            severity: .warning,
                            explanation: "Attribute '\(attr.name)' encodes multi-valued text inside a scalar column (1NF violation).",
                            remediation: "Extract '\(attr.name)' into a child 1:N entity or typed JSON collection."
                        )
                    )
                }
            }
            for (stem, groupedCols) in numberedStems where groupedCols.count >= 2 {
                normFindings.append(
                    SchemaNormalizationFinding(
                        id: "norm-1nf-repeat-\(entity.name)-\(stem)",
                        entityName: entity.name,
                        attributeNames: groupedCols.sorted(),
                        kind: .firstNFRepeatingGroup,
                        severity: .error,
                        explanation: "Repeating numbered attributes (\(groupedCols.sorted().joined(separator: ", "))) violate First Normal Form (1NF).",
                        remediation: "Normalize '\(stem)' into a dedicated child table linked via `\(SchemaNamingHelpers.snakeCase(entity.name))_id`."
                    )
                )
            }

            // 2NF check: composite primary key with non-key attributes that appear scoped to one half of the key
            if pks.count >= 2 {
                let pkPrefixes = pks.map { $0.name.replacingOccurrences(of: "_id", with: "").lowercased() }
                for attr in entity.attributes where !attr.isPrimaryKey {
                    let lowerAttr = attr.name.lowercased()
                    for prefix in pkPrefixes where !prefix.isEmpty && lowerAttr.hasPrefix(prefix + "_") {
                        normFindings.append(
                            SchemaNormalizationFinding(
                                id: "norm-2nf-\(entity.name)-\(attr.name)",
                                entityName: entity.name,
                                attributeNames: [attr.name],
                                kind: .secondNFPartialDependency,
                                severity: .warning,
                                explanation: "In composite-key entity '\(entity.name)', '\(attr.name)' depends partially on '\(prefix)_id' (2NF violation).",
                                remediation: "Move '\(attr.name)' onto the referenced '\(SchemaNamingHelpers.pascalCase(prefix))' entity."
                            )
                        )
                    }
                }
            }

            // 3NF check: transitive functional dependencies (e.g., zip_code + city_name, or foreign prefix copy like customer_email on Order)
            let attrNamesLower = Set(entity.attributes.map { $0.name.lowercased() })
            if attrNamesLower.contains("postal_code") || attrNamesLower.contains("zip_code") {
                let transitiveLoc = entity.attributes.map(\.name).filter {
                    let l = $0.lowercased()
                    return l == "city_name" || l == "state_name"
                }
                if !transitiveLoc.isEmpty {
                    normFindings.append(
                        SchemaNormalizationFinding(
                            id: "norm-3nf-geo-\(entity.name)",
                            entityName: entity.name,
                            attributeNames: transitiveLoc,
                            kind: .thirdNFTransitiveDependency,
                            severity: .advisory,
                            explanation: "Geographic labels (\(transitiveLoc.joined(separator: ", "))) transitively depend on postal/zip code (3NF advisory).",
                            remediation: "Reference a normalized PostalDirectory lookup or explicitly document snapshot semantics."
                        )
                    )
                }
            }

            let incomingRels = incomingRelationships(to: entity.name)
            for rel in incomingRels where rel.kind != .manyToMany {
                let ownerPrefix = SchemaNamingHelpers.snakeCase(rel.sourceEntityName) + "_"
                for attr in entity.attributes where !attr.isPrimaryKey && attr.name != rel.foreignKeyColumn {
                    let lower = attr.name.lowercased()
                    if lower.hasPrefix(ownerPrefix) && (lower.hasSuffix("_email") || lower.hasSuffix("_name") || lower.hasSuffix("_avatar")) {
                        normFindings.append(
                            SchemaNormalizationFinding(
                                id: "norm-3nf-fkcopy-\(entity.name)-\(attr.name)",
                                entityName: entity.name,
                                attributeNames: [rel.foreignKeyColumn, attr.name],
                                kind: .thirdNFTransitiveDependency,
                                severity: .warning,
                                explanation: "'\(attr.name)' duplicates data owned by '\(rel.sourceEntityName)' via '\(rel.foreignKeyColumn)' (3NF violation).",
                                remediation: "Join against '\(rel.sourceEntityName)' at query time instead of duplicating '\(attr.name)'."
                            )
                        )
                    }
                }
            }

            // Index coverage advisor per entity
            let coveredSingleColumns = Set(
                entity.indexes.compactMap { $0.columns.first }
                    + entity.attributes.filter { $0.isPrimaryKey || $0.isIndexed || $0.isUnique }.map(\.name)
            )

            // 1) Foreign key index coverage
            for rel in incomingRels where rel.kind != .manyToMany {
                if !coveredSingleColumns.contains(rel.foreignKeyColumn) {
                    let cols = entity.isTenantScoped
                        ? ["tenant_id", rel.foreignKeyColumn]
                        : [rel.foreignKeyColumn]
                    indexRecs.append(
                        SchemaIndexRecommendation(
                            entityName: entity.name,
                            suggestedIndex: SchemaIndex(
                                name: "idx_\(entity.tableName)_\(cols.joined(separator: "_"))",
                                columns: cols,
                                kind: .btree,
                                rationale: "Accelerates JOINs and parent `\(rel.deleteRule.rawValue)` checks from `\(rel.sourceEntityName)`."
                            ),
                            estimatedSpeedupFactor: max(2.4, log10(Double(max(100, entity.estimatedRowCount))) * 3.1),
                            reason: "Foreign key '\(rel.foreignKeyColumn)' lacks a leading B-Tree index across ~\(entity.estimatedRowCount) rows."
                        )
                    )
                }
            }

            // 2) Full-Text Search (FTS5) coverage
            let ftsCols = entity.attributes.filter(\.isFullTextSearchable).map(\.name)
            let hasFTSIndex = entity.indexes.contains { $0.kind == .fts5FullText }
            if !ftsCols.isEmpty && !hasFTSIndex {
                indexRecs.append(
                    SchemaIndexRecommendation(
                        entityName: entity.name,
                        suggestedIndex: SchemaIndex(
                            name: "fts_\(entity.tableName)_search",
                            columns: ftsCols,
                            kind: .fts5FullText,
                            rationale: "Replaces O(N) `LIKE '%term%'` table scans with tokenized BM25 SQLite FTS5 inverted index."
                        ),
                        estimatedSpeedupFactor: 18.5,
                        reason: "Searchable text columns (\(ftsCols.joined(separator: ", "))) have no FTS5 virtual index."
                    )
                )
            }

            // 3) Vector HNSW index coverage
            for attr in entity.attributes {
                if case .vectorEmbedding(let dims) = attr.fieldType {
                    let hasVecIndex = entity.indexes.contains { $0.kind == .vectorHNSW && $0.columns.contains(attr.name) }
                    if !hasVecIndex && entity.estimatedRowCount >= 1_000 {
                        indexRecs.append(
                            SchemaIndexRecommendation(
                                entityName: entity.name,
                                suggestedIndex: SchemaIndex(
                                    name: "hnsw_\(entity.tableName)_\(attr.name)",
                                    columns: [attr.name],
                                    kind: .vectorHNSW,
                                    rationale: "Approximate nearest-neighbor HNSW index for \(dims)-d cosine similarity retrieval."
                                ),
                                estimatedSpeedupFactor: 24.0,
                                reason: "\(dims)-d embedding '\(attr.name)' on \(entity.estimatedRowCount) rows needs an ANN HNSW index."
                            )
                        )
                    }
                }
            }

            // 4) Tenant + timestamp feed composite index
            if entity.isTenantScoped && entity.isAuditedWithTimestamps {
                let hasTenantTimeline = entity.indexes.contains {
                    $0.columns.count >= 2 && $0.columns[0] == "tenant_id" && $0.columns[1] == "created_at"
                }
                if !hasTenantTimeline && entity.estimatedRowCount >= 5_000 {
                    indexRecs.append(
                        SchemaIndexRecommendation(
                            entityName: entity.name,
                            suggestedIndex: SchemaIndex(
                                name: "idx_\(entity.tableName)_tenant_created_at",
                                columns: ["tenant_id", "created_at"],
                                kind: .btree,
                                rationale: "Covers paginated tenant timeline queries without temp B-Tree sort."
                            ),
                            estimatedSpeedupFactor: 6.2,
                            reason: "Tenant-scoped audited table benefits from composite `(tenant_id, created_at)` index."
                        )
                    )
                }
            }
        }

        // Foreign-key orphan & relationship integrity checks
        for rel in relationships {
            if !entityNames.contains(rel.sourceEntityName) {
                graphAnomalies.append(
                    SchemaGraphAnomaly(
                        id: "fk-orphan-source-\(rel.name)",
                        relationshipName: rel.name,
                        involvedEntities: [rel.sourceEntityName, rel.targetEntityName],
                        kind: .orphanSourceEntity,
                        severity: .error,
                        message: "Relationship '\(rel.name)' references missing source entity '\(rel.sourceEntityName)'."
                    )
                )
            }
            if !entityNames.contains(rel.targetEntityName) {
                graphAnomalies.append(
                    SchemaGraphAnomaly(
                        id: "fk-orphan-target-\(rel.name)",
                        relationshipName: rel.name,
                        involvedEntities: [rel.sourceEntityName, rel.targetEntityName],
                        kind: .orphanTargetEntity,
                        severity: .error,
                        message: "Relationship '\(rel.name)' references missing target entity '\(rel.targetEntityName)'."
                    )
                )
            }
            if (rel.inverseName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                graphAnomalies.append(
                    SchemaGraphAnomaly(
                        id: "fk-missing-inverse-\(rel.name)",
                        relationshipName: rel.name,
                        involvedEntities: [rel.sourceEntityName, rel.targetEntityName],
                        kind: .missingInverseName,
                        severity: .advisory,
                        message: "Relationship '\(rel.name)' omits `inverseName`, preventing SwiftData bidirectional graph sync."
                    )
                )
            }
            if rel.kind == .manyToMany && (rel.joinTableName ?? "").isEmpty {
                graphAnomalies.append(
                    SchemaGraphAnomaly(
                        id: "fk-missing-join-\(rel.name)",
                        relationshipName: rel.name,
                        involvedEntities: [rel.sourceEntityName, rel.targetEntityName],
                        kind: .manyToManyMissingJoinTable,
                        severity: .error,
                        message: "Many-to-many relationship '\(rel.name)' must define an associative join table."
                    )
                )
            }
            if rel.deleteRule == .nullify && !rel.isOptional && rel.kind != .manyToMany {
                graphAnomalies.append(
                    SchemaGraphAnomaly(
                        id: "fk-nullify-mandatory-\(rel.name)",
                        relationshipName: rel.name,
                        involvedEntities: [rel.sourceEntityName, rel.targetEntityName],
                        kind: .nullifyOnMandatoryForeignKey,
                        severity: .error,
                        message: "Relationship '\(rel.name)' uses `.nullify` delete rule on a non-optional foreign key."
                    )
                )
            }
        }

        // Cycle detectors: (a) Cascade delete cycles, (b) Mandatory FK cycles
        let cascadeCycles = detectDirectedCycles { rel in
            rel.deleteRule == .cascade && rel.kind != .manyToMany
        }
        for cycle in cascadeCycles {
            let key = cycle.joined(separator: " -> ")
            graphAnomalies.append(
                SchemaGraphAnomaly(
                    id: "cycle-cascade-\(cycle.sorted().joined(separator: "-"))",
                    relationshipName: "cascadeCycle",
                    involvedEntities: cycle,
                    kind: .cascadeDeleteCycle,
                    severity: .error,
                    message: "Cascade delete cycle detected (\(key)), risking recursive deletion loops."
                )
            )
        }

        let mandatoryCycles = detectDirectedCycles { rel in
            !rel.isOptional && rel.kind != .manyToMany
        }
        for cycle in mandatoryCycles {
            let key = cycle.joined(separator: " -> ")
            graphAnomalies.append(
                SchemaGraphAnomaly(
                    id: "cycle-mandatory-\(cycle.sorted().joined(separator: "-"))",
                    relationshipName: "mandatoryCycle",
                    involvedEntities: cycle,
                    kind: .mandatoryCircularDependency,
                    severity: .error,
                    message: "Non-nullable foreign key cycle (\(key)) prevents inserting initial rows without deferred constraints."
                )
            )
        }

        let (_, cyclicNames) = topologicalSortEntities()
        let totalBytes = entities.reduce(0.0) { acc, ent in
            acc + Double(ent.estimatedRowStrideBytes) * Double(ent.estimatedRowCount) * 1.28
        }
        let storageMB = (totalBytes / (1024.0 * 1024.0) * 100.0).rounded() / 100.0
        let piiCount = entities.reduce(0) { acc, ent in
            acc + ent.attributes.filter(\.isSensitivePII).count
        }

        let has1NFError = normFindings.contains { $0.kind == .missingPrimaryKey || $0.kind == .firstNFRepeatingGroup }
        let has2NFError = normFindings.contains { $0.kind == .secondNFPartialDependency }
        let has3NFWarning = normFindings.contains { $0.kind == .thirdNFTransitiveDependency }

        let achievedForm: String
        if has1NFError {
            achievedForm = "Unnormalized (0NF)"
        } else if has2NFError {
            achievedForm = "First Normal Form (1NF)"
        } else if has3NFWarning {
            achievedForm = "Second Normal Form (2NF)"
        } else {
            achievedForm = "Third Normal Form (3NF)"
        }

        let penalty = normFindings.reduce(0) { acc, item in
            switch item.severity {
            case .error: return acc + 20
            case .warning: return acc + 10
            case .advisory: return acc + 4
            case .info: return acc
            }
        } + graphAnomalies.reduce(0) { acc, item in
            switch item.severity {
            case .error: return acc + 18
            case .warning: return acc + 9
            case .advisory: return acc + 3
            case .info: return acc
            }
        }

        return SchemaAnalysisReport(
            normalFormScore: max(0, min(100, 100 - penalty)),
            achievedNormalForm: achievedForm,
            normalizationFindings: normFindings,
            graphAnomalies: graphAnomalies,
            indexRecommendations: indexRecs,
            estimatedTotalStorageMB: storageMB,
            piiAttributeCount: piiCount,
            cyclicEntityNames: cyclicNames
        )
    }

    private func detectDirectedCycles(matching predicate: (SchemaRelationship) -> Bool) -> [[String]] {
        var adj: [String: [String]] = [:]
        for rel in relationships where predicate(rel) {
            adj[rel.sourceEntityName, default: []].append(rel.targetEntityName)
        }

        var visited = Set<String>()
        var activeStack: [String] = []
        var activeSet = Set<String>()
        var seenCanonicalCycles = Set<String>()
        var cycles: [[String]] = []

        func dfs(_ node: String) {
            visited.insert(node)
            activeStack.append(node)
            activeSet.insert(node)

            for next in adj[node, default: []] {
                if !visited.contains(next) {
                    dfs(next)
                } else if activeSet.contains(next), let idx = activeStack.firstIndex(of: next) {
                    let cycleSlice = Array(activeStack[idx...]) + [next]
                    let canonical = Array(activeStack[idx...]).sorted().joined(separator: "|")
                    if seenCanonicalCycles.insert(canonical).inserted {
                        cycles.append(cycleSlice)
                    }
                }
            }

            activeStack.removeLast()
            activeSet.remove(node)
        }

        for entity in entities.map(\.name).sorted() where !visited.contains(entity) {
            dfs(entity)
        }
        return cycles
    }

    // MARK: - Mermaid ER Diagram Generator

    public func generateMermaidERDiagram(includeDocumentation: Bool = false) -> String {
        var lines: [String] = ["erDiagram"]

        for rel in relationships {
            let connector = rel.kind.mermaidConnector(isOptional: rel.isOptional)
            let label = "\(rel.name) (\(rel.deleteRule.rawValue))"
            lines.append("    \(rel.sourceEntityName) \(connector) \(rel.targetEntityName) : \"\(label)\"")
        }

        if !relationships.isEmpty {
            lines.append("")
        }

        for entity in entities {
            lines.append("    \(entity.name) {")
            let incomingFKs = incomingRelationships(to: entity.name).filter { $0.kind != .manyToMany }
            let fkColumns = Set(incomingFKs.map(\.foreignKeyColumn))

            for attr in entity.attributes {
                var badges: [String] = []
                if attr.isPrimaryKey { badges.append("PK") }
                if fkColumns.contains(attr.name) { badges.append("FK") }
                if attr.isUnique && !attr.isPrimaryKey { badges.append("UK") }
                let badgeStr = badges.isEmpty ? "" : " \(badges.joined(separator: ","))"
                let docComment: String
                if includeDocumentation && !attr.documentation.isEmpty {
                    let sanitized = attr.documentation.replacingOccurrences(of: "\"", with: "'")
                    docComment = " \"\(sanitized)\""
                } else if attr.isSensitivePII {
                    docComment = " \"PII\""
                } else {
                    docComment = ""
                }
                lines.append("        \(attr.fieldType.mermaidTypeToken) \(attr.name)\(badgeStr)\(docComment)")
            }

            // Render synthesized foreign keys not explicitly listed in entity.attributes
            let existingAttrNames = Set(entity.attributes.map(\.name))
            for fkRel in incomingFKs where !existingAttrNames.contains(fkRel.foreignKeyColumn) {
                lines.append("        UUID \(fkRel.foreignKeyColumn) FK \"ref \(fkRel.sourceEntityName)\"")
            }

            if entity.isTenantScoped && !existingAttrNames.contains("tenant_id") {
                lines.append("        UUID tenant_id FK \"Tenant isolation\"")
            }
            if entity.isAuditedWithTimestamps {
                if !existingAttrNames.contains("created_at") {
                    lines.append("        TIMESTAMPTZ created_at")
                }
                if !existingAttrNames.contains("updated_at") {
                    lines.append("        TIMESTAMPTZ updated_at")
                }
            }
            lines.append("    }")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 6 Built-In Rich Domain Presets

    public static func preset(_ kind: SchemaPresetKind) -> DataSchemaWorkspace {
        switch kind {
        case .saasMultiTenant:
            return buildSaaSMultiTenantPreset()
        case .fintechDoubleEntry:
            return buildFintechDoubleEntryPreset()
        case .aiRAGKnowledgeBase:
            return buildAIRAGKnowledgeBasePreset()
        case .ecommerceInventory:
            return buildEcommerceInventoryPreset()
        case .healthBiometricsVault:
            return buildHealthBiometricsVaultPreset()
        case .socialCreatorFeed:
            return buildSocialCreatorFeedPreset()
        }
    }

    private static func buildSaaSMultiTenantPreset() -> DataSchemaWorkspace {
        let org = SchemaEntity(
            name: "Organization",
            summary: "Root B2B tenant account with billing slug and SSO policy.",
            domainGroup: "Tenancy",
            accentHex: "#0D5CF0",
            estimatedRowCount: 8_500,
            position: SchemaEntityCanvasPosition(x: 40, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "slug", fieldType: .string(maxLength: 64), isUnique: true, documentation: "URL-safe workspace handle"),
                SchemaAttribute(name: "display_name", fieldType: .string(maxLength: 120), isFullTextSearchable: true),
                SchemaAttribute(name: "plan_tier", fieldType: .enumCases(["starter", "growth", "enterprise"]), defaultValue: .literalString("starter")),
                SchemaAttribute(name: "sso_enforced", fieldType: .bool, defaultValue: .literalBool(false)),
                SchemaAttribute(name: "seat_quota", fieldType: .int64, defaultValue: .literalInt(25))
            ],
            constraints: [
                SchemaConstraint(name: "chk_org_seat_quota", kind: .numericBounds, columns: ["seat_quota"], expression: "seat_quota >= 1", errorMessage: "Seat quota must be at least 1.")
            ]
        )

        let member = SchemaEntity(
            name: "WorkspaceMember",
            summary: "Authenticated user membership with role-based permissions.",
            domainGroup: "Identity",
            accentHex: "#6B3DE8",
            isTenantScoped: true,
            estimatedRowCount: 95_000,
            position: SchemaEntityCanvasPosition(x: 340, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "organization_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "email", fieldType: .string(maxLength: 254), isUnique: true, isSensitivePII: true),
                SchemaAttribute(name: "full_name", fieldType: .string(maxLength: 140), isSensitivePII: true, isFullTextSearchable: true),
                SchemaAttribute(name: "role", fieldType: .enumCases(["owner", "admin", "builder", "viewer"]), defaultValue: .literalString("builder")),
                SchemaAttribute(name: "last_active_at", fieldType: .timestamp, isNullable: true)
            ],
            indexes: [
                SchemaIndex(name: "idx_workspace_members_org_role", columns: ["organization_id", "role"], kind: .btree, rationale: "Fast RBAC roster lookup")
            ]
        )

        let project = SchemaEntity(
            name: "ProjectSpace",
            summary: "Isolated design & deployment workspace within an organization.",
            domainGroup: "Product",
            accentHex: "#149E63",
            isSoftDeletable: true,
            isTenantScoped: true,
            estimatedRowCount: 42_000,
            position: SchemaEntityCanvasPosition(x: 40, y: 260),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "organization_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "key_code", fieldType: .string(maxLength: 16), isIndexed: true),
                SchemaAttribute(name: "title", fieldType: .string(maxLength: 160), isFullTextSearchable: true),
                SchemaAttribute(name: "settings_json", fieldType: .jsonBlob(schemaHint: "ProjectSettings"), defaultValue: .emptyJSONObject)
            ]
        )

        let audit = SchemaEntity(
            name: "AuditTrailEntry",
            summary: "Append-only security event log for SOC2 compliance.",
            domainGroup: "Security",
            accentHex: "#D97706",
            isTenantScoped: true,
            estimatedRowCount: 1_200_000,
            position: SchemaEntityCanvasPosition(x: 340, y: 260),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "organization_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "actor_member_id", fieldType: .uuid, isNullable: true, isIndexed: true),
                SchemaAttribute(name: "action_verb", fieldType: .string(maxLength: 80), isIndexed: true),
                SchemaAttribute(name: "ip_address", fieldType: .string(maxLength: 45), isNullable: true, isSensitivePII: true),
                SchemaAttribute(name: "metadata_json", fieldType: .jsonBlob(schemaHint: "AuditDiff"), defaultValue: .emptyJSONObject)
            ]
        )

        return DataSchemaWorkspace(
            name: "SaaS Multi-Tenant Control Plane",
            namespacePrefix: "SaaS",
            entities: [org, member, project, audit],
            relationships: [
                SchemaRelationship(name: "members", sourceEntityName: "Organization", targetEntityName: "WorkspaceMember", inverseName: "organization", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "organization_id"),
                SchemaRelationship(name: "projects", sourceEntityName: "Organization", targetEntityName: "ProjectSpace", inverseName: "organization", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "organization_id"),
                SchemaRelationship(name: "auditEntries", sourceEntityName: "Organization", targetEntityName: "AuditTrailEntry", inverseName: "organization", kind: .oneToMany, deleteRule: .deny, foreignKeyColumn: "organization_id"),
                SchemaRelationship(name: "authoredAudits", sourceEntityName: "WorkspaceMember", targetEntityName: "AuditTrailEntry", inverseName: "actorMember", kind: .oneToMany, deleteRule: .nullify, isOptional: true, foreignKeyColumn: "actor_member_id")
            ]
        )
    }

    private static func buildFintechDoubleEntryPreset() -> DataSchemaWorkspace {
        let account = SchemaEntity(
            name: "LedgerAccount",
            summary: "Chart-of-accounts bucket with currency and normal balance side.",
            domainGroup: "Treasury",
            accentHex: "#0A8754",
            estimatedRowCount: 25_000,
            position: SchemaEntityCanvasPosition(x: 40, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "code", fieldType: .string(maxLength: 32), isUnique: true),
                SchemaAttribute(name: "name", fieldType: .string(maxLength: 120), isFullTextSearchable: true),
                SchemaAttribute(name: "currency_iso", fieldType: .string(maxLength: 3), defaultValue: .literalString("USD")),
                SchemaAttribute(name: "category", fieldType: .enumCases(["asset", "liability", "equity", "revenue", "expense"])),
                SchemaAttribute(name: "cached_balance", fieldType: .decimal(precision: 19, scale: 4), defaultValue: .literalDouble(0))
            ]
        )

        let journal = SchemaEntity(
            name: "JournalTransaction",
            summary: "Atomic balanced financial event with idempotency key.",
            domainGroup: "Ledger",
            accentHex: "#1D4ED8",
            estimatedRowCount: 650_000,
            position: SchemaEntityCanvasPosition(x: 340, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "idempotency_key", fieldType: .string(maxLength: 96), isUnique: true),
                SchemaAttribute(name: "status", fieldType: .enumCases(["pending", "posted", "reversed"]), defaultValue: .literalString("posted")),
                SchemaAttribute(name: "memo", fieldType: .string(maxLength: 280), isFullTextSearchable: true),
                SchemaAttribute(name: "posted_at", fieldType: .timestamp, defaultValue: .nowTimestamp)
            ]
        )

        let posting = SchemaEntity(
            name: "LedgerPostingLine",
            summary: "Immutable debit or credit leg belonging to a journal transaction.",
            domainGroup: "Ledger",
            accentHex: "#7C3AED",
            estimatedRowCount: 1_450_000,
            position: SchemaEntityCanvasPosition(x: 190, y: 250),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "journal_transaction_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "ledger_account_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "direction", fieldType: .enumCases(["debit", "credit"])),
                SchemaAttribute(name: "amount_minor_units", fieldType: .int64),
                SchemaAttribute(name: "amount_decimal", fieldType: .decimal(precision: 19, scale: 4))
            ],
            constraints: [
                SchemaConstraint(name: "chk_positive_posting", kind: .numericBounds, columns: ["amount_minor_units"], expression: "amount_minor_units > 0", errorMessage: "Posting amount must be strictly positive.")
            ]
        )

        return DataSchemaWorkspace(
            name: "Fintech Double-Entry Ledger",
            namespacePrefix: "Fin",
            entities: [account, journal, posting],
            relationships: [
                SchemaRelationship(name: "postings", sourceEntityName: "JournalTransaction", targetEntityName: "LedgerPostingLine", inverseName: "journalTransaction", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "journal_transaction_id"),
                SchemaRelationship(name: "accountPostings", sourceEntityName: "LedgerAccount", targetEntityName: "LedgerPostingLine", inverseName: "ledgerAccount", kind: .oneToMany, deleteRule: .deny, foreignKeyColumn: "ledger_account_id")
            ]
        )
    }

    private static func buildAIRAGKnowledgeBasePreset() -> DataSchemaWorkspace {
        let corpus = SchemaEntity(
            name: "KnowledgeCorpus",
            summary: "Curated domain collection configured with embedding model parameters.",
            domainGroup: "AI Retrieval",
            accentHex: "#6D28D9",
            estimatedRowCount: 1_200,
            position: SchemaEntityCanvasPosition(x: 40, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "title", fieldType: .string(maxLength: 140), isFullTextSearchable: true),
                SchemaAttribute(name: "embedding_model", fieldType: .string(maxLength: 80), defaultValue: .literalString("nomic-embed-text-v1.5")),
                SchemaAttribute(name: "chunk_token_window", fieldType: .int64, defaultValue: .literalInt(512))
            ]
        )

        let doc = SchemaEntity(
            name: "SourceDocument",
            summary: "Ingested Markdown, PDF, or Swift source artifact with SHA-256 digest.",
            domainGroup: "AI Retrieval",
            accentHex: "#2563EB",
            estimatedRowCount: 38_000,
            position: SchemaEntityCanvasPosition(x: 340, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "knowledge_corpus_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "uri", fieldType: .string(maxLength: 512), isUnique: true),
                SchemaAttribute(name: "sha256_checksum", fieldType: .string(maxLength: 64), isIndexed: true),
                SchemaAttribute(name: "raw_markdown", fieldType: .text, isFullTextSearchable: true)
            ]
        )

        let chunk = SchemaEntity(
            name: "SemanticChunk",
            summary: "Tokenized passage paired with a 768-d float32 vector embedding.",
            domainGroup: "Vector Store",
            accentHex: "#0891B2",
            estimatedRowCount: 420_000,
            position: SchemaEntityCanvasPosition(x: 190, y: 250),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "source_document_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "chunk_ordinal", fieldType: .int64),
                SchemaAttribute(name: "content_text", fieldType: .text, isFullTextSearchable: true),
                SchemaAttribute(name: "embedding", fieldType: .vectorEmbedding(dimensions: 768)),
                SchemaAttribute(name: "token_count", fieldType: .int64)
            ],
            indexes: [
                SchemaIndex(name: "hnsw_semantic_chunks_embedding", columns: ["embedding"], kind: .vectorHNSW, rationale: "Sub-10ms cosine kNN retrieval"),
                SchemaIndex(name: "fts_semantic_chunks_content", columns: ["content_text"], kind: .fts5FullText, rationale: "BM25 lexical hybrid reranking")
            ]
        )

        return DataSchemaWorkspace(
            name: "AI RAG Knowledge Base",
            namespacePrefix: "RAG",
            entities: [corpus, doc, chunk],
            relationships: [
                SchemaRelationship(name: "documents", sourceEntityName: "KnowledgeCorpus", targetEntityName: "SourceDocument", inverseName: "corpus", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "knowledge_corpus_id"),
                SchemaRelationship(name: "chunks", sourceEntityName: "SourceDocument", targetEntityName: "SemanticChunk", inverseName: "document", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "source_document_id")
            ]
        )
    }

    private static func buildEcommerceInventoryPreset() -> DataSchemaWorkspace {
        let product = SchemaEntity(
            name: "CatalogProduct",
            summary: "Merchandise master item with localized title and tax class.",
            domainGroup: "Catalog",
            accentHex: "#EA580C",
            estimatedRowCount: 18_000,
            position: SchemaEntityCanvasPosition(x: 40, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "handle", fieldType: .string(maxLength: 96), isUnique: true),
                SchemaAttribute(name: "title", fieldType: .string(maxLength: 180), isFullTextSearchable: true),
                SchemaAttribute(name: "description_body", fieldType: .text, isFullTextSearchable: true),
                SchemaAttribute(name: "status", fieldType: .enumCases(["draft", "active", "archived"]), defaultValue: .literalString("active"))
            ]
        )

        let sku = SchemaEntity(
            name: "ProductVariantSKU",
            summary: "Sellable SKU configuration with barcode, unit price, and safety stock.",
            domainGroup: "Inventory",
            accentHex: "#0D9488",
            estimatedRowCount: 64_000,
            position: SchemaEntityCanvasPosition(x: 340, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "catalog_product_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "sku_code", fieldType: .string(maxLength: 48), isUnique: true),
                SchemaAttribute(name: "unit_price", fieldType: .decimal(precision: 12, scale: 2)),
                SchemaAttribute(name: "available_units", fieldType: .int64, defaultValue: .literalInt(0))
            ],
            constraints: [
                SchemaConstraint(name: "chk_sku_non_negative_stock", kind: .numericBounds, columns: ["available_units"], expression: "available_units >= 0", errorMessage: "Inventory stock cannot drop below zero.")
            ]
        )

        let order = SchemaEntity(
            name: "CustomerOrder",
            summary: "Checkout order header with payment state and shipping destination.",
            domainGroup: "Fulfillment",
            accentHex: "#2563EB",
            estimatedRowCount: 310_000,
            position: SchemaEntityCanvasPosition(x: 40, y: 250),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "order_number", fieldType: .string(maxLength: 32), isUnique: true),
                SchemaAttribute(name: "customer_email", fieldType: .string(maxLength: 254), isIndexed: true, isSensitivePII: true),
                SchemaAttribute(name: "fulfillment_state", fieldType: .enumCases(["unfulfilled", "packed", "shipped", "delivered"]), defaultValue: .literalString("unfulfilled")),
                SchemaAttribute(name: "grand_total", fieldType: .decimal(precision: 12, scale: 2))
            ]
        )

        let lineItem = SchemaEntity(
            name: "OrderLineItem",
            summary: "Captured SKU quantity and unit price snapshot at purchase time.",
            domainGroup: "Fulfillment",
            accentHex: "#4F46E5",
            estimatedRowCount: 890_000,
            position: SchemaEntityCanvasPosition(x: 340, y: 250),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "customer_order_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "product_variant_sku_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "quantity", fieldType: .int64, defaultValue: .literalInt(1)),
                SchemaAttribute(name: "captured_unit_price", fieldType: .decimal(precision: 12, scale: 2))
            ]
        )

        return DataSchemaWorkspace(
            name: "Omnichannel Commerce & Inventory",
            namespacePrefix: "Shop",
            entities: [product, sku, order, lineItem],
            relationships: [
                SchemaRelationship(name: "variants", sourceEntityName: "CatalogProduct", targetEntityName: "ProductVariantSKU", inverseName: "product", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "catalog_product_id"),
                SchemaRelationship(name: "lineItems", sourceEntityName: "CustomerOrder", targetEntityName: "OrderLineItem", inverseName: "order", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "customer_order_id"),
                SchemaRelationship(name: "orderAllocations", sourceEntityName: "ProductVariantSKU", targetEntityName: "OrderLineItem", inverseName: "variantSKU", kind: .oneToMany, deleteRule: .deny, foreignKeyColumn: "product_variant_sku_id")
            ]
        )
    }

    private static func buildHealthBiometricsVaultPreset() -> DataSchemaWorkspace {
        let patient = SchemaEntity(
            name: "PatientProfile",
            summary: "De-identified clinical subject record with PII birth metadata.",
            domainGroup: "Clinical",
            accentHex: "#DC2626",
            estimatedRowCount: 22_000,
            position: SchemaEntityCanvasPosition(x: 40, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "medical_record_code", fieldType: .string(maxLength: 40), isUnique: true, isSensitivePII: true),
                SchemaAttribute(name: "given_name", fieldType: .string(maxLength: 80), isSensitivePII: true),
                SchemaAttribute(name: "biological_sex", fieldType: .enumCases(["female", "male", "intersex", "unspecified"])),
                SchemaAttribute(name: "resting_hr_baseline", fieldType: .double, isNullable: true)
            ]
        )

        let sample = SchemaEntity(
            name: "BiometricSampleSeries",
            summary: "Continuous Apple Watch HRV, SpO2, or heart-rate telemetry reading.",
            domainGroup: "Telemetry",
            accentHex: "#0284C7",
            estimatedRowCount: 2_500_000,
            position: SchemaEntityCanvasPosition(x: 340, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "patient_profile_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "metric_type", fieldType: .enumCases(["heartRateBPM", "hrvSDNNms", "bloodOxygenPct", "wristTempDeltaC"])),
                SchemaAttribute(name: "value", fieldType: .double),
                SchemaAttribute(name: "sampled_at", fieldType: .timestamp, isIndexed: true),
                SchemaAttribute(name: "source_device", fieldType: .string(maxLength: 64))
            ]
        )

        let consent = SchemaEntity(
            name: "ClinicalConsentRecord",
            summary: "Signed research consent artifact with revocation timestamp.",
            domainGroup: "Compliance",
            accentHex: "#059669",
            estimatedRowCount: 35_000,
            position: SchemaEntityCanvasPosition(x: 190, y: 250),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "patient_profile_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "protocol_version", fieldType: .string(maxLength: 24)),
                SchemaAttribute(name: "is_granted", fieldType: .bool, defaultValue: .literalBool(true)),
                SchemaAttribute(name: "signed_at", fieldType: .timestamp, defaultValue: .nowTimestamp)
            ]
        )

        return DataSchemaWorkspace(
            name: "Health Biometrics & Consent Vault",
            namespacePrefix: "Bio",
            entities: [patient, sample, consent],
            relationships: [
                SchemaRelationship(name: "biometricSamples", sourceEntityName: "PatientProfile", targetEntityName: "BiometricSampleSeries", inverseName: "patient", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "patient_profile_id"),
                SchemaRelationship(name: "consents", sourceEntityName: "PatientProfile", targetEntityName: "ClinicalConsentRecord", inverseName: "patient", kind: .oneToMany, deleteRule: .deny, foreignKeyColumn: "patient_profile_id")
            ]
        )
    }

    private static func buildSocialCreatorFeedPreset() -> DataSchemaWorkspace {
        let creator = SchemaEntity(
            name: "CreatorHandle",
            summary: "Public creator profile with handle, bio, and verification status.",
            domainGroup: "Social",
            accentHex: "#DB2777",
            estimatedRowCount: 150_000,
            position: SchemaEntityCanvasPosition(x: 40, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "handle", fieldType: .string(maxLength: 32), isUnique: true),
                SchemaAttribute(name: "display_name", fieldType: .string(maxLength: 80), isFullTextSearchable: true),
                SchemaAttribute(name: "bio_markdown", fieldType: .text, isFullTextSearchable: true),
                SchemaAttribute(name: "is_verified", fieldType: .bool, defaultValue: .literalBool(false))
            ]
        )

        let post = SchemaEntity(
            name: "MediaPost",
            summary: "Published feed card with visibility gate and engagement counters.",
            domainGroup: "Feed",
            accentHex: "#7C3AED",
            isSoftDeletable: true,
            estimatedRowCount: 1_800_000,
            position: SchemaEntityCanvasPosition(x: 340, y: 40),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "creator_handle_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "caption", fieldType: .text, isFullTextSearchable: true),
                SchemaAttribute(name: "visibility", fieldType: .enumCases(["publicFeed", "subscribersOnly", "unlisted"]), defaultValue: .literalString("publicFeed")),
                SchemaAttribute(name: "like_count", fieldType: .int64, defaultValue: .literalInt(0)),
                SchemaAttribute(name: "published_at", fieldType: .timestamp, isIndexed: true, defaultValue: .nowTimestamp)
            ]
        )

        let comment = SchemaEntity(
            name: "PostComment",
            summary: "Reader discussion reply attached to a media post.",
            domainGroup: "Engagement",
            accentHex: "#2563EB",
            estimatedRowCount: 4_200_000,
            position: SchemaEntityCanvasPosition(x: 190, y: 250),
            attributes: [
                SchemaAttribute(name: "id", fieldType: .uuid, isPrimaryKey: true, defaultValue: .uuidV4),
                SchemaAttribute(name: "media_post_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "author_handle_id", fieldType: .uuid, isIndexed: true),
                SchemaAttribute(name: "body_text", fieldType: .text, isFullTextSearchable: true)
            ]
        )

        return DataSchemaWorkspace(
            name: "Social Creator Subscription Feed",
            namespacePrefix: "Feed",
            entities: [creator, post, comment],
            relationships: [
                SchemaRelationship(name: "posts", sourceEntityName: "CreatorHandle", targetEntityName: "MediaPost", inverseName: "creator", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "creator_handle_id"),
                SchemaRelationship(name: "comments", sourceEntityName: "MediaPost", targetEntityName: "PostComment", inverseName: "post", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "media_post_id"),
                SchemaRelationship(name: "authoredComments", sourceEntityName: "CreatorHandle", targetEntityName: "PostComment", inverseName: "author", kind: .oneToMany, deleteRule: .cascade, foreignKeyColumn: "author_handle_id")
            ]
        )
    }
}

// MARK: - Internal Naming Utilities

enum SchemaNamingHelpers {
    static func snakeCase(_ input: String) -> String {
        guard !input.isEmpty else { return "" }
        var chars: [Character] = []
        let scalars = Array(input)
        for (idx, ch) in scalars.enumerated() {
            if ch.isUppercase {
                if idx > 0 {
                    let prev = scalars[idx - 1]
                    let nextIsLower = (idx + 1 < scalars.count) && scalars[idx + 1].isLowercase
                    if prev.isLowercase || prev.isNumber || (prev.isUppercase && nextIsLower) {
                        chars.append("_")
                    }
                }
                for c in ch.lowercased() { chars.append(c) }
            } else if ch == "-" || ch == " " {
                chars.append("_")
            } else {
                chars.append(ch)
            }
        }
        return String(chars)
    }

    static func pluralSnakeCase(_ input: String) -> String {
        let base = snakeCase(input)
        if base.hasSuffix("y") && !base.hasSuffix("ay") && !base.hasSuffix("ey") && !base.hasSuffix("oy") && !base.hasSuffix("uy") {
            return String(base.dropLast()) + "ies"
        }
        if base.hasSuffix("s") || base.hasSuffix("x") || base.hasSuffix("z") || base.hasSuffix("ch") || base.hasSuffix("sh") {
            return base + "es"
        }
        return base + "s"
    }

    static func camelCase(_ input: String) -> String {
        let parts = snakeCase(input)
            .split(separator: "_")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let first = parts.first else { return input }
        let tail = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
        return ([first.lowercased()] + tail).joined()
    }

    static func pascalCase(_ input: String) -> String {
        snakeCase(input)
            .split(separator: "_")
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined()
    }
}
