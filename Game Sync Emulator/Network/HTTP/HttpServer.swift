import NIO
@preconcurrency import NIOSSL
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

        // Plain HTTP on port 8080 (pfctl redirects 80 → 8080 in dev)
        plainChannel = try await ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HttpChannelHandler(router: router))
                }
            }
            .bind(host: "0.0.0.0", port: 8080)
            .get()

        print("HTTP server listening on port 8080")

        // HTTPS on port 8443 (pfctl redirects 443 → 8443 in dev)
        // Failure here is non-fatal — plain HTTP still works, HTTPS just won't be available.
        do {
            let (certChain, privateKey) = try CertificateGenerator.load()

            var tlsConfig = TLSConfiguration.makeServerConfiguration(
                certificateChain: certChain.map { .certificate($0) },
                privateKey: .privateKey(privateKey)
            )
            tlsConfig.minimumTLSVersion = .tlsv1
            // Include RC4 ciphers required by the DS alongside modern fallbacks.
            tlsConfig.cipherSuites = "RC4-SHA:RC4-MD5:AES128-SHA:AES256-SHA"

            let sslContext = try NIOSSLContext(configuration: tlsConfig)

            tlsChannel = try await ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.backlog, value: 256)
                .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .childChannelInitializer { channel in
                    let sslHandler = NIOSSLServerHandler(context: sslContext)
                    return channel.pipeline.addHandler(sslHandler).flatMap {
                        channel.pipeline.configureHTTPServerPipeline()
                    }.flatMap {
                        channel.pipeline.addHandler(HttpChannelHandler(router: router))
                    }
                }
                .bind(host: "0.0.0.0", port: 8443)
                .get()

            print("HTTPS server listening on port 8443")
        } catch {
            print("HTTPS server failed to start: \(error)")
        }
    }

    func stop() async {
        try? await plainChannel?.close().get()
        try? await tlsChannel?.close().get()
        try? await group.shutdownGracefully()
    }
}
