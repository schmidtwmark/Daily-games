import Foundation

enum DebugLogEntryType: String, Codable {
    case request
    case response
    case completionCheck
    case stateChange
    case debugCapture
}

struct DebugLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: DebugLogEntryType
    let reason: String
    let summary: String
    var details: [String: String]

    init(type: DebugLogEntryType, reason: String, summary: String, details: [String: String] = [:]) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.reason = reason
        self.summary = summary
        self.details = details
    }

    var typeIcon: String {
        switch type {
        case .request: return "arrow.up.circle"
        case .response: return "arrow.down.circle"
        case .completionCheck: return "checkmark.circle"
        case .stateChange: return "gearshape"
        case .debugCapture: return "doc.text"
        }
    }

    var typeLabel: String {
        switch type {
        case .request: return "Request"
        case .response: return "Response"
        case .completionCheck: return "Completion Check"
        case .stateChange: return "State Change"
        case .debugCapture: return "Debug Capture"
        }
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var shareText: String {
        var text = "[\(formattedTimestamp)] \(typeLabel) - \(reason)\n\(summary)\n"
        for (key, value) in details.sorted(by: { $0.key < $1.key }) {
            text += "  \(key): \(value)\n"
        }
        return text
    }
}

@MainActor
class DebugLogger: ObservableObject {
    @Published var logs: [String: [DebugLogEntry]] = [:]

    func log(game: Game, entry: DebugLogEntry) {
        if logs[game.id] == nil {
            logs[game.id] = []
        }
        logs[game.id]?.insert(entry, at: 0)
    }

    func entries(for game: Game) -> [DebugLogEntry] {
        logs[game.id] ?? []
    }

    func clear(for game: Game) {
        logs[game.id] = []
    }

    func allText(for game: Game) -> String {
        let entries = entries(for: game)
        if entries.isEmpty { return "No debug data for \(game.name)" }
        return "Debug Log for \(game.name)\n" +
            String(repeating: "=", count: 40) + "\n\n" +
            entries.reversed().map(\.shareText).joined(separator: "\n")
    }
}
