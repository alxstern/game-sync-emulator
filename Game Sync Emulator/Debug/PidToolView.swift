import SwiftUI

struct PidToolView: View {
    let userManager: UserManager
    @Environment(\.dismiss) private var dismiss

    @State private var wfcIdInput = ""
    @State private var friendCodeInput = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("If Game Sync shows error 60000, your GameSpy profile ID is out of sync with the cartridge. Enter the Wi-Fi Connection ID from your DS internet settings and the Friend Code from your in-game Pal Pad, then press Update.")
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Wi-Fi Connection ID")
                        .gridColumnAlignment(.trailing)
                    TextField("XXXX-XXXX-XXXX-XXXX", text: $wfcIdInput)
                        .frame(width: 240)
                }
                GridRow {
                    Text("Friend Code")
                        .gridColumnAlignment(.trailing)
                    TextField("XXXX-XXXX-XXXX", text: $friendCodeInput)
                        .frame(width: 240)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Update") { update() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420)
        .alert(alertMessage, isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.hasPrefix("Done") { dismiss() }
            }
        }
    }

    private func update() {
        let userId = wfcIdInput.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        let fcString = friendCodeInput.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard userId.count == 16, userId.allSatisfy(\.isNumber) else {
            alertMessage = "Please enter a valid Wi-Fi Connection ID (16 digits)."
            showingAlert = true; return
        }
        guard fcString.count == 12, fcString.allSatisfy(\.isNumber) else {
            alertMessage = "Please enter a valid Friend Code (12 digits)."
            showingAlert = true; return
        }
        guard let friendCode = Int64(fcString) else {
            alertMessage = "Friend Code is out of range."
            showingAlert = true; return
        }

        let profileId = Int(friendCode & 0x7FFFFFFF)
        let trimmedUserId = String(userId.prefix(13))

        Task {
            let exists = await userManager.userExists(id: trimmedUserId)
            guard exists else {
                await MainActor.run {
                    alertMessage = "No account found for this Wi-Fi Connection ID. Connect to Game Sync once first."
                    showingAlert = true
                }
                return
            }
            await userManager.setProfileIdOverride(userId: trimmedUserId, profileId: profileId)
            await MainActor.run {
                alertMessage = "Done! Restart your game and use Game Sync again."
                showingAlert = true
            }
        }
    }
}
