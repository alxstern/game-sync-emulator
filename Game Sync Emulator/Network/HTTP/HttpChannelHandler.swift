import Foundation
@preconcurrency import NIO
import NIOHTTP1

// MARK: - Request

struct HttpRequest {
    let head: HTTPRequestHead
    let body: Data

    var method: HTTPMethod { head.method }
    var headers: HTTPHeaders { head.headers }

    var path: String {
        String(head.uri.split(separator: "?", maxSplits: 1).first ?? Substring(head.uri))
    }

    var queryItems: [URLQueryItem] {
        URLComponents(string: head.uri)?.queryItems ?? []
    }

    func queryValue(for key: String) -> String? {
        queryItems.first { $0.name == key }?.value
    }

    var rawQueryString: String {
        URLComponents(string: head.uri)?.query ?? ""
    }

    var basicAuthCredentials: (username: String, password: String)? {
        guard let auth = head.headers["authorization"].first,
              auth.hasPrefix("Basic "),
              let data = Data(base64Encoded: String(auth.dropFirst(6))),
              let decoded = String(data: data, encoding: .utf8) else { return nil }
        let parts = decoded.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (username: String(parts[0]), password: String(parts[1]))
    }
}

// MARK: - Response

struct HttpResponse {
    var status: HTTPResponseStatus
    var headers: [(String, String)]
    var body: Data

    init(status: HTTPResponseStatus = .ok, headers: [(String, String)] = [], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    static func ok(_ body: Data, headers: [(String, String)] = []) -> HttpResponse {
        HttpResponse(status: .ok, headers: headers, body: body)
    }

    static func unauthorized() -> HttpResponse { HttpResponse(status: .unauthorized) }
    static func notFound()     -> HttpResponse { HttpResponse(status: .notFound) }
    static func internalError() -> HttpResponse { HttpResponse(status: .internalServerError) }
}

// MARK: - Router

protocol HttpRequestHandler: Sendable {
    func handle(_ request: HttpRequest) async -> HttpResponse
}

struct HttpRouter: @unchecked Sendable {
    let userManager: UserManager
    let playerManager: PlayerManager
    let dlcList: DlcList
    let configuration: Configuration

    func route(_ request: HttpRequest) async -> HttpResponse {
        switch request.path {
        case "/":
            // Nintendo conntest — must include X-Organization header or the DS shows error 052210-1.
            return HttpResponse(
                status: .ok,
                headers: [("X-Organization", "Nintendo")],
                body: Data("Test".utf8)
            )
        case "/ac":
            return await NasHandler(userManager: userManager, configuration: configuration).handle(request)
        case "/dsio/gw":
            return await PglHandler(userManager: userManager, playerManager: playerManager, dlcList: dlcList, configuration: configuration).handle(request)
        case "/download":
            return await DlsHandler(userManager: userManager, dlcList: dlcList).handle(request)
        default:
            print("HTTP: unhandled \(request.method) \(request.path)")
            return HttpResponse(status: .notFound)
        }
    }
}

// MARK: - Channel Handler

// Wraps ChannelHandlerContext for safe capture across concurrency boundaries.
// The value is only ever accessed after hopping back to its own event loop.
private struct ContextBox: @unchecked Sendable { let value: ChannelHandlerContext }

// Accumulates HTTPServerRequestPart events into a complete HttpRequest, then
// dispatches async to the router and writes the response back on the event loop.
final class HttpChannelHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn  = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private var requestHead: HTTPRequestHead?
    private var bodyAccumulator = Data()
    private let router: HttpRouter

    init(router: HttpRouter) {
        self.router = router
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            requestHead = head
            bodyAccumulator.removeAll(keepingCapacity: true)
        case .body(var buffer):
            if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                bodyAccumulator.append(contentsOf: bytes)
            }
        case .end:
            guard let head = requestHead else { return }
            let request = HttpRequest(head: head, body: bodyAccumulator)
            requestHead = nil
            bodyAccumulator.removeAll(keepingCapacity: true)

            let router = self.router
            let box = ContextBox(value: context)
            Task {
                let response = await router.route(request)
                box.value.eventLoop.execute {
                    self.write(response, to: box.value)
                }
            }
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("HTTP connection error: \(error)")
        context.close(promise: nil)
    }

    private func write(_ response: HttpResponse, to context: ChannelHandlerContext) {
        var headers = HTTPHeaders(response.headers)
        headers.add(name: "Content-Length", value: "\(response.body.count)")
        headers.add(name: "Connection", value: "close")

        let head = HTTPResponseHead(version: .http1_1, status: response.status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        if !response.body.isEmpty {
            var buffer = context.channel.allocator.buffer(capacity: response.body.count)
            buffer.writeBytes(response.body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }

        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}
