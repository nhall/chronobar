import Foundation
import ChronobarCore
import ChronobarOperations

/// Where tests point the command instead of the app's socket. With it set the command never launches the
/// app, so a test with nothing listening there can't start the real one.
let socketOverrideKey = "CHRONOBAR_SOCKET"

/// Reaches `copy` of the app over its socket, launching it by bundle ID if nothing answers there, then
/// waiting up to `wait` for it to start listening. With `CHRONOBAR_SOCKET` set, reaches that socket only.
func connect(to copy: BuildVariant.Copy, wait: TimeInterval = 10,
             environment: [String: String] = ProcessInfo.processInfo.environment) throws(OperationError)
    -> ChannelClient {
    if let path = environment[socketOverrideKey] {
        do {
            return try ChannelClient(url: URL(fileURLWithPath: path))
        } catch {
            throw OperationError(.appUnreachable, "Nothing answered on \(path) (\(socketOverrideKey)): \(error)")
        }
    }
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

/// Opens the app in the background with `open -g`, so it doesn't take the front from whatever the
/// user is doing: the app installed beside this command if there is one, else by bundle ID.
/// Launch Services knows a Homebrew install only once it has been opened, and forgets it on each
/// `brew upgrade` (the old keg's path is gone), so the copy beside the command comes first.
private func launch(_ copy: BuildVariant.Copy) throws(OperationError) {
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    if let executable = Bundle.main.executableURL, let app = copy.app(besideExecutable: executable) {
        open.arguments = ["-g", app.path]
    } else {
        open.arguments = ["-g", "-b", copy.bundleID]
    }
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

    /// The app in the folder above the one holding `executable`, after following links: where
    /// `scripts/bundle-app.sh` (`build/bin/chronobar`) and the Homebrew formula (`<keg>/bin/chronobar`)
    /// put the command. Nil when there is no such app.
    func app(besideExecutable executable: URL) -> URL? {
        let app = executable.resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("\(name).app", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: app.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return app
    }
}
