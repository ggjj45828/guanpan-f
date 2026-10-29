import XCTest
@testable import FCore

final class MarketMinuteDataTests: XCTestCase {
    private let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    private func stamp(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = shanghai
        formatter.dateFormat = "yyyyMMdd HHmm"
        formatter.isLenient = false
        return formatter.date(from: text)!
    }

    func testTencentSymbolMappingSupportsShanghaiAndShenzhenETFs() throws {
        XCTAssertEqual(try FTencentMinuteParser.symbol(for: "159352"), "sz159352")
        XCTAssertEqual(try FTencentMinuteParser.symbol(for: "563020"), "sh563020")
        XCTAssertThrowsError(try FTencentMinuteParser.symbol(for: "830001"))
    }

    func testParserSortsCurrentSessionRowsAndDropsOpeningAuction() throws {
        let fetched = stamp("20261026 0932")
        let payload = #"{"data":{"sz159352":{"data":{"date":"20261026","data":["0932 1.201 1120","0930 1.199 900","0931 1.200 1000"]}}}}"#
        let result = try FTencentMinuteParser.parse(Data(payload.utf8), securityCode: "159352",
                                                    fetchedAt: fetched, timeZone: shanghai)
        XCTAssertEqual(result.samples.map(\.timestamp), [stamp("20261026 0931"), stamp("20261026 0932")])
        XCTAssertEqual(result.samples.map(\.price), [Decimal(string: "1.200")!, Decimal(string: "1.201")!])
        XCTAssertNil(result.samples[0].volume) // first observed cumulative value has no safe delta
        XCTAssertEqual(result.samples[1].volume, Decimal(120))
        XCTAssertEqual(result.quoteTimestamp, stamp("20261026 0932"))
        XCTAssertEqual(result.fetchedAt, fetched)
        XCTAssertEqual(result.source, FTencentMinuteParser.source)
    }

    func testParserRejectsYesterdayInsteadOfShowingItAsLive() {
        let fetched = stamp("20261026 1000")
        let payload = #"{"data":{"sz159352":{"data":{"date":"20261023","data":["1459 1.2 5"]}}}}"#
        XCTAssertThrowsError(try FTencentMinuteParser.parse(Data(payload.utf8), securityCode: "159352",
                                                              fetchedAt: fetched, timeZone: shanghai)) { error in
            XCTAssertEqual(error as? FMarketDataError, .staleOrWrongSession)
        }
    }

    func testParserRejectsFutureRowsAndDoesNotFabricateFutureQuoteTime() throws {
        let fetched = stamp("20261026 0932")
        let payload = #"{"data":{"sz159352":{"data":{"date":"20261026","data":["0931 1.2 5","0933 1.3 8"]}}}}"#
        let result = try FTencentMinuteParser.parse(Data(payload.utf8), securityCode: "159352",
                                                    fetchedAt: fetched, timeZone: shanghai)
        XCTAssertEqual(result.samples.count, 1)
        XCTAssertEqual(result.quoteTimestamp, stamp("20261026 0931"))
    }

    func testParserRejectsSameDayButStaleDataDuringContinuousSession() {
        let fetched = stamp("20261026 1000")
        let payload = #"{"data":{"sz159352":{"data":{"date":"20261026","data":["0931 1.2 5"]}}}}"#
        XCTAssertThrowsError(try FTencentMinuteParser.parse(Data(payload.utf8), securityCode: "159352",
                                                              fetchedAt: fetched, timeZone: shanghai)) { error in
            XCTAssertEqual(error as? FMarketDataError, .staleOrWrongSession)
        }
    }

    func testParserRejectsInvalidSecurityAndEmptyRows() {
        let fetched = stamp("20261026 0932")
        let payload = #"{"data":{"sz159352":{"data":{"date":"20261026","data":[]}}}}"#
        XCTAssertThrowsError(try FTencentMinuteParser.parse(Data(payload.utf8), securityCode: "not-code",
                                                              fetchedAt: fetched, timeZone: shanghai))
        XCTAssertThrowsError(try FTencentMinuteParser.parse(Data(payload.utf8), securityCode: "159352",
                                                              fetchedAt: fetched, timeZone: shanghai)) { error in
            XCTAssertEqual(error as? FMarketDataError, .noUsableSamples)
        }
    }

    func testReviewedCalendarDistinguishesSessionLunchHolidayAndWeekend() throws {
        XCTAssertEqual(FMainlandTradingCalendar.status(at: stamp("20261026 1000")), .continuous)
        XCTAssertEqual(FMainlandTradingCalendar.status(at: stamp("20261026 1200")), .lunchBreak)
        XCTAssertEqual(FMainlandTradingCalendar.status(at: stamp("20261001 1000")), .closed)
        XCTAssertEqual(FMainlandTradingCalendar.status(at: stamp("20261025 1000")), .closed)
    }

    func testCalendarFailsClosedForUnreviewedYear() throws {
        let newYear = stamp("20270104 1000")
        XCTAssertEqual(FMainlandTradingCalendar.status(at: newYear), .unknown)
    }
}
