import XCTest

final class PrimaryNavigationUITests: XCTestCase {
    func testFivePrimaryDestinationsAreDistinctAndDiscoverable() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["首页"].waitForExistence(timeout: 5))

        app.tabBars.buttons["行情"].tap()
        XCTAssertTrue(app.navigationBars["今日市场观察"].waitForExistence(timeout: 3))

        app.tabBars.buttons["AI顾问"].tap()
        XCTAssertTrue(app.navigationBars["AI 私人投资顾问"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["发送"].exists)

        app.tabBars.buttons["真实资产"].tap()
        XCTAssertTrue(app.navigationBars["真实资产"].waitForExistence(timeout: 3))

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.secureTextFields["settings.nas.token"].exists)
        XCTAssertTrue(app.buttons["settings.nas.test"].exists)
    }

    func testAdvisorExplainsUnavailableOnlineService() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["AI顾问"].tap()

        XCTAssertTrue(app.staticTexts["未配置 DeepSeek API Key"].exists)
        XCTAssertTrue(app.buttons["发送"].exists)
        XCTAssertTrue(app.textFields.firstMatch.exists || app.textViews.firstMatch.exists)
    }
}
