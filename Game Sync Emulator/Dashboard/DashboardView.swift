import SwiftUI

struct DashboardView: View {
    let playerManager: PlayerManager
    let dlcList: DlcList

    @State private var loggedInPlayer: Player?

    var body: some View {
        if let player = loggedInPlayer {
            DashboardContentView(playerManager: playerManager, dlcList: dlcList, player: player) {
                loggedInPlayer = nil
            }
        } else {
            DashboardLoginView(playerManager: playerManager) { player in
                loggedInPlayer = player
            }
        }
    }
}
