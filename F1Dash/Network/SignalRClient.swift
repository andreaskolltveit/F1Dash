import Foundation
import os

/// SignalR 1.5 client for F1 Live Timing.
/// Handles negotiate → WebSocket connect → subscribe → listen loop.
actor SignalRClient {
    private let logger = Logger(subsystem: "com.f1dash", category: "SignalR")
    private let baseURL = "https://livetiming.formula1.com/signalr"
    private let hubName = "Streaming"
    private let userAgent = "BestHTTP"

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var connectionToken: String?
    private var cookie: String?

    private var continuation: AsyncStream<TopicMessage>.Continuation?

    /// A decoded topic message from the WebSocket stream.
    struct TopicMessage {
        let topic: String
        let data: Any
        let timestamp: String?
    }

    // MARK: - Public API

    /// Connect to F1 Live Timing and subscribe to all topics.
    /// Returns an AsyncStream of topic messages.
    func connect() async throws -> (initialState: [String: Any], stream: AsyncStream<TopicMessage>) {
        // 1. Negotiate
        let negotiateResult = try await negotiate()
        self.connectionToken = negotiateResult.token
        self.cookie = negotiateResult.cookie

        logger.info("Negotiated. Token: \(negotiateResult.token.prefix(20))...")

        // 2. Connect WebSocket
        let ws = try await connectWebSocket()
        self.webSocketTask = ws

        // Wait for init message (empty JSON object = {"S":1})
        let initMsg = try await ws.receive()
        if case .string(let text) = initMsg {
            logger.debug("Init message: \(text)")
        }

        // 3. Subscribe and get initial state
        let initialState = try await subscribe(ws: ws)
        logger.info("Subscribed. Got initial state with \(initialState.count) topics.")

        // 4. Create listen stream
        let stream = AsyncStream<TopicMessage> { continuation in
            self.continuation = continuation
            Task { [weak self] in
                await self?.listenLoop(ws: ws)
            }
        }

        return (initialState, stream)
    }

    /// Disconnect and clean up.
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Negotiate

    private struct NegotiateResult {
        let token: String
        let cookie: String
    }

    private func negotiate() async throws -> NegotiateResult {
        let connectionData = [["name": hubName]]
        let connectionDataJSON = try JSONSerialization.data(withJSONObject: connectionData)
        let connectionDataString = String(data: connectionDataJSON, encoding: .utf8)!

        var components = URLComponents(string: "\(baseURL)/negotiate")!
        components.queryItems = [
            URLQueryItem(name: "clientProtocol", value: "1.5"),
            URLQueryItem(name: "connectionData", value: connectionDataString),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("gzip,identity", forHTTPHeaderField: "Accept-Encoding")

        let (data, response) = try await URLSession.shared.data(for: request)

        // Extract cookies from response
        var cookieString = ""
        if let httpResponse = response as? HTTPURLResponse,
           let headerFields = httpResponse.allHeaderFields as? [String: String],
           let url = response.url {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
            cookieString = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        }

        let negotiateResponse = try JSONDecoder().decode(NegotiateResponse.self, from: data)
        return NegotiateResult(token: negotiateResponse.ConnectionToken, cookie: cookieString)
    }

    // MARK: - WebSocket

    private func connectWebSocket() async throws -> URLSessionWebSocketTask {
        guard let token = connectionToken else {
            throw SignalRError.notNegotiated
        }

        let connectionData = [["name": hubName]]
        let connectionDataJSON = try JSONSerialization.data(withJSONObject: connectionData)
        let connectionDataString = String(data: connectionDataJSON, encoding: .utf8)!

        var components = URLComponents(string: "\(baseURL)/connect")!
        components.scheme = "wss"
        components.queryItems = [
            URLQueryItem(name: "clientProtocol", value: "1.5"),
            URLQueryItem(name: "transport", value: "webSockets"),
            URLQueryItem(name: "connectionToken", value: token),
            URLQueryItem(name: "connectionData", value: connectionDataString),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("gzip,identity", forHTTPHeaderField: "Accept-Encoding")
        if let cookie = cookie, !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let session = URLSession(configuration: .default)
        self.session = session
        let ws = session.webSocketTask(with: request)
        ws.resume()
        return ws
    }

    // MARK: - Subscribe

    private func subscribe(ws: URLSessionWebSocketTask) async throws -> [String: Any] {
        let invocationId = UUID().uuidString
        let invocation = SignalRInvocation(
            H: hubName,
            M: "Subscribe",
            A: [F1Topic.allTopicNames],
            I: invocationId
        )

        let data = try JSONEncoder().encode(invocation)
        let jsonString = String(data: data, encoding: .utf8)!
        try await ws.send(.string(jsonString))

        logger.debug("Sent subscribe request: \(invocationId)")

        // Wait for response with matching invocation ID
        while true {
            let message = try await ws.receive()
            guard case .string(let text) = message else { continue }
            guard let messageData = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] else {
                continue
            }

            // Check if this is the subscribe response (has "I" matching our invocation)
            if let responseId = json["I"] as? String, responseId == invocationId {
                let initialState = json["R"] as? [String: Any] ?? [:]
                return initialState
            }

            // Process any messages that arrived before the response
            if let messages = json["M"] as? [[String: Any]] {
                for msg in messages {
                    if let topicMsg = parseHubMessage(msg) {
                        continuation?.yield(topicMsg)
                    }
                }
            }
        }
    }

    // MARK: - Listen Loop

    private func listenLoop(ws: URLSessionWebSocketTask) async {
        while true {
            do {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    processMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        processMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                logger.error("WebSocket error: \(error.localizedDescription)")
                continuation?.finish()
                return
            }
        }
    }

    private func processMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Process hub messages
        if let messages = json["M"] as? [[String: Any]] {
            for msg in messages {
                if let topicMsg = parseHubMessage(msg) {
                    continuation?.yield(topicMsg)
                }
            }
        }

        // Empty message = keepalive, just ignore
    }

    private func parseHubMessage(_ msg: [String: Any]) -> TopicMessage? {
        guard let args = msg["A"] as? [Any],
              args.count >= 2 else { return nil }

        let topic = args[0] as? String ?? ""
        let data = args[1]
        let timestamp = args.count > 2 ? args[2] as? String : nil

        return TopicMessage(topic: topic, data: data, timestamp: timestamp)
    }
}

// MARK: - Errors

enum SignalRError: Error, LocalizedError {
    case notNegotiated
    case connectionFailed(String)
    case subscribeFailed

    var errorDescription: String? {
        switch self {
        case .notNegotiated: "Not negotiated — call negotiate() first"
        case .connectionFailed(let msg): "Connection failed: \(msg)"
        case .subscribeFailed: "Subscribe failed"
        }
    }
}
