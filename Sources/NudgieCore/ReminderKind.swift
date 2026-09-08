/// Library-wide constants.
public enum NudgieCore {
    public static let version = "0.1.1"
}

/// The five things Nudgie nudges you about. Order here is display order.
public enum ReminderKind: String, CaseIterable, Codable, Sendable {
    case eyes, water, walk, posture, stretch

    public var title: String {
        switch self {
        case .eyes: "Eyes"
        case .water: "Water"
        case .walk: "Walk"
        case .posture: "Posture"
        case .stretch: "Stretch"
        }
    }

    public var emoji: String {
        switch self {
        case .eyes: "👀"
        case .water: "💧"
        case .walk: "🚶"
        case .posture: "🪑"
        case .stretch: "🙆"
        }
    }

    /// The plain instruction shown under the cheeky line.
    public var instruction: String {
        switch self {
        case .eyes: "Look at something 20 feet away for 20 seconds."
        case .water: "Drink a glass of water."
        case .walk: "Stand up and walk for a few minutes."
        case .posture: "Sit up, shoulders back, screen at eye level."
        case .stretch: "Stretch your neck, shoulders and wrists."
        }
    }

    public var defaultIntervalMinutes: Int {
        switch self {
        case .eyes: 20
        case .water: 45
        case .walk: 60
        case .posture: 30
        case .stretch: 60
        }
    }

    /// 0 means "no timed break": the card shows for a fixed time, then counts as done.
    public var defaultBreakSeconds: Int {
        switch self {
        case .eyes: 20
        case .water: 0
        case .walk: 180
        case .posture: 0
        case .stretch: 60
        }
    }
}
