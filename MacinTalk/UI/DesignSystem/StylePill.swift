import SwiftUI

struct StylePill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
    }
}
