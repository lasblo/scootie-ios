//
//  OnboardingTheme.swift
//  unu pro
//
//  Shared visual language for the onboarding flow: colors, the animated
//  background, reusable button styles and the phase-aware connection hero.
//

import SwiftUI

// MARK: - Palette

enum OnboardingTheme {
    static let bgTop    = Color(red: 0.04, green: 0.05, blue: 0.10)
    static let bgBottom = Color(red: 0.07, green: 0.10, blue: 0.18)

    static let accent  = Color(red: 0.10, green: 0.85, blue: 0.74)   // teal
    static let accent2 = Color(red: 0.17, green: 0.55, blue: 1.00)   // blue
    static let danger  = Color(red: 1.00, green: 0.45, blue: 0.45)

    static let accentGradient = LinearGradient(
        colors: [accent, accent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let onAccent = Color(red: 0.03, green: 0.06, blue: 0.12)
}

// MARK: - Animated background

struct OnboardingBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [OnboardingTheme.bgTop, OnboardingTheme.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // Soft drifting glow "blobs" for depth.
            Circle()
                .fill(OnboardingTheme.accent.opacity(0.28))
                .frame(width: 340)
                .blur(radius: 130)
                .offset(x: drift ? -130 : -70, y: drift ? -280 : -230)

            Circle()
                .fill(OnboardingTheme.accent2.opacity(0.24))
                .frame(width: 380)
                .blur(radius: 150)
                .offset(x: drift ? 150 : 90, y: drift ? 300 : 360)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(OnboardingTheme.onAccent)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(OnboardingTheme.accentGradient)
            )
            .opacity(enabled ? 1 : 0.4)
            .shadow(color: OnboardingTheme.accent.opacity(enabled ? 0.45 : 0),
                    radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

// MARK: - Connection hero

/// The central animated graphic on the connection sheet. Adapts its rings,
/// glow and glyph to the current connection phase.
struct ConnectionHero: View {
    enum Style { case scanning, working, success, failed }

    var style: Style

    private var ringColor: Color {
        switch style {
        case .success: return OnboardingTheme.accent
        case .failed:  return OnboardingTheme.danger
        default:       return OnboardingTheme.accent2
        }
    }

    var body: some View {
        ZStack {
            // Radar pulse while scanning.
            if style == .scanning {
                PulseRings()
            }

            // Glassy base disc.
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 180, height: 180)
                .overlay(
                    Circle().stroke(ringColor.opacity(0.85), lineWidth: 2)
                )
                .shadow(color: ringColor.opacity(0.5), radius: 30)

            // Spinning arc while connecting / pairing.
            if style == .working {
                SpinningArc()
            }

            glyph
        }
        .frame(width: 220, height: 220)
    }

    @ViewBuilder
    private var glyph: some View {
        switch style {
        case .success:
            Image(systemName: "checkmark")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(OnboardingTheme.accent)
                .transition(.scale.combined(with: .opacity))
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(OnboardingTheme.danger)
        default:
            Image(systemName: "scooter")
                .font(.system(size: 58))
                .foregroundStyle(.white)
        }
    }
}

// Self-contained so the animation re-fires every time the rings are inserted.
private struct PulseRings: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(OnboardingTheme.accent.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 180, height: 180)
                    .scaleEffect(animate ? 1.7 : 0.85)
                    .opacity(animate ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 2.6)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.85),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

private struct SpinningArc: View {
    @State private var rotate = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(OnboardingTheme.accentGradient,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 180, height: 180)
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    rotate = true
                }
            }
    }
}
