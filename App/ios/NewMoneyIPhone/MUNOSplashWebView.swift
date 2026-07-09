import SwiftUI
import WebKit

enum MUNOSplashPresentationPolicy {
    static let playsOncePerProcessLaunch = true
    static let replaysOnForeground = false
    static let usesScenePhaseReplayRevision = false
    static let fadeOutDuration = 0.28
}

struct MUNOSplashWebView: UIViewRepresentable {
    var resourceName: String = "muno-splash"
    var fileExtension: String = "html"
    var onFinished: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "splashFinished")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true
        configuration.suppressesIncrementalRendering = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false

        if let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onFinished = onFinished
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "splashFinished")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onFinished: () -> Void
        private var didFinish = false

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "splashFinished", !didFinish else { return }
            didFinish = true

            DispatchQueue.main.async {
                self.onFinished()
            }
        }
    }
}

struct MUNOSplashHost<Content: View>: View {
    @State private var isShowingSplash = true
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            content()
                .opacity(isShowingSplash ? 0 : 1)

            if isShowingSplash {
                MUNOSplashWebView {
                    withAnimation(.easeOut(duration: MUNOSplashPresentationPolicy.fadeOutDuration)) {
                        isShowingSplash = false
                    }
                }
                .ignoresSafeArea()
                .background(Color.black)
                .transition(.opacity)
            }
        }
        .background(Color.black)
    }
}

#Preview {
    MUNOSplashWebView()
        .ignoresSafeArea()
        .background(Color.black)
}
