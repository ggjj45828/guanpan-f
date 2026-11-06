import XCTest
@testable import FCore

final class MACDAnalysisTests: XCTestCase {
    func testUnorderedTimelineFailsClosedAndCannotConfirmSignal() throws {
        let bars = [
            FMACDInputBar(timestamp: Date(timeIntervalSince1970: 2), close: 10),
            FMACDInputBar(timestamp: Date(timeIntervalSince1970: 1), close: 11)
        ]
        let series = FMACDEngine.calculate(bars: bars, timeframe: .daily)
        XCTAssertTrue(series.points.isEmpty)
        XCTAssertFalse(series.finalized)
        XCTAssertTrue(series.reasonCodes.contains("macd_bar_timeline_invalid"))
        XCTAssertEqual(FMultiTimeframeMACDAnalyzer.assess(series).trend, .dataInsufficient)
    }

    func testInvalidTrailingBarCannotMarkOlderMACDPointFinal() throws {
        let bars = (0..<60).map { index in
            FMACDInputBar(timestamp: Date(timeIntervalSince1970: Double(index)),
                          close: index == 59 ? nil : 10 + sin(Double(index) / 4), isFinal: true)
        }
        let series = FMACDEngine.calculate(bars: bars, timeframe: .daily)
        XCTAssertNotNil(series.latest)
        XCTAssertFalse(series.finalized)
        XCTAssertFalse(FMultiTimeframeMACDAnalyzer.assess(series).signalConfirmed)
    }

    func testSMASeededEMAAndHistogramMatchReferenceVector() throws {
        let values = [1.0, 2, 3, 2, 1, 2, 3, 4]
        let bars = values.enumerated().map {
            FMACDInputBar(timestamp: Date(timeIntervalSince1970: Double($0.offset)), close: $0.element)
        }
        let parameters = try FMACDParameters(fast: 2, slow: 3, signal: 2)
        let result = FMACDEngine.calculate(bars: bars, timeframe: .daily, parameters: parameters)

        XCTAssertEqual(result.points.first?.inputIndex, 3)
        let first = try XCTUnwrap(result.points.first)
        XCTAssertEqual(first.dif, 1.0 / 6.0, accuracy: 1e-12)
        XCTAssertEqual(first.dea, 1.0 / 3.0, accuracy: 1e-12)
        XCTAssertEqual(first.histogram, -1.0 / 3.0, accuracy: 1e-12)
        XCTAssertEqual(result.points[1].inputIndex, 4)
        XCTAssertEqual(result.points[1].dif, -1.0 / 9.0, accuracy: 1e-12)
        XCTAssertEqual(result.points[1].dea, 1.0 / 27.0, accuracy: 1e-12)
        XCTAssertEqual(result.points[1].histogram, -8.0 / 27.0, accuracy: 1e-12)
    }

    func testMissingBarRestartsWarmupInsteadOfBridgingGap() {
        let bars = (0..<80).map { index in
            FMACDInputBar(timestamp: Date(timeIntervalSince1970: Double(index)),
                          close: index == 45 ? nil : 10 + Double(index))
        }
        let result = FMACDEngine.calculate(bars: bars, timeframe: .daily)

        XCTAssertEqual(result.points.last?.inputIndex, 79)
        XCTAssertFalse(result.points.contains { (46..<79).contains($0.inputIndex) })
        XCTAssertEqual(result.validInputCount, 79)
        XCTAssertEqual(result.completeness, 79.0 / 80.0, accuracy: 1e-12)
    }

    func testUnfinishedBarCannotProduceConfirmedSignal() {
        let bars = (0..<40).map { index in
            FMACDInputBar(timestamp: Date(timeIntervalSince1970: Double(index)),
                          close: 10 + Double(index) * 0.1, isFinal: index < 39)
        }
        let series = FMACDEngine.calculate(bars: bars, timeframe: .daily)
        let assessment = FMultiTimeframeMACDAnalyzer.assess(series)

        XCTAssertFalse(series.finalized)
        XCTAssertFalse(assessment.signalConfirmed)
        XCTAssertTrue(assessment.reasonCodes.contains("latest_bar_provisional"))
    }

    func testInsufficientBarsReturnExplicitInsufficientState() {
        let bars = (0..<20).map {
            FMACDInputBar(timestamp: Date(timeIntervalSince1970: Double($0)), close: 10 + Double($0))
        }
        let series = FMACDEngine.calculate(bars: bars, timeframe: .daily)
        let assessment = FMultiTimeframeMACDAnalyzer.assess(series)

        XCTAssertTrue(series.points.isEmpty)
        XCTAssertEqual(assessment.trend, .dataInsufficient)
        XCTAssertFalse(assessment.signalConfirmed)
    }

    func testStandardWarmupBarCountMatchesFirstSMASeededDEA() {
        XCTAssertEqual(FMACDParameters.standard.warmupBars, 34)
        let bars = (0..<34).map { index in
            FMACDInputBar(timestamp: Date(timeIntervalSince1970: Double(index)), close: 10 + Double(index))
        }
        let series = FMACDEngine.calculate(bars: bars, timeframe: .daily)

        XCTAssertEqual(series.points.first?.inputIndex, 33)
        XCTAssertEqual(series.points.count, 1)
    }

    func testMAAndVolumeEvidenceCannotUpgradeMACDToValidatedOrStrongSignal() throws {
        let bars = (0..<60).map { index in
            FMACDInputBar(timestamp: Date(timeIntervalSince1970: Double(index)),
                          close: 10 + Double(index) * 0.1)
        }
        let parameters = try FMACDParameters(fast: 2, slow: 3, signal: 2)
        let series = FMACDEngine.calculate(bars: bars, timeframe: .daily, parameters: parameters)
        let withEvidence = FMultiTimeframeMACDAnalyzer.assess(series, maEvidenceAvailable: true,
                                                              volumeEvidenceAvailable: true)
        let withoutEvidence = FMultiTimeframeMACDAnalyzer.assess(series, maEvidenceAvailable: false,
                                                                  volumeEvidenceAvailable: false)

        XCTAssertEqual(withEvidence.trend, withoutEvidence.trend)
        XCTAssertTrue(withEvidence.reasonCodes.contains("volume_state_is_descriptive_evidence_only"))
    }
}

