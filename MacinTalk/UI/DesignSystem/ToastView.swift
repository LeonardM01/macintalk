import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
            Text(message)
                .font(.system(size: 12.5, weight: .medium))
        }
        .foregroundStyle(AppTheme.success)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(AppTheme.success.opacity(0.14))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(AppTheme.success.opacity(0.35), lineWidth: 1)
        )
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 8)),
                removal: .opacity
            )
        )
    }
}
