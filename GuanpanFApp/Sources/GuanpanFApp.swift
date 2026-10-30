import SwiftUI
import Foundation
import FCore
import FAdvisor
import FLedgerWrite

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
    @Published private(set) var marketRefreshStateByCode: [String: String] = [:]
    @Published private(set) var archivedIntradayByCode: [String: FNASArchivedIntraday] = [:]
    @Published private(set) var archiveRefreshStateByCode: [String: String] = [:]
    @Published private(set) var dailyKlineByCode: [String: FDailyKlineSnapshot] = [:]
    @Published private(set) var dailyKlineStateByCode: [String: String] = [:]
    @Published var selectedHistoryDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @Published private(set) var refreshingMarketCodes: Set<String> = []
    @Published private(set) var selectedInstrumentCode: String?
    @Published private(set) var nasConnectionStatus = "未配置"
    @Published private(set) var checkingNASConnection = false
    @Published private(set) var nasResearchStatus = "尚未请求"
    @Published private(set) var newsStatus = "尚未请求"
    @Published private(set) var aiKeyStatus = "未配置 DeepSeek API Key"
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
    private var decisionMemoryStore: FDecisionMemoryStore?
    private var investorProfileStore: FInvestorProfileStore?
    private var decisionContextStore: FDecisionContextStore?
    private var candidateShadowJournalStore: FCandidateShadowJournalStore?
    var latestLedgerSnapshot: FReadOnlyLedgerSnapshot?

    init() {
        watchlistCodes = Self.loadWatchlistCodes()
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                                      in: .userDomainMask).first else {
            ledgerState = .unavailable
            ledgerStatus = "本机应用数据目录不可用 · 真实账本未读取"
            return
        }
        let store = FAccountBookStore(fileURL: support.appendingPathComponent("f-real-ledger.json"))
        ledgerStore = store
        let advisorDirectory = support.appendingPathComponent("f-advisor", isDirectory: true)
        decisionMemoryStore = FDecisionMemoryStore(directory: advisorDirectory)
        investorProfileStore = FInvestorProfileStore(directory: advisorDirectory)
        decisionContextStore = FDecisionContextStore(directory: advisorDirectory)
        candidateShadowJournalStore = FCandidateShadowJournalStore(directory: advisorDirectory)
        aiKeyStatus = (try? FAdvisorAIKeychain.read()) == nil
            ? "未配置 DeepSeek API Key" : "DeepSeek Key 已保存在本机 Keychain"
        Task { await loadLedger(from: store) }
        Task { await refreshCandidateShadowSummary() }
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
                                 locale: Locale(identifier: "en_US_POSIX")), cost >= 0,
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
              !enteredAmount.isNaN, enteredAmount > 0,
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
                reason: "其他费用/现金对账：\(cashAdjustmentReason.trimmingCharacters(in: .whitespacesAndNewlines))",
                userConfirmation: confirmation)
            let writer = FConfirmedLedgerWriter(store: store)
            _ = try await writer.confirmCashMovement(movement, now: now)
            await loadLedger(from: store)
            pendingCandidate = nil
            pendingCandidateScope = nil
            advisorResult = nil
            showingCashAdjustment = false
            cashAdjustmentStatus = "现金对账差额已追加；证券持仓、成本及盈亏未改变。旧AI候选已失效。"
        } catch {
            cashAdjustmentStatus = "现金对账差额未保存：\(error.localizedDescription)"
        }
    }

    private func writeFeeCorrection() async {
        guard let store = ledgerStore, let fillID = feeCorrectionFillID,
              let correctedFee = Decimal(string: correctedFeeText.trimmingCharacters(in: .whitespacesAndNewlines),
                                          locale: Locale(identifier: "en_US_POSIX")), correctedFee >= 0,
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
                                 locale: Locale(identifier: "en_US_POSIX")), cash >= 0,
              !positions.isEmpty,
              positions.allSatisfy({
                  $0.instrumentCode.utf8.count == 6 &&
                  $0.instrumentCode.utf8.allSatisfy { (48...57).contains($0) } &&
                  !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  $0.units > 0 && $0.economicCost >= 0 &&
                  ($0.brokerDisplayCostPerUnit.map { $0 >= 0 } ?? true)
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
                                  locale: Locale(identifier: "en_US_POSIX")), price > 0,
              let fee = Decimal(string: actualFillFeeText.trimmingCharacters(in: .whitespacesAndNewlines),
                                locale: Locale(identifier: "en_US_POSIX")), fee >= 0,
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
                                             now: now)
            if let candidateShadowJournalStore {
                do {
                    let link = try FCandidateShadowFillLink(confirmedFillID: fill.id,
                                                            linkedAt: now, units: units)
                    try await candidateShadowJournalStore.appendConfirmedExecution(
                        candidateID: candidate.id, link: link)
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
              let price = Decimal(string: manualFillPriceText.trimmingCharacters(in: .whitespacesAndNewlines), locale: Locale(identifier: "en_US_POSIX")), price > 0,
              let fee = Decimal(string: manualFillFeeText.trimmingCharacters(in: .whitespacesAndNewlines), locale: Locale(identifier: "en_US_POSIX")), fee >= 0,
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
        if let focusCode,
           (focusCode.count != 6 || !focusCode.allSatisfy(\.isNumber)) {
            advisorStatus = FAdvisorLiveError.invalidInstrument.localizedDescription
            return
        }
        let targetCodes = focusCode.map { [$0] } ?? initial.positions.map(\.instrumentCode)
        let scope: FAdvisorEntryScope
        if let focusCode { scope = .instrument(focusCode) } else { scope = .portfolio }
        isAskingAdvisor = true
        advisorStatus = focusCode == nil
            ? "正在读取真实持仓并直接刷新组合行情…"
            : "正在读取真实持仓并直接刷新目标证券行情…"
        defer { isAskingAdvisor = false }

        do {
            let apiKey = try FAdvisorAIKeychain.read()
            await refreshMarketData(for: targetCodes)
            let quotes = Dictionary(uniqueKeysWithValues: targetCodes.compactMap { code in
                marketDataByCode[code].map { (code, $0) }
            })
            var newsByCode: [String: FNewsFeed] = [:]
            var newsFailureByCode: [String: String] = [:]
            var marketNewsFeed: FNewsFeed?
            newsStatus = "正在读取同花顺财经近24小时快讯…"
            do {
                let feed = try await FNewsClient.fetchLatest()
                marketNewsFeed = feed
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
                newsStatus = feed.articles.isEmpty
                    ? "同花顺新闻暂不可用 · 最近24小时无可验证快讯"
                    : "\(FNewsClient.providerName) · \(feed.articles.count) 条市场快讯 · \(newsByCode.count)/\(targetCodes.count) 个标的有直接关联 · 不关联的标的不作个股归因"
            } catch {
                let failure = error.localizedDescription
                for code in targetCodes { newsFailureByCode[code] = failure }
                newsStatus = "新闻暂不可用 · \(failure)"
            }
            let researchByCode: [String: FDecisionResearchEvidence] = [:]
            var researchFailureByCode: [String: String] = [:]
            for code in targetCodes {
                researchFailureByCode[code] = "按设置，iOS顾问不读取NAS；只有历史分钟查询会连接NAS"
            }
            nasResearchStatus = "iOS行情刷新和顾问分析不访问NAS；仅历史分钟查询按需连接"

            guard let ledgerStore else { throw FAdvisorLiveError.noRealLedger }
            let contextCaptureTime = Date()
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
                if let quote = quotes[code], let price = quote.latestPrice {
                    observations.append(FContextObservation(
                        dataClass: .quote, subject: code, source: quote.source,
                        reference: quote.source, observedAt: quote.quoteTimestamp,
                        capturedAt: min(contextCaptureTime, quote.fetchedAt), decimalValue: price,
                        quoteTemporalMetadata: FQuoteTemporalMetadata(
                            quoteTimestamp: quote.quoteTimestamp, fetchedAt: quote.fetchedAt,
                            source: quote.source, timestampTrust: .verifiedExchangeTimestamp,
                            marketSessionStatus: sessionStatus)))
                    quoteStatuses.append("\(code) ¥\(price) · \(quote.source) · 行情时 \(quote.quoteTimestamp.formatted(date: .abbreviated, time: .standard)) · 获取于 \(quote.fetchedAt.formatted(date: .abbreviated, time: .standard)) · \(sessionStatus.displayName)")
                } else {
                    observations.append(FContextObservation(
                        dataClass: .quote, subject: code, source: FTencentMinuteParser.source,
                        observedAt: nil, capturedAt: contextCaptureTime, decimalValue: nil,
                        unavailableReason: marketRefreshStateByCode[code] ?? "行情未返回有效分钟点",
                        quoteTemporalMetadata: FQuoteTemporalMetadata(
                            quoteTimestamp: nil, fetchedAt: nil, source: FTencentMinuteParser.source,
                            timestampTrust: .unavailable, marketSessionStatus: sessionStatus)))
                    quoteStatuses.append("\(code) 行情不可用 · \(marketRefreshStateByCode[code] ?? "未返回分钟点")")
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
            var guardFindings = modelAssessment.guardResult.findings
            let requiresRealtimeQuant = [.buy, .sell, .dayTrade, .grid]
                .contains(modelAssessment.candidate.action)
            if requiresRealtimeQuant {
                guardFindings.append(.incompleteTradingEvidence(
                    "本地 Quant Engine 尚未接入；当前不会放行资产变化 Candidate"))
            }
            let uniqueGuardFindings = Array(Set(guardFindings)).sorted {
                String(describing: $0) < String(describing: $1)
            }
            let assessment = FAdvisorDecisionAssessment(
                candidate: modelAssessment.candidate,
                guardResult: FDecisionGuardResult(allowedForReview: uniqueGuardFindings.isEmpty,
                                                  findings: uniqueGuardFindings))
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
                        reasonCodes: uniqueGuardFindings.map { String(describing: $0) },
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
        archiveRefreshStateByCode[code] = "正在查询 NAS 历史分时…"
        do {
            let base = UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
            let archive = try await FNASHistoricalMinuteClient.fetch(
                baseAddress: base, securityCode: code, tradingDate: day)
            guard Calendar.current.isDate(selectedHistoryDate, inSameDayAs: day) else { return }
            archivedIntradayByCode[code] = archive
            archiveRefreshStateByCode[code] = archive.samples.isEmpty
                ? "\(archive.tradingDate) · NAS 无归档分钟点（\(archive.coverageStatus)）"
                : "\(archive.tradingDate) · \(archive.coverageSummary) · 来源 \(archive.sourceSummary)"
        } catch {
            archiveRefreshStateByCode[code] = "NAS 历史分时不可用 · \(error.localizedDescription)"
            archivedIntradayByCode[code] = nil
        }
    }

    func refreshDailyKline(for code: String) async {
        dailyKlineStateByCode[code] = "正在请求腾讯未复权日 K…"
        do {
            let snapshot = try await FQuoteHTTPClient.fetchDailyKline(code: code)
            dailyKlineByCode[code] = snapshot
            let count = snapshot.bars.count
            let missing = [5, 10, 20, 60, 250].filter { count < $0 }
            dailyKlineStateByCode[code] = "\(count) 个真实交易日 · \(snapshot.adjustment) · \(snapshot.source) · 获取于 \(snapshot.fetchedAt.formatted(date: .omitted, time: .standard))" +
                (missing.isEmpty ? "" : " · MA\(missing.map { String($0) }.joined(separator: "/"))样本不足")
        } catch {
            dailyKlineStateByCode[code] = "日 K 不可用 · \(error.localizedDescription)"
            dailyKlineByCode[code] = nil
        }
    }

    func configureAndTestNAS(baseAddress: String) async {
        guard FNASReadinessClient.validateAddress(baseAddress) != nil else {
            nasConnectionStatus = FNASConnectionError.invalidAddress.localizedDescription
            return
        }
        checkingNASConnection = true
        nasConnectionStatus = "正在检查 NAS 就绪状态…"
        defer { checkingNASConnection = false }
        do { nasConnectionStatus = try await FNASReadinessClient.check(baseAddress: baseAddress) }
        catch { nasConnectionStatus = FNASReadinessClient.connectionHint(for: error) }
    }

    func refreshMarketData(for requestedCodes: [String]? = nil) async {
        let codes = Set(requestedCodes ?? (holdings.map(\.instrumentCode) + [selectedInstrumentCode].compactMap { $0 }))
            .filter { $0.count == 6 && $0.allSatisfy(\.isNumber) }
            .sorted()
        let pending = codes.filter { !refreshingMarketCodes.contains($0) }
        guard !pending.isEmpty else { return }
        for code in pending {
            refreshingMarketCodes.insert(code)
            marketRefreshStateByCode[code] = "正在请求实时分时…"
        }
        await withTaskGroup(of: (String, FCurrentIntradaySnapshot?, String?).self) { group in
            for code in pending {
                group.addTask {
                    do { return (code, try await FQuoteHTTPClient.fetchCurrentMinutes(code: code), nil) }
                    catch { return (code, nil, error.localizedDescription) }
                }
            }
            for await (code, snapshot, error) in group {
                refreshingMarketCodes.remove(code)
                if let snapshot {
                    if let old = marketDataByCode[code],
                       old.quoteTimestamp > snapshot.quoteTimestamp {
                        marketRefreshStateByCode[code] = "上游数据较旧 · 保留较新图表缓存"
                    } else {
                        marketDataByCode[code] = snapshot
                        marketRefreshStateByCode[code] = "已更新 · 行情时间 \(snapshot.quoteTimestamp.formatted(date: .omitted, time: .standard))"
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
                } else {
                    marketRefreshStateByCode[code] = "更新失败 · \(error ?? "来源没有返回数据")"
                }
            }
        }
        // Reference fields (previous close / ETF IOPV) are refreshed separately:
        // a slow or unavailable auxiliary quote must never hold up the live minute chart.
        for code in pending where !refreshingReferenceCodes.contains(code) {
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

    func isInWatchlist(_ code: String) -> Bool {
        watchlistCodes.contains(code)
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
    case editorial, modern, dashboard, magazine, bento
    case inkModern, minimalTerminal, fluidGlass, dataStarMap, adaptiveBento
    var id: String { rawValue }
}
enum FHomeRoute: Hashable {
    case market, crossMarket, advisor, portfolio
    case instrument(String)
}

struct FHomeRoot: View {
    @ObservedObject var model: FHomeModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("guanpan.f.homeTheme") private var themeRaw = FHomeTheme.editorial.rawValue
    @State private var selectedTab = FPrimaryTab.home
    private var theme: FHomeTheme { FHomeTheme(rawValue: themeRaw) ?? .editorial }

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
        .toolbarBackground(theme.manifest.tokens.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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
        .background(theme.background.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .toolbarBackground(theme.manifest.tokens.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(theme == .dashboard ? .dark : .light, for: .navigationBar)
        .tint(theme.accent)
    }
}

private enum FPrimaryTab: Hashable { case home, market, advisor, assets, settings }

private enum FQuoteHTTPClient {
    static func capture<Value>(_ operation: () async throws -> Value) async -> Result<Value, Error> {
        do { return .success(try await operation()) }
        catch { return .failure(error) }
    }

    static func fetchCurrentMinutes(code: String) async throws -> FCurrentIntradaySnapshot {
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
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FMarketDataError.invalidPayload
        }
        return try FTencentMinuteParser.parse(data, securityCode: code, fetchedAt: Date())
    }

    static func fetchDailyKline(code: String) async throws -> FDailyKlineSnapshot {
        let symbol = try FTencentMinuteParser.symbol(for: code)
        guard var components = URLComponents(string: "https://web.ifzq.gtimg.cn/appstock/app/fqkline/get") else {
            throw FMarketDataError.invalidPayload
        }
        components.queryItems = [URLQueryItem(name: "param", value: "\(symbol),day,,,300,")]
        guard let url = components.url else { throw FMarketDataError.invalidPayload }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("https://gu.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FMarketDataError.invalidPayload
        }
        return try FTencentDailyKlineParser.parse(data, securityCode: code, fetchedAt: Date())
    }

    static func fetchMarketReference(code: String) async throws -> FTencentMarketReference {
        let symbol = try FTencentMinuteParser.symbol(for: code)
        guard let url = URL(string: "https://qt.gtimg.cn/q=\(symbol)&_t=\(Int(Date().timeIntervalSince1970))") else {
            throw FMarketDataError.invalidPayload
        }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Accept")
        request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FMarketDataError.invalidPayload
        }
        let text = String(decoding: data, as: UTF8.self)
        let pattern = #"v_([A-Za-z0-9]+)="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let bodyRange = Range(match.range(at: 2), in: text) else { throw FMarketDataError.invalidPayload }
        let fields = text[bodyRange].split(separator: "~", omittingEmptySubsequences: false).map(String.init)
        guard fields.count > 30,
              let price = Decimal(string: fields[3], locale: Locale(identifier: "en_US_POSIX")), price > 0,
              let previousClose = Decimal(string: fields[4], locale: Locale(identifier: "en_US_POSIX")), previousClose > 0,
              let observedAt = parseTencentTimestamp(fields[30]) else { throw FMarketDataError.invalidPayload }
        let instrumentType = fields.count > 61 ? fields[61].trimmingCharacters(in: .whitespacesAndNewlines).uppercased() : nil
        // Tencent occasionally omits the instrument-type field for ETFs. Match
        // B's verified code-family fallback while excluding REITs, which have no
        // intraday IOPV/premium semantics.
        let isETF = instrumentType == "ETF" || isTencentETFCode(code)
        let rawIOPV = isETF && fields.count > 78 ? parseTencentDecimal(fields[78]) : nil
        let iopv = rawIOPV.flatMap { $0 > 0 ? $0 : nil }
        let premium = isETF && fields.count > 77 ? parseTencentDecimal(fields[77]) : nil
        let validPremium = premium.flatMap { $0 > -100 ? $0 : nil }
        let now = Date()
        guard observedAt <= now.addingTimeInterval(60) else {
            throw FMarketDataError.staleOrWrongSession
        }
        return FTencentMarketReference(securityCode: code, latestPrice: price,
                                       previousClose: previousClose, iopv: iopv,
                                       premiumPercent: validPremium, observedAt: observedAt,
                                       fetchedAt: now, providerInstrumentType: instrumentType,
                                       source: "Tencent qt.gtimg.cn")
    }

    static func fetchInstrumentName(code: String) async throws -> String {
        let symbol = try FTencentMinuteParser.symbol(for: code)
        guard let url = URL(string: "https://qt.gtimg.cn/q=\(symbol)&_t=\(Int(Date().timeIntervalSince1970))") else {
            throw FMarketDataError.invalidPayload
        }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Accept")
        request.setValue("GuanpanF-iOS/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FMarketDataError.invalidPayload
        }
        let text = String(decoding: data, as: UTF8.self)
        let pattern = #"v_([A-Za-z0-9]+)="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let bodyRange = Range(match.range(at: 2), in: text) else { throw FMarketDataError.invalidPayload }
        let fields = text[bodyRange].split(separator: "~", omittingEmptySubsequences: false).map(String.init)
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
