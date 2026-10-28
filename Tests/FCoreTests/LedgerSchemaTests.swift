import XCTest
@_spi(LedgerStorage) @testable import FCore
@testable import FLedgerWrite
import FAdvisor

final class LedgerSchemaTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func opening(cash: Decimal = 0, positions: [FPosition] = []) -> FAccountOpeningSnapshot {
        .init(capturedAt: now.addingTimeInterval(-600), cashBalance: cash, positions: positions)
    }

    func testValidConfirmedLedgerPassesValidation() throws {
        let position = FPosition(instrumentCode: "510300", name: "沪深300ETF", units: 100,
                                 bookCost: Decimal(string: "385.25")!)
        let fill = FConfirmedFill(sequence: 1, tradedAt: now.addingTimeInterval(-60), instrumentCode: "510300",
                                  side: .buy, units: 100, price: Decimal(string: "3.85")!,
                                  fee: Decimal(string: "0.25")!, userConfirmation: confirmation())
        try FAccountBook(openingSnapshot: opening(cash: Decimal(string: "1385.25")!),
                         cashBalance: 1000, positions: [position], fills: [fill], updatedAt: now).validate(now: now)
    }

    func testRejectsUnsupportedSchema() {
        let book = FAccountBook(openingSnapshot: opening(cash: 10), cashBalance: 10, updatedAt: now, schemaVersion: 99)
        XCTAssertThrowsError(try book.validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .unsupportedSchema(99))
        }
    }

    func testRejectsNegativeCash() {
        XCTAssertThrowsError(try FAccountBook(openingSnapshot: opening(), cashBalance: -1, updatedAt: now).validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .invalidCash)
        }
    }

    func testRejectsDuplicateInstrumentPositions() {
        let a = FPosition(instrumentCode: "510300", name: "A", units: 100, bookCost: 100)
        let b = FPosition(instrumentCode: "510300", name: "B", units: 200, bookCost: 200)
        XCTAssertThrowsError(try FAccountBook(openingSnapshot: opening(cash: 10), cashBalance: 10, positions: [a, b], updatedAt: now).validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .duplicateInstrument("510300"))
        }
    }

    func testRejectsNonPositivePositionUnits() {
        let position = FPosition(instrumentCode: "510300", name: "ETF", units: 0, bookCost: 10)
        XCTAssertThrowsError(try FAccountBook(openingSnapshot: opening(cash: 10), cashBalance: 10, positions: [position], updatedAt: now).validate(now: now))
    }

    func testRejectsNegativeFee() {
        let fill = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .buy, units: 1,
                                  price: 3, fee: -0.1, userConfirmation: confirmation())
        XCTAssertThrowsError(try FAccountBook(openingSnapshot: opening(cash: 10), cashBalance: 10, fills: [fill], updatedAt: now).validate(now: now))
    }

    func testRejectsBlankUserConfirmation() {
        let fill = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .buy, units: 1,
                                  price: 3, fee: 0,
                                  userConfirmation: .init(confirmedAt: now, confirmationNote: "  "))
        XCTAssertThrowsError(try FAccountBook(openingSnapshot: opening(cash: 10), cashBalance: 10, fills: [fill], updatedAt: now).validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .invalidConfirmation(fill.id))
        }
    }

    func testRejectsFutureDatedFill() {
        let future = now.addingTimeInterval(600)
        let fill = FConfirmedFill(sequence: 1, tradedAt: future, instrumentCode: "510300", side: .buy, units: 1,
                                  price: 3, fee: 0,
                                  userConfirmation: .init(confirmedAt: future, confirmationNote: "确认"))
        XCTAssertThrowsError(try FAccountBook(openingSnapshot: opening(cash: 10), cashBalance: 10, fills: [fill], updatedAt: now).validate(now: now))
    }

    func testRejectsDuplicateFillIDs() {
        let id = UUID(), confirmed = confirmation()
        let one = FConfirmedFill(id: id, sequence: 1, tradedAt: now, instrumentCode: "510300", side: .buy,
                                 units: 1, price: 3, fee: 0, userConfirmation: confirmed)
        let two = FConfirmedFill(id: id, sequence: 2, tradedAt: now, instrumentCode: "510300", side: .buy,
                                 units: 2, price: 3, fee: 0, userConfirmation: confirmed)
        XCTAssertThrowsError(try FAccountBook(openingSnapshot: opening(cash: 10), cashBalance: 10, fills: [one, two], updatedAt: now).validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .duplicateFillID(id))
        }
    }

    func testRejectsEmptyAuditDigest() {
        let audit = FLedgerAuditEvent(occurredAt: now, action: "成交", reason: "用户确认",
                                      priorLedgerDigest: nil, resultingLedgerDigest: " ")
        XCTAssertThrowsError(try FAccountBook(openingSnapshot: opening(cash: 10), cashBalance: 10, audits: [audit], updatedAt: now).validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .invalidAudit(audit.id))
        }
    }

    func testRejectsCashThatDoesNotReconcileToConfirmedFills() {
        let fill = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .buy, units: 100,
                                  price: 3, fee: 1, userConfirmation: confirmation())
        let book = FAccountBook(openingSnapshot: opening(cash: 1000), cashBalance: 700,
                                positions: [FPosition(instrumentCode: "510300", name: "ETF", units: 100, bookCost: 301)],
                                fills: [fill], updatedAt: now)
        XCTAssertThrowsError(try book.validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .cashReconciliation(expected: 699, actual: 700))
        }
    }

    func testSellRequiresCostBasisAndReconcilesRemainingPosition() throws {
        let openingPosition = FPosition(instrumentCode: "510300", name: "ETF", units: 200, bookCost: 600)
        let sale = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .sell, units: 100,
                                 price: 3.2, fee: 1, costBasisRemoved: 300, userConfirmation: confirmation())
        let remaining = FPosition(instrumentCode: "510300", name: "ETF", units: 100, bookCost: 300)
        let book = FAccountBook(openingSnapshot: opening(cash: 100, positions: [openingPosition]),
                                cashBalance: 419, positions: [remaining], fills: [sale], updatedAt: now)
        XCTAssertNoThrow(try book.validate(now: now))
    }

    func testRealizedPerformanceIsReadOnlyAndUsesConfirmedSellFillsOnly() throws {
        let openingPosition = FPosition(instrumentCode: "510300", name: "ETF", units: 200, bookCost: 600)
        let sale = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .sell,
                                  units: 100, price: Decimal(string: "3.20")!, fee: 1,
                                  costBasisRemoved: 300, userConfirmation: confirmation())
        let book = FAccountBook(openingSnapshot: opening(cash: 100, positions: [openingPosition]),
                                cashBalance: 419,
                                positions: [.init(instrumentCode: "510300", name: "ETF", units: 100,
                                                  bookCost: 300)],
                                fills: [sale], updatedAt: now)
        let priorDigest = try book.ledgerStateDigest()

        let report = try FRealizedPerformanceSnapshot.derive(from: book, now: now)

        XCTAssertEqual(report.sellFillCount, 1)
        XCTAssertEqual(report.unitsSold, 100)
        XCTAssertEqual(report.grossProceeds, 320)
        XCTAssertEqual(report.fees, 1)
        XCTAssertEqual(report.costBasisRemoved, 300)
        XCTAssertEqual(report.netRealizedProfit, 19)
        XCTAssertEqual(report.byInstrument.map(\.instrumentCode), ["510300"])
        XCTAssertEqual(try book.ledgerStateDigest(), priorDigest)
        XCTAssertEqual(book.cashBalance, 419)
        XCTAssertEqual(book.positions.first?.bookCost, 300)
        XCTAssertEqual(book.fills, [sale])
    }

    func testCashMovementsReconcileAgainstOpeningCash() throws {
        let movement = FCashMovement(sequence: 1, occurredAt: now, amount: 50, reason: "用户确认入金",
                                     userConfirmation: confirmation())
        let book = FAccountBook(openingSnapshot: opening(cash: 100), cashBalance: 150,
                                cashMovements: [movement], updatedAt: now)
        XCTAssertNoThrow(try book.validate(now: now))
    }

    func testEventSequenceControlsSameTimestampCashAndFillOrder() throws {
        let timestamp = now.addingTimeInterval(-30)
        let fill = FConfirmedFill(sequence: 2, tradedAt: timestamp, instrumentCode: "510300",
                                  side: .buy, units: 40, price: 3, fee: 0,
                                  userConfirmation: .init(confirmedAt: now, confirmationNote: "已确认成交"))
        let deposit = FCashMovement(sequence: 1, occurredAt: timestamp, amount: 50, reason: "用户确认入金",
                                    userConfirmation: .init(confirmedAt: now, confirmationNote: "已确认入金"))
        let book = FAccountBook(openingSnapshot: opening(cash: 100), cashBalance: 30,
                                positions: [.init(instrumentCode: "510300", name: "ETF", units: 40, bookCost: 120)],
                                fills: [fill], cashMovements: [deposit], updatedAt: now)
        XCTAssertNoThrow(try book.validate(now: now))
    }

    func testHistoricalReplayRejectsTemporaryCashOverdraftEvenIfLaterDepositRepairsBalance() {
        let timestamp = now.addingTimeInterval(-30)
        let fill = FConfirmedFill(sequence: 1, tradedAt: timestamp, instrumentCode: "510300",
                                  side: .buy, units: 40, price: 3, fee: 0,
                                  userConfirmation: .init(confirmedAt: now, confirmationNote: "已确认成交"))
        let deposit = FCashMovement(sequence: 2, occurredAt: timestamp, amount: 50, reason: "用户确认入金",
                                    userConfirmation: .init(confirmedAt: now, confirmationNote: "已确认入金"))
        let book = FAccountBook(openingSnapshot: opening(cash: 100), cashBalance: 30,
                                positions: [.init(instrumentCode: "510300", name: "ETF", units: 40, bookCost: 120)],
                                fills: [fill], cashMovements: [deposit], updatedAt: now)
        XCTAssertThrowsError(try book.validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .historicalCashUnderflow(sequence: 1))
        }
    }

    func testRejectsDuplicateSequenceAcrossFillAndCashMovement() {
        let fill = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .buy,
                                  units: 1, price: 3, fee: 0, userConfirmation: confirmation())
        let movement = FCashMovement(sequence: 1, occurredAt: now, amount: 3, reason: "用户确认入金",
                                     userConfirmation: confirmation())
        let book = FAccountBook(openingSnapshot: opening(cash: 3), cashBalance: 3,
                                fills: [fill], cashMovements: [movement], updatedAt: now)
        XCTAssertThrowsError(try book.validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .duplicateEventSequence(1))
        }
    }

    func testRejectsSellExceedingOpeningUnits() {
        let sale = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .sell,
                                 units: 101, price: 3, fee: 0, costBasisRemoved: 100,
                                 userConfirmation: confirmation())
        let openingPosition = FPosition(instrumentCode: "510300", name: "ETF", units: 100, bookCost: 100)
        let book = FAccountBook(openingSnapshot: opening(cash: 10, positions: [openingPosition]),
                                cashBalance: 10, fills: [sale], updatedAt: now)
        XCTAssertThrowsError(try book.validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .positionUnitUnderflow("510300"))
        }
    }

    func testRejectsSellRemovingMoreCostThanHeld() {
        let sale = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .sell,
                                 units: 50, price: 3, fee: 0, costBasisRemoved: 60,
                                 userConfirmation: confirmation())
        let openingPosition = FPosition(instrumentCode: "510300", name: "ETF", units: 100, bookCost: 50)
        let remaining = FPosition(instrumentCode: "510300", name: "ETF", units: 50, bookCost: 0)
        let book = FAccountBook(openingSnapshot: opening(cash: 10, positions: [openingPosition]),
                                cashBalance: 160, positions: [remaining], fills: [sale], updatedAt: now)
        XCTAssertThrowsError(try book.validate(now: now))
    }

    func testConfirmedBuyReturnsReconciledBookAndAuditWithoutMutatingSource() throws {
        let source = FAccountBook(openingSnapshot: opening(cash: 1000), cashBalance: 1000, updatedAt: now.addingTimeInterval(-60))
        let fill = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .buy, units: 100,
                                  price: Decimal(string: "3.00")!, fee: 1, userConfirmation: confirmation())
        let updated = try source.applyingUserConfirmedFill(fill, instrumentName: "ETF", now: now)
        XCTAssertEqual(source.cashBalance, 1000)
        XCTAssertEqual(updated.cashBalance, 699)
        XCTAssertEqual(updated.positions.first?.units, 100)
        XCTAssertEqual(updated.positions.first?.bookCost, 301)
        XCTAssertEqual(updated.fills.count, 1)
        XCTAssertEqual(updated.audits.count, 1)
        XCTAssertNotNil(updated.audits[0].priorLedgerDigest)
        XCTAssertNotEqual(updated.audits[0].priorLedgerDigest, updated.audits[0].resultingLedgerDigest)
    }

    func testConfirmedFillUsesUserEnteredActualFeeInsteadOfFixedETFDefault() throws {
        let source = FAccountBook(openingSnapshot: opening(cash: 1_000), cashBalance: 1_000,
                                 updatedAt: now.addingTimeInterval(-60))
        let actualFee = Decimal(string: "0.16")!
        let fill = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "159352",
                                  side: .buy, units: 100, price: 3, fee: actualFee,
                                  userConfirmation: confirmation(), instrumentName: "A500")

        let updated = try source.applyingUserConfirmedFill(fill, instrumentName: "A500", now: now)

        XCTAssertEqual(updated.fills.first?.fee, actualFee)
        XCTAssertEqual(updated.cashBalance, Decimal(string: "699.84"))
        XCTAssertEqual(updated.positions.first?.bookCost, Decimal(string: "300.16"))
        XCTAssertEqual(try updated.readOnlySnapshot(capturedAt: now).cashFlow.last?.fee, actualFee)
    }

    func testConfirmedCloseAndReopenRetainsHistoryAndStartsFreshEpisodeAndCashFlow() throws {
        let code = "159352"
        var book = FAccountBook(openingSnapshot: opening(cash: 10_000), cashBalance: 10_000,
                                updatedAt: now.addingTimeInterval(-60))
        let buy1 = FConfirmedFill(sequence: 1, tradedAt: now.addingTimeInterval(-30),
                                  instrumentCode: code, side: .buy, units: 100, price: 10,
                                  fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                  userConfirmation: confirmation(), instrumentName: "A500")
        book = try book.applyingUserConfirmedFill(buy1, instrumentName: "A500", now: now)
        let sell = FConfirmedFill(sequence: 2, tradedAt: now.addingTimeInterval(-20),
                                  instrumentCode: code, side: .sell, units: 100, price: 12,
                                  fee: FETFTradeFeePolicy.defaultReferencePerFill, costBasisRemoved: 1_000.10,
                                  userConfirmation: confirmation(), instrumentName: "A500")
        book = try book.applyingUserConfirmedFill(sell, instrumentName: "A500", now: now)

        XCTAssertTrue(book.positions.isEmpty, "清仓只移除当前持仓投影")
        XCTAssertEqual(book.fills.count, 2, "清仓不能删除成交流水")
        XCTAssertEqual(book.fills.map(\.instrumentName), ["A500", "A500"])
        XCTAssertEqual(try FRealizedPerformanceSnapshot.derive(from: book, now: now).netRealizedProfit,
                       Decimal(string: "199.80")!)
        let closedSnapshot = try book.readOnlySnapshot(capturedAt: now)
        XCTAssertEqual(closedSnapshot.instrumentHistories.first?.activeUnits, 0)
        XCTAssertFalse(closedSnapshot.instrumentHistories.first?.isCurrentlyHeld ?? true)
        XCTAssertEqual(closedSnapshot.instrumentHistories.first?.episodes.first?.closedAt, sell.tradedAt)
        XCTAssertEqual(closedSnapshot.cashFlow.last?.resultingCashBalance, book.cashBalance)

        let buy2 = FConfirmedFill(sequence: 3, tradedAt: now.addingTimeInterval(-10),
                                  instrumentCode: code, side: .buy, units: 50, price: 11,
                                  fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                  userConfirmation: confirmation(), instrumentName: "A500")
        book = try book.applyingUserConfirmedFill(buy2, instrumentName: "A500", now: now)
        let snapshot = try book.readOnlySnapshot(capturedAt: now)

        XCTAssertEqual(snapshot.positions.first?.units, 50)
        XCTAssertEqual(snapshot.positions.first?.bookCost, Decimal(string: "550.10"))
        XCTAssertEqual(snapshot.instrumentHistories.first?.instrumentName, "A500")
        XCTAssertEqual(snapshot.instrumentHistories.first?.episodes.count, 2)
        XCTAssertEqual(snapshot.instrumentHistories.first?.episodes[0].closedAt, sell.tradedAt)
        XCTAssertEqual(snapshot.instrumentHistories.first?.episodes[0].netRealizedProfit,
                       Decimal(string: "199.80"))
        XCTAssertEqual(snapshot.instrumentHistories.first?.episodes[1].currentBookCost,
                       Decimal(string: "550.10"))
        XCTAssertEqual(snapshot.instrumentHistories.first?.episodes[1].openingUnits, 50)
        XCTAssertEqual(snapshot.instrumentHistories.first?.lifetimeRealizedProfit,
                       Decimal(string: "199.80"))
        XCTAssertEqual(snapshot.cashFlow.count, 4)
        XCTAssertEqual(snapshot.cashFlow.last?.resultingCashBalance, book.cashBalance)
        XCTAssertEqual(snapshot.cashFlow.dropFirst().map(\.fee),
                       Array(repeating: FETFTradeFeePolicy.defaultReferencePerFill, count: 3))
        XCTAssertEqual(snapshot.cashFlow.map(\.cashDelta), [10_000, -1_000.10, 1_199.90, -550.10])
        let context = FDecisionContext(snapshot: snapshot, observations: [])
        let request = try FAdvisorQuestionRequest(question: "A500 历史上一共赚了多少？",
                                                 scope: .instrument(code), decisionContext: context, now: now)
        XCTAssertEqual(request.portfolioContext?.positionHistory.first?.episodeCount, 2)
        XCTAssertEqual(request.portfolioContext?.recentPositionEpisodes.map(\.currentBookCost),
                       [0, Decimal(string: "550.10")!])
    }

    func testConfirmedPartialSalePreservesActivePositionEpisodeAndCashLedgerLink() throws {
        let openingPosition = FPosition(instrumentCode: "159352", name: "A500", units: 100,
                                        bookCost: 1_000)
        let sale = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "159352", side: .sell,
                                  units: 40, price: 12, fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                  costBasisRemoved: 400, userConfirmation: confirmation(), instrumentName: "A500")
        let book = FAccountBook(openingSnapshot: opening(cash: 5_000, positions: [openingPosition]),
                                cashBalance: 5_479.90,
                                positions: [.init(instrumentCode: "159352", name: "A500", units: 60,
                                                  bookCost: 600)], fills: [sale], updatedAt: now)
        let snapshot = try book.readOnlySnapshot(capturedAt: now)
        XCTAssertEqual(snapshot.positions.first?.units, 60)
        XCTAssertEqual(snapshot.instrumentHistories.first?.episodes.first?.currentUnits, 60)
        XCTAssertNil(snapshot.instrumentHistories.first?.episodes.first?.closedAt)
        XCTAssertEqual(snapshot.cashFlow.last?.cashDelta, Decimal(string: "479.90"))
        XCTAssertEqual(snapshot.cashFlow.last?.resultingCashBalance, 5_479.90)
    }

    func testRepeatedCloseAndReopenCreatesIndependentEpisodesAndFixedPerFillFees() throws {
        var book = FAccountBook(openingSnapshot: opening(cash: 1_000), cashBalance: 1_000,
                                updatedAt: now.addingTimeInterval(-60))
        var sequence: UInt64 = 0
        for episode in 1...3 {
            sequence += 1
            let buy = FConfirmedFill(sequence: sequence, tradedAt: now.addingTimeInterval(TimeInterval(episode - 10)),
                                     instrumentCode: "159352", side: .buy, units: 10, price: 10,
                                     fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                     userConfirmation: confirmation(), instrumentName: "A500")
            book = try book.applyingUserConfirmedFill(buy, instrumentName: "A500", now: now)
            sequence += 1
            let sell = FConfirmedFill(sequence: sequence, tradedAt: now.addingTimeInterval(TimeInterval(episode - 9)),
                                      instrumentCode: "159352", side: .sell, units: 10, price: 11,
                                      fee: FETFTradeFeePolicy.defaultReferencePerFill, costBasisRemoved: 100.10,
                                      userConfirmation: confirmation(), instrumentName: "A500")
            book = try book.applyingUserConfirmedFill(sell, instrumentName: "A500", now: now)
        }
        let snapshot = try book.readOnlySnapshot(capturedAt: now)
        let history = try XCTUnwrap(snapshot.instrumentHistories.first)
        XCTAssertEqual(history.instrumentCode, "159352")
        XCTAssertEqual(history.instrumentName, "A500")
        XCTAssertEqual(history.episodes.count, 3)
        XCTAssertTrue(history.episodes.allSatisfy { $0.closedAt != nil && $0.currentUnits == 0 })
        XCTAssertEqual(history.lifetimeRealizedProfit, Decimal(string: "29.40"))
        XCTAssertEqual(book.fills.count, 6)
        XCTAssertEqual(snapshot.cashFlow.dropFirst().map(\.fee),
                       Array(repeating: FETFTradeFeePolicy.defaultReferencePerFill, count: 6))
    }

    func testBrokerDisplayCostSurvivesFullCloseAndSameSecurityReopen() throws {
        let code = "159352"
        let updatedAt = now.addingTimeInterval(-180)
        let openingPosition = FPosition(instrumentCode: code, name: "A500", units: 100,
                                        bookCost: 1_000,
                                        brokerDisplayCostPerUnit: Decimal(string: "1.100")!,
                                        brokerDisplayCostUpdatedAt: updatedAt)
        var book = FAccountBook(openingSnapshot: opening(cash: 10_000, positions: [openingPosition]),
                                cashBalance: 10_000, positions: [openingPosition],
                                updatedAt: now.addingTimeInterval(-120))
        let sell = FConfirmedFill(sequence: 1, tradedAt: now.addingTimeInterval(-60),
                                  instrumentCode: code, side: .sell, units: 100, price: 12,
                                  fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                  costBasisRemoved: 1_000, userConfirmation: confirmation(),
                                  instrumentName: "A500")
        book = try book.applyingUserConfirmedFill(sell, instrumentName: "A500", now: now)
        XCTAssertTrue(book.positions.isEmpty)
        XCTAssertEqual(book.brokerDisplayCosts?.first?.costPerUnit, Decimal(string: "1.100"))

        let buy = FConfirmedFill(sequence: 2, tradedAt: now.addingTimeInterval(-30),
                                 instrumentCode: code, side: .buy, units: 50, price: 11,
                                 fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                 userConfirmation: confirmation(), instrumentName: "A500")
        book = try book.applyingUserConfirmedFill(buy, instrumentName: "A500", now: now)
        let reopened = try XCTUnwrap(book.positions.first)
        XCTAssertEqual(reopened.units, 50)
        XCTAssertEqual(reopened.bookCost, Decimal(string: "550.10"))
        XCTAssertEqual(reopened.brokerDisplayCostPerUnit, Decimal(string: "1.100"))
        XCTAssertEqual(reopened.brokerDisplayCostUpdatedAt, updatedAt)
        XCTAssertEqual(book.fills.count, 2)
    }

    func testSameDaySellBuySellFullCloseAndReopenKeepsBrokerAndEpisodeCostsSeparate() throws {
        let code = "159352"
        let openingPosition = FPosition(instrumentCode: code, name: "A500", units: 100,
                                        bookCost: 1_000,
                                        brokerDisplayCostPerUnit: Decimal(string: "10.35")!,
                                        brokerDisplayCostUpdatedAt: now.addingTimeInterval(-120))
        var book = FAccountBook(openingSnapshot: opening(cash: 5_000, positions: [openingPosition]),
                                cashBalance: 5_000, positions: [openingPosition],
                                updatedAt: now.addingTimeInterval(-120))
        func fill(_ sequence: UInt64, _ side: FTradeSide, _ units: Int64, _ price: Decimal,
                  _ removed: Decimal? = nil) -> FConfirmedFill {
            FConfirmedFill(sequence: sequence, tradedAt: now, instrumentCode: code, side: side,
                           units: units, price: price,
                           fee: FETFTradeFeePolicy.defaultReferencePerFill,
                           costBasisRemoved: removed, userConfirmation: confirmation(),
                           instrumentName: "A500")
        }
        book = try book.applyingUserConfirmedFill(fill(1, .sell, 40, 12, 400), instrumentName: "A500", now: now)
        book = try book.applyingUserConfirmedFill(fill(2, .buy, 20, 11), instrumentName: "A500", now: now)
        book = try book.applyingUserConfirmedFill(fill(3, .sell, 30, 12, Decimal(string: "307.5375")!), instrumentName: "A500", now: now)
        book = try book.applyingUserConfirmedFill(fill(4, .sell, 50, 12, Decimal(string: "512.5625")!), instrumentName: "A500", now: now)

        XCTAssertTrue(book.positions.isEmpty)
        XCTAssertEqual(book.fills.count, 4)
        let closed = try book.readOnlySnapshot(capturedAt: now)
        XCTAssertEqual(closed.instrumentHistories.first?.episodes.count, 1)
        XCTAssertNotNil(closed.instrumentHistories.first?.episodes[0].closedAt)
        XCTAssertEqual(closed.instrumentHistories.first?.lifetimeRealizedProfit,
                       Decimal(string: "219.60"))

        book = try book.applyingUserConfirmedFill(fill(5, .buy, 25, 11), instrumentName: "A500", now: now)
        let snapshot = try book.readOnlySnapshot(capturedAt: now)
        let position = try XCTUnwrap(snapshot.positions.first)
        XCTAssertEqual(position.units, 25)
        XCTAssertEqual(position.bookCost, Decimal(string: "275.10"))
        XCTAssertNil(position.brokerDisplayCostPerUnit, "新 Episode 不继承上一轮券商成本录入")
        XCTAssertEqual(snapshot.instrumentHistories.first?.episodes.count, 2)
        XCTAssertEqual(snapshot.instrumentHistories.first?.episodes[1].currentBookCost,
                       Decimal(string: "275.10"))
        XCTAssertEqual(snapshot.instrumentHistories.first?.episodes[0].netRealizedProfit,
                       Decimal(string: "219.60"))
        XCTAssertEqual(snapshot.cashFlow.dropFirst().map(\.fee),
                       Array(repeating: FETFTradeFeePolicy.defaultReferencePerFill, count: 5))
        XCTAssertEqual(snapshot.cashBalance, Decimal(string: "5944.50"))
        let daily = try XCTUnwrap(snapshot.dailyTradeSummaries.first)
        XCTAssertEqual(daily.securityCode, code)
        XCTAssertEqual(daily.tradingDate, "2027-01-15", "交易日期按Asia/Shanghai确定")
        XCTAssertEqual(daily.buyQuantity, 45)
        XCTAssertEqual(daily.buyAmount, 495)
        XCTAssertEqual(daily.sellQuantity, 120)
        XCTAssertEqual(daily.sellAmount, 1_440)
        XCTAssertEqual(daily.buyFees, Decimal(string: "0.20"))
        XCTAssertEqual(daily.sellFees, Decimal(string: "0.30"))
        XCTAssertEqual(daily.totalFees, Decimal(string: "0.50"))
        XCTAssertEqual(daily.realizedPnL, Decimal(string: "219.60"))
        XCTAssertEqual(daily.fillCount, 5)
        XCTAssertEqual(daily.firstFillTime, now)
        XCTAssertEqual(daily.lastFillTime, now)

        let correction = try book.correctingBrokerDisplayCost(
            instrumentCode: code, costPerUnit: Decimal(string: "11.07")!,
            confirmation: confirmation(), now: now)
        let corrected = try correction.readOnlySnapshot(capturedAt: now)
        XCTAssertEqual(corrected.positions.first?.brokerDisplayCostPerUnit, Decimal(string: "11.07"))
        XCTAssertEqual(corrected.positions.first?.bookCost, Decimal(string: "275.10"),
                       "券商成本修正不改写 Episode 经济成本")
        XCTAssertEqual(correction.fills.count, 5)
        XCTAssertEqual(correction.audits.last?.action, "用户录入/修正券商展示成本")
        let context = FDecisionContext(snapshot: corrected, observations: [])
        XCTAssertEqual(context.holdings.first?.brokerDisplayCostPerUnit, Decimal(string: "11.07"))
        XCTAssertEqual(context.holdings.first?.bookCost, Decimal(string: "275.10"))
        XCTAssertEqual(context.dailyTradeSummaryDate, "2027-01-15")
        XCTAssertEqual(context.dailyTradeSummaries, corrected.dailyTradeSummaries)
        XCTAssertEqual(context.dailyPortfolioRealizedPnL, Decimal(string: "219.60"))
        XCTAssertNoThrow(try context.validate(now: now))
        let request = try FAdvisorQuestionRequest(question: "今天159352做T赚了多少？",
                                                 scope: .instrument(code), decisionContext: context, now: now)
        XCTAssertEqual(request.portfolioContext?.dailyTradeSummaries, [daily])
        XCTAssertEqual(request.portfolioContext?.dailyPortfolioRealizedPnL, Decimal(string: "219.60"))
        XCTAssertTrue(request.portfolioContext?.matches(context, scope: .instrument(code)) == true)
        let decodedRequest = try JSONDecoder().decode(FAdvisorQuestionRequest.self,
                                                      from: JSONEncoder().encode(request))
        XCTAssertTrue(decodedRequest.portfolioContext?.matches(context, scope: .instrument(code)) == true)
        XCTAssertEqual(decodedRequest.portfolioContext?.dailyTradeSummaryDate, "2027-01-15")
    }

    func testDailyTradeSummaryUsesConfirmedBuySellBuyFactsAndKeepsAmountsAndFeesSeparate() throws {
        let code = "159352"
        var book = FAccountBook(openingSnapshot: opening(cash: 1_000), cashBalance: 1_000,
                                updatedAt: now.addingTimeInterval(-60))
        func fill(_ sequence: UInt64, _ side: FTradeSide, _ units: Int64, _ price: Decimal,
                  _ tradedAt: Date, _ removed: Decimal? = nil) -> FConfirmedFill {
            FConfirmedFill(sequence: sequence, tradedAt: tradedAt, instrumentCode: code,
                           side: side, units: units, price: price,
                           fee: FETFTradeFeePolicy.defaultReferencePerFill,
                           costBasisRemoved: removed, userConfirmation: confirmation(),
                           instrumentName: "A500")
        }
        book = try book.applyingUserConfirmedFill(
            fill(1, .buy, 10, 10, now.addingTimeInterval(-30)), instrumentName: "A500", now: now)
        book = try book.applyingUserConfirmedFill(
            fill(2, .sell, 4, 12, now.addingTimeInterval(-20), Decimal(string: "40.04")!),
            instrumentName: "A500", now: now)
        book = try book.applyingUserConfirmedFill(
            fill(3, .buy, 5, 11, now.addingTimeInterval(-10)), instrumentName: "A500", now: now)
        let otherBuy = FConfirmedFill(sequence: 4, tradedAt: now.addingTimeInterval(-8),
                                      instrumentCode: "159866", side: .buy, units: 1, price: 20,
                                      fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                      userConfirmation: confirmation(), instrumentName: "日经ETF")
        book = try book.applyingUserConfirmedFill(otherBuy, instrumentName: "日经ETF", now: now)
        let otherSell = FConfirmedFill(sequence: 5, tradedAt: now.addingTimeInterval(-5),
                                       instrumentCode: "159866", side: .sell, units: 1, price: 21,
                                       fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                       costBasisRemoved: Decimal(string: "20.10")!,
                                       userConfirmation: confirmation(), instrumentName: "日经ETF")
        book = try book.applyingUserConfirmedFill(otherSell, instrumentName: "日经ETF", now: now)

        let snapshot = try book.readOnlySnapshot(capturedAt: now)
        let daily = try XCTUnwrap(snapshot.dailyTradeSummaries.first)
        XCTAssertEqual(snapshot.dailyTradeSummaryDate, "2027-01-15")
        XCTAssertEqual(daily.buyQuantity, 15)
        XCTAssertEqual(daily.buyAmount, 155)
        XCTAssertEqual(daily.sellQuantity, 4)
        XCTAssertEqual(daily.sellAmount, 48)
        XCTAssertEqual(daily.buyFees, Decimal(string: "0.20"))
        XCTAssertEqual(daily.sellFees, Decimal(string: "0.10"))
        XCTAssertEqual(daily.totalFees, Decimal(string: "0.30"))
        XCTAssertEqual(daily.realizedPnL, Decimal(string: "7.86"))
        XCTAssertEqual(daily.fillCount, 3)
        let context = FDecisionContext(snapshot: snapshot, observations: [])
        XCTAssertEqual(snapshot.dailyTradeSummaries.count, 2)
        XCTAssertEqual(snapshot.dailyTradeSummaries.last?.realizedPnL, Decimal(string: "0.80"))
        XCTAssertEqual(context.dailyPortfolioRealizedPnL, Decimal(string: "8.66"),
                       "组合当日已实现盈亏是所有证券confirmed-fill摘要的确定性合计")
        let portfolioRequest = try FAdvisorQuestionRequest(question: "今天所有操作赚亏多少？",
                                                            scope: .portfolio,
                                                            decisionContext: context, now: now)
        XCTAssertEqual(portfolioRequest.portfolioContext?.dailyTradeSummaries.count, 2)
        XCTAssertEqual(portfolioRequest.portfolioContext?.dailyPortfolioRealizedPnL,
                       Decimal(string: "8.66"))
        XCTAssertTrue(portfolioRequest.portfolioContext?.matches(context, scope: .portfolio) == true)
        let securityRequest = try FAdvisorQuestionRequest(question: "今天159352做T赚多少？",
                                                           scope: .instrument(code),
                                                           decisionContext: context, now: now)
        XCTAssertEqual(securityRequest.portfolioContext?.dailyTradeSummaries.map(\.securityCode), [code])
        XCTAssertEqual(securityRequest.portfolioContext?.dailyPortfolioRealizedPnL,
                       Decimal(string: "7.86"))
        XCTAssertTrue(securityRequest.portfolioContext?.matches(context, scope: .instrument(code)) == true)
        XCTAssertEqual(snapshot.positions.first?.bookCost, Decimal(string: "115.16"))
        XCTAssertEqual(snapshot.cashBalance, Decimal(string: "893.50"))
        XCTAssertTrue(daily.isValid(asOf: now))
    }

    func testDailyTradeSummarySeparatesPriorTradingDateFromCurrentDayFill() throws {
        let code = "159941"
        let yesterday = now.addingTimeInterval(-24 * 60 * 60 - 60)
        let initial = FAccountOpeningSnapshot(capturedAt: now.addingTimeInterval(-48 * 60 * 60),
                                              cashBalance: 1_000)
        var book = FAccountBook(openingSnapshot: initial, cashBalance: 1_000,
                                updatedAt: now.addingTimeInterval(-48 * 60 * 60))
        let priorDayBuy = FConfirmedFill(sequence: 1, tradedAt: yesterday, instrumentCode: code,
                                         side: .buy, units: 10, price: 5,
                                         fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                         userConfirmation: confirmation(), instrumentName: "纳指ETF")
        book = try book.applyingUserConfirmedFill(priorDayBuy, instrumentName: "纳指ETF", now: now)
        let todaySell = FConfirmedFill(sequence: 2, tradedAt: now.addingTimeInterval(-30),
                                       instrumentCode: code, side: .sell, units: 2, price: 6,
                                       fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                       costBasisRemoved: Decimal(string: "10.02")!,
                                       userConfirmation: confirmation(), instrumentName: "纳指ETF")
        book = try book.applyingUserConfirmedFill(todaySell, instrumentName: "纳指ETF", now: now)

        let snapshot = try book.readOnlySnapshot(capturedAt: now)
        let daily = try XCTUnwrap(snapshot.dailyTradeSummaries.first)
        XCTAssertEqual(daily.securityCode, code)
        XCTAssertEqual(daily.buyQuantity, 0, "前一交易日买入不得混入今天摘要")
        XCTAssertEqual(daily.buyAmount, 0)
        XCTAssertEqual(daily.sellQuantity, 2)
        XCTAssertEqual(daily.sellAmount, 12)
        XCTAssertEqual(daily.sellFees, FETFTradeFeePolicy.defaultReferencePerFill)
        XCTAssertEqual(daily.realizedPnL, Decimal(string: "1.88"))
        XCTAssertEqual(daily.fillCount, 1)
        XCTAssertEqual(daily.firstFillTime, todaySell.tradedAt)
        XCTAssertEqual(daily.lastFillTime, todaySell.tradedAt)
    }

    func testSameDayFullCloseAndRebuyKeepsSecurityDayPnLSeparateFromNewEpisodePnL() throws {
        let code = "159352"
        let prior = FPosition(instrumentCode: code, name: "A500", units: 1_000,
                              bookCost: 10_000)
        var book = FAccountBook(openingSnapshot: opening(cash: 50_000, positions: [prior]),
                                cashBalance: 50_000, positions: [prior],
                                updatedAt: now.addingTimeInterval(-120))
        let sell = FConfirmedFill(sequence: 1, tradedAt: now.addingTimeInterval(-60),
                                  instrumentCode: code, side: .sell, units: 1_000, price: 11,
                                  fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                  costBasisRemoved: 10_000, userConfirmation: confirmation(),
                                  instrumentName: "A500", tradeIntent: nil)
        book = try book.applyingUserConfirmedFill(sell, instrumentName: "A500", now: now)
        XCTAssertTrue(book.positions.isEmpty)
        let buyback = FConfirmedFill(sequence: 2, tradedAt: now.addingTimeInterval(-30),
                                     instrumentCode: code, side: .buy, units: 500, price: 10.50,
                                     fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                     userConfirmation: confirmation(), instrumentName: "A500",
                                     tradeIntent: nil)
        book = try book.applyingUserConfirmedFill(buyback, instrumentName: "A500", now: now)

        let snapshot = try book.readOnlySnapshot(capturedAt: now)
        let day = try XCTUnwrap(snapshot.dailyTradeSummaries.first)
        let history = try XCTUnwrap(snapshot.instrumentHistories.first)
        let current = try XCTUnwrap(history.episodes.last)
        let securityDayPnL = try FSecurityPnLCalculator.dailySecurityPnL(
            securityCode: code, tradingDate: day.tradingDate,
            startOfDayUnits: 1_000, previousClose: 10, trades: day,
            endOfDayUnits: 500, currentPrice: Decimal(string: "10.48")!)
        let currentEpisodeUnrealized = try FSecurityPnLCalculator.episodeUnrealizedPnL(
            units: current.currentUnits, bookCost: current.currentBookCost,
            currentPrice: Decimal(string: "10.48")!)

        XCTAssertEqual(securityDayPnL, Decimal(string: "989.80"),
                       "全天PnL保留旧Episode清仓收益及新Episode当日浮动")
        XCTAssertEqual(currentEpisodeUnrealized, Decimal(string: "-10.10"),
                       "新Episode只按重新买回的500份和本轮成本计算")
        XCTAssertEqual(current.netRealizedProfit, Decimal.zero)
        XCTAssertEqual(history.lifetimeRealizedProfit, Decimal(string: "999.90"))
        XCTAssertEqual(day.dailyRealizedTradingPnL, Decimal(string: "999.90"))
        XCTAssertNil(day.tContribution, "历史成交未记录用途标签时不得把普通清仓收益叫作T")
        XCTAssertEqual(snapshot.positions.first?.units, 500)
        XCTAssertEqual(snapshot.positions.first?.bookCost, Decimal(string: "5250.10"))
        XCTAssertEqual(snapshot.cashFlow.suffix(2).map(\.fee),
                       [FETFTradeFeePolicy.defaultReferencePerFill, FETFTradeFeePolicy.defaultReferencePerFill])
        XCTAssertEqual(snapshot.instrumentHistories.first?.episodes.count, 2)
        XCTAssertEqual(history.episodes.map(\.historyIsComplete), [false, true],
                       "导入时已有持仓的旧Episode不完整；确认买入开启的新Episode有完整成交事实")
        XCTAssertFalse(history.lifetimeHistoryIsComplete,
                       "导入前交易缺失时，不能声称证券生命周期累计完整")

        let quoteTime = now.addingTimeInterval(-1)
        let quote = FContextObservation(dataClass: .quote, subject: code, source: "test real quote",
                                        observedAt: quoteTime, capturedAt: now,
                                        decimalValue: Decimal(string: "10.48")!,
                                        quoteTemporalMetadata: FQuoteTemporalMetadata(
                                            quoteTimestamp: quoteTime, fetchedAt: now,
                                            source: "test real quote",
                                            timestampTrust: .verifiedExchangeTimestamp,
                                            marketSessionStatus: .closed))
        let context = FDecisionContext(snapshot: snapshot, observations: [quote])
        let facts = try XCTUnwrap(context.instrumentPnLFacts.first)
        XCTAssertNil(facts.securityDailyPnL,
                     "缺少经过验证的前收与今日开盘持仓标记时，不允许把已实现值冒充全天总盈亏")
        XCTAssertEqual(facts.dailyRealizedTradingPnL, Decimal(string: "999.90"))
        XCTAssertNil(facts.dailyTContribution)
        XCTAssertEqual(facts.currentEpisodeHistoryIsComplete, true)
        XCTAssertEqual(facts.currentEpisodeUnrealizedPnL, Decimal(string: "-10.10"))
        XCTAssertEqual(facts.currentEpisodeTotalPnL, Decimal(string: "-10.10"))
        XCTAssertEqual(facts.securityLifetimeHistoryIsComplete, false)
        XCTAssertNil(facts.securityLifetimeRealizedPnL)
        XCTAssertNil(facts.closedEpisodesRealizedPnL)
        XCTAssertNil(facts.securityLifetimeTotalPnL,
                     "导入前基准持仓的成本和已实现历史未知，不得冒充完整Lifetime P&L")
        XCTAssertEqual(facts.brokerDisplayCostPerUnit, nil)
        XCTAssertEqual(facts.episodeEconomicCostPerUnit, Decimal(string: "10.5002"))
        let request = try FAdvisorQuestionRequest(question: "今天这只赚了多少？",
                                                 scope: .instrument(code),
                                                 decisionContext: context, now: now)
        XCTAssertEqual(request.portfolioContext?.instrumentPnLFacts, [facts])

        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(context)) as? [String: Any])
        for key in ["instrumentPnLFacts", "positionHistory", "recentPositionEpisodes"] {
            guard var rows = legacyObject[key] as? [[String: Any]] else { continue }
            let completenessKeys = ["historyIsComplete", "lifetimeHistoryIsComplete",
                                   "currentEpisodeHistoryIsComplete", "securityLifetimeHistoryIsComplete"]
            rows = rows.map { row in
                var legacyRow = row
                completenessKeys.forEach { legacyRow.removeValue(forKey: $0) }
                return legacyRow
            }
            legacyObject[key] = rows
        }
        let legacyContext = try JSONDecoder().decode(FDecisionContext.self,
            from: JSONSerialization.data(withJSONObject: legacyObject))
        XCTAssertNil(legacyContext.instrumentPnLFacts.first?.securityLifetimeHistoryIsComplete,
                     "旧版DecisionContext缺少完整性字段时按未知处理，不能默认为完整")
        XCTAssertNil(legacyContext.recentPositionEpisodes.last?.historyIsComplete)
    }

    func testSecurityDayLossCanCoexistWithProfitOnSameDayRebuyEpisode() throws {
        let summary = try XCTUnwrap(FDailyTradeSummary.derive(from: [
            FConfirmedFill(sequence: 1, tradedAt: now.addingTimeInterval(-60),
                           instrumentCode: "159866", side: .sell, units: 1_000, price: 9,
                           fee: FETFTradeFeePolicy.defaultReferencePerFill, costBasisRemoved: 10_000,
                           userConfirmation: confirmation()),
            FConfirmedFill(sequence: 2, tradedAt: now.addingTimeInterval(-30),
                           instrumentCode: "159866", side: .buy, units: 500, price: 8,
                           fee: FETFTradeFeePolicy.defaultReferencePerFill,
                           userConfirmation: confirmation())
        ], asOf: now).first)
        let dailyPnL = try FSecurityPnLCalculator.dailySecurityPnL(
            securityCode: "159866", tradingDate: summary.tradingDate,
            startOfDayUnits: 1_000, previousClose: 10, trades: summary,
            endOfDayUnits: 500, currentPrice: Decimal(string: "8.10")!)
        let episodeUnrealized = try FSecurityPnLCalculator.episodeUnrealizedPnL(
            units: 500, bookCost: Decimal(string: "4000.10")!,
            currentPrice: Decimal(string: "8.10")!)
        XCTAssertLessThan(dailyPnL, 0)
        XCTAssertGreaterThan(episodeUnrealized, 0)
    }

    func testExplicitTContributionDoesNotReplaceSecurityLifetimePnLInEitherDirection() throws {
        func context(oldBuy: Decimal, tSell: Decimal, tBuyback: Decimal,
                     current: Decimal) throws -> FDecisionContext {
            let code = "159866"
            let priorDay = now.addingTimeInterval(-24 * 60 * 60)
            var book = FAccountBook(openingSnapshot: .init(
                capturedAt: now.addingTimeInterval(-48 * 60 * 60), cashBalance: 10_000),
                cashBalance: 10_000, updatedAt: now.addingTimeInterval(-48 * 60 * 60))
            let openingFill = FConfirmedFill(sequence: 1, tradedAt: priorDay,
                                             instrumentCode: code, side: .buy, units: 10,
                                             price: oldBuy,
                                             fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                             userConfirmation: confirmation(), tradeIntent: .ordinary)
            book = try book.applyingUserConfirmedFill(openingFill, instrumentName: "日经ETF", now: now)
            let cycle = "\(code)-cycle-1"
            let sell = FConfirmedFill(sequence: 2, tradedAt: now.addingTimeInterval(-60),
                                      instrumentCode: code, side: .sell, units: 10,
                                      price: tSell, fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                      costBasisRemoved: oldBuy * Decimal(10) + FETFTradeFeePolicy.defaultReferencePerFill,
                                      userConfirmation: confirmation(), instrumentName: "日经ETF",
                                      tradeIntent: .tSell, tCycleID: cycle)
            book = try book.applyingUserConfirmedFill(sell, instrumentName: "日经ETF", now: now)
            let buyback = FConfirmedFill(sequence: 3, tradedAt: now.addingTimeInterval(-30),
                                         instrumentCode: code, side: .buy, units: 10,
                                         price: tBuyback, fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                         userConfirmation: confirmation(), instrumentName: "日经ETF",
                                         tradeIntent: .tBuyback, tCycleID: cycle)
            book = try book.applyingUserConfirmedFill(buyback, instrumentName: "日经ETF", now: now)
            let snapshot = try book.readOnlySnapshot(capturedAt: now)
            let quoteTime = now.addingTimeInterval(-1)
            let quote = FContextObservation(
                dataClass: .quote, subject: code, source: "test quote", observedAt: quoteTime,
                capturedAt: now, decimalValue: current,
                quoteTemporalMetadata: FQuoteTemporalMetadata(
                    quoteTimestamp: quoteTime, fetchedAt: now, source: "test quote",
                    timestampTrust: .verifiedExchangeTimestamp, marketSessionStatus: .closed))
            return FDecisionContext(snapshot: snapshot, observations: [quote])
        }

        let profitableT = try context(oldBuy: 15, tSell: 12, tBuyback: 9, current: 8)
        let profitFacts = try XCTUnwrap(profitableT.instrumentPnLFacts.first)
        XCTAssertEqual(profitFacts.dailyTContribution, Decimal(string: "29.80"))
        XCTAssertEqual(profitFacts.cumulativeTContribution, Decimal(string: "29.80"))
        XCTAssertEqual(profitFacts.currentEpisodeUnrealizedPnL, Decimal(string: "-10.10"))
        XCTAssertEqual(profitFacts.securityLifetimeRealizedPnL, Decimal(string: "-30.20"))
        XCTAssertEqual(profitFacts.securityLifetimeTotalPnL, Decimal(string: "-40.30"),
                       "T贡献为正时，证券整体仍可亏损")

        let losingT = try context(oldBuy: 5, tSell: 12, tBuyback: 13, current: Decimal(string: "13.50")!)
        let lossFacts = try XCTUnwrap(losingT.instrumentPnLFacts.first)
        XCTAssertEqual(lossFacts.dailyTContribution, Decimal(string: "-10.20"))
        XCTAssertEqual(lossFacts.currentEpisodeUnrealizedPnL, Decimal(string: "4.90"))
        XCTAssertEqual(lossFacts.securityLifetimeTotalPnL, Decimal(string: "74.70"),
                       "T贡献为负时，证券历史总体仍可盈利")
    }

    func testTContributionIsUnavailableForLegacyOrUnbalancedCycles() throws {
        let tSell = FConfirmedFill(sequence: 1, tradedAt: now.addingTimeInterval(-60),
                                   instrumentCode: "159866", side: .sell, units: 10, price: 12,
                                   fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                   costBasisRemoved: 100, userConfirmation: confirmation(),
                                   tradeIntent: .tSell, tCycleID: "cycle-1")
        let partialBuyback = FConfirmedFill(sequence: 2, tradedAt: now.addingTimeInterval(-30),
                                            instrumentCode: "159866", side: .buy, units: 9, price: 10,
                                            fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                            userConfirmation: confirmation(), tradeIntent: .tBuyback,
                                            tCycleID: "cycle-1")
        XCTAssertNil(FTradeContributionCalculator.contribution(from: [tSell, partialBuyback]),
                     "未完全配对的T数量不应伪装成精确贡献")

        let legacyFill = FConfirmedFill(sequence: 3, tradedAt: now,
                                        instrumentCode: "159866", side: .buy, units: 1,
                                        price: 10, fee: FETFTradeFeePolicy.defaultReferencePerFill,
                                        userConfirmation: confirmation(), tradeIntent: nil)
        XCTAssertNil(FTradeContributionCalculator.contribution(from: [tSell, partialBuyback, legacyFill]),
                     "存在未分类旧成交时，累计T贡献保持Unavailable")
    }

    func testBuyWithInsufficientCashDoesNotReturnChangedBook() {
        let source = FAccountBook(openingSnapshot: opening(cash: 100), cashBalance: 100, updatedAt: now.addingTimeInterval(-60))
        let fill = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .buy, units: 100,
                                  price: 3, fee: 1, userConfirmation: confirmation())
        XCTAssertThrowsError(try source.applyingUserConfirmedFill(fill, instrumentName: "ETF", now: now)) {
            XCTAssertEqual($0 as? FLedgerMutationError, .insufficientCash)
        }
        XCTAssertEqual(source.cashBalance, 100)
        XCTAssertTrue(source.positions.isEmpty)
        XCTAssertTrue(source.fills.isEmpty)
    }

    func testConfirmedFillMustUseNextLedgerSequence() {
        let first = FConfirmedFill(sequence: 1, tradedAt: now.addingTimeInterval(-120),
                                   instrumentCode: "510300", side: .buy, units: 100,
                                   price: 3, fee: 1,
                                   userConfirmation: .init(confirmedAt: now.addingTimeInterval(-60),
                                                           confirmationNote: "已确认成交"))
        let position = FPosition(instrumentCode: "510300", name: "ETF", units: 100, bookCost: 301)
        let source = FAccountBook(openingSnapshot: opening(cash: 1000), cashBalance: 699,
                                  positions: [position], fills: [first],
                                  updatedAt: now.addingTimeInterval(-60))
        let outOfOrder = FConfirmedFill(sequence: 3, tradedAt: now, instrumentCode: "510300",
                                        side: .buy, units: 1, price: 3, fee: 0,
                                        userConfirmation: confirmation())
        XCTAssertThrowsError(try source.applyingUserConfirmedFill(outOfOrder, instrumentName: "ETF", now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError,
                           .invalidEventSequence(expected: 2, actual: 3))
        }
    }

    func testPartialSaleCostBasisUsesEightDecimalAverageAllocation() throws {
        let partial = try FAccountingPolicy.costBasisRemoved(
            unitsSold: 1, totalUnits: 3, totalBookCost: Decimal(string: "10")!)
        XCTAssertEqual(partial, Decimal(string: "3.33333333")!)
        let final = try FAccountingPolicy.costBasisRemoved(
            unitsSold: 2, totalUnits: 2, totalBookCost: Decimal(string: "6.66666667")!)
        XCTAssertEqual(final, Decimal(string: "6.66666667")!)
    }

    func testCostBasisAllocationRejectsInvalidShareCounts() {
        XCTAssertThrowsError(try FAccountingPolicy.costBasisRemoved(
            unitsSold: 0, totalUnits: 3, totalBookCost: 10)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .invalidCostAllocation)
        }
    }

    func testPartialSaleAppliesPolicyAndPreservesRemainingCost() throws {
        let position = FPosition(instrumentCode: "510300", name: "ETF", units: 3,
                                 bookCost: Decimal(string: "10")!)
        let source = FAccountBook(openingSnapshot: opening(cash: 100, positions: [position]),
                                  cashBalance: 100, positions: [position], updatedAt: now.addingTimeInterval(-60))
        let sale = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .sell,
                                  units: 1, price: 5, fee: 0,
                                  costBasisRemoved: Decimal(string: "3.33333333")!,
                                  userConfirmation: confirmation())
        let updated = try source.applyingUserConfirmedFill(sale, instrumentName: "ETF", now: now)
        XCTAssertEqual(updated.positions.first?.units, 2)
        XCTAssertEqual(updated.positions.first?.bookCost, Decimal(string: "6.66666667")!)
        XCTAssertEqual(updated.cashBalance, 105)
    }

    func testPartialSaleRejectsCallerCostBasisOutsidePolicy() {
        let position = FPosition(instrumentCode: "510300", name: "ETF", units: 3,
                                 bookCost: Decimal(string: "10")!)
        let source = FAccountBook(openingSnapshot: opening(cash: 100, positions: [position]),
                                  cashBalance: 100, positions: [position], updatedAt: now.addingTimeInterval(-60))
        let sale = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .sell,
                                  units: 1, price: 5, fee: 0, costBasisRemoved: 3,
                                  userConfirmation: confirmation())
        XCTAssertThrowsError(try source.applyingUserConfirmedFill(sale, instrumentName: "ETF", now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError,
                           .costBasisPolicyMismatch(sequence: 1,
                                                   expected: Decimal(string: "3.33333333")!, actual: 3))
        }
    }

    func testUserConfirmedDepositReturnsAuditedBookWithoutMutatingSource() throws {
        let source = FAccountBook(openingSnapshot: opening(cash: 100), cashBalance: 100,
                                  updatedAt: now.addingTimeInterval(-60))
        let movement = FCashMovement(sequence: 1, occurredAt: now, amount: 50, reason: "确认入金",
                                     userConfirmation: confirmation())
        let updated = try source.applyingUserConfirmedCashMovement(movement, now: now)
        XCTAssertEqual(source.cashBalance, 100)
        XCTAssertEqual(updated.cashBalance, 150)
        XCTAssertEqual(updated.cashMovements.count, 1)
        XCTAssertEqual(updated.audits.count, 1)
        XCTAssertNotEqual(updated.audits[0].priorLedgerDigest, updated.audits[0].resultingLedgerDigest)
    }

    func testUserConfirmedWithdrawalCannotOverdrawCash() {
        let source = FAccountBook(openingSnapshot: opening(cash: 100), cashBalance: 100,
                                  updatedAt: now.addingTimeInterval(-60))
        let movement = FCashMovement(sequence: 1, occurredAt: now, amount: -101, reason: "确认出金",
                                     userConfirmation: confirmation())
        XCTAssertThrowsError(try source.applyingUserConfirmedCashMovement(movement, now: now)) {
            XCTAssertEqual($0 as? FLedgerMutationError, .insufficientCash)
        }
        XCTAssertEqual(source.cashBalance, 100)
        XCTAssertTrue(source.cashMovements.isEmpty)
    }

    func testCashMovementMustUseNextLedgerSequence() {
        let source = FAccountBook(openingSnapshot: opening(cash: 100), cashBalance: 100,
                                  updatedAt: now.addingTimeInterval(-60))
        let movement = FCashMovement(sequence: 2, occurredAt: now, amount: 50, reason: "确认入金",
                                     userConfirmation: confirmation())
        XCTAssertThrowsError(try source.applyingUserConfirmedCashMovement(movement, now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError,
                           .invalidEventSequence(expected: 1, actual: 2))
        }
    }

    func testCashMovementRequiresNonblankUserConfirmation() {
        let movement = FCashMovement(sequence: 1, occurredAt: now, amount: 50, reason: "入金",
                                     userConfirmation: .init(confirmedAt: now, confirmationNote: " "))
        let book = FAccountBook(openingSnapshot: opening(cash: 100), cashBalance: 150,
                                cashMovements: [movement], updatedAt: now)
        XCTAssertThrowsError(try book.validate(now: now)) {
            XCTAssertEqual($0 as? FLedgerValidationError, .invalidCashMovementConfirmation(movement.id))
        }
    }

    func testConfirmedFullSaleRemovesPositionAndReconcilesCash() throws {
        let openingPosition = FPosition(instrumentCode: "510300", name: "ETF", units: 100, bookCost: 100)
        let source = FAccountBook(openingSnapshot: opening(cash: 10, positions: [openingPosition]),
                                  cashBalance: 10, positions: [openingPosition], updatedAt: now.addingTimeInterval(-60))
        let fill = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "510300", side: .sell, units: 100,
                                  price: 3, fee: 1, costBasisRemoved: 100, userConfirmation: confirmation())
        let updated = try source.applyingUserConfirmedFill(fill, instrumentName: "ETF", now: now)
        XCTAssertEqual(updated.cashBalance, 309)
        XCTAssertTrue(updated.positions.isEmpty)
        XCTAssertEqual(updated.fills.count, 1)
        XCTAssertEqual(updated.audits.count, 1)
    }

    private func confirmation() -> FUserTradeConfirmation {
        .init(confirmedAt: now, confirmationNote: "已核对券商成交")
    }
}


