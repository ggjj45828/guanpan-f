from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
CORE_PNL = (ROOT / "Sources/FCore/SecurityPnLFacts.swift").read_text(encoding="utf-8")
CONTEXT = (ROOT / "Sources/FAdvisor/DecisionContext.swift").read_text(encoding="utf-8")
APP = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
UI = (ROOT / "GuanpanFApp/Sources/HomeExperience.swift").read_text(encoding="utf-8")


def _check_security_daily_pnl_uses_verified_same_day_quote_reference_and_ledger_fills():
    assert "case quote, previousClose, intraday" in CONTEXT
    assert "case .previousClose: return 15 * 60" in CONTEXT
    assert "FMarketQuoteTrustPolicy.isTrustedReferenceSource(source)" in CONTEXT
    assert "FMarketQuoteTrustPolicy.isTrustedReferenceSource($0.source)" in CONTEXT
    assert "FContextDataClass.previousClose.maximumAge" in CONTEXT
    assert "dailyTradeSummaryDate" in CONTEXT
    assert "derivedSecurityDailyPnL(for: fact)" in CONTEXT
    assert "trades: daily" in CONTEXT
    assert "reference.hasFreshReference(at: contextCaptureTime)" in APP
    assert "dataClass: .previousClose" in APP
    assert "quoteDate == tradingDate, referenceDate == tradingDate" in APP
    assert "synchronizedGap <= 15 * 60" in APP
    assert "trades: trades" in APP
    assert "endOfDayUnits: endingUnits" in APP
    assert "let (startOfDayUnits, buyOverflow)" in CORE_PNL
    assert "openingSnapshotSupportsDailyPnL" in CORE_PNL
    assert "dateBytes.count == 10, dateBytes[4] == 45, dateBytes[7] == 45" in CORE_PNL
    assert "FDailyTradeSummary.tradingDate(" in CORE_PNL
    assert "for: dayStart, timeZoneIdentifier: timeZoneIdentifier" in CORE_PNL
    assert "openingSnapshotSupportsDailyPnL" in CONTEXT
    assert "openingSnapshotSupportsDailyPnL" in APP
    assert "let openingSnapshotCapturedAt," in CONTEXT
    assert "openingSnapshotSupportsDailyPnL(" in CONTEXT
    assert "openingSnapshotCapturedAt = book.openingSnapshot.capturedAt" in (
        ROOT / "Sources/FCore/LedgerSnapshot.swift").read_text(encoding="utf-8")
    assert "testSameDayImportedPositionAfterOpenHasNoDailyTotalPnL" in (
        ROOT / "Tests/FCoreTests/LedgerSchemaTests.swift").read_text(encoding="utf-8")
    assert '"2026--10-20", "2026-2-20", "2026-02-30"' in (
        ROOT / "Tests/FCoreTests/LedgerSchemaTests.swift").read_text(encoding="utf-8")
    assert "legacyWithoutOpeningBaseline" in (
        ROOT / "Tests/FCoreTests/LedgerSchemaTests.swift").read_text(encoding="utf-8")
    assert "!trades.isValid(asOf: trades.lastFillTime)" in CORE_PNL
    assert "trades.isValid(asOf: trades.lastFillTime)" in CORE_PNL
    assert "testDecodedDailyTradeSummaryRejectsAmountWithoutMatchingSideQuantity" in (
        ROOT / "Tests/FCoreTests/LedgerSchemaTests.swift").read_text(encoding="utf-8")
    assert "securityCode.utf8.count == 6" in (
        ROOT / "Sources/FCore/DailyTradeSummary.swift").read_text(encoding="utf-8")
    assert "testDecodedDailyTradeSummaryRequiresSixASCIIDigitSecurityIdentity" in (
        ROOT / "Tests/FCoreTests/LedgerSchemaTests.swift").read_text(encoding="utf-8")


def _check_security_daily_pnl_is_shown_with_unavailable_fallback_on_home_and_security_page():
    assert "model.portfolioSecurityDailyPnL(at: context.date)" in UI
    assert "model.securityDailyPnL(for: code, at: context.date)" in UI
    assert 'TimelineView(.periodic(from: .now, by: 15))' in UI
    assert "可核对的日初份额" in UI
    assert "缺可靠前收与日初持仓口径" not in UI


def _check_ledger_confirmation_timestamps_follow_monotonic_event_sequence():
    schema = (ROOT / "Sources/FCore/LedgerSchema.swift").read_text(encoding="utf-8")
    tests = (ROOT / "Tests/FCoreTests/LedgerSchemaTests.swift").read_text(encoding="utf-8")
    assert "enum ConfirmationEvent" in schema
    assert "confirmationEvents.sorted(by: { $0.sequence < $1.sequence })" in schema
    assert 'implausibleTimestamp("ledgerEventConfirmationOrder")' in schema
    assert 'updatedAt < previousConfirmationAt' in schema
    assert "testLedgerRejectsConfirmationsThatRewindBehindEventSequence" in tests
    assert 'implausibleTimestamp("updatedAt.beforeLedgerEvent")' in schema


class SecurityDailyPnLWiringTests(unittest.TestCase):
    def test_uses_verified_same_day_quote_reference_and_fills(self):
        _check_security_daily_pnl_uses_verified_same_day_quote_reference_and_ledger_fills()

    def test_renders_unavailable_fallback(self):
        _check_security_daily_pnl_is_shown_with_unavailable_fallback_on_home_and_security_page()

    def test_ledger_event_confirmation_time_is_monotonic(self):
        _check_ledger_confirmation_timestamps_follow_monotonic_event_sequence()
