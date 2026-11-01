import Foundation

public enum FReadOnlyCashFlowKind: String, Codable, Equatable, Sendable {
    case openingBalance, buy, sell, feeAdjustment, deposit, withdrawal, accountExpense, cashReconciliation
}

/// One cash-changing ledger event with its resulting reconciled cash balance.
public struct FReadOnlyCashFlowEntry: Equatable, Sendable, Identifiable {
    public var id: UInt64 { sequence }
    public let sequence: UInt64
    public let occurredAt: Date
    public let kind: FReadOnlyCashFlowKind
    public let instrumentCode: String?
    public let instrumentName: String?
    public let sourceFillID: UUID?
    public let units: Int64?
    public let price: Decimal?
    public let fee: Decimal
    /// Latest effective total fee for a confirmed fill; nil for non-fill events.
    public let effectiveFee: Decimal?
    public let cashDelta: Decimal
    public let resultingCashBalance: Decimal
    public let reason: String

    fileprivate init(sequence: UInt64, occurredAt: Date, kind: FReadOnlyCashFlowKind,
                     instrumentCode: String?, instrumentName: String?, sourceFillID: UUID?,
                     units: Int64?, price: Decimal?, fee: Decimal, effectiveFee: Decimal?, cashDelta: Decimal,
                     resultingCashBalance: Decimal, reason: String) {
        self.sequence = sequence
        self.occurredAt = occurredAt
        self.kind = kind
        self.instrumentCode = instrumentCode
        self.instrumentName = instrumentName
        self.sourceFillID = sourceFillID
        self.units = units
        self.price = price
        self.fee = fee
        self.effectiveFee = effectiveFee
        self.cashDelta = cashDelta
        self.resultingCashBalance = resultingCashBalance
        self.reason = reason
    }
}

public struct FPositionEpisodeTrade: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID { fillID }
    public let fillID: UUID
    public let sequence: UInt64
    public let tradedAt: Date
    public let side: FTradeSide
    public let units: Int64
    public let price: Decimal
    public let fee: Decimal
    public let costBasisRemoved: Decimal?
    public let tradeIntent: FTradeIntent?
    public let tCycleID: String?
    public let confirmationNote: String

    fileprivate init(_ fill: FConfirmedFill) {
        fillID = fill.id
        sequence = fill.sequence
        tradedAt = fill.tradedAt
        side = fill.side
        units = fill.units
        price = fill.price
        fee = fill.fee
        costBasisRemoved = fill.costBasisRemoved
        tradeIntent = fill.tradeIntent
        tCycleID = fill.tCycleID
        confirmationNote = fill.userConfirmation.confirmationNote
    }

    public var realizedProfit: Decimal? {
        guard side == .sell, let costBasisRemoved else { return nil }
        return price * Decimal(units) - fee - costBasisRemoved
    }
}

/// Read-only lifecycle of one continuously open position. Full liquidation closes
/// the episode; a later confirmed buy begins another episode for the same security.
public struct FPositionEpisode: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(instrumentCode)#\(episodeNumber)" }
    public let instrumentCode: String
    public let instrumentName: String
    public let episodeNumber: Int
    public let openedAt: Date
    public let closedAt: Date?
    /// False when this episode is represented by an imported opening position without its opening fills.
    public let historyIsComplete: Bool
    public let openingUnits: Int64
    public let currentUnits: Int64
    public let currentBookCost: Decimal
    public let netRealizedProfit: Decimal
    public let openingReason: String?
    public let trades: [FPositionEpisodeTrade]

    fileprivate init(instrumentCode: String, instrumentName: String, episodeNumber: Int,
                     openedAt: Date, closedAt: Date?, openingUnits: Int64,
                     currentUnits: Int64, currentBookCost: Decimal,
                     historyIsComplete: Bool,
                     netRealizedProfit: Decimal, openingReason: String?,
                     trades: [FPositionEpisodeTrade]) {
        self.instrumentCode = instrumentCode
        self.instrumentName = instrumentName
        self.episodeNumber = episodeNumber
        self.openedAt = openedAt
        self.closedAt = closedAt
        self.historyIsComplete = historyIsComplete
        self.openingUnits = openingUnits
        self.currentUnits = currentUnits
        self.currentBookCost = currentBookCost
        self.netRealizedProfit = netRealizedProfit
        self.openingReason = openingReason
        self.trades = trades
    }

    public var isActive: Bool { closedAt == nil && currentUnits > 0 }
}

/// Persistent identity and all position episodes projected from the immutable
/// opening snapshot and append-only confirmed trade stream.
public struct FInstrumentHistorySnapshot: Equatable, Sendable, Identifiable {
    public var id: String { instrumentCode }
    public let instrumentCode: String
    public let instrumentName: String
    public let firstHeldAt: Date
    public let lastActivityAt: Date
    public let episodes: [FPositionEpisode]
    /// False when this account began from an imported open position without its prior fills.
    public let lifetimeHistoryIsComplete: Bool
    public let lifetimeRealizedProfit: Decimal
    public let cumulativeTContribution: Decimal?
    public let activeUnits: Int64
    public let activeBookCost: Decimal

    fileprivate init(instrumentCode: String, instrumentName: String, firstHeldAt: Date,
                     lastActivityAt: Date, episodes: [FPositionEpisode],
                     lifetimeHistoryIsComplete: Bool,
                     cumulativeTContribution: Decimal?) {
        self.instrumentCode = instrumentCode
        self.instrumentName = instrumentName
        self.firstHeldAt = firstHeldAt
        self.lastActivityAt = lastActivityAt
        self.episodes = episodes
        self.lifetimeHistoryIsComplete = lifetimeHistoryIsComplete
        lifetimeRealizedProfit = episodes.reduce(Decimal.zero) { $0 + $1.netRealizedProfit }
        self.cumulativeTContribution = cumulativeTContribution
        activeUnits = episodes.last(where: \.isActive)?.currentUnits ?? 0
        activeBookCost = episodes.last(where: \.isActive)?.currentBookCost ?? 0
    }

    public var isCurrentlyHeld: Bool { activeUnits > 0 }
}

private struct FMutablePositionEpisode {
    var instrumentCode: String
    var instrumentName: String
    var episodeNumber: Int
    var openedAt: Date
    var closedAt: Date?
    var historyIsComplete: Bool
    var openingUnits: Int64
    var currentUnits: Int64
    var currentBookCost: Decimal
    var netRealizedProfit: Decimal
    var openingReason: String?
    var trades: [FPositionEpisodeTrade]

    init(position: FPosition, episodeNumber: Int, openedAt: Date) {
        instrumentCode = position.instrumentCode
        instrumentName = position.name
        self.episodeNumber = episodeNumber
        self.openedAt = openedAt
        closedAt = nil
        historyIsComplete = false
        openingUnits = position.units
        currentUnits = position.units
        currentBookCost = position.bookCost
        netRealizedProfit = 0
        openingReason = nil
        trades = []
    }

    init(fill: FConfirmedFill, episodeNumber: Int) {
        instrumentCode = fill.instrumentCode
        instrumentName = fill.instrumentName ?? "名称未记录"
        self.episodeNumber = episodeNumber
        openedAt = fill.tradedAt
        closedAt = nil
        historyIsComplete = true
        openingUnits = 0
        currentUnits = 0
        currentBookCost = 0
        netRealizedProfit = 0
        openingReason = fill.userConfirmation.confirmationNote
        trades = []
    }

    mutating func apply(_ fill: FConfirmedFill) {
        if let name = fill.instrumentName { instrumentName = name }
        let trade = FPositionEpisodeTrade(fill)
        let isOpeningTrade = trades.isEmpty && currentUnits == 0
        trades.append(trade)
        if fill.side == .buy {
            if isOpeningTrade { openingUnits = fill.units }
            currentUnits += fill.units
            currentBookCost += fill.price * Decimal(fill.units) + fill.fee
        } else {
            let removed = fill.costBasisRemoved ?? 0
            currentUnits -= fill.units
            currentBookCost -= removed
            netRealizedProfit += fill.price * Decimal(fill.units) - fill.fee - removed
            if currentUnits == 0 {
                currentBookCost = 0
                closedAt = fill.tradedAt
            }
        }
    }

    func snapshot() -> FPositionEpisode {
        FPositionEpisode(instrumentCode: instrumentCode, instrumentName: instrumentName,
                         episodeNumber: episodeNumber, openedAt: openedAt, closedAt: closedAt,
                         openingUnits: openingUnits, currentUnits: currentUnits,
                         currentBookCost: currentBookCost, historyIsComplete: historyIsComplete,
                         netRealizedProfit: netRealizedProfit,
                         openingReason: openingReason, trades: trades)
    }
}

enum FLedgerHistoryProjection {
    static func instruments(from book: FAccountBook,
                            fills: [FConfirmedFill]) -> [FInstrumentHistorySnapshot] {
        var episodesByCode: [String: [FMutablePositionEpisode]] = [:]
        for position in book.openingSnapshot.positions {
            let date = position.acquiredAt ?? book.openingSnapshot.capturedAt
            episodesByCode[position.instrumentCode, default: []].append(
                FMutablePositionEpisode(position: position, episodeNumber: 1, openedAt: date))
        }

        for fill in fills.sorted(by: { $0.sequence < $1.sequence }) {
            var episodes = episodesByCode[fill.instrumentCode, default: []]
            if fill.side == .buy {
                if episodes.last?.closedAt != nil || episodes.isEmpty {
                    episodes.append(FMutablePositionEpisode(fill: fill, episodeNumber: episodes.count + 1))
                }
                episodes[episodes.count - 1].apply(fill)
            } else if let index = episodes.indices.last, episodes[index].closedAt == nil {
                episodes[index].apply(fill)
            }
            episodesByCode[fill.instrumentCode] = episodes
        }

        let activeNames = Dictionary(uniqueKeysWithValues: book.positions.map { ($0.instrumentCode, $0.name) })
        return episodesByCode.keys.sorted().compactMap { code in
            guard let mutableEpisodes = episodesByCode[code], !mutableEpisodes.isEmpty else { return nil }
            let episodes = mutableEpisodes.map { $0.snapshot() }
            let lastEventName = fills.sorted(by: { $0.sequence < $1.sequence })
                .last(where: { $0.instrumentCode == code })?.instrumentName
            let name = activeNames[code] ?? lastEventName ?? episodes.last?.instrumentName ?? "名称未记录"
            let firstHeld = episodes.map(\.openedAt).min() ?? book.openingSnapshot.capturedAt
            let lastActivity = fills.filter { $0.instrumentCode == code }.map(\.tradedAt).max() ?? firstHeld
            let lifetimeHistoryIsComplete = !book.openingSnapshot.positions.contains {
                $0.instrumentCode == code
            }
            return FInstrumentHistorySnapshot(instrumentCode: code, instrumentName: name,
                                              firstHeldAt: firstHeld, lastActivityAt: lastActivity,
                                              episodes: episodes,
                                              lifetimeHistoryIsComplete: lifetimeHistoryIsComplete,
                                              cumulativeTContribution: lifetimeHistoryIsComplete
                                                ? FTradeContributionCalculator.contribution(
                                                    from: fills.filter { $0.instrumentCode == code })
                                                : nil)
        }
    }

    static func cashFlow(from book: FAccountBook,
                         namesByCode: [String: String]) throws -> [FReadOnlyCashFlowEntry] {
        struct Event {
            let sequence: UInt64
            let date: Date
            let kind: FReadOnlyCashFlowKind
            let code: String?
            let name: String?
            let sourceFillID: UUID?
            let units: Int64?
            let price: Decimal?
            let fee: Decimal
            let effectiveFee: Decimal?
            let delta: Decimal
            let reason: String
        }
        let effectiveFees = try FLedgerFeeProjection.effectiveFees(in: book)
        var events = book.fills.map { fill -> Event in
            let gross = fill.price * Decimal(fill.units)
            let buy = fill.side == .buy
            return Event(sequence: fill.sequence, date: fill.tradedAt,
                         kind: buy ? .buy : .sell, code: fill.instrumentCode,
                         name: fill.instrumentName ?? namesByCode[fill.instrumentCode],
                         sourceFillID: fill.id, units: fill.units, price: fill.price, fee: fill.fee,
                         effectiveFee: effectiveFees[fill.id],
                         delta: buy ? -(gross + fill.fee) : gross - fill.fee,
                         reason: fill.userConfirmation.confirmationNote)
        }
        events += book.cashMovements.map { movement in
            let kind: FReadOnlyCashFlowKind
            switch movement.category {
            case .some(.accountExpense): kind = .accountExpense
            case .some(.cashReconciliation): kind = .cashReconciliation
            case .none: kind = movement.amount > 0 ? .deposit : .withdrawal
            }
            return Event(sequence: movement.sequence, date: movement.occurredAt,
                  kind: kind, code: nil, name: nil,
                  sourceFillID: nil, units: nil, price: nil, fee: 0, effectiveFee: nil,
                  delta: movement.amount,
                  reason: movement.reason + " · " + movement.userConfirmation.confirmationNote)
        }
        let fillsByID = Dictionary(uniqueKeysWithValues: book.fills.map { ($0.id, $0) })
        events += (book.feeAdjustments ?? []).map { adjustment in
            let fill = fillsByID[adjustment.fillID]
            return Event(sequence: adjustment.sequence, date: adjustment.occurredAt,
                         kind: .feeAdjustment, code: fill?.instrumentCode,
                         name: fill?.instrumentName ?? fill.flatMap { namesByCode[$0.instrumentCode] },
                         sourceFillID: nil, units: nil, price: nil, fee: adjustment.feeDelta,
                         effectiveFee: nil,
                         delta: -adjustment.feeDelta,
                         reason: "手续费差额更正 · \(adjustment.reason) · \(adjustment.userConfirmation.confirmationNote)")
        }

        var balance = book.openingSnapshot.cashBalance
        var entries = [FReadOnlyCashFlowEntry(
            sequence: 0, occurredAt: book.openingSnapshot.capturedAt, kind: .openingBalance,
            instrumentCode: nil, instrumentName: nil, sourceFillID: nil,
            units: nil, price: nil, fee: 0, effectiveFee: nil,
            cashDelta: balance, resultingCashBalance: balance, reason: "真实账本期初现金")]
        for event in events.sorted(by: { $0.sequence < $1.sequence }) {
            balance += event.delta
            entries.append(FReadOnlyCashFlowEntry(
                sequence: event.sequence, occurredAt: event.date, kind: event.kind,
                instrumentCode: event.code, instrumentName: event.name,
                sourceFillID: event.sourceFillID, units: event.units,
                price: event.price, fee: event.fee, effectiveFee: event.effectiveFee,
                cashDelta: event.delta,
                resultingCashBalance: balance, reason: event.reason))
        }
        return entries
    }
}
