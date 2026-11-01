import XCTest
@testable import FCore

final class MarketIndexTimestampTests: XCTestCase {
    func testParsesValidTimestampInTheDeclaredMarketTimezone() throws {
        let timestamp = try XCTUnwrap(FMarketIndexTimestamp.parse(
            "20261101153045", timeZoneIdentifier: "Asia/Shanghai"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: timestamp)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 15)
        XCTAssertEqual(components.minute, 30)
        XCTAssertEqual(components.second, 45)
    }

    func testRejectsImpossibleAndOverflowingCalendarComponents() {
        XCTAssertNil(FMarketIndexTimestamp.parse("20260231153000", timeZoneIdentifier: "Asia/Shanghai"))
        XCTAssertNil(FMarketIndexTimestamp.parse("20261101256000", timeZoneIdentifier: "Asia/Shanghai"))
        XCTAssertNil(FMarketIndexTimestamp.parse("20261101153060", timeZoneIdentifier: "Asia/Shanghai"))
    }

    func testRejectsNonDigitAndNonAsciiTimestampPayloads() {
        XCTAssertNil(FMarketIndexTimestamp.parse("junk20261101153000", timeZoneIdentifier: "Asia/Shanghai"))
        XCTAssertNil(FMarketIndexTimestamp.parse("2026-11-01 15:30", timeZoneIdentifier: "Asia/Shanghai"))
        XCTAssertNil(FMarketIndexTimestamp.parse("２０２６１１０１１５３０００", timeZoneIdentifier: "Asia/Shanghai"))
    }

    func testRejectsUnknownTimezoneInsteadOfUsingDeviceTimezone() {
        XCTAssertNil(FMarketIndexTimestamp.parse("20261101153000", timeZoneIdentifier: "Unknown/Market"))
    }

    func testTwelveDigitTimestampUsesZeroSeconds() throws {
        let timestamp = try XCTUnwrap(FMarketIndexTimestamp.parse(
            "202611011530", timeZoneIdentifier: "Asia/Shanghai"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        XCTAssertEqual(calendar.component(.second, from: timestamp), 0)
    }

    func testRejectsAmbiguousAndNonexistentNewYorkDaylightSavingTimes() {
        XCTAssertNil(FMarketIndexTimestamp.parse(
            "20261101013000", timeZoneIdentifier: "America/New_York"),
            "the fall-back wall time occurs twice and the source has no UTC offset")
        XCTAssertNil(FMarketIndexTimestamp.parse(
            "20260308023000", timeZoneIdentifier: "America/New_York"),
            "the spring-forward wall time does not exist")
    }

    func testAcceptsUnambiguousNewYorkTimesOnBothSidesOfDaylightSavingChange() throws {
        let before = try XCTUnwrap(FMarketIndexTimestamp.parse(
            "20260308013000", timeZoneIdentifier: "America/New_York"))
        let after = try XCTUnwrap(FMarketIndexTimestamp.parse(
            "20260308033000", timeZoneIdentifier: "America/New_York"))
        XCTAssertEqual(after.timeIntervalSince(before), 3_600)
    }
}
