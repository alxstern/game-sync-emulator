import Network

actor GameSpyServer {

    private var listener: NWListener?
    private var connections: [GameSpyConnection] = []
    let port: UInt16

    init(port: UInt16 = 29900) {
        self.port = port
    }

    func start(playerManager: PlayerManager, userManager: UserManager) throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let nwPort = NWEndpoint.Port(rawValue: port)!
        let listener = try NWListener(using: params, on: nwPort)
        let port = self.port

        listener.newConnectionHandler = { [weak self] nwConn in
            Task { [weak self] in
                guard let self else { return }
                let conn = GameSpyConnection(connection: nwConn, playerManager: playerManager, userManager: userManager)
                await self.add(conn)
                await conn.start()
            }
        }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("GameSpy server listening on port \(port)")
            case .failed(let error):
                print("GameSpy server failed: \(error)")
            default:
                break
            }
        }

        listener.start(queue: .global())
        self.listener = listener
    }

    func stop() {
        for conn in connections { Task { await conn.stop() } }
        connections.removeAll()
        listener?.cancel()
        listener = nil
        print("GameSpy server stopped")
    }

    private func add(_ connection: GameSpyConnection) {
        connections.append(connection)
    }
}