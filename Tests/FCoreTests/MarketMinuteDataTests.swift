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

    func testTencentTextQuoteMustEchoRequestedSymbol() throws {
        let valid = Data(#"v_sz159352="1~ETF name~159352~1.2~1.1";"#.utf8)
        XCTAssertEqual(try FTencentTextQuoteParser.fields(valid, expectedSymbol: "sz159352").count, 5)

        let wrong = Data(#"v_sz159353="1~Other ETF~159353~1.2~1.1";"#.utf8)
        XCTAssertThrowsError(try FTencentTextQuoteParser.fields(wrong, expectedSymbol: "sz159352")) { error in
            XCTAssertEqual(error as? FMarketDataError, .invalidPayload)
        }
    }

    func testLiveSnapshotFreshnessRejectsFutureFetchTime() throws {
        let now = Date()
        let quoteTime = now.addingTimeInterval(-30)
        let futureFetchTime = now.addingTimeInterval(1)
        let snapshot = try FCurrentIntradaySnapshot(
            securityCode: "159352",
            samples: [FMinuteSample(timestamp: quoteTime, price: Decimal(string: "1.2")!)],
            quoteTimestamp: quoteTime, fetchedAt: futureFetchTime,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource)

        XCTAssertEqual(snapshot.freshness(at: now), .unverified)
        XCTAssertEqual(snapshot.freshness(at: futureFetchTime), .fresh)
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

    func testParserDropsLunchAndAfterHoursRowsButKeepsSessionBoundaries() throws {
        let fetched = stamp("20261026 1502")
        let payload = #"{"data":{"sz159352":{"data":{"date":"20261026","data":["1130 1.200 100","1131 1.201 110","1200 1.202 120","1259 1.203 130","1300 1.204 140","1301 1.205 150","1501 1.206 160"]}}}}"#
        let result = try FTencentMinuteParser.parse(Data(payload.utf8), securityCode: "159352",
                                                    fetchedAt: fetched, timeZone: shanghai)

        XCTAssertEqual(result.samples.map(\.timestamp), [stamp("20261026 1130"), stamp("20261026 1300"), stamp("20261026 1301")])
        XCTAssertEqual(result.quoteTimestamp, stamp("20261026 1301"))
    }

    func testCumulativeVolumeRegressionIsUnknownAndDoesNotBecomeZeroVolume() throws {
        let fetched = stamp("20261026 0934")
        let payload = #"{"data":{"sz159352":{"data":{"date":"20261026","data":["0931 1.200 100","0932 1.201 90","0933 1.202 95","0934 1.203 101"]}}}}"#
        let result = try FTencentMinuteParser.parse(Data(payload.utf8), securityCode: "159352",
                                                    fetchedAt: fetched, timeZone: shanghai)

        XCTAssertNil(result.samples[0].volume) // first counter has no safe delta
        XCTAssertNil(result.samples[1].volume) // reset point is not a zero-volume minute
        XCTAssertEqual(result.samples[2].volume, Decimal(5)) // counter recovers from new baseline
        XCTAssertEqual(result.samples[3].volume, Decimal(6))
    }

    func testMissingCumulativeVolumeBreaksDeltaContinuity() throws {
        let fetched = stamp("20261026 0935")
        let payload = #"{"data":{"sz159352":{"data":{"date":"20261026","data":["0931 1.200 100","0932 1.201 110","0933 1.202","0934 1.203 150","0935 1.204 158"]}}}}"#
        let result = try FTencentMinuteParser.parse(Data(payload.utf8), securityCode: "159352",
                                                    fetchedAt: fetched, timeZone: shanghai)

        XCTAssertEqual(result.samples.map(\.timestamp), [stamp("20261026 0931"), stamp("20261026 0932"),
                                                          stamp("20261026 0933"), stamp("20261026 0934"),
                                                          stamp("20261026 0935")])
        XCTAssertNil(result.samples[0].volume)
        XCTAssertEqual(result.samples[1].volume, Decimal(10))
        XCTAssertNil(result.samples[2].volume)
        XCTAssertNil(result.samples[3].volume, "跨越缺失分钟的累计量不得冒充单分钟量")
        XCTAssertEqual(result.samples[4].volume, Decimal(8), "恢复基准后下一分钟量可重新使用")
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

    func testSnapshotRejectsInvalidMinutePriceAndVolumeValues() {
        let fetchedAt = stamp("20261026 0932")
        let validSample = FMinuteSample(timestamp: fetchedAt, price: 1.2)
        XCTAssertThrowsError(try FCurrentIntradaySnapshot(securityCode: "159352",
            samples: [FMinuteSample(timestamp: fetchedAt, price: 1.2, volume: -1)],
            quoteTimestamp: fetchedAt, fetchedAt: fetchedAt, source: "fixture"))
        XCTAssertThrowsError(try FCurrentIntradaySnapshot(securityCode: "159352",
            samples: [FMinuteSample(timestamp: fetchedAt, price: .nan)],
            quoteTimestamp: fetchedAt, fetchedAt: fetchedAt, source: "fixture"))
        let infinity = Decimal(Double.infinity)
        XCTAssertTrue(infinity.isInfinite)
        XCTAssertThrowsError(try FCurrentIntradaySnapshot(securityCode: "159352",
            samples: [FMinuteSample(timestamp: fetchedAt, price: infinity)],
            quoteTimestamp: fetchedAt, fetchedAt: fetchedAt, source: "fixture"))
        XCTAssertNoThrow(try FCurrentIntradaySnapshot(securityCode: "159352",
            samples: [validSample], quoteTimestamp: fetchedAt, fetchedAt: fetchedAt,
            source: "fixture"))
        XCTAssertThrowsError(try FCurrentIntradaySnapshot(securityCode: "١٥٩٣٥٢",
            samples: [validSample], quoteTimestamp: fetchedAt, fetchedAt: fetchedAt,
            source: "fixture"))
    }

    func testDailySnapshotRejectsNonFiniteOHLCVValues() {
        let fetchedAt = stamp("20261026 0932")
        let day = stamp("20261023 1200")
        let invalid = FDailyBar(tradingDate: day, open: 1, close: 1,
                                high: 1, low: 1, volume: .nan)
        XCTAssertThrowsError(try FDailyKlineSnapshot(securityCode: "159352", bars: [invalid],
            fetchedAt: fetchedAt, source: "fixture", adjustment: "不复权"))
        let infiniteVolume = FDailyBar(tradingDate: day, open: 1, close: 1,
            high: 1, low: 1, volume: Decimal(Double.infinity))
        XCTAssertThrowsError(try FDailyKlineSnapshot(securityCode: "159352", bars: [infiniteVolume],
            fetchedAt: fetchedAt, source: "fixture", adjustment: "不复权"))
    }

    func testDailyMovingAverageAvoidsIntermediateDecimalOverflow() throws {
        let firstDay = stamp("20261022 1200")
        let secondDay = stamp("20261023 1200")
        let maximum = Decimal.greatestFiniteMagnitude
        let bars = [firstDay, secondDay].map { day in
            FDailyBar(tradingDate: day, open: maximum, close: maximum,
                high: maximum, low: maximum, volume: 0)
        }
        let snapshot = try FDailyKlineSnapshot(securityCode: "159352", bars: bars,
            fetchedAt: stamp("20261026 0932"), source: "fixture", adjustment: "不复权")

        let averages = snapshot.movingAverage(period: 2)

        XCTAssertNil(averages[0])
        XCTAssertTrue(averages[1]?.isFinite == true)
        XCTAssertEqual(averages[1], Optional(maximum))
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
        XCTAssertTrue(FMainlandTradingCalendar.isContinuousSessionTime(at: newYear))
        XCTAssertFalse(FMainlandTradingCalendar.isContinuousSessionTime(at: stamp("20270104 1200")))
    }

}
