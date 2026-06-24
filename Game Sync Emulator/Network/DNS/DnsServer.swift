import Network

actor DnsServer {

    private var listener: NWListener?
    let hostIP: String
    let port: UInt16

    init(hostIP: String, port: UInt16 = 5300) {
        self.hostIP = hostIP
        self.port = port
    }

    func start() throws {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let nwPort = NWEndpoint.Port(rawValue: port)!
        let listener = try NWListener(using: params, on: nwPort)
        let hostIP = self.hostIP
        let port = self.port

        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            DnsServer.handle(connection, hostIP: hostIP)
        }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("DNS server listening on port \(port)")
            case .failed(let error):
                print("DNS server failed: \(error)")
            default:
                break
            }
        }

        listener.start(queue: .global())
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        print("DNS server stopped")
    }

    // Static so it can be called from the newConnectionHandler closure without capturing self.
    private nonisolated static func handle(_ connection: NWConnection, hostIP: String) {
        connection.receiveMessage { data, _, _, error in
            if let error {
                print("DNS receive error: \(error)")
                return
            }
            guard let data,
                  let response = DnsQueryHandler.respond(to: data, hostIP: hostIP) else { return }
            connection.send(content: response, completion: .idempotent)
        }
    }
}