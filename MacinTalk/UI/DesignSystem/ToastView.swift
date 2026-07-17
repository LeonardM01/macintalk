import SwiftUI

struct ToastView: View {
    let message: String
    var isSuccess: Bool = true

    private var tint: Color {
        isSuccess ? AppTheme.success : AppTheme.danger
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSuccess ? "checkmark" : "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(message)
                .font(.system(size: 12.5, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(tint.opacity(0.14))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 8)),
                removal: .opacity
            )
        )
    }
}
