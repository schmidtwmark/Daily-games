import SwiftUI

struct GameDebugView: View {
    let game: Game
    @EnvironmentObject private var prefetchManager: GamePrefetchManager

    @State private var showingShareSheet = false
    @State private var shareText = ""

    private var entries: [DebugLogEntry] {
        prefetchManager.debugLogger.entries(for: game)
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Debug Data",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("No requests or checks have been logged for \(game.name) yet.")
                )
            } else {
                Section {
                    HStack {
                        Button("Copy All") {
                            UIPasteboard.general.string = prefetchManager.debugLogger.allText(for: game)
                        }
                        Spacer()
                        Button("Share All") {
                            shareText = prefetchManager.debugLogger.allText(for: game)
                            showingShareSheet = true
                        }
                        Spacer()
                        Button("Clear", role: .destructive) {
                            prefetchManager.debugLogger.clear(for: game)
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }

                Section("Log Entries (\(entries.count))") {
                    ForEach(entries) { entry in
                        NavigationLink(value: entry.id) {
                            DebugLogEntryRow(entry: entry)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(game.name) Debug")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { entryId in
            if let entry = entries.first(where: { $0.id == entryId }) {
                DebugLogDetailView(entry: entry)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(text: shareText)
        }
    }
}

// MARK: - Row (compact summary in the list)

private struct DebugLogEntryRow: View {
    let entry: DebugLogEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.typeIcon)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(entry.typeLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(iconColor.opacity(0.15))
                        .foregroundStyle(iconColor)
                        .clipShape(Capsule())
                    Text(entry.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(entry.formattedTimestamp)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch entry.type {
        case .request: return .blue
        case .response: return .green
        case .completionCheck: return .orange
        case .stateChange: return .purple
        case .debugCapture: return .gray
        }
    }
}

// MARK: - Full detail view (pushed on tap)

private struct DebugLogDetailView: View {
    let entry: DebugLogEntry
    @State private var showingShareSheet = false

    var body: some View {
        List {
            // Header section
            Section("Overview") {
                LabeledRow(label: "Type", value: entry.typeLabel)
                LabeledRow(label: "Reason", value: entry.reason)
                LabeledRow(label: "Time", value: entry.formattedTimestamp)
                LabeledRow(label: "Summary", value: entry.summary)
            }

            // Each detail key gets its own section for large values
            let sorted = entry.details.sorted { $0.key < $1.key }
            ForEach(sorted, id: \.key) { key, value in
                Section {
                    DetailValueView(key: key, value: value)
                } header: {
                    HStack {
                        Text(key)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = value
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle(entry.typeLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Copy All") {
                        UIPasteboard.general.string = entry.shareText
                    }
                    Button("Share") {
                        showingShareSheet = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(text: entry.shareText)
        }
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }
}

private struct DetailValueView: View {
    let key: String
    let value: String

    @State private var isFullyExpanded = false

    private var isLargeValue: Bool {
        value.count > 500
    }

    private var isStructuredData: Bool {
        key == "localStorage" || key == "HTML" || key == "Body Text"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isStructuredData {
                // For large structured data, show a preview with expand
                Text(isFullyExpanded ? value : String(value.prefix(2000)))
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isLargeValue {
                    HStack {
                        Text("\(value.count) characters total")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button(isFullyExpanded ? "Collapse" : "Show All") {
                            isFullyExpanded.toggle()
                        }
                        .font(.caption)
                    }
                }
            } else {
                // Short values: show inline
                Text(value)
                    .font(.subheadline.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
