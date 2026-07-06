import SwiftUI
import AppKit

struct DebugLogView: View {
    let userManager: UserManager
    @ObservedObject private var logStore = LogStore.shared
    @State private var showingPidTool = false

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private var localIP: String { NetworkUtility.localIPAddress() }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "wifi")
                Text("Set your DS primary DNS to:")
                Text(localIP)
                    .fontWeight(.bold)
                    .textSelection(.enabled)
                Spacer()
                Button("Fix Error 60000") { showingPidTool = true }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.orange)
                Button("Copy Log") {
                    let text = logStore.entries.map { entry in
                        "\(Self.timestampFormatter.string(from: entry.timestamp))  \(entry.message)"
                    }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .buttonStyle(.borderless)
            }
            .font(.system(.body, design: .monospaced))
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.12))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(logStore.entries) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(Self.timestampFormatter.string(from: entry.timestamp))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 86, alignment: .leading)
                                Text(entry.message)
                                    .foregroundStyle(.primary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 1)
                            .id(entry.id)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onChange(of: logStore.entries.count) { _, _ in
                    if let last = logStore.entries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 640, minHeight: 400)
        .sheet(isPresented: $showingPidTool) {
            PidToolView(userManager: userManager)
        }
    }
}
