import Foundation

struct DlsHandler: HttpRequestHandler {

    let userManager: UserManager
    let dlcList: DlcList

    func handle(_ request: HttpRequest) async -> HttpResponse {
        let bodyString = String(data: request.body, encoding: .utf8) ?? ""

        // The DS percent-encodes '*' as '%2A' in the body — restore it before Base64 decoding.
        let preprocessed = bodyString.replacingOccurrences(of: "%2A", with: "*")

        guard let fields    = try? URLEncodedFormCodec.parse(preprocessed),
              let dlsRequest = DlsRequest(from: fields) else {
            return .unauthorized()
        }

        guard let session = await userManager.serviceSession(authToken: dlsRequest.serviceToken, service: "dls1.nintendowifi.net") else {
            print("DLS: rejected — service session not found or expired")
            return .unauthorized()
        }

        // Fetch the current user from UserManager to pick up any runtime DLC overrides
        // set by PGL's savedata.download call.
        let user = await userManager.user(id: session.user.id) ?? session.user

        let gameCode = normalizedGameCode(dlsRequest.dlcGameCode)
        let type     = normalizedDlcType(dlsRequest.dlcType)

        print("DLS: action=\(dlsRequest.action) gameCode=\(gameCode) type=\(type)")

        switch dlsRequest.action {
        case "list":     return handleList(dlsRequest, user: user, gameCode: gameCode, type: type)
        case "contents": return handleContents(dlsRequest, user: user, gameCode: gameCode, type: type)
        default:
            print("DLS: unknown action '\(dlsRequest.action)'")
            return .notFound()
        }
    }

    // Returns the tab-separated DLC metadata list the DS uses to learn what to download.
    // If the user has a runtime DLC override for this type (set during PGL dream data download),
    // that single override entry is returned instead of the default list.
    private func handleList(_ request: DlsRequest, user: User, gameCode: String, type: String) -> HttpResponse {
        let dlcs: [Dlc]

        if let override = user.dlcOverride(for: type) {
            dlcs = [override]
        } else {
            dlcs = dlcList.dlcs(gameCode: gameCode, type: type, index: request.dlcIndex)
        }

        let body = Data(dlcList.listString(for: dlcs).utf8)
        return .ok(body)
    }

    // Serves the raw DLC file bytes. Appends a 2-byte LE CRC-16 checksum if the file
    // didn't already have one embedded (determined at DLC load time).
    private func handleContents(_ request: DlsRequest, user: User, gameCode: String, type: String) -> HttpResponse {
        let dlc: Dlc?

        if let override = user.dlcOverride(for: type) {
            dlc = override
        } else {
            guard let name = request.dlcName else { return .notFound() }
            dlc = dlcList.dlc(gameCode: gameCode, type: type, name: name)
        }

        guard let dlc else { return .notFound() }

        guard var fileData = try? Data(contentsOf: dlc.path) else {
            print("DLS: could not read DLC file at \(dlc.path.path)")
            return .internalError()
        }

        if !dlc.checksumEmbedded {
            let checksum = UInt16(dlc.checksum & 0xFFFF)
            fileData.append(UInt8(checksum & 0xFF))
            fileData.append(UInt8(checksum >> 8))
        }

        return .ok(fileData)
    }

    // MARK: - Normalization

    // Japanese (IRAJ) and Korean (IRAK) White versions share the English White (IRAO) DLC folder.
    private func normalizedGameCode(_ code: String) -> String {
        switch code {
        case "IRAJ", "IRAK": return "IRAO"
        default:             return code
        }
    }

    // Region suffixes (_E, _F, _I, _G, _S, _J, _K) are stripped — DLC is stored by base type.
    private func normalizedDlcType(_ type: String) -> String {
        for base in ["CGEAR2", "CGEAR", "ZUKAN", "MUSICAL"] {
            if type.hasPrefix(base + "_") { return base }
        }
        return type
    }
}
