import SwiftUI
import NudgieCore

/// The floating reminder card: ring + mascot on the left, copy and buttons on the right.
struct CardView: View {
    static let width: CGFloat = 360
    static let height: CGFloat = 170
    /// Extra room around the card for the sticker shadow and the entry tilt.
    static let margin: CGFloat = 12

    let coordinator: Coordinator

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var celebrating = false

    var body: some View {
        ZStack {
            if let card = coordinator.card {
                content(card)
            }
            if celebrating {
                ConfettiView(colors: ReminderKind.allCases.map(Theme.accent))
            }
        }
        .frame(width: Self.width + Self.margin * 2, height: Self.height + Self.margin * 2)
    }

    private func content(_ card: CardPresentation) -> some View {
        let accent = Theme.accent(card.accentKind)
        let text = Theme.text(scheme)
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(text.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress(card))
                    .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: card.secondsLeft)
                MascotView(pose: MascotPose(kind: card.accentKind), accent: accent, size: 64)
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 6) {
                Text(card.headline)
                    .font(Theme.headline())
                    .foregroundStyle(text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle(card))
                    .font(Theme.body())
                    .foregroundStyle(text.opacity(0.8))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Button { celebrate(card) } label: {
                        Text("Did it!").font(Theme.headline(13)).lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .buttonStyle(PillButtonStyle(fill: accent, outline: Theme.ink, text: Theme.ink))
                    .disabled(celebrating)
                    Button { coordinator.snooze() } label: {
                        Text("\(coordinator.settings.snoozeMinutes) more min").font(Theme.body(12))
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .buttonStyle(PillButtonStyle(fill: .clear, outline: text, text: text))
                    .disabled(celebrating)
                    Spacer()
                    Text(timeLeft(card))
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(text.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(18)
        .frame(width: Self.width, height: Self.height)
        .sticker(fill: Theme.ground(scheme), outline: text, shadow: scheme == .dark ? accent : Theme.ink)
        .overlay(alignment: .topTrailing) {
            Button { coordinator.close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(text.opacity(0.7))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .padding(4)
            .disabled(celebrating)
            .accessibilityLabel("Close without counting")
        }
        .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -2))
        .scaleEffect(appeared || reduceMotion ? 1 : 0.92)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
            }
        }
    }

    private func progress(_ card: CardPresentation) -> Double {
        guard card.plan.countdownSeconds > 0 else { return 0 }
        return Double(card.secondsLeft) / Double(card.plan.countdownSeconds)
    }

    private func timeLeft(_ card: CardPresentation) -> String {
        guard card.plan.isTimed else { return "" }
        return String(format: "%d:%02d", card.secondsLeft / 60, card.secondsLeft % 60)
    }

    private func subtitle(_ card: CardPresentation) -> String {
        if card.plan.kinds.count == 1 { return card.accentKind.instruction }
        return card.plan.kinds.map { "\($0.emoji) \($0.title)" }.joined(separator: " · ")
    }

    /// Confetti first, then completion, but only of the card that was clicked.
    private func celebrate(_ card: CardPresentation) {
        if reduceMotion {
            coordinator.didIt(cardID: card.id)
            return
        }
        celebrating = true
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            coordinator.didIt(cardID: card.id)
            celebrating = false
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    var fill: Color
    var outline: Color
    var text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(outline, lineWidth: 2))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
