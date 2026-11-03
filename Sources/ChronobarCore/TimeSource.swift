import Foundation

/// The current time and the calendar (with its time zone) that Days are counted in.
/// Core never reads the system clock directly, so tests can inject their own.
public protocol TimeSource: AnyObject {
    var now: Date { get }
    var calendar: Calendar { get }
}

/// The real clock, following the user's calendar and time zone as they change.
public final class SystemTimeSource: TimeSource {
    public init() {}
    public var now: Date { Date() }
    public var calendar: Calendar { Calendar.autoupdatingCurrent }
}
