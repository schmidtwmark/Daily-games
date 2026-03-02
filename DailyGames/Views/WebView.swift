import SwiftUI
import WebKit

class WebViewModel: ObservableObject {
    @Published var estimatedProgress: Double = 0
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        self.webView = webView
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }
}

struct WebView: UIViewRepresentable {
    let viewModel: WebViewModel

    func makeUIView(context: Context) -> WKWebView {
        viewModel.webView.navigationDelegate = context.coordinator
        viewModel.webView.uiDelegate = context.coordinator
        context.coordinator.setupObservers(for: viewModel.webView)
        return viewModel.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let viewModel: WebViewModel
        private var observations: [NSKeyValueObservation] = []

        init(viewModel: WebViewModel) {
            self.viewModel = viewModel
        }

        func setupObservers(for webView: WKWebView) {
            observations.removeAll()
            observations = [
                webView.observe(\.estimatedProgress, options: .new) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.viewModel.estimatedProgress = wv.estimatedProgress
                    }
                },
                webView.observe(\.isLoading, options: .new) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.viewModel.isLoading = wv.isLoading
                    }
                },
                webView.observe(\.canGoBack, options: .new) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.viewModel.canGoBack = wv.canGoBack
                    }
                },
                webView.observe(\.canGoForward, options: .new) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.viewModel.canGoForward = wv.canGoForward
                    }
                },
            ]
        }

        // Handle target="_blank" links by loading them in the same web view
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil || !navigationAction.targetFrame!.isMainFrame {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
