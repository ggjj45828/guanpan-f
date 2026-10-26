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

    func testConfirmedCloseAndReopenRetainsHistoryAndStartsFreshEpisodeAndCashFlow() throws {
        let code = "159352"
        var book = FAccountBook(openingSnapshot: opening(cash: 10_000), cashBalance: 10_000,
                                updatedAt: now.addingTimeInterval(-60))
        let buy1 = FConfirmedFill(sequence: 1, tradedAt: now.addingTimeInterval(-30),
                                  instrumentCode: code, side: .buy, units: 100, price: 10,
                                  fee: FETFTradeFeePolicy.perConfirmedFill,
                                  userConfirmation: confirmation(), instrumentName: "A500")
        book = try book.applyingUserConfirmedFill(buy1, instrumentName: "A500", now: now)
        let sell = FConfirmedFill(sequence: 2, tradedAt: now.addingTimeInterval(-20),
                                  instrumentCode: code, side: .sell, units: 100, price: 12,
                                  fee: FETFTradeFeePolicy.perConfirmedFill, costBasisRemoved: 1_000.10,
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
                                  fee: FETFTradeFeePolicy.perConfirmedFill,
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
                       Array(repeating: FETFTradeFeePolicy.perConfirmedFill, count: 3))
        XCTAssertEqual(snapshot.cashFlow.map(\.cashDelta), [-1_000.10, 1_199.90, -550.10])
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
                                  units: 40, price: 12, fee: FETFTradeFeePolicy.perConfirmedFill,
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
                                     fee: FETFTradeFeePolicy.perConfirmedFill,
                                     userConfirmation: confirmation(), instrumentName: "A500")
            book = try book.applyingUserConfirmedFill(buy, instrumentName: "A500", now: now)
            sequence += 1
            let sell = FConfirmedFill(sequence: sequence, tradedAt: now.addingTimeInterval(TimeInterval(episode - 9)),
                                      instrumentCode: "159352", side: .sell, units: 10, price: 11,
                                      fee: FETFTradeFeePolicy.perConfirmedFill, costBasisRemoved: 100.10,
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
                       Array(repeating: FETFTradeFeePolicy.perConfirmedFill, count: 6))
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


