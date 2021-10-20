import SwiftUI
import WebKit

public final class WebView: NSObject, UIViewRepresentable, WKScriptMessageHandler {

    // MARK: - Type

    /// A dictionary that maps the message handler name with an optional callback function that takes a string argument
    public typealias MessageHandlers = [String: ((String) -> Void)?]

    // MARK: - Properties

    @Binding private var sendMessage: String

    private let request: URLRequest
    private let webView: WKWebView

    private let messageHandlers: MessageHandlers

    // MARK: - Setup

    public init(
        sendMessage: Binding<String>,
        url: URL,
        messageHandlers: [String: ((String) -> Void)?]
    ) {
        _sendMessage = sendMessage
        request = URLRequest(url: url)
        webView = WKWebView(
            frame: .zero,
            configuration: {
                let configuration = WKWebViewConfiguration()
                configuration.defaultWebpagePreferences = {
                    let prefs = WKWebpagePreferences()
                    prefs.allowsContentJavaScript = true
                    return prefs
                }()
                return configuration
            }()
        )
        self.messageHandlers = messageHandlers
    }

    public func makeUIView(context: Context) -> WKWebView {
        messageHandlers.forEach {
            webView.configuration.userContentController.add(self, name: $0.key)
        }
        webView.load(request)
        return webView
    }

    /// Methods to interact with the Webview.
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        guard !sendMessage.isEmpty else { return }
        uiView.evaluateJavaScript("receiveMessage(\"\(sendMessage)\");")
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? String,
              let handler = messageHandlers[message.name]
        else {
            return
        }
        handler?(body)
    }
}