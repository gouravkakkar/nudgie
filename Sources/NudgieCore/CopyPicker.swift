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

    /// The quiet line under the instruction: what you get out of doing it. Deliberately free of
    /// any reference to the time of day, because a card can appear at 9am or 10pm.
    public static let benefits: [ReminderKind: [String]] = [
        .eyes: [
            "Eases the strain of staring at one distance.",
            "Relaxes the focusing muscle you've been holding.",
            "Stops that dry, gritty feeling building up.",
        ],
        .water: [
            "Steadies your energy and your focus.",
            "Clears the fog before it settles in.",
            "Keeps the dull headache from creeping in.",
        ],
        .walk: [
            "Breaks up the sitting that stiffens you up.",
            "Gets the blood moving in your legs again.",
            "A change of position is what your back wants.",
        ],
        .posture: [
            "Saves your neck and lower back from aching later.",
            "Takes the weight of your head off your neck.",
            "Stops your shoulders creeping up to your ears.",
        ],
        .stretch: [
            "Loosens your shoulders before they get tight.",
            "Keeps your wrists from grumbling.",
            "Undoes the hunch you've settled into.",
        ],
    ]

    private var lastIndex: [ReminderKind: Int] = [:]
    private var lastBenefitIndex: [ReminderKind: Int] = [:]

    public init() {}

    public mutating func line(for kind: ReminderKind, using generator: inout some RandomNumberGenerator) -> String {
        pick(from: Self.lines[kind] ?? [kind.instruction], for: kind, remembering: &lastIndex, using: &generator)
    }

    public mutating func line(for kind: ReminderKind) -> String {
        var generator = SystemRandomNumberGenerator()
        return line(for: kind, using: &generator)
    }

    /// Rotated separately from the headline so the pairing varies rather than repeating in lockstep.
    public mutating func benefit(for kind: ReminderKind, using generator: inout some RandomNumberGenerator) -> String? {
        guard let options = Self.benefits[kind], !options.isEmpty else { return nil }
        return pick(from: options, for: kind, remembering: &lastBenefitIndex, using: &generator)
    }

    public mutating func benefit(for kind: ReminderKind) -> String? {
        var generator = SystemRandomNumberGenerator()
        return benefit(for: kind, using: &generator)
    }

    /// Never the same entry twice in a row for a given kind.
    private func pick(from options: [String],
                      for kind: ReminderKind,
                      remembering last: inout [ReminderKind: Int],
                      using generator: inout some RandomNumberGenerator) -> String {
        guard options.count > 1 else { return options[0] }
        var index = Int.random(in: 0..<options.count, using: &generator)
        if index == last[kind] {
            index = (index + 1) % options.count
        }
        last[kind] = index
        return options[index]
    }
}
