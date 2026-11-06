import SwiftUI

enum Nova {
    static let void = Color(hex: 0x0D0D0D)
    static let surface = Color(hex: 0x1C1C1C)
    static let bone = Color(hex: 0xF5F3EF)
    static let orange = Color(hex: 0xFF4000)
    static let ember = Color(hex: 0xFF5733)
    static let rust = Color(hex: 0xB85C3E)
    static let muted = Color(hex: 0x666666)
    static let hairline = Color.white.opacity(0.1)
}

enum Typeface {
    static let family = "Space Grotesk"

    static let hero = display(140, weight: .medium)
    static let sentence = display(30, weight: .medium)
    static let metric = display(34, weight: .medium)
    static let stat = display(22, weight: .medium)
    static let body = Font.custom(family, size: 17).weight(.regular)
    static let caption = Font.custom(family, size: 13).weight(.regular)

    /// Nova sets display type at -0.04em.
    static func tracking(for size: CGFloat) -> CGFloat { size * -0.04 }

    private static func display(_ size: CGFloat, weight: Font.Weight) -> Font {
        Font.custom(family, size: size).weight(weight).monospacedDigit()
    }
}

enum Space {
    static let margin: CGFloat = 24
    static let section: CGFloat = 32
    static let cardRadius: CGFloat = 20
}

enum Motion {
    static let reink = Animation.easeInOut(duration: 0.8)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
