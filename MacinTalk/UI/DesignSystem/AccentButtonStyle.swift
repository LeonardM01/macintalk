import SwiftUI

struct AccentButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: tint.opacity(0.4), radius: 12, x: 0, y: 2)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension ButtonStyle where Self == AccentButtonStyle {
    static func accent(_ tint: Color) -> AccentButtonStyle {
        AccentButtonStyle(tint: tint)
    }
}
