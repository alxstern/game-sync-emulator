import NIO
import NIOHTTP1

actor HttpServer {

    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
    private var plainChannel: Channel?
    private var tlsChannel: Channel?

    func start(
        userManager: UserManager,
        playerManager: PlayerManager,
        dlcList: DlcList,
        configuration: Configuration
    ) async throws {
        let router = HttpRouter(
            userManager: userManager,
            playerManager: playerManager,
            dlcList: dlcList,
            configuration: configuration
        )

        // Plain HTTP on port 80 — this machine doesn't enforce the classic "ports below 1024
        // need root" restriction, so no relay/daemon is needed to get here (see AppServices).
        plainChannel = try await ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HttpChannelHandler(router: router))
                }
            }
            .bind(host: "0.0.0.0", port: 80)
            .get()

        log("HTTP server listening on port 80")

        // HTTPS on port 443 using a custom SSL 3.0 / RC4 handler. The DS sends
        // client_version=0x0300 (SSL 3.0) with RC4-only ciphers, which BoringSSL dropped. We
        // implement the minimal SSL 3.0 handshake and RC4 record layer directly.
        do {
            let (certDER, caDER, privKey) = try CertificateGenerator.loadSSL3()

            tlsChannel = try await ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.backlog, value: 256)
                .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .childChannelInitializer { channel in
                    let ssl3 = Ssl3Handler(serverCertDER: certDER, caCertDER: caDER, privateKey: privKey)
                    return channel.pipeline.addHandler(ssl3).flatMap {
                        channel.pipeline.configureHTTPServerPipeline()
                    }.flatMap {
                        channel.pipeline.addHandler(HttpChannelHandler(router: router))
                    }
                }
                .bind(host: "0.0.0.0", port: 443)
                .get()

            log("HTTPS server listening on port 443")
        } catch {
            log("HTTPS server failed to start: \(error)")
        }
    }

    func stop() async {
        try? await plainChannel?.close().get()
        try? await tlsChannel?.close().get()
        try? await group.shutdownGracefully()
    }
}
