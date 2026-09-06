import SwiftUI
import NudgieCore

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Colours and type for the "sticker buddy" look (spec section 9).
enum Theme {
    static let ink = Color(hex: 0x1B1B1F)
    static let cream = Color(hex: 0xFFF8EE)
    static let cornerRadius: CGFloat = 24
    static let outline: CGFloat = 3

    static func accent(_ kind: ReminderKind) -> Color {
        switch kind {
        case .eyes: Color(hex: 0x3DF5B4)      // electric mint
        case .water: Color(hex: 0x4DB8FF)     // sky
        case .walk: Color(hex: 0xFF8C42)      // tangerine
        case .posture: Color(hex: 0xFF6FB5)   // bubblegum
        case .stretch: Color(hex: 0xFFE24D)   // lemon
        }
    }

    static func headline(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .medium, design: .rounded) }

    static func ground(_ scheme: ColorScheme) -> Color { scheme == .dark ? ink : cream }
    static func text(_ scheme: ColorScheme) -> Color { scheme == .dark ? cream : ink }
}

/// Flat fill, thick outline, hard offset shadow: a paper sticker.
struct StickerStyle: ViewModifier {
    var fill: Color
    var outline: Color
    var shadow: Color
    var radius: CGFloat = Theme.cornerRadius

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(shadow).offset(x: 6, y: 6)
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
                RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(outline, lineWidth: Theme.outline)
            }
        )
    }
}

extension View {
    func sticker(fill: Color, outline: Color, shadow: Color) -> some View {
        modifier(StickerStyle(fill: fill, outline: outline, shadow: shadow))
    }
}
