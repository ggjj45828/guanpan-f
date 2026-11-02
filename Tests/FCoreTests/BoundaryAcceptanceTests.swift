import XCTest
import CryptoKit
@_spi(LedgerStorage) import FCore
@testable import FAdvisor
@testable import FLedgerWrite


private struct FixedAdvisorModel: FAdvisorModelProviding {
    let result: FCandidateRecommendation
    func candidate(for request: FAdvisorQuestionRequest) async throws -> FCandidateRecommendation {
        result
    }
}

final class BoundaryAcceptanceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeBook() -> FAccountBook {
        let opening = FAccountOpeningSnapshot(capturedAt: now.addingTimeInterval(-60), cashBalance: 1_000)
        return FAccountBook(openingSnapshot: opening, cashBalance: 1_000,
                            updatedAt: now.addingTimeInterval(-60))
    }

    private func confirmed() -> FUserLedgerConfirmation {
        FUserLedgerConfirmation(confirmedAt: now, confirmationNote: "用户已确认")
    }

    private func securityRegimeObservation(
        securityCode: String = "159352", regime: FMarketRegime = .range,
        risk: FMarketRiskLevel = .r0Normal, dataAsOf: Date? = nil,
        observedAt: Date? = nil, capturedAt: Date? = nil
    ) -> FContextObservation {
        let asOf = dataAsOf ?? now.addingTimeInterval(-600)
        let observed = observedAt ?? now.addingTimeInterval(-1)
        let captured = capturedAt ?? now
        let formatter = ISO8601DateFormatter()
        return FContextObservation(dataClass: .quantState, subject: securityCode,
            source: "FCore Market Regime Engine",
            reference: "regime=\(regime.rawValue); risk=\(risk.rawValue); confidence=80; dataAsOf=\(formatter.string(from: asOf)); source=fixture; factors=trend=available",
            observedAt: observed, capturedAt: captured, decimalValue: 80)
    }

    private func mappedBenchmarkObservation(
        securityCode: String = "159352", regime: FMarketRegime = .range,
        risk: FMarketRiskLevel = .r0Normal, dataAsOf: Date? = nil,
        observedAt: Date? = nil
    ) throws -> FContextObservation {
        let mapping = try XCTUnwrap(FMarketIndexSecurityMappingRegistry.mapping(for: securityCode))
        let asOf = dataAsOf ?? now.addingTimeInterval(-86_400)
        let formatter = ISO8601DateFormatter()
        return FContextObservation(dataClass: .quantState,
            subject: "mapped-index:\(securityCode)",
            source: "F Verified Issuer Index Mapping + NAS Daily Regime",
            reference: "indexCode=\(mapping.indexCode);indexName=\(mapping.indexName);mappingSource=\(mapping.sourceURL);mapping=issuer_benchmark;contextRole=benchmark_only;regime=\(regime.rawValue);risk=\(risk.rawValue);confidence=80;dataAsOf=\(formatter.string(from: asOf));not_strategy_qualification=true",
            observedAt: observedAt ?? now.addingTimeInterval(-10), capturedAt: now, decimalValue: 80)
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GuanpanF-Boundary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func researchReference(id: String, generatedAt: Date) throws -> FDecisionResearchEvidence {
        let formatter = ISO8601DateFormatter()
        let metrics: [String: Any] = ["evidenceState": "available_for_review", "independentDays": 32,
                                      "minimumTrainingDays": 20, "minimumOutOfSampleDays": 5,
                                      "trainingDays": 24, "outOfSampleDays": 8,
                                      "maxMonthlySampleShare": 0.25, "maximumMonthlySampleShare": 0.5,
                                      "training": ["days": 24, "startDate": "2026-08-03",
                                                   "endDate": "2026-09-30", "median": 0.1,
                                                   "mean": 0.1, "positiveRate": 0.6],
                                      "outOfSample": ["days": 8, "startDate": "2026-10-01",
                                                      "endDate": "2026-10-20", "median": 0.1,
                                                      "mean": 0.1, "positiveRate": 0.6]]
        var payload: [String: Any] = [
            "schemaVersion": 2, "methodologyVersion": "minute-research-2", "evidenceId": String(repeating: "0", count: 64),
            "securityCode": "159352", "market": "CN",
            "range": ["start": "2026-08-01", "end": "2026-10-23"],
            "dataRange": ["start": "2026-08-03", "end": "2026-10-23"],
            "strategyVersion": NSNull(),
            "asOf": formatter.string(from: now.addingTimeInterval(-120)),
            "generatedAt": formatter.string(from: generatedAt), "timezone": "Asia/Shanghai",
            "sessionCoverage": ["complete": 32, "partial": 0, "missing": 0],
            "qualifiedIndependentDays": 32, "minimumQuality": 90, "sources": [FResearchSourceTrustPolicy.tencentMinuteSource],
            "evidence": ["vwapBreak": ["windows": ["5": metrics]]],
            "limitations": ["fixture only \(id)"], "rawMinuteBarsIncluded": false, "tradePlan": NSNull()
        ]
        let initialBytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let initialEnvelope = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: initialBytes)
        let digest = try initialEnvelope.calculatedContentDigest()
        payload["evidenceId"] = digest
        let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let envelope = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: bytes)
        return FDecisionResearchEvidence(envelope: envelope, capturedAt: now)
    }

    func testDecisionPipelineReturnsOnlyGuardedReviewCandidate() async throws {
        let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
                                       observations: [])
        let request = try FAdvisorQuestionRequest(question: "今天我的组合需要操作吗？",
                                                  scope: .portfolio,
                                                  decisionContext: context, now: now)
        let wait = FCandidateRecommendation(accountDigest: context.accountDigest,
                                            action: .wait, rationale: "暂无合格新证据")
        let result = try await FAdvisorDecisionPipeline(model: FixedAdvisorModel(result: wait))
            .assess(request: request, context: context, now: now)
        XCTAssertTrue(result.isEligibleForUserReview)
        XCTAssertEqual(result.candidate, wait)
    }

    func testDecisionPipelineRejectsRecommendationOutsideInstrumentScope() async throws {
        let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
                                       observations: [])
        let request = try FAdvisorQuestionRequest(question: "分析159352",
                                                  scope: .instrument("159352"),
                                                  decisionContext: context, now: now)
        let wrongSecurity = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .sell, instrumentCode: "563020", units: 100,
            limitPrice: 1, estimatedFee: 0.1, rationale: "测试错标证券")
        let result = try await FAdvisorDecisionPipeline(model: FixedAdvisorModel(result: wrongSecurity))
            .assess(request: request, context: context, now: now)
        XCTAssertFalse(result.isEligibleForUserReview)
        XCTAssertTrue(result.guardResult.findings.contains(.instrumentScopeMismatch(
            expected: "159352", actual: "563020")))
    }

    func testDecisionMemoryProjectionKeepsOnlyMatchingExplicitScope() throws {
        let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
                                       observations: [])
        let portfolioRequest = try FAdvisorQuestionRequest(question: "组合回顾", scope: .portfolio,
            decisionContext: context, now: now)
        let instrumentRequest = try FAdvisorQuestionRequest(question: "159352回顾",
            scope: .instrument("159352"), decisionContext: context, now: now)
        let portfolioCandidate = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .wait, rationale: "组合观察")
        let instrumentCandidate = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .wait, rationale: "证券观察")
        let portfolioMemory = try FDecisionMemory(context: context, candidate: portfolioCandidate,
            recommendation: "组合等待", rationale: "组合证据不足", advisorRequest: portfolioRequest)
        let instrumentMemory = try FDecisionMemory(context: context, candidate: instrumentCandidate,
            recommendation: "证券等待", rationale: "证券证据不足", advisorRequest: instrumentRequest)

        let portfolioProjection = try FAdvisorDecisionMemoryProjection(records: [portfolioMemory, instrumentMemory],
            accountID: context.accountID, scope: .portfolio, asOf: now, validatedAt: now)
        let instrumentProjection = try FAdvisorDecisionMemoryProjection(records: [portfolioMemory, instrumentMemory],
            accountID: context.accountID, scope: .instrument("159352"), asOf: now, validatedAt: now)

        XCTAssertEqual(portfolioMemory.scope, .portfolio)
        XCTAssertEqual(instrumentMemory.scope, .instrument("159352"))
        XCTAssertEqual(portfolioProjection.entries.map(\.id), [portfolioMemory.id])
        XCTAssertEqual(instrumentProjection.entries.map(\.id), [instrumentMemory.id])
        XCTAssertTrue(instrumentProjection.isValid(accountID: context.accountID,
            scope: .instrument("159352"), asOf: now))
    }

    func testDecisionPipelineRejectsResearchEvidenceInjectedAfterContextCapture() async throws {
        let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
                                       observations: [])
        let request = try FAdvisorQuestionRequest(question: "回看分钟研究",
                                                  scope: .instrument("159352"),
                                                  decisionContext: context, now: now)
        let unboundEvidence = try researchReference(id: String(repeating: "a", count: 64),
                                                   generatedAt: now.addingTimeInterval(-60))
        let encodedRequest = try JSONEncoder().encode(request)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedRequest)
                                    as? [String: Any])
        let evidenceBytes = try JSONEncoder().encode([unboundEvidence])
        payload["researchEvidence"] = try JSONSerialization.jsonObject(with: evidenceBytes)
        let tamperedBytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let tamperedRequest = try JSONDecoder().decode(FAdvisorQuestionRequest.self, from: tamperedBytes)
        let wait = FCandidateRecommendation(accountDigest: context.accountDigest,
                                            action: .wait, rationale: "仅作管线边界测试")

        do {
            _ = try await FAdvisorDecisionPipeline(model: FixedAdvisorModel(result: wait))
                .assess(request: tamperedRequest, context: context, now: now)
            XCTFail("unbound research evidence must be rejected before model invocation")
        } catch let error as FAdvisorDecisionPipelineError {
            XCTAssertEqual(error, .requestContextMismatch)
        }
    }

    func testResearchEvidenceRejectsQualifiedDaysAboveCompleteCoverage() throws {
        let reference = try researchReference(id: String(repeating: "0", count: 64),
                                              generatedAt: now.addingTimeInterval(-60))
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(reference.envelope)) as? [String: Any])
        payload["qualifiedIndependentDays"] = 33
        let unsignedBytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let unsigned = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: unsignedBytes)
        payload["evidenceId"] = try unsigned.calculatedContentDigest()
        let forgedBytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let forged = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: forgedBytes)

        XCTAssertThrowsError(try forged.validate(capturedAt: now, contextCreatedAt: now))
    }

    func testQualifiedResearchEvidenceRequiresAValidTimeZone() throws {
        let reference = try researchReference(id: String(repeating: "0", count: 64),
                                              generatedAt: now.addingTimeInterval(-60))
        for invalidZone in [NSNull(), "Mars/Olympus_Mons"] as [Any] {
            var payload = try XCTUnwrap(JSONSerialization.jsonObject(
                with: JSONEncoder().encode(reference.envelope)) as? [String: Any])
            payload["timezone"] = invalidZone
            let unsignedBytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            let unsigned = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: unsignedBytes)
            payload["evidenceId"] = try unsigned.calculatedContentDigest()
            let forgedBytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            let forged = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: forgedBytes)

            XCTAssertThrowsError(try forged.validate(capturedAt: now, contextCreatedAt: now))
        }
    }

    func testResearchDigestMatchesNASAtHalfMillisecondTimestamps() throws {
        let payload: [String: Any] = [
            "schemaVersion": 2, "methodologyVersion": "minute-research-2",
            "evidenceId": String(repeating: "0", count: 64),
            "securityCode": "159352", "market": "CN",
            "range": ["start": "2026-10-01", "end": "2026-10-31"],
            "dataRange": NSNull(), "strategyVersion": NSNull(),
            "asOf": "2026-10-25T02:00:00.000500Z",
            "generatedAt": "2026-10-25T02:00:00.001500Z", "timezone": NSNull(),
            "sessionCoverage": ["complete": 1], "qualifiedIndependentDays": 0,
            "minimumQuality": 90, "sources": [],
            "evidence": ["vwapBreak": ["metric": 0.5]],
            "limitations": [
                "Historical observational evidence; not a forecast or trade instruction.",
                "Only complete sessions meeting the configured quality and as-of gates are eligible.",
                "Market calendar and provider coverage require deployment verification."
            ],
            "rawMinuteBarsIncluded": false, "tradePlan": NSNull()
        ]
        let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let envelope = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: bytes)

        XCTAssertEqual(try envelope.calculatedContentDigest(),
                       "462be406477951375097389d057533a3cae5733e498d4d1e18cdfd799dd6aff2")
    }

    func testProfileProjectionRejectsFutureRevisionAfterDecode() throws {
        let revision = FInvestorProfileRevision(value: .text("中长期"), confidence: 0.8,
            source: .explicit, updatedAt: now.addingTimeInterval(-60), explanation: "用户明确设置")
        let profile = FInvestorProfile(attributes: [
            FInvestorProfileAttribute(key: .investmentHorizon, revisions: [revision])
        ])
        let projection = try FAdvisorInvestorProfileProjection(profile: profile, asOf: now, validatedAt: now)
        XCTAssertTrue(projection.isValid(asOf: now))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(projection))
                                    as? [String: Any])
        var preferences = try XCTUnwrap(payload["preferences"] as? [[String: Any]])
        preferences[0]["updatedAt"] = (now.addingTimeInterval(1).timeIntervalSince1970) * 1_000
        payload["preferences"] = preferences
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(FAdvisorInvestorProfileProjection.self,
            from: JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
        XCTAssertFalse(decoded.isValid(asOf: now))
    }

    func testProfileProjectionRevalidatesTemporaryPreferenceExpiryAfterDecode() throws {
        let revision = FInvestorProfileRevision(value: .text("本周降低交易频率"), confidence: 0.7,
            source: .temporary, updatedAt: now.addingTimeInterval(-60),
            explanation: "用户要求本周暂停频繁交易", expiresAt: now.addingTimeInterval(300))
        let profile = FInvestorProfile(attributes: [
            FInvestorProfileAttribute(key: .tradingFrequency, revisions: [revision])
        ])
        let projection = try FAdvisorInvestorProfileProjection(profile: profile, asOf: now, validatedAt: now)
        XCTAssertTrue(projection.isValid(asOf: now))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(projection))
                                    as? [String: Any])
        var preferences = try XCTUnwrap(payload["preferences"] as? [[String: Any]])
        preferences[0]["expiresAt"] = (now.addingTimeInterval(-1).timeIntervalSince1970) * 1_000
        payload["preferences"] = preferences
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(FAdvisorInvestorProfileProjection.self,
            from: JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
        XCTAssertFalse(decoded.isValid(asOf: now))
    }

    func testAssetChangingCandidateMustCiteTheVerifiedFreshQuote() throws {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(-10), fetchedAt: now,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352",
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, observedAt: metadata.quoteTimestamp,
            capturedAt: now, decimalValue: 1, quoteTemporalMetadata: metadata)
        let qualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion", strategyVersion: "v3", evaluatedAt: now))
        let grant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", observationID: qualification.id, evaluatedAt: now)
        let regime = securityRegimeObservation()
        let mappedBenchmark = try mappedBenchmarkObservation()
        let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, qualification, regime, mappedBenchmark], strategyQualificationGrants: [grant])
        let uncited = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100,
            limitPrice: 1, rationale: "基于价格评估",
            citedObservationIDs: [qualification.id, regime.id, mappedBenchmark.id])
        let uncitedResult = FRiskGuard.evaluate(uncited, in: context, now: now)
        XCTAssertTrue(uncitedResult.findings.contains(.missingCitedEvidence(quote.id)))

        let cited = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100,
            limitPrice: 1, rationale: "基于所引新鲜报价评估",
            citedObservationIDs: [quote.id, qualification.id, regime.id, mappedBenchmark.id])
        XCTAssertFalse(FRiskGuard.evaluate(cited, in: context, now: now)
            .findings.contains(.missingCitedEvidence(quote.id)))
    }

    func testAssetChangingCandidateRequiresFreshCitedQuantQualification() throws {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(-10), fetchedAt: now,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352",
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, observedAt: metadata.quoteTimestamp,
            capturedAt: now, decimalValue: 1, quoteTemporalMetadata: metadata)
        let regime = securityRegimeObservation()
        let withoutQualification = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now), observations: [quote, regime])
        let candidate = FCandidateRecommendation(accountDigest: withoutQualification.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "本地策略审查", citedObservationIDs: [quote.id, regime.id])
        let missing = FRiskGuard.evaluate(candidate, in: withoutQualification, now: now)
        XCTAssertTrue(missing.findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 {
                return reason.contains("本地 Quant 策略资格")
            }
            return false
        })

        let forgedQualification = FContextObservation(
            dataClass: .quantState, subject: "strategy-qualification:159352",
            source: "F Local Quant Strategy Qualification",
            reference: "strategyID=MeanReversion;strategyVersion=v3;qualification=qualified",
            observedAt: now, capturedAt: now, decimalValue: 1)
        let forgedContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, forgedQualification, regime])
        let forgedCandidate = FCandidateRecommendation(accountDigest: forgedContext.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "伪造资格标记", citedObservationIDs: [quote.id, forgedQualification.id, regime.id])
        XCTAssertTrue(FRiskGuard.evaluate(forgedCandidate, in: forgedContext, now: now).findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 {
                return reason.contains("本地 Quant 策略资格")
            }
            return false
        })

        let staleQualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", evaluatedAt: now.addingTimeInterval(-48 * 3600)))
        let staleGrant = FQuantStrategyQualificationGrant(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion", strategyVersion: "v3",
            observationID: staleQualification.id, evaluatedAt: now.addingTimeInterval(-48 * 3600))
        let staleContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, staleQualification, regime], strategyQualificationGrants: [staleGrant])
        XCTAssertTrue(FRiskGuard.evaluate(candidate, in: staleContext, now: now).findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 {
                return reason.contains("本地 Quant 策略资格")
            }
            return false
        })

        let freshQualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", evaluatedAt: now))
        let freshGrant = FQuantStrategyQualificationGrant(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion", strategyVersion: "v3",
            observationID: freshQualification.id, evaluatedAt: now)
        let mappedBenchmark = try mappedBenchmarkObservation()
        let qualifiedContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, freshQualification, regime, mappedBenchmark],
            strategyQualificationGrants: [freshGrant])
        let uncitedQualification = FCandidateRecommendation(accountDigest: qualifiedContext.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "未引用资格证据", citedObservationIDs: [quote.id, regime.id])
        XCTAssertTrue(FRiskGuard.evaluate(uncitedQualification, in: qualifiedContext, now: now)
            .findings.contains(.missingCitedEvidence(freshQualification.id)))
        let citedQualification = FCandidateRecommendation(accountDigest: qualifiedContext.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "引用合格策略和对应市场Regime",
            citedObservationIDs: [quote.id, freshQualification.id, regime.id, mappedBenchmark.id])
        XCTAssertTrue(FRiskGuard.evaluate(citedQualification, in: qualifiedContext, now: now).allowedForReview)

        let encodedContext = try JSONEncoder().encode(qualifiedContext)
        XCTAssertFalse(String(decoding: encodedContext, as: UTF8.self).contains("strategyQualificationGrants"))
        let restoredContext = try JSONDecoder().decode(FDecisionContext.self, from: encodedContext)
        XCTAssertFalse(FRiskGuard.evaluate(citedQualification, in: restoredContext, now: now).allowedForReview,
                       "Runtime qualification grants must not survive archive/JSON decoding")

        let bullRegime = securityRegimeObservation(regime: .bullTrend)
        let mismatchedRegimeContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, freshQualification, bullRegime],
            strategyQualificationGrants: [freshGrant])
        let mismatchedRegimeCandidate = FCandidateRecommendation(
            accountDigest: mismatchedRegimeContext.accountDigest, action: .buy,
            instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "震荡策略资格不得用于牛市",
            citedObservationIDs: [quote.id, freshQualification.id, bullRegime.id])
        XCTAssertTrue(FRiskGuard.evaluate(mismatchedRegimeCandidate,
            in: mismatchedRegimeContext, now: now).findings.contains {
                if case .incompleteTradingEvidence(let reason) = $0 {
                    return reason.contains("本地 Quant 策略资格")
                }
                return false
            })
    }

    func testFreshIOPVMustBeCitedByAssetChangingCandidate() throws {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(-10), fetchedAt: now,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352",
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, observedAt: metadata.quoteTimestamp,
            capturedAt: now, decimalValue: 1, quoteTemporalMetadata: metadata)
        let iopv = FContextObservation(dataClass: .iopv, subject: "159352",
            source: FMarketQuoteTrustPolicy.tencentReferenceSource,
            reference: "method=(ETF价格/IOPV-1)*100;unit=percent",
            observedAt: now.addingTimeInterval(-20), capturedAt: now,
            decimalValue: Decimal(string: "0.35"))
        let regime = securityRegimeObservation()
        let qualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", evaluatedAt: now))
        let grant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: .range,
            strategyID: "MeanReversion", strategyVersion: "v3",
            observationID: qualification.id, evaluatedAt: now)
        let mappedBenchmark = try mappedBenchmarkObservation()
        let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, iopv, regime, qualification, mappedBenchmark], strategyQualificationGrants: [grant])
        let uncited = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "基于当前行情评估",
            citedObservationIDs: [quote.id, regime.id, qualification.id, mappedBenchmark.id])

        XCTAssertTrue(FRiskGuard.evaluate(uncited, in: context, now: now)
            .findings.contains(.missingCitedEvidence(iopv.id)))
        let cited = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "已核对当前行情与IOPV折溢价",
            citedObservationIDs: [quote.id, iopv.id, regime.id, qualification.id, mappedBenchmark.id])
        XCTAssertFalse(FRiskGuard.evaluate(cited, in: context, now: now)
            .findings.contains(.missingCitedEvidence(iopv.id)))
    }

    func testDecisionContextRejectsForgedIOPVProviderOrMethod() throws {
        for observation in [
            FContextObservation(dataClass: .iopv, subject: "159352", source: "unknown-provider",
                reference: "method=(ETF价格/IOPV-1)*100;unit=percent", observedAt: now,
                capturedAt: now, decimalValue: 0.2),
            FContextObservation(dataClass: .iopv, subject: "159352",
                source: FMarketQuoteTrustPolicy.tencentReferenceSource,
                reference: "unverified-method", observedAt: now, capturedAt: now, decimalValue: 0.2)
        ] {
            let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
                                           observations: [observation])
            XCTAssertThrowsError(try context.validate(now: now))
        }
    }

    func testMappedETFBuyRequiresFreshOrderedBenchmarkAndBlocksSevereMappedRisk() throws {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(-10), fetchedAt: now,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352",
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, observedAt: metadata.quoteTimestamp,
            capturedAt: now, decimalValue: 1, quoteTemporalMetadata: metadata)
        let regime = securityRegimeObservation()
        let qualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", evaluatedAt: now))
        let grant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: .range,
            strategyID: "MeanReversion", strategyVersion: "v3",
            observationID: qualification.id, evaluatedAt: now)
        let mapped = try mappedBenchmarkObservation()

        for observations in [[quote, regime, qualification], [quote, regime, qualification, mapped]] {
            let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
                observations: observations, strategyQualificationGrants: [grant])
            let cited = FCandidateRecommendation(accountDigest: context.accountDigest,
                action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
                rationale: "核对ETF和A500市场状态",
                citedObservationIDs: observations.map(\.id))
            let result = FRiskGuard.evaluate(cited, in: context, now: now)
            if observations.contains(where: { $0.id == mapped.id }) {
                XCTAssertTrue(result.allowedForReview)
            } else {
                XCTAssertTrue(result.findings.contains {
                    if case .incompleteTradingEvidence(let reason) = $0 {
                        return reason.contains("对应市场Regime缺失")
                    }
                    return false
                })
            }
        }

        let stale = try mappedBenchmarkObservation(dataAsOf: now.addingTimeInterval(-6 * 86_400))
        let staleContext = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, regime, qualification, stale], strategyQualificationGrants: [grant])
        let staleCandidate = FCandidateRecommendation(accountDigest: staleContext.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "不能把过期A500状态当作当前依据",
            citedObservationIDs: [quote.id, regime.id, qualification.id, stale.id])
        XCTAssertTrue(FRiskGuard.evaluate(staleCandidate, in: staleContext, now: now).findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 {
                return reason.contains("对应市场Regime缺失")
            }
            return false
        })

        let futureRelativeToObservation = try mappedBenchmarkObservation(
            dataAsOf: now.addingTimeInterval(-5), observedAt: now.addingTimeInterval(-10))
        let futureContext = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, regime, qualification, futureRelativeToObservation],
            strategyQualificationGrants: [grant])
        let futureCandidate = FCandidateRecommendation(accountDigest: futureContext.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "指数数据时点不得晚于观察记录",
            citedObservationIDs: [quote.id, regime.id, qualification.id, futureRelativeToObservation.id])
        XCTAssertTrue(FRiskGuard.evaluate(futureCandidate, in: futureContext, now: now).findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 {
                return reason.contains("对应市场Regime缺失")
            }
            return false
        })

        let severe = try mappedBenchmarkObservation(regime: .extremeRisk, risk: .r4Extreme)
        let severeContext = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, regime, qualification, severe], strategyQualificationGrants: [grant])
        let severeCandidate = FCandidateRecommendation(accountDigest: severeContext.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "不得逆着A500极端风险低吸",
            citedObservationIDs: [quote.id, regime.id, qualification.id, severe.id])
        XCTAssertTrue(FRiskGuard.evaluate(severeCandidate, in: severeContext, now: now).findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 {
                return reason.contains("暂停普通买入候选")
            }
            return false
        })
    }

    func testMappedETFBuyRequiresStrategyAllowedByBothRegimes() throws {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(-10), fetchedAt: now,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource,
            timestampTrust: .verifiedExchangeTimestamp, marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352",
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, observedAt: metadata.quoteTimestamp,
            capturedAt: now, decimalValue: 1, quoteTemporalMetadata: metadata)

        let bullSecurityRegime = securityRegimeObservation(regime: .bullTrend)
        let meanReversionForBull = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .bullTrend, strategyID: "MeanReversion",
            strategyVersion: "v3", evaluatedAt: now))
        let bullGrant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: .bullTrend,
            strategyID: "MeanReversion", strategyVersion: "v3",
            observationID: meanReversionForBull.id, evaluatedAt: now)
        let rangeBenchmark = try mappedBenchmarkObservation(regime: .range)
        let securityMismatchContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, bullSecurityRegime, meanReversionForBull, rangeBenchmark],
            strategyQualificationGrants: [bullGrant])
        let securityMismatch = FCandidateRecommendation(accountDigest: securityMismatchContext.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "Bull不允许均值回归买入",
            citedObservationIDs: [quote.id, bullSecurityRegime.id, meanReversionForBull.id, rangeBenchmark.id])
        XCTAssertTrue(FRiskGuard.evaluate(securityMismatch, in: securityMismatchContext, now: now).findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 { return reason.contains("不允许该资格凭证对应的策略") }
            return false
        })

        let rangeSecurityRegime = securityRegimeObservation(regime: .range)
        let rangeQualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", evaluatedAt: now))
        let rangeGrant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: .range,
            strategyID: "MeanReversion", strategyVersion: "v3",
            observationID: rangeQualification.id, evaluatedAt: now)
        let bearBenchmark = try mappedBenchmarkObservation(regime: .bearTrend, risk: .r2High)
        let mappedMismatchContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, rangeSecurityRegime, rangeQualification, bearBenchmark],
            strategyQualificationGrants: [rangeGrant])
        let mappedMismatch = FCandidateRecommendation(accountDigest: mappedMismatchContext.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "A500下行状态不允许均值回归买入",
            citedObservationIDs: [quote.id, rangeSecurityRegime.id, rangeQualification.id, bearBenchmark.id])
        XCTAssertTrue(FRiskGuard.evaluate(mappedMismatch, in: mappedMismatchContext, now: now).findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 { return reason.contains("不允许该资格凭证对应的策略") }
            return false
        })
    }

    func testRiskGuardRequiresFreshMatchingRegimeAndBlocksSevereBuyRisk() throws {
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: now.addingTimeInterval(-10), fetchedAt: now,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp, marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352", source: FMarketQuoteTrustPolicy.tencentMinuteSource,
            observedAt: metadata.quoteTimestamp, capturedAt: now, decimalValue: 1,
            quoteTemporalMetadata: metadata)
        let qualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion", strategyVersion: "v3", evaluatedAt: now))
        let grant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", observationID: qualification.id, evaluatedAt: now)
        let observations = [quote]

        let wrongSecurityRegime = securityRegimeObservation(securityCode: "000001")
        let wrongSecurityContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: observations + [qualification, wrongSecurityRegime], strategyQualificationGrants: [grant])
        let wrongSecurityCandidate = FCandidateRecommendation(
            accountDigest: wrongSecurityContext.accountDigest, action: .buy,
            instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "不能把上证Regime挪给ETF自身",
            citedObservationIDs: [quote.id, qualification.id, wrongSecurityRegime.id])
        let wrongSecurityResult = FRiskGuard.evaluate(wrongSecurityCandidate,
            in: wrongSecurityContext, now: now)
        XCTAssertTrue(wrongSecurityResult.findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 { return reason.contains("Market Regime") }
            return false
        })

        let regimeTimeInFutureOfItsObservation = securityRegimeObservation(
            dataAsOf: now.addingTimeInterval(-10), observedAt: now.addingTimeInterval(-20),
            capturedAt: now.addingTimeInterval(-15))
        let inconsistentTimeContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: observations + [qualification, regimeTimeInFutureOfItsObservation],
            strategyQualificationGrants: [grant])
        let inconsistentTimeCandidate = FCandidateRecommendation(
            accountDigest: inconsistentTimeContext.accountDigest, action: .buy,
            instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "Regime数据不能晚于其自身评估/采集时点",
            citedObservationIDs: [quote.id, qualification.id, regimeTimeInFutureOfItsObservation.id])
        XCTAssertTrue(FRiskGuard.evaluate(inconsistentTimeCandidate,
            in: inconsistentTimeContext, now: now).findings.contains {
                if case .incompleteTradingEvidence(let reason) = $0 {
                    return reason.contains("Market Regime")
                }
                return false
            })

        let citedRegime = securityRegimeObservation()
        let citedRegimeContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: observations + [qualification, citedRegime], strategyQualificationGrants: [grant])
        let uncitedRegimeCandidate = FCandidateRecommendation(
            accountDigest: citedRegimeContext.accountDigest, action: .buy,
            instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "Regime必须被引用",
            citedObservationIDs: [quote.id, qualification.id])
        XCTAssertTrue(FRiskGuard.evaluate(uncitedRegimeCandidate, in: citedRegimeContext, now: now)
            .findings.contains(.missingCitedEvidence(citedRegime.id)))

        let conflictingRegime = securityRegimeObservation(regime: .bearTrend, risk: .r2High)
        let conflictingContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: observations + [qualification, citedRegime, conflictingRegime],
            strategyQualificationGrants: [grant])
        let conflictingCandidate = FCandidateRecommendation(
            accountDigest: conflictingContext.accountDigest, action: .buy,
            instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "相互冲突的同证券Regime不得按数组顺序挑选",
            citedObservationIDs: [quote.id, qualification.id, citedRegime.id, conflictingRegime.id])
        XCTAssertTrue(FRiskGuard.evaluate(conflictingCandidate, in: conflictingContext, now: now)
            .findings.contains {
                if case .incompleteTradingEvidence(let reason) = $0 { return reason.contains("Market Regime") }
                return false
            })

        for (regime, risk) in [(FMarketRegime.extremeRisk, FMarketRiskLevel.r4Extreme),
                               (.riskOff, .r3Severe), (.bullTrend, .r3Severe),
                               (.dataUnreliable, .r0Normal)] {
            let regimeObservation = securityRegimeObservation(regime: regime, risk: risk)
            let regimeQualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
                securityCode: "159352", regime: regime, strategyID: "MeanReversion",
                strategyVersion: "v3", evaluatedAt: now))
            let regimeGrant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: regime,
                strategyID: "MeanReversion", strategyVersion: "v3",
                observationID: regimeQualification.id, evaluatedAt: now)
            let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
                observations: observations + [regimeQualification, regimeObservation],
                strategyQualificationGrants: [regimeGrant])
            let candidate = FCandidateRecommendation(accountDigest: context.accountDigest,
                action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
                rationale: "需要遵从市场风险状态",
                citedObservationIDs: [quote.id, regimeQualification.id, regimeObservation.id])
            XCTAssertFalse(FRiskGuard.evaluate(candidate, in: context, now: now).allowedForReview,
                           "\(regime.rawValue)/R\(risk.rawValue)必须阻止普通买入")
        }

        let staleRegime = securityRegimeObservation(dataAsOf: now.addingTimeInterval(-6 * 86_400))
        let rangeQualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", evaluatedAt: now))
        let rangeGrant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: .range,
            strategyID: "MeanReversion", strategyVersion: "v3",
            observationID: rangeQualification.id, evaluatedAt: now)
        let staleContext = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: observations + [rangeQualification, staleRegime], strategyQualificationGrants: [rangeGrant])
        let staleCandidate = FCandidateRecommendation(accountDigest: staleContext.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: 1,
            rationale: "过期Regime不得放行",
            citedObservationIDs: [quote.id, rangeQualification.id, staleRegime.id])
        let staleResult = FRiskGuard.evaluate(staleCandidate, in: staleContext, now: now)
        XCTAssertFalse(staleResult.allowedForReview)
        XCTAssertTrue(staleResult.findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 { return reason.contains("Market Regime") }
            return false
        })
    }

    func testRiskGuardRejectsBuyLimitAboveLatestPriceAsChasing() throws {
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: now.addingTimeInterval(-10), fetchedAt: now,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp, marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352", source: FMarketQuoteTrustPolicy.tencentMinuteSource,
            observedAt: metadata.quoteTimestamp, capturedAt: now, decimalValue: 1,
            quoteTemporalMetadata: metadata)
        let qualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion", strategyVersion: "v3", evaluatedAt: now))
        let grant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", observationID: qualification.id, evaluatedAt: now)
        let regime = securityRegimeObservation()
        let mappedBenchmark = try mappedBenchmarkObservation()
        let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
            observations: [quote, qualification, regime, mappedBenchmark], strategyQualificationGrants: [grant])
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .buy,
            instrumentCode: "159352", units: 100, limitPrice: Decimal(string: "1.001")!,
            rationale: "当前价1.000，不得上调限价追买",
            citedObservationIDs: [quote.id, qualification.id, regime.id, mappedBenchmark.id])

        let result = FRiskGuard.evaluate(candidate, in: context, now: now)
        XCTAssertFalse(result.allowedForReview)
        XCTAssertTrue(result.findings.contains {
            if case .incompleteTradingEvidence(let reason) = $0 { return reason.contains("避免追价") }
            return false
        })
    }

    func testCandidateCreationCannotWriteTheLedger() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FAccountBookStore(fileURL: folder.appendingPathComponent("account.json"))
        let writer = FConfirmedLedgerWriter(store: store)
        _ = try await writer.confirmInitialLedger(makeBook(), confirmation: confirmed(), now: now)
        let before = try await store.currentDigest(now: now)
        let context = try await FDecisionContext.capture(from: store, observations: [], now: now)
        let captured = try XCTUnwrap(context)
        let candidate = FCandidateRecommendation(accountDigest: captured.accountDigest, action: .wait,
                                                 rationale: "等待更多信息")
        XCTAssertTrue(FDecisionGuards.evaluate(candidate, in: captured, now: now).allowedForReview)
        let after = try await store.currentDigest(now: now)
        XCTAssertEqual(after, before)
    }

    func testInitialLedgerConfirmationPersistsAuditedAccountSnapshot() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FAccountBookStore(fileURL: folder.appendingPathComponent("account.json"))
        let writer = FConfirmedLedgerWriter(store: store)
        let openingPosition = FPosition(instrumentCode: "159352", name: "A500 ETF",
                                        units: 500, bookCost: 602.50,
                                        brokerDisplayCostPerUnit: 1.19,
                                        brokerDisplayCostUpdatedAt: now)
        let opening = FAccountOpeningSnapshot(capturedAt: now, cashBalance: 1_200,
                                              positions: [openingPosition])
        let book = FAccountBook(openingSnapshot: opening, cashBalance: 1_200,
                                positions: [openingPosition], updatedAt: now)
        let confirmation = FUserLedgerConfirmation(confirmedAt: now,
                                                   confirmationNote: "按券商当前真实账户录入")

        _ = try await writer.confirmInitialLedger(book, confirmation: confirmation, now: now)
        let maybeSaved = try await store.load(now: now)
        let saved = try XCTUnwrap(maybeSaved)
        XCTAssertEqual(saved.fills, [])
        XCTAssertEqual(saved.positions, [openingPosition])
        XCTAssertEqual(saved.audits.count, 1)
        XCTAssertEqual(saved.audits[0].action, "用户确认录入初始真实账户快照")
        XCTAssertEqual(saved.audits[0].reason, confirmation.confirmationNote)
        XCTAssertNil(saved.audits[0].priorLedgerDigest)
    }

    func testAdvisorDocumentsPersistInSeparateStoresAndAreIdempotent() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let ledger = FAccountBookStore(fileURL: folder.appendingPathComponent("account.json"))
        let writer = FConfirmedLedgerWriter(store: ledger)
        _ = try await writer.confirmInitialLedger(makeBook(), confirmation: confirmed(), now: now)
        let maybeSnapshot = try await ledger.readLedgerSnapshot(now: now)
        let snapshot = try XCTUnwrap(maybeSnapshot)
        let context = FDecisionContext(snapshot: snapshot, observations: [], researchEvidence: [
            try researchReference(id: String(repeating: "a", count: 64),
                                  generatedAt: now.addingTimeInterval(-30)),
            try researchReference(id: String(repeating: "b", count: 64),
                                  generatedAt: now.addingTimeInterval(-20))
        ])
        try context.validate(now: now)
        let ledgerDigestBeforeAdvisorWrites = try await ledger.currentDigest(now: now)
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .wait,
                                                 rationale: "继续观察")
        let memoryRequest = try FAdvisorQuestionRequest(question: "组合决策记忆测试",
            scope: .portfolio, decisionContext: context, now: now)
        let memory = try FDecisionMemory(context: context, candidate: candidate,
                                         recommendation: "持有", rationale: "当前无新证据",
                                         advisorRequest: memoryRequest)
        let contextStore = FDecisionContextStore(directory: folder)
        let memoryStore = FDecisionMemoryStore(directory: folder)
        let profileStore = FInvestorProfileStore(directory: folder)
        let contextDigest = try await contextStore.append(context, expectedPriorDigest: nil, now: now)
        let contextRepeat = try await contextStore.append(context, expectedPriorDigest: contextDigest, now: now)
        let memoryDigest = try await memoryStore.append(memory, expectedPriorDigest: nil, now: now)
        let memoryRepeat = try await memoryStore.append(memory, expectedPriorDigest: memoryDigest, now: now)
        var profile = FInvestorProfile()
        _ = try profile.record(FInvestorProfileRevision(value: .text("15年以上"), confidence: 1,
                                                        source: .explicit, updatedAt: now,
                                                        explanation: "用户明确说明"),
                               for: .investmentHorizon, now: now)
        _ = try await profileStore.save(profile, expectedPriorDigest: nil, now: now)
        let ledgerDigestAfterAdvisorWrites = try await ledger.currentDigest(now: now)
        XCTAssertEqual(contextRepeat, contextDigest)
        XCTAssertEqual(memoryRepeat, memoryDigest)
        XCTAssertEqual(ledgerDigestAfterAdvisorWrites, ledgerDigestBeforeAdvisorWrites)
        let loadedContextArchive = try await FDecisionContextStore(directory: folder).load(now: now)
        let loadedMemoryArchive = try await FDecisionMemoryStore(directory: folder).load(now: now)
        XCTAssertEqual(loadedContextArchive?.contexts, [context])
        XCTAssertEqual(loadedMemoryArchive?.records, [memory])
        let memoryStoreForMigration = FDecisionMemoryStore(directory: folder)
        let migrationBefore = try await memoryStoreForMigration.currentDigest(now: now)
        let maybeFirstDryRun = try await memoryStoreForMigration.migrationDryRun(now: now)
        let maybeSecondDryRun = try await memoryStoreForMigration.migrationDryRun(now: now)
        let firstDryRun = try XCTUnwrap(maybeFirstDryRun)
        let secondDryRun = try XCTUnwrap(maybeSecondDryRun)
        XCTAssertEqual(firstDryRun, secondDryRun)
        XCTAssertTrue(firstDryRun.isEligible)
        XCTAssertEqual(firstDryRun.recordCount, 1)
        XCTAssertEqual(firstDryRun.duplicateIDs, [])
        XCTAssertEqual(firstDryRun.orderingViolationIDs, [])
        XCTAssertEqual(firstDryRun.invalidRecordIDs, [])
        XCTAssertEqual(firstDryRun.rejectionReasons, [])
        XCTAssertEqual(firstDryRun.shards.map(\.stableKey).count, 1)
        let migrationAfter = try await memoryStoreForMigration.currentDigest(now: now)
        XCTAssertEqual(migrationAfter, migrationBefore)
        let duplicatePlan = try FDecisionMemoryMigrationPlan(
            records: [memory, memory], sourceDigest: try XCTUnwrap(migrationBefore), now: now)
        XCTAssertFalse(duplicatePlan.isEligible)
        XCTAssertEqual(duplicatePlan.duplicateIDs, [memory.id])
        XCTAssertEqual(duplicatePlan.rejectionReasons, ["duplicate-record-ids"])
        var rejectedDuplicatePlan = false
        do {
            _ = try await memoryStoreForMigration.materializeSegmentedArchive(
                using: duplicatePlan, now: now)
            XCTFail("ineligible migration plan unexpectedly wrote a generation")
        } catch let error as FAdvisorPersistenceError {
            if case .corruptDocument(_) = error { rejectedDuplicatePlan = true }
        }
        XCTAssertTrue(rejectedDuplicatePlan)
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            folder.appendingPathComponent("decision-memory-segmented", isDirectory: true).path))
        let migrationArchive = try XCTUnwrap(loadedMemoryArchive)
        let faultPoints: [FSegmentedDecisionMemoryStore.FaultPoint] = [
            .afterRecordWrite, .afterIndexWrite, .afterManifestWrite,
            .afterGenerationRename, .beforeCurrentCommit, .afterCurrentWrite
        ]
        for faultPoint in faultPoints {
            let faultIndex = try XCTUnwrap(faultPoints.firstIndex(of: faultPoint))
            let faultDirectory = folder.appendingPathComponent("fault-\(faultIndex)",
                                                               isDirectory: true)
            let interruptedStore = FSegmentedDecisionMemoryStore(directory: faultDirectory) { point in
                if point == faultPoint {
                    throw FAdvisorPersistenceError.corruptDocument("injected interruption")
                }
            }
            var didInject = false
            do {
                _ = try await interruptedStore.install(archive: migrationArchive,
                                                       plan: firstDryRun,
                                                       expectedSourceDigest: firstDryRun.sourceDigest,
                                                       expectedPriorGenerationID: nil, now: now)
                XCTFail("fault injection did not interrupt migration")
            } catch let error as FAdvisorPersistenceError {
                XCTAssertEqual(error, .corruptDocument("injected interruption"))
                didInject = true
            } catch {
                XCTFail("unexpected fault injection error: \(error)")
            }
            XCTAssertTrue(didInject)
            let interruptedDigest = try await interruptedStore.currentSourceDigest()
            XCTAssertNil(interruptedDigest)
            let resumedStore = FSegmentedDecisionMemoryStore(directory: faultDirectory)
            let resumed = try await resumedStore.install(archive: migrationArchive,
                                                         plan: firstDryRun,
                                                         expectedSourceDigest: firstDryRun.sourceDigest,
                                                         expectedPriorGenerationID: nil, now: now)
            XCTAssertEqual(resumed.recordCount, migrationArchive.records.count)
        }
        let firstMaterialization = try await memoryStoreForMigration.materializeSegmentedArchive(
            using: firstDryRun, now: now)
        XCTAssertFalse(firstMaterialization.wasAlreadyCommitted)
        let repeatedMaterialization = try await memoryStoreForMigration.materializeSegmentedArchive(
            using: firstDryRun, now: now)
        XCTAssertTrue(repeatedMaterialization.wasAlreadyCommitted)
        XCTAssertEqual(firstMaterialization.sourceDigest, repeatedMaterialization.sourceDigest)
        XCTAssertEqual(firstMaterialization.generationID, repeatedMaterialization.generationID)
        XCTAssertEqual(firstMaterialization.recordCount, repeatedMaterialization.recordCount)
        let segmentedBackupURL = folder.appendingPathComponent("decision-memory-segmented.backup",
                                                              isDirectory: true)
        let segmentedBackup = try await memoryStoreForMigration.createSegmentedBackup(
            at: segmentedBackupURL)
        XCTAssertEqual(segmentedBackup.generationID, firstMaterialization.generationID)
        let segmentedStorage = FSegmentedDecisionMemoryStore(
            directory: folder.appendingPathComponent("decision-memory-segmented", isDirectory: true))
        try await segmentedStorage.invalidateCurrent()
        let restoredSegment = try await memoryStoreForMigration.restoreSegmentedBackup(
            from: segmentedBackupURL, expectedPriorGenerationID: nil, now: now)
        XCTAssertFalse(restoredSegment.wasAlreadyCurrent)
        XCTAssertEqual(restoredSegment.generationID, firstMaterialization.generationID)
        let segmentedProjection = try await memoryStoreForMigration.recentProjection(
            accountID: context.accountID, scope: .portfolio, asOf: now, now: now)
        XCTAssertEqual(segmentedProjection?.entries.map(\.id), [memory.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("decision-context-v1.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("decision-memory-v1.json").path))
        let assembler = FAdvisorRequestAssembler(profileStore: profileStore, memoryStore: memoryStore)
        let assembledRequest = try await assembler.assemble(question: "为什么今天建议和昨天不一样？",
                                                             scope: .portfolio,
                                                             decisionContext: context, now: now)
        XCTAssertEqual(assembledRequest.investorProfile?.preferences.first?.value, .text("15年以上"))
        XCTAssertEqual(assembledRequest.decisionMemory?.entries.map(\.id), [memory.id])
        let assembledGuard = FDecisionGuards.evaluate(candidate, in: context,
                                                       using: assembledRequest, now: now)
        XCTAssertTrue(assembledGuard.allowedForReview)
        let profileRevisionID = try XCTUnwrap(profile.attribute(.investmentHorizon)?.current(at: now)?.id)
        let citedCandidate = FCandidateRecommendation(
            accountDigest: context.accountDigest, action: .wait, rationale: "引用本次上下文",
            citedDecisionMemoryIDs: [memory.id],
            citedInvestorProfileRevisionIDs: [profileRevisionID])
        let citedGuard = FDecisionGuards.evaluate(citedCandidate, in: context,
                                                   using: assembledRequest, now: now)
        XCTAssertTrue(citedGuard.allowedForReview)
        let unknownProfileCandidate = FCandidateRecommendation(
            accountDigest: context.accountDigest, action: .wait, rationale: "引用不存在的画像",
            citedInvestorProfileRevisionIDs: [UUID()])
        let unknownProfileGuard = FAIGuard.evaluate(unknownProfileCandidate, in: context,
            using: assembledRequest, now: now)
        XCTAssertTrue(unknownProfileGuard.findings.contains {
            if case .missingInvestorProfileRevision = $0 { return true }
            return false
        })
        let unknownMemoryCandidate = FCandidateRecommendation(
            accountDigest: context.accountDigest, action: .wait, rationale: "引用不存在的历史",
            citedDecisionMemoryIDs: [UUID()])
        let unknownMemoryGuard = FAIGuard.evaluate(unknownMemoryCandidate, in: context,
                                                    using: assembledRequest, now: now)
        XCTAssertTrue(unknownMemoryGuard.findings.contains {
            if case .missingDecisionMemory = $0 { return true }
            return false
        })
        XCTAssertThrowsError(try FDecisionMemory(context: context, candidate: citedCandidate,
                                                  recommendation: "没有request不能保存引用",
                                                  rationale: "fail closed"))
        let citedMemory = try FDecisionMemory(context: context, candidate: citedCandidate,
                                              recommendation: "持有", rationale: "保留引用",
                                              advisorRequest: assembledRequest)
        XCTAssertTrue(citedMemory.evidence.contains { $0.kind == .decisionMemory })
        XCTAssertTrue(citedMemory.evidence.contains { $0.kind == .investorProfile })
        let unrelatedContext = FDecisionContext(
            snapshot: try makeBook().readOnlySnapshot(capturedAt: now), observations: [])
        let unrelatedRequest = try FAdvisorQuestionRequest(question: "另一账户请求",
                                                            scope: .portfolio,
                                                            decisionContext: unrelatedContext, now: now)
        let mismatchedGuard = FDecisionGuards.evaluate(candidate, in: context,
                                                        using: unrelatedRequest, now: now)
        XCTAssertFalse(mismatchedGuard.allowedForReview)
        XCTAssertTrue(mismatchedGuard.findings.contains(.advisorRequestContextMismatch))
        var legacyRequestObject = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(assembledRequest)) as? [String: Any])
        legacyRequestObject.removeValue(forKey: "decisionContextCreatedAt")
        legacyRequestObject.removeValue(forKey: "portfolioContext")
        legacyRequestObject.removeValue(forKey: "decisionMemory")
        legacyRequestObject.removeValue(forKey: "investorProfile")
        let legacyRequestBytes = try JSONSerialization.data(withJSONObject: legacyRequestObject,
                                                            options: [.sortedKeys])
        let unboundLegacyRequest = try JSONDecoder().decode(FAdvisorQuestionRequest.self,
                                                            from: legacyRequestBytes)
        let unboundGuard = FAIGuard.evaluate(candidate, in: context,
                                            using: unboundLegacyRequest, now: now)
        XCTAssertTrue(unboundGuard.findings.contains(.advisorRequestContextMismatch))
        let riskQuoteMetadata = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(-10), fetchedAt: now,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352",
                                        source: FMarketQuoteTrustPolicy.tencentMinuteSource,
                                        observedAt: riskQuoteMetadata.quoteTimestamp,
                                        capturedAt: now, decimalValue: Decimal(string: "1e126")!,
                                        quoteTemporalMetadata: riskQuoteMetadata)
        let riskQualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion", strategyVersion: "v3", evaluatedAt: now))
        let riskGrant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", observationID: riskQualification.id, evaluatedAt: now)
        let riskRegime = securityRegimeObservation()
        let riskBenchmark = try mappedBenchmarkObservation()
        let quoteSnapshot = try makeBook().readOnlySnapshot(capturedAt: now)
        let riskContext = FDecisionContext(snapshot: quoteSnapshot,
            observations: [quote, riskQualification, riskRegime, riskBenchmark],
            strategyQualificationGrants: [riskGrant])
        let oversizedPrice = try XCTUnwrap(Decimal(string: "1e126"))
        let overflowingCandidate = FCandidateRecommendation(
            accountDigest: riskContext.accountDigest, action: .buy, instrumentCode: "159352",
            units: FMainlandFundTradingRules.maximumOrderUnits, limitPrice: oversizedPrice,
            rationale: "超界算术必须拒绝",
            citedObservationIDs: [quote.id, riskQualification.id, riskRegime.id, riskBenchmark.id])
        let overflowGuard = FRiskGuard.evaluate(overflowingCandidate, in: riskContext, now: now)
        XCTAssertFalse(overflowGuard.allowedForReview)
        XCTAssertTrue(overflowGuard.findings.contains(.invalidCandidate) ||
                      overflowGuard.findings.contains(.insufficientCash))
        let fetchedAt = now.addingTimeInterval(-10)
        let unverifiedQuoteMetadata = FQuoteTemporalMetadata(
            quoteTimestamp: nil, fetchedAt: fetchedAt, source: "provider",
            timestampTrust: .fetchedAtOnly, marketSessionStatus: .continuous)
        let unverifiedQuote = FContextObservation(dataClass: .quote, subject: "159352",
                                                 source: "provider", observedAt: nil,
                                                 capturedAt: now, decimalValue: 1,
                                                 quoteTemporalMetadata: unverifiedQuoteMetadata)
        let unverifiedContext = FDecisionContext(snapshot: quoteSnapshot,
                                                 observations: [unverifiedQuote])
        let unverifiedCandidate = FCandidateRecommendation(
            accountDigest: unverifiedContext.accountDigest, action: .wait,
            rationale: "仅记录本机获取时间")
        let unverifiedMemory = try FDecisionMemory(context: unverifiedContext,
                                                   candidate: unverifiedCandidate,
                                                   recommendation: "等待",
                                                   rationale: "行情时间未验证")
        XCTAssertEqual(unverifiedMemory.evidence.first?.observedAt, fetchedAt)
        XCTAssertEqual(unverifiedMemory.evidence.first?.timestampTrust, .fetchedAtOnly)
        XCTAssertTrue(unverifiedMemory.evidence.first?.isStale ?? false)
        let ledgerDigestAfterAssembly = try await ledger.currentDigest(now: now)
        XCTAssertEqual(ledgerDigestAfterAssembly, ledgerDigestBeforeAdvisorWrites)

        let contextBackup = folder.appendingPathComponent("decision-context.backup.json")
        let memoryBackup = folder.appendingPathComponent("decision-memory.backup.json")
        _ = try await contextStore.createBackup(at: contextBackup, now: now)
        _ = try await memoryStore.createBackup(at: memoryBackup, now: now)
        let later = now.addingTimeInterval(30)
        let maybeNextContext = try await FDecisionContext.capture(from: ledger, observations: [], now: later)
        let nextContext = try XCTUnwrap(maybeNextContext)
        let nextCandidate = FCandidateRecommendation(accountDigest: nextContext.accountDigest,
                                                     action: .wait, rationale: "新增记录")
        let nextMemory = try FDecisionMemory(context: nextContext, candidate: nextCandidate,
                                             recommendation: "等待", rationale: "后续记录")
        let unsortedPlan = try FDecisionMemoryMigrationPlan(
            records: [nextMemory, memory], sourceDigest: memoryDigest, now: later)
        XCTAssertFalse(unsortedPlan.isEligible)
        XCTAssertEqual(unsortedPlan.orderingViolationIDs, [memory.id])
        XCTAssertEqual(unsortedPlan.rejectionReasons, ["non-canonical-source-order"])
        let frozenMemoryProjection = try FAdvisorDecisionMemoryProjection(
            records: [memory, nextMemory], accountID: context.accountID, scope: .portfolio,
            asOf: context.createdAt, validatedAt: later)
        XCTAssertEqual(frozenMemoryProjection.entries.map(\.id), [memory.id])
        XCTAssertTrue(frozenMemoryProjection.isValid(accountID: context.accountID,
                                                     scope: .portfolio, asOf: context.createdAt))
        let projectionEncoder = JSONEncoder()
        projectionEncoder.dateEncodingStrategy = .millisecondsSince1970
        var forgedProjection = try XCTUnwrap(JSONSerialization.jsonObject(
            with: projectionEncoder.encode(frozenMemoryProjection)) as? [String: Any])
        var forgedEntries = try XCTUnwrap(forgedProjection["entries"] as? [[String: Any]])
        forgedEntries[0]["decidedAt"] = (context.createdAt.addingTimeInterval(1).timeIntervalSince1970) * 1_000
        forgedProjection["entries"] = forgedEntries
        let forgedDecoder = JSONDecoder()
        forgedDecoder.dateDecodingStrategy = .millisecondsSince1970
        let decodedFutureMemory = try forgedDecoder.decode(FAdvisorDecisionMemoryProjection.self,
            from: JSONSerialization.data(withJSONObject: forgedProjection, options: [.sortedKeys]))
        XCTAssertFalse(decodedFutureMemory.isValid(accountID: context.accountID,
                                                   scope: .portfolio, asOf: context.createdAt))
        let newerContextDigest = try await contextStore.append(nextContext,
                                                               expectedPriorDigest: contextRepeat, now: later)
        let newerMemoryDigest = try await memoryStore.append(nextMemory,
                                                             expectedPriorDigest: memoryRepeat, now: later)
        do {
            _ = try await memoryStore.restoreSegmentedBackup(from: segmentedBackupURL,
                                                             expectedPriorGenerationID: nil,
                                                             now: later)
            XCTFail("stale segmented backup unexpectedly replaced newer Memory")
        } catch let error as FAdvisorPersistenceError {
            guard case .concurrentModification = error else {
                return XCTFail("unexpected segmented restore error: \(error)")
            }
        }
        do {
            _ = try await memoryStore.materializeSegmentedArchive(using: firstDryRun, now: later)
            XCTFail("stale migration plan unexpectedly installed a generation")
        } catch let error as FAdvisorPersistenceError {
            guard case .concurrentModification = error else {
                return XCTFail("unexpected stale migration error: \(error)")
            }
        }
        let maybeAfterAppendPlan = try await memoryStore.migrationDryRun(now: later)
        let afterAppendPlan = try XCTUnwrap(maybeAfterAppendPlan)
        let afterAppendReceipt = try await memoryStore.materializeSegmentedArchive(
            using: afterAppendPlan, now: later)
        XCTAssertEqual(afterAppendReceipt.recordCount, 2)
        let afterAppendProjection = try await memoryStore.recentProjection(
            accountID: context.accountID, scope: .portfolio, asOf: later, now: later)
        XCTAssertEqual(afterAppendProjection?.entries.map(\.id), [nextMemory.id, memory.id])
        let boundedMemoryProjection = try await memoryStore.recentProjection(
            accountID: context.accountID, scope: .portfolio, asOf: context.createdAt, now: later)
        XCTAssertEqual(boundedMemoryProjection?.entries.map(\.id), [memory.id])
        _ = try await contextStore.restoreBackup(from: contextBackup,
                                                 expectedPriorDigest: newerContextDigest, now: later)
        _ = try await memoryStore.restoreBackup(from: memoryBackup,
                                                expectedPriorDigest: newerMemoryDigest, now: later)
        let restoredContextArchive = try await contextStore.load(now: later)
        let restoredMemoryArchive = try await memoryStore.load(now: later)
        let projectionAfterRestore = try await memoryStore.recentProjection(
            accountID: context.accountID, scope: .portfolio, asOf: later, now: later)
        let ledgerDigestAfterRestore = try await ledger.currentDigest(now: later)
        XCTAssertEqual(restoredContextArchive?.contexts, [context])
        XCTAssertEqual(restoredMemoryArchive?.records, [memory])
        XCTAssertEqual(projectionAfterRestore?.entries.map(\.id), [memory.id])
        XCTAssertEqual(ledgerDigestAfterRestore, ledgerDigestBeforeAdvisorWrites)
        XCTAssertEqual(restoredContextArchive?.contexts.first?.researchEvidence.map(\.id),
                       context.researchEvidence.map(\.id))
        XCTAssertEqual(restoredContextArchive?.contexts.first?.researchEvidenceVersionConflicts(at: later)
            .first?.selectedEvidenceID, context.researchEvidence.last?.id)
        let restoredContextDigest = try await contextStore.currentDigest(now: later)
        let restoredMemoryDigest = try await memoryStore.currentDigest(now: later)
        do {
            _ = try await contextStore.restoreBackup(from: contextBackup,
                                                     expectedPriorDigest: newerContextDigest, now: later)
            XCTFail("stale context digest unexpectedly restored a backup")
        } catch let error as FAdvisorPersistenceError {
            guard case .concurrentModification = error else {
                return XCTFail("unexpected context restore error: \(error)")
            }
        }
        do {
            _ = try await memoryStore.restoreBackup(from: memoryBackup,
                                                    expectedPriorDigest: newerMemoryDigest, now: later)
            XCTFail("stale memory digest unexpectedly restored a backup")
        } catch let error as FAdvisorPersistenceError {
            guard case .concurrentModification = error else {
                return XCTFail("unexpected memory restore error: \(error)")
            }
        }
        let contextDigestAfterRejectedRestore = try await contextStore.currentDigest(now: later)
        let memoryDigestAfterRejectedRestore = try await memoryStore.currentDigest(now: later)
        XCTAssertEqual(contextDigestAfterRejectedRestore, restoredContextDigest)
        XCTAssertEqual(memoryDigestAfterRejectedRestore, restoredMemoryDigest)
    }

    func testCorruptAdvisorDocumentFailsClosed() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FInvestorProfileStore(directory: folder)
        _ = try await store.save(FInvestorProfile(), expectedPriorDigest: nil, now: now)
        try Data("{corrupt".utf8).write(to: folder.appendingPathComponent("investor-profile-v1.json"))
        do {
            let ignored = try await store.load(now: now)
            XCTFail("corrupt data unexpectedly loaded: \(String(describing: ignored))")
        } catch let error as FAdvisorPersistenceError {
            guard case .corruptDocument = error else { return XCTFail("unexpected error: \(error)") }
        }
    }

    func testBlankUserConfirmationLeavesLedgerDigestUnchanged() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FAccountBookStore(fileURL: folder.appendingPathComponent("account.json"))
        let writer = FConfirmedLedgerWriter(store: store)
        _ = try await writer.confirmInitialLedger(makeBook(), confirmation: confirmed(), now: now)
        let before = try await store.currentDigest(now: now)
        let fill = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "159941", side: .buy,
                                  units: 100, price: 1, fee: 0,
                                  userConfirmation: .init(confirmedAt: now, confirmationNote: "  "))
        do {
            _ = try await writer.confirmFill(fill, instrumentName: "纳指 ETF", now: now)
            XCTFail("blank confirmation unexpectedly wrote the ledger")
        } catch { }
        let after = try await store.currentDigest(now: now)
        XCTAssertEqual(after, before)
    }

    func testDuplicateConfirmedFillCannotBeWrittenTwice() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FAccountBookStore(fileURL: folder.appendingPathComponent("account.json"))
        let writer = FConfirmedLedgerWriter(store: store)
        _ = try await writer.confirmInitialLedger(makeBook(), confirmation: confirmed(), now: now)
        let fill = FConfirmedFill(sequence: 1, tradedAt: now, instrumentCode: "159941", side: .buy,
                                  units: 100, price: 1, fee: 0, userConfirmation: confirmed())
        _ = try await writer.confirmFill(fill, instrumentName: "纳指 ETF", now: now)
        let afterFirst = try await store.currentDigest(now: now)
        do {
            _ = try await writer.confirmFill(fill, instrumentName: "纳指 ETF", now: now)
            XCTFail("duplicate fill unexpectedly accepted")
        } catch let error as FLedgerMutationError {
            XCTAssertEqual(error, .duplicateFill(fill.id))
        }
        let afterRepeat = try await store.currentDigest(now: now)
        XCTAssertEqual(afterRepeat, afterFirst)
    }

    func testConcurrentLedgerStoreInstancesDoNotLoseConfirmedMovements() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("account.json")
        let firstStore = FAccountBookStore(fileURL: path)
        let secondStore = FAccountBookStore(fileURL: path)
        let firstWriter = FConfirmedLedgerWriter(store: firstStore)
        let secondWriter = FConfirmedLedgerWriter(store: secondStore)
        _ = try await firstWriter.confirmInitialLedger(makeBook(), confirmation: confirmed(), now: now)

        let fixedNow = now
        let confirmation = confirmed()
        let firstMovement = FCashMovement(sequence: 1, occurredAt: fixedNow, amount: 10,
                                          reason: "并发入金A", userConfirmation: confirmation)
        let secondMovement = FCashMovement(sequence: 1, occurredAt: fixedNow, amount: 10,
                                           reason: "并发入金B", userConfirmation: confirmation)
        let outcomes = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                do {
                    _ = try await firstWriter.confirmCashMovement(firstMovement, now: fixedNow)
                    return true
                } catch { return false }
            }
            group.addTask {
                do {
                    _ = try await secondWriter.confirmCashMovement(secondMovement, now: fixedNow)
                    return true
                } catch { return false }
            }
            var result: [Bool] = []
            for await value in group { result.append(value) }
            return result
        }
        XCTAssertEqual(outcomes.filter { $0 }.count, 1)
        let loadedBook = try await firstStore.load(now: now)
        let finalBook = try XCTUnwrap(loadedBook)
        XCTAssertEqual(finalBook.cashBalance, 1_010)
        XCTAssertEqual(finalBook.cashMovements.count, 1)
    }

    func testCandidateFillRejectsLedgerVersionChangedAfterAnalysis() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FAccountBookStore(fileURL: folder.appendingPathComponent("account.json"))
        let writer = FConfirmedLedgerWriter(store: store)
        _ = try await writer.confirmInitialLedger(makeBook(), confirmation: confirmed(), now: now)
        let readSnapshot = try await store.readLedgerSnapshot(now: now)
        let oldSnapshot = try XCTUnwrap(readSnapshot)

        let movement = FCashMovement(sequence: 1, occurredAt: now, amount: 10,
                                     reason: "并发入金", userConfirmation: confirmed())
        _ = try await writer.confirmCashMovement(movement, now: now)
        let staleCandidateFill = FConfirmedFill(
            sequence: 2, tradedAt: now, instrumentCode: "159941", side: .buy,
            units: 100, price: 1, fee: 0, userConfirmation: confirmed())

        do {
            _ = try await writer.confirmFill(staleCandidateFill, instrumentName: "纳指 ETF",
                expectedLedgerDigest: oldSnapshot.ledgerDigest, now: now)
            XCTFail("a candidate based on a superseded ledger version was accepted")
        } catch let error as FLedgerPersistenceError {
            guard case .concurrentModification = error else {
                return XCTFail("unexpected stale candidate rejection: \(error)")
            }
        }

        let loadedBook = try await store.load(now: now)
        let finalBook = try XCTUnwrap(loadedBook)
        XCTAssertEqual(finalBook.cashBalance, 1_010)
        XCTAssertEqual(finalBook.cashMovements.map(\.id), [movement.id])
        XCTAssertTrue(finalBook.fills.isEmpty)
    }

    func testInitialSnapshotCannotSmuggleUnconfirmedFillHistory() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let openedAt = now.addingTimeInterval(-60)
        let fillTime = now.addingTimeInterval(-30)
        let opening = FAccountOpeningSnapshot(capturedAt: openedAt, cashBalance: 1_000)
        let historicalFill = FConfirmedFill(sequence: 1, tradedAt: fillTime,
                                            instrumentCode: "159941", side: .buy,
                                            units: 10, price: 1, fee: 0,
                                            userConfirmation: .init(confirmedAt: fillTime,
                                                                    confirmationNote: "旧成交"))
        let embeddedHistory = FAccountBook(openingSnapshot: opening, cashBalance: 990,
                                           positions: [FPosition(instrumentCode: "159941", name: "纳指 ETF",
                                                                 units: 10, bookCost: 10)],
                                           fills: [historicalFill], updatedAt: fillTime)
        try embeddedHistory.validate(now: now)
        let store = FAccountBookStore(fileURL: folder.appendingPathComponent("account.json"))
        let writer = FConfirmedLedgerWriter(store: store)
        do {
            _ = try await writer.confirmInitialLedger(embeddedHistory, confirmation: confirmed(), now: now)
            XCTFail("an initial snapshot unexpectedly imported historical fills")
        } catch let error as FLedgerPersistenceError {
            XCTAssertEqual(error, .invalidInitialLedger)
        }
        let persistedDigest = try await store.currentDigest(now: now)
        XCTAssertNil(persistedDigest)
    }

    func testAdvisorProfileBackupRestoreUsesOptimisticDigest() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FInvestorProfileStore(directory: folder)
        let initial = FInvestorProfile()
        let initialDigest = try await store.save(initial, expectedPriorDigest: nil, now: now)
        let backup = folder.appendingPathComponent("profile.backup.json")
        _ = try await store.createBackup(at: backup, now: now)
        var changed = initial
        _ = try changed.record(FInvestorProfileRevision(value: .text("长期"), confidence: 1,
                                                        source: .explicit, updatedAt: now,
                                                        explanation: "用户明确说明"),
                               for: .investmentHorizon, now: now)
        let changedDigest = try await store.save(changed, expectedPriorDigest: initialDigest, now: now)
        _ = try await store.restoreBackup(from: backup, expectedPriorDigest: changedDigest, now: now)
        let restored = try await store.load(now: now)
        XCTAssertEqual(restored, initial)
    }

    func testLegacyArchiveV1IsVerifiedAndUpgradedToV2() throws {
        let account = makeBook()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let accountBytes = try encoder.encode(account)
        let oldDigest = SHA256.hash(data: accountBytes).map { String(format: "%02x", $0) }.joined()
        let object: [String: Any] = [
            "formatVersion": 1,
            "accountID": account.accountID.uuidString,
            "schemaVersion": account.schemaVersion,
            "archivedAt": now.timeIntervalSinceReferenceDate,
            "ledgerDigest": try account.ledgerStateDigest(),
            "archiveContentDigest": oldDigest,
            "accountBook": try XCTUnwrap(JSONSerialization.jsonObject(with: accountBytes) as? [String: Any])
        ]
        let bytes = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let upgraded = try JSONDecoder().decode(FAccountBookArchive.self, from: bytes)
        XCTAssertEqual(upgraded.formatVersion, FAccountBookArchive.currentFormatVersion)
        XCTAssertTrue(upgraded.migrationReceipts.isEmpty)
        XCTAssertEqual(upgraded.accountBook, account)
        try upgraded.validate(now: now)
    }

    func testABMigrationRepeatIsRejectedAndSourceBytesRemainUnchanged() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let raw = Data(#"{"schemaVersion":1,"id":"a7f4af98-13c8-4332-80b2-b986451697c1","cash":125.5,"positions":[],"fills":[]}"#.utf8)
        let originalBytes = raw
        let preview = try FLegacyLedgerMigrationPreview.make(sourceKind: .A,
                                                             sourceBytes: raw,
                                                             capturedAt: now.addingTimeInterval(-60))
        let store = FAccountBookStore(fileURL: folder.appendingPathComponent("account.json"))
        let writer = FConfirmedLedgerWriter(store: store)
        _ = try await writer.confirmInitialMigration(preview, confirmation: confirmed(), now: now)
        let importedDigest = try await store.currentDigest(now: now)
        do {
            _ = try await writer.confirmInitialMigration(preview, confirmation: confirmed(), now: now)
            XCTFail("duplicate source migration unexpectedly accepted")
        } catch let error as FLedgerPersistenceError {
            guard case .duplicateMigration = error else { return XCTFail("unexpected error: \(error)") }
        }
        let afterRepeat = try await store.currentDigest(now: now)
        XCTAssertEqual(afterRepeat, importedDigest)
        XCTAssertEqual(raw, originalBytes)
    }

    func testInvestorProfileRejectsUnsortedRevisionHistory() {
        let later = FInvestorProfileRevision(value: .text("15年以上"), confidence: 1,
                                             source: .explicit, updatedAt: now,
                                             explanation: "用户明确说明")
        let earlier = FInvestorProfileRevision(value: .text("长期"), confidence: 0.6,
                                               source: .learned, updatedAt: now.addingTimeInterval(-60),
                                               explanation: "历史交易行为推断")
        let profile = FInvestorProfile(attributes: [
            FInvestorProfileAttribute(key: .investmentHorizon, revisions: [later, earlier])
        ])
        XCTAssertThrowsError(try profile.validate(now: now))
    }

    func testLearnedProfileRevisionCannotReplaceExplicitPreference() throws {
        var profile = FInvestorProfile()
        _ = try profile.record(FInvestorProfileRevision(value: .text("15年以上"), confidence: 1,
                                                         source: .explicit, updatedAt: now,
                                                         explanation: "用户明确说明"),
                               for: .investmentHorizon, now: now)
        let result = try profile.record(FInvestorProfileRevision(value: .text("短期"), confidence: 0.99,
                                                                 source: .learned, updatedAt: now.addingTimeInterval(1),
                                                                 explanation: "近期行为推断"),
                                         for: .investmentHorizon, now: now.addingTimeInterval(1))
        XCTAssertEqual(result, .protectedByExplicitValue)
        XCTAssertEqual(profile.attribute(.investmentHorizon)?.current(at: now)?.value, .text("15年以上"))
    }

    func testTemporaryProfileValueExpiresWithoutDeletingLearnedHistory() throws {
        var profile = FInvestorProfile()
        _ = try profile.record(FInvestorProfileRevision(value: .text("低频"), confidence: 0.7,
                                                         source: .learned, updatedAt: now.addingTimeInterval(-60),
                                                         explanation: "长期历史交易行为"),
                               for: .tradingFrequency, now: now)
        _ = try profile.record(FInvestorProfileRevision(value: .text("暂停交易"), confidence: 0.9,
                                                         source: .temporary, updatedAt: now,
                                                         explanation: "用户临时要求观察一周",
                                                         expiresAt: now.addingTimeInterval(7 * 24 * 3600)),
                               for: .tradingFrequency, now: now)
        XCTAssertEqual(profile.attribute(.tradingFrequency)?.current(at: now)?.value, .text("暂停交易"))
        XCTAssertEqual(profile.attribute(.tradingFrequency)?.current(at: now.addingTimeInterval(8 * 24 * 3600))?.value,
                       .text("低频"))
    }

    func testFullInvestorProfileResetRequiresExplicitConfirmation() throws {
        var profile = FInvestorProfile()
        _ = try profile.record(FInvestorProfileRevision(value: .text("15年以上"), confidence: 1,
                                                         source: .explicit, updatedAt: now,
                                                         explanation: "用户明确说明"),
                               for: .investmentHorizon, now: now)
        XCTAssertThrowsError(try profile.resetAll(userConfirmed: false))
        try profile.resetAll(userConfirmed: true)
        XCTAssertTrue(profile.attributes.isEmpty)
    }

    func testClearingOneInvestorPreferenceRequiresConfirmationAndPreservesOthers() throws {
        var profile = FInvestorProfile()
        _ = try profile.record(FInvestorProfileRevision(value: .text("15年以上"), confidence: 1,
                                                         source: .explicit, updatedAt: now,
                                                         explanation: "用户明确说明"),
                               for: .investmentHorizon, now: now)
        _ = try profile.record(FInvestorProfileRevision(value: .text("低风险"), confidence: 1,
                                                         source: .explicit, updatedAt: now,
                                                         explanation: "用户明确说明"),
                               for: .riskTolerance, now: now)

        XCTAssertThrowsError(try profile.clear(.investmentHorizon, userConfirmed: false))
        XCTAssertNotNil(profile.attribute(.investmentHorizon))
        try profile.clear(.investmentHorizon, userConfirmed: true)

        XCTAssertNil(profile.attribute(.investmentHorizon))
        XCTAssertEqual(profile.attribute(.riskTolerance)?.current(at: now)?.value, .text("低风险"))
        try profile.validate(now: now)
    }

    func testQuantStateEvidenceCarriesItsOwnFreshnessAndAllowsExplicitUnavailableState() throws {
        let regime = FContextObservation(dataClass: .quantState, subject: "159352",
            source: "FCore Market Regime Engine",
            reference: "regime=range; risk=r0; confidence=68; dataAsOf=2026-10-30",
            observedAt: now, capturedAt: now, decimalValue: 68)
        try regime.validate(now: now)
        XCTAssertTrue(regime.isFresh(at: now))
        XCTAssertFalse(regime.isFresh(at: now.addingTimeInterval(36 * 3600 + 1)))

        let unavailable = FContextObservation(dataClass: .quantState, subject: "risk-gate:159352",
            source: "F App Local Quant / Risk Gate", observedAt: nil, capturedAt: now,
            decimalValue: nil,
            unavailableReason: "Local Quant 尚未接入；资产变化候选会被硬门槛阻止。")
        XCTAssertNoThrow(try unavailable.validate(now: now))
        XCTAssertFalse(unavailable.isFresh(at: now))

        let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
                                       observations: [regime, unavailable])
        try context.validate(now: now)
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .wait, rationale: "Local Quant 当前不可用，继续观察")
        let memory = try FDecisionMemory(context: context, candidate: candidate,
            recommendation: "等待确定性 Quant 接入", rationale: "保存当前 Regime 和硬门槛状态")
        XCTAssertEqual(memory.evidence.filter { $0.kind == .riskState }.count, 2)
        XCTAssertTrue(memory.evidence.contains { $0.id == regime.id && $0.reference == regime.reference })
    }

    func testInvestorProfileRevisionReplayIsIdempotent() throws {
        var profile = FInvestorProfile()
        let revision = FInvestorProfileRevision(id: UUID(uuidString: "2B9D93CD-DB22-4DB7-97C1-8B7EA02607FA")!,
                                                value: .text("长期耐心限价"), confidence: 0.8,
                                                source: .learned, updatedAt: now,
                                                explanation: "同一反馈事件")
        XCTAssertEqual(try profile.record(revision, for: .patientLimitPreference, now: now), .applied)
        XCTAssertEqual(try profile.record(revision, for: .patientLimitPreference, now: now), .alreadyApplied)
        XCTAssertEqual(profile.attribute(.patientLimitPreference)?.revisions.count, 1)
    }

    func testInvestorProfileRejectsRevisionIDReuseWithChangedContent() throws {
        var profile = FInvestorProfile()
        let revisionID = UUID(uuidString: "A7E98DB4-BB7C-40F4-967C-80750E886941")!
        let first = FInvestorProfileRevision(id: revisionID, value: .text("长期"), confidence: 0.8,
                                             source: .learned, updatedAt: now,
                                             explanation: "第一次记录")
        let changed = FInvestorProfileRevision(id: revisionID, value: .text("短期"), confidence: 0.9,
                                               source: .learned, updatedAt: now,
                                               explanation: "同ID但内容变化")
        _ = try profile.record(first, for: .investmentHorizon, now: now)
        XCTAssertThrowsError(try profile.record(changed, for: .investmentHorizon, now: now))
    }

    func testExplicitProfileCorrectionReferencesSupersededRevision() throws {
        var profile = FInvestorProfile()
        let original = FInvestorProfileRevision(id: UUID(uuidString: "C65A65A8-6D35-4BDA-9B21-7B4CF7B907C2")!,
                                                value: .text("长期"), confidence: 0.8,
                                                source: .explicit, updatedAt: now.addingTimeInterval(-60),
                                                explanation: "先前明确说明", sourceReference: "user-statement-1")
        _ = try profile.record(original, for: .investmentHorizon, now: now)
        let correction = FInvestorProfileRevision(value: .text("15年以上"), confidence: 1,
                                                  source: .explicit, updatedAt: now,
                                                  explanation: "用户纠正先前期限", sourceReference: "user-correction-2",
                                                  supersedesRevisionID: original.id)
        XCTAssertEqual(try profile.record(correction, for: .investmentHorizon, now: now), .applied)
        try profile.validate(now: now)
        XCTAssertEqual(profile.attribute(.investmentHorizon)?.current(at: now)?.value, .text("15年以上"))
        XCTAssertEqual(profile.attribute(.investmentHorizon)?.revisions.last?.supersedesRevisionID, original.id)
    }

    func testLearnedProfileRevisionCannotClaimExplicitCorrection() throws {
        var profile = FInvestorProfile()
        let original = FInvestorProfileRevision(id: UUID(uuidString: "ED586B3B-A8B9-42BC-B1A1-23DAD73B50C7")!,
                                                value: .text("长期"), confidence: 1,
                                                source: .explicit, updatedAt: now.addingTimeInterval(-60),
                                                explanation: "用户明确说明")
        _ = try profile.record(original, for: .investmentHorizon, now: now)
        let learned = FInvestorProfileRevision(value: .text("短期"), confidence: 0.99,
                                               source: .learned, updatedAt: now,
                                               explanation: "近期行为推断",
                                               supersedesRevisionID: original.id)
        XCTAssertThrowsError(try profile.record(learned, for: .investmentHorizon, now: now))
    }

    func testDecisionOutcomeIsIdempotentAndCannotReuseConfirmedFill() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FAccountBookStore(fileURL: folder.appendingPathComponent("account.json"))
        let writer = FConfirmedLedgerWriter(store: store)
        _ = try await writer.confirmInitialLedger(makeBook(), confirmation: confirmed(), now: now)
        let maybeContext = try await FDecisionContext.capture(from: store, observations: [], now: now)
        let context = try XCTUnwrap(maybeContext)
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .wait,
                                                 rationale: "等待后续结果")
        let memory = try FDecisionMemory(context: context, candidate: candidate,
                                         recommendation: "继续观察", rationale: "建立决策记忆")
        let tradedAt = now.addingTimeInterval(30)
        let fill = FConfirmedFill(sequence: 1, tradedAt: tradedAt, instrumentCode: "159941", side: .buy,
                                  units: 100, price: 1, fee: 0,
                                  userConfirmation: .init(confirmedAt: tradedAt, confirmationNote: "用户确认成交"))
        _ = try await writer.confirmFill(fill, instrumentName: "纳指 ETF", now: tradedAt)
        let captured = try await store.readLedgerSnapshot(now: now.addingTimeInterval(60))
        let snapshot = try XCTUnwrap(captured)
        let outcome = FDecisionOutcome(recordedAt: now.addingTimeInterval(60), confirmedFillIDs: [fill.id],
                                       summary: "已按计划成交")
        let first = try memory.recording(outcome, verifiedAgainst: snapshot)
        let repeated = try first.recording(outcome, verifiedAgainst: snapshot)
        XCTAssertEqual(repeated.outcomes.count, 1)
        let duplicateLink = FDecisionOutcome(recordedAt: now.addingTimeInterval(60),
                                             confirmedFillIDs: [fill.id], summary: "重复关联同一成交")
        XCTAssertThrowsError(try first.recording(duplicateLink, verifiedAgainst: snapshot))
    }

    func testDecisionOutcomeRejectsFillThatPredatesDecision() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FAccountBookStore(fileURL: folder.appendingPathComponent("account.json"))
        let writer = FConfirmedLedgerWriter(store: store)
        let ledgerCreatedAt = now.addingTimeInterval(-60)
        _ = try await writer.confirmInitialLedger(
            makeBook(), confirmation: .init(confirmedAt: ledgerCreatedAt, confirmationNote: "用户已确认"),
            now: now)
        let tradedAt = now.addingTimeInterval(-30)
        let fill = FConfirmedFill(sequence: 1, tradedAt: tradedAt, instrumentCode: "159941", side: .buy,
                                  units: 100, price: 1, fee: 0,
                                  userConfirmation: .init(confirmedAt: tradedAt, confirmationNote: "用户确认成交"))
        _ = try await writer.confirmFill(fill, instrumentName: "纳指 ETF", now: tradedAt)
        let maybeContext = try await FDecisionContext.capture(from: store, observations: [], now: now)
        let context = try XCTUnwrap(maybeContext)
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .wait,
                                                 rationale: "新决策")
        let memory = try FDecisionMemory(context: context, candidate: candidate,
                                         recommendation: "继续观察", rationale: "新决策")
        let captured = try await store.readLedgerSnapshot(now: now.addingTimeInterval(60))
        let snapshot = try XCTUnwrap(captured)
        let outcome = FDecisionOutcome(recordedAt: now.addingTimeInterval(60), confirmedFillIDs: [fill.id],
                                       summary: "不应关联决策前成交")
        XCTAssertThrowsError(try memory.recording(outcome, verifiedAgainst: snapshot))
    }

    func testExplicitProfileBackupRestoreRestoresCapturedRevisionSet() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FInvestorProfileStore(directory: folder)
        var original = FInvestorProfile()
        _ = try original.record(FInvestorProfileRevision(value: .text("低频观察"), confidence: 0.75,
                                                          source: .learned, updatedAt: now,
                                                          explanation: "长期交易节奏记录",
                                                          sourceReference: "decision-memory:sample-1"),
                                for: .tradingFrequency, now: now)
        let originalDigest = try await store.save(original, expectedPriorDigest: nil, now: now)
        let backup = folder.appendingPathComponent("profile-with-history.backup.json")
        _ = try await store.createBackup(at: backup, now: now)

        var cleared = original
        cleared.clearLearnedAndTemporary()
        let clearedDigest = try await store.save(cleared, expectedPriorDigest: originalDigest, now: now)
        _ = try await store.restoreBackup(from: backup, expectedPriorDigest: clearedDigest, now: now)
        let restored = try await store.load(now: now)
        let restoredDigest = try await store.currentDigest(now: now)
        XCTAssertEqual(restored, original)
        XCTAssertNotEqual(restoredDigest, clearedDigest)
    }

    func testAdvisorPnLAddReturnsUnavailableWhenDecimalOverflows() {
        let maximum = Decimal.greatestFiniteMagnitude
        XCTAssertNil(FDecisionFinancialMath.add(maximum, maximum))
    }

    func testAdvisorPnLSumReturnsUnavailableWhenDecimalOverflows() {
        let maximum = Decimal.greatestFiniteMagnitude
        XCTAssertNil(FDecisionFinancialMath.sum([maximum, maximum]))
    }

    func testAdvisorPnLAddPreservesCancellationOfFiniteExtremes() {
        let maximum = Decimal.greatestFiniteMagnitude
        XCTAssertEqual(FDecisionFinancialMath.add(maximum, -maximum), .zero)
    }

    func testAdvisorPnLSumRejectsNonFiniteInput() {
        let maximum = Decimal.greatestFiniteMagnitude
        XCTAssertNil(FDecisionFinancialMath.sum([maximum, Decimal(Double.infinity)]))
    }
}
