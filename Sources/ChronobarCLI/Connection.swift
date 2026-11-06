import Foundation
import ChronobarCore
import ChronobarOperations

/// Reaches `copy` of the app over its socket, launching it by bundle ID if nothing answers there, then
/// waiting up to `wait` for it to start listening.
func connect(to copy: BuildVariant.Copy, wait: TimeInterval = 10) throws(OperationError) -> ChannelClient {
    let url = Channel.socketURL(of: copy)
    do {
        return try ChannelClient(url: url)
    } catch let failure as Channel.Failure where failure.nobodyListening {
        // Not running, or a socket left by a crash: launch it below.
    } catch {
        throw OperationError(.appUnreachable, "Couldn't reach \(copy.name): \(error)")
    }
    try launch(copy)
    let deadline = Date().addingTimeInterval(wait)
    var lastError: (any Error)?
    while Date() < deadline {
        do {
            return try ChannelClient(url: url)
        } catch {
            lastError = error
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    throw OperationError(.appUnreachable,
                         "\(copy.name) was launched but didn't answer within \(Int(wait)) seconds"
                         + (lastError.map { " (\($0))." } ?? "."))
}

/// Opens the app in the background with `open -g -b`, so it doesn't take the front from whatever the
/// user is doing. Launch Services finds it wherever it is installed once it has been opened there.
private func launch(_ copy: BuildVariant.Copy) throws(OperationError) {
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = ["-g", "-b", copy.bundleID]
    open.standardOutput = FileHandle.nullDevice
    open.standardError = FileHandle.nullDevice
    do {
        try open.run()
    } catch {
        throw OperationError(.appUnreachable, "Couldn't run open to launch \(copy.name): \(error)")
    }
    open.waitUntilExit()
    guard open.terminationStatus == 0 else {
        throw OperationError(.appUnreachable, "Couldn't find \(copy.name) (\(copy.bundleID)) to launch it. "
                             + "Open it once from Finder so macOS knows where it is, then try again.")
    }
}

extension BuildVariant.Copy {
    /// The app's name, as its menu says it.
    var name: String {
        switch self {
        case .everyday: "Chronobar"
        case .development: "Chronobar Dev"
        }
    }
}
