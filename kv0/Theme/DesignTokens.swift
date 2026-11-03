import SwiftUI

enum Ink {
    static let washi = Color(hex: 0xEDE6D9)
    static let washiDeep = Color(hex: 0xE2D8C6)
    static let sumi = Color(hex: 0x1A1410)
    static let inkSoft = Color(hex: 0x5A4838)
    static let moss = Color(hex: 0x5D6B4A)
    static let shu = Color(hex: 0xA8342A)
}

enum Typeface {
    static let hero = Font.system(size: 112, weight: .light, design: .serif).monospacedDigit()
    static let sentence = Font.system(size: 28, weight: .regular, design: .serif)
    static let metric = Font.system(size: 28, weight: .light, design: .serif).monospacedDigit()
    static let body = Font.system(size: 17, weight: .regular)
    static let caption = Font.system(size: 13, weight: .regular)
}

enum Space {
    static let margin: CGFloat = 24
    static let section: CGFloat = 40
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
