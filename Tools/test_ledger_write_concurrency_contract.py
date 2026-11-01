from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
PERSISTENCE = (ROOT / "Sources/FLedgerWrite/LedgerPersistence.swift").read_text(encoding="utf-8")
WRITER = (ROOT / "Sources/FLedgerWrite/LedgerWriteBoundary.swift").read_text(encoding="utf-8")
APP = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
TESTS = (ROOT / "Tests/FCoreTests/BoundaryAcceptanceTests.swift").read_text(encoding="utf-8")


class LedgerWriteConcurrencyContractTests(unittest.TestCase):
    def test_mutation_base_reads_book_and_both_digests_from_one_archive(self):
        load = PERSISTENCE.split("func loadMutationBase(", 1)[1].split("/// Atomically saves", 1)[0]
        self.assertIn("let archive = try decodeArchive(Data(contentsOf: fileURL), now: now)", load)
        self.assertIn("accountBook: archive.accountBook", load)
        self.assertIn("ledgerDigest: archive.ledgerDigest", load)
        self.assertIn("archiveContentDigest: archive.archiveContentDigest", load)
        self.assertNotIn("await", load)

    def test_all_account_mutations_save_against_the_same_archive_digest(self):
        for method in (
            "confirmFill(", "confirmFillFeeCorrection(", "confirmCashMovement(",
            "confirmBrokerDisplayCost(",
        ):
            body = WRITER.split("public func " + method, 1)[1].split("@discardableResult", 1)[0]
            self.assertIn("store.loadMutationBase(now: now)", body, method)
            self.assertIn("base.archiveContentDigest", body, method)
            self.assertNotIn("store.load(now: now)", body, method)
            self.assertNotIn("store.currentDigest(now: now)", body, method)

    def test_candidate_fill_is_bound_to_the_ledger_digest_used_for_analysis(self):
        fill_method = WRITER.split("public func confirmFill(", 1)[1].split(
            "/// Appends an after-the-fact fee correction", 1
        )[0]
        self.assertIn("expectedLedgerDigest != base.ledgerDigest", fill_method)
        self.assertIn("expectedLedgerDigest: candidate.accountDigest", APP)
        self.assertIn("testCandidateFillRejectsLedgerVersionChangedAfterAnalysis", TESTS)


if __name__ == "__main__":
    unittest.main()
