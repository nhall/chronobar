/// What logging time stored: the Label as stored (the name its row is shown under), the Day it went on,
/// and the seconds of the manual Entry written, from the one parse of the typed duration.
public struct Logged: Equatable, Sendable {
    public let project: String
    public let day: Day
    public let seconds: Int

    public init(project: String, day: Day, seconds: Int) {
        self.project = project
        self.day = day
        self.seconds = seconds
    }
}
