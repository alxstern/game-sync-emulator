import SwiftUI

struct DebugLogView: View {
    @ObservedObject private var logStore = LogStore.shared

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
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
        .frame(minWidth: 640, minHeight: 400)
    }
}
