import SwiftUI

struct GamePlayerView: View {
    let game: Game
    @EnvironmentObject private var prefetchManager: GamePrefetchManager
    @State private var viewModel: WebViewModel?
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()

    var body: some View {
        ZStack(alignment: .top) {
            if let viewModel = viewModel {
                if game.needsBottomSafeArea {
                    // Respect safe area - add background that extends under safe area
                    WebView(viewModel: viewModel)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 0)
                        }
                        .background(Color(red: 0.96, green: 0.96, blue: 0.94)) // Bracket City background
                } else {
                    WebView(viewModel: viewModel)
                        .ignoresSafeArea(edges: .bottom)
                }

                if viewModel.isLoading {
                    ProgressView(value: viewModel.estimatedProgress)
                        .tint(game.color)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button { showingDatePicker = true } label: {
                        Image(systemName: "calendar")
                    }

                    Button { viewModel?.reload() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                selectedDate: $selectedDate,
                game: game
            ) { date in
                loadGame(for: date)
            }
        }
        .onAppear {
            setupViewModel()
        }
        .onDisappear {
            // Check completion when user exits game, with retry after 2s if needed
            prefetchManager.onGameExit(game: game)
        }
    }

    private var navigationTitle: String {
        if !Calendar.current.isDateInToday(selectedDate) {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(game.name) - \(formatter.string(from: selectedDate))"
        }
        return game.name
    }

    private func setupViewModel() {
        selectedDate = prefetchManager.currentDate(for: game)
        let prefetchedWebView = prefetchManager.webView(for: game)
        viewModel = WebViewModel(webView: prefetchedWebView)
    }

    private func loadGame(for date: Date) {
        selectedDate = date
        prefetchManager.prefetch(game: game, for: date, reason: "Date picker")
    }
}

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let game: Game
    let onDateSelected: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Choose Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        onDateSelected(selectedDate)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
