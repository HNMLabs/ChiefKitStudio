import Foundation

// MARK: - REST & GraphQL Contract Models

public enum HTTPMethodKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"

    public var id: String { rawValue }
    public var openAPIKey: String { rawValue.lowercased() }
}

public enum APIAuthScheme: Codable, Hashable, Sendable {
    case none
    case bearerJWT
    case apiKeyHeader(headerName: String)
    case oauth2AuthorizationCode(scopes: [String])
    case hmacSignature

    public var displayLabel: String {
        switch self {
        case .none: "Public (No Auth)"
        case .bearerJWT: "Bearer JWT (RFC 6750)"
        case .apiKeyHeader(let header): "API Key (\(header))"
        case .oauth2AuthorizationCode(let scopes): "OAuth 2.0 PKCE (\(scopes.count) scopes)"
        case .hmacSignature: "HMAC-SHA256 Signed Request"
        }
    }

    public var securitySchemeName: String? {
        switch self {
        case .none: nil
        case .bearerJWT: "BearerJWT"
        case .apiKeyHeader: "ApiKeyHeader"
        case .oauth2AuthorizationCode: "OAuth2PKCE"
        case .hmacSignature: "HMACSignature"
        }
    }
}

public struct APIRateLimitPolicy: Codable, Hashable, Sendable {
    public var requestsPerMinute: Int
    public var burstCapacity: Int
    public var keyStrategy: String
    public var emitStandardRateLimitHeaders: Bool

    public init(
        requestsPerMinute: Int = 120,
        burstCapacity: Int = 30,
        keyStrategy: String = "tenant_or_ip",
        emitStandardRateLimitHeaders: Bool = true
    ) {
        self.requestsPerMinute = max(1, requestsPerMinute)
        self.burstCapacity = max(1, burstCapacity)
        self.keyStrategy = keyStrategy
        self.emitStandardRateLimitHeaders = emitStandardRateLimitHeaders
    }
}

public enum APIPaginationStyle: Codable, Hashable, Sendable {
    case none
    case cursorBased(defaultLimit: Int, maxLimit: Int)
    case offsetLimit(defaultLimit: Int, maxLimit: Int)

    public var isPaginated: Bool {
        switch self {
        case .none: false
        case .cursorBased, .offsetLimit: true
        }
    }
}

public enum APIParameterLocation: String, CaseIterable, Codable, Identifiable, Sendable {
    case path
    case query
    case header

    public var id: String { rawValue }
}

public struct APIParameterSpec: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var location: APIParameterLocation
    public var fieldType: SchemaFieldType
    public var isRequired: Bool
    public var defaultValue: String?
    public var summary: String

    public init(
        id: UUID = UUID(),
        name: String,
        location: APIParameterLocation,
        fieldType: SchemaFieldType,
        isRequired: Bool = false,
        defaultValue: String? = nil,
        summary: String = ""
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.fieldType = fieldType
        self.isRequired = location == .path ? true : isRequired
        self.defaultValue = defaultValue
        self.summary = summary
    }
}

public struct APIEndpointSpec: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var operationID: String
    public var summary: String
    public var tagGroup: String
    public var method: HTTPMethodKind
    public var pathTemplate: String
    public var authOverride: APIAuthScheme?
    public var pagination: APIPaginationStyle
    public var parameters: [APIParameterSpec]
    public var requestEntityName: String?
    public var responseEntityName: String?
    public var returnsCollection: Bool
    public var successStatusCode: Int
    public var isIdempotent: Bool

    public init(
        id: UUID = UUID(),
        operationID: String,
        summary: String,
        tagGroup: String = "Core",
        method: HTTPMethodKind,
        pathTemplate: String,
        authOverride: APIAuthScheme? = nil,
        pagination: APIPaginationStyle = .none,
        parameters: [APIParameterSpec] = [],
        requestEntityName: String? = nil,
        responseEntityName: String? = nil,
        returnsCollection: Bool = false,
        successStatusCode: Int = 200,
        isIdempotent: Bool? = nil
    ) {
        self.id = id
        self.operationID = operationID
        self.summary = summary
        self.tagGroup = tagGroup
        self.method = method
        self.pathTemplate = pathTemplate.hasPrefix("/") ? pathTemplate : "/\(pathTemplate)"
        self.authOverride = authOverride
        self.pagination = pagination
        self.parameters = parameters
        self.requestEntityName = requestEntityName
        self.responseEntityName = responseEntityName
        self.returnsCollection = returnsCollection
        self.successStatusCode = successStatusCode
        if let isIdempotent {
            self.isIdempotent = isIdempotent
        } else {
            self.isIdempotent = (method == .get || method == .put || method == .delete || method == .head || method == .options)
        }
    }
}

public struct APIServiceSpec: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var version: String
    public var baseURL: String
    public var description: String
    public var defaultAuth: APIAuthScheme
    public var rateLimit: APIRateLimitPolicy
    public var schemaWorkspace: DataSchemaWorkspace
    public var endpoints: [APIEndpointSpec]

    public init(
        id: UUID = UUID(),
        title: String,
        version: String = "1.0.0",
        baseURL: String = "https://api.chiefkit.dev/v1",
        description: String = "",
        defaultAuth: APIAuthScheme = .bearerJWT,
        rateLimit: APIRateLimitPolicy = APIRateLimitPolicy(),
        schemaWorkspace: DataSchemaWorkspace,
        endpoints: [APIEndpointSpec] = []
    ) {
        self.id = id
        self.title = title
        self.version = version
        self.baseURL = baseURL
        self.description = description
        self.defaultAuth = defaultAuth
        self.rateLimit = rateLimit
        self.schemaWorkspace = schemaWorkspace
        self.endpoints = endpoints
    }

    /// Automatically derives idiomatic REST CRUD + Search endpoints for every entity in a `DataSchemaWorkspace`.
    public static func deriveCRUDService(
        from workspace: DataSchemaWorkspace,
        baseURL: String = "https://api.chiefkit.dev/v1",
        auth: APIAuthScheme = .bearerJWT,
        pagination: APIPaginationStyle = .cursorBased(defaultLimit: 25, maxLimit: 100)
    ) -> APIServiceSpec {
        var generated: [APIEndpointSpec] = []

        for entity in workspace.entities {
            let resourceSlug = entity.tableName.replacingOccurrences(of: "_", with: "-")
            let collectionPath = "/\(resourceSlug)"
            let itemPath = "/\(resourceSlug)/{id}"
            let pluralPascal = SchemaNamingHelpers.pascalCase(entity.tableName)
            let pkType = entity.primaryKeyAttribute?.fieldType ?? .uuid

            var listParams: [APIParameterSpec] = []
            switch pagination {
            case .none:
                break
            case .cursorBased(let defLimit, _):
                listParams.append(APIParameterSpec(name: "cursor", location: .query, fieldType: .string(maxLength: 128), summary: "Opaque pagination cursor"))
                listParams.append(APIParameterSpec(name: "limit", location: .query, fieldType: .int64, defaultValue: "\(defLimit)", summary: "Page size"))
            case .offsetLimit(let defLimit, _):
                listParams.append(APIParameterSpec(name: "offset", location: .query, fieldType: .int64, defaultValue: "0", summary: "Zero-based row offset"))
                listParams.append(APIParameterSpec(name: "limit", location: .query, fieldType: .int64, defaultValue: "\(defLimit)", summary: "Maximum records"))
            }

            if entity.attributes.contains(where: \.isFullTextSearchable) {
                listParams.append(APIParameterSpec(name: "q", location: .query, fieldType: .string(maxLength: 160), summary: "Full-text search filter"))
            }

            generated.append(
                APIEndpointSpec(
                    operationID: "list\(pluralPascal)",
                    summary: "List \(entity.name) records with filtering and pagination.",
                    tagGroup: entity.domainGroup,
                    method: .get,
                    pathTemplate: collectionPath,
                    pagination: pagination,
                    parameters: listParams,
                    responseEntityName: entity.name,
                    returnsCollection: true,
                    successStatusCode: 200
                )
            )

            generated.append(
                APIEndpointSpec(
                    operationID: "create\(entity.name)",
                    summary: "Create a new \(entity.name) resource.",
                    tagGroup: entity.domainGroup,
                    method: .post,
                    pathTemplate: collectionPath,
                    parameters: [
                        APIParameterSpec(name: "Idempotency-Key", location: .header, fieldType: .string(maxLength: 96), isRequired: false, summary: "Safe retry key")
                    ],
                    requestEntityName: entity.name,
                    responseEntityName: entity.name,
                    returnsCollection: false,
                    successStatusCode: 201,
                    isIdempotent: false
                )
            )

            let idPathParam = APIParameterSpec(name: "id", location: .path, fieldType: pkType, isRequired: true, summary: "Primary key identifier")

            generated.append(
                APIEndpointSpec(
                    operationID: "get\(entity.name)",
                    summary: "Fetch a single \(entity.name) by primary key.",
                    tagGroup: entity.domainGroup,
                    method: .get,
                    pathTemplate: itemPath,
                    parameters: [idPathParam],
                    responseEntityName: entity.name,
                    returnsCollection: false,
                    successStatusCode: 200
                )
            )

            generated.append(
                APIEndpointSpec(
                    operationID: "update\(entity.name)",
                    summary: "Patch mutable fields on an existing \(entity.name).",
                    tagGroup: entity.domainGroup,
                    method: .patch,
                    pathTemplate: itemPath,
                    parameters: [idPathParam],
                    requestEntityName: entity.name,
                    responseEntityName: entity.name,
                    returnsCollection: false,
                    successStatusCode: 200,
                    isIdempotent: true
                )
            )

            generated.append(
                APIEndpointSpec(
                    operationID: "delete\(entity.name)",
                    summary: "Delete a \(entity.name) resource by primary key.",
                    tagGroup: entity.domainGroup,
                    method: .delete,
                    pathTemplate: itemPath,
                    parameters: [idPathParam],
                    returnsCollection: false,
                    successStatusCode: 204,
                    isIdempotent: true
                )
            )
        }

        return APIServiceSpec(
            title: "\(workspace.name) API",
            version: "\(workspace.schemaVersion).0.0",
            baseURL: baseURL,
            description: "Contract-first REST & GraphQL specification synthesized from \(workspace.name).",
            defaultAuth: auth,
            schemaWorkspace: workspace,
            endpoints: generated
        )
    }
}

// MARK: - Mock HTTP Response Model

public struct MockHTTPResponse: Codable, Hashable, Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var bodyJSON: String
    public var matchedOperationID: String?
    public var simulatedLatencyMs: Double

    public init(
        statusCode: Int,
        headers: [String: String],
        bodyJSON: String,
        matchedOperationID: String? = nil,
        simulatedLatencyMs: Double = 14.5
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.bodyJSON = bodyJSON
        self.matchedOperationID = matchedOperationID
        self.simulatedLatencyMs = simulatedLatencyMs
    }
}

// MARK: - APISpecAndMockEngine

public enum APISpecAndMockEngine {

    // MARK: - 1) OpenAPI 3.1.0 JSON Compiler

    public static func compileOpenAPI31JSON(_ service: APIServiceSpec) -> String {
        var root: [String: Any] = [
            "openapi": "3.1.0",
            "info": [
                "title": service.title,
                "version": service.version,
                "description": service.description.isEmpty ? "Generated by ChiefKit Studio 3.0" : service.description
            ],
            "servers": [
                ["url": service.baseURL, "description": "Primary API Gateway"]
            ]
        ]

        if let secName = service.defaultAuth.securitySchemeName {
            root["security"] = [[secName: [String]()]]
        }

        // Build paths
        var pathsDict: [String: [String: Any]] = [:]
        for ep in service.endpoints {
            var opObj: [String: Any] = [
                "operationId": ep.operationID,
                "summary": ep.summary,
                "tags": [ep.tagGroup]
            ]

            let activeAuth = ep.authOverride ?? service.defaultAuth
            if case .none = activeAuth {
                opObj["security"] = [[String: [String]]]()
            } else if let scheme = activeAuth.securitySchemeName {
                opObj["security"] = [[scheme: [String]()]]
            }

            if !ep.parameters.isEmpty {
                opObj["parameters"] = ep.parameters.map { param -> [String: Any] in
                    var paramMap: [String: Any] = [
                        "name": param.name,
                        "in": param.location.rawValue,
                        "required": param.isRequired,
                        "schema": openAPISchemaObject(for: param.fieldType)
                    ]
                    if !param.summary.isEmpty {
                        paramMap["description"] = param.summary
                    }
                    return paramMap
                }
            }

            if let reqEntity = ep.requestEntityName {
                let schemaRef = ep.method == .patch ? "#/components/schemas/\(reqEntity)PatchInput" : "#/components/schemas/\(reqEntity)Input"
                opObj["requestBody"] = [
                    "required": true,
                    "content": [
                        "application/json": [
                            "schema": ["$ref": schemaRef]
                        ]
                    ]
                ]
            }

            var responses: [String: Any] = [:]
            let statusKey = "\(ep.successStatusCode)"
            if ep.successStatusCode == 204 || ep.responseEntityName == nil {
                responses[statusKey] = ["description": "No Content"]
            } else if let respEntity = ep.responseEntityName {
                let responseSchema: [String: Any]
                if ep.returnsCollection {
                    if ep.pagination.isPaginated {
                        responseSchema = ["$ref": "#/components/schemas/\(respEntity)Page"]
                    } else {
                        responseSchema = [
                            "type": "array",
                            "items": ["$ref": "#/components/schemas/\(respEntity)"]
                        ]
                    }
                } else {
                    responseSchema = ["$ref": "#/components/schemas/\(respEntity)"]
                }
                responses[statusKey] = [
                    "description": "Successful \(ep.operationID) response",
                    "content": [
                        "application/json": ["schema": responseSchema]
                    ]
                ]
            }

            responses["400"] = ["$ref": "#/components/responses/BadRequestProblem"]
            responses["401"] = ["$ref": "#/components/responses/UnauthorizedProblem"]
            responses["429"] = ["$ref": "#/components/responses/RateLimitedProblem"]
            opObj["responses"] = responses

            var pathMethods = pathsDict[ep.pathTemplate] ?? [:]
            pathMethods[ep.method.openAPIKey] = opObj
            pathsDict[ep.pathTemplate] = pathMethods
        }
        root["paths"] = pathsDict

        // Build components.schemas
        var schemas: [String: Any] = [
            "ProblemDetails": [
                "type": "object",
                "required": ["type", "title", "status", "detail"],
                "properties": [
                    "type": ["type": "string", "format": "uri"],
                    "title": ["type": "string"],
                    "status": ["type": "integer"],
                    "detail": ["type": "string"],
                    "trace_id": ["type": "string"]
                ]
            ]
        ]

        for entity in service.schemaWorkspace.entities {
            var props: [String: Any] = [:]
            var requiredCols: [String] = []
            var inputProps: [String: Any] = [:]
            var inputRequired: [String] = []

            for attr in entity.attributes {
                let fieldSchema = openAPISchemaObject(for: attr.fieldType, nullable: attr.isNullable)
                props[attr.name] = fieldSchema
                if !attr.isNullable {
                    requiredCols.append(attr.name)
                }
                if !attr.isPrimaryKey {
                    inputProps[attr.name] = fieldSchema
                    if !attr.isNullable && attr.defaultValue == .none {
                        inputRequired.append(attr.name)
                    }
                }
            }

            if entity.isAuditedWithTimestamps {
                props["created_at"] = ["type": "string", "format": "date-time"]
                props["updated_at"] = ["type": "string", "format": "date-time"]
            }

            schemas[entity.name] = [
                "type": "object",
                "description": entity.summary,
                "required": requiredCols,
                "properties": props
            ]

            var createInput: [String: Any] = [
                "type": "object",
                "properties": inputProps
            ]
            if !inputRequired.isEmpty {
                createInput["required"] = inputRequired
            }
            schemas["\(entity.name)Input"] = createInput

            schemas["\(entity.name)PatchInput"] = [
                "type": "object",
                "properties": inputProps
            ]

            schemas["\(entity.name)Page"] = [
                "type": "object",
                "required": ["items", "has_more"],
                "properties": [
                    "items": [
                        "type": "array",
                        "items": ["$ref": "#/components/schemas/\(entity.name)"]
                    ],
                    "next_cursor": ["type": ["string", "null"]],
                    "has_more": ["type": "boolean"],
                    "total_estimate": ["type": "integer"]
                ]
            ]
        }

        var components: [String: Any] = [
            "schemas": schemas,
            "responses": [
                "BadRequestProblem": [
                    "description": "Validation or malformed payload error",
                    "content": ["application/problem+json": ["schema": ["$ref": "#/components/schemas/ProblemDetails"]]]
                ],
                "UnauthorizedProblem": [
                    "description": "Missing or invalid authentication credentials",
                    "content": ["application/problem+json": ["schema": ["$ref": "#/components/schemas/ProblemDetails"]]]
                ],
                "RateLimitedProblem": [
                    "description": "Rate limit quota exceeded (\(service.rateLimit.requestsPerMinute) req/min)",
                    "content": ["application/problem+json": ["schema": ["$ref": "#/components/schemas/ProblemDetails"]]]
                ]
            ]
        ]

        if let secScheme = openAPISecurityScheme(for: service.defaultAuth),
           let secName = service.defaultAuth.securitySchemeName {
            components["securitySchemes"] = [secName: secScheme]
        }

        root["components"] = components

        guard JSONSerialization.isValidJSONObject(root),
              let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func openAPISchemaObject(for fieldType: SchemaFieldType, nullable: Bool = false) -> [String: Any] {
        func wrapType(_ primary: String) -> Any {
            nullable ? [primary, "null"] : primary
        }
        switch fieldType {
        case .uuid:
            return ["type": wrapType("string"), "format": "uuid"]
        case .string(let maxLength):
            var obj: [String: Any] = ["type": wrapType("string")]
            if let maxLength { obj["maxLength"] = maxLength }
            return obj
        case .text:
            return ["type": wrapType("string")]
        case .int64:
            return ["type": wrapType("integer"), "format": "int64"]
        case .double:
            return ["type": wrapType("number"), "format": "double"]
        case .decimal(let precision, let scale):
            return ["type": wrapType("string"), "format": "decimal(\(precision),\(scale))"]
        case .bool:
            return ["type": wrapType("boolean")]
        case .timestamp:
            return ["type": wrapType("string"), "format": "date-time"]
        case .jsonBlob:
            return ["type": nullable ? ["object", "null"] : "object", "additionalProperties": true]
        case .enumCases(let cases):
            return ["type": wrapType("string"), "enum": cases]
        case .vectorEmbedding(let dims):
            return [
                "type": wrapType("array"),
                "items": ["type": "number", "format": "float"],
                "minItems": dims,
                "maxItems": dims
            ]
        }
    }

    private static func openAPISecurityScheme(for auth: APIAuthScheme) -> [String: Any]? {
        switch auth {
        case .none:
            return nil
        case .bearerJWT:
            return ["type": "http", "scheme": "bearer", "bearerFormat": "JWT"]
        case .apiKeyHeader(let headerName):
            return ["type": "apiKey", "in": "header", "name": headerName]
        case .oauth2AuthorizationCode(let scopes):
            let scopeDict = Dictionary(uniqueKeysWithValues: scopes.map { ($0, "Access \($0)") })
            return [
                "type": "oauth2",
                "flows": [
                    "authorizationCode": [
                        "authorizationUrl": "https://auth.chiefkit.dev/oauth/authorize",
                        "tokenUrl": "https://auth.chiefkit.dev/oauth/token",
                        "scopes": scopeDict
                    ]
                ]
            ]
        case .hmacSignature:
            return ["type": "apiKey", "in": "header", "name": "X-ChiefKit-Signature"]
        }
    }

    // MARK: - 2) GraphQL Schema Definition Language (SDL) Compiler

    public static func compileGraphQLSDL(_ service: APIServiceSpec) -> String {
        let workspace = service.schemaWorkspace
        var sdl: [String] = [
            "# Generated by ChiefKit Studio 3.0 — GraphQL SDL Compiler",
            "# Service: \(service.title) (v\(service.version))",
            "",
            "scalar UUID",
            "scalar DateTime",
            "scalar Decimal",
            "scalar JSON",
            "",
            "type PageInfo {",
            "  hasNextPage: Boolean!",
            "  endCursor: String",
            "  totalCount: Int!",
            "}",
            ""
        ]

        // Enums
        for entity in workspace.entities {
            for attr in entity.attributes {
                if case .enumCases(let cases) = attr.fieldType {
                    let enumName = "\(entity.name)\(SchemaNamingHelpers.pascalCase(attr.name))"
                    sdl.append("enum \(enumName) {")
                    for raw in (cases.isEmpty ? ["UNSPECIFIED"] : cases) {
                        let token = SchemaNamingHelpers.snakeCase(raw).uppercased()
                        sdl.append("  \(token.isEmpty ? "UNSPECIFIED" : token)")
                    }
                    sdl.append("}")
                    sdl.append("")
                }
            }
        }

        // Object types, Connections, and Input types
        for entity in workspace.entities {
            if !entity.summary.isEmpty {
                sdl.append("\"\"\"\(entity.summary)\"\"\"")
            }
            sdl.append("type \(entity.name) {")
            for attr in entity.attributes {
                let fieldName = SchemaNamingHelpers.camelCase(attr.name)
                let gqlType = graphQLFieldType(for: attr, entityName: entity.name, forceNullable: false)
                sdl.append("  \(fieldName): \(gqlType)")
            }

            for rel in workspace.outgoingRelationships(from: entity.name) {
                let relField = SchemaNamingHelpers.camelCase(rel.name)
                switch rel.kind {
                case .oneToOne:
                    let bang = rel.isOptional ? "" : "!"
                    sdl.append("  \(relField): \(rel.targetEntityName)\(bang)")
                case .oneToMany, .manyToMany:
                    sdl.append("  \(relField)(first: Int = 20, after: String): [\(rel.targetEntityName)!]!")
                }
            }

            if entity.isAuditedWithTimestamps {
                sdl.append("  createdAt: DateTime!")
                sdl.append("  updatedAt: DateTime!")
            }
            sdl.append("}")
            sdl.append("")

            sdl.append("type \(entity.name)Edge {")
            sdl.append("  cursor: String!")
            sdl.append("  node: \(entity.name)!")
            sdl.append("}")
            sdl.append("")

            sdl.append("type \(entity.name)Connection {")
            sdl.append("  edges: [\(entity.name)Edge!]!")
            sdl.append("  pageInfo: PageInfo!")
            sdl.append("}")
            sdl.append("")

            sdl.append("input Create\(entity.name)Input {")
            for attr in entity.attributes where !attr.isPrimaryKey {
                let fieldName = SchemaNamingHelpers.camelCase(attr.name)
                let isOptionalInput = attr.isNullable || attr.defaultValue != .none
                let gqlType = graphQLFieldType(for: attr, entityName: entity.name, forceNullable: isOptionalInput)
                sdl.append("  \(fieldName): \(gqlType)")
            }
            sdl.append("}")
            sdl.append("")

            sdl.append("input Patch\(entity.name)Input {")
            for attr in entity.attributes where !attr.isPrimaryKey {
                let fieldName = SchemaNamingHelpers.camelCase(attr.name)
                let gqlType = graphQLFieldType(for: attr, entityName: entity.name, forceNullable: true)
                sdl.append("  \(fieldName): \(gqlType)")
            }
            sdl.append("}")
            sdl.append("")
        }

        // Root Query, Mutation, Subscription
        sdl.append("type Query {")
        for entity in workspace.entities {
            let singleField = SchemaNamingHelpers.camelCase(entity.name)
            let listField = SchemaNamingHelpers.camelCase(entity.tableName)
            sdl.append("  \(singleField)(id: UUID!): \(entity.name)")
            sdl.append("  \(listField)(first: Int = 25, after: String, search: String): \(entity.name)Connection!")
        }
        sdl.append("}")
        sdl.append("")

        sdl.append("type Mutation {")
        for entity in workspace.entities {
            sdl.append("  create\(entity.name)(input: Create\(entity.name)Input!): \(entity.name)!")
            sdl.append("  patch\(entity.name)(id: UUID!, input: Patch\(entity.name)Input!): \(entity.name)!")
            sdl.append("  delete\(entity.name)(id: UUID!): Boolean!")
        }
        sdl.append("}")
        sdl.append("")

        sdl.append("type Subscription {")
        for entity in workspace.entities {
            let eventField = "\(SchemaNamingHelpers.camelCase(entity.name))Changed"
            sdl.append("  \(eventField)(tenantID: UUID): \(entity.name)!")
        }
        sdl.append("}")

        return sdl.joined(separator: "\n")
    }

    private static func graphQLFieldType(for attr: SchemaAttribute, entityName: String, forceNullable: Bool) -> String {
        let base: String
        switch attr.fieldType {
        case .uuid:
            base = attr.isPrimaryKey ? "ID" : "UUID"
        case .string, .text:
            base = "String"
        case .int64:
            base = "Int"
        case .double:
            base = "Float"
        case .decimal:
            base = "Decimal"
        case .bool:
            base = "Boolean"
        case .timestamp:
            base = "DateTime"
        case .jsonBlob:
            base = "JSON"
        case .enumCases:
            base = "\(entityName)\(SchemaNamingHelpers.pascalCase(attr.name))"
        case .vectorEmbedding:
            base = "[Float!]"
        }
        let nullable = forceNullable || attr.isNullable
        return nullable ? base : "\(base)!"
    }

    // MARK: - 3) Deterministic Mock HTTP Router & Realistic Sample JSON Synthesizer

    public static func simulateRequest(
        service: APIServiceSpec,
        method: HTTPMethodKind,
        path: String,
        query: [String: String] = [:],
        headers: [String: String] = [:],
        body: String? = nil,
        enforceAuth: Bool = false,
        seed: UInt64 = 2026
    ) -> MockHTTPResponse {
        let cleanPath = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? path
        let normalizedPath = cleanPath.hasPrefix("/") ? cleanPath : "/\(cleanPath)"
        let requestID = deterministicUUIDString(seed: seed, label: "\(method.rawValue):\(normalizedPath)")

        var baseHeaders: [String: String] = [
            "Content-Type": "application/json; charset=utf-8",
            "X-Request-Id": requestID
        ]
        if service.rateLimit.emitStandardRateLimitHeaders {
            baseHeaders["X-RateLimit-Limit"] = "\(service.rateLimit.requestsPerMinute)"
            baseHeaders["X-RateLimit-Remaining"] = "\(max(0, service.rateLimit.requestsPerMinute - 1))"
        }

        // Route matching
        var matchedEndpoint: APIEndpointSpec?
        var extractedPathParams: [String: String] = [:]

        for ep in service.endpoints where ep.method == method {
            if let params = matchPathTemplate(template: ep.pathTemplate, actualPath: normalizedPath) {
                matchedEndpoint = ep
                extractedPathParams = params
                break
            }
        }

        guard let endpoint = matchedEndpoint else {
            let pathExistsOtherMethod = service.endpoints.contains {
                matchPathTemplate(template: $0.pathTemplate, actualPath: normalizedPath) != nil
            }
            let code = pathExistsOtherMethod ? 405 : 404
            let title = pathExistsOtherMethod ? "Method Not Allowed" : "Endpoint Not Found"
            baseHeaders["Content-Type"] = "application/problem+json"
            return MockHTTPResponse(
                statusCode: code,
                headers: baseHeaders,
                bodyJSON: problemDetailsJSON(status: code, title: title, detail: "No \(method.rawValue) route matches '\(normalizedPath)'.", traceID: requestID),
                matchedOperationID: nil,
                simulatedLatencyMs: 4.2
            )
        }

        // Auth verification
        let activeAuth = endpoint.authOverride ?? service.defaultAuth
        let lowerHeaders = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        if enforceAuth && activeAuth != .none {
            let isAuthorized: Bool
            switch activeAuth {
            case .none:
                isAuthorized = true
            case .bearerJWT, .oauth2AuthorizationCode:
                let authVal = lowerHeaders["authorization"] ?? ""
                isAuthorized = authVal.lowercased().hasPrefix("bearer ") && authVal.count > 10
            case .apiKeyHeader(let headerName):
                isAuthorized = !(lowerHeaders[headerName.lowercased()] ?? "").isEmpty
            case .hmacSignature:
                isAuthorized = !(lowerHeaders["x-chiefkit-signature"] ?? "").isEmpty
            }
            if !isAuthorized {
                baseHeaders["Content-Type"] = "application/problem+json"
                return MockHTTPResponse(
                    statusCode: 401,
                    headers: baseHeaders,
                    bodyJSON: problemDetailsJSON(status: 401, title: "Unauthorized", detail: "Missing or invalid credentials for \(activeAuth.displayLabel).", traceID: requestID),
                    matchedOperationID: endpoint.operationID,
                    simulatedLatencyMs: 6.1
                )
            }
        }

        // Required query parameter validation
        for param in endpoint.parameters where param.location == .query && param.isRequired {
            if (query[param.name] ?? "").isEmpty {
                baseHeaders["Content-Type"] = "application/problem+json"
                return MockHTTPResponse(
                    statusCode: 400,
                    headers: baseHeaders,
                    bodyJSON: problemDetailsJSON(status: 400, title: "Missing Required Query Parameter", detail: "Query parameter '\(param.name)' is required.", traceID: requestID),
                    matchedOperationID: endpoint.operationID,
                    simulatedLatencyMs: 5.0
                )
            }
        }

        // Parse request body JSON if endpoint expects one
        var parsedBodyOverrides: [String: Any] = [:]
        if endpoint.requestEntityName != nil {
            guard let bodyText = body, !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                baseHeaders["Content-Type"] = "application/problem+json"
                return MockHTTPResponse(
                    statusCode: 400,
                    headers: baseHeaders,
                    bodyJSON: problemDetailsJSON(status: 400, title: "Empty Request Body", detail: "Operation '\(endpoint.operationID)' requires a JSON object body.", traceID: requestID),
                    matchedOperationID: endpoint.operationID,
                    simulatedLatencyMs: 5.5
                )
            }
            guard let rawData = bodyText.data(using: .utf8),
                  let jsonObj = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] else {
                baseHeaders["Content-Type"] = "application/problem+json"
                return MockHTTPResponse(
                    statusCode: 400,
                    headers: baseHeaders,
                    bodyJSON: problemDetailsJSON(status: 400, title: "Malformed JSON Payload", detail: "Request body must be a valid JSON object.", traceID: requestID),
                    matchedOperationID: endpoint.operationID,
                    simulatedLatencyMs: 5.8
                )
            }
            parsedBodyOverrides = jsonObj
        }

        if endpoint.successStatusCode == 204 || endpoint.responseEntityName == nil {
            return MockHTTPResponse(
                statusCode: endpoint.successStatusCode,
                headers: baseHeaders,
                bodyJSON: "",
                matchedOperationID: endpoint.operationID,
                simulatedLatencyMs: 11.4
            )
        }

        guard let entityName = endpoint.responseEntityName,
              let entity = service.schemaWorkspace.entity(named: entityName) else {
            return MockHTTPResponse(
                statusCode: endpoint.successStatusCode,
                headers: baseHeaders,
                bodyJSON: "{}",
                matchedOperationID: endpoint.operationID,
                simulatedLatencyMs: 12.0
            )
        }

        if endpoint.returnsCollection {
            let requestedLimit = query["limit"].flatMap(Int.init) ?? 3
            let clampedCount = min(max(1, requestedLimit), 5)
            let records = (0..<clampedCount).map { ordinal in
                synthesizeSampleObject(for: entity, ordinal: ordinal, pathParams: extractedPathParams, overrides: [:], seed: seed)
            }

            let responsePayload: Any
            if endpoint.pagination.isPaginated {
                responsePayload = [
                    "items": records,
                    "has_more": entity.estimatedRowCount > clampedCount,
                    "next_cursor": "cur_\(deterministicUUIDString(seed: seed &+ UInt64(clampedCount), label: entity.name).prefix(12))",
                    "total_estimate": entity.estimatedRowCount
                ] as [String: Any]
            } else {
                responsePayload = records
            }

            return MockHTTPResponse(
                statusCode: endpoint.successStatusCode,
                headers: baseHeaders,
                bodyJSON: encodePrettyJSONObject(responsePayload),
                matchedOperationID: endpoint.operationID,
                simulatedLatencyMs: 18.6
            )
        } else {
            let singleObj = synthesizeSampleObject(
                for: entity,
                ordinal: 0,
                pathParams: extractedPathParams,
                overrides: parsedBodyOverrides,
                seed: seed
            )
            return MockHTTPResponse(
                statusCode: endpoint.successStatusCode,
                headers: baseHeaders,
                bodyJSON: encodePrettyJSONObject(singleObj),
                matchedOperationID: endpoint.operationID,
                simulatedLatencyMs: 14.2
            )
        }
    }

    public static func synthesizeSampleEntityJSON(
        entity: SchemaEntity,
        ordinal: Int = 0,
        seed: UInt64 = 2026
    ) -> String {
        let obj = synthesizeSampleObject(for: entity, ordinal: ordinal, pathParams: [:], overrides: [:], seed: seed)
        return encodePrettyJSONObject(obj)
    }

    private static func synthesizeSampleObject(
        for entity: SchemaEntity,
        ordinal: Int,
        pathParams: [String: String],
        overrides: [String: Any],
        seed: UInt64
    ) -> [String: Any] {
        var obj: [String: Any] = [:]
        for attr in entity.attributes {
            if let overrideVal = overrides[attr.name] {
                obj[attr.name] = overrideVal
                continue
            }
            if attr.isPrimaryKey, let pathID = pathParams["id"] {
                obj[attr.name] = pathID
                continue
            }
            obj[attr.name] = sampleValue(for: attr, entityName: entity.name, ordinal: ordinal, seed: seed)
        }

        if entity.isAuditedWithTimestamps {
            if obj["created_at"] == nil {
                obj["created_at"] = "2026-04-1\(min(9, ordinal + 1))T09:30:00Z"
            }
            if obj["updated_at"] == nil {
                obj["updated_at"] = "2026-04-1\(min(9, ordinal + 1))T14:45:00Z"
            }
        }
        return obj
    }

    private static func sampleValue(
        for attr: SchemaAttribute,
        entityName: String,
        ordinal: Int,
        seed: UInt64
    ) -> Any {
        let hash = fnv1aHash("\(seed):\(entityName):\(attr.name):\(ordinal)")
        let lower = attr.name.lowercased()

        switch attr.fieldType {
        case .uuid:
            return deterministicUUIDString(seed: hash, label: attr.name)
        case .string(let maxLen):
            let raw: String
            if lower.contains("email") {
                raw = "member\(ordinal + 1)@chiefkit.io"
            } else if lower.contains("slug") || lower.contains("handle") {
                raw = "\(SchemaNamingHelpers.snakeCase(entityName).replacingOccurrences(of: "_", with: "-"))-\(ordinal + 1)"
            } else if lower.contains("currency") {
                raw = ["USD", "EUR", "GBP"][ordinal % 3]
            } else if lower.contains("uri") || lower.contains("url") {
                raw = "https://cdn.chiefkit.dev/docs/item-\(ordinal + 1).md"
            } else if lower.contains("code") || lower.contains("sku") || lower.contains("number") {
                raw = "\(entityName.prefix(3).uppercased())-\(1000 + ordinal)"
            } else {
                raw = "\(entityName) Sample #\(ordinal + 1)"
            }
            if let maxLen, raw.count > maxLen {
                return String(raw.prefix(maxLen))
            }
            return raw
        case .text:
            return "Structured \(entityName) narrative content #\(ordinal + 1) indexed for ChiefKit Studio."
        case .int64:
            return Int((hash % 900) + 10)
        case .double:
            let scaled = Double((hash % 9_500) + 125) / 100.0
            return (scaled * 100.0).rounded() / 100.0
        case .decimal(_, let scale):
            let whole = (hash % 480) + 19
            let frac = hash % 99
            if scale <= 0 { return "\(whole)" }
            return String(format: "%llu.%02llu", whole, frac)
        case .bool:
            return (ordinal % 2) == 0
        case .timestamp:
            return "2026-04-1\(min(9, ordinal + 1))T12:00:00Z"
        case .jsonBlob(let hint):
            return ["schema": hint ?? "metadata", "ordinal": ordinal + 1]
        case .enumCases(let cases):
            guard !cases.isEmpty else { return "default" }
            return cases[Int(hash % UInt64(cases.count))]
        case .vectorEmbedding(let dims):
            let previewDims = min(dims, 8)
            return (0..<previewDims).map { idx in
                let val = Double(((hash &+ UInt64(idx * 31)) % 200)) / 200.0 - 0.5
                return (val * 1000.0).rounded() / 1000.0
            }
        }
    }

    private static func matchPathTemplate(template: String, actualPath: String) -> [String: String]? {
        let tParts = template.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let aParts = actualPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard tParts.count == aParts.count else { return nil }

        var params: [String: String] = [:]
        for (tSeg, aSeg) in zip(tParts, aParts) {
            if tSeg.hasPrefix("{") && tSeg.hasSuffix("}") && tSeg.count > 2 {
                let key = String(tSeg.dropFirst().dropLast())
                params[key] = aSeg
            } else if tSeg != aSeg {
                return nil
            }
        }
        return params
    }

    private static func problemDetailsJSON(status: Int, title: String, detail: String, traceID: String) -> String {
        encodePrettyJSONObject([
            "type": "https://api.chiefkit.dev/problems/http-\(status)",
            "title": title,
            "status": status,
            "detail": detail,
            "trace_id": traceID
        ])
    }

    private static func encodePrettyJSONObject(_ obj: Any) -> String {
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    private static func fnv1aHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func deterministicUUIDString(seed: UInt64, label: String) -> String {
        let h1 = fnv1aHash("\(seed)-a-\(label)")
        let h2 = fnv1aHash("\(seed)-b-\(label)")
        let p1 = String(format: "%08x", UInt32(truncatingIfNeeded: h1 >> 32))
        let p2 = String(format: "%04x", UInt16(truncatingIfNeeded: h1 >> 16))
        let p3 = String(format: "4%03x", UInt16(truncatingIfNeeded: h1) & 0x0FFF)
        let p4 = String(format: "%04x", (UInt16(truncatingIfNeeded: h2 >> 48) & 0x3FFF) | 0x8000)
        let p5 = String(format: "%012llx", h2 & 0x0000_FFFF_FFFF_FFFF)
        return "\(p1)-\(p2)-\(p3)-\(p4)-\(p5)"
    }

    // MARK: - 4) Swift 6 URLSession Async/Await Typed Client + Retry Policy Generator

    public static func synthesizeSwiftURLSessionClient(_ service: APIServiceSpec) -> String {
        let prefix = SchemaNamingHelpers.pascalCase(service.schemaWorkspace.namespacePrefix.isEmpty ? "Studio" : service.schemaWorkspace.namespacePrefix)
        let clientName = "\(prefix)APIClient"

        var code: [String] = [
            "// Generated by ChiefKit Studio 3.0 — Swift 6 Typed URLSession Client",
            "// Service: \(service.title) (\(service.version))",
            "import Foundation",
            "#if canImport(FoundationNetworking)",
            "import FoundationNetworking",
            "#endif",
            "",
            "public enum \(prefix)APIClientError: Error, LocalizedError, Equatable, Sendable {",
            "    case invalidURL(String)",
            "    case unexpectedStatusCode(Int, body: String)",
            "    case rateLimitExceeded(retryAfterSeconds: Double?)",
            "    case decodingFailed(String)",
            "",
            "    public var errorDescription: String? {",
            "        switch self {",
            "        case .invalidURL(let path): return \"Invalid API URL path: \\(path)\"",
            "        case .unexpectedStatusCode(let code, let body): return \"HTTP \\(code): \\(body)\"",
            "        case .rateLimitExceeded(let retry): return \"HTTP 429 Rate Limit (retryAfter: \\(retry ?? 0)s)\"",
            "        case .decodingFailed(let detail): return \"Payload decode failure: \\(detail)\"",
            "        }",
            "    }",
            "}",
            "",
            "public struct ExponentialBackoffRetryPolicy: Codable, Hashable, Sendable {",
            "    public var maxAttempts: Int",
            "    public var baseDelaySeconds: Double",
            "    public var maxDelaySeconds: Double",
            "    public var jitterFraction: Double",
            "",
            "    public init(",
            "        maxAttempts: Int = 3,",
            "        baseDelaySeconds: Double = 0.35,",
            "        maxDelaySeconds: Double = 8.0,",
            "        jitterFraction: Double = 0.2",
            "    ) {",
            "        self.maxAttempts = max(1, maxAttempts)",
            "        self.baseDelaySeconds = max(0.05, baseDelaySeconds)",
            "        self.maxDelaySeconds = max(baseDelaySeconds, maxDelaySeconds)",
            "        self.jitterFraction = min(max(0, jitterFraction), 0.5)",
            "    }",
            "",
            "    public func delayNanoseconds(forAttempt attempt: Int, retryAfterHeader: Double? = nil) -> UInt64 {",
            "        if let retryAfterHeader, retryAfterHeader > 0 {",
            "            return UInt64(min(retryAfterHeader, maxDelaySeconds) * 1_000_000_000)",
            "        }",
            "        let exp = baseDelaySeconds * pow(2.0, Double(max(0, attempt - 1)))",
            "        let clamped = min(exp, maxDelaySeconds)",
            "        return UInt64(clamped * 1_000_000_000)",
            "    }",
            "}",
            "",
            "public struct PaginatedEnvelope<Item: Codable & Sendable>: Codable, Sendable {",
            "    public let items: [Item]",
            "    public let nextCursor: String?",
            "    public let hasMore: Bool",
            "}",
            ""
        ]

        // Emit lightweight DTOs for entities referenced by endpoints
        for entity in service.schemaWorkspace.entities {
            for attr in entity.attributes {
                if case .enumCases(let cases) = attr.fieldType {
                    let enumName = "\(entity.name)\(SchemaNamingHelpers.pascalCase(attr.name))"
                    code.append("public enum \(enumName): String, Codable, Sendable {")
                    for c in (cases.isEmpty ? ["unspecified"] : cases) {
                        code.append("    case \(SchemaNamingHelpers.camelCase(c)) = \"\(c)\"")
                    }
                    code.append("}")
                    code.append("")
                }
            }

            code.append("public struct \(entity.name)DTO: Codable, Hashable, Sendable {")
            for attr in entity.attributes {
                let prop = SchemaNamingHelpers.camelCase(attr.name)
                let swiftType = attr.fieldType.swiftTypeName(
                    entityName: entity.name,
                    attributeName: attr.name,
                    isOptional: attr.isNullable
                )
                code.append("    public var \(prop): \(swiftType)")
            }
            code.append("}")
            code.append("")
        }

        // Emit Actor Client
        code.append("public actor \(clientName) {")
        code.append("    public let baseURL: URL")
        code.append("    public let retryPolicy: ExponentialBackoffRetryPolicy")
        code.append("    private let session: URLSession")
        code.append("    private var bearerToken: String?")
        code.append("")
        code.append("    public init(")
        code.append("        baseURL: URL = URL(string: \"\(service.baseURL)\")!,")
        code.append("        session: URLSession = .shared,")
        code.append("        retryPolicy: ExponentialBackoffRetryPolicy = ExponentialBackoffRetryPolicy(),")
        code.append("        bearerToken: String? = nil")
        code.append("    ) {")
        code.append("        self.baseURL = baseURL")
        code.append("        self.session = session")
        code.append("        self.retryPolicy = retryPolicy")
        code.append("        self.bearerToken = bearerToken")
        code.append("    }")
        code.append("")
        code.append("    public func setBearerToken(_ token: String?) {")
        code.append("        self.bearerToken = token")
        code.append("    }")
        code.append("")
        code.append("    private func send<Response: Decodable & Sendable>(")
        code.append("        method: String,")
        code.append("        path: String,")
        code.append("        queryItems: [URLQueryItem] = [],")
        code.append("        bodyData: Data? = nil,")
        code.append("        isIdempotent: Bool")
        code.append("    ) async throws -> Response {")
        code.append("        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {")
        code.append("            throw \(prefix)APIClientError.invalidURL(path)")
        code.append("        }")
        code.append("        if !queryItems.isEmpty { components.queryItems = queryItems }")
        code.append("        guard let url = components.url else { throw \(prefix)APIClientError.invalidURL(path) }")
        code.append("")
        code.append("        var request = URLRequest(url: url)")
        code.append("        request.httpMethod = method")
        code.append("        request.setValue(\"application/json\", forHTTPHeaderField: \"Accept\")")
        code.append("        if let bodyData {")
        code.append("            request.httpBody = bodyData")
        code.append("            request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")")
        code.append("        }")
        code.append("        if let bearerToken {")
        code.append("            request.setValue(\"Bearer \\(bearerToken)\", forHTTPHeaderField: \"Authorization\")")
        code.append("        }")
        code.append("")
        code.append("        let maxTries = isIdempotent ? retryPolicy.maxAttempts : 1")
        code.append("        let decoder = JSONDecoder()")
        code.append("        decoder.keyDecodingStrategy = .convertFromSnakeCase")
        code.append("        decoder.dateDecodingStrategy = .iso8601")
        code.append("")
        code.append("        for attempt in 1...maxTries {")
        code.append("            let (data, response) = try await session.data(for: request)")
        code.append("            let status = (response as? HTTPURLResponse)?.statusCode ?? 200")
        code.append("            if (200..<300).contains(status) {")
        code.append("                return try decoder.decode(Response.self, from: data)")
        code.append("            }")
        code.append("            let retryable = (status == 429 || status == 502 || status == 503 || status == 504)")
        code.append("            if retryable && attempt < maxTries {")
        code.append("                let retryHeader = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: \"Retry-After\").flatMap(Double.init)")
        code.append("                try await Task.sleep(nanoseconds: retryPolicy.delayNanoseconds(forAttempt: attempt, retryAfterHeader: retryHeader))")
        code.append("                continue")
        code.append("            }")
        code.append("            if status == 429 {")
        code.append("                let retryHeader = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: \"Retry-After\").flatMap(Double.init)")
        code.append("                throw \(prefix)APIClientError.rateLimitExceeded(retryAfterSeconds: retryHeader)")
        code.append("            }")
        code.append("            throw \(prefix)APIClientError.unexpectedStatusCode(status, body: String(decoding: data, as: UTF8.self))")
        code.append("        }")
        code.append("        throw \(prefix)APIClientError.unexpectedStatusCode(500, body: \"Exhausted retries\")")
        code.append("    }")

        for ep in service.endpoints {
            code.append("")
            code.append(contentsOf: buildClientEndpointMethod(ep))
        }

        code.append("}")
        return code.joined(separator: "\n")
    }

    private static func buildClientEndpointMethod(_ ep: APIEndpointSpec) -> [String] {
        var params: [String] = []
        var queryLines: [String] = []
        var interpolatedPath = ep.pathTemplate

        for p in ep.parameters where p.location == .path {
            let argName = SchemaNamingHelpers.camelCase(p.name)
            params.append("\(argName): String")
            interpolatedPath = interpolatedPath.replacingOccurrences(of: "{\(p.name)}", with: "\\(\(argName))")
        }

        for p in ep.parameters where p.location == .query {
            let argName = SchemaNamingHelpers.camelCase(p.name)
            params.append("\(argName): String? = nil")
            queryLines.append("        if let \(argName) { queryItems.append(URLQueryItem(name: \"\(p.name)\", value: \(argName))) }")
        }

        if let reqEntity = ep.requestEntityName {
            params.append("payload: \(reqEntity)DTO")
        }

        let returnType: String
        if ep.successStatusCode == 204 || ep.responseEntityName == nil {
            returnType = "Void"
        } else if let respEntity = ep.responseEntityName {
            if ep.returnsCollection {
                returnType = ep.pagination.isPaginated ? "PaginatedEnvelope<\(respEntity)DTO>" : "[\(respEntity)DTO]"
            } else {
                returnType = "\(respEntity)DTO"
            }
        } else {
            returnType = "Void"
        }

        var methodLines: [String] = [
            "    /// \(ep.summary)",
            "    public func \(ep.operationID)(\(params.joined(separator: ", "))) async throws -> \(returnType) {"
        ]

        if !queryLines.isEmpty {
            methodLines.append("        var queryItems: [URLQueryItem] = []")
            methodLines.append(contentsOf: queryLines)
        }
        let queryArg = queryLines.isEmpty ? "[]" : "queryItems"

        let bodyArg: String
        if ep.requestEntityName != nil {
            methodLines.append("        let encoder = JSONEncoder()")
            methodLines.append("        encoder.keyEncodingStrategy = .convertToSnakeCase")
            methodLines.append("        let bodyData = try encoder.encode(payload)")
            bodyArg = "bodyData"
        } else {
            bodyArg = "nil"
        }

        if returnType == "Void" {
            methodLines.append("        struct EmptyAck: Decodable, Sendable {}")
            methodLines.append("        _ = try? await send(method: \"\(ep.method.rawValue)\", path: \"\(interpolatedPath)\", queryItems: \(queryArg), bodyData: \(bodyArg), isIdempotent: \(ep.isIdempotent)) as EmptyAck")
        } else {
            methodLines.append("        return try await send(method: \"\(ep.method.rawValue)\", path: \"\(interpolatedPath)\", queryItems: \(queryArg), bodyData: \(bodyArg), isIdempotent: \(ep.isIdempotent))")
        }
        methodLines.append("    }")
        return methodLines
    }
}
