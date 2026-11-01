import Foundation

/// Parses provider timestamps in an explicitly declared exchange timezone.
/// Invalid zones and calendar-normalized dates are rejected.
public enum FMarketIndexTimestamp {
    public static func parse(_ raw: String, timeZoneIdentifier: String) -> Date? {
        let digits = raw
        guard (digits.utf8.count == 12 || digits.utf8.count == 14),
              digits.utf8.allSatisfy({ (48...57).contains($0) }),
              let year = Int(digits.prefix(4)), let month = Int(digits.dropFirst(4).prefix(2)),
              let day = Int(digits.dropFirst(6).prefix(2)), let hour = Int(digits.dropFirst(8).prefix(2)),
              let minute = Int(digits.dropFirst(10).prefix(2)),
              let zone = TimeZone(identifier: timeZoneIdentifier) else { return nil }

        let second: Int
        if digits.count == 14 {
            guard let parsedSecond = Int(digits.dropFirst(12).prefix(2)) else { return nil }
            second = parsedSecond
        } else {
            second = 0
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let components = DateComponents(year: year, month: month, day: day,
                                        hour: hour, minute: minute, second: second)
        guard let date = calendar.date(from: components) else { return nil }
        let verified = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard verified.year == year, verified.month == month, verified.day == day,
              verified.hour == hour, verified.minute == minute, verified.second == second,
              !isAmbiguousLocalTime(year: year, month: month, day: day,
                                    hour: hour, minute: minute, second: second,
                                    timeZone: zone) else { return nil }
        return date
    }

    /// A wall-clock time during a fall-back transition can name two distinct
    /// instants. Without an explicit UTC offset, either choice would invent
    /// market-time provenance, so treat the timestamp as unavailable.
    private static func isAmbiguousLocalTime(year: Int, month: Int, day: Int,
                                             hour: Int, minute: Int, second: Int,
                                             timeZone: TimeZone) -> Bool {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day,
                                        hour: hour, minute: minute, second: second)
        guard let wallClockAsUTC = utcCalendar.date(from: components) else { return true }

        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone
        let offsets = stride(from: -86_400.0, through: 86_400.0, by: 1_800.0)
            .map { timeZone.secondsFromGMT(for: wallClockAsUTC.addingTimeInterval($0)) }
        var matchingInstants = Set<Int64>()
        for offset in Set(offsets) {
            let candidate = wallClockAsUTC.addingTimeInterval(TimeInterval(-offset))
            let local = localCalendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: candidate)
            guard local.year == year, local.month == month, local.day == day,
                  local.hour == hour, local.minute == minute, local.second == second else { continue }
            matchingInstants.insert(Int64(candidate.timeIntervalSince1970))
            if matchingInstants.count > 1 { return true }
        }
        return false
    }
}
