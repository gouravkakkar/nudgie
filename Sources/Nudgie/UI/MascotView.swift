import SwiftUI
import NudgieCore

enum MascotPose: Equatable {
    case eyes, water, walk, posture, stretch, shh, sleepy

    init(kind: ReminderKind) {
        switch kind {
        case .eyes: self = .eyes
        case .water: self = .water
        case .walk: self = .walk
        case .posture: self = .posture
        case .stretch: self = .stretch
        }
    }
}

/// Nudgie: a round blob with big eyes, drawn entirely with shapes. One pose per reminder.
struct MascotView: View {
    let pose: MascotPose
    let accent: Color
    var size: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wiggle = false

    var body: some View {
        ZStack {
            if pose == .walk {
                HStack(spacing: size * 0.18) {
                    leg.rotationEffect(.degrees(wiggle ? 14 : -14))
                    leg.rotationEffect(.degrees(wiggle ? -14 : 14))
                }
                .offset(y: size * 0.42)
            }
            Ellipse()
                .fill(accent)
                .overlay(Ellipse().stroke(Theme.ink, lineWidth: Theme.outline))
                .scaleEffect(x: bodyScale.width, y: bodyScale.height)
                .offset(y: bounce)
            face.offset(y: bounce)
            if pose == .water {
                glass.offset(x: size * 0.42, y: size * 0.22)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { wiggle = true }
        }
    }

    // MARK: Pose geometry

    private var bodyScale: CGSize {
        switch pose {
        case .stretch: CGSize(width: 0.8, height: wiggle ? 1.28 : 1.08)   // taffy
        case .posture: CGSize(width: 1.05, height: wiggle ? 1.0 : 0.8)    // slouch, then sit up
        default: CGSize(width: 1, height: 1)
        }
    }

    private var bounce: CGFloat { pose == .walk && wiggle ? -6 : 0 }

    private var pupilOffset: CGFloat {
        switch pose {
        case .eyes: wiggle ? size * 0.07 : -size * 0.07   // looking far away, left then right
        case .sleepy: 0
        default: size * 0.02
        }
    }

    // MARK: Parts

    private var leg: some View {
        Capsule().fill(Theme.ink).frame(width: size * 0.1, height: size * 0.28)
    }

    private var glass: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.9))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.accent(.water)).frame(height: size * 0.16).padding(2)
            }
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.ink, lineWidth: 2))
            .frame(width: size * 0.22, height: size * 0.3)
    }

    private var face: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.12) {
                eye
                eye
            }
            mouth
        }
    }

    private var eye: some View {
        ZStack {
            Circle().fill(.white).overlay(Circle().stroke(Theme.ink, lineWidth: 2))
            if pose == .sleepy {
                Capsule().fill(Theme.ink).frame(width: size * 0.14, height: 2)
            } else {
                Circle().fill(Theme.ink)
                    .frame(width: size * 0.08, height: size * 0.08)
                    .offset(x: pupilOffset)
            }
        }
        .frame(width: size * 0.22, height: size * 0.22)
    }

    @ViewBuilder private var mouth: some View {
        switch pose {
        case .shh:
            ZStack {
                Capsule().fill(Theme.ink).frame(width: size * 0.18, height: 2.5)  // lips pressed shut
                Capsule().fill(Theme.ink)
                    .frame(width: size * 0.05, height: size * 0.24)
                    .rotationEffect(.degrees(12))
                    .offset(x: size * 0.04)
            }
        case .sleepy:
            Text("z z")
                .font(.system(size: size * 0.16, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
        case .posture:
            Capsule().fill(Theme.ink).frame(width: size * 0.18, height: 2.5)
        default:
            SmileShape()
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.1)
        }
    }
}

/// A smile: the lower arc of a circle.
struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY), radius: rect.width / 2,
                    startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        return path
    }
}
