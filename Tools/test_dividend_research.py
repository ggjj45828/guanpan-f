from datetime import datetime, timedelta, timezone
from decimal import Decimal
import unittest

from nas.fminute.archive import ArchiveError
from nas.fminute.dividend import build_dividend_research_evidence


UTC = timezone.utc
AS_OF = datetime(2026, 10, 23, 8, tzinfo=UTC)


def factor(value, *, observed=AS_OF - timedelta(days=1), fetched=AS_OF - timedelta(hours=1),
           source="fixture", quality=95, unit=None):
    return {"value": value, "source": source, "observedAt": observed.isoformat(),
            "fetchedAt": fetched.isoformat(), "quality": quality, "unit": unit}


class DividendResearchTests(unittest.TestCase):
    def test_four_percent_is_reference_only_and_never_an_eligibility_gate(self):
        result = build_dividend_research_evidence(
            {"currentYield": factor(3.9, unit="percent")}, as_of=AS_OF)
        self.assertEqual(result["evidenceState"], "evidence_available")
        self.assertEqual(result["currentYieldContext"], "below_reference")
        self.assertEqual(result["referenceInterpretation"], "descriptive_only_not_a_hard_gate")
        self.assertIsNone(result["tradePlan"])

    def test_multifactor_evidence_keeps_each_source_and_does_not_fill_missing_values(self):
        factors = {"currentYield": factor("4.1", unit="percent"),
                   "payoutRatio": factor("62", unit="percent"),
                   "freeCashFlow": factor("positive", unit="source_label")}
        result = build_dividend_research_evidence(factors, as_of=AS_OF)
        self.assertEqual(result["factorCoverage"], {"available": 3, "expected": 10})
        self.assertEqual(result["factors"]["payoutRatio"]["source"], "fixture")
        self.assertEqual(result["excludedFactors"]["earningsQuality"], "not_provided")
        self.assertEqual(result["currentYieldContext"], "at_or_above_reference")

    def test_future_and_low_quality_factors_are_excluded(self):
        factors = {
            "currentYield": factor(4.1, observed=AS_OF + timedelta(minutes=1)),
            "payoutRatio": factor(70, quality=79),
        }
        result = build_dividend_research_evidence(factors, as_of=AS_OF)
        self.assertEqual(result["evidenceState"], "insufficient_evidence")
        self.assertEqual(result["excludedFactors"]["currentYield"], "quality_or_as_of_gate")
        self.assertEqual(result["excludedFactors"]["payoutRatio"], "quality_or_as_of_gate")

    def test_historical_yield_percentile_uses_only_unique_as_of_observations(self):
        history = [factor(value, observed=AS_OF - timedelta(days=offset),
                          fetched=AS_OF - timedelta(days=offset) + timedelta(minutes=1))
                   for offset, value in ((30, 3.0), (20, 4.0), (10, 5.0))]
        history.append(factor(99, observed=AS_OF + timedelta(days=1)))
        result = build_dividend_research_evidence(
            {"currentYield": factor(4.0)}, as_of=AS_OF, historical_yields=history)
        self.assertEqual(result["yieldHistory"]["eligibleObservations"], 3)
        self.assertEqual(result["yieldHistory"]["currentYieldPercentile"], 2 / 3)
        self.assertEqual(result["yieldHistory"]["medianYieldPercent"], 4.0)

    def test_duplicate_observation_selection_is_independent_of_input_order(self):
        observed = AS_OF - timedelta(days=2)
        rows = [factor(3.0, observed=observed, fetched=observed + timedelta(hours=1),
                       source="low", quality=85),
                factor(4.0, observed=observed, fetched=observed + timedelta(hours=2),
                       source="trusted", quality=95),
                factor(5.0, observed=observed, fetched=observed + timedelta(hours=3),
                       source="invalid", quality=101)]
        current = {"currentYield": factor(4.0)}
        forward = build_dividend_research_evidence(
            current, as_of=AS_OF, historical_yields=rows)
        reverse = build_dividend_research_evidence(
            current, as_of=AS_OF, historical_yields=list(reversed(rows)))
        self.assertEqual(forward, reverse)
        self.assertEqual(forward["yieldHistory"]["eligibleObservations"], 1)
        self.assertEqual(forward["yieldHistory"]["medianYieldPercent"], 4.0)
        self.assertEqual(forward["yieldHistory"]["sources"], ["trusted"])

    def test_naive_as_of_is_rejected(self):
        with self.assertRaises(ArchiveError):
            build_dividend_research_evidence({}, as_of=datetime(2026, 10, 23, 8))

    def test_decimal_metrics_are_normalized_without_losing_source(self):
        result = build_dividend_research_evidence(
            {"currentYield": factor(Decimal("3.90"), unit="percent")}, as_of=AS_OF)
        self.assertEqual(result["factors"]["currentYield"]["value"], "3.90")
        self.assertEqual(result["currentYieldContext"], "below_reference")


if __name__ == "__main__":
    unittest.main()
