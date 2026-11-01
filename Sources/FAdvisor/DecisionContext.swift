import Foundation
import FCore

public enum FContextDataClass: String, Codable, Equatable, Sendable {
    case quote, previousClose, intraday, iopv, dailyHistory, news, nasResearch, crossMarket, quantState
}

enum FDecisionFinancialMath {
    static func sum(_ values: [Decimal]) -> Decimal? {
        var total = Decimal.zero
        for value in values {
            guard value.isFinite else { return nil }
            total += value
            guard total.isFinite else { return nil }
        }
        return total
    }

    static func add(_ lhs: Decimal, _ rhs: Decimal) -> Decimal? {
        guard lhs.isFinite, rhs.isFinite else { return nil }
        let total = lhs + rhs
        return total.isFinite ? total : nil
    }
}

/// A captured market/research observation. Unavailable data is represented explicitly;
/// callers must not fabricate a numeric value to satisfy a decision workflow.
public struct FContextObservation: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let dataClass: FContextDataClass
    public let subject: String
    public let source: String
    public let reference: String?
    public let observedAt: Date?
    public let capturedAt: Date
    public let decimalValue: Decimal?
    public let unavailableReason: String?
    /// Exchange time and local retrieval time remain distinct. Legacy quote
    /// observations without this field can be displayed but are not actionable.
    public let quoteTemporalMetadata: FQuoteTemporalMetadata?

    public init(id: UUID = UUID(), dataClass: FContextDataClass, subject: String,
                source: String, reference: String? = nil, observedAt: Date?,
                capturedAt: Date, decimalValue: Decimal?, unavailableReason: String? = nil,
                quoteTemporalMetadata: FQuoteTemporalMetadata? = nil) {
        self.id = id
        self.dataClass = dataClass
        self.subject = subject
        self.source = source
        self.reference = reference
        self.observedAt = observedAt
        self.capturedAt = capturedAt
        self.decimalValue = decimalValue
        self.unavailableReason = unavailableReason
        self.quoteTemporalMetadata = quoteTemporalMetadata
    }

    public func validate(now: Date = Date()) throws {
        let explicitUnavailable = decimalValue == nil &&
            FDecisionContextValidation.nonBlank(unavailableReason ?? "")
        let availableValue = decimalValue.map { $0.isFinite } ?? false
        let validObservedValue = decimalValue.map {
            (dataClass == .quote || dataClass == .previousClose || dataClass == .intraday) ? $0 > 0 : true
        } ?? true
        let validObservationTime: Bool
        if let observedAt {
            validObservationTime = FDecisionContextValidation.plausible(observedAt, now: now) &&
                observedAt <= capturedAt
        } else {
            validObservationTime = explicitUnavailable ||
                (dataClass == .quote && quoteTemporalMetadata?.timestampTrust == .fetchedAtOnly)
        }
        let validQuoteMetadata = quoteTemporalMetadata.map {
            dataClass == .quote && $0.isConsistent(source: source, observedAt: observedAt,
                                                   capturedAt: capturedAt) &&
                ($0.timestampTrust != .unavailable || decimalValue == nil)
        } ?? true
        let validIOPV = dataClass != .iopv ||
            (source == FMarketQuoteTrustPolicy.tencentReferenceSource &&
             subject.utf8.count == 6 && subject.utf8.allSatisfy { (48...57).contains($0) } &&
             reference == "method=(ETF价格/IOPV-1)*100;unit=percent" &&
             decimalValue.map { $0.isFinite && $0 > -100 } == true)
        let validPreviousClose = dataClass != .previousClose ||
            (FMarketQuoteTrustPolicy.isTrustedReferenceSource(source) &&
             subject.utf8.count == 6 && subject.utf8.allSatisfy { (48...57).contains($0) })
        guard FDecisionContextValidation.nonBlank(subject),
              FDecisionContextValidation.nonBlank(source),
              (dataClass != .news || !availableValue ||
                (FNewsTrustPolicy.isTrustedProvider(source) &&
                 FDecisionContextValidation.nonBlank(reference ?? ""))),
              FDecisionContextValidation.plausible(capturedAt, now: now),
              validObservationTime, validQuoteMetadata, validIOPV, validPreviousClose,
              availableValue || explicitUnavailable, validObservedValue,
              !(availableValue && unavailableReason != nil) else {
            throw FDecisionContextError.invalidObservation(id)
        }
    }

    public func isFresh(at now: Date) -> Bool {
        if dataClass == .quote {
            guard let quoteTemporalMetadata,
                  quoteTemporalMetadata.timestampTrust == .verifiedExchangeTimestamp,
                  quoteTemporalMetadata.isConsistent(source: source, observedAt: observedAt,
                                                     capturedAt: capturedAt),
                  quoteTemporalMetadata.freshness(at: now) == .fresh else { return false }
            return true
        }
        guard let observedAt, decimalValue != nil, now >= observedAt,
              now.timeIntervalSince(observedAt) <= dataClass.maximumAge else { return false }
        return true
    }
}

public extension FContextDataClass {
    var maximumAge: TimeInterval {
        switch self {
        case .quote: return FQuoteTemporalMetadata.defaultMaximumAge
        case .previousClose: return 15 * 60
        case .intraday: return 90
        case .iopv: return 90
        case .dailyHistory: return 36 * 3600
        case .news: return 24 * 3600
        case .nasResearch: return 7 * 24 * 3600
        case .crossMarket: return 24 * 3600
        case .quantState: return 36 * 3600
        }
    }
}

/// Compact Ledger-derived history for the advisor. Episode cost and lifetime realized
/// profit stay separate so a closed round cannot contaminate a later active round.
public struct FDecisionPositionEpisode: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(instrumentCode)#\(episodeNumber)" }
    public let instrumentCode: String
    public let instrumentName: String
    public let episodeNumber: Int
    public let openedAt: Date
    public let closedAt: Date?
    /// Optional for backward decoding; nil in older serialized contexts is treated as incomplete.
    public let historyIsComplete: Bool?
    public let openingUnits: Int64
    public let currentUnits: Int64
    public let currentBookCost: Decimal
    public let netRealizedProfit: Decimal
    public let openingReason: String?

    public init(_ episode: FPositionEpisode) {
        instrumentCode = episode.instrumentCode
        instrumentName = episode.instrumentName
        episodeNumber = episode.episodeNumber
        openedAt = episode.openedAt
        closedAt = episode.closedAt
        historyIsComplete = episode.historyIsComplete
        openingUnits = episode.openingUnits
        currentUnits = episode.currentUnits
        currentBookCost = episode.currentBookCost
        netRealizedProfit = episode.netRealizedProfit
        openingReason = episode.openingReason.map { String($0.prefix(256)) }
    }
}

public struct FDecisionPositionHistory: Codable, Equatable, Sendable, Identifiable {
    public var id: String { instrumentCode }
    public let instrumentCode: String
    public let instrumentName: String
    public let episodeCount: Int
    /// Optional for backward decoding; nil in older serialized contexts is treated as incomplete.
    public let lifetimeHistoryIsComplete: Bool?
    public let lifetimeRealizedProfit: Decimal
    public let firstHeldAt: Date
    public let lastActivityAt: Date

    public init(_ history: FInstrumentHistorySnapshot) {
        instrumentCode = history.instrumentCode
        instrumentName = history.instrumentName
        episodeCount = history.episodes.count
        lifetimeHistoryIsComplete = history.lifetimeHistoryIsComplete
        lifetimeRealizedProfit = history.lifetimeRealizedProfit
        firstHeldAt = history.firstHeldAt
        lastActivityAt = history.lastActivityAt
    }
}

/// Deterministic, read-only P&L labels for one security. Nil means the source facts
/// required for that specific accounting window were not captured; it never means zero.
public struct FDecisionInstrumentPnL: Codable, Equatable, Sendable, Identifiable {
    public var id: String { instrumentCode }
    public let instrumentCode: String
    public let securityDailyPnL: Decimal?
    public let dailyRealizedTradingPnL: Decimal?
    public let dailyTContribution: Decimal?
    public let cumulativeTContribution: Decimal?
    public let dailyTContributionUnavailableReason: String?
    public let cumulativeTContributionUnavailableReason: String?
    public let currentEpisodeRealizedPnL: Decimal?
    /// Optional for backward decoding; nil in older serialized contexts is treated as incomplete.
    public let currentEpisodeHistoryIsComplete: Bool?
    public let currentEpisodeUnrealizedPnL: Decimal?
    public let currentEpisodeTotalPnL: Decimal?
    /// Optional for backward decoding; nil in older serialized contexts is treated as incomplete.
    public let securityLifetimeHistoryIsComplete: Bool?
    public let securityLifetimeRealizedPnL: Decimal?
    public let closedEpisodesRealizedPnL: Decimal?
    public let securityLifetimeUnrealizedPnL: Decimal?
    public let securityLifetimeTotalPnL: Decimal?
    public let brokerDisplayCostPerUnit: Decimal?
    public let episodeEconomicCostPerUnit: Decimal?

    fileprivate init(instrumentCode: String, history: FInstrumentHistorySnapshot?,
                     holding: FReadOnlyPositionSnapshot?, daily: FDailyTradeSummary?,
                     dailySummaryDate: String?, quotePrice: Decimal?,
                     previousClose: Decimal?, endOfDayUnits: Int64) {
        self.instrumentCode = instrumentCode
        let active = history?.episodes.last(where: \.isActive)
        let episodeHistoryComplete = active?.historyIsComplete ?? true
        let unrealized: Decimal? = if let active, let quotePrice {
            try? FSecurityPnLCalculator.episodeUnrealizedPnL(
                units: active.currentUnits, bookCost: active.currentBookCost,
                currentPrice: quotePrice)
        } else if active == nil { Decimal.zero } else { nil }
        let episodeRealized = active?.netRealizedProfit
        let historyComplete = history?.lifetimeHistoryIsComplete ?? true
        let lifetimeRealized = history?.lifetimeRealizedProfit ?? .zero
        let closedRealized = FDecisionFinancialMath.sum(
            history?.episodes.filter { $0.closedAt != nil }.map(\.netRealizedProfit) ?? [])
        if let dailySummaryDate, let previousClose, let quotePrice {
            securityDailyPnL = try? FSecurityPnLCalculator.dailySecurityPnL(
                securityCode: instrumentCode, tradingDate: dailySummaryDate,
                previousClose: previousClose, trades: daily,
                endOfDayUnits: endOfDayUnits, currentPrice: quotePrice)
        } else {
            securityDailyPnL = nil
        }
        dailyRealizedTradingPnL = dailySummaryDate == nil ? nil :
            (daily?.dailyRealizedTradingPnL ?? .zero)
        let dailyT: Decimal? = if dailySummaryDate == nil {
            nil
        } else if let daily {
            daily.tContribution
        } else {
            .zero
        }
        dailyTContribution = dailyT
        cumulativeTContribution = historyComplete ? history?.cumulativeTContribution : nil
        dailyTContributionUnavailableReason = dailyT == nil
            ? "当日成交未全部分类或T配对不完整" : nil
        cumulativeTContributionUnavailableReason = cumulativeTContribution == nil
            ? "历史成交存在未分类记录或T配对不完整" : nil
        currentEpisodeHistoryIsComplete = episodeHistoryComplete
        currentEpisodeRealizedPnL = episodeHistoryComplete ? episodeRealized : nil
        currentEpisodeUnrealizedPnL = active == nil ? nil : unrealized
        currentEpisodeTotalPnL = if episodeHistoryComplete,
                                   let episodeRealized, let episodeUnrealized = unrealized {
            FDecisionFinancialMath.add(episodeRealized, episodeUnrealized)
        } else { nil }
        securityLifetimeHistoryIsComplete = historyComplete
        securityLifetimeRealizedPnL = historyComplete ? lifetimeRealized : nil
        closedEpisodesRealizedPnL = historyComplete ? closedRealized : nil
        let lifetimeUnrealized: Decimal? = active == nil ? .zero : unrealized
        securityLifetimeUnrealizedPnL = lifetimeUnrealized
        securityLifetimeTotalPnL = if historyComplete, let lifetimeUnrealized {
            FDecisionFinancialMath.add(lifetimeRealized, lifetimeUnrealized)
        } else { nil }
        brokerDisplayCostPerUnit = holding?.brokerDisplayCostPerUnit
        episodeEconomicCostPerUnit = if let active, active.currentUnits > 0 {
            active.currentBookCost / Decimal(active.currentUnits)
        } else { nil }
    }
}

/// Immutable decision-time view of account state and external facts.
public struct FDecisionContext: Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let accountID: UUID
    public let accountDigest: String
    public let cashBalance: Decimal
    public let holdings: [FDecisionHoldingSnapshot]
    public let observations: [FContextObservation]
    /// Provenance for the imported opening position baseline. Nil only in legacy contexts.
    public let openingSnapshotCapturedAt: Date?
    public let openingPositionCodes: Set<String>
    let strategyQualificationGrants: [FQuantStrategyQualificationGrant]
    /// Read-only, per-security facts derived from confirmed fills on the captured
    /// CN trading date. No raw Ledger records or mutation API are exposed here.
    /// A non-nil date with an empty summary list means the Ledger confirms no fills
    /// for that date; nil is reserved for legacy contexts without this projection.
    public let dailyTradeSummaryDate: String?
    public let dailyTradeSummaries: [FDailyTradeSummary]
    /// Deterministic sum of the per-security realized P/L facts; nil means either
    /// no fills were captured or the nonempty sum is not representable as Decimal.
    public let dailyPortfolioRealizedPnL: Decimal?
    /// Per-security P&L facts are calculated before serialization. Daily total and T
    /// values remain unavailable until their required market marks / explicit tags exist.
    public let instrumentPnLFacts: [FDecisionInstrumentPnL]
    /// Compact NAS statistics captured by reference; never a mutable store or raw minute series.
    public let researchEvidence: [FDecisionResearchEvidence]
    public let positionHistory: [FDecisionPositionHistory]
    public let recentPositionEpisodes: [FDecisionPositionEpisode]
    public let positionEpisodeHistoryIsTruncated: Bool

    public init(id: UUID = UUID(), snapshot: FReadOnlyLedgerSnapshot,
                observations: [FContextObservation],
                researchEvidence: [FDecisionResearchEvidence] = []) {
        self.init(id: id, snapshot: snapshot, observations: observations,
                  researchEvidence: researchEvidence, strategyQualificationGrants: [])
    }

    init(id: UUID = UUID(), snapshot: FReadOnlyLedgerSnapshot,
         observations: [FContextObservation],
         researchEvidence: [FDecisionResearchEvidence] = [],
         strategyQualificationGrants: [FQuantStrategyQualificationGrant]) {
        let capturedAt = snapshot.capturedAt
        let capturedDailyTradeSummaryDate = snapshot.dailyTradeSummaryDate
        let capturedObservations = observations
        self.id = id
        createdAt = capturedAt
        accountID = snapshot.accountID
        accountDigest = snapshot.ledgerDigest
        cashBalance = snapshot.cashBalance
        holdings = snapshot.positions.map {
            FDecisionHoldingSnapshot(instrumentCode: $0.instrumentCode, name: $0.name,
                                     units: $0.units, bookCost: $0.bookCost,
                                     brokerDisplayCostPerUnit: $0.brokerDisplayCostPerUnit,
                                     brokerDisplayCostUpdatedAt: $0.brokerDisplayCostUpdatedAt)
        }
        self.observations = observations
        openingSnapshotCapturedAt = snapshot.openingSnapshotCapturedAt
        openingPositionCodes = snapshot.openingPositionCodes
        self.strategyQualificationGrants = strategyQualificationGrants
        dailyTradeSummaryDate = capturedDailyTradeSummaryDate
        dailyTradeSummaries = snapshot.dailyTradeSummaries
        dailyPortfolioRealizedPnL = FDailyTradeSummary.aggregateRealizedPnL(snapshot.dailyTradeSummaries)
        self.researchEvidence = Self.deduplicatedResearchEvidence(researchEvidence)
        positionHistory = snapshot.instrumentHistories.map(FDecisionPositionHistory.init)
            .sorted { $0.instrumentCode < $1.instrumentCode }
        let allEpisodes = snapshot.instrumentHistories.flatMap(\.episodes)
            .sorted { $0.openedAt < $1.openedAt }
        positionEpisodeHistoryIsTruncated = allEpisodes.count > 64
        recentPositionEpisodes = allEpisodes.suffix(64).map(FDecisionPositionEpisode.init)
        let historyByCode = Dictionary(uniqueKeysWithValues: snapshot.instrumentHistories.map {
            ($0.instrumentCode, $0)
        })
        let holdingByCode = Dictionary(uniqueKeysWithValues: snapshot.positions.map { ($0.instrumentCode, $0) })
        let dailyByCode = Dictionary(uniqueKeysWithValues: snapshot.dailyTradeSummaries.map { ($0.securityCode, $0) })
        let codes = Set(historyByCode.keys).union(holdingByCode.keys).union(dailyByCode.keys)
        instrumentPnLFacts = codes.sorted().map { code in
            let quoteObservation = capturedObservations.filter { $0.dataClass == .quote && $0.subject == code }
                .filter { $0.isFresh(at: capturedAt) }
                .max { ($0.observedAt ?? .distantPast) < ($1.observedAt ?? .distantPast) }
            let dailyMark = Self.dailyMark(for: code, observations: capturedObservations,
                                           tradingDate: capturedDailyTradeSummaryDate,
                                           asOf: capturedAt)
            let openingPositionIsKnown = FSecurityPnLCalculator.openingSnapshotSupportsDailyPnL(
                openingSnapshotCapturedAt: snapshot.openingSnapshotCapturedAt,
                securityCode: code, openingPositionCodes: snapshot.openingPositionCodes,
                tradingDate: capturedDailyTradeSummaryDate)
            return FDecisionInstrumentPnL(instrumentCode: code, history: historyByCode[code],
                                          holding: holdingByCode[code], daily: dailyByCode[code],
                                          dailySummaryDate: capturedDailyTradeSummaryDate,
                                          quotePrice: quoteObservation?.decimalValue,
                                          previousClose: openingPositionIsKnown ? dailyMark?.previousClose : nil,
                                          endOfDayUnits: holdingByCode[code]?.units ?? 0)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, accountID, accountDigest, cashBalance, holdings, observations
        case openingSnapshotCapturedAt, openingPositionCodes
        case dailyTradeSummaryDate, dailyTradeSummaries, dailyPortfolioRealizedPnL, instrumentPnLFacts, researchEvidence
        case positionHistory, recentPositionEpisodes, positionEpisodeHistoryIsTruncated
    }

    /// Old archived contexts remain readable; absent research references mean none were captured.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        accountID = try values.decode(UUID.self, forKey: .accountID)
        accountDigest = try values.decode(String.self, forKey: .accountDigest)
        cashBalance = try values.decode(Decimal.self, forKey: .cashBalance)
        holdings = try values.decode([FDecisionHoldingSnapshot].self, forKey: .holdings)
        observations = try values.decode([FContextObservation].self, forKey: .observations)
        openingSnapshotCapturedAt = try values.decodeIfPresent(Date.self, forKey: .openingSnapshotCapturedAt)
        openingPositionCodes = try values.decodeIfPresent(Set<String>.self, forKey: .openingPositionCodes) ?? []
        strategyQualificationGrants = []
        dailyTradeSummaryDate = try values.decodeIfPresent(String.self, forKey: .dailyTradeSummaryDate)
        dailyTradeSummaries = try values.decodeIfPresent([FDailyTradeSummary].self,
                                                        forKey: .dailyTradeSummaries) ?? []
        dailyPortfolioRealizedPnL = try values.decodeIfPresent(Decimal.self,
                                                               forKey: .dailyPortfolioRealizedPnL)
        instrumentPnLFacts = try values.decodeIfPresent([FDecisionInstrumentPnL].self,
                                                        forKey: .instrumentPnLFacts) ?? []
        researchEvidence = Self.deduplicatedResearchEvidence(
            try values.decodeIfPresent([FDecisionResearchEvidence].self, forKey: .researchEvidence) ?? [])
        positionHistory = try values.decodeIfPresent([FDecisionPositionHistory].self, forKey: .positionHistory) ?? []
        recentPositionEpisodes = try values.decodeIfPresent([FDecisionPositionEpisode].self, forKey: .recentPositionEpisodes) ?? []
        positionEpisodeHistoryIsTruncated = try values.decodeIfPresent(Bool.self, forKey: .positionEpisodeHistoryIsTruncated) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(accountID, forKey: .accountID)
        try values.encode(accountDigest, forKey: .accountDigest)
        try values.encode(cashBalance, forKey: .cashBalance)
        try values.encode(holdings, forKey: .holdings)
        try values.encode(observations, forKey: .observations)
        try values.encodeIfPresent(openingSnapshotCapturedAt, forKey: .openingSnapshotCapturedAt)
        try values.encode(openingPositionCodes, forKey: .openingPositionCodes)
        try values.encodeIfPresent(dailyTradeSummaryDate, forKey: .dailyTradeSummaryDate)
        try values.encode(dailyTradeSummaries, forKey: .dailyTradeSummaries)
        try values.encodeIfPresent(dailyPortfolioRealizedPnL, forKey: .dailyPortfolioRealizedPnL)
        try values.encode(instrumentPnLFacts, forKey: .instrumentPnLFacts)
        try values.encode(researchEvidence, forKey: .researchEvidence)
        try values.encode(positionHistory, forKey: .positionHistory)
        try values.encode(recentPositionEpisodes, forKey: .recentPositionEpisodes)
        try values.encode(positionEpisodeHistoryIsTruncated, forKey: .positionEpisodeHistoryIsTruncated)
        // The runtime authorization grant is deliberately never serialized.
    }

    public static func capture(from reader: any FLedgerSnapshotReading,
                               observations: [FContextObservation],
                               researchEvidence: [FDecisionResearchEvidence] = [],
                               now: Date = Date()) async throws -> FDecisionContext? {
        guard let snapshot = try await reader.readLedgerSnapshot(now: now) else { return nil }
        let context = FDecisionContext(snapshot: snapshot, observations: observations,
                                       researchEvidence: researchEvidence)
        try context.validate(now: now)
        return context
    }

    public func validate(now: Date = Date()) throws {
        let expectedDailyTradeSummaryDate = try? FDailyTradeSummary.tradingDate(for: createdAt)
        let securityDailyPnLIsConsistent = instrumentPnLFacts.allSatisfy { fact in
            fact.securityDailyPnL == derivedSecurityDailyPnL(for: fact)
        }
        guard FDecisionContextValidation.plausible(createdAt, now: now),
              FDecisionContextValidation.digest(accountDigest),
              (openingSnapshotCapturedAt.map { $0.timeIntervalSince1970.isFinite && $0 <= createdAt } ?? true),
              openingPositionCodes.allSatisfy({
                  $0.utf8.count == 6 && $0.utf8.allSatisfy({ (48...57).contains($0) })
              }),
              cashBalance.isFinite, cashBalance >= 0,
              Set(holdings.map(\.instrumentCode)).count == holdings.count,
              holdings.allSatisfy({ $0.units > 0 && $0.bookCost.isFinite && $0.bookCost >= 0 &&
                  ($0.brokerDisplayCostPerUnit.map { $0.isFinite && $0 >= 0 } ?? true) }),
              Set(observations.map(\.id)).count == observations.count,
              (dailyTradeSummaryDate == expectedDailyTradeSummaryDate ||
               (dailyTradeSummaryDate == nil && dailyTradeSummaries.isEmpty && dailyPortfolioRealizedPnL == nil)),
              Set(dailyTradeSummaries.map(\.id)).count == dailyTradeSummaries.count,
              dailyTradeSummaries.allSatisfy({ $0.isValid(asOf: createdAt) }),
              dailyPortfolioRealizedPnL == FDailyTradeSummary.aggregateRealizedPnL(dailyTradeSummaries),
              securityDailyPnLIsConsistent,
              Set(instrumentPnLFacts.map(\.instrumentCode)).count == instrumentPnLFacts.count,
              instrumentPnLFacts.allSatisfy({
                  FDecisionContextValidation.nonBlank($0.instrumentCode) &&
                  ($0.securityLifetimeRealizedPnL.map { $0.isFinite } ?? true) &&
                  ($0.securityDailyPnL.map { $0.isFinite } ?? true) &&
                  ($0.dailyRealizedTradingPnL.map { $0.isFinite } ?? true) &&
                  ($0.dailyTContribution.map { $0.isFinite } ?? true) &&
                  ($0.cumulativeTContribution.map { $0.isFinite } ?? true) &&
                  ($0.closedEpisodesRealizedPnL.map { $0.isFinite } ?? true) &&
                  ($0.currentEpisodeRealizedPnL.map { $0.isFinite } ?? true) &&
                  ($0.currentEpisodeUnrealizedPnL.map { $0.isFinite } ?? true) &&
                  ($0.currentEpisodeTotalPnL.map { $0.isFinite } ?? true) &&
                  ($0.securityLifetimeUnrealizedPnL.map { $0.isFinite } ?? true) &&
                  ($0.securityLifetimeTotalPnL.map { $0.isFinite } ?? true) &&
                  ($0.brokerDisplayCostPerUnit.map { $0.isFinite && $0 >= 0 } ?? true) &&
                  ($0.episodeEconomicCostPerUnit.map { $0.isFinite && $0 >= 0 } ?? true)
              }),
              Set(positionHistory.map(\.instrumentCode)).count == positionHistory.count,
              Set(recentPositionEpisodes.map(\.id)).count == recentPositionEpisodes.count,
              recentPositionEpisodes.count <= 64,
              positionHistory.allSatisfy({ $0.episodeCount >= 0 && $0.lifetimeRealizedProfit.isFinite }),
              recentPositionEpisodes.allSatisfy({ $0.episodeNumber > 0 && $0.openingUnits >= 0 &&
                  $0.currentUnits >= 0 && $0.currentBookCost.isFinite && $0.currentBookCost >= 0 &&
                  $0.netRealizedProfit.isFinite && FDecisionContextValidation.nonBlank($0.instrumentCode) &&
                  FDecisionContextValidation.nonBlank($0.instrumentName) }),
              Set(researchEvidence.map(\.id)).count == researchEvidence.count else {
            if let duplicate = Dictionary(grouping: researchEvidence, by: \.id)
                .first(where: { $0.value.count > 1 })?.key {
                throw FDecisionContextError.invalidResearchEvidence(duplicate)
            }
            throw FDecisionContextError.invalidContext
        }
        for observation in observations {
            try observation.validate(now: now)
            guard observation.capturedAt <= createdAt else {
                throw FDecisionContextError.invalidObservation(observation.id)
            }
        }
        for reference in researchEvidence {
            try reference.validate(contextCreatedAt: createdAt)
        }
        guard try JSONEncoder().encode(researchEvidence).count <= 262_144 else {
            throw FDecisionContextError.researchEvidencePayloadTooLarge
        }
    }

    private func derivedSecurityDailyPnL(for fact: FDecisionInstrumentPnL) -> Decimal? {
        guard let dailyTradeSummaryDate,
              let openingSnapshotCapturedAt,
              FSecurityPnLCalculator.openingSnapshotSupportsDailyPnL(
                  openingSnapshotCapturedAt: openingSnapshotCapturedAt,
                  securityCode: fact.instrumentCode,
                  openingPositionCodes: openingPositionCodes,
                  tradingDate: dailyTradeSummaryDate),
              let mark = Self.dailyMark(for: fact.instrumentCode, observations: observations,
                                        tradingDate: dailyTradeSummaryDate, asOf: createdAt) else {
            return nil
        }
        let endOfDayUnits = holdings.first(where: { $0.instrumentCode == fact.instrumentCode })?.units ?? 0
        let trades = dailyTradeSummaries.first(where: { $0.securityCode == fact.instrumentCode })
        return try? FSecurityPnLCalculator.dailySecurityPnL(
            securityCode: fact.instrumentCode, tradingDate: dailyTradeSummaryDate,
            previousClose: mark.previousClose, trades: trades,
            endOfDayUnits: endOfDayUnits, currentPrice: mark.currentPrice)
    }

    private static func dailyMark(for code: String, observations: [FContextObservation],
                                  tradingDate: String?, asOf: Date)
        -> (currentPrice: Decimal, previousClose: Decimal)? {
        guard let tradingDate,
              let quote = observations.filter({
                  $0.dataClass == .quote && $0.subject == code && $0.isFresh(at: asOf)
              }).max(by: { ($0.observedAt ?? .distantPast) < ($1.observedAt ?? .distantPast) }),
              let quoteTime = quote.observedAt, let currentPrice = quote.decimalValue,
              let previousClose = observations.filter({
                  $0.dataClass == .previousClose && $0.subject == code &&
                  FMarketQuoteTrustPolicy.isTrustedReferenceSource($0.source) && $0.isFresh(at: asOf)
              }).max(by: { ($0.observedAt ?? .distantPast) < ($1.observedAt ?? .distantPast) }),
              let previousCloseTime = previousClose.observedAt,
              let previousCloseValue = previousClose.decimalValue else { return nil }
        let synchronizationGap = abs(quoteTime.timeIntervalSince(previousCloseTime))
        guard synchronizationGap.isFinite, synchronizationGap <= FContextDataClass.previousClose.maximumAge,
              (try? FDailyTradeSummary.tradingDate(for: quoteTime)) == tradingDate,
              (try? FDailyTradeSummary.tradingDate(for: previousCloseTime)) == tradingDate else { return nil }
        return (currentPrice, previousCloseValue)
    }

    public func usableResearchEvidence(at now: Date = Date()) -> [FDecisionResearchEvidence] {
        let groups = Dictionary(grouping: researchEvidence, by: Self.researchScopeKey)
        return groups.values.compactMap { versions in
            versions.filter { $0.isUsableForAI(contextCreatedAt: createdAt, now: now) }
                .max { lhs, rhs in
                    if lhs.envelope.generatedAtDate != rhs.envelope.generatedAtDate {
                        return lhs.envelope.generatedAtDate < rhs.envelope.generatedAtDate
                    }
                    return lhs.id < rhs.id
                }
        }.sorted { $0.id < $1.id }
    }

    public func researchEvidenceVersionConflicts(at now: Date = Date()) -> [FResearchEvidenceVersionConflict] {
        let groups = Dictionary(grouping: researchEvidence, by: Self.researchScopeKey)
        return groups.values.compactMap { versions in
            let uniqueIDs = Set(versions.map(\.id))
            guard uniqueIDs.count > 1, let first = versions.first else { return nil }
            let selectedID = usableResearchEvidence(at: now).first {
                Self.researchScopeKey($0) == Self.researchScopeKey(first)
            }?.id
            return FResearchEvidenceVersionConflict(
                securityCode: first.envelope.securityCode, market: first.envelope.market,
                range: first.envelope.range,
                schemaVersions: Array(Set(versions.map { $0.envelope.schemaVersion })).sorted(),
                methodologyVersions: Array(Set(versions.map { $0.envelope.methodologyVersion })).sorted(),
                evidenceIDs: uniqueIDs.sorted(), selectedEvidenceID: selectedID)
        }.sorted { $0.id < $1.id }
    }

    private static func deduplicatedResearchEvidence(_ references: [FDecisionResearchEvidence]) -> [FDecisionResearchEvidence] {
        var firstByID: [String: FDecisionResearchEvidence] = [:]
        var result: [FDecisionResearchEvidence] = []
        for reference in references {
            if let existing = firstByID[reference.id], existing == reference { continue }
            firstByID[reference.id] = firstByID[reference.id] ?? reference
            result.append(reference)
        }
        return result
    }

    private static func researchScopeKey(_ reference: FDecisionResearchEvidence) -> String {
        let envelope = reference.envelope
        return [envelope.market, envelope.securityCode, envelope.range.start, envelope.range.end]
            .joined(separator: "\u{1f}")
    }

    public func freshQuote(for code: String, at now: Date) -> FContextObservation? {
        observations.filter { $0.dataClass == .quote && $0.subject == code && $0.isFresh(at: now) }
            .max { ($0.observedAt ?? .distantPast) < ($1.observedAt ?? .distantPast) }
    }

    public func holdingUnits(for code: String) -> Int64 {
        holdings.first(where: { $0.instrumentCode == code })?.units ?? 0
    }
}

/// Canonical, per-security authorization evidence emitted only after a local
/// strategy package passes its qualification gate. It is an input to Risk Guard,
/// not an AI-generated confidence score.
enum FQuantStrategyQualificationEvidence {
    static let source = "F Local Quant Strategy Qualification"

    static func observation(securityCode: String, regime: FMarketRegime, strategyID: String,
                            strategyVersion: String, evaluatedAt: Date) -> FContextObservation? {
        guard validSecurityCode(securityCode), validToken(strategyID), validToken(strategyVersion),
              evaluatedAt.timeIntervalSince1970.isFinite else { return nil }
        return FContextObservation(
            dataClass: .quantState, subject: "strategy-qualification:\(securityCode)",
            source: source,
            reference: "regime=\(regime.rawValue);strategyID=\(strategyID);strategyVersion=\(strategyVersion);qualification=qualified",
            observedAt: evaluatedAt, capturedAt: evaluatedAt, decimalValue: 1)
    }

    static func isQualified(_ observation: FContextObservation,
                            for securityCode: String, regime: FMarketRegime, at now: Date) -> Bool {
        guard validSecurityCode(securityCode), observation.dataClass == .quantState,
              observation.subject == "strategy-qualification:\(securityCode)",
              observation.source == source, observation.decimalValue == 1,
              observation.unavailableReason == nil, observation.isFresh(at: now),
              let reference = observation.reference else { return false }
        let fields = reference.split(separator: ";", omittingEmptySubsequences: false)
        guard fields.count == 4 else { return false }
        let values = fields.compactMap { field -> (String, String)? in
            let pair = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return nil }
            return (String(pair[0]), String(pair[1]))
        }
        guard values.count == 4 else { return false }
        let metadata = Dictionary(values, uniquingKeysWith: { _, _ in "" })
        guard metadata.count == 4,
              metadata["regime"] == regime.rawValue,
              let strategyID = metadata["strategyID"], validToken(strategyID),
              let version = metadata["strategyVersion"], validToken(version) else { return false }
        return metadata["qualification"] == "qualified"
    }

    private static func validSecurityCode(_ value: String) -> Bool {
        value.utf8.count == 6 && value.utf8.allSatisfy { (48...57).contains($0) }
    }

    private static func validToken(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 64 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) ||
                $0 == 45 || $0 == 46 || $0 == 95
        }
    }
}

/// Runtime-only capability proving that trusted FAdvisor code verified the
/// corresponding qualification observation. It is deliberately not Codable and
/// cannot be supplied through the public DecisionContext initializer.
struct FQuantStrategyQualificationGrant: Equatable, Sendable {
    let securityCode: String
    let regime: FMarketRegime
    let strategyID: String
    let strategyVersion: String
    let observationID: UUID
    let evaluatedAt: Date

    init(securityCode: String, regime: FMarketRegime, strategyID: String, strategyVersion: String,
         observationID: UUID, evaluatedAt: Date) {
        self.securityCode = securityCode
        self.regime = regime
        self.strategyID = strategyID
        self.strategyVersion = strategyVersion
        self.observationID = observationID
        self.evaluatedAt = evaluatedAt
    }

    func authorizes(_ observation: FContextObservation, securityCode: String,
                    regime: FMarketRegime, at now: Date) -> Bool {
        self.securityCode == securityCode && self.regime == regime && observation.id == observationID &&
            observation.observedAt == evaluatedAt && observation.capturedAt == evaluatedAt &&
            evaluatedAt <= now && now.timeIntervalSince(evaluatedAt) <= FContextDataClass.quantState.maximumAge &&
            FQuantStrategyQualificationEvidence.isQualified(observation, for: securityCode,
                                                            regime: regime, at: now) &&
            observation.reference == "regime=\(regime.rawValue);strategyID=\(strategyID);strategyVersion=\(strategyVersion);qualification=qualified"
    }
}

private struct FDecisionMarketRegimeEvidence {
    let observation: FContextObservation
    let regime: FMarketRegime
    let risk: FMarketRiskLevel
    var allowedStrategies: Set<FQuantStrategyKind> {
        FMarketRegimeEngine.allowedStrategies(for: regime, riskLevel: risk,
                                               reliable: regime != .dataUnreliable)
    }

    static func find(in observations: [FContextObservation], securityCode: String,
                     at now: Date) -> FDecisionMarketRegimeEvidence? {
        let candidates = observations.filter { observation in
            observation.dataClass == .quantState &&
            observation.subject == securityCode && observation.source == "FCore Market Regime Engine" &&
            observation.isFresh(at: now)
        }
        // Conflicting snapshots must not be resolved by array order. The caller
        // must capture one canonical regime observation per security.
        guard candidates.count == 1, let observation = candidates.first,
              let reference = observation.reference else { return nil }
        var fields: [String: String] = [:]
        var malformed = false
        for component in reference.split(separator: ";", omittingEmptySubsequences: false) {
            let pair = component.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { continue }
            let key = String(pair[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            if ["regime", "risk", "confidence", "dataAsOf"].contains(key) {
                guard fields[key] == nil else { malformed = true; break }
                fields[key] = String(pair[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        guard !malformed,
              let rawRegime = fields["regime"],
              let regime = FMarketRegime(rawValue: rawRegime),
              let rawRisk = fields["risk"], let riskValue = Int(rawRisk),
              let risk = FMarketRiskLevel(rawValue: riskValue),
              let confidence = observation.decimalValue,
              confidence.isFinite, confidence >= 0, confidence <= 100,
              let rawDataAsOf = fields["dataAsOf"],
              let dataAsOf = ISO8601DateFormatter().date(from: rawDataAsOf),
              let observationTime = observation.observedAt,
              dataAsOf <= observationTime, dataAsOf <= observation.capturedAt,
              dataAsOf <= now, now.timeIntervalSince(dataAsOf) <= 5 * 86_400 else { return nil }
        return FDecisionMarketRegimeEvidence(observation: observation, regime: regime, risk: risk)
    }
}

private struct FDecisionMappedBenchmarkEvidence {
    let observation: FContextObservation
    let regime: FMarketRegime
    let risk: FMarketRiskLevel
    var allowedStrategies: Set<FQuantStrategyKind> {
        FMarketRegimeEngine.allowedStrategies(for: regime, riskLevel: risk,
                                               reliable: regime != .dataUnreliable)
    }

    static func find(in observations: [FContextObservation], securityCode: String,
                     mapping: FMarketIndexSecurityMapping, at now: Date)
        -> FDecisionMappedBenchmarkEvidence? {
        let candidates = observations.filter {
            $0.dataClass == .quantState && $0.subject == "mapped-index:\(securityCode)" &&
                $0.source == "F Verified Issuer Index Mapping + NAS Daily Regime"
        }
        guard candidates.count == 1, let observation = candidates.first,
              observation.isFresh(at: now), let reference = observation.reference else { return nil }
        var fields: [String: String] = [:]
        for component in reference.split(separator: ";", omittingEmptySubsequences: false) {
            let pair = component.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { continue }
            let key = String(pair[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            if ["indexCode", "mappingSource", "mapping", "contextRole", "regime", "risk",
                "dataAsOf", "not_strategy_qualification"].contains(key) {
                guard fields[key] == nil else { return nil }
                fields[key] = String(pair[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        guard fields["indexCode"] == mapping.indexCode,
              fields["mappingSource"] == mapping.sourceURL,
              fields["mapping"] == "issuer_benchmark",
              fields["contextRole"] == "benchmark_only",
              fields["not_strategy_qualification"] == "true",
              let rawRegime = fields["regime"],
              let regime = FMarketRegime(rawValue: rawRegime), regime != .dataUnreliable,
              let rawRisk = fields["risk"], let risk = Int(rawRisk),
              let riskLevel = FMarketRiskLevel(rawValue: risk),
              let rawAsOf = fields["dataAsOf"],
              let dataAsOf = ISO8601DateFormatter().date(from: rawAsOf),
              let observedAt = observation.observedAt,
              dataAsOf <= observedAt, dataAsOf <= observation.capturedAt, dataAsOf <= now,
              now.timeIntervalSince(dataAsOf) <= 5 * 86_400,
              let confidence = observation.decimalValue,
              confidence.isFinite, (0...100).contains(confidence) else { return nil }
        return FDecisionMappedBenchmarkEvidence(observation: observation, regime: regime, risk: riskLevel)
    }
}

public struct FCandidateRecommendation: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let accountDigest: String
    public let action: FDecisionAction
    public let instrumentCode: String?
    public let units: Int64?
    public let limitPrice: Decimal?
    public let estimatedFee: Decimal
    public let rationale: String
    public let citedObservationIDs: [UUID]
    public let citedResearchEvidenceIDs: [String]
    public let citedDecisionMemoryIDs: [UUID]
    public let citedInvestorProfileRevisionIDs: [UUID]

    public init(id: UUID = UUID(), accountDigest: String, action: FDecisionAction,
                instrumentCode: String? = nil, units: Int64? = nil,
                limitPrice: Decimal? = nil, estimatedFee: Decimal = 0,
                rationale: String, citedObservationIDs: [UUID] = [],
                citedResearchEvidenceIDs: [String] = [],
                citedDecisionMemoryIDs: [UUID] = [],
                citedInvestorProfileRevisionIDs: [UUID] = []) {
        self.id = id
        self.accountDigest = accountDigest
        self.action = action
        self.instrumentCode = instrumentCode
        self.units = units
        self.limitPrice = limitPrice
        self.estimatedFee = estimatedFee
        self.rationale = rationale
        self.citedObservationIDs = citedObservationIDs
        self.citedResearchEvidenceIDs = citedResearchEvidenceIDs
        self.citedDecisionMemoryIDs = citedDecisionMemoryIDs
        self.citedInvestorProfileRevisionIDs = citedInvestorProfileRevisionIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, accountDigest, action, instrumentCode, units, limitPrice, estimatedFee, rationale
        case citedObservationIDs, citedResearchEvidenceIDs
        case citedDecisionMemoryIDs, citedInvestorProfileRevisionIDs
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        accountDigest = try values.decode(String.self, forKey: .accountDigest)
        action = try values.decode(FDecisionAction.self, forKey: .action)
        instrumentCode = try values.decodeIfPresent(String.self, forKey: .instrumentCode)
        units = try values.decodeIfPresent(Int64.self, forKey: .units)
        limitPrice = try values.decodeIfPresent(Decimal.self, forKey: .limitPrice)
        estimatedFee = try values.decode(Decimal.self, forKey: .estimatedFee)
        rationale = try values.decode(String.self, forKey: .rationale)
        citedObservationIDs = try values.decodeIfPresent([UUID].self, forKey: .citedObservationIDs) ?? []
        citedResearchEvidenceIDs = try values.decodeIfPresent([String].self, forKey: .citedResearchEvidenceIDs) ?? []
        citedDecisionMemoryIDs = try values.decodeIfPresent([UUID].self,
                                                             forKey: .citedDecisionMemoryIDs) ?? []
        citedInvestorProfileRevisionIDs = try values.decodeIfPresent(
            [UUID].self, forKey: .citedInvestorProfileRevisionIDs) ?? []
    }
}

public enum FDecisionGuardFinding: Codable, Equatable, Hashable, Sendable {
    case invalidContext
    case accountChanged
    case invalidCandidate
    case missingFreshQuote(String)
    case staleCitedEvidence(UUID)
    case missingCitedEvidence(UUID)
    case staleResearchEvidence(String)
    case missingResearchEvidence(String)
    case insufficientCash
    case insufficientUnits
    case advisorRequestContextMismatch
    case instrumentScopeMismatch(expected: String, actual: String)
    case missingDecisionMemory(UUID)
    case missingInvestorProfileRevision(UUID)
    case missingQualifiedResearch(String)
    case incompleteTradingEvidence(String)
}

public struct FDecisionGuardResult: Codable, Equatable, Sendable {
    public let allowedForReview: Bool
    public let findings: [FDecisionGuardFinding]

    public init(allowedForReview: Bool, findings: [FDecisionGuardFinding]) {
        self.allowedForReview = allowedForReview
        self.findings = findings
    }
}

/// Two deterministic gates for a reviewable candidate. Passing means only that
/// the candidate is internally consistent with the captured context; it is not
/// approval to trade and has no ledger-writing capability.
public enum FDecisionGuards {
    public static func evaluate(_ candidate: FCandidateRecommendation,
                                in context: FDecisionContext,
                                now: Date = Date()) -> FDecisionGuardResult {
        let risk = FRiskGuard.evaluate(candidate, in: context, now: now)
        let ai = FAIGuard.evaluate(candidate, in: context, now: now)
        let findings = Array(Set(risk.findings + ai.findings))
            .sorted { String(describing: $0) < String(describing: $1) }
        return FDecisionGuardResult(allowedForReview: findings.isEmpty, findings: findings)
    }

    public static func evaluate(_ candidate: FCandidateRecommendation,
                                in context: FDecisionContext,
                                using request: FAdvisorQuestionRequest,
                                now: Date = Date()) -> FDecisionGuardResult {
        let risk = FRiskGuard.evaluate(candidate, in: context, now: now)
        let ai = FAIGuard.evaluate(candidate, in: context, using: request, now: now)
        let findings = Array(Set(risk.findings + ai.findings))
            .sorted { String(describing: $0) < String(describing: $1) }
        return FDecisionGuardResult(allowedForReview: findings.isEmpty, findings: findings)
    }
}

public enum FRiskGuard {
    public static func evaluate(_ candidate: FCandidateRecommendation,
                                in context: FDecisionContext,
                                now: Date = Date()) -> FDecisionGuardResult {
        var findings: [FDecisionGuardFinding] = []
        do { try context.validate(now: now) }
        catch { return FDecisionGuardResult(allowedForReview: false, findings: [.invalidContext]) }
        if candidate.accountDigest != context.accountDigest { findings.append(.accountChanged) }
        if !FDecisionContextValidation.nonBlank(candidate.rationale) || candidate.estimatedFee < 0 ||
            !candidate.estimatedFee.isFinite { findings.append(.invalidCandidate) }

        let isAssetChanging = [.buy, .sell, .dayTrade, .grid].contains(candidate.action)
        if isAssetChanging {
            guard let code = candidate.instrumentCode,
                  let units = candidate.units, units > 0,
                  let price = candidate.limitPrice, price > 0, price.isFinite else {
                findings.append(.invalidCandidate)
                return FDecisionGuardResult(allowedForReview: false, findings: findings)
            }
            let holdingUnits = context.holdingUnits(for: code)
            let validUnits: Bool
            switch candidate.action {
            case .sell:
                validUnits = FMainlandFundTradingRules.isValidSellUnits(units, currentHolding: holdingUnits)
            case .buy, .dayTrade, .grid:
                validUnits = FMainlandFundTradingRules.isValidBuyUnits(units)
            default:
                validUnits = false
            }
            guard validUnits, FMainlandFundTradingRules.isValidLimitPrice(price) else {
                findings.append(.incompleteTradingEvidence(
                    "(code)委托不符合场内基金规则：买入份额须为100的整数倍；卖出可按100的整数倍或一次卖出全部剩余份额；限价须按0.001元递增"))
                return FDecisionGuardResult(allowedForReview: false, findings: findings)
            }
            guard let regimeEvidence = FDecisionMarketRegimeEvidence.find(
                in: context.observations, securityCode: code, at: now) else {
                findings.append(.incompleteTradingEvidence(
                    "\(code) 缺少新鲜、同标的且可验证的 Market Regime 与风险状态"))
                return FDecisionGuardResult(allowedForReview: false, findings: findings)
            }
            let qualification = context.strategyQualificationGrants
                .filter { $0.securityCode == code && $0.regime == regimeEvidence.regime }
                .compactMap { grant in
                    context.observations.first {
                        grant.authorizes($0, securityCode: code, regime: regimeEvidence.regime, at: now)
                    }
                }
                .first
            guard let qualification else {
                findings.append(.incompleteTradingEvidence(
                    "\(code) 缺少新鲜、合格且版本可追溯的本地 Quant 策略资格证据"))
                return FDecisionGuardResult(allowedForReview: false, findings: findings)
            }
            if !candidate.citedObservationIDs.contains(qualification.id) {
                findings.append(.missingCitedEvidence(qualification.id))
            }
            let isBuyIntent = candidate.action == .buy || candidate.action == .dayTrade || candidate.action == .grid
            if isBuyIntent {
                guard let strategyID = qualification.reference.flatMap({ strategyID(in: $0) }),
                      let strategy = FQuantStrategyKind(qualificationID: strategyID),
                      regimeEvidence.allowedStrategies.contains(strategy) else {
                    findings.append(.incompleteTradingEvidence(
                        "Market Regime=\(regimeEvidence.regime.rawValue) 不允许该资格凭证对应的策略；拒绝买入候选"))
                    return FDecisionGuardResult(allowedForReview: false, findings: findings)
                }
            }
            guard let freshQuote = context.freshQuote(for: code, at: now) else {
                findings.append(.missingFreshQuote(code))
                return FDecisionGuardResult(allowedForReview: false, findings: findings)
            }
            if !candidate.citedObservationIDs.contains(freshQuote.id) {
                findings.append(.missingCitedEvidence(freshQuote.id))
            }
            if !candidate.citedObservationIDs.contains(regimeEvidence.observation.id) {
                findings.append(.missingCitedEvidence(regimeEvidence.observation.id))
            }
            if let iopv = context.observations.filter({
                $0.dataClass == .iopv && $0.subject == code && $0.isFresh(at: now)
            }).max(by: { ($0.observedAt ?? .distantPast) < ($1.observedAt ?? .distantPast) }),
               !candidate.citedObservationIDs.contains(iopv.id) {
                findings.append(.missingCitedEvidence(iopv.id))
            }
            let buyIntent = candidate.action == .buy || candidate.action == .dayTrade || candidate.action == .grid
            if buyIntent, let mapping = FMarketIndexSecurityMappingRegistry.mapping(for: code) {
                guard let mappedBenchmark = FDecisionMappedBenchmarkEvidence.find(
                    in: context.observations, securityCode: code, mapping: mapping, at: now) else {
                    findings.append(.incompleteTradingEvidence(
                        "\(code) 已映射到\(mapping.indexName)，但对应市场Regime缺失、过期或来源不匹配；暂停普通买入候选"))
                    return FDecisionGuardResult(allowedForReview: false, findings: findings)
                }
                if !candidate.citedObservationIDs.contains(mappedBenchmark.observation.id) {
                    findings.append(.missingCitedEvidence(mappedBenchmark.observation.id))
                }
                if let strategyID = qualification.reference.flatMap({ strategyID(in: $0) }),
                   let strategy = FQuantStrategyKind(qualificationID: strategyID),
                   !mappedBenchmark.allowedStrategies.contains(strategy) {
                    findings.append(.incompleteTradingEvidence(
                        "对应市场\(mapping.indexName) Regime=\(mappedBenchmark.regime.rawValue) 不允许该资格凭证对应的策略；拒绝买入候选"))
                }
                if mappedBenchmark.risk >= .r3Severe ||
                    [.riskOff, .extremeRisk, .uncertain, .dataUnreliable].contains(mappedBenchmark.regime) {
                    findings.append(.incompleteTradingEvidence(
                        "对应市场\(mapping.indexName) Regime=\(mappedBenchmark.regime.rawValue)、风险R\(mappedBenchmark.risk.rawValue)；暂停普通买入候选"))
                }
            }
            if buyIntent, let currentPrice = freshQuote.decimalValue, price > currentPrice {
                findings.append(.incompleteTradingEvidence(
                    "买入限价高于最新成交价；为避免追价，候选必须等待价格进入计划区"))
            }
            if buyIntent && (regimeEvidence.risk >= .r3Severe ||
                [.riskOff, .extremeRisk, .uncertain, .dataUnreliable].contains(regimeEvidence.regime)) {
                findings.append(.incompleteTradingEvidence(
                    "Market Regime=\(regimeEvidence.regime.rawValue), risk=R\(regimeEvidence.risk.rawValue)；暂停普通买入候选"))
            }
            if candidate.action == .sell || candidate.action == .dayTrade {
                if units > context.holdingUnits(for: code) { findings.append(.insufficientUnits) }
            }
            if candidate.action == .buy || candidate.action == .dayTrade || candidate.action == .grid {
                guard let usage = checkedTradeUsage(price: price, units: units,
                                                    fee: candidate.estimatedFee) else {
                    findings.append(.invalidCandidate)
                    return FDecisionGuardResult(allowedForReview: false, findings: findings)
                }
                if usage > context.cashBalance {
                    findings.append(.insufficientCash)
                }
            }
        }

        return FDecisionGuardResult(allowedForReview: findings.isEmpty, findings: findings)
    }

    private static func checkedTradeUsage(price: Decimal, units: Int64, fee: Decimal) -> Decimal? {
        var price = price
        var quantity = Decimal(units)
        var notional = Decimal.zero
        guard NSDecimalMultiply(&notional, &price, &quantity, .plain) == .noError else { return nil }

        var notionalForAddition = notional
        var fee = fee
        var usage = Decimal.zero
        guard NSDecimalAdd(&usage, &notionalForAddition, &fee, .plain) == .noError,
              usage.isFinite else { return nil }
        return usage
    }
}

private func strategyID(in reference: String) -> String? {
    let values = reference.split(separator: ";", omittingEmptySubsequences: false).compactMap { part -> String? in
        let pair = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard pair.count == 2, pair[0] == "strategyID" else { return nil }
        return String(pair[1])
    }
    return values.count == 1 ? values[0] : nil
}

public enum FAIGuard {
    public static func evaluate(_ candidate: FCandidateRecommendation,
                                in context: FDecisionContext,
                                now: Date = Date()) -> FDecisionGuardResult {
        evaluate(candidate, in: context, using: nil, now: now)
    }

    private static func evaluate(_ candidate: FCandidateRecommendation,
                                 in context: FDecisionContext,
                                 using request: FAdvisorQuestionRequest?,
                                 now: Date) -> FDecisionGuardResult {
        var findings: [FDecisionGuardFinding] = []
        do { try context.validate(now: now) }
        catch { return FDecisionGuardResult(allowedForReview: false, findings: [.invalidContext]) }
        if !FDecisionContextValidation.nonBlank(candidate.rationale) || candidate.rationale.utf8.count > 8_192 {
            findings.append(.invalidCandidate)
        }
        let nonTradingAction = candidate.action == .hold || candidate.action == .wait
        if nonTradingAction && (candidate.instrumentCode != nil || candidate.units != nil ||
                                candidate.limitPrice != nil || candidate.estimatedFee != 0) {
            findings.append(.invalidCandidate)
        }
        if candidate.action == .recoveryPlan {
            guard let code = candidate.instrumentCode,
                  !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  context.holdingUnits(for: code) > 0,
                  candidate.units == nil, candidate.limitPrice == nil,
                  candidate.estimatedFee == 0 else {
                findings.append(.invalidCandidate)
                return FDecisionGuardResult(allowedForReview: false, findings: findings)
            }
        }
        if Set(candidate.citedObservationIDs).count != candidate.citedObservationIDs.count ||
            Set(candidate.citedResearchEvidenceIDs).count != candidate.citedResearchEvidenceIDs.count ||
            candidate.citedResearchEvidenceIDs.contains(where: { $0.trimmingCharacters(
                in: .whitespacesAndNewlines).isEmpty }) {
            findings.append(.invalidCandidate)
        }
        let observations = Dictionary(grouping: context.observations, by: \.id)
        for id in candidate.citedObservationIDs {
            guard let observation = observations[id]?.first else {
                findings.append(.missingCitedEvidence(id)); continue
            }
            if !observation.isFresh(at: now) { findings.append(.staleCitedEvidence(id)) }
        }
        if Set(candidate.citedResearchEvidenceIDs).count != candidate.citedResearchEvidenceIDs.count {
            findings.append(.invalidCandidate)
        }
        if candidate.action == .dayTrade {
            guard let code = candidate.instrumentCode else {
                findings.append(.invalidCandidate)
                return FDecisionGuardResult(allowedForReview: false, findings: findings)
            }
            let quote = context.freshQuote(for: code, at: now)
            if quote?.quoteTemporalMetadata?.marketSessionStatus != .continuous {
                findings.append(.incompleteTradingEvidence("做T候选仅在连续交易时段接受新鲜、可信行情"))
            }
            let citedVWAPStudy = context.usableResearchEvidence(at: now).contains { reference in
                candidate.citedResearchEvidenceIDs.contains(reference.id) &&
                    reference.envelope.securityCode == code &&
                    reference.envelope.market == "CN" &&
                    reference.envelope.hasQualifiedEvidence("vwapBreak")
            }
            if !citedVWAPStudy {
                findings.append(.missingQualifiedResearch("vwapBreak:\(code)"))
            }
        }
        if candidate.action == .grid, let code = candidate.instrumentCode {
            let citedGridStudy = context.usableResearchEvidence(at: now).contains { reference in
                candidate.citedResearchEvidenceIDs.contains(reference.id) &&
                    reference.envelope.securityCode == code &&
                    reference.envelope.hasQualifiedEvidence("gridSpacingReplay")
            }
            if !citedGridStudy {
                findings.append(.missingQualifiedResearch("gridSpacingReplay:\(code)"))
            }
        }
        let availableResearchIDs = Set(context.researchEvidence.map(\.id))
        let usableResearchIDs = Set(context.usableResearchEvidence(at: now).map(\.id))
        for id in candidate.citedResearchEvidenceIDs {
            guard availableResearchIDs.contains(id) else {
                findings.append(.missingResearchEvidence(id)); continue
            }
            if !usableResearchIDs.contains(id) { findings.append(.staleResearchEvidence(id)) }
        }
        if Set(candidate.citedDecisionMemoryIDs).count != candidate.citedDecisionMemoryIDs.count ||
            Set(candidate.citedInvestorProfileRevisionIDs).count !=
                candidate.citedInvestorProfileRevisionIDs.count {
            findings.append(.invalidCandidate)
        }
        if let request {
            guard request.accountID == context.accountID,
                  request.accountDigest == context.accountDigest,
                  request.decisionContextID == context.id,
                  request.decisionContextCreatedAt == context.createdAt,
                  request.portfolioContext?.matches(context, scope: request.scope) == true else {
                findings.append(.advisorRequestContextMismatch)
                let failed = Array(Set(findings)).sorted {
                    String(describing: $0) < String(describing: $1)
                }
                return FDecisionGuardResult(allowedForReview: false, findings: failed)
            }
            let memoryIDs = Set(request.decisionMemory?.entries.map(\.id) ?? [])
            for id in candidate.citedDecisionMemoryIDs where !memoryIDs.contains(id) {
                findings.append(.missingDecisionMemory(id))
            }
            let profileRevisionIDs = Set(request.investorProfile?.preferences.map(\.revisionID) ?? [])
            for id in candidate.citedInvestorProfileRevisionIDs where !profileRevisionIDs.contains(id) {
                findings.append(.missingInvestorProfileRevision(id))
            }
        } else {
            findings += candidate.citedDecisionMemoryIDs.map(FDecisionGuardFinding.missingDecisionMemory)
            findings += candidate.citedInvestorProfileRevisionIDs.map(
                FDecisionGuardFinding.missingInvestorProfileRevision)
        }
        let uniqueFindings = Array(Set(findings)).sorted { String(describing: $0) < String(describing: $1) }
        return FDecisionGuardResult(allowedForReview: uniqueFindings.isEmpty, findings: uniqueFindings)
    }

    public static func evaluate(_ candidate: FCandidateRecommendation,
                                in context: FDecisionContext,
                                using request: FAdvisorQuestionRequest,
                                now: Date = Date()) -> FDecisionGuardResult {
        evaluate(candidate, in: context, using: Optional(request), now: now)
    }
}

public enum FDecisionContextError: Error, Equatable, Sendable {
    case invalidContext
    case invalidObservation(UUID)
    case invalidResearchEvidence(String)
    case researchEvidencePayloadTooLarge
}

private enum FDecisionContextValidation {
    static func nonBlank(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    static func digest(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy(\.isHexDigit)
    }
    static func plausible(_ date: Date, now: Date) -> Bool {
        date.timeIntervalSince1970.isFinite && date <= now.addingTimeInterval(300)
    }
}
