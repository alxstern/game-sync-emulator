import Foundation

// Drives the per-connection GameSpy auth state machine.
// Owned by GameSpyConnection (an actor), so mutation is already serialized.
struct GameSpyHandler {

    enum State {
        case awaitingLogin
        case authenticated(user: User, profile: GameProfile, branchCode: String, sessKey: Int)
    }

    private var state: State = .awaitingLogin
    private let serverChallenge: String

    nonisolated init() {
        serverChallenge = CredentialGenerator.generateChallenge(length: 8)
    }

    // Sent immediately on TCP connect.
    nonisolated var connectMessage: String {
        GameSpyChallengeMessage(challenge: serverChallenge).wireFormat
    }

    // Dispatches an incoming message and returns the response to send, or nil for no reply.
    mutating func handle(_ fields: [String: String],
                         userManager: UserManager,
                         playerManager: PlayerManager) async -> String? {
        if fields["login"] != nil {
            return await handleLogin(GameSpyLoginRequest(from: fields), userManager: userManager)
        } else if fields["getprofile"] != nil {
            return handleProfileRequest(GameSpyProfileRequest(from: fields))
        } else if fields["updatepro"] != nil {
            return await handleProfileUpdate(GameSpyProfileUpdateRequest(from: fields), userManager: userManager)
        } else if fields["logout"] != nil || fields["keepalive"] != nil || fields["status"] != nil {
            return nil
        }
        print("GameSpy: unrecognized message keys: \(fields.keys.sorted())")
        return nil
    }

    private mutating func handleLogin(_ request: GameSpyLoginRequest?,
                                      userManager: UserManager) async -> String {
        guard let request else {
            return GameSpyErrorMessage(code: 0, message: "Invalid login request").wireFormat
        }

        guard let session = await userManager.serviceSession(authToken: request.authToken, service: "gamespy") else {
            return GameSpyErrorMessage(code: 256, message: "Authentication failed").wireFormat
        }

        let user = session.user
        let branchCode = session.branchCode

        let profile: GameProfile
        if let existing = user.profile(for: branchCode) {
            profile = existing
        } else {
            do {
                profile = try await userManager.createProfile(branchCode: branchCode, forUserId: user.id)
            } catch {
                return GameSpyErrorMessage(code: 0, message: "Failed to create profile").wireFormat
            }
        }

        let sessKey = Int.random(in: 1..<Int(Int32.max))
        state = .authenticated(user: user, profile: profile, branchCode: branchCode, sessKey: sessKey)

        return GameSpyLoginResponse(
            sessKey: sessKey,
            proof: computeProof(challengeHash: session.challengeHash, clientChallenge: request.clientChallenge),
            userId: user.id,
            profileId: profile.id,
            uniqueNick: user.formattedId,
            id: request.id
        ).wireFormat
    }

    private func handleProfileRequest(_ request: GameSpyProfileRequest?) -> String {
        guard case .authenticated(let user, let profile, _, _) = state else {
            return GameSpyErrorMessage(code: 0, message: "Not authenticated").wireFormat
        }
        guard let request else {
            return GameSpyErrorMessage(code: 0, message: "Invalid profile request").wireFormat
        }
        return GameSpyProfileResponse(
            userId: user.id,
            profile: profile,
            uniqueNick: user.formattedId,
            id: request.id
        ).wireFormat
    }

    private mutating func handleProfileUpdate(_ request: GameSpyProfileUpdateRequest?,
                                              userManager: UserManager) async -> String? {
        guard case .authenticated(var user, var profile, let branchCode, let sessKey) = state,
              let request else { return nil }
        profile.firstName = request.firstName ?? profile.firstName
        profile.lastName  = request.lastName  ?? profile.lastName
        profile.aimName   = request.aimName   ?? profile.aimName
        profile.zipCode   = request.zipCode   ?? profile.zipCode
        user.profiles[branchCode] = profile
        state = .authenticated(user: user, profile: profile, branchCode: branchCode, sessKey: sessKey)
        try? await userManager.updateUser(user)
        return nil
    }

    // TODO: verify exact proof formula against DS expectations during hardware testing.
    private func computeProof(challengeHash: String, clientChallenge: String) -> String {
        MD5.digest(challengeHash + String(repeating: " ", count: 48) + clientChallenge + serverChallenge + challengeHash)
    }
}