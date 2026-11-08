import Foundation

/// A socket that answers every request line with `reply`, as an app of another version would, for the
/// built `chronobar` to reach through `CHRONOBAR_SOCKET`. It answers on its own thread, so a test can wait
/// for the command without holding it up.
final class FakeApp: @unchecked Sendable {
    /// Under /tmp, not the per-user temp folder: a socket path must fit in 104 bytes.
    let url = URL(fileURLWithPath: "/tmp/cb-\(UUID().uuidString.prefix(8)).sock")
    private let listener: Int32

    init(reply: Data) throws {
        listener = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { path in
            path.copyBytes(from: url.path.utf8.prefix(path.count - 1))
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, listen(listener, 8) == 0 else {
            close(listener)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let listener = listener
        Thread.detachNewThread {
            while true {
                let client = accept(listener, nil, nil)
                guard client >= 0 else { return }
                Self.answer(client, with: reply)
            }
        }
    }

    deinit {
        close(listener)
        unlink(url.path)
    }

    /// Reads `client`'s request lines, answering each with `reply` and a newline, until it closes.
    private static func answer(_ client: Int32, with reply: Data) {
        defer { close(client) }
        var line = Data()
        var byte: UInt8 = 0
        while read(client, &byte, 1) == 1 {
            guard byte == UInt8(ascii: "\n") else {
                line.append(byte)
                continue
            }
            line = Data()
            let answer = reply + Data("\n".utf8)
            _ = answer.withUnsafeBytes { write(client, $0.baseAddress, answer.count) }
        }
    }
}

/// The built `chronobar`, run as a script would run it.
enum Command {
    struct Run {
        let status: Int32
        let output: String
        let error: String
    }

    /// `chronobar-cli` beside the test bundle, as `swift test` builds it.
    static let url: URL = {
        let products = Bundle.allBundles.first { $0.bundleURL.pathExtension == "xctest" }?
            .bundleURL.deletingLastPathComponent()
        return (products ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/debug"))
            .appendingPathComponent("chronobar-cli")
    }()

    /// Runs the command with `arguments`, reaching `socket` and never the app, with `input` on standard
    /// input.
    static func run(_ arguments: [String], socket: URL, input: Data = Data()) throws -> Run {
        let process = Process()
        process.executableURL = url
        process.arguments = arguments
        process.environment = ["CHRONOBAR_SOCKET": socket.path, "PATH": "/usr/bin:/bin",
                               "HOME": NSHomeDirectory()]
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        stdin.fileHandleForWriting.write(input)
        try stdin.fileHandleForWriting.close()
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let error = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Run(status: process.terminationStatus, output: String(decoding: output, as: UTF8.self),
                   error: String(decoding: error, as: UTF8.self))
    }

    /// `chronobar mcp` sent `messages`, one JSON-RPC message a line, with its input kept open as a client
    /// keeps it until the reply with `id` arrives, or 10 seconds pass: the server stops at the end of its
    /// input without answering what it read. The JSON-RPC replies, in order.
    static func mcp(_ messages: [String], socket: URL, until id: Int) throws -> [[String: Any]] {
        let process = Process()
        process.executableURL = url
        process.arguments = ["mcp"]
        process.environment = ["CHRONOBAR_SOCKET": socket.path, "PATH": "/usr/bin:/bin",
                               "HOME": NSHomeDirectory()]
        let stdin = Pipe(), stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        try process.run()
        stdin.fileHandleForWriting.write(Data(messages.map { $0 + "\n" }.joined().utf8))
        var replies: [[String: Any]] = []
        var pending = Data()
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline, !replies.contains(where: { $0["id"] as? Int == id }) {
            let chunk = stdout.fileHandleForReading.availableData
            guard !chunk.isEmpty else { break }
            pending += chunk
            while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
                if let reply = try? JSONSerialization.jsonObject(with: pending[..<newline]) as? [String: Any] {
                    replies.append(reply)
                }
                pending = Data(pending[pending.index(after: newline)...])
            }
        }
        try stdin.fileHandleForWriting.close()
        process.waitUntilExit()
        return replies
    }
}
