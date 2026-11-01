import Foundation

private struct FMarketQuoteCacheSample: Codable {
    let timestamp: Date
    let price: Decimal
    let volume: Decimal?
}

private struct FMarketQuoteCacheRecord: Codable {
    let schemaVersion: Int
    let securityCode: String
    let samples: [FMarketQuoteCacheSample]
    let quoteTimestamp: Date
    let fetchedAt: Date
    let source: String

    init(snapshot: FCurrentIntradaySnapshot) {
        schemaVersion = 1
        securityCode = snapshot.securityCode
        samples = snapshot.samples.map {
            FMarketQuoteCacheSample(timestamp: $0.timestamp, price: $0.price, volume: $0.volume)
        }
        quoteTimestamp = snapshot.quoteTimestamp
        fetchedAt = snapshot.fetchedAt
        source = snapshot.source
    }

    func snapshot(at now: Date, maximumAge: TimeInterval) -> FCurrentIntradaySnapshot? {
        guard schemaVersion == 1, fetchedAt <= now,
              now.timeIntervalSince(fetchedAt) <= maximumAge,
              samples.count <= 500 else { return nil }
        let minuteSamples = samples.map {
            FMinuteSample(timestamp: $0.timestamp, price: $0.price, volume: $0.volume)
        }
        return try? FCurrentIntradaySnapshot(securityCode: securityCode, samples: minuteSamples,
                                             quoteTimestamp: quoteTimestamp, fetchedAt: fetchedAt,
                                             source: source)
    }
}

/// Durable last-known intraday quotes for display while offline. Callers must
/// still apply normal freshness checks before using a restored quote as evidence.
public actor FMarketQuoteCache {
    public static let maximumAge: TimeInterval = 30 * 24 * 60 * 60
    private static let maximumRecords = 250
    private static let maximumRecordBytes = 512_000
    private enum CacheError: Error { case invalidRecord }
    private let directory: URL
    private let fileManager = FileManager.default

    public init(directory: URL) throws {
        self.directory = directory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func loadAll(at now: Date = Date(), maximumAge: TimeInterval = Self.maximumAge)
        -> [FCurrentIntradaySnapshot] {
        guard now.timeIntervalSince1970.isFinite, maximumAge.isFinite, maximumAge >= 0,
              let files = try? fileManager.contentsOfDirectory(at: directory,
                                                               includingPropertiesForKeys: [.contentModificationDateKey])
        else { return [] }
        let newestFirst = files
            .filter { Self.securityCode(from: $0) != nil && isRegularCacheFile($0) }
            .sorted {
                let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return left > right
            }
        for url in newestFirst.dropFirst(Self.maximumRecords) {
            try? fileManager.removeItem(at: url)
        }
        var restored: [FCurrentIntradaySnapshot] = []
        for url in newestFirst.prefix(Self.maximumRecords) {
            guard let code = Self.securityCode(from: url),
                  let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                  let size = attributes[.size] as? NSNumber,
                  size.intValue > 0, size.intValue <= Self.maximumRecordBytes,
                  let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                  let record = try? JSONDecoder().decode(FMarketQuoteCacheRecord.self, from: data),
                  record.securityCode == code,
                  let snapshot = record.snapshot(at: now, maximumAge: maximumAge) else {
                try? fileManager.removeItem(at: url)
                continue
            }
            restored.append(snapshot)
        }
        return restored
    }

    public func save(_ snapshot: FCurrentIntradaySnapshot, now: Date = Date()) throws {
        guard now.timeIntervalSince1970.isFinite,
              snapshot.fetchedAt <= now,
              now.timeIntervalSince(snapshot.fetchedAt) <= Self.maximumAge,
              snapshot.samples.count <= 500,
              Self.isValidSecurityCode(snapshot.securityCode) else { return }
        let destination = fileURL(for: snapshot.securityCode)
        if let existingRecord = try? readRecord(at: destination),
           let existing = existingRecord.snapshot(at: now, maximumAge: Self.maximumAge),
           (existing.quoteTimestamp > snapshot.quoteTimestamp ||
            (existing.quoteTimestamp == snapshot.quoteTimestamp && existing.fetchedAt > snapshot.fetchedAt)) {
            return
        }
        if !fileManager.fileExists(atPath: destination.path) {
            pruneIfNeeded(keeping: destination)
        }
        let data = try JSONEncoder().encode(FMarketQuoteCacheRecord(snapshot: snapshot))
        guard data.count <= Self.maximumRecordBytes else { return }
        try data.write(to: destination, options: .atomic)
    }

    private func pruneIfNeeded(keeping destination: URL) {
        guard let files = try? fileManager.contentsOfDirectory(at: directory,
                                                               includingPropertiesForKeys: [.contentModificationDateKey])
        else { return }
        let quoteFiles = files.filter {
            Self.securityCode(from: $0) != nil && $0 != destination && isRegularCacheFile($0)
        }
        guard quoteFiles.count >= Self.maximumRecords else { return }
        let oldestFirst = quoteFiles.sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left < right
        }
        let excess = quoteFiles.count - (Self.maximumRecords - 1)
        for url in oldestFirst.prefix(excess) { try? fileManager.removeItem(at: url) }
    }

    private func fileURL(for securityCode: String) -> URL {
        directory.appendingPathComponent("quote-\(securityCode).json", isDirectory: false)
    }

    private func readRecord(at url: URL) throws -> FMarketQuoteCacheRecord {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              size.intValue > 0, size.intValue <= Self.maximumRecordBytes else { throw CacheError.invalidRecord }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try JSONDecoder().decode(FMarketQuoteCacheRecord.self, from: data)
    }

    private func isRegularCacheFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func securityCode(from url: URL) -> String? {
        let name = url.deletingPathExtension().lastPathComponent
        guard name.hasPrefix("quote-") else { return nil }
        let code = String(name.dropFirst("quote-".count))
        return isValidSecurityCode(code) ? code : nil
    }

    private static func isValidSecurityCode(_ code: String) -> Bool {
        code.utf8.count == 6 && code.utf8.allSatisfy { (48...57).contains($0) }
    }
}
