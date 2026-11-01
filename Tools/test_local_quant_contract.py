from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
ENGINE = (ROOT / "Sources/FCore/LocalQuantEngine.swift").read_text(encoding="utf-8")
APP = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
ADVISOR = (ROOT / "GuanpanFApp/Sources/FAdvisorVerticalSlice.swift").read_text(encoding="utf-8")


def _check_local_quant_is_read_only_and_never_invents_candidate_plans():
    assert "candidatePlanGenerated: false" in ENGINE
    assert "nas_strategy_parameters_not_qualified" in ENGINE
    assert "qualified: false" in ENGINE
    assert "FConfirmedLedgerWriter" not in ENGINE
    assert "targetPrice" not in ENGINE
    assert "suggestedQuantity" not in ENGINE


def _check_local_quant_requires_fresh_quote_and_exact_security_regime():
    assert "freshness == .fresh && sessionStatus == .continuous" in ENGINE
    assert 'assessment.market == "security:\\(code)"' in ENGINE
    assert "assessment.securityCode == code" in ENGINE
    assert "maximumDailyHistoryAge" in ENGINE
    assert "maximumRegimeAge" in ENGINE
    assert "maximumIntradaySampleGap" in ENGINE
    assert "recentConsecutiveSamples" in ENGINE


def _check_local_quant_requires_real_regime_data_timestamp_not_only_fresh_memory():
    assert "guard let dataAsOf = assessment.dataAsOf" in ENGINE
    assert "dataAsOf <= lastEvaluation" in ENGINE
    assert "dataAsOf <= now" in ENGINE
    assert "now.timeIntervalSince(dataAsOf) <= maximumRegimeAge" in ENGINE
    assert "testRegimeWithMissingFutureOrStaleDataTimeFailsClosed" in (
        ROOT / "Tests/FCoreTests/LocalQuantEngineTests.swift"
    ).read_text(encoding="utf-8")


def _check_local_quant_consumes_the_exact_issuer_mapped_benchmark():
    assert "FMarketIndexSecurityMappingRegistry.mapping(for: code)" in ENGINE
    assert 'assessment.market == "index:\\(mapping.indexCode)"' in ENGINE
    assert "dataAsOf <= assessment.memory.lastEvaluationAt" in ENGINE
    assert 'reasonCode: "mapped_benchmark_unavailable"' in ENGINE
    assert 'reasonCode: "mapped_benchmark_severe_risk"' in ENGINE
    assert "testMappedBenchmarkIsSecuritySpecificFreshAndControlsStrategyReadiness" in (
        ROOT / "Tests/FCoreTests/LocalQuantEngineTests.swift"
    ).read_text(encoding="utf-8")


def _check_severe_security_regime_disables_local_strategy_readiness():
    assert "validRegime.riskLevel >= .r3Severe" in ENGINE
    assert 'reasonCode: "security_regime_severe_risk"' in ENGINE
    assert "testSevereSecurityRiskDisablesLocalStrategiesDespiteBullRegimeTag" in (
        ROOT / "Tests/FCoreTests/LocalQuantEngineTests.swift"
    ).read_text(encoding="utf-8")


def _check_local_quant_exposes_the_eight_defined_factors_and_three_mvp_strategies():
    for factor in (
        "trendStructure", "movingAverageStructure", "vwapDeviation",
        "shortMomentum", "meanReversion", "intradayVolatility",
        "volumeAnomaly", "iopvPremium",
    ):
        assert f"case {factor}" in ENGINE
    assert ".meanReversion, .trendPullback, .vwapDeviation" in ENGINE


def _check_zero_realized_volatility_is_a_valid_measurement():
    volatility = ENGINE.split("private static func returnVolatility", 1)[1].split(
        "private static func double", 1
    )[0]
    assert "variance.isFinite, variance >= 0" in volatility
    assert "return result.isFinite && result >= 0 ? result : nil" in volatility
    assert "return result.isFinite && result > 0 ? result : nil" not in volatility
    assert "testFlatValidSeriesReportsZeroVolatilityInsteadOfUnavailable" in (
        ROOT / "Tests/FCoreTests/LocalQuantEngineTests.swift"
    ).read_text(encoding="utf-8")


def _check_vwap_tolerates_only_small_unknown_volume_coverage():
    vwap = ENGINE.split("private static func volumeWeightedAverage", 1)[1].split(
        "private static func recentConsecutiveSamples", 1
    )[0]
    assert "samples.count >= 20" in vwap
    assert "Int(ceil(Double(samples.count) * 0.9))" in vwap
    assert "VWAP仅使用已知成交量点" in ENGINE
    assert "factor.qualityNote" in APP
    assert "testVWAPAllowsSmallUnknownVolumeCoverageButRejectsPoorCoverage" in (
        ROOT / "Tests/FCoreTests/LocalQuantEngineTests.swift"
    ).read_text(encoding="utf-8")


def _check_trend_structure_needs_more_than_one_moving_average_horizon():
    assert "guard averages.count >= 2 else { return nil }" in ENGINE
    assert "testTrendStructureRequiresAtLeastTwoAvailableMovingAverageHorizons" in (
        ROOT / "Tests/FCoreTests/LocalQuantEngineTests.swift"
    ).read_text(encoding="utf-8")


def _check_advisor_receives_local_quant_observation_without_qualifying_it():
    assert "FLocalQuantEngine.evaluate(" in APP
    assert 'subject: "local-quant:\\(code)"' in APP
    assert 'let localQuantSource = "FCore Local Quant Engine · observation only"' in APP
    assert "reference.hasFreshIOPV(at: contextCaptureTime)" in APP
    assert "策略未qualified时不得据此生成buy/sell/dayTrade/grid候选" in ADVISOR
    assert "NAS验证策略参数包及资格尚未接入" in APP
    assert "availableFactorCount=\\(availableFactorCount)" in APP
    assert "supportingDataAsOf=\\(supportingDataAsOf);source=\\(source)" in APP
    assert "supportingDataAsOf: validDaily?.bars.last?.tradingDate" in ENGINE
    assert "at: validDaily?.bars.last?.tradingDate" in ENGINE
    assert "testDailyQuantFactorsCarryTheirActualSourcesAndObservationTimes" in (
        ROOT / "Tests/FCoreTests/LocalQuantEngineTests.swift"
    ).read_text(encoding="utf-8")
    start = APP.index("    private func runAdvisorQuestion(")
    end = APP.index("    private func researchSummaryStatus", start)
    advisor_flow = APP[start:end]
    assert "Task {\n                await refreshNASResearchEvidence(" in advisor_flow
    assert "\n            await refreshNASResearchEvidence(" not in advisor_flow


def _check_production_has_no_strategy_qualification_grant_issuer():
    production_roots = (ROOT / "Sources", ROOT / "GuanpanFApp/Sources")
    forbidden_calls = (
        "FQuantStrategyQualificationEvidence.observation(",
        "FQuantStrategyQualificationGrant(",
    )
    for production_root in production_roots:
        for source in production_root.rglob("*.swift"):
            contents = source.read_text(encoding="utf-8")
            for call in forbidden_calls:
                assert call not in contents, f"unverified qualification issuer {call} in {source}"
    assert "strategyQualificationGrants = []" in (
        ROOT / "Sources/FAdvisor/DecisionContext.swift"
    ).read_text(encoding="utf-8")
    assert "Runtime qualification grants must not survive archive/JSON decoding" in (
        ROOT / "Tests/FCoreTests/BoundaryAcceptanceTests.swift"
    ).read_text(encoding="utf-8")


class LocalQuantContractTests(unittest.TestCase):
    def test_read_only_contract(self):
        _check_local_quant_is_read_only_and_never_invents_candidate_plans()

    def test_live_data_and_regime_gates(self):
        _check_local_quant_requires_fresh_quote_and_exact_security_regime()

    def test_regime_timestamp_gate(self):
        _check_local_quant_requires_real_regime_data_timestamp_not_only_fresh_memory()

    def test_security_specific_mapped_benchmark_gate(self):
        _check_local_quant_consumes_the_exact_issuer_mapped_benchmark()

    def test_factor_and_strategy_inventory(self):
        _check_local_quant_exposes_the_eight_defined_factors_and_three_mvp_strategies()

    def test_zero_volatility_measurement(self):
        _check_zero_realized_volatility_is_a_valid_measurement()

    def test_vwap_unknown_volume_coverage_gate(self):
        _check_vwap_tolerates_only_small_unknown_volume_coverage()

    def test_trend_horizon_requirement(self):
        _check_trend_structure_needs_more_than_one_moving_average_horizon()

    def test_advisor_wiring(self):
        _check_advisor_receives_local_quant_observation_without_qualifying_it()

    def test_strategy_qualification_fails_closed_until_a_production_verifier_exists(self):
        _check_production_has_no_strategy_qualification_grant_issuer()
