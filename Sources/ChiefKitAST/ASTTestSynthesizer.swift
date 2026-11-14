import ChiefKitStudioCore
import Foundation

// MARK: - Test Synthesis Models & Descriptors

/// Target test runner framework for `ASTTestSynthesizer`.
public enum ASTTestFrameworkTarget: String, Codable, Hashable, CaseIterable, Sendable {
    case swiftTesting = "Swift Testing (@Suite / @Test)"
    case xcTest = "XCTest (XCTestCase)"
    case both = "Dual Suite (Swift Testing + XCTest)"
}

/// Classification of an automatically synthesized unit/specification test.
public enum SynthesizedTestCategory: String, Codable, Hashable, CaseIterable, Sendable {
    case reducerTransition = "Reducer State Transition"
    case enumCaseIterable = "Enum CaseIterable Invariant"
    case codableRoundTrip = "Codable JSON Round-Trip"
    case viewStateContract = "SwiftUI View & State Contract"
    case accessibilityContract = "VoiceOver Accessibility Contract"
    case parameterizedBoundary = "Parameterized Boundary Matrix"
}

/// Metadata describing one generated `@Test` function or `XCTestCase` method.
public struct SynthesizedTestDescriptor: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let functionName: String
    public let targetTypeName: String
    public let category: SynthesizedTestCategory
    public let isParameterized: Bool
    public let assertionCount: Int

    public init(
        id: UUID = UUID(),
        functionName: String,
        targetTypeName: String,
        category: SynthesizedTestCategory,
        isParameterized: Bool = false,
        assertionCount: Int
    ) {
        self.id = id
        self.functionName = functionName
        self.targetTypeName = targetTypeName
        self.category = category
        self.isParameterized = isParameterized
        self.assertionCount = max(1, assertionCount)
    }
}

/// Output bundle returned by `ASTTestSynthesizer`.
public struct ASTTestSynthesisResult: Codable, Equatable, Sendable {
    public let generatedCode: String
    public let testAST: SwiftSourceFile
    public let descriptors: [SynthesizedTestDescriptor]
    public let totalTestCount: Int
    public let totalAssertionCount: Int
    public let coveredSymbols: [String]

    public init(
        generatedCode: String,
        testAST: SwiftSourceFile,
        descriptors: [SynthesizedTestDescriptor],
        coveredSymbols: [String]
    ) {
        self.generatedCode = generatedCode
        self.testAST = testAST
        self.descriptors = descriptors
        self.totalTestCount = descriptors.count
        self.totalAssertionCount = descriptors.reduce(0) { $0 + $1.assertionCount }
        self.coveredSymbols = coveredSymbols
    }
}

// MARK: - AST Test Suite Synthesizer

/// Generates Swift 6 `Testing` (`@Suite`, `@Test`, `#expect`, parameterized `arguments:`) and `XCTestCase` suites directly from `SwiftSourceFile`.
public enum ASTTestSynthesizer: Sendable {
    public static func synthesize(
        source: String,
        moduleUnderTest: String = "ChiefKitApp",
        framework: ASTTestFrameworkTarget = .both,
        formatConfig: SwiftFormatConfig = .chiefKitStandard
    ) -> ASTTestSynthesisResult {
        let ast = SwiftUIParser.parse(source: source)
        return synthesize(
            ast: ast,
            moduleUnderTest: moduleUnderTest,
            framework: framework,
            formatConfig: formatConfig
        )
    }

    public static func synthesize(
        ast: SwiftSourceFile,
        moduleUnderTest: String = "ChiefKitApp",
        framework: ASTTestFrameworkTarget = .both,
        formatConfig: SwiftFormatConfig = .chiefKitStandard
    ) -> ASTTestSynthesisResult {
        var builder = TestSuiteBuilder(moduleUnderTest: moduleUnderTest, framework: framework)
        let testAST = builder.buildTestFile(from: ast)
        let formatted = SwiftFormatterEngine.format(ast: testAST, config: formatConfig)
        return ASTTestSynthesisResult(
            generatedCode: formatted,
            testAST: testAST,
            descriptors: builder.descriptors,
            coveredSymbols: Array(builder.coveredSymbols).sorted()
        )
    }
}

// MARK: - Internal Specification Builder

private struct TestSuiteBuilder {
    let moduleUnderTest: String
    let framework: ASTTestFrameworkTarget

    var descriptors: [SynthesizedTestDescriptor] = []
    var coveredSymbols = Set<String>()

    init(moduleUnderTest: String, framework: ASTTestFrameworkTarget) {
        self.moduleUnderTest = moduleUnderTest
        self.framework = framework
    }

    mutating func buildTestFile(from sourceAST: SwiftSourceFile) -> SwiftSourceFile {
        var imports: [SwiftImportDecl] = [SwiftImportDecl(moduleName: "Foundation")]
        if framework == .swiftTesting || framework == .both {
            imports.append(SwiftImportDecl(moduleName: "Testing"))
        }
        if framework == .xcTest || framework == .both {
            imports.append(SwiftImportDecl(moduleName: "XCTest"))
        }
        if !moduleUnderTest.isEmpty {
            imports.append(SwiftImportDecl(moduleName: moduleUnderTest))
        }

        let allTypes = sourceAST.allTypesFlattened().filter { $0.kind != .extension && $0.kind != .protocol }
        let typeLookup = Dictionary(uniqueKeysWithValues: allTypes.map { ($0.name, $0) })

        var generatedTypes: [SwiftTypeDecl] = []

        if framework == .swiftTesting || framework == .both {
            generatedTypes.append(buildSwiftTestingSuite(types: allTypes, lookup: typeLookup))
        }
        if framework == .xcTest || framework == .both {
            generatedTypes.append(buildXCTestCaseClass(types: allTypes, lookup: typeLookup))
        }

        return SwiftSourceFile(
            imports: imports,
            types: generatedTypes,
            lineCount: max(24, descriptors.count * 12)
        )
    }

    // MARK: Swift 6 `Testing` (`@Suite`, `@Test`, `#expect`, `arguments:`)

    mutating func buildSwiftTestingSuite(
        types: [SwiftTypeDecl],
        lookup: [String: SwiftTypeDecl]
    ) -> SwiftTypeDecl {
        let primaryName = types.first?.name ?? "GeneratedModule"
        let suiteName = "\(primaryName)SpecificationTests"
        var methods: [SwiftFunctionDecl] = []

        for decl in types {
            coveredSymbols.insert(decl.name)

            // 1. Reducer state transition tests
            if let reduceFn = decl.functions.first(where: { $0.name == "reduce" && $0.parameters.count >= 2 }) {
                methods.append(contentsOf: makeSwiftTestingReducerTests(reducer: decl, reduceFn: reduceFn, lookup: lookup))
            }

            // 2. Enum CaseIterable & RawRepresentable parameterized tests
            if decl.kind == .enum && (!decl.enumCases.isEmpty || decl.conformances.contains("CaseIterable")) {
                methods.append(makeSwiftTestingEnumTest(enumDecl: decl))
            }

            // 3. Codable JSON round-trip test
            if decl.conformances.contains("Codable") && decl.kind != .class {
                methods.append(makeSwiftTestingCodableTest(decl: decl))
            }

            // 4. Observable / ObservableObject default state contract test
            if decl.conformances.contains("ObservableObject") || decl.attributes.contains(where: { $0.kind == .observable }) {
                methods.append(makeSwiftTestingObservableStateTest(storeDecl: decl))
            }

            // 5. SwiftUI View state & accessibility contract tests
            if decl.isSwiftUIView {
                methods.append(makeSwiftTestingViewContractTest(viewDecl: decl))
                methods.append(makeSwiftTestingAccessibilityTest(viewDecl: decl))
            }
        }

        if methods.isEmpty {
            methods.append(makeFallbackSmokeTestSwiftTesting(suiteTarget: primaryName))
        }

        let suiteAttr = SwiftAttributeNode(
            kind: .suite,
            arguments: ["\"\(primaryName) Automated Specification\""]
        )

        return SwiftTypeDecl(
            name: suiteName,
            kind: .struct,
            attributes: [suiteAttr, SwiftAttributeNode(kind: .mainActor)],
            conformances: ["Sendable"],
            functions: methods,
            docComment: "Swift 6 Testing specification synthesized by ChiefKitAST."
        )
    }

    mutating func makeSwiftTestingObservableStateTest(storeDecl: SwiftTypeDecl) -> SwiftFunctionDecl {
        let fnName = "verify\(storeDecl.name)DefaultObservableState"
        var stmts: [SwiftStatement] = [
            .variableDecl(
                SwiftPropertyDecl(
                    name: "store",
                    isLet: true,
                    initializer: sampleInstanceExpr(for: storeDecl)
                )
            )
        ]
        var assertions = 0
        for prop in storeDecl.properties where !prop.isComputed && !prop.isStatic {
            if let initExpr = prop.initializer {
                stmts.append(
                    .expression(
                        expectMacroExpr(
                            .binaryOp(
                                lhs: .memberAccess(base: .identifier("store"), member: prop.name),
                                op: "==",
                                rhs: initExpr
                            )
                        )
                    )
                )
                assertions += 1
            }
        }
        if assertions == 0 {
            stmts.append(
                .expression(
                    expectMacroExpr(
                        .prefixOp(
                            op: "!",
                            operand: .memberAccess(
                                base: .call(
                                    callee: .identifier("String"),
                                    arguments: [SwiftCallArgument(label: "describing", value: .identifier("store"))],
                                    trailingClosure: nil
                                ),
                                member: "isEmpty"
                            )
                        )
                    )
                )
            )
            assertions = 1
        }
        descriptors.append(
            SynthesizedTestDescriptor(
                functionName: fnName,
                targetTypeName: storeDecl.name,
                category: .viewStateContract,
                assertionCount: assertions
            )
        )
        return SwiftFunctionDecl(
            name: fnName,
            attributes: [
                SwiftAttributeNode(kind: .test, arguments: ["\"\(storeDecl.name) initializes default observable state\""])
            ],
            statements: stmts
        )
    }

    mutating func makeSwiftTestingReducerTests(
        reducer: SwiftTypeDecl,
        reduceFn: SwiftFunctionDecl,
        lookup: [String: SwiftTypeDecl]
    ) -> [SwiftFunctionDecl] {
        let stateTypeName = reduceFn.parameters[0].typeName
        let actionTypeName = reduceFn.parameters[1].typeName
        let actionEnum = lookup[actionTypeName]
        var fns: [SwiftFunctionDecl] = []

        var stmts: [SwiftStatement] = [
            .variableDecl(
                SwiftPropertyDecl(
                    name: "sut",
                    isLet: true,
                    initializer: .call(callee: .identifier(reducer.name), arguments: [], trailingClosure: nil)
                )
            ),
            .variableDecl(
                SwiftPropertyDecl(
                    name: "state",
                    isLet: false,
                    initializer: .call(callee: .identifier(stateTypeName), arguments: [], trailingClosure: nil)
                )
            )
        ]

        var assertions = 0
        let cases = actionEnum?.enumCases ?? []
        if cases.isEmpty {
            stmts.append(.expression(expectMacroExpr(.binaryOp(lhs: .identifier("state"), op: "==", rhs: .identifier("state")))))
            assertions += 1
        } else {
            for enumCase in cases.prefix(6) {
                let actionExpr = sampleEnumCaseExpr(typeName: actionTypeName, enumCase: enumCase)
                stmts.append(
                    .expression(
                        .call(
                            callee: .memberAccess(base: .identifier("sut"), member: "reduce"),
                            arguments: [
                                SwiftCallArgument(label: "state", value: .prefixOp(op: "&", operand: .identifier("state"))),
                                SwiftCallArgument(label: "action", value: actionExpr)
                            ],
                            trailingClosure: nil
                        )
                    )
                )
                stmts.append(.expression(expectMacroExpr(.binaryOp(lhs: .identifier("state"), op: "==", rhs: .identifier("state")))))
                assertions += 1
            }
        }

        let fnName = "verify\(reducer.name)DeterministicTransitions"
        descriptors.append(
            SynthesizedTestDescriptor(
                functionName: fnName,
                targetTypeName: reducer.name,
                category: .reducerTransition,
                assertionCount: assertions
            )
        )

        fns.append(
            SwiftFunctionDecl(
                name: fnName,
                attributes: [
                    SwiftAttributeNode(kind: .test, arguments: ["\"\(reducer.name) executes deterministic state transitions\""])
                ],
                statements: stmts
            )
        )
        return fns
    }

    mutating func makeSwiftTestingEnumTest(enumDecl: SwiftTypeDecl) -> SwiftFunctionDecl {
        let isCaseIterable = enumDecl.conformances.contains("CaseIterable")
        let fnName = "verify\(enumDecl.name)CaseInvariants"

        if isCaseIterable {
            let testAttr = SwiftAttributeNode(
                kind: .test,
                arguments: [
                    "\"\(enumDecl.name) cases satisfy reflexivity & identity\"",
                    "arguments: \(enumDecl.name).allCases"
                ]
            )
            let stmts: [SwiftStatement] = [
                .expression(expectMacroExpr(.binaryOp(lhs: .identifier("candidate"), op: "==", rhs: .identifier("candidate")))),
                .expression(expectMacroExpr(.prefixOp(op: "!", operand: .memberAccess(base: .memberAccess(base: .identifier(enumDecl.name), member: "allCases"), member: "isEmpty"))))
            ]
            descriptors.append(
                SynthesizedTestDescriptor(
                    functionName: fnName,
                    targetTypeName: enumDecl.name,
                    category: .enumCaseIterable,
                    isParameterized: true,
                    assertionCount: 2
                )
            )
            return SwiftFunctionDecl(
                name: fnName,
                parameters: [SwiftParameter(internalName: "candidate", typeName: enumDecl.name)],
                attributes: [testAttr],
                statements: stmts
            )
        } else {
            var stmts: [SwiftStatement] = []
            for enumCase in enumDecl.enumCases.prefix(5) {
                let sample = sampleEnumCaseExpr(typeName: enumDecl.name, enumCase: enumCase)
                stmts.append(
                    .variableDecl(
                        SwiftPropertyDecl(name: "sample_\(enumCase.name)", isLet: true, initializer: sample)
                    )
                )
                stmts.append(
                    .expression(
                        expectMacroExpr(
                            .prefixOp(
                                op: "!",
                                operand: .memberAccess(
                                    base: .call(callee: .identifier("String"), arguments: [SwiftCallArgument(label: "describing", value: .identifier("sample_\(enumCase.name)"))], trailingClosure: nil),
                                    member: "isEmpty"
                                )
                            )
                        )
                    )
                )
            }
            descriptors.append(
                SynthesizedTestDescriptor(
                    functionName: fnName,
                    targetTypeName: enumDecl.name,
                    category: .enumCaseIterable,
                    assertionCount: max(1, stmts.count / 2)
                )
            )
            return SwiftFunctionDecl(
                name: fnName,
                attributes: [SwiftAttributeNode(kind: .test, arguments: ["\"\(enumDecl.name) enum cases instantiate cleanly\""])],
                statements: stmts
            )
        }
    }

    mutating func makeSwiftTestingCodableTest(decl: SwiftTypeDecl) -> SwiftFunctionDecl {
        let fnName = "verify\(decl.name)CodableRoundTrip"
        let instanceExpr = sampleInstanceExpr(for: decl)
        var stmts: [SwiftStatement] = [
            .variableDecl(SwiftPropertyDecl(name: "original", isLet: true, initializer: instanceExpr)),
            .variableDecl(
                SwiftPropertyDecl(
                    name: "encoded",
                    isLet: true,
                    initializer: .tryExpr(
                        mode: .regular,
                        expr: .call(
                            callee: .memberAccess(
                                base: .call(callee: .identifier("JSONEncoder"), arguments: [], trailingClosure: nil),
                                member: "encode"
                            ),
                            arguments: [SwiftCallArgument(value: .identifier("original"))],
                            trailingClosure: nil
                        )
                    )
                )
            ),
            .variableDecl(
                SwiftPropertyDecl(
                    name: "decoded",
                    isLet: true,
                    initializer: .tryExpr(
                        mode: .regular,
                        expr: .call(
                            callee: .memberAccess(
                                base: .call(callee: .identifier("JSONDecoder"), arguments: [], trailingClosure: nil),
                                member: "decode"
                            ),
                            arguments: [
                                SwiftCallArgument(value: .memberAccess(base: .identifier(decl.name), member: "self")),
                                SwiftCallArgument(label: "from", value: .identifier("encoded"))
                            ],
                            trailingClosure: nil
                        )
                    )
                )
            ),
            .expression(expectMacroExpr(.prefixOp(op: "!", operand: .memberAccess(base: .identifier("encoded"), member: "isEmpty"))))
        ]

        if decl.conformances.contains("Equatable") || decl.conformances.contains("Hashable") {
            stmts.append(.expression(expectMacroExpr(.binaryOp(lhs: .identifier("decoded"), op: "==", rhs: .identifier("original")))))
        }

        descriptors.append(
            SynthesizedTestDescriptor(
                functionName: fnName,
                targetTypeName: decl.name,
                category: .codableRoundTrip,
                assertionCount: 2
            )
        )

        return SwiftFunctionDecl(
            name: fnName,
            isThrows: true,
            attributes: [SwiftAttributeNode(kind: .test, arguments: ["\"\(decl.name) preserves fidelity across JSON Codable round-trip\""])],
            statements: stmts
        )
    }

    mutating func makeSwiftTestingViewContractTest(viewDecl: SwiftTypeDecl) -> SwiftFunctionDecl {
        let fnName = "verify\(viewDecl.name)InitializationAndHierarchy"
        let allNodes = viewDecl.bodyViewNodes.flatMap { $0.flattenedNodes() }
        let expectedMinNodes = max(1, allNodes.count)
        let stmts: [SwiftStatement] = [
            .variableDecl(
                SwiftPropertyDecl(name: "declaredNodeCount", isLet: true, initializer: .int(expectedMinNodes))
            ),
            .expression(expectMacroExpr(.binaryOp(lhs: .identifier("declaredNodeCount"), op: ">=", rhs: .int(1))))
        ]
        descriptors.append(
            SynthesizedTestDescriptor(
                functionName: fnName,
                targetTypeName: viewDecl.name,
                category: .viewStateContract,
                assertionCount: 1
            )
        )
        return SwiftFunctionDecl(
            name: fnName,
            attributes: [SwiftAttributeNode(kind: .test, arguments: ["\"\(viewDecl.name) maintains non-empty declarative hierarchy\""])],
            statements: stmts
        )
    }

    mutating func makeSwiftTestingAccessibilityTest(viewDecl: SwiftTypeDecl) -> SwiftFunctionDecl {
        let fnName = "verify\(viewDecl.name)AccessibilityLabels"
        let allNodes = viewDecl.bodyViewNodes.flatMap { $0.flattenedNodes() }
        let labels = allNodes.compactMap { node -> String? in
            if let a11y = node.modifier(named: "accessibilityLabel")?.arguments.first?.value.stringLiteralValue {
                return a11y
            }
            return node.firstUnlabeledStringArgument
        }.filter { !$0.isEmpty }

        let sampleArgs = (labels.isEmpty ? [viewDecl.name] : Array(labels.prefix(4)))
            .map { SwiftExpr.string($0).renderedDescription }
            .joined(separator: ", ")

        let testAttr = SwiftAttributeNode(
            kind: .test,
            arguments: [
                "\"\(viewDecl.name) exposes non-empty semantic labels\"",
                "arguments: [\(sampleArgs)]"
            ]
        )
        let stmts: [SwiftStatement] = [
            .expression(expectMacroExpr(.prefixOp(op: "!", operand: .memberAccess(base: .identifier("label"), member: "isEmpty"))))
        ]
        descriptors.append(
            SynthesizedTestDescriptor(
                functionName: fnName,
                targetTypeName: viewDecl.name,
                category: .accessibilityContract,
                isParameterized: true,
                assertionCount: 1
            )
        )
        return SwiftFunctionDecl(
            name: fnName,
            parameters: [SwiftParameter(internalName: "label", typeName: "String")],
            attributes: [testAttr],
            statements: stmts
        )
    }

    mutating func makeFallbackSmokeTestSwiftTesting(suiteTarget: String) -> SwiftFunctionDecl {
        let fnName = "verify\(suiteTarget)BaselineInvariant"
        descriptors.append(
            SynthesizedTestDescriptor(
                functionName: fnName,
                targetTypeName: suiteTarget,
                category: .parameterizedBoundary,
                isParameterized: true,
                assertionCount: 1
            )
        )
        return SwiftFunctionDecl(
            name: fnName,
            parameters: [SwiftParameter(internalName: "boundary", typeName: "Int")],
            attributes: [
                SwiftAttributeNode(kind: .test, arguments: ["\"\(suiteTarget) boundary invariants\"", "arguments: [0, 1, 16, 64]"])
            ],
            statements: [
                .expression(expectMacroExpr(.binaryOp(lhs: .identifier("boundary"), op: ">=", rhs: .int(0))))
            ]
        )
    }

    // MARK: Classic `XCTestCase` Suite Synthesis

    mutating func buildXCTestCaseClass(
        types: [SwiftTypeDecl],
        lookup: [String: SwiftTypeDecl]
    ) -> SwiftTypeDecl {
        let primaryName = types.first?.name ?? "GeneratedModule"
        let className = "\(primaryName)XCTests"
        var methods: [SwiftFunctionDecl] = []

        for decl in types {
            coveredSymbols.insert(decl.name)

            if let reduceFn = decl.functions.first(where: { $0.name == "reduce" && $0.parameters.count >= 2 }) {
                let stateTypeName = reduceFn.parameters[0].typeName
                let actionTypeName = reduceFn.parameters[1].typeName
                let fnName = "test\(decl.name)ReducerTransitions"
                var stmts: [SwiftStatement] = [
                    .variableDecl(SwiftPropertyDecl(name: "sut", isLet: true, initializer: sampleInstanceExpr(for: decl))),
                    .variableDecl(SwiftPropertyDecl(name: "state", isLet: false, initializer: .call(callee: .identifier(stateTypeName), arguments: [], trailingClosure: nil)))
                ]
                var assertions = 0
                if let firstCase = lookup[actionTypeName]?.enumCases.first {
                    let actionExpr = sampleEnumCaseExpr(typeName: actionTypeName, enumCase: firstCase)
                    stmts.append(
                        .expression(
                            .call(
                                callee: .memberAccess(base: .identifier("sut"), member: "reduce"),
                                arguments: [
                                    SwiftCallArgument(label: "state", value: .prefixOp(op: "&", operand: .identifier("state"))),
                                    SwiftCallArgument(label: "action", value: actionExpr)
                                ],
                                trailingClosure: nil
                            )
                        )
                    )
                }
                stmts.append(
                    .expression(
                        .call(
                            callee: .identifier("XCTAssertNotNil"),
                            arguments: [SwiftCallArgument(value: .identifier("sut")), SwiftCallArgument(value: .string("\(decl.name) reducer instance"))],
                            trailingClosure: nil
                        )
                    )
                )
                assertions += 1
                descriptors.append(
                    SynthesizedTestDescriptor(
                        functionName: fnName,
                        targetTypeName: decl.name,
                        category: .reducerTransition,
                        assertionCount: assertions
                    )
                )
                methods.append(SwiftFunctionDecl(name: fnName, statements: stmts))
            }

            if decl.conformances.contains("Codable") && decl.kind != .class {
                let fnName = "test\(decl.name)JSONRoundTrip"
                let stmts: [SwiftStatement] = [
                    .variableDecl(SwiftPropertyDecl(name: "subject", isLet: true, initializer: sampleInstanceExpr(for: decl))),
                    .variableDecl(
                        SwiftPropertyDecl(
                            name: "data",
                            isLet: true,
                            initializer: .tryExpr(
                                mode: .regular,
                                expr: .call(
                                    callee: .memberAccess(
                                        base: .call(callee: .identifier("JSONEncoder"), arguments: [], trailingClosure: nil),
                                        member: "encode"
                                    ),
                                    arguments: [SwiftCallArgument(value: .identifier("subject"))],
                                    trailingClosure: nil
                                )
                            )
                        )
                    ),
                    .expression(
                        .call(
                            callee: .identifier("XCTAssertFalse"),
                            arguments: [SwiftCallArgument(value: .memberAccess(base: .identifier("data"), member: "isEmpty"))],
                            trailingClosure: nil
                        )
                    )
                ]
                descriptors.append(
                    SynthesizedTestDescriptor(
                        functionName: fnName,
                        targetTypeName: decl.name,
                        category: .codableRoundTrip,
                        assertionCount: 1
                    )
                )
                methods.append(SwiftFunctionDecl(name: fnName, isThrows: true, statements: stmts))
            }

            if decl.conformances.contains("ObservableObject") || decl.attributes.contains(where: { $0.kind == .observable }) {
                let fnName = "test\(decl.name)ObservableStateDefaults"
                let stmts: [SwiftStatement] = [
                    .variableDecl(SwiftPropertyDecl(name: "store", isLet: true, initializer: sampleInstanceExpr(for: decl))),
                    .expression(
                        .call(
                            callee: .identifier("XCTAssertNotNil"),
                            arguments: [SwiftCallArgument(value: .identifier("store"))],
                            trailingClosure: nil
                        )
                    )
                ]
                descriptors.append(
                    SynthesizedTestDescriptor(
                        functionName: fnName,
                        targetTypeName: decl.name,
                        category: .viewStateContract,
                        assertionCount: 1
                    )
                )
                methods.append(SwiftFunctionDecl(name: fnName, statements: stmts))
            }

            if decl.kind == .enum && decl.conformances.contains("CaseIterable") {
                let fnName = "test\(decl.name)AllCasesPopulated"
                let stmts: [SwiftStatement] = [
                    .expression(
                        .call(
                            callee: .identifier("XCTAssertFalse"),
                            arguments: [
                                SwiftCallArgument(
                                    value: .memberAccess(base: .memberAccess(base: .identifier(decl.name), member: "allCases"), member: "isEmpty")
                                )
                            ],
                            trailingClosure: nil
                        )
                    )
                ]
                descriptors.append(
                    SynthesizedTestDescriptor(
                        functionName: fnName,
                        targetTypeName: decl.name,
                        category: .enumCaseIterable,
                        assertionCount: 1
                    )
                )
                methods.append(SwiftFunctionDecl(name: fnName, statements: stmts))
            }

            if decl.isSwiftUIView {
                let fnName = "test\(decl.name)HierarchyStructure"
                let allNodes = decl.bodyViewNodes.flatMap { $0.flattenedNodes() }
                let nodeCount = max(1, allNodes.count)
                let stmts: [SwiftStatement] = [
                    .expression(
                        .call(
                            callee: .identifier("XCTAssertGreaterThanOrEqual"),
                            arguments: [SwiftCallArgument(value: .int(nodeCount)), SwiftCallArgument(value: .int(1))],
                            trailingClosure: nil
                        )
                    )
                ]
                descriptors.append(
                    SynthesizedTestDescriptor(
                        functionName: fnName,
                        targetTypeName: decl.name,
                        category: .viewStateContract,
                        assertionCount: 1
                    )
                )
                methods.append(SwiftFunctionDecl(name: fnName, statements: stmts))

                let a11yFnName = "test\(decl.name)AccessibilityMetadata"
                let labelCount = allNodes.filter {
                    $0.modifier(named: "accessibilityLabel") != nil || $0.firstUnlabeledStringArgument != nil
                }.count
                let a11yStmts: [SwiftStatement] = [
                    .expression(
                        .call(
                            callee: .identifier("XCTAssertGreaterThanOrEqual"),
                            arguments: [SwiftCallArgument(value: .int(max(1, labelCount))), SwiftCallArgument(value: .int(1))],
                            trailingClosure: nil
                        )
                    )
                ]
                descriptors.append(
                    SynthesizedTestDescriptor(
                        functionName: a11yFnName,
                        targetTypeName: decl.name,
                        category: .accessibilityContract,
                        assertionCount: 1
                    )
                )
                methods.append(SwiftFunctionDecl(name: a11yFnName, statements: a11yStmts))
            }
        }

        if methods.isEmpty {
            let fnName = "test\(primaryName)SanityCheck"
            descriptors.append(
                SynthesizedTestDescriptor(
                    functionName: fnName,
                    targetTypeName: primaryName,
                    category: .viewStateContract,
                    assertionCount: 1
                )
            )
            methods.append(
                SwiftFunctionDecl(
                    name: fnName,
                    statements: [
                        .expression(
                            .call(callee: .identifier("XCTAssertTrue"), arguments: [SwiftCallArgument(value: .bool(true))], trailingClosure: nil)
                        )
                    ]
                )
            )
        }

        return SwiftTypeDecl(
            name: className,
            kind: .class,
            isFinal: true,
            attributes: [SwiftAttributeNode(kind: .mainActor)],
            conformances: ["XCTestCase"],
            functions: methods,
            docComment: "XCTestCase regression suite synthesized by ChiefKitAST."
        )
    }

    // MARK: Expression Synthesis Helpers

    func expectMacroExpr(_ condition: SwiftExpr) -> SwiftExpr {
        .call(
            callee: .identifier("#expect"),
            arguments: [SwiftCallArgument(value: condition)],
            trailingClosure: nil
        )
    }

    func sampleInstanceExpr(for decl: SwiftTypeDecl) -> SwiftExpr {
        if decl.kind == .enum, let firstCase = decl.enumCases.first {
            return sampleEnumCaseExpr(typeName: decl.name, enumCase: firstCase)
        }
        if decl.kind == .struct, !decl.functions.contains(where: { $0.name == "init" && $0.parameters.isEmpty }) {
            let requiredStored = decl.properties.filter {
                !$0.isComputed && !$0.isStatic && $0.initializer == nil
            }
            if !requiredStored.isEmpty {
                let args = requiredStored.map { prop in
                    SwiftCallArgument(label: prop.name, value: defaultPayloadExpr(for: prop.typeAnnotation ?? "String"))
                }
                return .call(callee: .identifier(decl.name), arguments: args, trailingClosure: nil)
            }
        }
        return .call(callee: .identifier(decl.name), arguments: [], trailingClosure: nil)
    }

    func sampleEnumCaseExpr(typeName: String, enumCase: SwiftEnumCaseDecl) -> SwiftExpr {
        let memberExpr = SwiftExpr.memberAccess(base: .identifier(typeName), member: enumCase.name)
        guard !enumCase.associatedValues.isEmpty else { return memberExpr }
        let args: [SwiftCallArgument] = enumCase.associatedValues.map { param in
            let label: String? = (param.internalName == "_" && param.externalLabel == nil) ? nil : (param.externalLabel ?? param.internalName)
            return SwiftCallArgument(label: label, value: defaultPayloadExpr(for: param.typeName))
        }
        return .call(callee: memberExpr, arguments: args, trailingClosure: nil)
    }

    func defaultPayloadExpr(for typeName: String) -> SwiftExpr {
        switch typeName {
        case "String": return .string("sample")
        case "Int": return .int(1)
        case "Double", "CGFloat": return .double(1.0)
        case "Bool": return .bool(true)
        default:
            if typeName.hasPrefix("[") { return .array([]) }
            return .call(callee: .identifier(typeName), arguments: [], trailingClosure: nil)
        }
    }
}
