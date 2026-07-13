import Foundation

struct NasHandler: HttpRequestHandler {

    let userManager: UserManager
    let configuration: Configuration

    func handle(_ request: HttpRequest) async -> HttpResponse {
        let bodyString = String(data: request.body, encoding: .utf8) ?? ""

        guard let fields = try? URLEncodedFormCodec.parse(bodyString),
              let nasRequest = NasRequest(from: fields) else {
            return encode(returnCode: .badRequest)
        }

        log("NAS: action=\(nasRequest.action) rawBody=\(bodyString)")

        switch nasRequest.action {
        case "login":       return await handleLogin(nasRequest)
        case "acctcreate":  return await handleCreateAccount(nasRequest)
        case "SVCLOC":      return await handleServiceLocation(nasRequest)
        default:
            log("NAS: unknown action '\(nasRequest.action)'")
            return encode(returnCode: .badRequest)
        }
    }

    // POST /ac action=login
    // Authenticates a WFC user and returns a GameSpy auth token.
    // If the user doesn't exist and auto-registration is enabled, registers them first.
    private func handleLogin(_ request: NasRequest) async -> HttpResponse {
        guard let branchCode = request.branchCode else {
            return encode(returnCode: .badRequest)
        }

        var user = await userManager.authenticateUser(id: request.userId, password: request.password)

        if user == nil {
            guard configuration.allowWfcRegistrationThroughLogin else {
                return encode(returnCode: .userNotFound)
            }
            user = try? await userManager.registerUser(id: request.userId, password: request.password)
            guard user != nil else { return encode(returnCode: .userNotFound) }
            user = await userManager.authenticateUser(id: request.userId, password: request.password)
        }

        guard let user else { return encode(returnCode: .userNotFound) }

        let credentials = await userManager.createServiceSession(for: user, service: "gamespy", branchCode: branchCode)
        log("NAS: created GameSpy session for user \(user.formattedId)")
        return encode([("locator", "gamespy.com"), ("token", credentials.authToken), ("challenge", credentials.challenge)])
    }

    // POST /ac action=acctcreate
    // Registers a new WFC user account.
    private func handleCreateAccount(_ request: NasRequest) async -> HttpResponse {
        do {
            let user = try await userManager.registerUser(id: request.userId, password: request.password)
            log("NAS: created account for user \(user.formattedId)")
            return encode(returnCode: .registrationSuccess)
        } catch UserManager.Failure.invalidUserId, UserManager.Failure.duplicateUserId {
            return encode(returnCode: .userAlreadyExists)
        } catch {
            return encode(returnCode: .internalServerError)
        }
    }

    // POST /ac action=SVCLOC
    // Authenticates a user and returns a service token + host for PGL ("0000") or DLS ("9000").
    private func handleServiceLocation(_ request: NasRequest) async -> HttpResponse {
        log("NAS: SVCLOC svc=\(request.serviceType ?? "?")")
        guard let user = await userManager.authenticateUser(id: request.userId, password: request.password) else {
            return encode(returnCode: .userNotFound)
        }

        let service: String
        let svchost: String
        switch request.serviceType {
        case "0000": service = "external"; svchost = service
        case "9000": service = "dls1.nintendowifi.net"; svchost = service
        default:     return encode(returnCode: .badRequest)
        }

        let credentials = await userManager.createServiceSession(for: user, service: service, branchCode: "")
        log("NAS: created \(service) session tok=\(credentials.authToken.prefix(10))… user=\(user.formattedId)")

        let response = encodeServiceLocation(statusdata: "Y", svchost: svchost, servicetoken: credentials.authToken)
        log("NAS: SVCLOC svchost=\(svchost) response body(\(response.body.count)B)=\(String(data: response.body, encoding: .utf8) ?? "<non-utf8>")")
        return response
    }

    // Field order matches the original's actual wire output, verified against a live capture.
    private func encodeServiceLocation(statusdata: String, svchost: String, servicetoken: String) -> HttpResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        let pairs: [(String, String)] = [
            ("statusdata",    statusdata),
            ("svchost",       svchost),
            ("servicetoken",  servicetoken),
            ("datetime",      formatter.string(from: Date())),
            ("returncd",      NasReturnCode.success.formatted)
        ]
        return .ok(Data(URLEncodedFormCodec.encode(pairs).utf8))
    }

    // Encodes a NAS response as a URL-encoded form with Base64 values.
    // Every NAS response includes datetime and returncd, in that order, last.
    private func encode(_ pairs: [(String, String)] = [], returnCode: NasReturnCode = .success) -> HttpResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        var all = pairs
        all.append(("datetime", formatter.string(from: Date())))
        all.append(("returncd", returnCode.formatted))
        let bodyString = URLEncodedFormCodec.encode(all)
        log("NAS: response=\(bodyString)")
        return .ok(Data(bodyString.utf8))
    }
}
