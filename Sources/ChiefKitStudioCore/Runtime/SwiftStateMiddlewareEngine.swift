import Foundation

// MARK: - Action, Effect, Reducer & Middleware Primitives

public protocol StudioActionProtocol: Sendable {
    var actionName: String { get }
    var rateLimitKey: String? { get }
}

public extension StudioActionProtocol {
    var actionName: String { String(describing: self) }
    var rateLimitKey: String? { nil }
}

public struct StudioEffect<Action: Sendable>: Sendable {
    public enum OperationKind: Sendable {
        case none
        case immediate(Action)
        case asyncTask(id: String?, priority: TaskPriority?, work: @Sendable () async -> Action?)
        case cancel(id: String)
        case batch([StudioEffect<Action>], sequential: Bool)
    }

    public let operation: OperationKind

    public init(operation: OperationKind) {
        self.operation = operation
    }

    public static var none: StudioEffect<Action> {
        StudioEffect(operation: .none)
    }

    public static func send(_ action: Action) -> StudioEffect<Action> {
        StudioEffect(operation: .immediate(action))
    }

    public static func run(
        id: String? = nil,
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async -> Action?
    ) -> StudioEffect<Action> {
        StudioEffect(operation: .asyncTask(id: id, priority: priority, work: operation))
    }

    public static func cancel(id: String) -> StudioEffect<Action> {
        StudioEffect(operation: .cancel(id: id))
    }

    public static func merge(_ effects: [StudioEffect<Action>]) -> StudioEffect<Action> {
        StudioEffect(operation: .batch(effects, sequential: false))
    }

    public static func sequence(_ effects: [StudioEffect<Action>]) -> StudioEffect<Action> {
        StudioEffect(operation: .batch(effects, sequential: true))
    }

    public var isNone: Bool {
        if case .none = operation { return true }
        return false
    }

    public var leafEffectCount: Int {
        switch operation {
        case .none: return 0
        case .immediate, .asyncTask, .cancel: return 1
        case .batch(let children, _): return children.reduce(0) { $0 + $1.leafEffectCount }
        }
    }
}

public struct StudioReducer<State: Sendable, Action: Sendable>: Sendable {
    private let reduceClosure: @Sendable (inout State, Action) -> StudioEffect<Action>

    public init(_ reduce: @escaping @Sendable (inout State, Action) -> StudioEffect<Action>) {
        self.reduceClosure = reduce
    }

    public func reduce(state: inout State, action: Action) -> StudioEffect<Action> {
        reduceClosure(&state, action)
    }

    public static func combine(_ reducers: [StudioReducer<State, Action>]) -> StudioReducer<State, Action> {
        StudioReducer { state, action in
            var effects: [StudioEffect<Action>] = []
            for r in reducers {
                let eff = r.reduce(state: &state, action: action)
                if !eff.isNone {
                    effects.append(eff)
                }
            }
            if effects.isEmpty { return .none }
            if effects.count == 1 { return effects[0] }
            return .merge(effects)
        }
    }
}

public struct StudioMiddlewareContext: Codable, Hashable, Sendable {
    public var storeName: String
    public var dispatchSequenceNumber: Int
    public var activeBranch: String
    public var timestampEpochMs: Int64

    public init(
        storeName: String,
        dispatchSequenceNumber: Int,
        activeBranch: String,
        timestampEpochMs: Int64
    ) {
        self.storeName = storeName
        self.dispatchSequenceNumber = dispatchSequenceNumber
        self.activeBranch = activeBranch
        self.timestampEpochMs = timestampEpochMs
    }
}

public enum StudioMiddlewareDisposition<Action: Sendable>: Sendable {
    case proceed(Action)
    case drop(reason: String)
    case rewrite(Action, sideEffect: StudioEffect<Action>)
}

public struct StudioMiddleware<State: Sendable, Action: Sendable>: Sendable {
    public let name: String
    private let handler: @Sendable (State, Action, StudioMiddlewareContext) -> StudioMiddlewareDisposition<Action>

    public init(
        name: String,
        intercept: @escaping @Sendable (State, Action, StudioMiddlewareContext) -> StudioMiddlewareDisposition<Action>
    ) {
        self.name = name
        self.handler = intercept
    }

    public func evaluate(
        state: State,
        action: Action,
        context: StudioMiddlewareContext
    ) -> StudioMiddlewareDisposition<Action> {
        handler(state, action, context)
    }

    public static func guardPredicate(
        name: String,
        reasonWhenBlocked: String,
        allow: @escaping @Sendable (State, Action) -> Bool
    ) -> StudioMiddleware<State, Action> {
        StudioMiddleware(name: name) { state, action, _ in
            allow(state, action) ? .proceed(action) : .drop(reason: reasonWhenBlocked)
        }
    }
}

// MARK: - Causal State History DAG (Branches, Checkpoints, Time-Travel & JSON Diffing)

public struct CausalCommitNode<State: Codable & Equatable & Sendable>: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var parentCommitID: String?
    public var branchName: String
    public var actionName: String
    public var timestampEpochMs: Int64
    public var checkpointTag: String?
    public var state: State

    public init(
        id: String,
        parentCommitID: String?,
        branchName: String,
        actionName: String,
        timestampEpochMs: Int64,
        checkpointTag: String? = nil,
        state: State
    ) {
        self.id = id
        self.parentCommitID = parentCommitID
        self.branchName = branchName
        self.actionName = actionName
        self.timestampEpochMs = timestampEpochMs
        self.checkpointTag = checkpointTag
        self.state = state
    }
}

public struct StateJSONFieldDiff: Identifiable, Codable, Hashable, Sendable {
    public var id: String { jsonPath }
    public var jsonPath: String
    public var beforeValue: String
    public var afterValue: String

    public init(jsonPath: String, beforeValue: String, afterValue: String) {
        self.jsonPath = jsonPath
        self.beforeValue = beforeValue
        self.afterValue = afterValue
    }
}

public struct CausalStateDAG<State: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public private(set) var commits: [String: CausalCommitNode<State>]
    public private(set) var branchHeads: [String: String]
    public private(set) var checkpoints: [String: String]
    public private(set) var activeBranch: String
    public private(set) var headCommitID: String
    private var nextSequence: Int

    public init(initialState: State, initialBranch: String = "main", timestampEpochMs: Int64 = 1_760_000_000_000) {
        let rootID = "c0000"
        let rootNode = CausalCommitNode(
            id: rootID,
            parentCommitID: nil,
            branchName: initialBranch,
            actionName: "<init>",
            timestampEpochMs: timestampEpochMs,
            checkpointTag: "genesis",
            state: initialState
        )
        self.commits = [rootID: rootNode]
        self.branchHeads = [initialBranch: rootID]
        self.checkpoints = ["genesis": rootID]
        self.activeBranch = initialBranch
        self.headCommitID = rootID
        self.nextSequence = 1
    }

    public var currentState: State {
        commits[headCommitID]!.state
    }

    @discardableResult
    public mutating func appendCommit(
        actionName: String,
        state: State,
        timestampEpochMs: Int64
    ) -> CausalCommitNode<State> {
        let newID = String(format: "c%04d", nextSequence)
        nextSequence += 1
        let node = CausalCommitNode(
            id: newID,
            parentCommitID: headCommitID,
            branchName: activeBranch,
            actionName: actionName,
            timestampEpochMs: timestampEpochMs,
            state: state
        )
        commits[newID] = node
        headCommitID = newID
        branchHeads[activeBranch] = newID
        return node
    }

    @discardableResult
    public mutating func createBranch(named branch: String, fromCommitID sourceID: String? = nil) -> Bool {
        let clean = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, branchHeads[clean] == nil else { return false }
        let anchor = sourceID ?? headCommitID
        guard commits[anchor] != nil else { return false }
        branchHeads[clean] = anchor
        activeBranch = clean
        headCommitID = anchor
        return true
    }

    public mutating func switchBranch(to branch: String) -> State? {
        guard let targetHead = branchHeads[branch], let node = commits[targetHead] else { return nil }
        activeBranch = branch
        headCommitID = targetHead
        return node.state
    }

    public mutating func tagCheckpoint(_ tag: String, commitID: String? = nil) {
        let target = commitID ?? headCommitID
        guard var node = commits[target] else { return }
        node.checkpointTag = tag
        commits[target] = node
        checkpoints[tag] = target
    }

    public mutating func timeTravelJump(toCommitID targetID: String) -> State? {
        guard let node = commits[targetID] else { return nil }
        headCommitID = targetID
        branchHeads[activeBranch] = targetID
        return node.state
    }

    public mutating func jumpToCheckpoint(_ tag: String) -> State? {
        guard let cid = checkpoints[tag] else { return nil }
        return timeTravelJump(toCommitID: cid)
    }

    public func ancestryLineage(fromCommitID startID: String? = nil) -> [CausalCommitNode<State>] {
        var chain: [CausalCommitNode<State>] = []
        var cursor: String? = startID ?? headCommitID
        var safety = 0
        while let current = cursor, let node = commits[current], safety < 10_000 {
            chain.append(node)
            cursor = node.parentCommitID
            safety += 1
        }
        return chain.reversed()
    }

    /// Replays a selected list of historical actions onto `baseCommitID` on a new or current branch.
    public mutating func cherryPickReplay<Action: StudioActionProtocol>(
        actionsToReplay: [Action],
        ontoCommitID baseCommitID: String,
        newBranchName: String? = nil,
        reducer: StudioReducer<State, Action>,
        timestampEpochMs: Int64
    ) -> State? {
        guard let baseNode = commits[baseCommitID] else { return nil }
        if let newBranchName {
            _ = createBranch(named: newBranchName, fromCommitID: baseCommitID)
        } else {
            headCommitID = baseCommitID
            branchHeads[activeBranch] = baseCommitID
        }

        var workingState = baseNode.state
        for (offset, act) in actionsToReplay.enumerated() {
            _ = reducer.reduce(state: &workingState, action: act)
            _ = appendCommit(
                actionName: "cherry-pick:\(act.actionName)",
                state: workingState,
                timestampEpochMs: timestampEpochMs + Int64(offset + 1)
            )
        }
        return workingState
    }

    /// Computes structured field-level JSON diffs between any two commits in the DAG.
    public func diffStatesJSON(fromCommitID leftID: String, toCommitID rightID: String) -> [StateJSONFieldDiff] {
        guard let leftState = commits[leftID]?.state,
              let rightState = commits[rightID]?.state else { return [] }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let leftData = try? encoder.encode(leftState),
              let rightData = try? encoder.encode(rightState),
              let leftObj = try? JSONSerialization.jsonObject(with: leftData),
              let rightObj = try? JSONSerialization.jsonObject(with: rightData) else {
            return []
        }
        var diffs: [StateJSONFieldDiff] = []
        Self.collectJSONDiffs(path: "$", left: leftObj, right: rightObj, into: &diffs)
        return diffs.sorted { $0.jsonPath < $1.jsonPath }
    }

    private static func collectJSONDiffs(
        path: String,
        left: Any,
        right: Any,
        into diffs: inout [StateJSONFieldDiff]
    ) {
        if let lDict = left as? [String: Any], let rDict = right as? [String: Any] {
            let allKeys = Set(lDict.keys).union(rDict.keys).sorted()
            for key in allKeys {
                let childPath = "\(path).\(key)"
                switch (lDict[key], rDict[key]) {
                case (nil, let rVal?):
                    diffs.append(StateJSONFieldDiff(jsonPath: childPath, beforeValue: "<absent>", afterValue: stringifyJSONLeaf(rVal)))
                case (let lVal?, nil):
                    diffs.append(StateJSONFieldDiff(jsonPath: childPath, beforeValue: stringifyJSONLeaf(lVal), afterValue: "<removed>"))
                case (let lVal?, let rVal?):
                    collectJSONDiffs(path: childPath, left: lVal, right: rVal, into: &diffs)
                case (nil, nil):
                    break
                }
            }
            return
        }

        if let lArr = left as? [Any], let rArr = right as? [Any] {
            let maxCount = max(lArr.count, rArr.count)
            for idx in 0..<maxCount {
                let childPath = "\(path)[\(idx)]"
                if idx >= lArr.count {
                    diffs.append(StateJSONFieldDiff(jsonPath: childPath, beforeValue: "<absent>", afterValue: stringifyJSONLeaf(rArr[idx])))
                } else if idx >= rArr.count {
                    diffs.append(StateJSONFieldDiff(jsonPath: childPath, beforeValue: stringifyJSONLeaf(lArr[idx]), afterValue: "<removed>"))
                } else {
                    collectJSONDiffs(path: childPath, left: lArr[idx], right: rArr[idx], into: &diffs)
                }
            }
            return
        }

        let lText = stringifyJSONLeaf(left)
        let rText = stringifyJSONLeaf(right)
        if lText != rText {
            diffs.append(StateJSONFieldDiff(jsonPath: path, beforeValue: lText, afterValue: rText))
        }
    }

    private static func stringifyJSONLeaf(_ value: Any) -> String {
        if value is NSNull { return "null" }
        if let str = value as? String { return "\"\(str)\"" }
        if let num = value as? NSNumber {
            return num.stringValue
        }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "\(value)"
    }
}

// MARK: - Action Rate-Limiter / Debouncer Calculator

public enum ActionRateLimitDecision: Codable, Equatable, Sendable {
    case allowImmediate
    case coalesceDebounce(remainingWindowMs: Int64)
    case rejectThrottled(retryAfterMs: Int64)
}

public struct ActionRateLimiterCalculator: Codable, Equatable, Sendable {
    private struct BucketState: Codable, Equatable, Sendable {
        var availableTokens: Double
        var lastRefillMs: Int64
        var lastAcceptedMs: Int64
    }

    public var debounceIntervalMs: Int64
    public var burstTokens: Double
    public var refillTokensPerSecond: Double
    private var buckets: [String: BucketState]

    public init(
        debounceIntervalMs: Int64 = 120,
        burstTokens: Double = 10.0,
        refillTokensPerSecond: Double = 5.0
    ) {
        self.debounceIntervalMs = max(0, debounceIntervalMs)
        self.burstTokens = max(1.0, burstTokens)
        self.refillTokensPerSecond = max(0.1, refillTokensPerSecond)
        self.buckets = [:]
    }

    public mutating func evaluate(key: String, nowEpochMs: Int64) -> ActionRateLimitDecision {
        var bucket = buckets[key] ?? BucketState(
            availableTokens: burstTokens,
            lastRefillMs: nowEpochMs,
            lastAcceptedMs: nowEpochMs - debounceIntervalMs - 1
        )

        let elapsedMs = max(0, nowEpochMs - bucket.lastRefillMs)
        let replenished = (Double(elapsedMs) / 1000.0) * refillTokensPerSecond
        bucket.availableTokens = min(burstTokens, bucket.availableTokens + replenished)
        bucket.lastRefillMs = nowEpochMs

        let sinceLastAccepted = nowEpochMs - bucket.lastAcceptedMs
        if debounceIntervalMs > 0 && sinceLastAccepted >= 0 && sinceLastAccepted < debounceIntervalMs {
            buckets[key] = bucket
            return .coalesceDebounce(remainingWindowMs: debounceIntervalMs - sinceLastAccepted)
        }

        if bucket.availableTokens < 1.0 {
            let deficit = 1.0 - bucket.availableTokens
            let waitMs = Int64(((deficit / refillTokensPerSecond) * 1000.0).rounded(.up))
            buckets[key] = bucket
            return .rejectThrottled(retryAfterMs: max(1, waitMs))
        }

        bucket.availableTokens -= 1.0
        bucket.lastAcceptedMs = nowEpochMs
        buckets[key] = bucket
        return .allowImmediate
    }
}

// MARK: - Telemetry Ring Buffer

public struct StudioTelemetrySample: Identifiable, Codable, Equatable, Sendable {
    public var id: Int
    public var actionName: String
    public var branchName: String
    public var reducerDurationMicroseconds: Int
    public var spawnedEffectCount: Int
    public var wasDropped: Bool
    public var dropReason: String?
    public var timestampEpochMs: Int64

    public init(
        id: Int,
        actionName: String,
        branchName: String,
        reducerDurationMicroseconds: Int,
        spawnedEffectCount: Int,
        wasDropped: Bool,
        dropReason: String? = nil,
        timestampEpochMs: Int64
    ) {
        self.id = id
        self.actionName = actionName
        self.branchName = branchName
        self.reducerDurationMicroseconds = reducerDurationMicroseconds
        self.spawnedEffectCount = spawnedEffectCount
        self.wasDropped = wasDropped
        self.dropReason = dropReason
        self.timestampEpochMs = timestampEpochMs
    }
}

public struct StudioTelemetrySummary: Codable, Equatable, Sendable {
    public var totalRecordedCount: Int
    public var bufferedSampleCount: Int
    public var droppedActionCount: Int
    public var p50DurationMicroseconds: Int
    public var p95DurationMicroseconds: Int
    public var maxDurationMicroseconds: Int
}

public struct StudioTelemetryRingBuffer: Codable, Equatable, Sendable {
    public let capacity: Int
    private var storage: [StudioTelemetrySample?]
    private var writeCursor: Int
    public private(set) var totalRecordedCount: Int
    public private(set) var droppedActionCount: Int

    public init(capacity: Int = 128) {
        let clamped = max(4, capacity)
        self.capacity = clamped
        self.storage = Array(repeating: nil, count: clamped)
        self.writeCursor = 0
        self.totalRecordedCount = 0
        self.droppedActionCount = 0
    }

    public mutating func push(_ sample: StudioTelemetrySample) {
        storage[writeCursor] = sample
        writeCursor = (writeCursor + 1) % capacity
        totalRecordedCount += 1
        if sample.wasDropped {
            droppedActionCount += 1
        }
    }

    public var orderedSamples: [StudioTelemetrySample] {
        var result: [StudioTelemetrySample] = []
        result.reserveCapacity(capacity)
        for offset in 0..<capacity {
            let idx = (writeCursor + offset) % capacity
            if let item = storage[idx] {
                result.append(item)
            }
        }
        return result
    }

    public func summarize() -> StudioTelemetrySummary {
        let samples = orderedSamples
        let durations = samples.filter { !$0.wasDropped }.map(\.reducerDurationMicroseconds).sorted()
        guard !durations.isEmpty else {
            return StudioTelemetrySummary(
                totalRecordedCount: totalRecordedCount,
                bufferedSampleCount: samples.count,
                droppedActionCount: droppedActionCount,
                p50DurationMicroseconds: 0,
                p95DurationMicroseconds: 0,
                maxDurationMicroseconds: 0
            )
        }
        let p50 = durations[(durations.count - 1) * 50 / 100]
        let p95 = durations[(durations.count - 1) * 95 / 100]
        return StudioTelemetrySummary(
            totalRecordedCount: totalRecordedCount,
            bufferedSampleCount: samples.count,
            droppedActionCount: droppedActionCount,
            p50DurationMicroseconds: p50,
            p95DurationMicroseconds: p95,
            maxDurationMicroseconds: durations.last ?? 0
        )
    }
}

// MARK: - Actor-Safe Deterministic StudioStore Runtime

public actor StudioStore<State: Codable & Equatable & Sendable, Action: StudioActionProtocol> {
    public let storeName: String
    private let reducer: StudioReducer<State, Action>
    private let middlewares: [StudioMiddleware<State, Action>]
    private var historyDAG: CausalStateDAG<State>
    private var rateLimiter: ActionRateLimiterCalculator
    private var telemetry: StudioTelemetryRingBuffer
    private var runningTasks: [String: Task<Void, Never>]
    private var dispatchCounter: Int

    public init(
        storeName: String = "ChiefKitStudioStore",
        initialState: State,
        reducer: StudioReducer<State, Action>,
        middlewares: [StudioMiddleware<State, Action>] = [],
        rateLimiter: ActionRateLimiterCalculator = ActionRateLimiterCalculator(debounceIntervalMs: 0),
        telemetryCapacity: Int = 256
    ) {
        self.storeName = storeName
        self.reducer = reducer
        self.middlewares = middlewares
        self.historyDAG = CausalStateDAG(initialState: initialState)
        self.rateLimiter = rateLimiter
        self.telemetry = StudioTelemetryRingBuffer(capacity: telemetryCapacity)
        self.runningTasks = [:]
        self.dispatchCounter = 0
    }

    public func currentState() -> State {
        historyDAG.currentState
    }

    public func snapshotDAG() -> CausalStateDAG<State> {
        historyDAG
    }

    public func telemetrySummary() -> StudioTelemetrySummary {
        telemetry.summarize()
    }

    public func recentTelemetrySamples() -> [StudioTelemetrySample] {
        telemetry.orderedSamples
    }

    @discardableResult
    public func send(_ action: Action, nowEpochMs: Int64? = nil) async -> State {
        let nowMs = nowEpochMs ?? Int64(Date().timeIntervalSince1970 * 1000.0)
        dispatchCounter += 1
        let seq = dispatchCounter

        // Optional rate-limiter / debounce gate
        if let rlKey = action.rateLimitKey {
            let decision = rateLimiter.evaluate(key: rlKey, nowEpochMs: nowMs)
            switch decision {
            case .allowImmediate:
                break
            case .coalesceDebounce(let waitMs):
                telemetry.push(StudioTelemetrySample(
                    id: seq,
                    actionName: action.actionName,
                    branchName: historyDAG.activeBranch,
                    reducerDurationMicroseconds: 0,
                    spawnedEffectCount: 0,
                    wasDropped: true,
                    dropReason: "debounced(\(waitMs)ms)",
                    timestampEpochMs: nowMs
                ))
                return historyDAG.currentState
            case .rejectThrottled(let retryMs):
                telemetry.push(StudioTelemetrySample(
                    id: seq,
                    actionName: action.actionName,
                    branchName: historyDAG.activeBranch,
                    reducerDurationMicroseconds: 0,
                    spawnedEffectCount: 0,
                    wasDropped: true,
                    dropReason: "throttled(\(retryMs)ms)",
                    timestampEpochMs: nowMs
                ))
                return historyDAG.currentState
            }
        }

        // Middleware pipeline
        let ctx = StudioMiddlewareContext(
            storeName: storeName,
            dispatchSequenceNumber: seq,
            activeBranch: historyDAG.activeBranch,
            timestampEpochMs: nowMs
        )

        var workingAction = action
        var extraEffects: [StudioEffect<Action>] = []
        let preState = historyDAG.currentState

        for mw in middlewares {
            switch mw.evaluate(state: preState, action: workingAction, context: ctx) {
            case .proceed(let nextAct):
                workingAction = nextAct
            case .rewrite(let rewritten, let sideEffect):
                workingAction = rewritten
                if !sideEffect.isNone { extraEffects.append(sideEffect) }
            case .drop(let reason):
                telemetry.push(StudioTelemetrySample(
                    id: seq,
                    actionName: workingAction.actionName,
                    branchName: historyDAG.activeBranch,
                    reducerDurationMicroseconds: 0,
                    spawnedEffectCount: 0,
                    wasDropped: true,
                    dropReason: "\(mw.name): \(reason)",
                    timestampEpochMs: nowMs
                ))
                return preState
            }
        }

        // Pure deterministic reducer step
        let startTime = Date().timeIntervalSinceReferenceDate
        var nextState = preState
        let primaryEffect = reducer.reduce(state: &nextState, action: workingAction)
        let elapsedMicros = max(1, Int(((Date().timeIntervalSinceReferenceDate - startTime) * 1_000_000.0).rounded()))

        if nextState != preState {
            historyDAG.appendCommit(
                actionName: workingAction.actionName,
                state: nextState,
                timestampEpochMs: nowMs
            )
        }

        let combinedEffect = extraEffects.isEmpty ? primaryEffect : .merge([primaryEffect] + extraEffects)
        telemetry.push(StudioTelemetrySample(
            id: seq,
            actionName: workingAction.actionName,
            branchName: historyDAG.activeBranch,
            reducerDurationMicroseconds: elapsedMicros,
            spawnedEffectCount: combinedEffect.leafEffectCount,
            wasDropped: false,
            timestampEpochMs: nowMs
        ))

        await executeEffect(combinedEffect)
        return historyDAG.currentState
    }

    private func executeEffect(_ effect: StudioEffect<Action>) async {
        switch effect.operation {
        case .none:
            return
        case .immediate(let followUp):
            _ = await send(followUp)
        case .cancel(let taskID):
            runningTasks[taskID]?.cancel()
            runningTasks.removeValue(forKey: taskID)
        case .asyncTask(let taskID, let priority, let work):
            let key = taskID ?? UUID().uuidString
            runningTasks[key]?.cancel()
            let handle = Task(priority: priority) { [weak self] in
                let maybeAction = await work()
                guard !Task.isCancelled, let self, let produced = maybeAction else { return }
                _ = await self.send(produced)
            }
            runningTasks[key] = handle
        case .batch(let children, let sequential):
            if sequential {
                for child in children {
                    await executeEffect(child)
                }
            } else {
                for child in children {
                    await executeEffect(child)
                }
            }
        }
    }

    public func createBranch(named branch: String) -> Bool {
        historyDAG.createBranch(named: branch)
    }

    public func switchBranch(to branch: String) -> State? {
        historyDAG.switchBranch(to: branch)
    }

    public func tagCheckpoint(_ tag: String) {
        historyDAG.tagCheckpoint(tag)
    }

    public func timeTravel(toCommitID commitID: String) -> State? {
        historyDAG.timeTravelJump(toCommitID: commitID)
    }

    public func diffCommits(from leftID: String, to rightID: String) -> [StateJSONFieldDiff] {
        historyDAG.diffStatesJSON(fromCommitID: leftID, toCommitID: rightID)
    }

    public func cancelAllEffects() {
        for task in runningTasks.values {
            task.cancel()
        }
        runningTasks.removeAll()
    }
}
