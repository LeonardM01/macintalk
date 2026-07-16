import SwiftUI

struct DictationOrb: View {
    var isRecording: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseActive = false

    var body: some View {
        ZStack {
            Circle()
                .fill(orbGradient)
                .overlay(
                    Circle()
                        .strokeBorder(orbBorderColor, lineWidth: 1)
                )
                .shadow(color: glowColor.opacity(pulseGlowOpacity), radius: pulseGlowRadius)
                .frame(width: 112, height: 112)

            if isRecording {
                waveformBars
            } else {
                idleContent
            }
        }
        .onAppear { startPulseIfNeeded() }
        .onChange(of: isRecording) { _, _ in startPulseIfNeeded() }
        .onChange(of: reduceMotion) { _, _ in startPulseIfNeeded() }
    }

    private func startPulseIfNeeded() {
        guard isRecording, !reduceMotion else {
            pulseActive = false
            return
        }
        pulseActive = false
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            pulseActive = true
        }
    }

    private var pulseGlowRadius: CGFloat {
        guard isRecording else { return 30 }
        guard !reduceMotion else { return 30 }
        return pulseActive ? 42 : 24
    }

    private var pulseGlowOpacity: Double {
        guard isRecording else { return 0.28 }
        guard !reduceMotion else { return 0.32 }
        return pulseActive ? 0.45 : 0.2
    }

    private var glowColor: Color {
        isRecording ? AppTheme.danger : AppTheme.accent
    }

    private var orbBorderColor: Color {
        isRecording
            ? Color(red: 1, green: 0.43, blue: 0.39).opacity(0.45)
            : Color(red: 0.47, green: 0.67, blue: 1).opacity(0.35)
    }

    private var orbGradient: RadialGradient {
        if isRecording {
            return RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 1, green: 0.47, blue: 0.43).opacity(0.45), location: 0),
                    .init(color: Color(red: 1, green: 0.27, blue: 0.23).opacity(0.1), location: 0.65)
                ]),
                center: .init(x: 0.35, y: 0.28),
                startRadius: 0,
                endRadius: 70
            )
        }
        return RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.55, green: 0.75, blue: 1).opacity(0.5), location: 0),
                .init(color: AppTheme.accent.opacity(0.12), location: 0.65)
            ]),
            center: .init(x: 0.35, y: 0.28),
            startRadius: 0,
            endRadius: 70
        )
    }

    private var idleContent: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 26, weight: .medium))
            .foregroundStyle(AppTheme.accentLight)
    }

    private var waveformBars: some View {
        HStack(spacing: 5) {
            ForEach(Array(waveformSpecs.enumerated()), id: \.offset) { _, spec in
                WaveformBar(spec: spec, reduceMotion: reduceMotion)
            }
        }
    }

    private struct BarSpec {
        let height: CGFloat
        let color: Color
        let duration: Double
        let delay: Double
    }

    private var waveformSpecs: [BarSpec] {
        [
            BarSpec(height: 14, color: Color(red: 1, green: 0.7, blue: 0.68), duration: 0.42, delay: 0.1),
            BarSpec(height: 26, color: Color(red: 1, green: 0.54, blue: 0.5), duration: 0.55, delay: 0),
            BarSpec(height: 34, color: Color(red: 1, green: 0.41, blue: 0.38), duration: 0.38, delay: 0.05),
            BarSpec(height: 22, color: Color(red: 1, green: 0.54, blue: 0.5), duration: 0.5, delay: 0.15),
            BarSpec(height: 12, color: Color(red: 1, green: 0.7, blue: 0.68), duration: 0.46, delay: 0.08)
        ]
    }

    private struct WaveformBar: View {
        let spec: BarSpec
        let reduceMotion: Bool
        @State private var scaled = false

        var body: some View {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(spec.color)
                .frame(width: 4, height: spec.height)
                .scaleEffect(y: scaleY, anchor: .center)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(
                        .easeInOut(duration: spec.duration)
                            .repeatForever(autoreverses: true)
                            .delay(spec.delay)
                    ) {
                        scaled = true
                    }
                }
        }

        private var scaleY: CGFloat {
            guard !reduceMotion else { return 1 }
            return scaled ? 1 : 0.35
        }
    }
}
