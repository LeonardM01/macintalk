import Foundation

enum WritingStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case casual
    case balanced
    case business

    var id: String { rawValue }

    var title: String {
        switch self {
        case .casual: "Casual"
        case .balanced: "Balanced"
        case .business: "Business"
        }
    }

    var subtitle: String {
        switch self {
        case .casual:
            "Conversational tone with light punctuation. Keeps contractions and common abbreviations."
        case .balanced:
            "Clear grammar and punctuation while preserving your natural voice."
        case .business:
            "Formal wording, full punctuation and capitalization. Expands abbreviations when clear."
        }
    }

    var exampleDescription: String {
        switch self {
        case .casual:
            "\"hey can u send that over asap thanks\""
        case .balanced:
            "\"Hey, can you send that over? Thanks.\""
        case .business:
            "\"Hello, could you please send that over at your earliest convenience? Thank you.\""
        }
    }
}
