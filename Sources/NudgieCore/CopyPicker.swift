/// The cheeky one-liners. Picks at random, never the same line twice in a row.
public struct CopyPicker: Equatable, Sendable {
    public static let lines: [ReminderKind: [String]] = [
        .eyes: [
            "Your eyeballs called. They want a vacation.",
            "Stare at something 20 feet away. The wall counts.",
            "Blink. Blink again. Now look far away.",
            "Give the pixels a break. Find a window.",
        ],
        .water: [
            "Hydrate or dydrate.",
            "Plants get watered. So should you.",
            "Sip happens.",
            "Your brain is 75% water. Top it up.",
        ],
        .walk: [
            "Legs. Remember those? Take them for a spin.",
            "Go touch grass, or at least the kitchen.",
            "Your chair needs some alone time.",
            "A short lap now beats a stiff back later.",
        ],
        .posture: [
            "You're doing the shrimp again.",
            "Shoulders down. Chin up. You've got this.",
            "Sit like someone's taking your photo.",
            "Unfold yourself. Slowly. Like a lawn chair.",
        ],
        .stretch: [
            "Reach for the ceiling. It's not going anywhere.",
            "Roll those shoulders like you mean it.",
            "Wrists, neck, shoulders. Go.",
            "Stretch now, thank yourself at 5 pm.",
        ],
    ]

    private var lastIndex: [ReminderKind: Int] = [:]

    public init() {}

    public mutating func line(for kind: ReminderKind, using generator: inout some RandomNumberGenerator) -> String {
        let options = Self.lines[kind] ?? [kind.instruction]
        guard options.count > 1 else { return options[0] }
        var index = Int.random(in: 0..<options.count, using: &generator)
        if index == lastIndex[kind] {
            index = (index + 1) % options.count
        }
        lastIndex[kind] = index
        return options[index]
    }

    public mutating func line(for kind: ReminderKind) -> String {
        var generator = SystemRandomNumberGenerator()
        return line(for: kind, using: &generator)
    }
}
