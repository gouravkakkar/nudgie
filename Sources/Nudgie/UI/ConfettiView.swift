import SwiftUI

/// A one-shot burst. Put it in the view tree when you want it to fire; it animates on appear.
struct ConfettiView: View {
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [Particle] = []
    @State private var fired = false

    struct Particle: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let color: Color
        let size: CGFloat
        let spin: Double
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 0.6)
                    .rotationEffect(.degrees(fired ? p.spin : 0))
                    .offset(x: fired ? cos(p.angle) * p.distance : 0,
                            y: fired ? sin(p.angle) * p.distance + 30 : 0)
                    .opacity(fired ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            particles = (0..<28).map { _ in
                Particle(angle: .random(in: 0..<(2 * .pi)),
                         distance: .random(in: 60...140),
                         color: colors.randomElement() ?? Theme.ink,
                         size: .random(in: 6...11),
                         spin: .random(in: -360...360))
            }
            withAnimation(.easeOut(duration: 0.8)) { fired = true }
        }
    }
}
