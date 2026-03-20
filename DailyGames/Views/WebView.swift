import SwiftUI
import WebKit

@MainActor
class WebViewModel: ObservableObject {
    @Published var estimatedProgress: Double = 0
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []

    init(webView: WKWebView? = nil) {
        if let webView = webView {
            self.webView = webView
        } else {
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []

            let newWebView = WKWebView(frame: .zero, configuration: config)
            newWebView.allowsBackForwardNavigationGestures = true
            self.webView = newWebView
        }

        setupObservers()
    }

    private func setupObservers() {
        observations = [
            webView.observe(\.estimatedProgress, options: .new) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.estimatedProgress = wv.estimatedProgress
                }
            },
            webView.observe(\.isLoading, options: .new) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.isLoading = wv.isLoading
                }
            },
            webView.observe(\.canGoBack, options: .new) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.canGoBack = wv.canGoBack
                }
            },
            webView.observe(\.canGoForward, options: .new) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.canGoForward = wv.canGoForward
                }
            },
        ]

        estimatedProgress = webView.estimatedProgress
        isLoading = webView.isLoading
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
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
        return viewModel.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let viewModel: WebViewModel

        init(viewModel: WebViewModel) {
            self.viewModel = viewModel
        }

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
