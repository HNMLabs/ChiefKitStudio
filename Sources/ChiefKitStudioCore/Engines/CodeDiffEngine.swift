import Foundation

public enum DiffLineKind: String, Codable, Hashable, Sendable {
    case unchanged
    case added
    case removed

    public var prefixSymbol: String {
        switch self {
        case .unchanged: " "
        case .added: "+"
        case .removed: "-"
        }
    }
}

public struct DiffLine: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let kind: DiffLineKind
    public let oldLineNumber: Int?
    public let newLineNumber: Int?
    public let text: String

    public init(
        id: Int,
        kind: DiffLineKind,
        oldLineNumber: Int?,
        newLineNumber: Int?,
        text: String
    ) {
        self.id = id
        self.kind = kind
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.text = text
    }
}

public struct DiffReport: Codable, Hashable, Sendable {
    public let lines: [DiffLine]
    public let addedCount: Int
    public let removedCount: Int
    public let unchangedCount: Int

    public init(lines: [DiffLine]) {
        self.lines = lines
        var added = 0
        var removed = 0
        var same = 0
        for line in lines {
            switch line.kind {
            case .added: added += 1
            case .removed: removed += 1
            case .unchanged: same += 1
            }
        }
        self.addedCount = added
        self.removedCount = removed
        self.unchangedCount = same
    }

    public var hasChanges: Bool {
        addedCount > 0 || removedCount > 0
    }

    public var summaryBadge: String {
        "+\(addedCount) / -\(removedCount)"
    }

    public var unifiedPatch: String {
        guard hasChanges else {
            return "// No line differences between baseline and active code."
        }
        var output = ["--- a/PlaygroundView.swift", "+++ b/PlaygroundView.swift", "@@ \(summaryBadge) lines @@"]
        for line in lines {
            output.append("\(line.kind.prefixSymbol) \(line.text)")
        }
        return output.joined(separator: "\n")
    }
}

public enum CodeDiffEngine {
    /// Computes an exact line-by-line LCS diff for files up to ~600 lines, falling back to prefix/suffix anchored diff for huge inputs.
    public static func diff(original: String, updated: String) -> DiffReport {
        if original == updated {
            let split = original.components(separatedBy: "\n")
            let unchanged = split.enumerated().map { idx, text in
                DiffLine(id: idx, kind: .unchanged, oldLineNumber: idx + 1, newLineNumber: idx + 1, text: text)
            }
            return DiffReport(lines: unchanged)
        }

        let oldLines = original.isEmpty ? [] : original.components(separatedBy: "\n")
        let newLines = updated.isEmpty ? [] : updated.components(separatedBy: "\n")

        let m = oldLines.count
        let n = newLines.count

        if m * n > 400_000 {
            return anchoredLinearDiff(oldLines: oldLines, newLines: newLines)
        }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        if m > 0 && n > 0 {
            for i in stride(from: m - 1, through: 0, by: -1) {
                for j in stride(from: n - 1, through: 0, by: -1) {
                    if oldLines[i] == newLines[j] {
                        dp[i][j] = dp[i + 1][j + 1] + 1
                    } else {
                        dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                    }
                }
            }
        }

        var raw: [(DiffLineKind, Int?, Int?, String)] = []
        var i = 0
        var j = 0
        while i < m && j < n {
            if oldLines[i] == newLines[j] {
                raw.append((.unchanged, i + 1, j + 1, oldLines[i]))
                i += 1
                j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                raw.append((.removed, i + 1, nil, oldLines[i]))
                i += 1
            } else {
                raw.append((.added, nil, j + 1, newLines[j]))
                j += 1
            }
        }
        while i < m {
            raw.append((.removed, i + 1, nil, oldLines[i]))
            i += 1
        }
        while j < n {
            raw.append((.added, nil, j + 1, newLines[j]))
            j += 1
        }

        let built = raw.enumerated().map { index, entry in
            DiffLine(
                id: index,
                kind: entry.0,
                oldLineNumber: entry.1,
                newLineNumber: entry.2,
                text: entry.3
            )
        }
        return DiffReport(lines: built)
    }

    private static func anchoredLinearDiff(oldLines: [String], newLines: [String]) -> DiffReport {
        var prefix = 0
        while prefix < oldLines.count, prefix < newLines.count, oldLines[prefix] == newLines[prefix] {
            prefix += 1
        }
        var oldEnd = oldLines.count
        var newEnd = newLines.count
        while oldEnd > prefix, newEnd > prefix, oldLines[oldEnd - 1] == newLines[newEnd - 1] {
            oldEnd -= 1
            newEnd -= 1
        }

        var result: [DiffLine] = []
        var nextID = 0
        for idx in 0..<prefix {
            result.append(DiffLine(id: nextID, kind: .unchanged, oldLineNumber: idx + 1, newLineNumber: idx + 1, text: oldLines[idx]))
            nextID += 1
        }
        for idx in prefix..<oldEnd {
            result.append(DiffLine(id: nextID, kind: .removed, oldLineNumber: idx + 1, newLineNumber: nil, text: oldLines[idx]))
            nextID += 1
        }
        for idx in prefix..<newEnd {
            result.append(DiffLine(id: nextID, kind: .added, oldLineNumber: nil, newLineNumber: idx + 1, text: newLines[idx]))
            nextID += 1
        }
        let tailCount = oldLines.count - oldEnd
        for offset in 0..<tailCount {
            let oIdx = oldEnd + offset
            let nIdx = newEnd + offset
            result.append(DiffLine(id: nextID, kind: .unchanged, oldLineNumber: oIdx + 1, newLineNumber: nIdx + 1, text: oldLines[oIdx]))
            nextID += 1
        }
        return DiffReport(lines: result)
    }
}
