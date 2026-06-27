import Foundation
import NIOHTTP1

struct PglHandler: HttpRequestHandler {

    private static let authUsername = "pokemon"
    private static let authPassword = "2Phfv9MY"

    let userManager: UserManager
    let playerManager: PlayerManager
    let dlcList: DlcList
    let configuration: Configuration

    func handle(_ request: HttpRequest) async -> HttpResponse {
        guard let creds = request.basicAuthCredentials,
              creds.username == Self.authUsername,
              creds.password == Self.authPassword else {
            print("PGL: rejected — bad credentials")
            return .unauthorized()
        }

        guard let fields = try? URLEncodedFormCodec.parse(request.rawQueryString, base64Values: false),
              let pglRequest = PglRequest(from: fields) else {
            return .unauthorized()
        }

        guard let session = await userManager.serviceSession(authToken: pglRequest.token, service: "external") else {
            print("PGL: rejected — service session not found or expired")
            return .unauthorized()
        }

        print("PGL: \(request.method) type=\(pglRequest.type) gsid=\(pglRequest.gameSyncId ?? "nil")")

        switch request.method {
        case .GET:  return await handleGet(pglRequest, user: session.user)
        case .POST: return await handlePost(pglRequest, body: request.body)
        default:    return .notFound()
        }
    }

    // MARK: - GET dispatch

    private func handleGet(_ request: PglRequest, user: User) async -> HttpResponse {
        switch request.type {
        case "sleepily.bitlist":   return await handleGetSleepyList(request)
        case "account.playstatus": return await handleGetAccountStatus(request)
        case "savedata.download":  return await handleDownloadSaveData(request, user: user)
        case "savedata.getbw":     return await handleMemoryLink(request, user: user)
        default:
            print("PGL: unknown GET type '\(request.type)'")
            return .notFound()
        }
    }

    // MARK: - POST dispatch

    private func handlePost(_ request: PglRequest, body: Data) async -> HttpResponse {
        switch request.type {
        case "savedata.upload":          return await handleUploadSaveData(request, body: body)
        case "savedata.download.finish": return await handleDownloadSaveDataFinish(request)
        case "account.create.upload":    return await handleCreateAccount(request, body: body)
        case "account.createdata":       return await handleCreateData(body: body)
        default:
            print("PGL: unknown POST type '\(request.type)'")
            return .notFound()
        }
    }

    // MARK: - GET sleepily.bitlist
    // Returns a 128-byte bitset with a bit set for every species 1–649.
    private func handleGetSleepyList(_ request: PglRequest) async -> HttpResponse {
        guard let gsid = request.gameSyncId,
              await playerManager.playerExists(gameSyncId: gsid) else {
            return pglOk(status: 1) // Unauthorized
        }

        var bitlist = [UInt8](repeating: 0, count: 128)
        for species in 1...649 {
            bitlist[species / 8] |= 1 << (species % 8)
        }

        var body = statusData(0)
        body.append(contentsOf: bitlist)
        return .ok(body)
    }

    // MARK: - GET account.playstatus
    // Returns status code 8 if no account exists (DS will call account.create.upload next).
    // Otherwise writes the player's current status ordinal as a 2-byte LE short.
    private func handleGetAccountStatus(_ request: PglRequest) async -> HttpResponse {
        guard let gsid = request.gameSyncId,
              let player = await playerManager.player(gameSyncId: gsid) else {
            return pglOk(status: 8)
        }

        var writer = statusWriter(0)
        writer.writeShort(Int16(player.status.wireOrdinal))
        return .ok(writer.data)
    }

    // MARK: - GET savedata.download
    // Sends the full Dream World payload. All data follows a 128-byte status header.
    // If the player is awake the header is sent alone (nothing to download).
    private func handleDownloadSaveData(_ request: PglRequest, user: User) async -> HttpResponse {
        guard let gsid = request.gameSyncId,
              let player = await playerManager.player(gameSyncId: gsid) else {
            return pglOk(status: 1)
        }

        print("PGL: player \(gsid) downloading save data")
        var writer = statusWriter(0)

        // If awake, send the header but no payload — the DS uses this to confirm wake-up.
        guard player.status != .awake, let version = player.gameVersion else {
            return .ok(writer.data)
        }

        let encounters = player.encounters
        let items      = player.items
        let decorList  = player.decor
        var user       = user

        // 4-byte counter stored in the save file. If unchanged on next sync, the DS skips applying
        // dream data. Using a random value ensures the data is always applied.
        writer.writeInt(Int32.random(in: 0..<Int32.max))

        // Encounters (up to 10, 8 bytes each: species u16, move u16, form u8, gender u8, anim u8, pad u8)
        for encounter in encounters {
            writer.writeShort(Int16(encounter.species))
            writer.writeShort(Int16(encounter.move))
            writer.writeBytes(UInt8(encounter.form), count: 1)
            writer.writeBytes(UInt8(encounter.gender.wireOrdinal), count: 1)
            writer.writeBytes(UInt8(encounter.animation.wireOrdinal), count: 1)
            writer.writeBytes(0, count: 1)
        }
        writer.writeBytes(0, count: (10 - encounters.count) * 8)

        // Misc flags and DLC slot indices
        writer.writeShort(Int16(player.levelsGained))
        writer.writeBytes(0, count: 1) // unknown
        writer.writeBytes(UInt8(dlcIndex(for: player.musical,  type: "MUSICAL", customFile: player.musicalFile, user: &user)), count: 1)
        let cgearType = version.isVersion2 ? "CGEAR2" : "CGEAR"
        writer.writeBytes(UInt8(dlcIndex(for: player.cgearSkin, type: cgearType, customFile: player.cgearFile, user: &user)), count: 1)
        writer.writeBytes(UInt8(dlcIndex(for: player.dexSkin,  type: "ZUKAN",   customFile: player.dexFile,    user: &user)), count: 1)
        writer.writeBytes(decorList.isEmpty ? 0 : 1, count: 1)
        writer.writeBytes(0, count: 1) // must be zero

        // Flush DLC override changes to UserManager so DLS can serve the right files.
        try? await userManager.updateUser(user)

        // Item IDs (up to 20, 2 bytes each) then item quantities (up to 20, 1 byte each)
        for item in items { writer.writeShort(Int16(item.id)) }
        writer.writeBytes(0, count: (20 - items.count) * 2)
        for item in items { writer.writeBytes(UInt8(min(item.quantity, 255)), count: 1) }
        writer.writeBytes(0, count: 20 - items.count)

        // Decor (up to 5 entries, 26 bytes each: id u16, name UTF-16LE padded to 24 bytes with 0xFF)
        for decor in decorList {
            writer.writeShort(Int16(decor.id))
            let nameBytes = Array(decor.name.data(using: .utf16LittleEndian) ?? Data())
            let toWrite = min(24, nameBytes.count)
            writer.data.append(contentsOf: nameBytes[..<toWrite])
            if nameBytes.count < 24 { writer.writeBytes(0xFF, count: 24 - nameBytes.count) }
        }
        for _ in 0..<(5 - decorList.count) {
            writer.writeShort(0x7E) // Default/empty slot marker
            writer.writeBytes(0, count: 24)
        }
        writer.writeShort(0) // unknown

        // BW2 only: Join Avenue visitors (up to 12, 32 bytes each) + 4-byte trailer
        if version.isVersion2 {
            let visitors = player.avenueVisitors
            for visitor in visitors {
                let nameBytes = Array(visitor.name.data(using: .utf16LittleEndian) ?? Data())
                writer.data.append(contentsOf: nameBytes[..<min(14, nameBytes.count)])
                let namePad = 16 - nameBytes.count
                if namePad > 0 { writer.writeBytes(0xFF, count: namePad) }

                // visitorType encodes the trainer class and personality index.
                // shopType ordinal is offset so slot 0 means different shops for different visitor types.
                let visitorType = visitor.type.clientId + visitor.personality * 8
                writer.writeBytes(UInt8(truncatingIfNeeded: visitorType), count: 1)
                writer.writeBytes(UInt8(visitor.shopType.wireOrdinal + (7 - visitorType * 2 % 7)), count: 1)
                writer.writeShort(0)
                writer.writeInt(1)  // Ignored by DS if 0
                writer.writeBytes(UInt8(visitor.countryCode), count: 1)
                writer.writeBytes(UInt8(visitor.stateProvinceCode), count: 1)
                writer.writeBytes(UInt8(visitor.gameVersion.languageCode), count: 1)
                writer.writeBytes(UInt8(visitor.gameVersion.romCode), count: 1)
                writer.writeBytes(visitor.type.isFemale ? 1 : 0, count: 1)
                writer.writeBytes(0, count: 1)
                writer.writeShort(Int16(visitor.dreamerSpecies))
            }
            writer.writeBytes(0, count: (12 - visitors.count) * 32)
            writer.writeInt(0) // BW2 total after status header = 672 bytes
        }

        return .ok(writer.data)
    }

    // MARK: - GET savedata.getbw
    // Memory Link: a BW2 game downloads a BW1 save file to import data.
    private func handleMemoryLink(_ request: PglRequest, user: User) async -> HttpResponse {
        guard let gsid = request.gameSyncId, GSIDUtility.isValid(gsid) else {
            return pglOk(status: 8)
        }
        guard let player = await playerManager.player(gameSyncId: gsid) else {
            return pglOk(status: 8)
        }
        guard let version = player.gameVersion else {
            return pglOk(status: 5) // No save data exists
        }
        guard !version.isVersion2 else {
            return pglOk(status: 10) // Must be a BW1 save
        }
        guard let saveURL = player.saveFile,
              let saveData = try? Data(contentsOf: saveURL) else {
            return pglOk(status: 5)
        }

        print("PGL: user \(user.formattedId) memory linking with player \(gsid)")
        var body = statusData(0)
        body.append(saveData)
        return .ok(body)
    }

    // MARK: - POST savedata.upload
    // Tuck-in: stores the save binary, reads dreamer Pokémon info, marks the player SLEEPING.
    private func handleUploadSaveData(_ request: PglRequest, body: Data) async -> HttpResponse {
        guard let gsid = request.gameSyncId,
              var player = await playerManager.player(gameSyncId: gsid) else {
            return pglOk(status: 1)
        }

        print("PGL: player \(gsid) uploading save data")

        if player.status != .awake {
            print("PGL warning: player \(gsid) is not AWAKE — existing dream info will be overwritten")
        }

        do {
            try await playerManager.storeSaveData(body, for: gsid)
        } catch {
            return pglOk(status: 4) // Save data IO error
        }

        // Dreamer Pokémon data starts at 0x1D300 + 8 bytes offset in the save file.
        var dreamerInfo: PokemonInfo? = nil
        let pkmnOffset = 0x1D308
        if body.count >= pkmnOffset + 236 {
            dreamerInfo = try? PokemonInfoReader.read(from: body.subdata(in: pkmnOffset..<(pkmnOffset + 236)))
        }

        player.status      = .sleeping
        player.gameVersion = request.gameVersion
        player.dreamerInfo = dreamerInfo

        do {
            try await playerManager.updatePlayer(player)
        } catch {
            print("PGL: failed to save player \(gsid): \(error)")
            return .internalError()
        }

        return pglOk(status: 0)
    }

    // MARK: - POST savedata.download.finish
    // Confirms wake-up. Clears dream info if clearPlayerDreamInfoOnWake is set.
    private func handleDownloadSaveDataFinish(_ request: PglRequest) async -> HttpResponse {
        guard let gsid = request.gameSyncId,
              var player = await playerManager.player(gameSyncId: gsid) else {
            return pglOk(status: 1)
        }

        if configuration.clearPlayerDreamInfoOnWake {
            player.resetDreamInfo()
            do {
                try await playerManager.updatePlayer(player)
            } catch {
                print("PGL: failed to save player \(gsid): \(error)")
                return .internalError()
            }
        }

        return pglOk(status: 0)
    }

    // MARK: - POST account.create.upload
    // First-time registration: creates the player record and stores the initial save file.
    private func handleCreateAccount(_ request: PglRequest, body: Data) async -> HttpResponse {
        guard let gsid = request.gameSyncId, GSIDUtility.isValid(gsid) else {
            return pglOk(status: 8) // Invalid GSID
        }
        guard !(await playerManager.playerExists(gameSyncId: gsid)) else {
            return pglOk(status: 2) // Duplicate GSID
        }

        do {
            _ = try await playerManager.registerPlayer(gameSyncId: gsid, gameVersion: request.gameVersion)
        } catch {
            return pglOk(status: 3) // Registration error
        }

        do {
            try await playerManager.storeSaveData(body, for: gsid)
        } catch {
            return pglOk(status: 4) // Save data IO error
        }

        return pglOk(status: 0)
    }

    // MARK: - POST account.createdata
    // Japanese version quirk: GSID arrives as a null-padded decimal integer in the body,
    // not via the usual query parameter. No save file is included.
    private func handleCreateData(body: Data) async -> HttpResponse {
        let bodyString = String(data: body, encoding: .utf8) ?? ""
        let stripped   = bodyString.replacingOccurrences(of: "\0", with: "")

        guard let pid = Int32(stripped) else { return pglOk(status: 8) }

        let gsid = GSIDUtility.stringify(pid)
        guard GSIDUtility.isValid(gsid) else { return pglOk(status: 8) }
        guard !(await playerManager.playerExists(gameSyncId: gsid)) else { return pglOk(status: 2) }

        do {
            _ = try await playerManager.registerPlayer(gameSyncId: gsid)
        } catch {
            return pglOk(status: 3)
        }

        return pglOk(status: 0)
    }

    // MARK: - Helpers

    // Every PGL response starts with a 4-byte LE status code followed by 124 zero bytes.
    private func statusWriter(_ status: Int32) -> LittleEndianWriter {
        var writer = LittleEndianWriter()
        writer.writeInt(status)
        writer.writeBytes(0, count: 124)
        return writer
    }

    private func statusData(_ status: Int32) -> Data { statusWriter(status).data }
    private func pglOk(status: Int32) -> HttpResponse { .ok(statusData(status)) }

    // Returns the DLC slot index for a player's chosen DLC, and updates the user's runtime override
    // so that a subsequent DLS request can serve the correct file.
    // Returns 0 when no DLC is selected; 1+ for a named or custom DLC slot.
    private func dlcIndex(for name: String?, type: String, customFile: URL?, user: inout User) -> Int {
        if name == "custom", let customFile {
            let size = (try? FileManager.default.attributesOfItem(atPath: customFile.path)[.size] as? Int) ?? 0
            let dlc  = Dlc(path: customFile, name: "custom", gameCode: "IRAO",
                           type: type, index: 1, projectedSize: size, checksum: 0, checksumEmbedded: true)
            user.setDlcOverride(dlc, for: type)
            return 1
        } else {
            user.setDlcOverride(nil, for: type)
            return dlcList.index(gameCode: "IRAO", type: type, name: name ?? "none")
        }
    }
}

// MARK: - Wire ordinals
// These must match the Java enum declaration order exactly — the DS interprets them as integers.

private extension PlayerStatus {
    var wireOrdinal: Int {
        switch self {
        case .awake:     return 0
        case .sleeping:  return 1
        case .dreaming:  return 2
        case .wakeReady: return 3
        }
    }
}

private extension PokemonGender {
    var wireOrdinal: Int {
        switch self {
        case .male:       return 0
        case .female:     return 1
        case .genderless: return 2 // treated as random gender in-game
        }
    }
}

private extension DreamAnimation {
    var wireOrdinal: Int {
        switch self {
        case .lookAround:           return 0
        case .walkAround:           return 1
        case .walkLookAround:       return 2
        case .walkVertically:       return 3
        case .walkHorizontally:     return 4
        case .walkLookHorizontally: return 5
        case .spinRight:            return 6
        case .spinLeft:             return 7
        }
    }
}

private extension AvenueShopType {
    var wireOrdinal: Int {
        switch self {
        case .raffle:  return 0
        case .florist: return 1
        case .salon:   return 2
        case .antique: return 3
        case .dojo:    return 4
        case .cafe:    return 5
        case .market:  return 6
        }
    }
}
