import Foundation

/// Data channels have independent triggers and ownership rules.
public enum FSyncChannel: String, Codable, Equatable, Sendable {
    case personalLedger
    case marketData
    case nasResearch
}

public struct FSyncChannelPolicy: Equatable, Sendable {
    public let channel: FSyncChannel
    public let allowsAutomaticRefresh: Bool
    public let independentOfLedgerSyncToggle: Bool
    public let mayWritePersonalLedger: Bool
    public let requiresUserConfirmationBeforeRemoteApply: Bool

    public static func policy(for channel: FSyncChannel) -> FSyncChannelPolicy {
        switch channel {
        case .personalLedger:
            return .init(channel: channel, allowsAutomaticRefresh: false,
                         independentOfLedgerSyncToggle: false, mayWritePersonalLedger: true,
                         requiresUserConfirmationBeforeRemoteApply: true)
        case .marketData:
            return .init(channel: channel, allowsAutomaticRefresh: true,
                         independentOfLedgerSyncToggle: true, mayWritePersonalLedger: false,
                         requiresUserConfirmationBeforeRemoteApply: false)
        case .nasResearch:
            return .init(channel: channel, allowsAutomaticRefresh: true,
                         independentOfLedgerSyncToggle: true, mayWritePersonalLedger: false,
                         requiresUserConfirmationBeforeRemoteApply: false)
        }
    }
}

public enum FPersonalLedgerSyncAssessment: Equatable, Sendable {
    case empty
    case identical(digest: String)
    /// Different or one-sided versions never select a winner or merge automatically.
    case requiresExplicitChoice(localDigest: String?, remoteDigest: String?)
}

public enum FSyncPolicyError: Error, Equatable, Sendable {
    case invalidLedgerDigest
}

public enum FPersonalLedgerSyncPolicy {
    public static func assess(localDigest: String?, remoteDigest: String?) throws
        -> FPersonalLedgerSyncAssessment {
        for digest in [localDigest, remoteDigest].compactMap({ $0 }) where !isSHA256(digest) {
            throw FSyncPolicyError.invalidLedgerDigest
        }
        guard localDigest != nil || remoteDigest != nil else { return .empty }
        if let localDigest, localDigest == remoteDigest {
            return .identical(digest: localDigest)
        }
        return .requiresExplicitChoice(localDigest: localDigest, remoteDigest: remoteDigest)
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "0123456789abcdef").contains($0)
        }
    }
}
