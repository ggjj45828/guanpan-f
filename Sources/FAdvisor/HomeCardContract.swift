import Foundation

/// Semantic responsibilities and navigation outcomes for the five F home layouts.
/// A theme may rearrange cards, but it cannot change what a card means.
public enum FHomeLayoutStyle: String, Codable, CaseIterable, Hashable, Sendable {
    case editorial, modern, dashboard, magazine, bento
}

public enum FHomeCardRole: String, Codable, CaseIterable, Hashable, Sendable {
    case advisorQuestion
    case dailyGuidance
    case portfolioSnapshot
    case holdings
    case marketPulse
    case dataQuality
    case nasResearch
    case candidatePlans
    case dividendResearch
    case alerts
    case instrumentFocus
}

public enum FHomeLedgerAvailability: String, Codable, Equatable, Sendable {
    case loading
    case notEstablished
    case available
    case unavailable
}

public enum FHomeCardPresentation {
    /// Keeps an unreadable or loading account from being presented as an empty or
    /// not-yet-created ledger. A numeric balance is shown only for a read snapshot.
    public static func cashBalanceText(state: FHomeLedgerAvailability,
                                       formattedBalance: String?) -> String {
        switch state {
        case .loading: return "读取中"
        case .notEstablished: return "未建立"
        case .unavailable: return "不可读取"
        case .available: return formattedBalance ?? "不可用"
        }
    }
}

/// These destinations are intentionally task-specific. Home cards cannot route
/// to an untyped generic page, and no action in this type writes the real ledger.
public enum FHomeDestination: Hashable, Codable, Sendable {
    case askAboutPortfolio
    case reviewCurrentDecision
    case openPortfolio
    case openHoldings
    case openMarketOverview
    case openDataQuality
    case openNASResearch
    case openCandidatePlans
    case openDividendResearch
    case openAlerts
    case openInstrument(String)
}

public struct FHomeCardContract: Codable, Equatable, Sendable {
    public let id: String
    public let role: FHomeCardRole
    public let title: String
    public let informationDuty: String
    public let primaryActionLabel: String
    public let destination: FHomeDestination

    public init(id: String, role: FHomeCardRole, title: String,
                informationDuty: String, primaryActionLabel: String,
                destination: FHomeDestination) {
        self.id = id
        self.role = role
        self.title = title
        self.informationDuty = informationDuty
        self.primaryActionLabel = primaryActionLabel
        self.destination = destination
    }
}

public struct FHomeLayoutContract: Codable, Equatable, Sendable {
    public let style: FHomeLayoutStyle
    /// Visual order, from first visible card to last.
    public let cards: [FHomeCardContract]

    public init(style: FHomeLayoutStyle, cards: [FHomeCardContract]) {
        self.style = style
        self.cards = cards
    }

    public func validate() throws {
        guard cards.count >= FHomeCardRole.requiredHomeRoles.count else {
            throw FHomeLayoutError.missingRequiredRole
        }
        guard cards.first?.role == .advisorQuestion else {
            throw FHomeLayoutError.advisorQuestionMustBeFirst
        }
        guard Set(cards.map(\.id)).count == cards.count else {
            throw FHomeLayoutError.duplicateCardID
        }
        guard Set(cards.map(\.role)).count == cards.count else {
            throw FHomeLayoutError.duplicateRole
        }
        guard Set(cards.map(\.destination)).count == cards.count else {
            throw FHomeLayoutError.duplicateDestination
        }
        guard FHomeCardRole.requiredHomeRoles.isSubset(of: Set(cards.map(\.role))) else {
            throw FHomeLayoutError.missingRequiredRole
        }
        for card in cards {
            guard !card.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !card.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !card.informationDuty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !card.primaryActionLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw FHomeLayoutError.incompleteCardDescription(card.id)
            }
            guard card.destination.isValid(for: card.role) else {
                throw FHomeLayoutError.destinationDoesNotMatchRole(card.role)
            }
        }
    }
}

extension FHomeCardRole {
    fileprivate static let requiredHomeRoles: Set<Self> = [
        .advisorQuestion, .portfolioSnapshot, .holdings, .marketPulse, .dataQuality
    ]
}

extension FHomeDestination {
    fileprivate func isValid(for role: FHomeCardRole) -> Bool {
        switch (role, self) {
        case (.advisorQuestion, .askAboutPortfolio),
             (.dailyGuidance, .reviewCurrentDecision),
             (.portfolioSnapshot, .openPortfolio),
             (.holdings, .openHoldings),
             (.marketPulse, .openMarketOverview),
             (.dataQuality, .openDataQuality),
             (.nasResearch, .openNASResearch),
             (.candidatePlans, .openCandidatePlans),
             (.dividendResearch, .openDividendResearch),
             (.alerts, .openAlerts):
            return true
        case (.instrumentFocus, .openInstrument(let code)):
            return !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }
}

public enum FHomeLayoutError: Error, Equatable, Sendable {
    case missingRequiredRole
    case advisorQuestionMustBeFirst
    case duplicateCardID
    case duplicateRole
    case duplicateDestination
    case incompleteCardDescription(String)
    case destinationDoesNotMatchRole(FHomeCardRole)
}
