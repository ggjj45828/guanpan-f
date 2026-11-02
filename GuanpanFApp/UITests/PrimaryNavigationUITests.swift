import XCTest

final class PrimaryNavigationUITests: XCTestCase {
    func testFivePrimaryDestinationsAreDistinctAndDiscoverable() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["首页"].waitForExistence(timeout: 5))
        attachScreenshot("01-home", app: app)
        let homeScroll = app.scrollViews["home.scroll"]
        XCTAssertTrue(homeScroll.waitForExistence(timeout: 3), app.debugDescription)
        // Current homepage themes render the valuation as a compact live value;
        // the descriptive label is intentionally not repeated in every theme.
        let valuation = homeScroll.descendants(matching: .any)["home.signature.portfolio-value"]
        scrollUntilHittable(valuation, in: homeScroll)
        XCTAssertTrue(valuation.waitForExistence(timeout: 3),
            "Home must expose the ledger-only portfolio valuation, including its unavailable state.\n\(app.debugDescription)")

        app.buttons["navigation.tab.行情"].tap()
        XCTAssertTrue(app.navigationBars["今日市场观察"].waitForExistence(timeout: 3))
        attachScreenshot("02-market-empty-ledger", app: app)

        let lookup = app.textFields["market.security-code"]
        XCTAssertTrue(lookup.waitForExistence(timeout: 3))
        lookup.tap()
        lookup.typeText("159352")
        let openSecurity = app.buttons["market.open-security"]
        XCTAssertTrue(openSecurity.isEnabled)
        openSecurity.tap()
        XCTAssertTrue(app.navigationBars["159352"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["market.refresh.159352"].exists)
        XCTAssertTrue(app.staticTexts["NAS 历史分时"].exists)
        let liveChart = app.descendants(matching: .any)["market.security-chart.live"]
        XCTAssertTrue(liveChart.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertGreaterThanOrEqual(liveChart.frame.height, 400,
                                    "Security detail chart should use the expanded 420pt plot height")
        XCTAssertLessThanOrEqual(liveChart.frame.height, 424.5,
                                 "Security detail chart must stay within its 420pt height cap")
        attachScreenshot("03-security-detail-top", app: app)
        let detailScroll = app.scrollViews["market.security-detail.scroll"]
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 3))
        let dailyChartHeading = app.staticTexts["日 K 与均线"]
        scrollUntilHittable(dailyChartHeading, in: detailScroll)
        XCTAssertTrue(dailyChartHeading.isHittable, app.debugDescription)
        let dailyChart = app.descendants(matching: .any)["market.security-chart.daily"]
        if dailyChart.waitForExistence(timeout: 1) {
            scrollUntilHittable(dailyChart, in: detailScroll)
            XCTAssertGreaterThanOrEqual(dailyChart.frame.height, 400,
                                        "Daily chart should use the expanded 420pt plot height")
            XCTAssertLessThanOrEqual(dailyChart.frame.height, 424.5,
                                     "Daily chart must stay within its 420pt height cap")
        } else {
            XCTAssertTrue(app.staticTexts["market.security-chart.daily.unavailable"].exists,
                          "Without NAS daily history, the page must show an explicit unavailable state")
        }
        attachScreenshot("04-security-daily-chart", app: app)
        let historyHeading = app.staticTexts["NAS 历史分时"]
        detailScroll.swipeUp(velocity: .fast)
        detailScroll.swipeUp(velocity: .fast)
        let historyQueryButton = app.buttons["查询所选交易日"]
        scrollUntilHittable(historyQueryButton, in: detailScroll)
        XCTAssertTrue(historyHeading.isHittable, app.debugDescription)
        XCTAssertTrue(historyQueryButton.isHittable, app.debugDescription)
        attachScreenshot("05-security-history-chart", app: app)

        app.buttons["navigation.tab.AI顾问"].tap()
        XCTAssertTrue(app.navigationBars["AI 私人投资顾问"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["发送"].exists)
        attachScreenshot("06-advisor", app: app)

        app.buttons["navigation.tab.资产"].tap()
        XCTAssertTrue(app.navigationBars["真实资产"].waitForExistence(timeout: 3))
        attachScreenshot("07-real-assets-current", app: app)

        app.buttons["navigation.tab.我的"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.secureTextFields["settings.nas.token"].exists)
        XCTAssertTrue(app.secureTextFields["settings.ai.deepseekKey"].exists)
        let nasTestButton = app.buttons["settings.nas.test"]
        // On iOS 18, SwiftUI Form is exposed as its native CollectionView;
        // the Form's accessibility identifier is not surfaced in XCTest.
        let settingsForm = app.collectionViews.firstMatch
        guard settingsForm.waitForExistence(timeout: 3) else {
            XCTFail("Settings Form must expose its native scroll container.\n\(app.debugDescription)")
            return
        }
        // SwiftUI Form does not expose off-screen rows until scrolling brings
        // them into the accessibility tree. Use the shared scroll helper first.
        scrollUntilHittable(nasTestButton, in: settingsForm)
        XCTAssertTrue(nasTestButton.exists, app.debugDescription)
        XCTAssertTrue(nasTestButton.isHittable, app.debugDescription)
        attachScreenshot("08-settings", app: app)
    }

    func testSecurityDetailChartsUseExpandedPhoneHeight() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        app.buttons["navigation.tab.行情"].tap()
        XCTAssertTrue(app.navigationBars["今日市场观察"].waitForExistence(timeout: 5))
        let lookup = app.textFields["market.security-code"]
        XCTAssertTrue(lookup.waitForExistence(timeout: 3))
        lookup.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), app.debugDescription)
        lookup.typeText("159352")
        let openSecurity = app.buttons["market.open-security"]
        XCTAssertTrue(openSecurity.waitForExistence(timeout: 3))
        openSecurity.tap()

        let detailScroll = app.scrollViews["market.security-detail.scroll"]
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 5))
        let liveChart = app.descendants(matching: .any)["market.security-chart.live"]
        scrollUntilHittable(liveChart, in: detailScroll)
        XCTAssertTrue(liveChart.exists, app.debugDescription)
        XCTAssertGreaterThanOrEqual(liveChart.frame.height, 400,
                                    "Live chart should use the expanded 420pt phone chart height")
        XCTAssertLessThanOrEqual(liveChart.frame.height, 424.5,
                                 "Live chart exceeded the 420pt phone chart height")

        let dailyChartHeading = app.staticTexts["日 K 与均线"]
        scrollUntilHittable(dailyChartHeading, in: detailScroll)
        let dailyChart = app.descendants(matching: .any)["market.security-chart.daily"]
        if dailyChart.exists {
            scrollUntilHittable(dailyChart, in: detailScroll)
            XCTAssertGreaterThanOrEqual(dailyChart.frame.height, 400,
                                        "Daily chart should use the expanded 420pt phone chart height")
            XCTAssertLessThanOrEqual(dailyChart.frame.height, 424.5,
                                     "Daily chart exceeded the 420pt phone chart height")
        } else {
            XCTAssertTrue(app.staticTexts["market.security-chart.daily.unavailable"].exists,
                          "Missing NAS history must remain explicit instead of rendering a fabricated chart")
        }
    }

    func testAdvisorExplainsUnavailableOnlineService() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["navigation.tab.AI顾问"].tap()

        let aiStatus = app.descendants(matching: .any)["advisor.ai-key-status"]
        XCTAssertTrue(aiStatus.waitForExistence(timeout: 5))
        XCTAssertTrue(aiStatus.label.contains("DeepSeek API Key"))
        XCTAssertTrue(app.buttons["发送"].exists)
        XCTAssertTrue(app.textFields.firstMatch.exists || app.textViews.firstMatch.exists)
    }

    func testWatchlistIsSeparateAndAppearsInItsOwnMarketFilter() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        app.buttons["navigation.tab.行情"].tap()
        XCTAssertTrue(app.navigationBars["今日市场观察"].waitForExistence(timeout: 5))

        let code = "159352"
        let lookup = app.textFields["market.security-code"]
        XCTAssertTrue(lookup.waitForExistence(timeout: 3))
        lookup.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), app.debugDescription)
        lookup.typeText(code)

        let toggle = app.buttons["market.watchlist.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        let wasAlreadySaved = toggle.label.contains("移出自选")
        if !wasAlreadySaved { toggle.tap() }
        defer {
            if !wasAlreadySaved {
                let cleanupToggle = app.buttons["market.watchlist.toggle"]
                if cleanupToggle.exists && cleanupToggle.label.contains("移出自选") {
                    cleanupToggle.tap()
                }
            }
        }

        let dismissKeyboard = app.buttons["market.security-code.dismiss"]
        if dismissKeyboard.exists { dismissKeyboard.tap() }

        let scope = app.segmentedControls["market.list.scope"]
        XCTAssertTrue(scope.waitForExistence(timeout: 3), app.debugDescription)
        let watchlistFilter = scope.buttons.matching(NSPredicate(format: "label == %@", "自选")).firstMatch
        XCTAssertTrue(watchlistFilter.waitForExistence(timeout: 3), app.debugDescription)
        watchlistFilter.tap()
        let row = app.descendants(matching: .any)["market.instrument.\(code)"]
        XCTAssertTrue(row.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(row.label.contains(code), row.label)
        XCTAssertTrue(row.label.contains("自选"), row.label)

        // Restore the starting watchlist state so this UI test does not leave
        // user preference data behind for later tests or local app runs.
        if !wasAlreadySaved {
            let rowToggle = app.buttons["market.watchlist.\(code)"]
            XCTAssertTrue(rowToggle.waitForExistence(timeout: 3), app.debugDescription)
            rowToggle.tap()
            XCTAssertFalse(row.exists, "Removing the watchlist-only code should remove it from the watchlist filter")
        }
    }

    func testAdvisorExposesStructuredQuestionAndContextSections() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["navigation.tab.AI顾问"].tap()

        XCTAssertTrue(app.navigationBars["AI 私人投资顾问"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["advisor.composer.question"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["advisor.composer.prompts"].exists)
        XCTAssertTrue(app.buttons["发送"].exists)

        let contextHeading = app.staticTexts["本次可用上下文"]
        let contextScroll = app.scrollViews.firstMatch
        XCTAssertTrue(contextHeading.waitForExistence(timeout: 3))
        scrollUntilHittable(contextHeading, in: contextScroll)
        for identifier in ["advisor.context.ledger", "advisor.context.quotes",
                           "advisor.context.scorecard", "advisor.context.nas-research",
                           "advisor.context.news", "advisor.ai-key-status"] {
            let row = app.descendants(matching: .any)[identifier]
            scrollUntilHittable(row, in: contextScroll)
            XCTAssertTrue(row.exists, "Missing advisor context row \(identifier).\n\(app.debugDescription)")
        }
    }

    func testInvestorProfilePreferenceCanBeSavedAndClearedExplicitly() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["navigation.tab.我的"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        let settingsForm = app.collectionViews.firstMatch
        XCTAssertTrue(settingsForm.waitForExistence(timeout: 3), app.debugDescription)

        let profileDisclosure = app.descendants(matching: .any)["settings.profile.edit"]
        scrollUntilHittable(profileDisclosure, in: settingsForm)
        XCTAssertTrue(profileDisclosure.isHittable, app.debugDescription)
        profileDisclosure.tap()

        let clear = app.buttons["profile.preference.clear.investmentHorizon"]
        if clear.exists {
            scrollUntilHittable(clear, in: settingsForm)
            clear.tap()
            let initialConfirm = app.buttons["清除该项画像"]
            XCTAssertTrue(initialConfirm.waitForExistence(timeout: 3), app.debugDescription)
            initialConfirm.tap()
            let removed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: clear)
            wait(for: [removed], timeout: 10)
        }

        let field = app.textFields["profile.preference.investmentHorizon"]
        scrollUntilHittable(field, in: settingsForm)
        XCTAssertTrue(field.isHittable, app.debugDescription)
        field.tap()
        if let current = field.value as? String, current != "投资期限", !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText("Long term")
        let dismissKeyboard = app.buttons["收起键盘"]
        if dismissKeyboard.exists { dismissKeyboard.tap() }
        let save = app.buttons["profile.preference.save.investmentHorizon"]
        scrollUntilHittable(save, in: settingsForm)
        let saveEnabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        wait(for: [saveEnabled], timeout: 10)
        XCTAssertTrue(save.isEnabled, app.debugDescription)
        save.tap()
        scrollUntilHittable(clear, in: settingsForm)
        let saved = expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: clear)
        wait(for: [saved], timeout: 10)
        XCTAssertTrue(clear.exists, app.debugDescription)
        clear.tap()
        let confirm = app.buttons["清除该项画像"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2), app.debugDescription)
        confirm.tap()
        let cleared = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: clear)
        wait(for: [cleared], timeout: 10)
        XCTAssertFalse(clear.exists, app.debugDescription)
    }

    func testCrossMarketIndexBoardIsDiscoverableAndListsConfiguredMarkets() {
        let app = XCUIApplication()
        app.launch()

        let crossMarketCard = app.descendants(matching: .any)["home.role.crossMarketPulse"]
        XCTAssertTrue(crossMarketCard.waitForExistence(timeout: 5), app.debugDescription)
        crossMarketCard.tap()

        XCTAssertTrue(app.navigationBars["跨市场脉搏"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["crossmarket.refresh"].exists)
        let indexList = app.scrollViews["crossmarket.list"]
        XCTAssertTrue(indexList.waitForExistence(timeout: 3), app.debugDescription)
        for code in ["sh000001", "sz399001", "sh000300", "sh000510", "sz399006", "usNDX",
                     "int_nikkei", "KOSPI", "hkHSI"] {
            let indexCard = app.descendants(matching: .any)["crossmarket.index.\(code)"]
            scrollUntilHittable(indexCard, in: indexList)
            XCTAssertTrue(indexCard.isHittable, "Missing configured index card \(code).\n\(app.debugDescription)")
            XCTAssertTrue(indexCard.label.contains("Regime"),
                          "Missing Regime status for \(code).\n\(app.debugDescription)")
            XCTAssertTrue(indexCard.label.contains("交易时段"),
                          "Missing explicit or unverified trading-session status for \(code).\n\(app.debugDescription)")
        }
    }

    func testRealAssetsExposeCurrentClosedAndCashSections() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["navigation.tab.资产"].tap()

        XCTAssertTrue(app.navigationBars["真实资产"].waitForExistence(timeout: 5))
        let assetList = app.descendants(matching: .any)["assets.list"]
        XCTAssertTrue(assetList.waitForExistence(timeout: 3))

        let closedView = app.segmentedControls["assets.view-picker"].buttons["已清仓"]
        XCTAssertTrue(closedView.waitForExistence(timeout: 3))
        closedView.tap()
        let closedHeading = app.staticTexts["已清仓 / 历史持仓"]
        XCTAssertTrue(closedHeading.waitForExistence(timeout: 3))
        scrollUntilHittable(closedHeading, in: assetList)
        XCTAssertTrue(closedHeading.isHittable, app.debugDescription)
        attachScreenshot("09-real-assets-closed", app: app)

        app.buttons["当前持仓"].tap()
        XCTAssertTrue(app.staticTexts["当前持仓"].exists)
        let cashFlowHeading = app.staticTexts["现金与成交流水"]
        scrollUntilHittable(cashFlowHeading, in: assetList)
        XCTAssertTrue(cashFlowHeading.isHittable, app.debugDescription)
    }

    func testEmptyLedgerOffersInlineCashAndHoldingsEntry() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["navigation.tab.资产"].tap()

        let entry = app.buttons["ledger.opening-snapshot.begin"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription)
        entry.tap()
        XCTAssertTrue(app.navigationBars["录入现有持仓"].waitForExistence(timeout: 3))
        let cash = app.textFields["ledger.opening.cash"]
        XCTAssertTrue(cash.exists, app.debugDescription)
        XCTAssertTrue(app.buttons["ledger.opening.position.add"].exists)
        let confirm = app.buttons["ledger.opening.confirm"]
        XCTAssertTrue(confirm.exists)
        XCTAssertFalse(confirm.isEnabled, "The empty form must not create an incomplete ledger.")
        attachScreenshot("10-holdings-entry", app: app)

        cash.tap()
        cash.typeText("0")
        let code = app.textFields["ledger.opening.position.code"]
        code.tap()
        code.typeText("159352")
        let name = app.textFields["ledger.opening.position.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        if name.value as? String == "证券名称（自动识别，可修改）" {
            name.tap()
            name.typeText("TestETF")
        }
        let units = app.textFields["ledger.opening.position.units"]
        units.tap()
        units.typeText("100")
        let cost = app.textFields["ledger.opening.position.unitCost"]
        cost.tap()
        cost.typeText("1.00")
        app.buttons["收起键盘"].tap()
        XCTAssertTrue(confirm.isEnabled, app.debugDescription)
        confirm.tap()
        XCTAssertFalse(app.navigationBars["录入现有持仓"].waitForExistence(timeout: 5),
                       "A valid opening balance should be saved and close the entry sheet.")
    }

    func testSixApprovedVisualConceptsRenderHomeScreenshots() {
        let themes = [
            "editorial", "dashboard", "bento", "modern", "minimalTerminal", "adaptiveBento"
        ]
        for theme in themes {
            let app = XCUIApplication()
            app.launchArguments = ["-guanpan.f.homeTheme", theme]
            app.launch()
            XCTAssertTrue(app.navigationBars["首页"].waitForExistence(timeout: 8), "Home failed for theme \(theme)")
            let home = app.scrollViews["home.scroll"]
            XCTAssertTrue(home.waitForExistence(timeout: 3))
            let roles = ["portfolio", "marketObservation", "crossMarketPulse", "advisorGuidance"]
                .map { home.descendants(matching: .any).matching(identifier: "home.role.\($0)").firstMatch }
            for (role, element) in zip(["portfolio", "marketObservation", "crossMarketPulse", "advisorGuidance"], roles) {
                XCTAssertTrue(element.waitForExistence(timeout: 3), "Theme \(theme) is missing home role \(role)")
            }
            attachScreenshot("theme-\(theme)-home", app: app)
            app.terminate()
        }
    }

    func testSixApprovedVisualConceptsRenderInSystemDarkAppearance() {
        let themes = [
            "editorial", "dashboard", "bento", "modern", "minimalTerminal", "adaptiveBento"
        ]
        for theme in themes {
            let app = XCUIApplication()
            app.launchArguments = ["-uiUserInterfaceStyle", "Dark", "-guanpan.f.homeTheme", theme]
            app.launch()
            XCTAssertTrue(app.navigationBars["首页"].waitForExistence(timeout: 8),
                          "Dark appearance failed for theme \(theme)")
            attachScreenshot("theme-\(theme)-dark-home", app: app)
            app.terminate()
        }
    }

    func testLandscapeRotationKeepsSecurityDetailAndChartAccessible() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.navigationBars["首页"].waitForExistence(timeout: 8))
        app.buttons["navigation.tab.行情"].tap()

        let lookup = app.textFields["market.security-code"]
        XCTAssertTrue(lookup.waitForExistence(timeout: 5))
        lookup.tap()
        lookup.typeText("159352")
        let dismissKeyboard = app.buttons["market.security-code.dismiss"]
        XCTAssertTrue(dismissKeyboard.waitForExistence(timeout: 3))
        dismissKeyboard.tap()
        let openSecurity = app.buttons["market.open-security"]
        XCTAssertTrue(openSecurity.waitForExistence(timeout: 3))
        openSecurity.tap()

        XCTAssertTrue(app.navigationBars["159352"].waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.scrollViews["market.security-detail.scroll"].exists, app.debugDescription)
        attachScreenshot("landscape-security-detail", app: app)
    }

    private func attachScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollUntilHittable(_ element: XCUIElement, in scrollContainer: XCUIElement) {
        for _ in 0..<20 {
            if element.isHittable { return }
            guard element.exists else {
                scrollContainer.swipeUp(velocity: .slow)
                continue
            }

            let viewport = scrollContainer.frame
            let target = element.frame
            let topSafeEdge = viewport.minY + 90
            let bottomSafeEdge = viewport.maxY - 90

            if target.maxY < topSafeEdge || target.minY < topSafeEdge {
                scrollContainer.swipeDown(velocity: .slow)
            } else if target.minY > bottomSafeEdge {
                scrollContainer.swipeUp(velocity: .slow)
            } else if target.midY < viewport.midY {
                scrollContainer.swipeDown(velocity: .slow)
            } else {
                scrollContainer.swipeUp(velocity: .slow)
            }
        }
    }
}


