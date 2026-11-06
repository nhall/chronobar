import Foundation
import ChronobarCore

/// The Unix domain socket between the app and the `chronobar` command: `chronobar.sock` in the data folder,
/// readable and writable by its owner only. Each connection carries any number of request lines, each
/// answered in turn with one response line (`Wire`). Not covered by `swift test`; the README's checklist
/// tries it by hand.
public enum Channel {
    public static let socketName = "chronobar.sock"

    public static func socketURL(storageRoot: URL) -> URL {
        storageRoot.appendingPathComponent(socketName)
    }

    /// The socket of `copy`, where the `chronobar` command looks for the app.
    public static func socketURL(of copy: BuildVariant.Copy) -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return socketURL(storageRoot: applicationSupport.appendingPathComponent(copy.dataFolder, isDirectory: true))
    }

    /// A socket call the system refused, with its `errno`.
    public struct Failure: Error, CustomStringConvertible {
        public let call: String
        public let code: Int32

        init(_ call: String, _ code: Int32 = errno) {
            self.call = call
            self.code = code
        }

        /// Nothing listens there: no socket file, or one a stopped app left behind.
        public var nobodyListening: Bool { code == ENOENT || code == ECONNREFUSED }

        public var description: String { "\(call): \(String(cString: strerror(code)))" }
    }

    /// The longest line either end reads, so a runaway peer can't grow a buffer without limit.
    static let maxLine = 1 << 20

    /// `url` as a socket address, refused if the path is longer than one can hold (104 bytes).
    static func address(_ url: URL) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = Array(url.path.utf8CString)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.count <= capacity else { throw Failure("socket path too long (\(url.path))", ENAMETOOLONG) }
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in
            path.withUnsafeBytes { bytes.copyMemory(from: $0) }
        }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        return address
    }

    /// A new stream socket that won't raise SIGPIPE when its peer has gone.
    static func makeSocket() throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure("socket") }
        noSigPipe(fd)
        return fd
    }

    static func noSigPipe(_ fd: Int32) {
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    }

    /// Writes all of `data`.
    static func write(_ data: Data, to fd: Int32) throws {
        try data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            var offset = 0
            while offset < bytes.count {
                let written = Darwin.write(fd, bytes.baseAddress! + offset, bytes.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw Failure("write")
                }
                offset += written
            }
        }
    }
}

/// Reads newline-terminated lines from a socket.
struct LineReader {
    let fd: Int32
    private var buffer = Data()

    init(fd: Int32) {
        self.fd = fd
    }

    /// The next line without its newline; nil once the peer closes or sends a line over `Channel.maxLine`.
    mutating func next() throws -> Data? {
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            if let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[buffer.startIndex..<newline]
                buffer = Data(buffer[buffer.index(after: newline)...])
                return Data(line)
            }
            guard buffer.count <= Channel.maxLine else { return nil }
            let count = read(fd, &chunk, chunk.count)
            if count < 0 {
                if errno == EINTR { continue }
                // The receive timeout passed.
                if errno == EAGAIN { throw Channel.Failure("read", ETIMEDOUT) }
                throw Channel.Failure("read")
            }
            if count == 0 { return nil }
            buffer.append(contentsOf: chunk[0..<count])
        }
    }
}

/// The app's end: listens on the socket and answers each line on the main actor, where Core lives, so
/// requests take their turn with the Panel's own changes and the app stays the only writer.
public final class ChannelServer: @unchecked Sendable {
    private let url: URL
    private let listener: Int32

    /// Listens at `url`, replacing a socket a previous run left there. `respond` answers one request line
    /// with one response line (`Operations.respond(to:)`).
    public init(url: URL, respond: @escaping @MainActor @Sendable (Data) -> Data) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        unlink(url.path)
        var address = try Channel.address(url)
        listener = try Channel.makeSocket()
        // Owner-only from the moment the file exists: the umask applies to the socket `bind` makes.
        let mask = umask(0o077)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        let bindError = errno
        umask(mask)
        guard bound == 0 else {
            close(listener)
            throw Channel.Failure("bind \(url.path)", bindError)
        }
        chmod(url.path, 0o600)
        guard listen(listener, 16) == 0 else {
            let failure = Channel.Failure("listen")
            close(listener)
            throw failure
        }
        let listener = listener
        Thread.detachNewThread {
            while true {
                let client = accept(listener, nil, nil)
                if client < 0 {
                    if errno == EINTR || errno == ECONNABORTED { continue }
                    return
                }
                Channel.noSigPipe(client)
                Thread.detachNewThread { Self.serve(client, respond: respond) }
            }
        }
    }

    /// Answers `client`'s lines until it closes the connection.
    private static func serve(_ client: Int32, respond: @escaping @MainActor @Sendable (Data) -> Data) {
        defer { close(client) }
        var lines = LineReader(fd: client)
        while let line = try? lines.next() {
            guard !line.allSatisfy({ $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: "\r") }) else { continue }
            let reply = onMainRunLoop { respond(line) }
            guard (try? Channel.write(reply, to: client)) != nil else { return }
        }
    }

    /// Runs `work` on the main thread and waits for it. Through the main run loop in its common modes, not
    /// the main dispatch queue: an alert's modal loop (the idle alert's `runModal`) can run inside a main
    /// queue block, which holds every other main queue block until the alert closes, while the run loop
    /// keeps serving its common modes.
    private static func onMainRunLoop(_ work: @escaping @MainActor @Sendable () -> Data) -> Data {
        final class Reply: @unchecked Sendable {
            var data = Data()
        }
        let reply = Reply()
        let done = DispatchSemaphore(value: 0)
        let main = CFRunLoopGetMain()
        CFRunLoopPerformBlock(main, CFRunLoopMode.commonModes.rawValue) {
            reply.data = MainActor.assumeIsolated { work() }
            done.signal()
        }
        CFRunLoopWakeUp(main)
        done.wait()
        return reply.data
    }

    /// Stops listening and removes the socket file.
    public func stop() {
        close(listener)
        unlink(url.path)
    }
}

/// The `chronobar` command's end: one connection to the app.
public final class ChannelClient {
    private let fd: Int32
    private var lines: LineReader

    /// Connects to the app's socket at `url`. A `Channel.Failure` with `nobodyListening` means the app
    /// isn't running.
    public init(url: URL, timeout: TimeInterval = 15) throws {
        var address = try Channel.address(url)
        let fd = try Channel.makeSocket()
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            let failure = Channel.Failure("connect \(url.path)")
            close(fd)
            throw failure
        }
        // A request waits for the app's main thread, which an open alert can hold; don't wait forever.
        var wait = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))
        self.fd = fd
        self.lines = LineReader(fd: fd)
    }

    deinit { close(fd) }

    /// Sends `request` and waits for the app's answer.
    public func send(_ request: Request) throws -> Response {
        try Wire.response(from: send(line: Wire.encode(request)))
    }

    /// Sends one request line, newline included, and returns the response line without its newline.
    public func send(line: Data) throws -> Data {
        try Channel.write(line, to: fd)
        guard let reply = try lines.next() else { throw Channel.Failure("read", ECONNRESET) }
        return reply
    }
}
