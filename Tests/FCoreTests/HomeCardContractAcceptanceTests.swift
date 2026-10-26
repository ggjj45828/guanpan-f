import XCTest
import FAdvisor

final class HomeCardContractAcceptanceTests: XCTestCase {
    func testContractSupportsAllFiveBInspiredLayoutStyles() throws {
        for style in FHomeLayoutStyle.allCases {
            try layout(style: style).validate()
        }
    }

    func testDifferentCardsCannotMasqueradeAsSeparateEntriesToOneDestination() {
        var cards = baseCards()
        cards.append(card("guidance-duplicate", .dailyGuidance, "今日判断", "最新建议", "查看判断", .openPortfolio))
        XCTAssertThrowsError(try FHomeLayoutContract(style: .editorial, cards: cards).validate()) {
            XCTAssertEqual($0 as? FHomeLayoutError, .duplicateDestination)
        }
    }

    func testDestinationMustMatchTheCardInformationDuty() {
        var cards = baseCards()
        cards[2] = card("holdings", .holdings, "真实持仓", "证券份额与成本", "查看持仓", .openAlerts)
        XCTAssertThrowsError(try FHomeLayoutContract(style: .modern, cards: cards).validate()) {
            XCTAssertEqual($0 as? FHomeLayoutError, .destinationDoesNotMatchRole(.holdings))
        }
    }

    func testEveryCardMustExplainItsTitleDutyAndAction() {
        var cards = baseCards()
        cards[3] = card("market", .marketPulse, "", "指数与市场时段", "看行情", .openMarketOverview)
        XCTAssertThrowsError(try FHomeLayoutContract(style: .dashboard, cards: cards).validate()) {
            XCTAssertEqual($0 as? FHomeLayoutError, .incompleteCardDescription("market"))
        }
    }

    func testAdvisorComposerMustBeTheFirstVisibleHomeCard() {
        var cards = baseCards()
        cards.swapAt(0, 1)
        XCTAssertThrowsError(try FHomeLayoutContract(style: .magazine, cards: cards).validate()) {
            XCTAssertEqual($0 as? FHomeLayoutError, .advisorQuestionMustBeFirst)
        }
    }

    func testAllCardsInOneLayoutHaveUniqueIDsAndSemanticRoles() {
        var cards = baseCards()
        cards.append(card("holdings-extra", .holdings, "持仓", "证券份额", "打开", .openInstrument("159352")))
        XCTAssertThrowsError(try FHomeLayoutContract(style: .bento, cards: cards).validate()) {
            XCTAssertEqual($0 as? FHomeLayoutError, .duplicateRole)
        }
    }

    func testCashLabelDistinguishesUnreadableAndUnestablishedLedger() {
        XCTAssertEqual(FHomeCardPresentation.cashBalanceText(state: .loading, formattedBalance: nil), "读取中")
        XCTAssertEqual(FHomeCardPresentation.cashBalanceText(state: .notEstablished, formattedBalance: nil), "未建立")
        XCTAssertEqual(FHomeCardPresentation.cashBalanceText(state: .unavailable, formattedBalance: nil), "不可读取")
        XCTAssertEqual(FHomeCardPresentation.cashBalanceText(state: .available, formattedBalance: nil), "不可用")
        XCTAssertEqual(FHomeCardPresentation.cashBalanceText(state: .available, formattedBalance: "¥100.00"), "¥100.00")
    }

    private func layout(style: FHomeLayoutStyle) -> FHomeLayoutContract {
        FHomeLayoutContract(style: style, cards: baseCards())
    }

    private func baseCards() -> [FHomeCardContract] {
        [
            card("advisor", .advisorQuestion, "问 AI 顾问", "自动结合真实组合与最新上下文", "提问", .askAboutPortfolio),
            card("portfolio", .portfolioSnapshot, "真实组合", "总资产、现金与盈亏", "查看组合", .openPortfolio),
            card("holdings", .holdings, "真实持仓", "证券份额、成本与当前市值", "查看持仓", .openHoldings),
            card("market", .marketPulse, "市场脉搏", "指数状态与最后可信行情时间", "看市场", .openMarketOverview),
            card("quality", .dataQuality, "数据状态", "行情、新闻和研究的来源与新鲜度", "查看数据状态", .openDataQuality)
        ]
    }

    private func card(_ id: String, _ role: FHomeCardRole, _ title: String,
                      _ duty: String, _ action: String,
                      _ destination: FHomeDestination) -> FHomeCardContract {
        FHomeCardContract(id: id, role: role, title: title,
                          informationDuty: duty, primaryActionLabel: action,
                          destination: destination)
    }
}
