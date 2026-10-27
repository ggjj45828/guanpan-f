import XCTest

final class PrimaryNavigationUITests: XCTestCase {
    func testFivePrimaryDestinationsAreDistinctAndDiscoverable() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["首页"].waitForExistence(timeout: 5))
        attachScreenshot("01-home", app: app)

        app.tabBars.buttons["行情"].tap()
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
        attachScreenshot("03-security-detail-top", app: app)
        let detailScroll = app.scrollViews["market.security-detail.scroll"]
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 3))
        let dailyChartHeading = app.staticTexts["日 K 与均线"]
        scrollUntilHittable(dailyChartHeading, in: detailScroll)
        XCTAssertTrue(dailyChartHeading.isHittable, app.debugDescription)
        attachScreenshot("04-security-daily-chart", app: app)
        let historyHeading = app.staticTexts["NAS 历史分时"]
        detailScroll.swipeUp(velocity: .fast)
        detailScroll.swipeUp(velocity: .fast)
        let historyQueryButton = app.buttons["查询所选交易日"]
        scrollUntilHittable(historyQueryButton, in: detailScroll)
        XCTAssertTrue(historyHeading.isHittable, app.debugDescription)
        XCTAssertTrue(historyQueryButton.isHittable, app.debugDescription)
        attachScreenshot("05-security-history-chart", app: app)

        app.tabBars.buttons["AI顾问"].tap()
        XCTAssertTrue(app.navigationBars["AI 私人投资顾问"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["发送"].exists)
        attachScreenshot("06-advisor", app: app)

        app.tabBars.buttons["真实资产"].tap()
        XCTAssertTrue(app.navigationBars["真实资产"].waitForExistence(timeout: 3))
        attachScreenshot("07-real-assets-current", app: app)

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.secureTextFields["settings.nas.token"].exists)
        XCTAssertTrue(app.secureTextFields["settings.ai.deepseekKey"].exists)
        let nasTestButton = app.buttons["settings.nas.test"]
        let settingsForm = app.descendants(matching: .any)["settings.form"]
        guard settingsForm.waitForExistence(timeout: 3) else {
            XCTFail("Settings Form must be exposed as the identified scroll container.\n\(app.debugDescription)")
            return
        }
        for _ in 0..<6 where !nasTestButton.isHittable {
            settingsForm.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(nasTestButton.isHittable, app.debugDescription)
        attachScreenshot("08-settings", app: app)
    }

    func testAdvisorExplainsUnavailableOnlineService() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["AI顾问"].tap()

        let aiStatus = app.descendants(matching: .any)["advisor.ai-key-status"]
        XCTAssertTrue(aiStatus.waitForExistence(timeout: 5))
        XCTAssertTrue(aiStatus.label.contains("DeepSeek API Key"))
        XCTAssertTrue(app.buttons["发送"].exists)
        XCTAssertTrue(app.textFields.firstMatch.exists || app.textViews.firstMatch.exists)
    }

    func testRealAssetsExposeCurrentClosedAndCashSections() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["真实资产"].tap()

        XCTAssertTrue(app.navigationBars["真实资产"].waitForExistence(timeout: 5))
        let assetList = app.descendants(matching: .any)["assets.list"]
        XCTAssertTrue(assetList.waitForExistence(timeout: 3))

        let closedView = app.buttons["已清仓"]
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
