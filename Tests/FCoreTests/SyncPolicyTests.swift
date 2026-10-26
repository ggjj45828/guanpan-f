import XCTest
@testable import FCore

final class SyncPolicyTests: XCTestCase {
    func testChannelsKeepIndependentTriggersAndLedgerOwnership() {
        let ledger = FSyncChannelPolicy.policy(for: .personalLedger)
        let market = FSyncChannelPolicy.policy(for: .marketData)
        let research = FSyncChannelPolicy.policy(for: .nasResearch)

        XCTAssertFalse(ledger.allowsAutomaticRefresh)
        XCTAssertTrue(ledger.requiresUserConfirmationBeforeRemoteApply)
        XCTAssertTrue(market.allowsAutomaticRefresh)
        XCTAssertTrue(research.allowsAutomaticRefresh)
        XCTAssertTrue(market.independentOfLedgerSyncToggle)
        XCTAssertTrue(research.independentOfLedgerSyncToggle)
        XCTAssertFalse(market.mayWritePersonalLedger)
        XCTAssertFalse(research.mayWritePersonalLedger)
    }

    func testLedgerSyncNeverChoosesOrMergesDifferentVersions() throws {
        let first = String(repeating: "a", count: 64)
        let second = String(repeating: "b", count: 64)
        XCTAssertEqual(try FPersonalLedgerSyncPolicy.assess(localDigest: nil, remoteDigest: nil), .empty)
        XCTAssertEqual(try FPersonalLedgerSyncPolicy.assess(localDigest: first, remoteDigest: first),
                       .identical(digest: first))
        XCTAssertEqual(try FPersonalLedgerSyncPolicy.assess(localDigest: first, remoteDigest: second),
                       .requiresExplicitChoice(localDigest: first, remoteDigest: second))
        XCTAssertEqual(try FPersonalLedgerSyncPolicy.assess(localDigest: nil, remoteDigest: first),
                       .requiresExplicitChoice(localDigest: nil, remoteDigest: first))
        XCTAssertThrowsError(try FPersonalLedgerSyncPolicy.assess(localDigest: "not-a-digest", remoteDigest: nil)) {
            XCTAssertEqual($0 as? FSyncPolicyError, .invalidLedgerDigest)
        }
    }
}
