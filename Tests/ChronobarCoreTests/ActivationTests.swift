import Testing
import ChronobarCore

@Suite struct ActivationTests {
    /// macOS turns down a plain request when a Pill click comes through the menu bar, or when nothing the
    /// user did reached the app (the idle alert, leaving the Dock), but honours taking over from the app
    /// in front.
    @Test func anotherAppInFrontIsTakenOverFrom() {
        #expect(Activation.request(frontmost: 501, current: 700) == .takeOver(from: 501))
    }

    @Test func thisAppInFrontAsksPlainly() {
        #expect(Activation.request(frontmost: 700, current: 700) == .plain)
    }

    /// No app is in front, as between one app quitting and the next activating.
    @Test func noAppInFrontAsksPlainly() {
        #expect(Activation.request(frontmost: nil, current: 700) == .plain)
    }
}
