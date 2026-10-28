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
    @Published private(set) var ledgerStatus = "正在读取本机真实账本"
    @Published private(set) var ledgerState: FHomeLedgerState = .loading
    @Published var question = ""
    @Published var alertMessage: String?
    @Published private(set) var marketDataByCode: [String: FCurrentIntradaySnapshot] = [:]
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
    @Published private(set) var aiKeyStatus = "未配置 DeepSeek API Key"
    @Published private(set) var advisorStatus = "尚未开始分析"
    @Published private(set) var isAskingAdvisor = false
    @Published private(set) var advisorResult: FAdvisorVerticalSliceResult?
    @Published var showingLedgerConfirmation = false
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
    private var pendingCandidate: FCandidateRecommendation?
    private var pendingCandidateScope: FAdvisorEntryScope?
    private var ledgerStore: FAccountBookStore?
    private var decisionMemoryStore: FDecisionMemoryStore?
    private var investorProfileStore: FInvestorProfileStore?
    private var decisionContextStore: FDecisionContextStore?
    var latestLedgerSnapshot: FReadOnlyLedgerSnapshot?

    init() {
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
        aiKeyStatus = (try? FAdvisorAIKeychain.read()) == nil
            ? "未配置 DeepSeek API Key" : "DeepSeek Key 已保存在本机 Keychain"
        Task { await loadLedger(from: store) }
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
        advisorResult = nil
        advisorStatus = focusCode == nil
            ? "正在读取全部真实持仓，刷新组合行情并请求逐证券 NAS 研究…"
            : "正在读取真实持仓、刷新目标证券行情并请求 NAS 研究…"
        defer { isAskingAdvisor = false }

        do {
            let apiKey = try FAdvisorAIKeychain.read()
            await refreshMarketData(for: targetCodes)
            let quotes = Dictionary(uniqueKeysWithValues: targetCodes.compactMap { code in
                marketDataByCode[code].map { (code, $0) }
            })
            let baseAddress = UserDefaults.standard.string(forKey: "guanpan.f.nas.baseURL") ?? ""
            var researchByCode: [String: FDecisionResearchEvidence] = [:]
            var researchFailureByCode: [String: String] = [:]
            await withTaskGroup(of: (String, FDecisionResearchEvidence?, String?).self) { group in
                for code in targetCodes {
                    group.addTask {
                        do { return (code, try await FNASResearchClient.fetchEvidence(
                            baseAddress: baseAddress, securityCode: code), nil) }
                        catch { return (code, nil, error.localizedDescription) }
                    }
                }
                for await (code, evidence, failure) in group {
                    if let evidence { researchByCode[code] = evidence }
                    else { researchFailureByCode[code] = failure ?? "NAS未返回研究证据" }
                }
            }
            nasResearchStatus = "\(researchByCode.count)/\(targetCodes.count) 只目标证券取得 NAS 研究证据"

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
                observations.append(FContextObservation(
                    dataClass: .news, subject: code, source: "F News Provider",
                    observedAt: nil, capturedAt: contextCaptureTime, decimalValue: nil,
                    unavailableReason: "新闻源尚未接入"))
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
            let changesAssets = [.buy, .sell, .dayTrade, .grid].contains(modelAssessment.candidate.action)
            let candidateCode = modelAssessment.candidate.instrumentCode
            let hasQualifiedInstrumentResearch = context.usableResearchEvidence(at: Date()).contains {
                $0.envelope.securityCode == candidateCode && $0.envelope.market == "CN"
            }
            if changesAssets && !hasQualifiedInstrumentResearch {
                guardFindings.append(.missingQualifiedResearch("NAS分钟研究:\(candidateCode ?? "未指定证券")"))
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
            let memoryDigest = try await decisionMemoryStore.currentDigest(now: completedAt)
            _ = try await decisionMemoryStore.append(memory, expectedPriorDigest: memoryDigest,
                                                      now: completedAt)
            let holdingSummary = freshLedger.positions.filter { targetCodes.contains($0.instrumentCode) }
                .map { "\($0.instrumentCode) \($0.name) · \($0.units) 份 · 账面成本总额 ¥\(NSDecimalNumber(decimal: $0.bookCost))" }
                .joined(separator: "\n")
            advisorResult = FAdvisorVerticalSliceResult(assessment: assessment, narrative: narrative,
                                                        scope: scope,
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
                } else {
                    marketRefreshStateByCode[code] = "更新失败 · \(error ?? "来源没有返回数据")"
                }
            }
        }
    }

    func autoRefreshMarketData() async {
        let codes = holdings.map(\.instrumentCode) + [selectedInstrumentCode].compactMap { $0 }
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
        .tint(theme.accent)
        .alert("观盘 F", isPresented: Binding(
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
            await model.autoRefreshMarketData()
            while !Task.isCancelled {
                if FMainlandTradingCalendar.status(at: Date()) == .continuous {
                    await model.autoRefreshMarketData()
                }
                do { try await Task.sleep(nanoseconds: 10_000_000_000) }
                catch { break }
            }
        }
    }

    private func rootStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationDestination(for: FHomeRoute.self) { route in
                    HomeDestination(route: route, model: model)
                }
        }
    }
}

private enum FPrimaryTab: Hashable { case home, market, advisor, assets, settings }

private enum FQuoteHTTPClient {
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
}
