import Foundation

// Drop-in replacement for print() — also routes to LogStore for the in-app debug view
// and to a file, since LogStore only keeps the last 500 entries.
func log(_ message: String) {
    print(message)
    DispatchQueue.main.async {
        LogStore.shared.append(message)
    }
    FileLog.shared.append(message)
}

// Appends every log line to ~/Library/Application Support/Entralinked/debug.log.
final class FileLog: @unchecked Sendable {
    static let shared = FileLog()

    private let queue = DispatchQueue(label: "FileLog")
    private let handle: FileHandle?
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Entralinked", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = base.appendingPathComponent("debug.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: url)
        handle?.seekToEndOfFile()
    }

    func append(_ message: String) {
        queue.async { [self] in
            let line = "\(formatter.string(from: Date()))  \(message)\n"
            handle?.write(Data(line.utf8))
        }
    }
}
