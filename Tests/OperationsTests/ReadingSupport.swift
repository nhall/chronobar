import Foundation
import ChronobarCore
import ChronobarOperations

/// The reading and list operations, as tests call them.
extension Operations {
    func day(_ date: String? = nil) throws -> DayRowsResult {
        guard case .day(let result) = try perform(.day(date: date)).success() else { throw Unexpected() }
        return result
    }

    func week(_ date: String? = nil) throws -> WeekResult {
        guard case .week(let result) = try perform(.week(date: date)).success() else { throw Unexpected() }
        return result
    }

    func labels(_ query: String? = nil) throws -> LabelsResult {
        guard case .labels(let result) = try perform(.labels(query: query)).success() else { throw Unexpected() }
        return result
    }

    @discardableResult
    func pin(_ label: String) throws -> PinResult {
        guard case .pin(let result) = try perform(.pin(label: label)).success() else { throw Unexpected() }
        return result
    }

    @discardableResult
    func archive(_ label: String) throws -> ArchiveResult {
        guard case .archive(let result) = try perform(.archive(label: label)).success() else { throw Unexpected() }
        return result
    }

    func summary() throws -> SummaryResult {
        guard case .summary(let result) = try perform(.summary).success() else { throw Unexpected() }
        return result
    }
}
