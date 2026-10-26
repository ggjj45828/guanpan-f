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

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GuanpanF-Boundary-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func researchReference(id: String, generatedAt: Date) throws -> FDecisionResearchEvidence {
        let formatter = ISO8601DateFormatter()
        let metrics: [String: Any] = ["evidenceState": "available_for_review", "trainingDays": 24,
                                      "outOfSampleDays": 8, "maxMonthlySampleShare": 0.25,
                                      "maximumMonthlySampleShare": 0.5]
        var payload: [String: Any] = [
            "schemaVersion": 1, "methodologyVersion": "minute-research-1", "evidenceId": String(repeating: "0", count: 64),
            "securityCode": "159352", "market": "CN",
            "range": ["start": "2026-10-01", "end": "2026-10-23"],
            "asOf": formatter.string(from: now.addingTimeInterval(-120)),
            "generatedAt": formatter.string(from: generatedAt), "timezone": "Asia/Shanghai",
            "sessionCoverage": ["complete": 28, "partial": 0, "missing": 0],
            "qualifiedIndependentDays": 28, "minimumQuality": 90, "sources": ["fixture-source"],
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

    func testAssetChangingCandidateMustCiteTheVerifiedFreshQuote() throws {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(-10), fetchedAt: now,
            source: "acceptance-fixture", timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352",
            source: "acceptance-fixture", observedAt: metadata.quoteTimestamp,
            capturedAt: now, decimalValue: 1, quoteTemporalMetadata: metadata)
        let context = FDecisionContext(snapshot: try makeBook().readOnlySnapshot(capturedAt: now),
                                       observations: [quote])
        let uncited = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100,
            limitPrice: 1, rationale: "基于价格评估")
        let uncitedResult = FRiskGuard.evaluate(uncited, in: context, now: now)
        XCTAssertTrue(uncitedResult.findings.contains(.missingCitedEvidence(quote.id)))

        let cited = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100,
            limitPrice: 1, rationale: "基于所引新鲜报价评估",
            citedObservationIDs: [quote.id])
        XCTAssertFalse(FRiskGuard.evaluate(cited, in: context, now: now)
            .findings.contains(.missingCitedEvidence(quote.id)))
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
        let memory = try FDecisionMemory(context: context, candidate: candidate,
                                         recommendation: "持有", rationale: "当前无新证据")
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
            source: "acceptance-fixture", timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352",
                                        source: "acceptance-fixture",
                                        observedAt: riskQuoteMetadata.quoteTimestamp,
                                        capturedAt: now, decimalValue: 1,
                                        quoteTemporalMetadata: riskQuoteMetadata)
        let quoteSnapshot = try makeBook().readOnlySnapshot(capturedAt: now)
        let riskContext = FDecisionContext(snapshot: quoteSnapshot, observations: [quote])
        let oversizedPrice = try XCTUnwrap(Decimal(string: "1e120"))
        let overflowingCandidate = FCandidateRecommendation(
            accountDigest: riskContext.accountDigest, action: .buy, instrumentCode: "159352",
            units: Int64.max, limitPrice: oversizedPrice, rationale: "超界算术必须拒绝")
        let overflowGuard = FRiskGuard.evaluate(overflowingCandidate, in: riskContext, now: now)
        XCTAssertTrue(overflowGuard.findings.contains(.invalidCandidate))
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
}
