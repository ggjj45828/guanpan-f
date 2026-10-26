import Foundation

/// Local session gate for the currently reviewed mainland exchange calendar.
/// Unknown years return `.unknown` so automatic polling can fail closed.
public enum FMainlandTradingCalendar {
    private static let reviewedYear = 2026
    private static let closures2026: Set<String> = [
        "2026-01-01", "2026-01-02",
        "2026-02-16", "2026-02-17", "2026-02-18", "2026-02-19", "2026-02-20", "2026-02-23",
        "2026-04-06", "2026-05-01", "2026-05-04", "2026-05-05", "2026-06-19", "2026-09-25",
        "2026-10-01", "2026-10-02", "2026-10-05", "2026-10-06", "2026-10-07"
    ]

    public static func status(at instant: Date, timeZone: TimeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current)
        -> FMarketSessionStatus {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: instant)
        guard components.year == reviewedYear, let month = components.month, let day = components.day,
              let weekday = components.weekday, let hour = components.hour, let minute = components.minute else {
            return .unknown
        }
        let dateKey = String(format: "%04d-%02d-%02d", reviewedYear, month, day)
        guard weekday != 1, weekday != 7, !closures2026.contains(dateKey) else { return .closed }
        let minuteOfDay = hour * 60 + minute
        if (570...690).contains(minuteOfDay) || (780...900).contains(minuteOfDay) { return .continuous }
        if (690..<780).contains(minuteOfDay) { return .lunchBreak }
        if minuteOfDay < 570 { return .preOpen }
        return .closed
    }
}
