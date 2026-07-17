import SwiftUI

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.cornerRadius

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(AppTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = AppTheme.cornerRadius) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
