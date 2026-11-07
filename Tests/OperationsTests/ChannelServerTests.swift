import Foundation
import Testing
import ChronobarOperations

/// The socket file's life: the app removes its own socket when it stops, replaces one a crashed run left,
/// and never takes over a socket another running copy listens on.
@Suite final class ChannelServerTests {
    /// Under /tmp, not the per-user temp folder: a socket path must fit in 104 bytes.
    let url: URL = {
        let folder = URL(fileURLWithPath: "/tmp/cb-\(UUID().uuidString.prefix(8))", isDirectory: true)
        return Channel.socketURL(storageRoot: folder)
    }()

    let echo: @MainActor @Sendable (Data) -> Data = { $0 }

    deinit { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    @Test func stoppingRemovesTheSocketFile() throws {
        let server = try ChannelServer(url: url, respond: echo)
        #expect(FileManager.default.fileExists(atPath: url.path))

        server.stop()

        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func stoppingTwiceLeavesALaterServersSocketAlone() throws {
        let first = try ChannelServer(url: url, respond: echo)
        first.stop()
        let second = try ChannelServer(url: url, respond: echo)
        defer { second.stop() }

        first.stop()

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(throws: Never.self) { try ChannelClient(url: url) }
    }

    @Test func stoppingLeavesAnotherSocketAtThePathAlone() throws {
        let first = try ChannelServer(url: url, respond: echo)
        // Someone removed the file while it ran, and another copy started there.
        unlink(url.path)
        let second = try ChannelServer(url: url, respond: echo)
        defer { second.stop() }

        first.stop()

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(throws: Never.self) { try ChannelClient(url: url) }
    }

    @Test func startingReplacesASocketACrashedRunLeft() throws {
        try leaveStaleSocket(at: url)
        #expect(throws: Channel.Failure.self) { try ChannelClient(url: url) }

        let server = try ChannelServer(url: url, respond: echo)
        defer { server.stop() }

        #expect(throws: Never.self) { try ChannelClient(url: url) }
    }

    @Test func startingRefusesASocketAnotherCopyListensOn() throws {
        let running = try ChannelServer(url: url, respond: echo)
        defer { running.stop() }

        #expect {
            try ChannelServer(url: url, respond: echo)
        } throws: { error in
            (error as? Channel.Failure)?.code == EADDRINUSE
                && "\(error)".contains("another copy of Chronobar is listening")
        }
        #expect(throws: Never.self) { try ChannelClient(url: url) }
    }

    /// A socket file with nothing listening, as a run that crashed leaves it.
    private func leaveStaleSocket(at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in
            Array(url.path.utf8CString).withUnsafeBytes { bytes.copyMemory(from: $0) }
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        close(fd)
        #expect(bound == 0)
    }
}
