import Foundation

/// A real, user-owned account snapshot. Storage- and UI-agnostic by design.
/// Candidate plans, AI outputs, quotes, and research evidence have no ledger fields.
public struct FAccountBook: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let accountID: UUID
    public var schemaVersion: Int
    public var currencyCode: String
    public var openingSnapshot: FAccountOpeningSnapshot
    public var cashBalance: Decimal
    public var positions: [FPosition]
    /// Latest user-confirmed broker display cost per security, retained across full closes.
    /// Optional for backward-compatible decoding of existing account files.
    public var brokerDisplayCosts: [FBrokerDisplayCostRecord]?
    /// Append-only fee corrections. Nil is the legacy-file representation of no corrections.
    public var feeAdjustments: [FFillFeeAdjustment]?
    public var fills: [FConfirmedFill]
    public var cashMovements: [FCashMovement]
    public var audits: [FLedgerAuditEvent]
    public var updatedAt: Date

    public init(accountID: UUID = UUID(), currencyCode: String = "CNY",
                openingSnapshot: FAccountOpeningSnapshot, cashBalance: Decimal,
                positions: [FPosition] = [], fills: [FConfirmedFill] = [],
                brokerDisplayCosts: [FBrokerDisplayCostRecord]? = nil,
                feeAdjustments: [FFillFeeAdjustment]? = nil,
                cashMovements: [FCashMovement] = [], audits: [FLedgerAuditEvent] = [],
                updatedAt: Date = Date(), schemaVersion: Int = FAccountBook.currentSchemaVersion) {
        self.accountID = accountID
        self.schemaVersion = schemaVersion
        self.currencyCode = currencyCode
        self.openingSnapshot = openingSnapshot
        self.cashBalance = cashBalance
        self.positions = positions
        self.brokerDisplayCosts = brokerDisplayCosts
        self.feeAdjustments = feeAdjustments
        self.fills = fills
        self.cashMovements = cashMovements
        self.audits = audits
        self.updatedAt = updatedAt
    }
}

/// An immutable correction event that changes the effective fee attributed to one
/// confirmed fill. Cash settles at this event's sequence; economics are replayed at the
/// original fill date. The original FConfirmedFill is never rewritten.
public struct FFillFeeAdjustment: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let sequence: UInt64
    public let fillID: UUID
    /// Positive means additional fee owed; negative means fee returned by the broker.
    public let feeDelta: Decimal
    public let occurredAt: Date
    public let reason: String
    public let userConfirmation: FUserLedgerConfirmation

    public init(id: UUID = UUID(), sequence: UInt64, fillID: UUID, feeDelta: Decimal,
                occurredAt: Date, reason: String,
                userConfirmation: FUserLedgerConfirmation) {
        self.id = id
        self.sequence = sequence
        self.fillID = fillID
        self.feeDelta = feeDelta
        self.occurredAt = occurredAt
        self.reason = reason
        self.userConfirmation = userConfirmation
    }
}

public struct FBrokerDisplayCostRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String { instrumentCode }
    public let instrumentCode: String
    public let costPerUnit: Decimal
    public let updatedAt: Date

    public init(instrumentCode: String, costPerUnit: Decimal, updatedAt: Date) {
        self.instrumentCode = instrumentCode
        self.costPerUnit = costPerUnit
        self.updatedAt = updatedAt
    }
}

/// Verified starting point for the F ledger. Imported historical accounts can begin here;
/// only subsequent confirmed events are replayed against it.
public struct FAccountOpeningSnapshot: Codable, Equatable, Sendable {
    public var capturedAt: Date
    public var cashBalance: Decimal
    public var positions: [FPosition]

    public init(capturedAt: Date, cashBalance: Decimal, positions: [FPosition] = []) {
        self.capturedAt = capturedAt
        self.cashBalance = cashBalance
        self.positions = positions
    }
}

public struct FPosition: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var instrumentCode: String
    public var name: String
    public var units: Int64
    /// Total acquisition cost attributed to currently held units, including allocated fees.
    public var bookCost: Decimal
    public var acquiredAt: Date?
    /// User-entered external broker display basis per unit. This is informational and
    /// never participates in cash, fill, or economic-cost reconciliation.
    public var brokerDisplayCostPerUnit: Decimal?
    public var brokerDisplayCostUpdatedAt: Date?

    public init(id: UUID = UUID(), instrumentCode: String, name: String, units: Int64,
                bookCost: Decimal, acquiredAt: Date? = nil,
                brokerDisplayCostPerUnit: Decimal? = nil,
                brokerDisplayCostUpdatedAt: Date? = nil) {
        self.id = id
        self.instrumentCode = instrumentCode
        self.name = name
        self.units = units
        self.bookCost = bookCost
        self.acquiredAt = acquiredAt
        self.brokerDisplayCostPerUnit = brokerDisplayCostPerUnit
        self.brokerDisplayCostUpdatedAt = brokerDisplayCostUpdatedAt
    }
}

/// One cost-allocation rule for the entire F ledger. Monetary event inputs retain their exact
/// Decimal values; only partial-sale cost basis is rounded, to eight decimal places in CNY.
public enum FAccountingPolicy {
    public static let partialCostBasisScale: Int = 8

    public static func costBasisRemoved(unitsSold: Int64, totalUnits: Int64,
                                        totalBookCost: Decimal) throws -> Decimal {
        guard unitsSold > 0, totalUnits > 0, unitsSold <= totalUnits,
              totalBookCost.isFinite, totalBookCost >= 0 else {
            throw FLedgerValidationError.invalidCostAllocation
        }
        if unitsSold == totalUnits { return totalBookCost }
        var soldUnits = Decimal(unitsSold)
        var allUnits = Decimal(totalUnits)
        var share = Decimal.zero
        let divisionStatus = NSDecimalDivide(&share, &soldUnits, &allUnits, .plain)
        guard (divisionStatus == .noError || divisionStatus == .lossOfPrecision),
              share.isFinite, share >= 0, share <= 1 else {
            throw FLedgerValidationError.invalidCostAllocation
        }
        var cost = totalBookCost
        var raw = Decimal.zero
        let multiplicationStatus = NSDecimalMultiply(&raw, &cost, &share, .plain)
        guard (multiplicationStatus == .noError || multiplicationStatus == .lossOfPrecision),
              raw.isFinite else { throw FLedgerValidationError.invalidCostAllocation }
        var input = raw
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, partialCostBasisScale, .plain)
        guard rounded.isFinite, rounded >= 0, rounded <= totalBookCost else {
            throw FLedgerValidationError.invalidCostAllocation
        }
        return rounded
    }
}

/// Suggested ETF fee reference for the fill-confirmation form. Real fills must
/// store the fee confirmed by the user from the broker, which may differ.
public enum FETFTradeFeePolicy {
    public static let defaultReferencePerFill = Decimal(string: "0.10")!
}

public enum FTradeSide: String, Codable, Equatable, Sendable { case buy, sell }
public enum FTradeIntent: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    case ordinary, tSell, tBuyback

    public var displayName: String {
        switch self {
        case .ordinary: return "普通交易"
        case .tSell: return "做T卖出"
        case .tBuyback: return "做T买回"
        }
    }
}

/// Required confirmation metadata. The eventual ledger-writing use case must additionally be
/// callable only from an explicit user confirmation action; these fields alone cannot prove actor identity.
public struct FUserLedgerConfirmation: Codable, Equatable, Sendable {
    public var confirmedAt: Date
    public var confirmationNote: String

    public init(confirmedAt: Date, confirmationNote: String) {
        self.confirmedAt = confirmedAt
        self.confirmationNote = confirmationNote
    }
}

public typealias FUserTradeConfirmation = FUserLedgerConfirmation

public struct FConfirmedFill: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    /// Monotonic ledger-event order, assigned by the account store. Timestamps are descriptive
    /// and may collide or be entered late; they must not decide the accounting replay order.
    public var sequence: UInt64
    public var tradedAt: Date
    public var instrumentCode: String
    /// The security name at this event. Optional only for backward decoding of existing ledgers.
    public var instrumentName: String?
    public var side: FTradeSide
    public var units: Int64
    public var price: Decimal
    public var fee: Decimal
    /// Required for sells; the amount of existing book cost removed from the position.
    /// Nil for buys. Realized profit is proceeds minus fee minus this amount.
    public var costBasisRemoved: Decimal?
    public var userConfirmation: FUserLedgerConfirmation
    /// Nil is retained only for legacy fills whose user intent was never captured.
    public var tradeIntent: FTradeIntent?
    /// Shared explicit ID joining the sell and buyback legs of one T cycle.
    public var tCycleID: String?

    public init(id: UUID = UUID(), sequence: UInt64, tradedAt: Date, instrumentCode: String, side: FTradeSide,
                units: Int64, price: Decimal, fee: Decimal,
                costBasisRemoved: Decimal? = nil, userConfirmation: FUserLedgerConfirmation,
                instrumentName: String? = nil, tradeIntent: FTradeIntent? = .ordinary,
                tCycleID: String? = nil) {
        self.id = id
        self.sequence = sequence
        self.tradedAt = tradedAt
        self.instrumentCode = instrumentCode
        self.instrumentName = instrumentName
        self.side = side
        self.units = units
        self.price = price
        self.fee = fee
        self.costBasisRemoved = costBasisRemoved
        self.userConfirmation = userConfirmation
        self.tradeIntent = tradeIntent
        self.tCycleID = tCycleID
    }
}

public struct FCashMovement: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var sequence: UInt64
    public var occurredAt: Date
    /// Positive for deposits/income; negative for withdrawals/outflows.
    public var amount: Decimal
    /// Optional for legacy movements. Separates account-level costs from broker cash
    /// reconciliation without attributing either to a security or a fill.
    public var category: FCashMovementCategory?
    public var reason: String
    public var userConfirmation: FUserLedgerConfirmation

    public init(id: UUID = UUID(), sequence: UInt64, occurredAt: Date, amount: Decimal,
                category: FCashMovementCategory? = nil, reason: String,
                userConfirmation: FUserLedgerConfirmation) {
        self.id = id
        self.sequence = sequence
        self.occurredAt = occurredAt
        self.amount = amount
        self.category = category
        self.reason = reason
        self.userConfirmation = userConfirmation
    }
}

public enum FCashMovementCategory: String, Codable, Equatable, Sendable {
    case accountExpense
    case cashReconciliation
}

public struct FLedgerAuditEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var occurredAt: Date
    public var action: String
    public var reason: String
    public var priorLedgerDigest: String?
    public var resultingLedgerDigest: String

    public init(id: UUID = UUID(), occurredAt: Date, action: String, reason: String,
                priorLedgerDigest: String?, resultingLedgerDigest: String) {
        self.id = id
        self.occurredAt = occurredAt
        self.action = action
        self.reason = reason
        self.priorLedgerDigest = priorLedgerDigest
        self.resultingLedgerDigest = resultingLedgerDigest
    }
}

public enum FLedgerValidationError: Error, Equatable, Sendable {
    case unsupportedSchema(Int), invalidCurrency, invalidCash
    case duplicatePositionID(UUID), duplicateInstrument(String), invalidPosition(UUID)
    case duplicateFillID(UUID), duplicateEventSequence(UInt64), invalidEventSequence(expected: UInt64, actual: UInt64)
    case invalidFill(UUID), invalidConfirmation(UUID), invalidBrokerDisplayCostRecord(String)
    case invalidTradeClassification(UUID)
    case duplicateFeeAdjustmentID(UUID), invalidFeeAdjustment(UUID), feeAdjustmentTargetMissing(UUID)
    case duplicateCashMovementID(UUID), invalidCashMovement(UUID), invalidCashMovementConfirmation(UUID)
    case duplicateAuditID(UUID), invalidAudit(UUID), implausibleTimestamp(String)
    case invalidOpeningSnapshot, unexpectedSellCostBasis(UUID), missingSellCostBasis(UUID)
    case invalidCostAllocation, costBasisPolicyMismatch(sequence: UInt64, expected: Decimal, actual: Decimal)
    case cashReconciliation(expected: Decimal, actual: Decimal)
    case historicalCashUnderflow(sequence: UInt64)
    case positionUnitReconciliation(code: String, expected: Int64, actual: Int64)
    case positionCostReconciliation(code: String, expected: Decimal, actual: Decimal)
    case positionQuantityOverflow(String), positionUnitUnderflow(String)
}

public extension FAccountBook {
    /// Structural/semantic checks only. This function never mutates the account or applies trades.
    func validate(now: Date = Date()) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw FLedgerValidationError.unsupportedSchema(schemaVersion)
        }
        guard currencyCode == "CNY" else { throw FLedgerValidationError.invalidCurrency }
        guard Self.isFinite(cashBalance), cashBalance >= 0 else { throw FLedgerValidationError.invalidCash }
        guard Self.isFinite(openingSnapshot.cashBalance), openingSnapshot.cashBalance >= 0,
              Self.isPlausible(openingSnapshot.capturedAt, now: now) else {
            throw FLedgerValidationError.invalidOpeningSnapshot
        }
        guard Self.isPlausible(updatedAt, now: now) else {
            throw FLedgerValidationError.implausibleTimestamp("updatedAt")
        }

        for collection in [openingSnapshot.positions, positions] {
            var positionIDs = Set<UUID>()
            var instrumentCodes = Set<String>()
            for position in collection {
                guard positionIDs.insert(position.id).inserted else {
                    throw FLedgerValidationError.duplicatePositionID(position.id)
                }
                let code = position.instrumentCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard instrumentCodes.insert(code).inserted else {
                    throw FLedgerValidationError.duplicateInstrument(code)
                }
                guard position.instrumentCode == code, Self.validCode(code), !position.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      position.units > 0, Self.isFinite(position.bookCost), position.bookCost >= 0 else {
                    throw FLedgerValidationError.invalidPosition(position.id)
                }
                if let brokerCost = position.brokerDisplayCostPerUnit,
                   !Self.isFinite(brokerCost) || brokerCost < 0 {
                    throw FLedgerValidationError.invalidPosition(position.id)
                }
                if let costUpdatedAt = position.brokerDisplayCostUpdatedAt,
                   !Self.isPlausible(costUpdatedAt, now: now) {
                    throw FLedgerValidationError.implausibleTimestamp("position.brokerDisplayCostUpdatedAt")
                }
                if let acquiredAt = position.acquiredAt, !Self.isPlausible(acquiredAt, now: now) {
                    throw FLedgerValidationError.implausibleTimestamp("position.acquiredAt")
                }
            }
        }

        var brokerCostCodes = Set<String>()
        for record in brokerDisplayCosts ?? [] {
            guard Self.validCode(record.instrumentCode),
                  brokerCostCodes.insert(record.instrumentCode).inserted,
                  Self.isFinite(record.costPerUnit), record.costPerUnit >= 0,
                  Self.isPlausible(record.updatedAt, now: now) else {
                throw FLedgerValidationError.invalidBrokerDisplayCostRecord(record.instrumentCode)
            }
        }

        var fillIDs = Set<UUID>()
        var eventSequences = Set<UInt64>()
        for fill in fills {
            guard fillIDs.insert(fill.id).inserted else { throw FLedgerValidationError.duplicateFillID(fill.id) }
            guard fill.sequence > 0, eventSequences.insert(fill.sequence).inserted else {
                throw FLedgerValidationError.duplicateEventSequence(fill.sequence)
            }
            guard fill.instrumentCode == fill.instrumentCode.trimmingCharacters(in: .whitespacesAndNewlines),
                  Self.validCode(fill.instrumentCode), fill.units > 0,
                  Self.isFinite(fill.price), fill.price > 0, Self.isFinite(fill.fee), fill.fee >= 0 else {
                throw FLedgerValidationError.invalidFill(fill.id)
            }
            if let name = fill.instrumentName,
               name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw FLedgerValidationError.invalidFill(fill.id)
            }
            switch fill.tradeIntent {
            case .ordinary:
                guard fill.tCycleID == nil else { throw FLedgerValidationError.invalidTradeClassification(fill.id) }
            case .tSell:
                guard fill.side == .sell,
                      let cycle = fill.tCycleID,
                      !cycle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw FLedgerValidationError.invalidTradeClassification(fill.id)
                }
            case .tBuyback:
                guard fill.side == .buy,
                      let cycle = fill.tCycleID,
                      !cycle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw FLedgerValidationError.invalidTradeClassification(fill.id)
                }
            case nil:
                guard fill.tCycleID == nil else { throw FLedgerValidationError.invalidTradeClassification(fill.id) }
            }
            if fill.side == .buy {
                guard fill.costBasisRemoved == nil else {
                    throw FLedgerValidationError.unexpectedSellCostBasis(fill.id)
                }
            } else {
                guard let removed = fill.costBasisRemoved else {
                    throw FLedgerValidationError.missingSellCostBasis(fill.id)
                }
                guard removed >= 0, removed.isFinite else {
                    throw FLedgerValidationError.invalidFill(fill.id)
                }
                guard Self.isFinite(removed), removed >= 0 else {
                    throw FLedgerValidationError.invalidFill(fill.id)
                }
            }
            guard !fill.userConfirmation.confirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw FLedgerValidationError.invalidConfirmation(fill.id)
            }
            guard Self.isPlausible(fill.tradedAt, now: now),
                  Self.isPlausible(fill.userConfirmation.confirmedAt, now: now),
                  fill.tradedAt >= openingSnapshot.capturedAt,
                  fill.userConfirmation.confirmedAt >= fill.tradedAt else {
                throw FLedgerValidationError.implausibleTimestamp("fill")
            }
        }

        let fillsByID = Dictionary(uniqueKeysWithValues: fills.map { ($0.id, $0) })
        var feeAdjustmentIDs = Set<UUID>()
        var effectiveFees = Dictionary(uniqueKeysWithValues: fills.map { ($0.id, $0.fee) })
        for adjustment in (feeAdjustments ?? []).sorted(by: { $0.sequence < $1.sequence }) {
            guard feeAdjustmentIDs.insert(adjustment.id).inserted else {
                throw FLedgerValidationError.duplicateFeeAdjustmentID(adjustment.id)
            }
            guard adjustment.sequence > 0, eventSequences.insert(adjustment.sequence).inserted else {
                throw FLedgerValidationError.duplicateEventSequence(adjustment.sequence)
            }
            guard let fill = fillsByID[adjustment.fillID] else {
                throw FLedgerValidationError.feeAdjustmentTargetMissing(adjustment.fillID)
            }
            guard adjustment.sequence > fill.sequence,
                  Self.isFinite(adjustment.feeDelta), adjustment.feeDelta != 0,
                  !adjustment.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  Self.isPlausible(adjustment.occurredAt, now: now),
                  adjustment.occurredAt >= fill.tradedAt,
                  Self.isPlausible(adjustment.userConfirmation.confirmedAt, now: now),
                  adjustment.userConfirmation.confirmedAt >= adjustment.occurredAt,
                  !adjustment.userConfirmation.confirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw FLedgerValidationError.invalidFeeAdjustment(adjustment.id)
            }
            let correctedFee = (effectiveFees[adjustment.fillID] ?? fill.fee) + adjustment.feeDelta
            guard Self.isFinite(correctedFee), correctedFee >= 0 else {
                throw FLedgerValidationError.invalidFeeAdjustment(adjustment.id)
            }
            effectiveFees[adjustment.fillID] = correctedFee
        }

        var movementIDs = Set<UUID>()
        for movement in cashMovements {
            guard movementIDs.insert(movement.id).inserted else {
                throw FLedgerValidationError.duplicateCashMovementID(movement.id)
            }
            guard movement.sequence > 0, eventSequences.insert(movement.sequence).inserted else {
                throw FLedgerValidationError.duplicateEventSequence(movement.sequence)
            }
            guard Self.isFinite(movement.amount), movement.amount != 0,
                  movement.category != .accountExpense || movement.amount < 0,
                  !movement.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw FLedgerValidationError.invalidCashMovement(movement.id)
            }
            guard Self.isPlausible(movement.occurredAt, now: now) else {
                throw FLedgerValidationError.implausibleTimestamp("cashMovement")
            }
            guard !movement.userConfirmation.confirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  Self.isPlausible(movement.userConfirmation.confirmedAt, now: now),
                  movement.userConfirmation.confirmedAt >= movement.occurredAt else {
                throw FLedgerValidationError.invalidCashMovementConfirmation(movement.id)
            }
            guard movement.occurredAt >= openingSnapshot.capturedAt else {
                throw FLedgerValidationError.implausibleTimestamp("cashMovement.beforeOpening")
            }
        }

        enum ConfirmationEvent {
            case fill(FConfirmedFill)
            case movement(FCashMovement)
            case feeAdjustment(FFillFeeAdjustment)

            var sequence: UInt64 {
                switch self {
                case .fill(let value): value.sequence
                case .movement(let value): value.sequence
                case .feeAdjustment(let value): value.sequence
                }
            }

            var confirmedAt: Date {
                switch self {
                case .fill(let value): value.userConfirmation.confirmedAt
                case .movement(let value): value.userConfirmation.confirmedAt
                case .feeAdjustment(let value): value.userConfirmation.confirmedAt
                }
            }
        }
        let confirmationEvents = fills.map(ConfirmationEvent.fill) +
            cashMovements.map(ConfirmationEvent.movement) +
            (feeAdjustments ?? []).map(ConfirmationEvent.feeAdjustment)
        var previousConfirmationAt: Date?
        for event in confirmationEvents.sorted(by: { $0.sequence < $1.sequence }) {
            if let previousConfirmationAt, event.confirmedAt < previousConfirmationAt {
                throw FLedgerValidationError.implausibleTimestamp("ledgerEventConfirmationOrder")
            }
            previousConfirmationAt = event.confirmedAt
        }
        if let previousConfirmationAt, updatedAt < previousConfirmationAt {
            throw FLedgerValidationError.implausibleTimestamp("updatedAt.beforeLedgerEvent")
        }

        var auditIDs = Set<UUID>()
        for audit in audits {
            guard auditIDs.insert(audit.id).inserted else { throw FLedgerValidationError.duplicateAuditID(audit.id) }
            guard !audit.action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !audit.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !audit.resultingLedgerDigest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw FLedgerValidationError.invalidAudit(audit.id)
            }
            guard Self.isPlausible(audit.occurredAt, now: now) else {
                throw FLedgerValidationError.implausibleTimestamp("audit")
            }
        }

        try reconcileBalances()
    }

    /// Replays only confirmed account facts from the opening snapshot and compares the result
    /// with the materialized balances. No quote, plan, or AI output participates.
    func reconcileBalances() throws {
        var expectedCash = openingSnapshot.cashBalance
        var expectedUnits: [String: Int64] = [:]
        var expectedCost: [String: Decimal] = [:]
        for position in openingSnapshot.positions {
            expectedUnits[position.instrumentCode] = position.units
            expectedCost[position.instrumentCode] = position.bookCost
        }

        enum Event {
            case fill(FConfirmedFill)
            case cash(FCashMovement)
            case feeAdjustment(FFillFeeAdjustment)
            var sequence: UInt64 {
                switch self {
                case .fill(let value): return value.sequence
                case .cash(let value): return value.sequence
                case .feeAdjustment(let value): return value.sequence
                }
            }
        }
        let events = fills.map(Event.fill) + cashMovements.map(Event.cash) +
            (feeAdjustments ?? []).map(Event.feeAdjustment)
        var knownEffectiveFees = Dictionary(uniqueKeysWithValues: fills.map { ($0.id, $0.fee) })
        var fillsBeforeCurrentEvent: [FConfirmedFill] = []
        for event in events.sorted(by: { $0.sequence < $1.sequence }) {
            let fill: FConfirmedFill
            switch event {
            case .cash(let movement):
                expectedCash += movement.amount
                guard expectedCash >= 0 else {
                    throw FLedgerValidationError.historicalCashUnderflow(sequence: movement.sequence)
                }
                continue
            case .feeAdjustment(let adjustment):
                expectedCash -= adjustment.feeDelta
                guard expectedCash >= 0 else {
                    throw FLedgerValidationError.historicalCashUnderflow(sequence: adjustment.sequence)
                }
                knownEffectiveFees[adjustment.fillID, default: 0] += adjustment.feeDelta
                let replayed = try FLedgerFeeProjection.replay(
                    opening: openingSnapshot, fills: fillsBeforeCurrentEvent,
                    fees: knownEffectiveFees, recalculateSellBasis: true).state
                expectedUnits = replayed.units
                expectedCost = replayed.costs
                continue
            case .fill(let value):
                fill = value
            }
            let code = fill.instrumentCode
            let currentUnits = expectedUnits[code, default: 0]
            let currentCost = expectedCost[code, default: 0]
            let (nextUnits, overflow) = currentUnits.addingReportingOverflow(fill.side == .buy ? fill.units : -fill.units)
            guard !overflow else {
                throw FLedgerValidationError.positionQuantityOverflow(code)
            }
            guard nextUnits >= 0 else { throw FLedgerValidationError.positionUnitUnderflow(code) }
            expectedUnits[code] = nextUnits

            if fill.side == .buy {
                let consideration = fill.price * Decimal(fill.units) + fill.fee
                expectedCash -= consideration
                guard expectedCash >= 0 else {
                    throw FLedgerValidationError.historicalCashUnderflow(sequence: fill.sequence)
                }
                expectedCost[code] = currentCost + consideration
            } else {
                guard let removed = fill.costBasisRemoved else {
                    throw FLedgerValidationError.missingSellCostBasis(fill.id)
                }
                let policyCost = try FAccountingPolicy.costBasisRemoved(
                    unitsSold: fill.units, totalUnits: currentUnits, totalBookCost: currentCost)
                guard removed == policyCost else {
                    throw FLedgerValidationError.costBasisPolicyMismatch(
                        sequence: fill.sequence, expected: policyCost, actual: removed)
                }
                guard removed <= currentCost else { throw FLedgerValidationError.invalidFill(fill.id) }
                expectedCash += fill.price * Decimal(fill.units) - fill.fee
                expectedCost[code] = currentCost - removed
            }
            fillsBeforeCurrentEvent.append(fill)
        }
        guard expectedCash == cashBalance else {
            throw FLedgerValidationError.cashReconciliation(expected: expectedCash, actual: cashBalance)
        }
        let actualByCode = Dictionary(uniqueKeysWithValues: positions.map { ($0.instrumentCode, $0) })
        let allCodes = Set(expectedUnits.keys).union(actualByCode.keys)
        for code in allCodes {
            let expected = expectedUnits[code, default: 0]
            let actual = actualByCode[code]?.units ?? 0
            guard expected == actual else {
                throw FLedgerValidationError.positionUnitReconciliation(code: code, expected: expected, actual: actual)
            }
            let expectedPositionCost = expected == 0 ? 0 : expectedCost[code, default: 0]
            let actualPositionCost = actualByCode[code]?.bookCost ?? 0
            guard expectedPositionCost == actualPositionCost else {
                throw FLedgerValidationError.positionCostReconciliation(code: code,
                                                                         expected: expectedPositionCost,
                                                                         actual: actualPositionCost)
            }
        }
    }

    private static func validCode(_ code: String) -> Bool {
        let value = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return (2...16).contains(value.count) && value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-"
        }
    }

    private static func isFinite(_ value: Decimal) -> Bool { value.isFinite }

    private static func isPlausible(_ date: Date, now: Date) -> Bool {
        let timestamp = date.timeIntervalSince1970
        return timestamp.isFinite && timestamp <= now.addingTimeInterval(300).timeIntervalSince1970
    }
}

