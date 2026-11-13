import Foundation

public enum TimestampClockFormatting {
    public static func hmsString(from date: Date) -> String {
        let comps = Calendar(identifier: .gregorian).dateComponents([.hour, .minute, .second], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let s = comps.second ?? 0
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

public struct TimelineEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let action: String
    public let state: String
    public let timestamp: Date

    public init(id: UUID = UUID(), action: String, state: String, timestamp: Date = Date()) {
        self.id = id
        self.action = action
        self.state = state
        self.timestamp = timestamp
    }

    public var timeText: String {
        TimestampClockFormatting.hmsString(from: timestamp)
    }
}

public struct CartDemoItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var price: Int
    public var quantity: Int

    public init(id: String, name: String, price: Int, quantity: Int) {
        self.id = id
        self.name = name
        self.price = price
        self.quantity = quantity
    }
}

public struct StateSnapshot: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let index: Int
    public let action: String
    public let summary: String
    public let timestamp: Date

    public let counter: Int
    public let isLoading: Bool
    public let loadedMessage: String?
    public let cartItems: [CartDemoItem]
    public let promoApplied: Bool
    public let activeFlowStepIndex: Int

    public init(
        id: UUID = UUID(),
        index: Int,
        action: String,
        summary: String,
        timestamp: Date = Date(),
        counter: Int,
        isLoading: Bool,
        loadedMessage: String?,
        cartItems: [CartDemoItem],
        promoApplied: Bool,
        activeFlowStepIndex: Int
    ) {
        self.id = id
        self.index = index
        self.action = action
        self.summary = summary
        self.timestamp = timestamp
        self.counter = counter
        self.isLoading = isLoading
        self.loadedMessage = loadedMessage
        self.cartItems = cartItems
        self.promoApplied = promoApplied
        self.activeFlowStepIndex = activeFlowStepIndex
    }

    public var timeText: String {
        TimestampClockFormatting.hmsString(from: timestamp)
    }
}

public struct TimeTravelEngine: Codable, Equatable, Sendable {
    public private(set) var snapshots: [StateSnapshot]
    public private(set) var currentIndex: Int

    public init(initialSnapshot: StateSnapshot) {
        self.snapshots = [initialSnapshot]
        self.currentIndex = 0
    }

    public var currentSnapshot: StateSnapshot {
        snapshots[min(max(0, currentIndex), snapshots.count - 1)]
    }

    public var canStepBackward: Bool {
        currentIndex > 0
    }

    public var canStepForward: Bool {
        currentIndex < snapshots.count - 1
    }

    @discardableResult
    public mutating func record(
        action: String,
        summary: String,
        counter: Int,
        isLoading: Bool,
        loadedMessage: String?,
        cartItems: [CartDemoItem],
        promoApplied: Bool,
        activeFlowStepIndex: Int
    ) -> StateSnapshot {
        if currentIndex < snapshots.count - 1 {
            snapshots = Array(snapshots.prefix(currentIndex + 1))
        }
        let nextIndex = snapshots.count
        let snap = StateSnapshot(
            index: nextIndex,
            action: action,
            summary: summary,
            counter: counter,
            isLoading: isLoading,
            loadedMessage: loadedMessage,
            cartItems: cartItems,
            promoApplied: promoApplied,
            activeFlowStepIndex: activeFlowStepIndex
        )
        snapshots.append(snap)
        currentIndex = nextIndex
        return snap
    }

    @discardableResult
    public mutating func scrub(to targetIndex: Int) -> StateSnapshot {
        guard !snapshots.isEmpty else {
            fatalError("TimeTravelEngine must always retain at least one initial snapshot.")
        }
        currentIndex = min(max(0, targetIndex), snapshots.count - 1)
        return snapshots[currentIndex]
    }

    @discardableResult
    public mutating func stepBackward() -> StateSnapshot? {
        guard canStepBackward else { return nil }
        return scrub(to: currentIndex - 1)
    }

    @discardableResult
    public mutating func stepForward() -> StateSnapshot? {
        guard canStepForward else { return nil }
        return scrub(to: currentIndex + 1)
    }

    public mutating func reset(to initialSnapshot: StateSnapshot) {
        snapshots = [initialSnapshot]
        currentIndex = 0
    }
}

public struct CanvasHistoryStack: Equatable, Sendable {
    private var undoStack: [CanvasDocument] = []
    private var redoStack: [CanvasDocument] = []
    public let maxDepth: Int

    public init(maxDepth: Int = 40) {
        self.maxDepth = maxDepth
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoCount: Int { undoStack.count }
    public var redoCount: Int { redoStack.count }

    public mutating func recordBeforeMutation(_ current: CanvasDocument) {
        if undoStack.last == current { return }
        undoStack.append(current)
        if undoStack.count > maxDepth {
            undoStack.removeFirst(undoStack.count - maxDepth)
        }
        redoStack.removeAll()
    }

    public mutating func undo(current: CanvasDocument) -> CanvasDocument? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    public mutating func redo(current: CanvasDocument) -> CanvasDocument? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }

    public mutating func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
