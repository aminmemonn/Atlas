import Foundation

/// Manages the encrypted WebSocket connection to the self-hosted gateway.
///
/// Implemented as an `actor` so connection state and the underlying
/// `URLSessionWebSocketTask` are mutated from a single isolation domain.
/// Inbound frames are delivered via an `AsyncStream`; outbound commands are
/// sent with `send(_:)`. Reconnection uses bounded exponential backoff.
///
/// Security: only `wss://` endpoints are accepted, and the bearer token is read
/// from the Keychain at connect time — it is never held on a model object.
actor GatewayService {
    private let coder = GatewayCoder()
    private let keychain: KeychainService
    private let session: URLSession

    private var task: URLSessionWebSocketTask?
    private var connection: GatewayConnectionInfo?
    private var receiveLoop: Task<Void, Never>?
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 6

    private(set) var connectionState: ConnectionState = .disconnected {
        didSet { stateContinuation?.yield(connectionState) }
    }

    private var frameContinuation: AsyncStream<GatewayFrame>.Continuation?
    private var stateContinuation: AsyncStream<ConnectionState>.Continuation?

    init(keychain: KeychainService = KeychainService(),
         session: URLSession = .shared) {
        self.keychain = keychain
        self.session = session
    }

    /// Stream of inbound frames. Created lazily; one consumer is expected.
    func frames() -> AsyncStream<GatewayFrame> {
        let (stream, continuation) = AsyncStream<GatewayFrame>.makeStream()
        frameContinuation = continuation
        return stream
    }

    /// Stream of connection-state transitions for UI binding.
    func connectionStates() -> AsyncStream<ConnectionState> {
        let (stream, continuation) = AsyncStream<ConnectionState>.makeStream()
        stateContinuation = continuation
        continuation.yield(connectionState)
        return stream
    }

    // MARK: - Lifecycle

    func connect(to info: GatewayConnectionInfo) async {
        guard info.endpoint.scheme?.lowercased() == "wss" else {
            connectionState = .failed(reason: "Gateway must use wss://")
            return
        }
        self.connection = info
        reconnectAttempt = 0
        await openSocket()
    }

    func disconnect() {
        receiveLoop?.cancel()
        receiveLoop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        connectionState = .disconnected
    }

    private func openSocket() async {
        guard let connection else { return }
        connectionState = reconnectAttempt == 0 ? .connecting : .reconnecting(attempt: reconnectAttempt)

        var request = URLRequest(url: connection.endpoint)
        if let token = try? keychain.token(for: connection.id) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("atlas-ios", forHTTPHeaderField: "X-Atlas-Client")

        let socket = session.webSocketTask(with: request)
        self.task = socket
        socket.resume()
        connectionState = .connected
        reconnectAttempt = 0

        receiveLoop = Task { [weak self] in
            await self?.listen()
        }
    }

    // MARK: - Receive

    private func listen() async {
        guard let task else { return }
        do {
            while !Task.isCancelled {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    handle(text: text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) { handle(text: text) }
                @unknown default:
                    break
                }
            }
        } catch {
            if !Task.isCancelled {
                await handleDisconnect(error: error)
            }
        }
    }

    private func handle(text: String) {
        guard let frame = try? coder.decodeFrame(text) else { return }
        frameContinuation?.yield(frame)
    }

    private func handleDisconnect(error: Error) async {
        task = nil
        guard reconnectAttempt < maxReconnectAttempts else {
            connectionState = .failed(reason: "Lost connection to gateway")
            return
        }
        reconnectAttempt += 1
        connectionState = .reconnecting(attempt: reconnectAttempt)

        // Exponential backoff capped at ~16s.
        let delay = min(pow(2.0, Double(reconnectAttempt)), 16)
        try? await Task.sleep(for: .seconds(delay))
        if !Task.isCancelled {
            await openSocket()
        }
    }

    // MARK: - Send

    func send(_ command: GatewayCommand) async throws {
        guard let task, connectionState.isConnected else {
            throw GatewaySendError.notConnected
        }
        let text = try coder.encodeCommand(command)
        try await task.send(.string(text))
    }

    enum GatewaySendError: Error, Equatable {
        case notConnected
    }
}
