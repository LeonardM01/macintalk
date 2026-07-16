import SwiftUI

enum AppTheme {
    static let textPrimary = Color(red: 0xf5 / 255, green: 0xf5 / 255, blue: 0xf7 / 255)
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.4)

    static let accent = Color(red: 0x0a / 255, green: 0x84 / 255, blue: 0xff / 255)
    static let accentHover = Color(red: 0x24 / 255, green: 0x92 / 255, blue: 0xff / 255)
    static let accentLight = Color(red: 0x8e / 255, green: 0xc2 / 255, blue: 0xff / 255)

    static let success = Color(red: 0x30 / 255, green: 0xd1 / 255, blue: 0x58 / 255)
    static let danger = Color(red: 0xff / 255, green: 0x45 / 255, blue: 0x3a / 255)
    static let dangerLight = Color(red: 0xff / 255, green: 0x69 / 255, blue: 0x61 / 255)
    static let warning = Color(red: 0xff / 255, green: 0x9f / 255, blue: 0x0a / 255)

    static let cardSurface = Color.white.opacity(0.05)
    static let cardBorder = Color.white.opacity(0.08)
    static let cornerRadius: CGFloat = 12

    static var backdrop: some View {
        ZStack {
            Color(red: 0x0c / 255, green: 0x09 / 255, blue: 0x21 / 255)
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0x4a / 255, green: 0x2f / 255, blue: 0x96 / 255), location: 0),
                    .init(color: Color(red: 0x2b / 255, green: 0x1b / 255, blue: 0x66 / 255), location: 0.42),
                    .init(color: Color(red: 0x15 / 255, green: 0x0e / 255, blue: 0x38 / 255), location: 0.8),
                    .init(color: Color(red: 0x0c / 255, green: 0x09 / 255, blue: 0x21 / 255), location: 1)
                ]),
                center: .init(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 900
            )
        }
        .ignoresSafeArea()
    }
}
