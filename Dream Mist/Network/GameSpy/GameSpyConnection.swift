import Foundation
import Network

// Manages one TCP connection from a DS client. Accumulates incoming bytes until the
// GameSpy \final\ delimiter is seen, then dispatches complete messages to the handler.
actor GameSpyConnection {

    private let connection: NWConnection
    private var buffer = Data()
    private var handler = GameSpyHandler()
    private let playerManager: PlayerManager
    private let userManager: UserManager
    private(set) var authenticatedUserId: String?

    // GameSpy messages are delimited by \final\ on the wire.
    private static let delimiter = Data("\\final\\".utf8)

    init(connection: NWConnection, playerManager: PlayerManager, userManager: UserManager) {
        self.connection = connection
        self.playerManager = playerManager
        self.userManager = userManager
    }

    func start() {
        connection.start(queue: .global())
        send(handler.connectMessage)
        receive()
    }

    func stop() {
        log("GameSpy: connection closed from \(connection.endpoint)")
        connection.cancel()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { [weak self] in
                guard let self else { return }
                if let data { await self.received(data) }
                if isComplete || error != nil {
                    await self.stop()
                } else {
                    await self.receive()
                }
            }
        }
    }

    private func received(_ data: Data) {
        buffer.append(data)
        Task { await processBuffer() }
    }

    private func processBuffer() async {
        while let range = buffer.range(of: Self.delimiter) {
            let messageData = buffer[..<range.lowerBound]
            buffer.removeSubrange(..<range.upperBound)
            guard let text = String(data: messageData, encoding: .utf8),
                  let fields = try? GameSpyCodec.parse(text) else { continue }
            // Copy handler to a local variable — Swift 6 prohibits passing an actor-stored
            // property as inout to an async call. Safe here because processBuffer is the
            // only code path that mutates handler.
            var h = handler
            let response = await h.handle(fields, userManager: userManager, playerManager: playerManager)
            handler = h
            if let response { send(response) }
            if authenticatedUserId == nil, let uid = handler.userId {
                authenticatedUserId = uid
            }
        }
    }

    func sendPush(_ message: String) {
        send(message)
    }

    private func send(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        connection.send(content: data, completion: .idempotent)
    }
}