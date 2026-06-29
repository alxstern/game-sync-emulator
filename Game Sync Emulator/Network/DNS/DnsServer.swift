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
            log("DNS: query from \(connection.endpoint)")
            connection.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    log("DNS connection error: \(error)")
                }
            }
            connection.start(queue: .global())
            DnsServer.handle(connection, hostIP: hostIP)
        }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                log("DNS server listening on port \(port)")
            case .failed(let error):
                log("DNS server failed: \(error)")
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
        log("DNS server stopped")
    }

    // Static so it can be called from the newConnectionHandler closure without capturing self.
    private nonisolated static func handle(_ connection: NWConnection, hostIP: String) {
        connection.receiveMessage { data, _, _, error in
            if let error {
                log("DNS receive error: \(error)")
                return
            }
            guard let data else { log("DNS: nil data from \(connection.endpoint)"); return }
            guard let response = DnsQueryHandler.respond(to: data, hostIP: hostIP) else {
                log("DNS: failed to build response for \(data.count)-byte query from \(connection.endpoint)")
                return
            }
            log("DNS: sending \(response.count)B response to \(connection.endpoint)")
            connection.send(content: response, completion: .contentProcessed { error in
                if let error { log("DNS send error: \(error)") }
            })
        }
    }
}