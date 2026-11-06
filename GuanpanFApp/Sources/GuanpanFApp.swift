import SwiftUI
import Foundation
import CoreFoundation
import CryptoKit
import FCore
import FAdvisor
import FLedgerWrite

private func fIopvPremiumPercent(price: Decimal, iopv: Decimal) -> Decimal? {
    guard price.isFinite, price > 0, iopv.isFinite, iopv > 0 else { return nil }
    var price = price
    var iopv = iopv
    var ratio = Decimal.zero
    guard NSDecimalDivide(&ratio, &price, &iopv, .plain) == .noError else { return nil }
    var one = Decimal(1)
    var premium = Decimal.zero
    guard NSDecimalSubtract(&premium, &ratio, &one, .plain) == .noError else { return nil }
    var hundred = Decimal(100)
    var percent = Decimal.zero
    guard NSDecimalMultiply(&percent, &premium, &hundred, .plain) == .noError,
          percent.isFinite else { return nil }
    return percent
}

@main
struct GuanpanFApp: App {
    @StateObject private var model = FHomeModel()
    var body: some Scene { WindowGroup { FHomeRoot(model: model) } }
}

struct FHomeHolding: Identifiable {
    var id: String { instrumentCode }
    let instrumentCode: String
    let name: String
    let units: Int64
    let bookCost: Decimal
    let brokerDisplayCostPerUnit: Decimal?
    let brokerDisplayCostUpdatedAt: Date?
}

struct FInitialLedgerPositionInput {
    let instrumentCode: String
    let name: String
    let units: Int64
    let economicCost: Decimal
    let brokerDisplayCostPerUnit: Decimal?
}

struct FTencentMarketReference: Equatable {
    let securityCode: String
    let latestPrice: Decimal
    let previousClose: Decimal
    let iopv: Decimal?
    let premiumPercent: Decimal?
    let observedAt: Date
    let fetchedAt: Date
    let providerInstrumentType: String?
    let source: String

    func hasTrustedTimestamp(at now: Date = Date()) -> Bool {
        let valuesAreValid = latestPrice.isFinite && latestPrice > 0 &&
            previousClose.isFinite && previousClose > 0 &&
            (iopv.map { $0.isFinite && $0 > 0 } ?? true) &&
            (premiumPercent.map { $0.isFinite && $0 > -100 } ?? true)
        let timesAreValid = observedAt.timeIntervalSince1970.isFinite &&
            fetchedAt.timeIntervalSince1970.isFinite && now.timeIntervalSince1970.isFinite &&
            observedAt <= fetchedAt && fetchedAt <= now
        let identityIsValid = securityCode.utf8.count == 6 &&
            securityCode.utf8.allSatisfy { (48...57).contains($0) } &&
            !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return valuesAreValid && timesAreValid && identityIsValid
    }

    func hasFreshIOPV(at now: Date = Date()) -> Bool {
        guard hasFreshReference(at: now), iopv != nil else { return false }
        let age = now.timeIntervalSince(observedAt)
        return age.isFinite && age >= 0 && age <= FContextDataClass.iopv.maximumAge
    }

    func hasFreshReference(at now: Date = Date()) -> Bool {
        guard hasTrustedTimestamp(at: now) else { return false }
        let age = now.timeIntervalSince(observedAt)
        return age.isFinite && age >= 0 && age <= 900
    }
}

struct FMarketIndexQuote: Identifiable, Equatable, Sendable {
    var id: String { code }
    let code: String
    let name: String
    let market: String
    let timeZoneIdentifier: String
    let latestPrice: Decimal?
    let changePercent: Decimal?
    let observedAt: Date?
    let fetchedAt: Date?
    let source: String?
    let marketStatus: String?
    let unavailableReason: String?

    var hasNumericQuote: Bool { latestPrice != nil && changePercent != nil }
    var isAvailable: Bool {
        guard hasNumericQuote, let observedAt, let fetchedAt, unavailableReason == nil,
              FMarketQuoteTrustPolicy.isTrusted(source),
              observedAt.timeIntervalSince1970.isFinite, fetchedAt.timeIntervalSince1970.isFinite else {
            return false
        }
        return observedAt <= fetchedAt
    }

    func freshness(at now: Date) -> FQuoteFreshness {
        guard isAvailable, let observedAt, let fetchedAt else { return .unverified }
        return FQuoteTemporalMetadata(quoteTimestamp: observedAt, fetchedAt: fetchedAt,
                                      source: source, timestampTrust: .verifiedExchangeTimestamp,
                                      marketSessionStatus: .unknown).freshness(at: now)
    }
}

typealias FHomeLedgerState = FHomeLedgerAvailability

@MainActor
final class FHomeModel: ObservableObject {
    static let commonQuestions = [
        "今天我的持仓需要操作吗？",
        "159352 现在适合买入吗？",
        "我的 A500 怎么降低成本？",
        "今天适合做 T 吗？",
        "为什么今天的建议和昨天不一样？"
    ]

    func commonQuestions(for instrumentCode: String?) -> [String] {
        guard let instrumentCode else { return Self.commonQuestions }
        return [
            "\(instrumentCode) 今天需要操作吗？",
            "\(instrumentCode) 现在适合买入吗？",
            "我的 \(instrumentCode) 怎么降低成本？",
            "\(instrumentCode) 今天适合做 T 吗？",
            "为什么 \(instrumentCode) 今天的建议和昨天不一样？"
        ]
    }

    @Published private(set) var cashBalance: Decimal?
    @Published private(set) var holdings: [FHomeHolding] = []
    @Published private(set) var instrumentHistories: [FInstrumentHistorySnapshot] = []
    @Published private(set) var cashFlow: [FReadOnlyCashFlowEntry] = []
    /// Local watchlist is separate from Ledger positions and never creates holdings.
    @Published private(set) var watchlistCodes: [String] = []
    @Published private(set) var ledgerStatus = "正在读取本机真实账本"
    @Published private(set) var ledgerState: FHomeLedgerState = .loading
    @Published var question = ""
    @Published var alertMessage: String?
    @Published private(set) var marketDataByCode: [String: FCurrentIntradaySnapshot] = [:]
    @Published private(set) var marketReferenceByCode: [String: FTencentMarketReference] = [:]
    @Published private(set) var marketReferenceStateByCode: [String: String] = [:]
    private var refreshingReferenceCodes: Set<String> = []
    private var marketRefreshTasks: [String: Task<Void, Never>] = [:]
    @Published private(set) var marketRefreshStateByCode: [String: String] = [:]
    @Published private(set) var archivedIntradayByCode: [String: FNASArchivedIntraday] = [:]
    @Published private(set) var archiveRefreshStateByCode: [String: String] = [:]
    @Published private(set) var dailyKlineByCode: [String: FDailyKlineSnapshot] = [:]
    @Published private(set) var dailyKlineStateByCode: [String: String] = [:]
    @Published private(set) var securityRegimeByCode: [String: FMarketRegimeAssessment] = [:]
    @Published private(set) var securityRegimeStatusByCode: [String: String] = [:]
    private var regimeMemoryByCode: [String: FMarketRegimeMemory] = [:]
    @Published private(set) var marketIndexQuotes: [FMarketIndexQuote] = FMarketIndexHTTPClient.emptyCatalog
    @Published private(set) var refreshingMarketIndices = false
    @Published private(set) var marketIndicesUpdatedAt: Date?
    @Published private(set) var marketIndicesError: String?
    @Published private(set) var marketIndexRegimesByCode: [String: FMarketRegimeAssessment] = [:]
    @Published private(set) var marketIndexRegimeFetchedAtByCode: [String: Date] = [:]
    @Published private(set) var marketIndexRegimeStatusByCode: [String: String] = FMarketIndexHTTPClient.regimeStatusCatalog
    @Published private(set) var refreshingMarketIndexRegimes = false
    @Published var selectedHistoryDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @Published private(set) var refreshingMarketCodes: Set<String> = []
    @Published private(set) var selectedInstrumentCode: String?
    @Published private(set) var nasConnectionStatus = "未配置"
    @Published private(set) var checkingNASConnection = false
    @Published private(set) var nasResearchStatus = "尚未请求"
    @Published private(set) var nasResearchEvidenceByCode: [String: FDecisionResearchEvidence] = [:]
    private var nasDataSourceKey: String?
    private var nasDataGeneration: UInt64 = 0
    private var refreshingNASResearchCodes: [String: UInt64] = [:]
    private var cachedNewsFeed: FNewsFeed?
    private var newsRefreshTask: Task<Void, Never>?
    private var newsLastAttemptAt: Date?
    @Published private(set) var newsStatus = "尚未请求"
    @Published private(set) var aiKeyStatus = "未配置 DeepSeek API Key"
    @Published private(set) var investorProfile = FInvestorProfile()
    @Published private(set) var investorProfileStatus = "正在读取本机画像"
    @Published private(set) var loadingInvestorProfile = true
    @Published private(set) var savingInvestorProfile = false
    private var investorProfileLoadGeneration: UInt64 = 0
    @Published private(set) var advisorStatus = "尚未开始分析"
    @Published private(set) var candidateShadowJournalStatus = "建议成绩单尚未记录"
    @Published private(set) var candidateShadowSummary: FCandidateShadowSummary?
    @Published private(set) var isAskingAdvisor = false
    @Published private(set) var advisorResult: FAdvisorVerticalSliceResult?
    @Published var showingLedgerConfirmation = false
    @Published var showingInitialLedgerSetup = false
    @Published var showingManualLedgerFill = false
    @Published private(set) var writingInitialLedger = false
    @Published var showingFeeCorrection = false
    @Published var showingCashAdjustment = false
    @Published var feeCorrectionFillID: UUID?
    @Published var correctedFeeText = ""
    @Published var feeCorrectionReason = ""
    @Published var feeCorrectionConfirmationNote = ""
    @Published private(set) var writingFeeCorrection = false
    @Published var cashAdjustmentAmountText = ""
    @Published var cashAdjustmentAddsCash = false
    @Published var cashAdjustmentReason = ""
    @Published var cashAdjustmentConfirmationNote = ""
    @Published private(set) var writingCashAdjustment = false
    @Published private(set) var cashAdjustmentStatus = ""
    @Published var actualFillUnitsText = ""
    @Published var actualFillPriceText = ""
    @Published var actualFillFeeText = NSDecimalNumber(decimal: FETFTradeFeePolicy.defaultReferencePerFill).stringValue
    @Published var actualFillInstrumentName = ""
    @Published var actualFillTradeIntent: FTradeIntent = .ordinary
    @Published var actualFillTCycleID = ""
    @Published var ledgerConfirmationNote = ""
    @Published private(set) var writingConfirmedFill = false
    @Published private(set) var ledgerWriteStatus = ""
    @Published var manualFillInstrumentCode = ""
    @Published var manualFillInstrumentName = ""
    @Published var manualFillSide: FTradeSide = .buy
    @Published var manualFillTradeAt = Date()
    @Published var manualFillUnitsText = ""
    @Published var manualFillPriceText = ""
    @Published var manualFillFeeText = NSDecimalNumber(decimal: FETFTradeFeePolicy.defaultReferencePerFill).stringValue
    @Published var manualFillTradeIntent: FTradeIntent = .ordinary
    @Published var manualFillTCycleID = ""
    @Published var manualFillConfirmationNote = ""
    @Published private(set) var writingManualFill = false
    @Published var manualFillNeedsFinalConfirmation = false
    private var pendingCandidate: FCandidateRecommendation?
    private var pendingCandidateScope: FAdvisorEntryScope?
    private var ledgerStore: FAccountBookStore?
    private var marketQuoteCache: FMarketQuoteCache?
    private var decisionMemoryStore: FDecisionMemoryStore?
    private var investorProfileStore: FInvestorProfileStore?
    private var investorProfileDigest: String?
    private var decisionContextStore: FDecisionContextStore?
    private var candidateShadowJournalStore: FCandidateShadowJournalStore?
    var latestLedgerSnapshot: FReadOnlyLedgerSnapshot?

    init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                         in: .userDomainMask).first
        Self.resetPersistentStateForUITestsIfRequested(applicationSupport: supportDirectory)
        watchlistCodes = Self.loadWatchlistCodes()
        guard let support = supportDirectory else {
            ledgerState = .unavailable
            ledgerStatus = "本机应用数据目录不可用 · 真实账本未读取"
            return
        }
        let store = FAccountBookStore(fileURL: support.appendingPathComponent("f-real-ledger.json"))
        ledgerStore = store
        marketQuoteCache = try? FMarketQuoteCache(
            directory: support.appendingPathComponent("f-market-quote-cache", isDirectory: true))
        let advisorDirectory = support.appendingPathComponent("f-advisor", isDirectory: true)
        decisionMemoryStore = FDecisionMemoryStore(directory: advisorDirectory)
        investorProfileStore = FInvestorProfileStore(directory: advisorDirectory)
        decisionContextStore = FDecisionContextStore(directory: advisorDirectory)
        candidateShadowJournalStore = FCandidateShadowJournalStore(directory: advisorDirectory)
        aiKeyStatus = (try? FAdvisorAIKeychain.read()) == nil
            ? "未配置 DeepSeek API Key" : "DeepSeek Key 已保存在本机 Keychain"
        if let marketQuoteCache {
            Task { await restoreCachedMarketQuotes(from: marketQuoteCache) }
        }
        Task { await loadLedger(from: store) }
        Task { await refreshCandidateShadowSummary() }
        Task { await loadInvestorProfile() }
    }

    /// UI tests share an installed Simulator app across test methods. Reset only
    /// app-owned persistence when the explicit UI-test launch flag is present,
    /// so tests cannot inherit a prior method's real-ledger or preference state.
    private static func resetPersistentStateForUITestsIfRequested(applicationSupport: URL?) {
        guard ProcessInfo.processInfo.arguments.contains("-guanpan.ui-testing-reset-state") else { return }
        if let applicationSupport {
            let fileManager = FileManager.default
            for name in ["f-real-ledger.json", "f-market-quote-cache", "f-advisor"] {
                try? fileManager.removeItem(at: applicationSupport.appendingPathComponent(name))
            }
        }
        let defaults = UserDefaults.standard
        let appOwnedKeys = Array(defaults.dictionaryRepresentation().keys)
            .filter { $0.hasPrefix("guanpan.f.") }
        for key in appOwnedKeys {
            defaults.removeObject(forKey: key)
        }
    }

    private func restoreCachedMarketQuotes(from cache: FMarketQuoteCache) async {
        for snapshot in await cache.loadAll() {
            if let current = marketDataByCode[snapshot.securityCode],
               current.quoteTimestamp > snapshot.quoteTimestamp ||
                (current.quoteTimestamp == snapshot.quoteTimestamp && current.fetchedAt >= snapshot.fetchedAt) {
                continue
            }
            marketDataByCode[snapshot.securityCode] = snapshot
            marketRefreshStateByCode[snapshot.securityCode] =
                "本机缓存 · 仅供离线查看 · 行情时间 \(snapshot.quoteTimestamp.formatted(date: .abbreviated, time: .standard)) · 获取于 \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .standard))"
        }
    }

    func refreshCandidateShadowSummary(now: Date = Date()) async {
        guard let candidateShadowJournalStore else { return }
        do {
            let archive = try await candidateShadowJournalStore.load()
            candidateShadowSummary = archive.scorecard(
                since: now.addingTimeInterval(-30 * 24 * 60 * 60), asOf: now)
        } catch {
            candidateShadowJournalStatus = "建议成绩单暂不可读取 · \(error.localizedDescription)"
        }
    }

    private func loadLedger(from store: FAccountBookStore) async {
        do {
            guard let snapshot = try await store.readLedgerSnapshot(now: Date()) else {
                ledgerState = .notEstablished
                ledgerStatus = "尚未建立真实账本"
                return
            }
            cashBalance = snapshot.cashBalance
            instrumentHistories = snapshot.instrumentHistories
            cashFlow = snapshot.cashFlow
            latestLedgerSnapshot = snapshot
            holdings = snapshot.positions.map {
                FHomeHolding(instrumentCode: $0.instrumentCode, name: $0.name,
                             units: $0.units, bookCost: $0.bookCost,
                             brokerDisplayCostPerUnit: $0.brokerDisplayCostPerUnit,
                             brokerDisplayCostUpdatedAt: $0.brokerDisplayCostUpdatedAt)
            }
            ledgerState = .available
            ledgerStatus = "真实账本 · 只读快照 · \(holdings.count) 项持仓"
        } catch {
            ledgerState = .unavailable
            ledgerStatus = "真实账本不可读取 · \(String(describing: error))"
        }
    }

    var portfolioContextLabel: String {
        switch ledgerState {
        case .loading: return "组合上下文：读取中"
        case .notEstablished: return "组合上下文：账本尚未建立"
        case .unavailable: return "组合上下文：账本不可读取"
        case .available:
            return holdings.isEmpty ? "组合上下文：已读取 · 当前无持仓" : "组合上下文：已读取真实组合"
        }
    }

    var marketCalendarStatusText: String {
        switch FMainlandTradingCalendar.status(at: Date()) {
        case .continuous: return "交易中 · 行情自动刷新"
        case .lunchBreak: return "午间休市 · 自动刷新暂停"
        case .preOpen: return "开盘前 · 自动刷新暂停"
        case .closed: return "已收盘或休市 · 自动刷新暂停"
        case .unknown: return "交易日历未覆盖当前年份 · 自动刷新暂停"
        }
    }

    func securityDailyPnL(for code: String, at now: Date = Date()) -> Decimal? {
        guard let snapshot = latestLedgerSnapshot else { return nil }
        let tradingDate = snapshot.dailyTradeSummaryDate
        guard
              (try? FDailyTradeSummary.tradingDate(for: now)) == tradingDate,
              (try? FDailyTradeSummary.tradingDate(for: snapshot.capturedAt)) == tradingDate,
              let quote = marketDataByCode[code], quote.freshness(at: now) == .fresh,
              let currentPrice = quote.latestPrice,
              let reference = marketReferenceByCode[code], reference.hasFreshReference(at: now),
              let quoteDate = try? FDailyTradeSummary.tradingDate(for: quote.quoteTimestamp),
              let referenceDate = try? FDailyTradeSummary.tradingDate(for: reference.observedAt),
              quoteDate == tradingDate, referenceDate == tradingDate,
              FSecurityPnLCalculator.openingSnapshotSupportsDailyPnL(
                  openingSnapshotCapturedAt: snapshot.openingSnapshotCapturedAt,
                  securityCode: code, openingPositionCodes: snapshot.openingPositionCodes,
                  tradingDate: tradingDate) else { return nil }
        let synchronizedGap = abs(quote.quoteTimestamp.timeIntervalSince(reference.observedAt))
        guard synchronizedGap.isFinite, synchronizedGap <= 15 * 60 else { return nil }
        let endingUnits = snapshot.positions.first(where: { $0.instrumentCode == code })?.units ?? 0
        let trades = snapshot.dailyTradeSummaries.first(where: { $0.securityCode == code })
        return try? FSecurityPnLCalculator.dailySecurityPnL(
            securityCode: code, tradingDate: tradingDate,
            previousClose: reference.previousClose, trades: trades,
            endOfDayUnits: endingUnits, currentPrice: currentPrice)
    }

    var portfolioSecurityDailyPnL: Decimal? {
        portfolioSecurityDailyPnL(at: Date())
    }

    func portfolioSecurityDailyPnL(at now: Date) -> Decimal? {
        guard ledgerState == .available, let snapshot = latestLedgerSnapshot else { return nil }
        let codes = Set(snapshot.positions.map(\.instrumentCode))
            .union(snapshot.dailyTradeSummaries.map(\.securityCode))
        var total = Decimal.zero
        for code in codes {
            guard let value = securityDailyPnL(for: code, at: now) else { return nil }
            total += value
            guard total.isFinite else { return nil }
        }
        return total
    }

    func portfolioMarketValuation(at now: Date)
        -> Result<FPortfolioMarketValuation, FPortfolioMarketValuationUnavailableReason> {
        guard ledgerState == .available, let snapshot = latestLedgerSnapshot else {
            return .failure(.ledgerUnavailable)
        }
        return FPortfolioMarketValuationCalculator.calculate(
            ledger: snapshot, quotes: marketDataByCode, at: now)
    }

    func askAdvisor(instrumentCode: String? = nil) {
        guard !isAskingAdvisor else { return }
        Task { await runAdvisorQuestion(instrumentCode: instrumentCode) }
    }

    /// Opens a draft only for a directly recordable buy or sell recommendation.
    /// The user must still enter the actual fill, then press the separate confirm
    /// action before the only ledger writer is invoked.
    func beginLedgerConfirmation(for result: FAdvisorVerticalSliceResult) {
        guard result.isReviewable,
              result.candidate.action == .buy || result.candidate.action == .sell,
              let code = result.candidate.instrumentCode,
              let units = result.candidate.units,
              let price = result.candidate.limitPrice,
              result.candidate.accountDigest == latestLedgerSnapshot?.ledgerDigest else {
            ledgerWriteStatus = "候选计划已失效或不是可登记的单笔买入/卖出；请重新分析。"
            return
        }
        pendingCandidate = result.candidate
        pendingCandidateScope = result.scope
        actualFillUnitsText = String(units)
        actualFillPriceText = NSDecimalNumber(decimal: price).stringValue
        actualFillFeeText = NSDecimalNumber(decimal: FETFTradeFeePolicy.defaultReferencePerFill).stringValue
        actualFillTradeIntent = .ordinary
        actualFillTCycleID = ""
        actualFillInstrumentName = latestLedgerSnapshot?.instrumentHistories.first(where: {
            $0.instrumentCode == code
        })?.instrumentName ?? latestLedgerSnapshot?.positions.first(where: {
            $0.instrumentCode == code
        })?.name ?? code
        ledgerConfirmationNote = ""
        ledgerWriteStatus = "请核对并填写实际成交信息；此操作会更新真实账本。"
        showingLedgerConfirmation = true
    }

    func confirmBrokerDisplayCost(instrumentCode: String, costText: String, note: String) async {
        guard let store = ledgerStore,
              let cost = Decimal(string: costText.trimmingCharacters(in: .whitespacesAndNewlines),
                                 locale: Locale(identifier: "en_US_POSIX")), cost.isFinite, cost >= 0,
              !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ledgerWriteStatus = "请输入有效的券商单位成本和本次修正说明。"
            return
        }
        do {
            let now = Date()
            let confirmation = FUserLedgerConfirmation(
                confirmedAt: now,
                confirmationNote: "券商展示成本：" + note.trimmingCharacters(in: .whitespacesAndNewlines))
            let writer = FConfirmedLedgerWriter(store: store)
            _ = try await writer.confirmBrokerDisplayCost(instrumentCode: instrumentCode,
                                                          costPerUnit: cost,
                                                          confirmation: confirmation,
                                                          now: now)
            await loadLedger(from: store)
            ledgerWriteStatus = "券商展示成本已保存；Episode经济成本和成交流水未被改写。"
        } catch {
            ledgerWriteStatus = "券商展示成本未保存：\(error.localizedDescription)"
        }
    }

    func beginFeeCorrection(for entry: FReadOnlyCashFlowEntry) {
        guard let fillID = entry.sourceFillID, let fee = entry.effectiveFee else { return }
        feeCorrectionFillID = fillID
        correctedFeeText = NSDecimalNumber(decimal: fee).stringValue
        feeCorrectionReason = ""
        feeCorrectionConfirmationNote = ""
        ledgerWriteStatus = "请输入券商实际收取的该笔总手续费；保存时仅追加费用更正事件。"
        showingFeeCorrection = true
    }

    func confirmFeeCorrection() {
        guard !writingFeeCorrection else { return }
        Task { await writeFeeCorrection() }
    }

    func beginCashAdjustment() {
        cashAdjustmentAmountText = ""
        cashAdjustmentAddsCash = false
        cashAdjustmentReason = ""
        cashAdjustmentConfirmationNote = ""
        cashAdjustmentStatus = "现金对账差额只改变现金余额，不归属到任何证券成本或盈亏。"
        showingCashAdjustment = true
    }

    func confirmCashAdjustment() {
        guard !writingCashAdjustment else { return }
        Task { await writeCashAdjustment() }
    }

    private func writeCashAdjustment() async {
        guard let store = ledgerStore,
              let enteredAmount = Decimal(string: cashAdjustmentAmountText.trimmingCharacters(in: .whitespacesAndNewlines),
                                           locale: Locale(identifier: "en_US_POSIX")),
              enteredAmount.isFinite, enteredAmount > 0,
              !cashAdjustmentReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !cashAdjustmentConfirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cashAdjustmentStatus = "请填写正数金额、原因和确认说明。增加或减少方向由选择器指定。"
            return
        }
        let amount = cashAdjustmentAddsCash ? enteredAmount : -enteredAmount
        writingCashAdjustment = true
        defer { writingCashAdjustment = false }
        do {
            let now = Date()
            guard let book = try await store.load(now: now) else {
                throw FLedgerPersistenceError.primaryFileMissing
            }
            let lastSequence = (book.fills.map(\.sequence) + book.cashMovements.map(\.sequence) +
                                (book.feeAdjustments ?? []).map(\.sequence)).max() ?? 0
            guard lastSequence < UInt64.max else {
                throw FAdvisorLiveError.ledgerChangedDuringAnalysis
            }
            let confirmation = FUserLedgerConfirmation(
                confirmedAt: now,
                confirmationNote: cashAdjustmentConfirmationNote.trimmingCharacters(in: .whitespacesAndNewlines))
            let movement = FCashMovement(
                sequence: lastSequence + 1, occurredAt: now, amount: amount,
                category: cashAdjustmentAddsCash ? .cashReconciliation : .accountExpense,
                reason: "\(cashAdjustmentAddsCash ? "现金对账" : "账户级杂费")：\(cashAdjustmentReason.trimmingCharacters(in: .whitespacesAndNewlines))",
                userConfirmation: confirmation)
            let writer = FConfirmedLedgerWriter(store: store)
            _ = try await writer.confirmCashMovement(movement, now: now)
            await loadLedger(from: store)
            pendingCandidate = nil
            pendingCandidateScope = nil
            advisorResult = nil
            showingCashAdjustment = false
            cashAdjustmentStatus = cashAdjustmentAddsCash
                ? "现金对账差额已追加；证券持仓、成本及盈亏未改变。旧AI候选已失效。"
                : "账户级杂费已记入现金流水；未归属到证券成本或证券盈亏。旧AI候选已失效。"
        } catch {
            cashAdjustmentStatus = "现金对账差额未保存：\(error.localizedDescription)"
        }
    }

    private func writeFeeCorrection() async {
        guard let store = ledgerStore, let fillID = feeCorrectionFillID,
              let correctedFee = Decimal(string: correctedFeeText.trimmingCharacters(in: .whitespacesAndNewlines),
                                          locale: Locale(identifier: "en_US_POSIX")), correctedFee.isFinite,
              correctedFee >= 0,
              !feeCorrectionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !feeCorrectionConfirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ledgerWriteStatus = "请填写有效的修正后手续费、差额原因和确认说明。"
            return
        }
        writingFeeCorrection = true
        defer { writingFeeCorrection = false }
        do {
            let now = Date()
            let confirmation = FUserLedgerConfirmation(
                confirmedAt: now,
                confirmationNote: feeCorrectionConfirmationNote.trimmingCharacters(in: .whitespacesAndNewlines))
            let writer = FConfirmedLedgerWriter(store: store)
            _ = try await writer.confirmFillFeeCorrection(
                fillID: fillID, correctedFee: correctedFee,
                reason: feeCorrectionReason.trimmingCharacters(in: .whitespacesAndNewlines),
                confirmation: confirmation, now: now)
            await loadLedger(from: store)
            pendingCandidate = nil
            pendingCandidateScope = nil
            advisorResult = nil
            showingFeeCorrection = false
            ledgerWriteStatus = "手续费更正已追加；现金按补录日结算，历史成本与盈亏按原成交重算。原AI候选已失效，请使用更新后的账本重新提问。"
        } catch {
            ledgerWriteStatus = "手续费更正未保存：\(error.localizedDescription)"
        }
    }

    func confirmPendingFill() {
        guard !writingConfirmedFill else { return }
        Task { await writePendingConfirmedFill() }
    }

    func clearLedgerWriteStatus() {
        ledgerWriteStatus = ""
    }

    func establishInitialLedger(cashText: String, positions: [FInitialLedgerPositionInput],
                                note: String) async -> Bool {
        guard ledgerState == .notEstablished, let store = ledgerStore else {
            ledgerWriteStatus = "已有账本或账本不可用；初始快照不会覆盖现有数据。"
            return false
        }
        guard let cash = Decimal(string: cashText.trimmingCharacters(in: .whitespacesAndNewlines),
                                 locale: Locale(identifier: "en_US_POSIX")), cash.isFinite, cash >= 0,
              !positions.isEmpty,
              positions.allSatisfy({
                  $0.instrumentCode.utf8.count == 6 &&
                  $0.instrumentCode.utf8.allSatisfy { (48...57).contains($0) } &&
                  !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  $0.units > 0 && $0.economicCost.isFinite && $0.economicCost >= 0 &&
                  ($0.brokerDisplayCostPerUnit.map { $0.isFinite && $0 >= 0 } ?? true)
              }), Set(positions.map(\.instrumentCode)).count == positions.count,
              !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ledgerWriteStatus = "请填写有效现金、至少一只证券、唯一代码、正份额、真实成本和确认说明。"
            return false
        }
        writingInitialLedger = true
        defer { writingInitialLedger = false }
        do {
            let now = Date()
            let openingPositions = positions.map { input in
                FPosition(instrumentCode: input.instrumentCode,
                          name: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
                          units: input.units, bookCost: input.economicCost,
                          brokerDisplayCostPerUnit: input.brokerDisplayCostPerUnit,
                          brokerDisplayCostUpdatedAt: input.brokerDisplayCostPerUnit == nil ? nil : now)
            }
            let opening = FAccountOpeningSnapshot(capturedAt: now, cashBalance: cash,
                                                  positions: openingPositions)
            let book = FAccountBook(openingSnapshot: opening, cashBalance: cash,
                                    positions: openingPositions, updatedAt: now)
            let confirmation = FUserLedgerConfirmation(
                confirmedAt: now,
                confirmationNote: "用户录入当前真实持仓快照：" + note.trimmingCharacters(in: .whitespacesAndNewlines))
            let writer = FConfirmedLedgerWriter(store: store)
            _ = try await writer.confirmInitialLedger(book, confirmation: confirmation, now: now)
            await loadLedger(from: store)
            ledgerWriteStatus = "初始真实账户快照已保存；份额是当前持仓起点，不会伪装成历史成交。"
            return true
        } catch {
            ledgerWriteStatus = "初始真实持仓未保存：\(error.localizedDescription)"
            return false
        }
    }

    private func writePendingConfirmedFill() async {
        guard let candidate = pendingCandidate, let scope = pendingCandidateScope,
              let store = ledgerStore,
              let code = candidate.instrumentCode,
              let units = Int64(actualFillUnitsText.trimmingCharacters(in: .whitespacesAndNewlines)),
              units > 0,
              let price = Decimal(string: actualFillPriceText.trimmingCharacters(in: .whitespacesAndNewlines),
                                  locale: Locale(identifier: "en_US_POSIX")), price.isFinite, price > 0,
              let fee = Decimal(string: actualFillFeeText.trimmingCharacters(in: .whitespacesAndNewlines),
                                locale: Locale(identifier: "en_US_POSIX")), fee.isFinite, fee >= 0,
              !actualFillInstrumentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !ledgerConfirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ledgerWriteStatus = "请填写有效的实际成交份额、价格、手续费、证券名称和确认说明。"
            return
        }
        let side: FTradeSide
        switch candidate.action {
        case .buy: side = .buy
        case .sell: side = .sell
        default:
            ledgerWriteStatus = "做T、网格和回本计划必须逐笔记录真实成交，不能自动写入账本。"
            return
        }
        if (actualFillTradeIntent == .tSell && side != .sell) ||
            (actualFillTradeIntent == .tBuyback && side != .buy) ||
            (actualFillTradeIntent != .ordinary &&
             actualFillTCycleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            ledgerWriteStatus = "做T成交请正确选择卖出/买回，并为同一组填写相同配对编号。"
            return
        }
        writingConfirmedFill = true
        defer { writingConfirmedFill = false }
        do {
            let now = Date()
            guard let snapshot = try await store.readLedgerSnapshot(now: now),
                  snapshot.ledgerDigest == candidate.accountDigest,
                  let book = try await store.load(now: now) else {
                throw FAdvisorLiveError.ledgerChangedDuringAnalysis
            }
            let lastSequence = (book.fills.map(\.sequence) + book.cashMovements.map(\.sequence) +
                                (book.feeAdjustments ?? []).map(\.sequence)).max() ?? 0
            guard lastSequence < UInt64.max else { throw FAdvisorLiveError.ledgerChangedDuringAnalysis }
            let removedCost: Decimal?
            if side == .sell {
                guard let position = book.positions.first(where: { $0.instrumentCode == code }) else {
                    throw FLedgerMutationError.missingPosition(code)
                }
                removedCost = try FAccountingPolicy.costBasisRemoved(unitsSold: units,
                                                                      totalUnits: position.units,
                                                                      totalBookCost: position.bookCost)
            } else {
                removedCost = nil
            }
            let confirmation = FUserLedgerConfirmation(confirmedAt: now,
                                                       confirmationNote: ledgerConfirmationNote
                                                        .trimmingCharacters(in: .whitespacesAndNewlines))
            let fill = FConfirmedFill(sequence: lastSequence + 1, tradedAt: now,
                                      instrumentCode: code, side: side, units: units, price: price,
                                      fee: fee, costBasisRemoved: removedCost,
                                      userConfirmation: confirmation,
                                      instrumentName: actualFillInstrumentName.trimmingCharacters(in: .whitespacesAndNewlines),
                                      tradeIntent: actualFillTradeIntent,
                                      tCycleID: actualFillTradeIntent == .ordinary ? nil :
                                        actualFillTCycleID.trimmingCharacters(in: .whitespacesAndNewlines))
            let writer = FConfirmedLedgerWriter(store: store)
            _ = try await writer.confirmFill(fill, instrumentName: actualFillInstrumentName,
                                             expectedLedgerDigest: candidate.accountDigest, now: now)
            if let candidateShadowJournalStore {
                do {
                    let link = try FCandidateShadowFillLink(confirmedFillID: fill.id,
                                                            linkedAt: now, units: units)
                    guard let confirmedLedger = try await store.readLedgerSnapshot(now: Date()) else {
                        throw FAdvisorLiveError.noRealLedger
                    }
                    try await candidateShadowJournalStore.appendConfirmedExecution(
                        candidateID: candidate.id, link: link, ledgerSnapshot: confirmedLedger)
                    await refreshCandidateShadowSummary(now: now)
                } catch {
                    candidateShadowJournalStatus = "真实成交已入账；成绩单未能关联成交编号 · \(error.localizedDescription)"
                }
            }
            await loadLedger(from: store)
            pendingCandidate = nil
            pendingCandidateScope = nil
            advisorResult = nil
            showingLedgerConfirmation = false
            ledgerWriteStatus = "真实成交已由用户确认并写入账本；正在以更新后的账本重新判断。"
            advisorStatus = ledgerWriteStatus
            let target: String?
            if case let .instrument(instrument) = scope { target = instrument } else { target = nil }
            await runAdvisorQuestion(instrumentCode: target)
        } catch {
            ledgerWriteStatus = "真实账本未更新：\(error.localizedDescription)"
        }
    }

    func prepareManualLedgerFill() {
        guard ledgerState == .available else {
            ledgerWriteStatus = "请先建立或读取真实账本，再登记已完成的成交。"
            return
        }
        manualFillInstrumentCode = ""
        manualFillInstrumentName = ""
        manualFillSide = .buy
        manualFillTradeAt = Date()
        manualFillUnitsText = ""
        manualFillPriceText = ""
        manualFillFeeText = NSDecimalNumber(decimal: FETFTradeFeePolicy.defaultReferencePerFill).stringValue
        manualFillTradeIntent = .ordinary
        manualFillTCycleID = ""
        manualFillConfirmationNote = ""
        manualFillNeedsFinalConfirmation = false
        ledgerWriteStatus = ""
        showingManualLedgerFill = true
    }

    func requestManualLedgerFillConfirmation() {
        guard !writingManualFill else { return }
        manualFillNeedsFinalConfirmation = true
    }

    func confirmManualLedgerFill() {
        guard !writingManualFill else { return }
        manualFillNeedsFinalConfirmation = false
        Task { await writeManualLedgerFill() }
    }

    private func writeManualLedgerFill() async {
        guard ledgerState == .available, let store = ledgerStore,
              manualFillInstrumentCode.utf8.count == 6,
              manualFillInstrumentCode.utf8.allSatisfy({ (48...57).contains($0) }),
              !manualFillInstrumentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let units = Int64(manualFillUnitsText.trimmingCharacters(in: .whitespacesAndNewlines)), units > 0,
              let price = Decimal(string: manualFillPriceText.trimmingCharacters(in: .whitespacesAndNewlines), locale: Locale(identifier: "en_US_POSIX")), price.isFinite, price > 0,
              let fee = Decimal(string: manualFillFeeText.trimmingCharacters(in: .whitespacesAndNewlines), locale: Locale(identifier: "en_US_POSIX")), fee.isFinite, fee >= 0,
              !manualFillConfirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ledgerWriteStatus = "请填写六位证券代码、名称、正份额、真实成交价、实际费用和确认说明。"
            return
        }
        if (manualFillTradeIntent == .tSell && manualFillSide != .sell) ||
            (manualFillTradeIntent == .tBuyback && manualFillSide != .buy) ||
            (manualFillTradeIntent != .ordinary && manualFillTCycleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            ledgerWriteStatus = "做T成交请匹配正确的买卖方向，并填写配对编号。"
            return
        }
        writingManualFill = true
        defer { writingManualFill = false }
        do {
            let now = Date()
            guard manualFillTradeAt <= now,
                  let book = try await store.load(now: now),
                  manualFillTradeAt >= book.updatedAt else {
                ledgerWriteStatus = "成交时间不能早于账本最近事件，也不能晚于现在；请核对录入顺序。"
                return
            }
            let lastSequence = (book.fills.map(\.sequence) + book.cashMovements.map(\.sequence) +
                                (book.feeAdjustments ?? []).map(\.sequence)).max() ?? 0
            guard lastSequence < UInt64.max else { throw FAdvisorLiveError.ledgerChangedDuringAnalysis }
            let removedCost: Decimal?
            if manualFillSide == .sell {
                guard let position = book.positions.first(where: { $0.instrumentCode == manualFillInstrumentCode }) else {
                    throw FLedgerMutationError.missingPosition(manualFillInstrumentCode)
                }
                removedCost = try FAccountingPolicy.costBasisRemoved(unitsSold: units, totalUnits: position.units,
                                                                      totalBookCost: position.bookCost)
            } else { removedCost = nil }
            let note = manualFillConfirmationNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let confirmation = FUserLedgerConfirmation(confirmedAt: now,
                confirmationNote: "用户手动登记已完成的真实成交：" + note)
            let fill = FConfirmedFill(sequence: lastSequence + 1, tradedAt: manualFillTradeAt,
                instrumentCode: manualFillInstrumentCode, side: manualFillSide, units: units, price: price,
                fee: fee, costBasisRemoved: removedCost, userConfirmation: confirmation,
                instrumentName: manualFillInstrumentName.trimmingCharacters(in: .whitespacesAndNewlines),
                tradeIntent: manualFillTradeIntent,
                tCycleID: manualFillTradeIntent == .ordinary ? nil : manualFillTCycleID.trimmingCharacters(in: .whitespacesAndNewlines))
            let writer = FConfirmedLedgerWriter(store: store)
            _ = try await writer.confirmFill(fill, instrumentName: manualFillInstrumentName, now: now)
            await loadLedger(from: store)
            showingManualLedgerFill = false
            advisorResult = nil
            ledgerWriteStatus = "已按用户确认的真实成交更新账本；现金、持仓、Episode和成交流水已重算。"
            advisorStatus = ledgerWriteStatus
            await runAdvisorQuestion(instrumentCode: nil)
        } catch {
            ledgerWriteStatus = "真实成交未写入：\(error.localizedDescription)"
        }
    }

    func saveDeepSeekKey(_ draft: String) {
        do {
            try FAdvisorAIKeychain.save(draft)
            aiKeyStatus = "DeepSeek Key 已安全保存在本机 Keychain"
        } catch {
            aiKeyStatus = error.localizedDescription
        }
    }

    func saveExplicitInvestorPreference(_ key: FInvestorProfileAttributeKey,
                                        value rawValue: String) async {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            investorProfileStatus = "偏好内容不能为空"
            return
        }
        guard !loadingInvestorProfile, !savingInvestorProfile,
              let store = investorProfileStore else {
            investorProfileStatus = "画像尚未就绪，暂不能保存"
            return
        }

        // Invalidate any startup read still in flight so it cannot overwrite
        // this save's success or failure status with the earlier empty profile.
        investorProfileLoadGeneration &+= 1
        let operationGeneration = investorProfileLoadGeneration
        savingInvestorProfile = true
        investorProfileStatus = "正在保存投资者偏好…"
        defer { savingInvestorProfile = false }

        let now = Date()
        var updated = investorProfile
        let prior = updated.attribute(key)?.current(at: now)
        let revision = FInvestorProfileRevision(
            value: .text(String(value.prefix(240))), confidence: 1,
            source: .explicit, updatedAt: now,
            explanation: "用户在设置页明确录入或修正",
            sourceReference: "settings.explicit-preference",
            supersedesRevisionID: prior?.source == .explicit ? prior?.id : nil)
        do {
            _ = try updated.record(revision, for: key, now: now)
            let digest = try await store.save(updated,
                expectedPriorDigest: investorProfileDigest, now: now)
            guard operationGeneration == investorProfileLoadGeneration else { return }
            investorProfileDigest = digest
            investorProfile = updated
            investorProfileStatus = "画像偏好已保存；只有显式录入的内容会作为用户偏好"
        } catch {
            guard operationGeneration == investorProfileLoadGeneration else { return }
            investorProfileStatus = "画像保存失败：\(error.localizedDescription)"
        }
    }

    func clearInvestorProfileAttribute(_ key: FInvestorProfileAttributeKey) async {
        guard !loadingInvestorProfile, !savingInvestorProfile,
              let store = investorProfileStore else {
            investorProfileStatus = "画像尚未就绪，暂不能清除"
            return
        }
        investorProfileLoadGeneration &+= 1
        let operationGeneration = investorProfileLoadGeneration
        savingInvestorProfile = true
        defer { savingInvestorProfile = false }
        let now = Date()
        var updated = investorProfile
        do {
            try updated.clear(key, userConfirmed: true)
            investorProfileDigest = try await store.save(updated,
                expectedPriorDigest: investorProfileDigest, now: now)
            guard operationGeneration == investorProfileLoadGeneration else { return }
            investorProfile = updated
            investorProfileStatus = "已清除该项画像；其他偏好和账本不变"
        } catch {
            guard operationGeneration == investorProfileLoadGeneration else { return }
            investorProfileStatus = "画像清除失败：\(error.localizedDescription)"
        }
    }

    private func loadInvestorProfile() async {
        // Never let a late refresh replace an in-flight save status or its result.
        guard !savingInvestorProfile else { return }
        investorProfileLoadGeneration &+= 1
        let loadGeneration = investorProfileLoadGeneration
        defer { if loadGeneration == investorProfileLoadGeneration { loadingInvestorProfile = false } }
        guard let store = investorProfileStore else {
            loadingInvestorProfile = false
            investorProfileStatus = "本机画像存储不可用"
            return
        }
        loadingInvestorProfile = true
        do {
            let now = Date()
            let loaded = try await store.load(now: now) ?? FInvestorProfile()
            let digest = try await store.currentDigest(now: now)
            guard loadGeneration == investorProfileLoadGeneration else { return }
            investorProfile = loaded
            investorProfileDigest = digest
            investorProfileStatus = loaded.attributes.isEmpty
                ? "尚未录入个人偏好；顾问不会自行猜测"
                : "已读取 \(loaded.attributes.count) 项本机画像偏好"
        } catch {
            guard loadGeneration == investorProfileLoadGeneration else { return }
            investorProfileStatus = "本机画像读取失败：\(error.localizedDescription)"
        }
    }

    private func runAdvisorQuestion(instrumentCode requestedCode: String?) async {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { advisorStatus = FAdvisorLiveError.noQuestion.localizedDescription; return }
        guard ledgerState == .available else { advisorStatus = FAdvisorLiveError.noRealLedger.localizedDescription; return }
        guard let initial = latestLedgerSnapshot else {
            advisorStatus = FAdvisorLiveError.noRealLedger.localizedDescription
            return
        }
        let normalizedQuestion = text.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "").lowercased()
        let numericCodes = text.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
            .filter { $0.count == 6 }
        let mentionedByCode = initial.positions.first { text.contains($0.instrumentCode) }
        let unheldNumericCode = numericCodes.first { number in
            !initial.positions.contains(where: { $0.instrumentCode == number })
        }
        // A six-digit code selects a security advisor even when it is not held.
        // Portfolio requests still capture every real holding and cash below.
        let mentionedByName = initial.instrumentHistories.first { history in
            let name = history.instrumentName.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "　", with: "").lowercased()
            return !name.isEmpty && normalizedQuestion.contains(name)
        }
        let explicitPortfolioPhrases = ["我的持仓", "全部持仓", "所有持仓", "当前持仓", "整体持仓",
                                        "整个组合", "我的组合", "组合今天", "组合需要", "组合怎么样"]
        let broadPortfolioPhrases = ["组合", "持仓", "现金", "资金", "总资产", "总仓位", "配置", "买什么", "怎么配"]
        let explicitPortfolioIntent = explicitPortfolioPhrases.contains(where: normalizedQuestion.contains)
        let hasExplicitSecurityMention = unheldNumericCode != nil || mentionedByCode != nil || mentionedByName != nil
        let portfolioIntent = explicitPortfolioIntent ||
            (!hasExplicitSecurityMention && broadPortfolioPhrases.contains(where: normalizedQuestion.contains))
        // The wording of the question owns the advisor scope. A detail-screen
        // caller may supply its current instrument as a default, but that must
        // not silently turn an explicit portfolio question into a single-name one.
        // A code/name explicitly typed by the user wins over the detail page's
        // ambient instrument. The caller's code is only a fallback when the
        // question itself does not identify a security.
        let explicitQuestionCode = unheldNumericCode ?? mentionedByCode?.instrumentCode ?? mentionedByName?.instrumentCode
        let focusCode = portfolioIntent ? nil : (explicitQuestionCode ?? requestedCode)
        if let focusCode, !Self.isValidSixDigitSecurityCode(focusCode) {
            advisorStatus = FAdvisorLiveError.invalidInstrument.localizedDescription
            return
        }
        let targetCodes = focusCode.map { [$0] } ?? initial.positions.map(\.instrumentCode)
        let scope: FAdvisorEntryScope
        if let focusCode { scope = .instrument(focusCode) } else { scope = .portfolio }
        isAskingAdvisor = true
        advisorStatus = focusCode == nil
            ? "正在读取真实持仓并刷新组合行情；仅使用本机已有NAS研究摘要，不等待NAS…"
            : "正在读取真实持仓并刷新目标证券行情；仅使用本机已有NAS研究摘要，不等待NAS…"
        defer { isAskingAdvisor = false }

        do {
            let apiKey = try FAdvisorAIKeychain.read()
            refreshNewsFeedInBackground(for: targetCodes)
            await refreshMarketData(for: targetCodes)
            let quotes = Dictionary(uniqueKeysWithValues: targetCodes.compactMap { code in
                marketDataByCode[code].map { (code, $0) }
            })
            var newsByCode: [String: FNewsFeed] = [:]
            var newsFailureByCode: [String: String] = [:]
            let newsCheckedAt = Date()
            let marketNewsFeed = cachedNewsFeed?.recent(at: newsCheckedAt)
            if let feed = marketNewsFeed {
                for code in targetCodes {
                    let matched = feed.articlesAssociated(with: code)
                    if !matched.isEmpty {
                        newsByCode[code] = FNewsFeed(provider: feed.provider,
                                                     fetchedAt: feed.fetchedAt,
                                                     articles: matched)
                    } else {
                        newsFailureByCode[code] = feed.articles.isEmpty
                            ? "最近24小时没有通过校验的市场快讯"
                            : "取得市场快讯，但来源未提供与该证券代码的直接关联"
                    }
                }
            } else {
                for code in targetCodes {
                    newsFailureByCode[code] = "没有新鲜的已缓存新闻；本轮不等待新闻源"
                }
            }
            if let marketNewsFeed {
                newsStatus = newsFeedStatus(marketNewsFeed, targetCodes: targetCodes)
            } else if newsRefreshTask != nil {
                newsStatus = "新闻后台更新中；本轮分析不等待新闻源"
            } else {
                newsStatus = "新闻缓存暂不可用；本轮不等待新闻源"
            }
            let researchBaseAddress = UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
            let researchGeneration = synchronizeNASDataSource(baseAddress: researchBaseAddress)
            let researchCheckedAt = Date()
            let usableResearchEntries: [(String, FDecisionResearchEvidence)] = targetCodes.compactMap { code in
                guard let cached = nasResearchEvidenceByCode[code],
                      cached.isUsableForAI(contextCreatedAt: researchCheckedAt, now: researchCheckedAt) else {
                    return nil
                }
                return (code, cached)
            }
            var researchByCode = Dictionary(uniqueKeysWithValues: usableResearchEntries)
            var researchFailureByCode: [String: String] = [:]
            for code in targetCodes where researchByCode[code] == nil {
                researchFailureByCode[code] = "历史Quant研究摘要暂不可用。"
            }
            if !researchByCode.isEmpty {
                nasResearchStatus = targetCodes.compactMap { code in
                    guard let evidence = researchByCode[code] else { return nil }
                    return researchSummaryStatus(code: code, evidence: evidence, now: researchCheckedAt)
                }.joined(separator: "；")
            } else {
                nasResearchStatus = "历史Quant研究摘要暂不可用。顾问继续分析，不等待NAS。"
            }
            Task {
                await refreshNASResearchEvidence(for: targetCodes,
                                                 baseAddress: researchBaseAddress,
                                                 expectedGeneration: researchGeneration)
            }

            guard let ledgerStore else { throw FAdvisorLiveError.noRealLedger }
            let contextCaptureTime = Date()
            let currentResearchBaseAddress = UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
            let currentResearchGeneration = synchronizeNASDataSource(baseAddress: currentResearchBaseAddress)
            if currentResearchGeneration != researchGeneration {
                researchByCode.removeAll()
                researchFailureByCode = Dictionary(uniqueKeysWithValues:
                    targetCodes.map { ($0, "历史Quant研究摘要暂不可用。NAS 地址已更改，正在重新获取。") })
                nasResearchStatus = "NAS 地址已更改；旧地址研究摘要已作废，顾问继续分析。"
            }
            guard let freshLedger = try await ledgerStore.readLedgerSnapshot(now: contextCaptureTime),
                  freshLedger.ledgerDigest == initial.ledgerDigest else {
                throw FAdvisorLiveError.ledgerChangedDuringAnalysis
            }
            latestLedgerSnapshot = freshLedger
            cashBalance = freshLedger.cashBalance
            instrumentHistories = freshLedger.instrumentHistories
            cashFlow = freshLedger.cashFlow
            holdings = freshLedger.positions.map {
                FHomeHolding(instrumentCode: $0.instrumentCode, name: $0.name,
                             units: $0.units, bookCost: $0.bookCost,
                             brokerDisplayCostPerUnit: $0.brokerDisplayCostPerUnit,
                             brokerDisplayCostUpdatedAt: $0.brokerDisplayCostUpdatedAt)
            }

            let sessionStatus = FMainlandTradingCalendar.status(at: contextCaptureTime)
            var observations: [FContextObservation] = []
            var evidence: [FDecisionResearchEvidence] = []
            var quoteStatuses: [String] = []
            var researchStatuses: [String] = []
            for code in targetCodes {
                if let regime = securityRegimeByCode[code], regime.regime != .dataUnreliable,
                   Self.isMarketRegimeDataFresh(regime, at: contextCaptureTime),
                   let snapshot = dailyKlineByCode[code],
                   snapshot.fetchedAt <= contextCaptureTime,
                   contextCaptureTime.timeIntervalSince(snapshot.fetchedAt) <= FContextDataClass.quantState.maximumAge {
                    let factorSummary = regime.factors.map { factor -> String in
                        guard factor.available, let value = factor.value else { return "\(factor.key)=Unavailable" }
                        return "\(factor.key)=\(value)"
                    }.joined(separator: ",")
                    let dataAsOf = regime.dataAsOf.map { ISO8601DateFormatter().string(from: $0) } ?? "Unavailable"
                    let reference = "regime=\(regime.regime.rawValue); risk=\(regime.riskLevel.rawValue); confidence=\(regime.confidence); dataAsOf=\(dataAsOf); source=\(snapshot.source); factors=\(factorSummary)"
                    observations.append(FContextObservation(
                        dataClass: .quantState, subject: code, source: "FCore Market Regime Engine",
                        reference: String(reference.prefix(4_000)), observedAt: snapshot.fetchedAt,
                        capturedAt: contextCaptureTime, decimalValue: Decimal(regime.confidence)))
                } else {
                    let localStatus = securityRegimeStatusByCode[code] ?? "尚未计算证券自身 Regime"
                    observations.append(FContextObservation(
                        dataClass: .quantState, subject: code, source: "FCore Market Regime Engine",
                        observedAt: nil, capturedAt: contextCaptureTime, decimalValue: nil,
                        unavailableReason: "证券自身 Regime 不可用（\(localStatus)）；Local Quant 策略资格不可用，资产变化候选会被硬门槛阻止。"))
                }

                let localQuantSource = "FCore Local Quant Engine · observation only"
                if let quote = quotes[code] ?? marketDataByCode[code] {
                    let iopv = marketReferenceByCode[code].flatMap { reference -> FIOPVObservation? in
                        guard reference.securityCode == code, reference.hasFreshIOPV(at: contextCaptureTime),
                              reference.observedAt <= quote.quoteTimestamp,
                              let value = reference.iopv else { return nil }
                        return try? FIOPVObservation(securityCode: code, value: value,
                            observedAt: reference.observedAt, fetchedAt: reference.fetchedAt,
                            source: reference.source, quality: .complete)
                    }
                    if let reference = marketReferenceByCode[code],
                       reference.securityCode == code,
                       reference.source == FMarketQuoteTrustPolicy.tencentReferenceSource,
                       reference.hasFreshIOPV(at: contextCaptureTime),
                       reference.observedAt <= quote.quoteTimestamp,
                       let iopvValue = reference.iopv,
                       let quotePrice = quote.latestPrice,
                       let premium = fIopvPremiumPercent(price: quotePrice, iopv: iopvValue) {
                        observations.append(FContextObservation(
                            dataClass: .iopv, subject: code, source: reference.source,
                            reference: "method=(同一报价时点ETF价格/不晚于报价时点的IOPV-1)*100;unit=percent",
                            observedAt: reference.observedAt, capturedAt: contextCaptureTime,
                            decimalValue: premium))
                    }
                    let assessment = FLocalQuantEngine.evaluate(
                        quote: quote, dailyHistory: dailyKlineByCode[code],
                        regime: securityRegimeByCode[code], iopv: iopv,
                        sessionStatus: sessionStatus,
                        mappedBenchmarkRegime: FMarketIndexSecurityMappingRegistry.mapping(for: code)
                            .flatMap { marketIndexRegimesByCode[$0.indexCode] },
                        mappedBenchmarkFetchedAt: FMarketIndexSecurityMappingRegistry.mapping(for: code)
                            .flatMap { marketIndexRegimeFetchedAtByCode[$0.indexCode] },
                        mappedBenchmarkIndexCode: FMarketIndexSecurityMappingRegistry.mapping(for: code)?.indexCode,
                        now: contextCaptureTime)
                    let factorFacts = assessment.factors.map { factor in
                        let value = factor.value.map { String($0) } ?? "Unavailable"
                        let score = factor.directionalScore.map { String($0) } ?? "Unavailable"
                        let observedAt = factor.observedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "Unavailable"
                        let supportingDataAsOf = factor.supportingDataAsOf.map {
                            ISO8601DateFormatter().string(from: $0)
                        } ?? "Unavailable"
                        let source = factor.source ?? "Unavailable"
                        let reason = factor.unavailableReason.map { ";reason=\($0)" } ?? ""
                        let quality = factor.qualityNote.map { ";quality=\($0)" } ?? ""
                        return "\(factor.kind.rawValue)=\(value);directionalScore=\(score);observedAt=\(observedAt);supportingDataAsOf=\(supportingDataAsOf);source=\(source)\(quality)\(reason)"
                    }.joined(separator: "|")
                    let strategyFacts = assessment.strategies.map {
                        "\($0.strategy.rawValue)=\($0.readiness.rawValue);qualified=\($0.qualified);reason=\($0.reasonCode)"
                    }.joined(separator: "|")
                    let quoteTimestamp = assessment.quoteTimestamp.map {
                        ISO8601DateFormatter().string(from: $0)
                    } ?? "Unavailable"
                    let regimeName = assessment.marketRegime?.rawValue ?? "Unavailable"
                    let riskName = assessment.riskLevel.map { String($0.rawValue) } ?? "Unavailable"
                    let benchmarkCode = assessment.benchmarkIndexCode ?? "NotMapped"
                    let benchmarkRegime = assessment.benchmarkRegime?.rawValue ?? "Unavailable"
                    let benchmarkRisk = assessment.benchmarkRiskLevel.map { String($0.rawValue) } ?? "Unavailable"
                    let availableFactorCount = assessment.factors.filter(\.isAvailable).count
                    let benchmarkReason = assessment.benchmarkUnavailableReason ?? "none"
                    let reference = "version=observation-only-v1;quoteFreshness=\(assessment.quoteFreshness.rawValue);quoteTimestamp=\(quoteTimestamp);regime=\(regimeName);risk=\(riskName);benchmarkIndex=\(benchmarkCode);benchmarkRegime=\(benchmarkRegime);benchmarkRisk=\(benchmarkRisk);benchmarkReason=\(benchmarkReason);disposition=\(assessment.disposition.rawValue);candidatePlanGenerated=\(assessment.candidatePlanGenerated);availableFactorCount=\(availableFactorCount);reasonCodes=\(assessment.reasonCodes.joined(separator: ","));factors=[\(factorFacts)];strategies=[\(strategyFacts)]"
                    observations.append(FContextObservation(
                        dataClass: .quantState, subject: "local-quant:\(code)",
                        source: localQuantSource, reference: String(reference.prefix(4_000)),
                        observedAt: assessment.evaluatedAt, capturedAt: contextCaptureTime,
                        decimalValue: Decimal(availableFactorCount)))
                } else {
                    observations.append(FContextObservation(
                        dataClass: .quantState, subject: "local-quant:\(code)", source: localQuantSource,
                        observedAt: nil, capturedAt: contextCaptureTime, decimalValue: nil,
                        unavailableReason: "本次请求没有实时分钟快照，无法形成Local Quant因子观察。"))
                }
            }
            let freshIndexRegimeCodes = marketIndexRegimesByCode.keys.sorted().filter { code in
                guard let fetchedAt = marketIndexRegimeFetchedAtByCode[code],
                      let regime = marketIndexRegimesByCode[code], regime.regime != .dataUnreliable,
                      let dataAsOf = regime.dataAsOf, dataAsOf <= fetchedAt,
                      Self.isMarketRegimeDataFresh(regime, at: contextCaptureTime) else { return false }
                return fetchedAt <= contextCaptureTime &&
                    contextCaptureTime.timeIntervalSince(fetchedAt) <= FContextDataClass.quantState.maximumAge
            }
            let freshIndexRegimeSet = Set(freshIndexRegimeCodes)
            for code in freshIndexRegimeCodes {
                guard let regime = marketIndexRegimesByCode[code],
                      let fetchedAt = marketIndexRegimeFetchedAtByCode[code] else { continue }
                let dataAsOf = regime.dataAsOf.map { ISO8601DateFormatter().string(from: $0) } ?? "Unavailable"
                let reference = "indexCode=\(code); regime=\(regime.regime.rawValue); risk=\(regime.riskLevel.rawValue); confidence=\(regime.confidence); dataAsOf=\(dataAsOf); securityMapping=Unavailable"
                observations.append(FContextObservation(
                    dataClass: .quantState, subject: "index:\(code)", source: "F NAS index daily history + FCore Market Regime Engine",
                    reference: reference, observedAt: fetchedAt, capturedAt: contextCaptureTime,
                    decimalValue: Decimal(regime.confidence)))
            }
            for code in FMarketIndexHTTPClient.indexCodes where !freshIndexRegimeSet.contains(code) {
                observations.append(FContextObservation(
                    dataClass: .quantState, subject: "index:\(code)",
                    source: "F NAS index daily history + FCore Market Regime Engine",
                    observedAt: nil, capturedAt: contextCaptureTime, decimalValue: nil,
                    unavailableReason: "\(marketIndexRegimeStatusByCode[code] ?? "尚未读取该指数Regime")；不等待 NAS，也不推断该指数与持仓证券的对应关系。"))
            }
            for code in targetCodes {
                guard let mapping = FMarketIndexSecurityMappingRegistry.mapping(for: code) else { continue }
                let mappedRegime = marketIndexRegimesByCode[mapping.indexCode]
                let fetchedAt = marketIndexRegimeFetchedAtByCode[mapping.indexCode]
                if let regime = mappedRegime, regime.regime != .dataUnreliable,
                   Self.isMarketRegimeDataFresh(regime, at: contextCaptureTime),
                   let dataAsOf = regime.dataAsOf, let fetchedAt,
                   dataAsOf <= fetchedAt, fetchedAt <= contextCaptureTime,
                   contextCaptureTime.timeIntervalSince(fetchedAt) <= FContextDataClass.quantState.maximumAge {
                    let dataAsOf = regime.dataAsOf.map { ISO8601DateFormatter().string(from: $0) } ?? "Unavailable"
                    let reference = "indexCode=\(mapping.indexCode);indexName=\(mapping.indexName);mappingSource=\(mapping.sourceURL);mapping=issuer_benchmark;contextRole=benchmark_only;regime=\(regime.regime.rawValue);risk=\(regime.riskLevel.rawValue);confidence=\(regime.confidence);dataAsOf=\(dataAsOf);not_strategy_qualification=true"
                    observations.append(FContextObservation(
                        dataClass: .quantState, subject: "mapped-index:\(code)",
                        source: "F Verified Issuer Index Mapping + NAS Daily Regime",
                        reference: reference, observedAt: fetchedAt, capturedAt: contextCaptureTime,
                        decimalValue: Decimal(regime.confidence)))
                } else {
                    observations.append(FContextObservation(
                        dataClass: .quantState, subject: "mapped-index:\(code)",
                        source: "F Verified Issuer Index Mapping + NAS Daily Regime",
                        observedAt: nil, capturedAt: contextCaptureTime, decimalValue: nil,
                        unavailableReason: "\(mapping.indexName)已由基金发行方确认是该ETF基准，但对应新鲜历史Regime暂不可用；本记录不代替ETF自身行情/IOPV/溢价/流动性，也不构成策略资格。"))
                }
            }
            for code in targetCodes {
                observations.append(FContextObservation(
                    dataClass: .quantState, subject: "risk-gate:\(code)", source: "F App Local Quant / Risk Gate",
                    observedAt: nil, capturedAt: contextCaptureTime, decimalValue: nil,
                    unavailableReason: "Local Quant因子观察已接入，但本地验证策略参数包及资格尚未接入；BUY/SELL/T_BUY/T_SELL候选当前会被硬门槛阻止。其余候选仍会经过确定性 Risk Guard 与 AI Guard。"))
            }
            if let feed = marketNewsFeed, !feed.articles.isEmpty,
               let latestPublishedAt = feed.articles.map(\.publishedAt).max() {
                let payload = FNewsEvidencePayload(
                    note: "同花顺财经7×24市场快讯公开网页接口；这是市场背景标题/摘要，不代表已核实完整正文。只有条目明确列出证券代码时才视为证券直接关联。不得仅凭市场标题推断某只证券的因果影响；引用时给出媒体、时间与原文链接。",
                    fetchedAt: feed.fetchedAt, articles: feed.articles)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let payloadReference = (try? encoder.encode(payload)).flatMap {
                    String(data: $0, encoding: .utf8)
                }
                observations.append(FContextObservation(
                    dataClass: .news, subject: "CN/global market headlines", source: feed.provider,
                    reference: payloadReference, observedAt: latestPublishedAt,
                    capturedAt: min(contextCaptureTime, feed.fetchedAt),
                    decimalValue: Decimal(feed.articles.count)))
            }
            for code in targetCodes {
                let cachedQuote = quotes[code]
                if let reference = marketReferenceByCode[code],
                   reference.hasFreshReference(at: contextCaptureTime) {
                    observations.append(FContextObservation(
                        dataClass: .previousClose, subject: code, source: reference.source,
                        reference: "前收=\(reference.previousClose);时点=\(reference.observedAt.ISO8601Format())",
                        observedAt: reference.observedAt, capturedAt: contextCaptureTime,
                        decimalValue: reference.previousClose))
                }
                let quoteMetadata = cachedQuote.map { quote in
                    FQuoteTemporalMetadata(
                        quoteTimestamp: quote.quoteTimestamp, fetchedAt: quote.fetchedAt,
                        source: quote.source, timestampTrust: .verifiedExchangeTimestamp,
                        marketSessionStatus: sessionStatus)
                }
                if let quote = cachedQuote, let price = quote.latestPrice,
                   let quoteMetadata, quoteMetadata.freshness(at: contextCaptureTime) == .fresh {
                    observations.append(FContextObservation(
                        dataClass: .quote, subject: code, source: quote.source,
                        reference: quote.source, observedAt: quote.quoteTimestamp,
                        capturedAt: min(contextCaptureTime, quote.fetchedAt), decimalValue: price,
                        quoteTemporalMetadata: quoteMetadata))
                    quoteStatuses.append("\(code) ¥\(price) · \(quote.source) · 行情时 \(quote.quoteTimestamp.formatted(date: .abbreviated, time: .standard)) · 获取于 \(quote.fetchedAt.formatted(date: .abbreviated, time: .standard)) · \(sessionStatus.displayName)")
                } else {
                    let unavailableReason: String
                    if let quote = cachedQuote {
                        unavailableReason = "缓存行情已过期或时点未验证 · \(quote.source) · 行情时间 \(quote.quoteTimestamp.formatted(date: .abbreviated, time: .standard))"
                    } else {
                        unavailableReason = marketRefreshStateByCode[code] ?? "行情未返回有效分钟点"
                    }
                    observations.append(FContextObservation(
                        dataClass: .quote, subject: code, source: FTencentMinuteParser.source,
                        observedAt: nil, capturedAt: contextCaptureTime, decimalValue: nil,
                        unavailableReason: unavailableReason,
                        quoteTemporalMetadata: FQuoteTemporalMetadata(
                            quoteTimestamp: nil, fetchedAt: nil, source: FTencentMinuteParser.source,
                            timestampTrust: .unavailable, marketSessionStatus: sessionStatus)))
                    quoteStatuses.append("\(code) 行情不可用 · \(unavailableReason)")
                }
                if let feed = newsByCode[code], let latestPublishedAt = feed.articles.map(\.publishedAt).max() {
                    let payload = FNewsEvidencePayload(
                        note: "同花顺财经7×24市场快讯；该条明确关联此证券代码。只提供标题/摘要，不代表已核实完整正文；引用时给出媒体、时间和原文链接。",
                        fetchedAt: feed.fetchedAt, articles: feed.articles)
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let payloadReference = (try? encoder.encode(payload)).flatMap {
                        String(data: $0, encoding: .utf8)
                    }
                    observations.append(FContextObservation(
                        dataClass: .news, subject: code, source: feed.provider,
                        reference: payloadReference, observedAt: latestPublishedAt,
                        capturedAt: min(contextCaptureTime, feed.fetchedAt),
                        decimalValue: Decimal(feed.articles.count)))
                } else {
                    observations.append(FContextObservation(
                        dataClass: .news, subject: code, source: FNewsClient.providerName,
                        observedAt: nil, capturedAt: contextCaptureTime, decimalValue: nil,
                        unavailableReason: newsFailureByCode[code] ?? "没有可用的证券相关新闻"))
                }
                if let research = researchByCode[code] {
                    try research.validate(contextCreatedAt: contextCaptureTime)
                    evidence.append(research)
                    if research.isUsableForAI(contextCreatedAt: contextCaptureTime, now: contextCaptureTime) {
                        observations.append(FContextObservation(
                            dataClass: .nasResearch, subject: code, source: "F NAS Research Evidence API",
                            reference: research.id, observedAt: research.envelope.observedAt,
                            capturedAt: research.capturedAt,
                            decimalValue: Decimal(research.envelope.qualifiedIndependentDays)))
                    } else {
                        observations.append(FContextObservation(
                            dataClass: .nasResearch, subject: code, source: "F NAS Research Evidence API",
                            reference: research.id, observedAt: nil, capturedAt: contextCaptureTime,
                            decimalValue: nil, unavailableReason: "返回研究未达到 AI 质量或样本门槛"))
                    }
                    researchStatuses.append("\(code) · \(research.envelope.compactSummary)")
                } else {
                    let failure = researchFailureByCode[code] ?? "NAS Research Evidence 不可用"
                    observations.append(FContextObservation(
                        dataClass: .nasResearch, subject: code, source: "F NAS Research Evidence API",
                        observedAt: nil, capturedAt: contextCaptureTime, decimalValue: nil,
                        unavailableReason: failure))
                    researchStatuses.append("\(code) · 研究不可用：\(failure)")
                }
            }
            let context = FDecisionContext(snapshot: freshLedger, observations: observations,
                                           researchEvidence: evidence)
            try context.validate(now: contextCaptureTime)
            guard let decisionMemoryStore, let investorProfileStore, let decisionContextStore else {
                throw FAdvisorLiveError.noRealLedger
            }
            let request = try await FAdvisorRequestAssembler(
                profileStore: investorProfileStore, memoryStore: decisionMemoryStore
            ).assemble(question: text, scope: scope, decisionContext: context, now: contextCaptureTime)
            let provider = FDeepSeekCandidateProvider(apiKey: apiKey)
            let modelAssessment = try await FAdvisorDecisionPipeline(model: provider).assess(
                request: request, context: context, now: contextCaptureTime)
            let assessment = modelAssessment
            let completedAt = Date()
            guard let ledgerAfterModel = try await ledgerStore.readLedgerSnapshot(now: completedAt),
                  ledgerAfterModel.ledgerDigest == freshLedger.ledgerDigest else {
                throw FAdvisorLiveError.ledgerChangedDuringAnalysis
            }
            guard let narrative = await provider.takeNarrative(for: assessment.candidate.id) else {
                throw FAdvisorLiveError.invalidAIResponse
            }
            let contextDigest = try await decisionContextStore.currentDigest(now: completedAt)
            _ = try await decisionContextStore.append(context, expectedPriorDigest: contextDigest,
                                                       now: completedAt)
            let memory = try FDecisionMemory(context: context, candidate: assessment.candidate,
                                              recommendation: narrative.conclusion,
                                              rationale: narrative.basis,
                                              conditions: narrative.invalidationConditions,
                                              advisorRequest: request)
            if let candidateShadowJournalStore {
                do {
                    let shadowSnapshot = try FCandidateShadowSnapshot(
                        candidate: assessment.candidate, context: context,
                        advisorConclusion: narrative.conclusion,
                        invalidationConditions: narrative.invalidationConditions,
                        reasonCodes: assessment.guardResult.findings.map { String(describing: $0) },
                        finalAction: assessment.guardResult.allowedForReview
                            ? assessment.candidate.action : .wait,
                        guardAllowed: assessment.guardResult.allowedForReview)
                    try await candidateShadowJournalStore.append(shadowSnapshot)
                    candidateShadowJournalStatus = "建议影子记录已保存 · 不影响真实账本"
                    await refreshCandidateShadowSummary(now: completedAt)
                } catch {
                    candidateShadowJournalStatus = "建议已生成，但影子成绩单保存失败 · \(error.localizedDescription)"
                }
            }
            let memoryDigest = try await decisionMemoryStore.currentDigest(now: completedAt)
            _ = try await decisionMemoryStore.append(memory, expectedPriorDigest: memoryDigest,
                                                      now: completedAt)
            let holdingSummary = freshLedger.positions.filter { targetCodes.contains($0.instrumentCode) }
                .map { "\($0.instrumentCode) \($0.name) · \($0.units) 份 · 账面成本总额 ¥\(NSDecimalNumber(decimal: $0.bookCost))" }
                .joined(separator: "\n")
            advisorResult = FAdvisorVerticalSliceResult(assessment: assessment, narrative: narrative,
                                                        scope: scope,
                                                        generatedAt: completedAt,
                                                        ledgerCapturedAt: freshLedger.capturedAt,
                                                        holdingSummary: holdingSummary,
                                                        cashBalance: freshLedger.cashBalance,
                                                        quoteStatus: quoteStatuses.joined(separator: "\n"),
                                                        researchStatus: researchStatuses.joined(separator: "\n"))
            advisorStatus = "已完成 DecisionContext → Risk Guard / AI Guard · 候选计划仅供审阅"
        } catch {
            advisorStatus = error.localizedDescription
        }
    }

    var defaultAdvisorInstrumentCode: String? {
        latestLedgerSnapshot?.positions.first?.instrumentCode
    }

    func selectInstrument(_ code: String?) {
        selectedInstrumentCode = code
    }

    func lookupInstrumentName(code: String) async -> String? {
        try? await FQuoteHTTPClient.fetchInstrumentName(code: code)
    }

    func loadArchivedIntraday(for code: String) async {
        let day = selectedHistoryDate
        let baseAddress = UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
        let generation = synchronizeNASDataSource(baseAddress: baseAddress)
        archiveRefreshStateByCode[code] = "正在查询 NAS 历史分时…"
        do {
            let archive = try await FNASHistoricalMinuteClient.fetch(
                baseAddress: baseAddress, securityCode: code, tradingDate: day)
            let currentBaseAddress = UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
            guard synchronizeNASDataSource(baseAddress: currentBaseAddress) == generation else { return }
            guard Calendar.current.isDate(selectedHistoryDate, inSameDayAs: day) else { return }
            if let current = archivedIntradayByCode[code],
               current.tradingDate == archive.tradingDate,
               current.fetchedAt > archive.fetchedAt {
                archiveRefreshStateByCode[code] = "较旧的 NAS 响应已忽略；保留更新归档。"
                return
            }
            archivedIntradayByCode[code] = archive
            archiveRefreshStateByCode[code] = archive.samples.isEmpty
                ? "\(archive.tradingDate) · NAS 无归档分钟点（\(archive.coverageStatus)）"
                : "\(archive.tradingDate) · \(archive.coverageSummary) · 来源 \(archive.sourceSummary)"
        } catch {
            guard synchronizeNASDataSource(
                baseAddress: UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
            ) == generation else { return }
            archiveRefreshStateByCode[code] = "NAS 历史分时不可用 · \(error.localizedDescription)"
            archivedIntradayByCode[code] = nil
        }
    }

    func refreshDailyKline(for code: String) async {
        dailyKlineStateByCode[code] = "正在由 iPhone 直连行情源读取历史日 K…"
        do {
            let snapshot = try await FQuoteHTTPClient.fetchDailyKline(code: code, count: 320)
            if let current = dailyKlineByCode[code], current.fetchedAt > snapshot.fetchedAt {
                dailyKlineStateByCode[code] = "较旧的行情响应已忽略；保留更新日 K。"
                return
            }
            dailyKlineByCode[code] = snapshot
            let evaluatedAt = Date()
            let shanghai = TimeZone(identifier: "Asia/Shanghai") ?? .current
            var tradingCalendar = Calendar(identifier: .gregorian)
            tradingCalendar.timeZone = shanghai
            let currentTradingDayStart = tradingCalendar.startOfDay(for: evaluatedAt)
            // The daily provider does not label an in-progress session bar as
            // partial. Exclude today's row from regime inference until the next
            // local trading day; the chart still keeps the original snapshot.
            let completedBars = snapshot.bars.filter { $0.tradingDate < currentTradingDayStart }
            let regimeBars = completedBars.map { bar in
                FMarketRegimeBar(
                    timestamp: bar.tradingDate,
                    close: NSDecimalNumber(decimal: bar.close).doubleValue,
                    open: NSDecimalNumber(decimal: bar.open).doubleValue,
                    high: NSDecimalNumber(decimal: bar.high).doubleValue,
                    low: NSDecimalNumber(decimal: bar.low).doubleValue,
                    volume: NSDecimalNumber(decimal: bar.volume).doubleValue
                )
            }
            let previousMemory = regimeMemoryByCode[code] ?? loadRegimeMemory(for: code)
            let regime = FMarketRegimeEngine.evaluate(
                FMarketRegimeInput(
                    market: "security:\(code)", securityCode: code, asOf: evaluatedAt,
                    sourceUpdatedAt: snapshot.fetchedAt, source: snapshot.source, bars: regimeBars
                ), previous: previousMemory,
                now: evaluatedAt
            )
            if regime.regime != .dataUnreliable {
                regimeMemoryByCode[code] = regime.memory
                if let data = try? JSONEncoder().encode(regime.memory) {
                    UserDefaults.standard.set(data, forKey: regimeMemoryKey(for: code))
                }
            }
            securityRegimeByCode[code] = regime
            let availableFactors = regime.factors.filter(\.available).count
            let dataTime = regime.dataAsOf?.formatted(date: .numeric, time: .omitted) ?? "不可用"
            securityRegimeStatusByCode[code] =
                "证券自身：\(regime.regime.displayName) · \(regime.riskLevel.displayName) · \(availableFactors)/\(regime.factors.count) 个因子可用 · 日K至 \(dataTime)"
            let count = snapshot.bars.count
            let missing = [5, 10, 20, 60, 250].filter { count < $0 }
            dailyKlineStateByCode[code] = "\(count) 个真实交易日 · \(snapshot.adjustment) · \(snapshot.source) · iPhone直连 · 获取于 \(snapshot.fetchedAt.formatted(date: .omitted, time: .standard))" +
                (missing.isEmpty ? "" : " · MA\(missing.map { String($0) }.joined(separator: "/"))样本不足")
        } catch {
            if dailyKlineByCode[code] != nil {
                dailyKlineStateByCode[code] = "日 K 更新失败，保留本机缓存 · \(error.localizedDescription)"
            } else {
                dailyKlineStateByCode[code] = "手机直连日 K 不可用 · \(error.localizedDescription)"
                securityRegimeByCode[code] = nil
                securityRegimeStatusByCode[code] = "证券自身状态不可用 · 缺少可信日K"
            }
        }
    }

    private func researchSummaryStatus(code: String, evidence: FDecisionResearchEvidence, now: Date) -> String {
        let envelope = evidence.envelope
        let ageHours = max(0, Int(now.timeIntervalSince(envelope.observedAt) / 3_600))
        let dataRange = envelope.dataRange.map { "\($0.start)→\($0.end)" } ?? "Unavailable"
        let strategyVersion = envelope.strategyVersion ?? "Unavailable"
        return "\(code) · researchGeneratedAt \(envelope.generatedAt) · dataRange \(dataRange) · sampleCount \(envelope.qualifiedIndependentDays)独立交易日 · strategyVersion \(strategyVersion) · methodologyVersion \(envelope.methodologyVersion) · freshness 有效/\(ageHours)小时前"
    }

    private func regimeMemoryKey(for code: String) -> String {
        let endpoint = nasDataSourceKey ?? "unconfigured"
        let namespace = SHA256.hash(data: Data(endpoint.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return "guanpan.f.regime.memory.v2.\(namespace).\(code)"
    }

    private static func isMarketRegimeDataFresh(_ assessment: FMarketRegimeAssessment, at now: Date) -> Bool {
        guard let dataAsOf = assessment.dataAsOf,
              dataAsOf.timeIntervalSince1970.isFinite,
              dataAsOf <= now else { return false }
        return now.timeIntervalSince(dataAsOf) <= 5 * 86_400
    }

    private func loadRegimeMemory(for code: String) -> FMarketRegimeMemory? {
        guard let data = UserDefaults.standard.data(forKey: regimeMemoryKey(for: code)),
              let memory = try? JSONDecoder().decode(FMarketRegimeMemory.self, from: data) else {
            return nil
        }
        regimeMemoryByCode[code] = memory
        return memory
    }

    private func synchronizeNASDataSource(baseAddress: String) -> UInt64 {
        let endpointKey = nasResearchEndpointKey(for: baseAddress)
        guard endpointKey != nasDataSourceKey else { return nasDataGeneration }
        nasDataSourceKey = endpointKey
        nasDataGeneration &+= 1
        nasResearchEvidenceByCode.removeAll()
        refreshingNASResearchCodes.removeAll()
        var archiveCodes = Set(archiveRefreshStateByCode.keys)
        archiveCodes.formUnion(archivedIntradayByCode.keys)
        if let selectedInstrumentCode { archiveCodes.insert(selectedInstrumentCode) }
        archivedIntradayByCode.removeAll()
        for code in archiveCodes {
            archiveRefreshStateByCode[code] = "NAS 地址已更改；请重新读取历史分钟。"
        }
        // Daily K-lines and security-level regimes are sourced directly by the
        // iPhone and remain usable when the optional NAS endpoint changes.
        marketIndexRegimesByCode.removeAll()
        marketIndexRegimeFetchedAtByCode.removeAll()
        marketIndexRegimeStatusByCode = FMarketIndexHTTPClient.indexCodes.reduce(into: [:]) {
            $0[$1] = endpointKey == nil
                ? "历史 Regime 不可用 · 未配置有效 NAS 地址"
                : "NAS 地址已更改；需要重新读取指数历史"
        }
        regimeMemoryByCode.removeAll()
        nasResearchStatus = endpointKey == nil
            ? "历史Quant研究摘要暂不可用。未配置有效 NAS 地址。"
            : "NAS 地址已更改；历史研究摘要与历史状态正在刷新。"
        return nasDataGeneration
    }

    func nasAddressDidChange(_ baseAddress: String) {
        let previousKey = nasDataSourceKey
        _ = synchronizeNASDataSource(baseAddress: baseAddress)
        guard previousKey != nasDataSourceKey else { return }
        nasConnectionStatus = FNASReadinessClient.validateAddress(baseAddress) == nil
            ? "NAS 地址无效；历史数据暂不可用。"
            : "NAS 地址已更改；请保存并测试连接。"
    }

    private func nasResearchEndpointKey(for baseAddress: String) -> String? {
        FNASReadinessClient.validateAddress(baseAddress).flatMap { url in
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            components.scheme = components.scheme?.lowercased()
            components.host = components.host?.lowercased()
            components.path = ""
            components.query = nil
            components.fragment = nil
            return components.string
        }
    }

    private func refreshNASResearchEvidence(for codes: [String], baseAddress: String,
                                            expectedGeneration: UInt64) async {
        let currentBaseAddress = UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
        guard synchronizeNASDataSource(baseAddress: currentBaseAddress) == expectedGeneration,
              nasResearchEndpointKey(for: baseAddress) == nasDataSourceKey else { return }
        guard FNASReadinessClient.validateAddress(baseAddress) != nil else {
            nasResearchStatus = "历史Quant研究摘要暂不可用。未配置NAS；顾问继续分析。"
            return
        }
        let pending = codes.filter { refreshingNASResearchCodes[$0] != expectedGeneration }
        guard !pending.isEmpty else { return }
        for code in pending { refreshingNASResearchCodes[code] = expectedGeneration }
        await withTaskGroup(of: (String, FDecisionResearchEvidence?).self) { group in
            for code in pending {
                group.addTask {
                    do {
                        let evidence = try await FNASResearchClient.fetchEvidence(
                            baseAddress: baseAddress, securityCode: code)
                        return (code, evidence)
                    } catch {
                        return (code, nil)
                    }
                }
            }
            for await (code, evidence) in group {
                if refreshingNASResearchCodes[code] == expectedGeneration {
                    refreshingNASResearchCodes.removeValue(forKey: code)
                }
                guard synchronizeNASDataSource(
                    baseAddress: UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
                ) == expectedGeneration else { continue }
                if let evidence {
                    nasResearchEvidenceByCode[code] = evidence
                }
            }
        }
        guard synchronizeNASDataSource(
            baseAddress: UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
        ) == expectedGeneration else { return }
        let checkedAt = Date()
        let usable = codes.compactMap { code -> String? in
            guard let evidence = nasResearchEvidenceByCode[code],
                  evidence.isUsableForAI(contextCreatedAt: checkedAt, now: checkedAt) else { return nil }
            return researchSummaryStatus(code: code, evidence: evidence, now: checkedAt)
        }
        nasResearchStatus = usable.isEmpty
            ? "历史Quant研究摘要暂不可用。顾问继续分析，不等待NAS。"
            : usable.joined(separator: "；")
    }

    private func newsFeedStatus(_ feed: FNewsFeed, targetCodes: [String]) -> String {
        let associatedCount = targetCodes.filter { !$0.isEmpty && !feed.articlesAssociated(with: $0).isEmpty }.count
        let fetched = feed.fetchedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(feed.provider) · 缓存 \(feed.articles.count) 条 · \(associatedCount)/\(targetCodes.count) 个标的有直接关联 · 获取于 \(fetched) · 不关联的标的不作个股归因"
    }

    private func refreshNewsFeedInBackground(for targetCodes: [String]) {
        let now = Date()
        guard !targetCodes.isEmpty else {
            newsStatus = "当前没有目标证券，跳过证券关联快讯"
            return
        }
        if newsRefreshTask != nil {
            if cachedNewsFeed?.recent(at: now) == nil {
                newsStatus = "新闻后台更新中；本轮分析不等待新闻源"
            }
            return
        }
        if let lastAttempt = newsLastAttemptAt, now.timeIntervalSince(lastAttempt) < 120 {
            if cachedNewsFeed?.recent(at: now) == nil {
                newsStatus = "新闻源最近没有可用快讯；本轮继续分析，稍后再试"
            }
            return
        }
        newsLastAttemptAt = now
        if cachedNewsFeed?.recent(at: now) == nil {
            newsStatus = "新闻后台更新中；本轮分析不等待新闻源"
        }
        newsRefreshTask = Task { [weak self] in
            do {
                let fetchedFeed = try await FNewsClient.fetchLatest()
                guard let self else { return }
                let completedAt = Date()
                let priorFreshFeed = self.cachedNewsFeed?.recent(at: completedAt)
                self.cachedNewsFeed = FNewsFeedCachePolicy.replacement(
                    existing: self.cachedNewsFeed, received: fetchedFeed, at: completedAt)
                if let recent = fetchedFeed.recent(at: completedAt) {
                    self.newsStatus = self.newsFeedStatus(recent, targetCodes: targetCodes)
                } else if let priorFreshFeed {
                    self.newsStatus = "\(self.newsFeedStatus(priorFreshFeed, targetCodes: targetCodes)) · 新响应无有效快讯，保留原缓存"
                } else {
                    self.newsStatus = "新闻源已响应，但没有近24小时的有效快讯"
                }
            } catch {
                guard let self else { return }
                if let recent = self.cachedNewsFeed?.recent(at: Date()) {
                    self.newsStatus = "\(self.newsFeedStatus(recent, targetCodes: targetCodes)) · 后台更新失败：\(error.localizedDescription)"
                } else {
                    self.newsStatus = "新闻后台更新失败 · \(error.localizedDescription)"
                }
            }
            self?.newsRefreshTask = nil
        }
    }

    func configureAndTestNAS(baseAddress: String) async {
        let generation = synchronizeNASDataSource(baseAddress: baseAddress)
        guard FNASReadinessClient.validateAddress(baseAddress) != nil else {
            nasConnectionStatus = FNASConnectionError.invalidAddress.localizedDescription
            return
        }
        checkingNASConnection = true
        nasConnectionStatus = "正在检查 NAS 就绪状态…"
        defer { checkingNASConnection = false }
        do {
            let status = try await FNASReadinessClient.check(baseAddress: baseAddress)
            guard synchronizeNASDataSource(
                baseAddress: UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
            ) == generation else { return }
            nasConnectionStatus = status
        } catch {
            guard synchronizeNASDataSource(
                baseAddress: UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
            ) == generation else { return }
            nasConnectionStatus = FNASReadinessClient.connectionHint(for: error)
        }
    }

    func refreshMarketIndices() async {
        guard !refreshingMarketIndices else { return }
        refreshingMarketIndices = true
        marketIndicesError = nil
        defer { refreshingMarketIndices = false }
        let quotes = await FMarketIndexHTTPClient.fetchAll()
        marketIndexQuotes = quotes
        marketIndicesUpdatedAt = Date()
        let availableCount = quotes.filter(\.isAvailable).count
        if availableCount == 0 {
            marketIndicesError = "指数行情源当前均未返回有效数据；未使用 NAS 或缓存值代替实时行情。"
        } else if availableCount < quotes.count {
            marketIndicesError = "部分指数暂不可用；各项显示自己的来源与时间状态。"
        }
    }

    func refreshHistoricalIndexRegimes() async {
        guard !refreshingMarketIndexRegimes else { return }
        refreshingMarketIndexRegimes = true
        var retryForChangedNAS = false
        defer {
            refreshingMarketIndexRegimes = false
            if retryForChangedNAS {
                Task { await refreshHistoricalIndexRegimes() }
            }
        }
        marketIndexRegimeStatusByCode = FMarketIndexHTTPClient.indexCodes.reduce(into: [:]) {
            $0[$1] = "正在更新已完成交易日的指数 Regime…"
        }
        let baseAddress = UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
        let generation = synchronizeNASDataSource(baseAddress: baseAddress)
        let previous = Dictionary(uniqueKeysWithValues: FMarketIndexHTTPClient.indexCodes.compactMap { code in
            (regimeMemoryByCode[code] ?? loadRegimeMemory(for: code)).map { (code, $0) }
        })
        let result = await FMarketIndexHTTPClient.fetchDailyRegimes(previous: previous,
                                                                     nasBaseAddress: baseAddress)
        let currentBaseAddress = UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
        guard synchronizeNASDataSource(baseAddress: currentBaseAddress) == generation else {
            marketIndexRegimeStatusByCode = FMarketIndexHTTPClient.indexCodes.reduce(into: [:]) {
                $0[$1] = "NAS 地址已更改；旧地址指数结果已丢弃，正在重读。"
            }
            retryForChangedNAS = true
            return
        }
        marketIndexRegimesByCode = result.assessments
        marketIndexRegimeFetchedAtByCode = result.fetchedAtByCode
        marketIndexRegimeStatusByCode = result.statuses
        for (code, assessment) in result.assessments where assessment.regime != .dataUnreliable {
            regimeMemoryByCode[code] = assessment.memory
            if let data = try? JSONEncoder().encode(assessment.memory) {
                UserDefaults.standard.set(data, forKey: regimeMemoryKey(for: code))
            }
        }
    }

    private static func isValidSixDigitSecurityCode(_ code: String) -> Bool {
        let bytes = code.utf8
        return bytes.count == 6 && bytes.allSatisfy { (48...57).contains($0) }
    }

    func refreshMarketData(for requestedCodes: [String]? = nil) async {
        let codes = Set(requestedCodes ?? (holdings.map(\.instrumentCode) + [selectedInstrumentCode].compactMap { $0 }))
            .filter { Self.isValidSixDigitSecurityCode($0) }
            .sorted()
        guard !codes.isEmpty else { return }
        for code in codes where marketRefreshTasks[code] == nil {
            refreshingMarketCodes.insert(code)
            marketRefreshStateByCode[code] = "正在请求实时分时…"
            marketRefreshTasks[code] = Task { await performMarketRefresh(for: code) }
        }
        // UI refresh and Advisor may request the same code concurrently. Both
        // callers await the shared fetch so Advisor never races ahead with an
        // older cached quote merely because another request is already active.
        let activeTasks = codes.compactMap { marketRefreshTasks[$0] }
        for task in activeTasks { await task.value }
        // Reference fields (previous close / ETF IOPV) are refreshed separately:
        // a slow or unavailable auxiliary quote must never hold up the live minute chart.
        for code in codes where !refreshingReferenceCodes.contains(code) {
            refreshingReferenceCodes.insert(code)
            Task {
                defer { refreshingReferenceCodes.remove(code) }
                do {
                    let reference = try await FQuoteHTTPClient.fetchMarketReference(code: code)
                    marketReferenceByCode[code] = reference
                    marketReferenceStateByCode[code] = "Tencent 实时参考行情已更新"
                } catch {
                    // A failed auxiliary quote must not leave an older close/IOPV
                    // looking current. Keep the failure visible beside the chart.
                    marketReferenceByCode.removeValue(forKey: code)
                    marketReferenceStateByCode[code] = error.localizedDescription
                }
            }
        }
    }

    private func performMarketRefresh(for code: String) async {
        defer {
            refreshingMarketCodes.remove(code)
            marketRefreshTasks.removeValue(forKey: code)
        }
        do {
            let snapshot = try await FQuoteHTTPClient.fetchCurrentMinutes(code: code)
            let isNewerThanCache = marketDataByCode[code].map {
                $0.quoteTimestamp <= snapshot.quoteTimestamp
            } ?? true
            guard isNewerThanCache else {
                marketRefreshStateByCode[code] = "上游数据较旧 · 保留较新图表缓存"
                return
            }
            marketDataByCode[code] = snapshot
            marketRefreshStateByCode[code] = "已更新 · 行情时间 \(snapshot.quoteTimestamp.formatted(date: .omitted, time: .standard))"
            if let marketQuoteCache {
                Task { [weak self] in
                    do {
                        try await marketQuoteCache.save(snapshot)
                        guard let self, self.marketDataByCode[code]?.fetchedAt == snapshot.fetchedAt,
                              self.marketRefreshStateByCode[code]?.hasPrefix("已更新") == true else { return }
                        self.marketRefreshStateByCode[code] =
                            (self.marketRefreshStateByCode[code] ?? "已更新") + " · 已保存本机缓存"
                    } catch {
                        guard let self, self.marketDataByCode[code]?.fetchedAt == snapshot.fetchedAt,
                              self.marketRefreshStateByCode[code]?.hasPrefix("已更新") == true else { return }
                        self.marketRefreshStateByCode[code] = "已更新但本机缓存保存失败 · \(error.localizedDescription)"
                    }
                }
            } else {
                marketRefreshStateByCode[code] =
                    (marketRefreshStateByCode[code] ?? "已更新") + " · 本机离线缓存不可用"
            }
            if let candidateShadowJournalStore,
               let price = snapshot.latestPrice, price > 0 {
                do {
                    let observation = try FCandidateShadowMarketObservation(
                        securityCode: code, price: price,
                        quoteTimestamp: snapshot.quoteTimestamp, capturedAt: snapshot.fetchedAt,
                        source: snapshot.source, timestampTrust: .verifiedExchangeTimestamp,
                        sessionStatus: FMainlandTradingCalendar.status(at: snapshot.fetchedAt))
                    try await candidateShadowJournalStore.appendMarketObservation(observation)
                } catch {
                    candidateShadowJournalStatus = "行情更新成功；建议影子行情未记录 · \(error.localizedDescription)"
                }
            }
        } catch {
            if let cached = marketDataByCode[code] {
                marketRefreshStateByCode[code] = "更新失败 · 保留本机最近报价供离线查看 · 行情时间 \(cached.quoteTimestamp.formatted(date: .abbreviated, time: .standard)) · \(error.localizedDescription)"
            } else {
                marketRefreshStateByCode[code] = "更新失败 · \(error.localizedDescription)"
            }
        }
    }

    func isInWatchlist(_ code: String) -> Bool {
        watchlistCodes.contains(code)
    }

    func watchlistQuantAssessment(for code: String, at now: Date = Date()) -> FLocalQuantAssessment? {
        guard let quote = marketDataByCode[code] else { return nil }
        let reference = marketReferenceByCode[code]
        let iopv = reference.flatMap { value -> FIOPVObservation? in
            guard value.securityCode == code, value.hasFreshIOPV(at: now), let iopv = value.iopv else { return nil }
            return try? FIOPVObservation(securityCode: code, value: iopv,
                observedAt: value.observedAt, fetchedAt: value.fetchedAt,
                source: value.source, quality: .complete)
        }
        let mapping = FMarketIndexSecurityMappingRegistry.mapping(for: code)
        return FLocalQuantEngine.evaluate(
            quote: quote, dailyHistory: dailyKlineByCode[code], regime: securityRegimeByCode[code],
            iopv: iopv, sessionStatus: FMainlandTradingCalendar.status(at: now),
            mappedBenchmarkRegime: mapping.flatMap { marketIndexRegimesByCode[$0.indexCode] },
            mappedBenchmarkFetchedAt: mapping.flatMap { marketIndexRegimeFetchedAtByCode[$0.indexCode] },
            mappedBenchmarkIndexCode: mapping?.indexCode, now: now)
    }

    func toggleWatchlist(_ code: String) {
        guard Self.isValidWatchlistCode(code) else { return }
        if watchlistCodes.contains(code) {
            watchlistCodes.removeAll { $0 == code }
        } else {
            watchlistCodes.append(code)
            watchlistCodes.sort()
        }
        UserDefaults.standard.set(watchlistCodes, forKey: Self.watchlistDefaultsKey)
    }

    private static let watchlistDefaultsKey = "guanpan.f.market.watchlist.v1"

    private static func loadWatchlistCodes() -> [String] {
        let saved = UserDefaults.standard.stringArray(forKey: watchlistDefaultsKey) ?? []
        return Array(Set(saved.filter(isValidWatchlistCode))).sorted()
    }

    private static func isValidWatchlistCode(_ code: String) -> Bool {
        code.utf8.count == 6 && code.utf8.allSatisfy { (48...57).contains($0) }
    }

    func autoRefreshMarketData() async {
        guard FMainlandTradingCalendar.status(at: Date()) == .continuous else { return }
        let codes = Array(Set(holdings.map(\.instrumentCode) + watchlistCodes +
            [selectedInstrumentCode].compactMap { $0 })).sorted()
        guard !codes.isEmpty else { return }
        await refreshMarketData(for: codes)
    }

    var cashText: String {
        let formatted: String?
        if let cashBalance {
            formatted = Self.moneyFormatter.string(from: cashBalance as NSDecimalNumber)
        } else {
            formatted = nil
        }
        return FHomeCardPresentation.cashBalanceText(state: ledgerState,
                                                     formattedBalance: formatted)
    }
    private static let moneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

enum FHomeTheme: String, CaseIterable, Identifiable {
    case referenceDark, editorial, modern, dashboard, magazine, bento
    case inkModern, minimalTerminal, fluidGlass, dataStarMap, adaptiveBento
    static var allCases: [FHomeTheme] {
        [.referenceDark, .editorial, .dashboard, .bento, .modern, .minimalTerminal, .adaptiveBento]
    }
    var id: String { rawValue }
}
enum FHomeRoute: Hashable {
    case market, crossMarket, advisor, portfolio
    case instrument(String)
    case marketIndex(String)
}

struct FHomeRoot: View {
    @ObservedObject var model: FHomeModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("guanpan.f.homeTheme") private var themeRaw = FHomeTheme.referenceDark.rawValue
    @State private var selectedTab = FPrimaryTab.home
    private var theme: FHomeTheme { FHomeTheme.selected(themeRaw) }

    var body: some View {
        TabView(selection: $selectedTab) {
            rootStack {
                HomeLayout(model: model, theme: theme).navigationTitle("首页")
            }
            .tabItem { Label("首页", systemImage: "house") }
            .tag(FPrimaryTab.home)

            rootStack { MarketOverview(model: model) }
                .tabItem { Label("行情", systemImage: "chart.xyaxis.line") }
                .tag(FPrimaryTab.market)

            rootStack { AdvisorOverview(model: model) }
                .tabItem { Label("AI顾问", systemImage: "sparkles") }
                .tag(FPrimaryTab.advisor)

            rootStack { RealAssetsOverview(model: model) }
                .tabItem { Label("真实资产", systemImage: "briefcase") }
                .tag(FPrimaryTab.assets)

            rootStack { SettingsOverview(model: model) }
                .tabItem { Label("设置", systemImage: "slider.horizontal.3") }
                .tag(FPrimaryTab.settings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.manifest.tokens.background.ignoresSafeArea())
        .tint(theme.accent)
        // Keep this at the navigation root so every scrollable screen and
        // sheet list inherits the same drag-to-dismiss keyboard behavior.
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FBottomNavigationBar(selection: $selectedTab, theme: theme)
        }
        .alert("观盘max", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { model.alertMessage = nil }
        } message: { Text(model.alertMessage ?? "") }
        .sheet(isPresented: $model.showingLedgerConfirmation) {
            FLedgerConfirmationSheet(model: model)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            let clock = ContinuousClock()
            await model.autoRefreshMarketData()
            while !Task.isCancelled {
                // Keep the polling cadence anchored to the start of each fetch.
                // A slow request must not add another full 10-second delay.
                let nextRefresh = clock.now + .seconds(10)
                if FMainlandTradingCalendar.status(at: Date()) == .continuous {
                    await model.autoRefreshMarketData()
                }
                do { try await clock.sleep(until: nextRefresh) }
                catch { break }
            }
        }
    }

    private func rootStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationDestination(for: FHomeRoute.self) { route in
                    HomeDestination(route: route, model: model, theme: theme)
                }
        }
        .toolbar(.hidden, for: .tabBar)
        .background(theme.background.ignoresSafeArea())
        .toolbarBackground(theme.manifest.tokens.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(theme.accent)
    }
}

private enum FPrimaryTab: Hashable { case home, market, advisor, assets, settings }

private struct FBottomNavigationItem: Identifiable {
    let id: FPrimaryTab
    let title: String
    let symbol: String
}

private struct FBottomNavigationBar: View {
    @Binding var selection: FPrimaryTab
    let theme: FHomeTheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let items: [FBottomNavigationItem] = [
        .init(id: .home, title: "首页", symbol: "house.fill"),
        .init(id: .market, title: "行情", symbol: "chart.xyaxis.line"),
        .init(id: .advisor, title: "AI顾问", symbol: "sparkles"),
        .init(id: .assets, title: "资产", symbol: "wallet.bifold.fill"),
        .init(id: .settings, title: "我的", symbol: "person.crop.circle")
    ]

    var body: some View {
        let compact = verticalSizeClass == .compact
        HStack(alignment: .center, spacing: 2) {
            ForEach(items) { item in
                let isSelected = selection == item.id
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selection = item.id
                    }
                } label: {
                    Group {
                        if item.id == .advisor {
                            VStack(spacing: 3) {
                                Image(systemName: theme == .referenceDark ? "sparkles" : item.symbol)
                                    .font(.system(size: compact ? 19 : 23, weight: .semibold))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(theme.manifest.tokens.accentForeground)
                                    .frame(width: compact ? 40 : 52, height: compact ? 40 : 52)
                                    .background {
                                        if theme == .referenceDark {
                                            Circle().fill(LinearGradient(
                                                colors: [Color.white, Color(red: 0.86, green: 0.90, blue: 1.0)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                                        } else {
                                            Circle().fill(LinearGradient(
                                                colors: [theme.manifest.tokens.advisorSurface, theme.accent],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                                        }
                                    }
                                    .overlay(Circle().stroke(.white.opacity(theme == .referenceDark ? 0.30 : 0.82), lineWidth: 3))
                                    .shadow(color: theme == .referenceDark ? Color.white.opacity(0.22) : theme.accent.opacity(0.34),
                                            radius: 10, x: 0, y: 5)
                                    .offset(y: compact ? -7 : (theme == .referenceDark ? -9 : -13))
                                if theme != .referenceDark {
                                    Text(item.title)
                                        .font(.system(size: compact ? 9 : 10, weight: isSelected ? .bold : .semibold))
                                        .foregroundStyle(isSelected ? theme.accent : theme.manifest.tokens.secondaryForeground)
                                        .offset(y: compact ? -6 : -11)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: compact ? 43 : 59)
                        } else {
                            VStack(spacing: compact ? 2 : 5) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: compact ? (isSelected ? 20 : 18) : (isSelected ? 23 : 21),
                                                  weight: isSelected ? .semibold : .regular))
                                    .symbolRenderingMode(.hierarchical)
                                    .frame(height: compact ? 20 : 25)
                                if theme != .referenceDark {
                                    Text(item.title)
                                        .font(.system(size: compact ? 9 : 10, weight: isSelected ? .semibold : .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .foregroundStyle(isSelected ? theme.accent : theme.manifest.tokens.secondaryForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: compact ? 42 : 55)
                            .overlay(alignment: .bottom) {
                                if isSelected && usesTerminalNavigation {
                                    Capsule().fill(theme.accent).frame(width: 22, height: 2)
                                        .offset(y: compact ? 1 : 2)
                                }
                            }
                            .background {
                                if isSelected && usesPillSelection {
                                    RoundedRectangle(cornerRadius: usesGlassNavigation ? 20 : 15,
                                                     style: .continuous)
                                        .fill(theme.accent.opacity(usesTerminalNavigation ? 0.18 : 0.12))
                                        .padding(.horizontal, 3)
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("navigation.tab.\(item.title)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 9)
        .padding(.top, compact ? 2 : 7)
        .padding(.bottom, compact ? 1 : 4)
        .background {
            Group {
                switch theme.surfaceTreatment {
                case .terminal, .minimal:
                    Rectangle().fill(theme.manifest.tokens.surface)
                        .overlay(alignment: .top) {
                            Rectangle().fill(theme.accent.opacity(0.48)).frame(height: 1)
                        }
                case .glass, .orbit:
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(theme.accent.opacity(0.22), lineWidth: 1))
                        .shadow(color: theme.accent.opacity(0.12), radius: 15, y: 5)
                case .ink, .magazine:
                    Rectangle().fill(theme.manifest.tokens.background.opacity(0.96))
                        .overlay(alignment: .top) {
                            Rectangle().fill(theme.accent.opacity(0.30)).frame(height: 0.8)
                        }
                case .bento, .adaptive:
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(theme.accent.opacity(0.18), lineWidth: 0.8))
                case .editorial:
                    Rectangle().fill(theme.manifest.tokens.surface)
                        .overlay(alignment: .top) {
                            Rectangle().fill(theme.manifest.tokens.foreground.opacity(0.10)).frame(height: 0.7)
                        }
                case .card:
                    Rectangle().fill(theme == .referenceDark ? Color(red: 0.043, green: 0.043, blue: 0.051) : theme.manifest.tokens.surface)
                        .overlay(alignment: .top) {
                            Rectangle().fill(theme == .referenceDark ? Color.white.opacity(0.06) : theme.manifest.tokens.foreground.opacity(0.10))
                                .frame(height: 0.7)
                        }
                }
            }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    private var usesTerminalNavigation: Bool {
        theme.surfaceTreatment == .terminal || theme.surfaceTreatment == .minimal
    }

    private var usesGlassNavigation: Bool {
        theme.surfaceTreatment == .glass || theme.surfaceTreatment == .orbit
    }

    private var usesPillSelection: Bool {
        switch theme.surfaceTreatment {
        case .terminal, .minimal, .ink, .magazine: false
        default: true
        }
    }
}

private enum FMarketIndexHTTPClient {
    private struct Definition: Sendable {
        let code: String
        let name: String
        let market: String
        let timeZone: String
        let provider: String
    }

    private static let definitions = [
        Definition(code: "sh000001", name: "上证指数", market: "中国", timeZone: "Asia/Shanghai", provider: "Tencent"),
        Definition(code: "sz399001", name: "深证成指", market: "中国", timeZone: "Asia/Shanghai", provider: "Tencent"),
        Definition(code: "sh000300", name: "沪深300", market: "中国", timeZone: "Asia/Shanghai", provider: "Tencent"),
        Definition(code: "sh000510", name: "中证A500", market: "中国", timeZone: "Asia/Shanghai", provider: "Tencent"),
        Definition(code: "sz399006", name: "创业板指", market: "中国", timeZone: "Asia/Shanghai", provider: "Tencent"),
        Definition(code: "usNDX", name: "纳斯达克100", market: "美国", timeZone: "America/New_York", provider: "Tencent"),
        Definition(code: "int_nikkei", name: "日经225", market: "日本", timeZone: "Asia/Tokyo", provider: "Nikkei Indexes"),
        Definition(code: "KOSPI", name: "KOSPI", market: "韩国", timeZone: "Asia/Seoul", provider: "Naver"),
        Definition(code: "hkHSI", name: "恒生指数", market: "香港", timeZone: "Asia/Hong_Kong", provider: "Tencent")
    ]

    static let emptyCatalog = definitions.map {
        FMarketIndexQuote(code: $0.code, name: $0.name, market: $0.market,
                          timeZoneIdentifier: $0.timeZone, latestPrice: nil,
                          changePercent: nil, observedAt: nil, fetchedAt: nil,
                          source: nil, marketStatus: nil, unavailableReason: "尚未读取")
    }

    static let indexCodes = definitions.map(\.code)
    static let regimeStatusCatalog = Dictionary(uniqueKeysWithValues: definitions.map {
        ($0.code, "历史 Regime 尚未读取")
    })

    private struct DailyRegimeResult: Sendable {
        let code: String
        let history: FNASArchivedIndexDaily?
        let previous: FMarketRegimeMemory?
        let status: String
    }

    static func fetchDailyRegimes(previous: [String: FMarketRegimeMemory], nasBaseAddress: String) async
        -> (assessments: [String: FMarketRegimeAssessment], statuses: [String: String], fetchedAtByCode: [String: Date]) {
        var assessments: [String: FMarketRegimeAssessment] = [:]
        var statuses = regimeStatusCatalog
        var fetchedAtByCode: [String: Date] = [:]
        var results: [DailyRegimeResult] = []
        let historical = definitions.filter { ["Tencent", "Nikkei Indexes", "Naver"].contains($0.provider) }
        await withTaskGroup(of: DailyRegimeResult.self) { group in
            for definition in definitions where !["Tencent", "Nikkei Indexes", "Naver"].contains(definition.provider) {
                group.addTask {
                    DailyRegimeResult(code: definition.code, history: nil, previous: nil,
                        status: "当前公开源未提供已验证的跨市场指数日K；Regime 暂不可用")
                }
            }
            for definition in historical {
                let memory = previous[definition.code]
                group.addTask {
                    await fetchDailyRegime(for: definition, nasBaseAddress: nasBaseAddress,
                                           previous: memory)
                }
            }
            for await result in group {
                results.append(result)
            }
        }
        // Evaluate every index against one capture time. Peers are derived only
        // from completed NAS archive bars and retain their own exchange timestamp,
        // retrieval time, and provider identity. The core filters market, source,
        // freshness, duplicate and session synchronization mismatches.
        let evaluationTime = Date()
        let completedBarsByCode: [String: [FMarketRegimeBar]] = Dictionary(
            uniqueKeysWithValues: results.compactMap { result -> (String, [FMarketRegimeBar])? in
            guard let history = result.history,
                  let definition = definitions.first(where: { $0.code == result.code }),
                  let timeZone = TimeZone(identifier: definition.timeZone) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let currentSessionDayStart = calendar.startOfDay(for: evaluationTime)
            return (result.code, history.bars.filter { $0.timestamp < currentSessionDayStart })
        })
        for result in results.sorted(by: { $0.code < $1.code }) {
            statuses[result.code] = result.status
            guard let history = result.history else { continue }
            fetchedAtByCode[result.code] = history.fetchedAt
            let benchmarks = results.compactMap { peer -> FMarketRegimeBenchmarkObservation? in
                guard peer.code != result.code, let peerHistory = peer.history,
                      let peerBars = completedBarsByCode[peer.code], peerBars.count >= 2,
                      let previousBar = peerBars.dropLast().last,
                      let latestBar = peerBars.last,
                      previousBar.close.isFinite, previousBar.close > 0,
                      latestBar.close.isFinite, latestBar.close > 0 else { return nil }
                let sessionReturn = latestBar.close / previousBar.close - 1
                guard sessionReturn.isFinite, (-1...1).contains(sessionReturn) else { return nil }
                return FMarketRegimeBenchmarkObservation(
                    marketContext: "index:\(result.code)", marketCode: peer.code,
                    observedAt: latestBar.timestamp, sessionStartAt: previousBar.timestamp,
                    capturedAt: peerHistory.fetchedAt,
                    source: peerHistory.source, sessionReturn: sessionReturn)
            }
            let completedBars = completedBarsByCode[result.code] ?? []
            let assessment = FMarketRegimeEngine.evaluate(
                FMarketRegimeInput(market: "index:\(result.code)", asOf: evaluationTime,
                    sourceUpdatedAt: history.fetchedAt, source: history.source,
                    bars: completedBars, benchmarkObservations: benchmarks),
                previous: result.previous, now: evaluationTime)
            assessments[result.code] = assessment
            let newestDate = assessment.dataAsOf?.formatted(date: .numeric, time: .omitted) ?? "不可用"
            statuses[result.code] = assessment.regime == .dataUnreliable
                ? "历史 Regime 不可用 · \(completedBars.count) 根已完成日K · 最近数据 \(newestDate) · 数据不足或过旧"
                : "历史 Regime \(assessment.regime.displayName) · \(assessment.riskLevel.displayName) · \(assessment.confidence)/100 · \(newestDate) 截止"
        }
        return (assessments, statuses, fetchedAtByCode)
    }

    private static func fetchDailyRegime(for definition: Definition, nasBaseAddress: String,
                                         previous: FMarketRegimeMemory?) async -> DailyRegimeResult {
        do {
            let history = try await FNASIndexDailyHistoryClient.fetch(
                baseAddress: nasBaseAddress, indexCode: definition.code)
            return DailyRegimeResult(code: definition.code, history: history,
                                     previous: previous, status: "历史日K已读取")
        } catch {
            return DailyRegimeResult(code: definition.code, history: nil, previous: previous,
                status: "历史 Regime 暂不可用 · \(error.localizedDescription)")
        }
    }

    static func fetchAll() async -> [FMarketIndexQuote] {
        async let tencent = fetchTencentIndices()
        async let sina = fetchSinaNikkei()
        async let naver = fetchNaverKospi()
        let results = await (tencent, sina, naver)
        let quotes = results.0.merging(results.1) { _, latest in latest }
            .merging(results.2) { _, latest in latest }
        return definitions.map { quotes[$0.code] ?? unavailable($0, reason: "来源没有返回报价") }
    }

    private static func fetchTencentIndices() async -> [String: FMarketIndexQuote] {
        let selected = definitions.filter { $0.provider == "Tencent" }
        let symbols = selected.map(\.code).joined(separator: ",")
        guard var components = URLComponents(string: "https://qt.gtimg.cn/") else {
            return Dictionary(uniqueKeysWithValues: selected.map { ($0.code, unavailable($0, reason: "Tencent 地址无效")) })
        }
        components.queryItems = [URLQueryItem(name: "q", value: symbols)]
        guard let url = components.url else {
            return Dictionary(uniqueKeysWithValues: selected.map { ($0.code, unavailable($0, reason: "Tencent 地址无效")) })
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Accept")
        request.setValue("https://gu.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        do {
            let (data, response) = try await FBoundedHTTPClient.data(for: request, maximumResponseBytes: 128_000)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw FMarketDataError.invalidPayload
            }
            let responseText = String(decoding: data, as: UTF8.self)
            let pattern = #"v_([A-Za-z0-9]+)="([^"]*)""#
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                throw FMarketDataError.invalidPayload
            }
            var payloads: [String: String] = [:]
            let fullRange = NSRange(responseText.startIndex..., in: responseText)
            for match in regex.matches(in: responseText, range: fullRange) {
                guard let codeRange = Range(match.range(at: 1), in: responseText),
                      let bodyRange = Range(match.range(at: 2), in: responseText) else { continue }
                payloads[String(responseText[codeRange])] = String(responseText[bodyRange])
            }
            let fetchedAt = Date()
            return Dictionary(uniqueKeysWithValues: selected.map { definition in
                guard let body = payloads[definition.code] else {
                    return (definition.code, unavailable(definition, reason: "Tencent 没有返回该指数"))
                }
                let fields = body.split(separator: "~", omittingEmptySubsequences: false).map(String.init)
                guard fields.count > 32,
                      let price = decimal(fields[3]), price > 0,
                      let changePercent = decimal(fields[32]) else {
                    return (definition.code, unavailable(definition, reason: "Tencent 指数响应字段无效"))
                }
                let observedAt = fields.count > 30 ? parseTencentTimestamp(fields[30], timeZone: definition.timeZone) : nil
                guard observedAt.map({ $0 <= fetchedAt }) ?? true else {
                    return (definition.code, unavailable(definition, reason: "Tencent 指数时间戳在未来"))
                }
                if let observedAt, fetchedAt.timeIntervalSince(observedAt) > 72 * 60 * 60 {
                    return (definition.code, unavailable(definition, reason: "Tencent 指数行情时点已超过72小时"))
                }
                return (definition.code, FMarketIndexQuote(
                    code: definition.code, name: definition.name, market: definition.market,
                    timeZoneIdentifier: definition.timeZone, latestPrice: price,
                    changePercent: changePercent, observedAt: observedAt, fetchedAt: fetchedAt,
                    source: FMarketQuoteTrustPolicy.tencentReferenceSource, marketStatus: nil,
                    unavailableReason: observedAt == nil ? "供应商未提供可识别的指数行情时点" : nil))
            })
        } catch {
            return Dictionary(uniqueKeysWithValues: selected.map {
                ($0.code, unavailable($0, reason: "Tencent 指数行情不可用：\(error.localizedDescription)"))
            })
        }
    }

    private static func fetchSinaNikkei() async -> [String: FMarketIndexQuote] {
        guard let definition = definitions.first(where: { $0.code == "int_nikkei" }),
              let url = URL(string: "https://hq.sinajs.cn/list=int_nikkei") else { return [:] }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("text/plain; charset=GBK", forHTTPHeaderField: "Accept")
        request.setValue("https://finance.sina.com.cn/", forHTTPHeaderField: "Referer")
        request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await FBoundedHTTPClient.data(for: request, maximumResponseBytes: 128_000)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw FMarketDataError.invalidPayload
            }
            let text = String(decoding: data, as: UTF8.self)
            let pattern = #"hq_str_int_nikkei="([^"]*)""#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else {
                throw FMarketDataError.invalidPayload
            }
            let fields = text[range].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 4, let price = decimal(fields[1]), price > 0,
                  let changePercent = decimal(fields[3]) else { throw FMarketDataError.invalidPayload }
            let quote = FMarketIndexQuote(
                code: definition.code, name: definition.name, market: definition.market,
                timeZoneIdentifier: definition.timeZone, latestPrice: price,
                changePercent: changePercent, observedAt: nil, fetchedAt: Date(),
                source: FMarketQuoteTrustPolicy.sinaIndexSource, marketStatus: nil,
                unavailableReason: "Sina 未提供可验证的指数行情时点；仅作行情观察，不进入 Regime/Quant")
            return [definition.code: quote]
        } catch {
            return [definition.code: unavailable(definition,
                reason: "日经指数行情不可用：\(error.localizedDescription)")]
        }
    }

    private static func fetchNaverKospi() async -> [String: FMarketIndexQuote] {
        guard let definition = definitions.first(where: { $0.code == "KOSPI" }),
              let url = URL(string: "https://polling.finance.naver.com/api/realtime/domestic/index/KOSPI") else { return [:] }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await FBoundedHTTPClient.data(for: request, maximumResponseBytes: 128_000)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rows = root["datas"] as? [[String: Any]],
                  let item = rows.first, item["itemCode"] as? String == "KOSPI",
                  let price = decimal(item["closePriceRaw"]), price > 0,
                  let changePercent = decimal(item["fluctuationsRatioRaw"]) else {
                throw FMarketDataError.invalidPayload
            }
            let observedAt = (item["localTradedAt"] as? String).flatMap(parseISO8601)
            let fetchedAt = Date()
            guard observedAt.map({ $0 <= fetchedAt }) ?? false else {
                throw FMarketDataError.invalidPayload
            }
            guard let observedAt, fetchedAt.timeIntervalSince(observedAt) <= 72 * 60 * 60 else {
                return [definition.code: unavailable(definition, reason: "KOSPI 指数行情时点已超过72小时或缺失")]
            }
            let status = item["marketStatus"] as? String
            return [definition.code: FMarketIndexQuote(
                code: definition.code, name: definition.name, market: definition.market,
                timeZoneIdentifier: definition.timeZone, latestPrice: price,
                changePercent: changePercent, observedAt: observedAt, fetchedAt: fetchedAt,
                source: FMarketQuoteTrustPolicy.naverIndexSource, marketStatus: status,
                unavailableReason: nil)]
        } catch {
            return [definition.code: unavailable(definition,
                reason: "KOSPI 行情不可用：\(error.localizedDescription)")]
        }
    }

    private static func unavailable(_ definition: Definition, reason: String) -> FMarketIndexQuote {
        FMarketIndexQuote(code: definition.code, name: definition.name, market: definition.market,
                          timeZoneIdentifier: definition.timeZone, latestPrice: nil,
                          changePercent: nil, observedAt: nil, fetchedAt: nil,
                          source: definition.provider, marketStatus: nil, unavailableReason: reason)
    }

    private static func iopvPremiumPercent(price: Decimal, iopv: Decimal) -> Decimal? {
        guard price.isFinite, price > 0, iopv.isFinite, iopv > 0 else { return nil }
        var price = price
        var iopv = iopv
        var ratio = Decimal.zero
        guard NSDecimalDivide(&ratio, &price, &iopv, .plain) == .noError else { return nil }
        var one = Decimal(1)
        var premium = Decimal.zero
        guard NSDecimalSubtract(&premium, &ratio, &one, .plain) == .noError else { return nil }
        var hundred = Decimal(100)
        var percent = Decimal.zero
        guard NSDecimalMultiply(&percent, &premium, &hundred, .plain) == .noError,
              percent.isFinite else { return nil }
        return percent
    }

    private static func decimal(_ raw: Any?) -> Decimal? {
        let text: String
        if let value = raw as? String {
            text = value.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "")
        } else if let value = raw as? NSNumber {
            guard CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
            text = value.stringValue
        } else {
            return nil
        }
        guard let number = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              number.isFinite, NSDecimalNumber(decimal: number).doubleValue.isFinite else { return nil }
        return number
    }

    private static func parseISO8601(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private static func parseTencentTimestamp(_ raw: String, timeZone: String) -> Date? {
        FMarketIndexTimestamp.parse(raw, timeZoneIdentifier: timeZone)
    }
}

private enum FQuoteProviderError: LocalizedError {
    case bothProvidersFailed(tencent: String, eastmoney: String)

    var errorDescription: String? {
        switch self {
        case .bothProvidersFailed(let tencent, let eastmoney):
            return "腾讯与东方财富实时分钟行情均不可用（腾讯：\(tencent)；东方财富：\(eastmoney)）"
        }
    }
}

private enum FQuoteHTTPClient {
    static func capture<Value>(_ operation: () async throws -> Value) async -> Result<Value, Error> {
        do { return .success(try await operation()) }
        catch { return .failure(error) }
    }

    static func fetchCurrentMinutes(code: String) async throws -> FCurrentIntradaySnapshot {
        do {
            return try await fetchTencentCurrentMinutes(code: code)
        } catch {
            let primaryFailure = error.localizedDescription
            do {
                return try await fetchEastmoneyCurrentMinutes(code: code)
            } catch {
                throw FQuoteProviderError.bothProvidersFailed(
                    tencent: primaryFailure,
                    eastmoney: error.localizedDescription
                )
            }
        }
    }

    static func fetchDailyKline(code: String, count: Int) async throws -> FDailyKlineSnapshot {
        let symbol = try FTencentMinuteParser.symbol(for: code)
        let endpoints = [
            "https://proxy.finance.qq.com/ifzqgtimg/appstock/app/newfqkline/get",
            "https://ifzq.gtimg.cn/appstock/app/newfqkline/get",
            "https://web.ifzq.gtimg.cn/appstock/app/newfqkline/get"
        ]
        var failures: [String] = []
        for endpoint in endpoints {
            do {
                guard var components = URLComponents(string: endpoint) else { throw FMarketDataError.invalidPayload }
                components.queryItems = [URLQueryItem(name: "param", value: "\(symbol),day,,,\(min(max(count, 1), 500))")]
                guard let url = components.url else { throw FMarketDataError.invalidPayload }
                var request = URLRequest(url: url, timeoutInterval: 10)
                request.setValue("https://gu.qq.com/", forHTTPHeaderField: "Referer")
                request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await FBoundedHTTPClient.data(for: request, maximumResponseBytes: 2_000_000)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw FMarketDataError.invalidPayload
                }
                return try FTencentDailyKlineParser.parse(
                    data, securityCode: code, fetchedAt: Date(),
                    source: "Tencent Finance daily K-line · iPhone直连"
                )
            } catch {
                failures.append("\(URL(string: endpoint)?.host ?? endpoint): \(error.localizedDescription)")
            }
        }
        throw NSError(domain: "FQuoteHTTPClient.DailyKline", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: "腾讯手机直连日K来源均失败：\(failures.joined(separator: "；"))"])
    }

    private static func fetchTencentCurrentMinutes(code: String) async throws -> FCurrentIntradaySnapshot {
        let symbol = try FTencentMinuteParser.symbol(for: code)
        guard var components = URLComponents(string: "https://web.ifzq.gtimg.cn/appstock/app/minute/query") else {
            throw FMarketDataError.invalidPayload
        }
        components.queryItems = [URLQueryItem(name: "code", value: symbol),
                                 URLQueryItem(name: "_var", value: "min_data_" + symbol)]
        guard let url = components.url else { throw FMarketDataError.invalidPayload }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("https://gu.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await FBoundedHTTPClient.data(for: request, maximumResponseBytes: 128_000)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FMarketDataError.invalidPayload
        }
        return try FTencentMinuteParser.parse(data, securityCode: code, fetchedAt: Date())
    }

    private static func fetchEastmoneyCurrentMinutes(code: String) async throws -> FCurrentIntradaySnapshot {
        let symbol = try FTencentMinuteParser.symbol(for: code)
        let market = symbol.hasPrefix("sh") ? "1" : "0"
        guard var components = URLComponents(string: "https://push2.eastmoney.com/api/qt/stock/trends2/get") else {
            throw FMarketDataError.invalidPayload
        }
        components.queryItems = [
            URLQueryItem(name: "secid", value: "\(market).\(code)"),
            URLQueryItem(name: "fields1", value: "f1,f2,f3,f4,f5,f6"),
            URLQueryItem(name: "fields2", value: "f51,f52,f53,f54,f55,f56,f57"),
            URLQueryItem(name: "ndays", value: "1"),
            URLQueryItem(name: "iscr", value: "0"),
            URLQueryItem(name: "iscca", value: "0"),
            URLQueryItem(name: "ut", value: "fa5fd1943c7b386f172d6893dbbd1d0c")
        ]
        guard let url = components.url else { throw FMarketDataError.invalidPayload }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("https://quote.eastmoney.com/", forHTTPHeaderField: "Referer")
        request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await FBoundedHTTPClient.data(for: request, maximumResponseBytes: 128_000)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FMarketDataError.invalidPayload
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any],
              let rows = payload["trends"] as? [String] else {
            throw FMarketDataError.invalidPayload
        }

        let timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        var formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let fetchedAt = Date()
        let expectedDay = formatter.string(from: fetchedAt).prefix(10)
        var byTimestamp: [Date: FMinuteSample] = [:]
        for row in rows {
            let fields = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 2,
                  fields[0].hasPrefix(expectedDay),
                  let stamp = formatter.date(from: fields[0]),
                  stamp <= fetchedAt,
                  !fields[0].hasSuffix("09:30"),
                  FMainlandTradingCalendar.isContinuousSessionTime(at: stamp, timeZone: timeZone),
                  let price = Decimal(string: fields[1], locale: Locale(identifier: "en_US_POSIX")),
                  price > 0 else { continue }
            byTimestamp[stamp] = FMinuteSample(timestamp: stamp, price: price)
        }
        let samples = byTimestamp.keys.sorted().compactMap { byTimestamp[$0] }
        guard let latest = samples.last?.timestamp else { throw FMarketDataError.noUsableSamples }
        if FMainlandTradingCalendar.status(at: fetchedAt, timeZone: timeZone) == .continuous,
           fetchedAt.timeIntervalSince(latest) > 300 {
            throw FMarketDataError.staleOrWrongSession
        }
        return try FCurrentIntradaySnapshot(
            securityCode: code,
            samples: samples,
            quoteTimestamp: latest,
            fetchedAt: fetchedAt,
            source: FMarketQuoteTrustPolicy.eastmoneyMinuteSource
        )
    }

    static func fetchMarketReference(code: String) async throws -> FTencentMarketReference {
        let symbol = try FTencentMinuteParser.symbol(for: code)
        guard let url = URL(string: "https://qt.gtimg.cn/q=\(symbol)&_t=\(Int(Date().timeIntervalSince1970))") else {
            throw FMarketDataError.invalidPayload
        }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Accept")
        request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await FBoundedHTTPClient.data(for: request, maximumResponseBytes: 128_000)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FMarketDataError.invalidPayload
        }
        let fields = try FTencentTextQuoteParser.fields(data, expectedSymbol: symbol)
        guard fields.count > 30,
              let price = Decimal(string: fields[3], locale: Locale(identifier: "en_US_POSIX")),
              price.isFinite, price > 0,
              let previousClose = Decimal(string: fields[4], locale: Locale(identifier: "en_US_POSIX")),
              previousClose.isFinite, previousClose > 0,
              let observedAt = parseTencentTimestamp(fields[30]) else { throw FMarketDataError.invalidPayload }
        let instrumentType = fields.count > 61 ? fields[61].trimmingCharacters(in: .whitespacesAndNewlines).uppercased() : nil
        // Tencent occasionally omits the instrument-type field for ETFs. Match
        // B's verified code-family fallback while excluding REITs, which have no
        // intraday IOPV/premium semantics.
        let isETF = instrumentType == "ETF" || isTencentETFCode(code)
        let rawIOPV = isETF && fields.count > 78 ? parseTencentDecimal(fields[78]) : nil
        let iopv = rawIOPV.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let premium = isETF && fields.count > 77 ? parseTencentDecimal(fields[77]) : nil
        let validPremium = premium.flatMap { $0.isFinite && $0 > -100 ? $0 : nil }
        let now = Date()
        guard observedAt <= now else {
            throw FMarketDataError.staleOrWrongSession
        }
        return FTencentMarketReference(securityCode: code, latestPrice: price,
                                       previousClose: previousClose, iopv: iopv,
                                       premiumPercent: validPremium, observedAt: observedAt,
                                       fetchedAt: now, providerInstrumentType: instrumentType,
                                       source: FMarketQuoteTrustPolicy.tencentReferenceSource)
    }

    static func fetchInstrumentName(code: String) async throws -> String {
        let symbol = try FTencentMinuteParser.symbol(for: code)
        guard let url = URL(string: "https://qt.gtimg.cn/q=\(symbol)&_t=\(Int(Date().timeIntervalSince1970))") else {
            throw FMarketDataError.invalidPayload
        }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Accept")
        request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await FBoundedHTTPClient.data(for: request, maximumResponseBytes: 128_000)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FMarketDataError.invalidPayload
        }
        let fields = try FTencentTextQuoteParser.fields(data, expectedSymbol: symbol)
        guard fields.count > 1 else { throw FMarketDataError.invalidPayload }
        let name = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw FMarketDataError.invalidPayload }
        return name
    }

    private static func isTencentETFCode(_ raw: String) -> Bool {
        let code = raw.filter(\.isNumber)
        guard code.count == 6, !code.hasPrefix("508"), !code.hasPrefix("180") else { return false }
        return ["15", "16", "18", "50", "51", "52", "56", "58", "59"].contains { code.hasPrefix($0) }
    }

    private static func parseTencentDecimal(_ raw: String) -> Decimal? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "%", with: "")
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
            .flatMap { $0.isFinite ? $0 : nil }
    }

    private static func parseTencentTimestamp(_ raw: String) -> Date? {
        let digits = raw.filter(\.isNumber)
        guard digits.count == 12 || digits.count == 14,
              let year = Int(digits.prefix(4)), let month = Int(digits.dropFirst(4).prefix(2)),
              let day = Int(digits.dropFirst(6).prefix(2)), let hour = Int(digits.dropFirst(8).prefix(2)),
              let minute = Int(digits.dropFirst(10).prefix(2)) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        var parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        parts.second = digits.count == 14 ? Int(digits.dropFirst(12).prefix(2)) : 0
        guard let date = calendar.date(from: parts) else { return nil }
        let verified = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard verified.year == year, verified.month == month, verified.day == day,
              verified.hour == hour, verified.minute == minute else { return nil }
        return date
    }
}

