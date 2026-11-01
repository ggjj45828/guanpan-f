from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCHEMA = (ROOT / "Sources/FCore/LedgerSchema.swift").read_text(encoding="utf-8")
HISTORY = (ROOT / "Sources/FCore/LedgerHistoryProjection.swift").read_text(encoding="utf-8")
APP = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
UI = (ROOT / "GuanpanFApp/Sources/HomeExperience.swift").read_text(encoding="utf-8")
TESTS = (ROOT / "Tests/FCoreTests/LedgerSchemaTests.swift").read_text(encoding="utf-8")


def _check_account_expense_is_classified_without_security_attribution():
    assert "public enum FCashMovementCategory" in SCHEMA
    assert "public var category: FCashMovementCategory?" in SCHEMA
    assert "movement.category != .accountExpense || movement.amount < 0" in SCHEMA
    assert "case .some(.accountExpense): kind = .accountExpense" in HISTORY
    assert "case .some(.cashReconciliation): kind = .cashReconciliation" in HISTORY
    assert "category: cashAdjustmentAddsCash ? .cashReconciliation : .accountExpense" in APP
    assert 'case .accountExpense: "账户级杂费"' in UI
    assert 'Text("账户级杂费 / 减少现金")' in UI
    assert "snapshot.cashFlow.last?.kind, .accountExpense" in TESTS
    assert "snapshot.cashFlow.last?.instrumentCode, nil" in TESTS
    assert "testAccountExpenseCategoryRejectsCashInflow" in TESTS
    assert "testCashMovementCategoryDecodesLegacyRowsAndRoundTripsNewCategory" in TESTS


class AccountExpenseClassificationTests(unittest.TestCase):
    def test_classifies_account_expense_without_security_attribution(self):
        _check_account_expense_is_classified_without_security_attribution()

    def test_ui_rejects_non_finite_user_entered_amounts_early(self):
        self.assertIn("enteredAmount.isFinite", APP)
        self.assertIn("correctedFee.isFinite", APP)
        self.assertIn("cost.isFinite", APP)
        self.assertIn("price.isFinite, price > 0", APP)
        self.assertIn("fee.isFinite, fee >= 0", APP)
