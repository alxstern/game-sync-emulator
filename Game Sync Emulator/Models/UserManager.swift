import Foundation

actor UserManager {

    enum Failure: Error {
        case invalidUserId
        case duplicateUserId
        case userNotFound
        case duplicateProfile
    }

    private var users: [String: User]
    private var sessions: [String: ServiceSession] = [:]
    let dataDirectory: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .prettyPrinted
        return e
    }()

    private let decoder = JSONDecoder()

    nonisolated static func isValidUserId(_ id: String) -> Bool {
        id.count == 13 && id.allSatisfy(\.isNumber)
    }

    init(dataDirectory: URL) {
        self.dataDirectory = dataDirectory
        self.users = Self.loadUsers(from: dataDirectory)
        print("Loaded \(users.count) user(s)")
    }

    // nonisolated static so it can be called during init before the actor is fully live.
    private nonisolated static func loadUsers(from directory: URL) -> [String: User] {
        var loaded: [String: User] = [:]
        let dec = JSONDecoder()

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return loaded }

        for file in files {
            guard (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true else { continue }
            do {
                let data = try Data(contentsOf: file)
                let user = try dec.decode(User.self, from: data)
                guard loaded[user.id] == nil else {
                    print("Error: Duplicate user ID \(user.id)")
                    continue
                }
                loaded[user.id] = user
            } catch {
                print("Error loading user at \(file.path): \(error)")
            }
        }

        return loaded
    }

    func saveUser(_ user: User) throws {
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let file = dataDirectory.appendingPathComponent("WFC-\(user.formattedId).json")
        try encoder.encode(user).write(to: file, options: .atomic)
    }

    func saveUsers() {
        for user in users.values { try? saveUser(user) }
    }

    func registerUser(id: String, password: String) throws -> User {
        guard Self.isValidUserId(id) else { throw Failure.invalidUserId }
        guard users[id] == nil       else { throw Failure.duplicateUserId }
        let user = User(id: id, password: password)
        try saveUser(user)
        users[id] = user
        return user
    }

    func authenticateUser(id: String, password: String) -> User? {
        guard let user = users[id], user.password == password else { return nil }
        return user
    }

    // Call this after a handler modifies a user's state to persist the change.
    func updateUser(_ user: User) throws {
        guard users[user.id] != nil else { throw Failure.userNotFound }
        users[user.id] = user
        try saveUser(user)
    }

    func createProfile(branchCode: String, forUserId userId: String) throws -> GameProfile {
        guard users[userId] != nil                            else { throw Failure.userNotFound }
        guard users[userId]!.profile(for: branchCode) == nil else { throw Failure.duplicateProfile }

        let profile = GameProfile(id: Int.random(in: 0..<Int(Int32.max)))
        users[userId]!.profiles[branchCode] = profile
        try saveUser(users[userId]!)
        return profile
    }

    func createServiceSession(for user: User, service: String, branchCode: String) -> ServiceCredentials {
        var authToken: String
        repeat { authToken = "NDS" + CredentialGenerator.generateAuthToken(length: 96) }
        while sessions[authToken] != nil

        let challenge = CredentialGenerator.generateChallenge(length: 8)
        sessions[authToken] = ServiceSession(
            user: user, service: service, branchCode: branchCode,
            challengeHash: MD5.digest(challenge), duration: 30 * 60
        )
        return ServiceCredentials(authToken: authToken, challenge: challenge)
    }

    func serviceSession(authToken: String, service: String) -> ServiceSession? {
        guard let session = sessions[authToken] else { return nil }
        if session.isExpired {
            sessions.removeValue(forKey: authToken)
            return nil
        }
        return session.service == service ? session : nil
    }

    func user(id: String) -> User?      { users[id] }
    func userExists(id: String) -> Bool  { users[id] != nil }
    var allUsers: [User]                { Array(users.values) }
}