import SwiftUI

struct GamePlayerView: View {
    let game: Game
    @StateObject private var viewModel = WebViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            WebView(viewModel: viewModel)
                .ignoresSafeArea(edges: .bottom)

            if viewModel.isLoading {
                ProgressView(value: viewModel.estimatedProgress)
                    .tint(game.color)
            }
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { viewModel.goBack() } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!viewModel.canGoBack)

                Button { viewModel.goForward() } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!viewModel.canGoForward)

                Spacer()

                Button { viewModel.reload() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            viewModel.load(game.url)
        }
    }
}
