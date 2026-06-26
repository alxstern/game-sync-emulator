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

        print("NAS: action=\(nasRequest.action)")

        switch nasRequest.action {
        case "login":       return await handleLogin(nasRequest)
        case "acctcreate":  return await handleCreateAccount(nasRequest)
        case "SVCLOC":      return await handleServiceLocation(nasRequest)
        default:
            print("NAS: unknown action '\(nasRequest.action)'")
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
        print("NAS: created GameSpy session for user \(user.formattedId)")
        return encode([("locator", "gamespy.com"), ("token", credentials.authToken), ("challenge", credentials.challenge)])
    }

    // POST /ac action=acctcreate
    // Registers a new WFC user account.
    private func handleCreateAccount(_ request: NasRequest) async -> HttpResponse {
        do {
            let user = try await userManager.registerUser(id: request.userId, password: request.password)
            print("NAS: created account for user \(user.formattedId)")
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
        guard let user = await userManager.authenticateUser(id: request.userId, password: request.password) else {
            return encode(returnCode: .userNotFound)
        }

        let service: String
        switch request.serviceType {
        case "0000": service = "external"               // Pokémon Global Link
        case "9000": service = "dls1.nintendowifi.net"  // Download Service
        default:     return encode(returnCode: .badRequest)
        }

        let credentials = await userManager.createServiceSession(for: user, service: service, branchCode: "")
        print("NAS: created \(service) session for user \(user.formattedId)")
        return encode([("statusdata", "Y"), ("svchost", service), ("servicetoken", credentials.authToken)])
    }

    // Encodes a NAS response as a URL-encoded form with Base64 values.
    // Every NAS response includes returncd and datetime.
    private func encode(_ pairs: [(String, String)] = [], returnCode: NasReturnCode = .success) -> HttpResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        var all: [(String, String)] = [
            ("returncd", returnCode.formatted),
            ("datetime", formatter.string(from: Date()))
        ]
        all.append(contentsOf: pairs)
        return .ok(Data(URLEncodedFormCodec.encode(all).utf8))
    }
}
