import SwiftUI

struct DashboardLoginView: View {
    let playerManager: PlayerManager
    let onLogIn: (Player) -> Void

    @State private var gameSyncId = ""
    @State private var errorMessage: String?
    @State private var showingPidTool = false

    private var localIP: String { NetworkUtility.localIPAddress() }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Dream World Dashboard")
                    .font(.title2.bold())
                Text("Tuck in a Pokémon in-game, then enter your Game Sync ID to continue.\nIt can be found in Game Sync Settings in the game's main menu.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            VStack(spacing: 10) {
                TextField("Game Sync ID", text: $gameSyncId)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 220)
                    .onChange(of: gameSyncId) {
                        gameSyncId = GSIDUtility.sanitizeInput(gameSyncId)
                    }
                    .onSubmit(logIn)

                Button("Log In", action: logIn)
                    .buttonStyle(.borderedProminent)
                    .disabled(gameSyncId.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Spacer()

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                    Text("Set your DS primary DNS to:")
                    Text(localIP)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Button("Trouble connecting? Fix Error 60000") { showingPidTool = true }
                    .buttonStyle(.borderless)
                    .font(.footnote)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .alert("Attention", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showingPidTool) {
            PidToolView(userManager: AppServices.shared.userManager)
        }
    }

    private func logIn() {
        let gsid = gameSyncId
        guard GSIDUtility.isValid(gsid) else {
            errorMessage = "Please enter a valid Game Sync ID."
            return
        }
        Task {
            guard let player = await playerManager.player(gameSyncId: gsid) else {
                errorMessage = "This Game Sync ID does not exist.\nIf you haven't already, please tuck in a Pokémon first."
                return
            }
            guard player.dreamerInfo != nil else {
                errorMessage = "Please use Game Sync to tuck in a Pokémon first."
                return
            }
            onLogIn(player)
        }
    }
}
