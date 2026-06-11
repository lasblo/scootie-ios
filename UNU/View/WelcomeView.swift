import SwiftUI

struct WelcomeScreen: View {
    @EnvironmentObject var scooterManager: UnuScooterManager
    @Environment(\.openURL) private var openURL
    @Binding var hasCompletedOnboarding: Bool

    @State private var appeared = false
    @State private var float = false
    @State private var showConnect = false

    private var bluetoothReady: Bool { scooterManager.bluetoothState == .poweredOn }

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                hero
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.05),
                               value: appeared)

                titleBlock
                    .padding(.top, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15),
                               value: appeared)

                features
                    .padding(.top, 36)
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.25),
                               value: appeared)

                Spacer(minLength: 24)

                actions
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.35),
                               value: appeared)
            }
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showConnect) {
            ScooterConnectionView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                float = true
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            Circle()
                .fill(OnboardingTheme.accentGradient)
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .opacity(0.45)

            Image("scooter")
                .resizable()
                .scaledToFit()
                .frame(height: 180)
                .shadow(color: OnboardingTheme.accent.opacity(0.5), radius: 28, y: 10)
                .offset(y: float ? -10 : 10)
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text("Welcome to")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Text("unu pro")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingTheme.accentGradient)

            Text("Connect your scooter and control it\nwith just your phone.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 4)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Feature highlights

    private var features: some View {
        VStack(spacing: 18) {
            FeatureRow(icon: "lock.open.fill",
                       title: "Lock & unlock",
                       subtitle: "Secure your scooter with a single tap.")
            FeatureRow(icon: "bolt.fill",
                       title: "Battery & range",
                       subtitle: "Check every charge level at a glance.")
            FeatureRow(icon: "lightbulb.fill",
                       title: "Lights & seat",
                       subtitle: "Blinkers, hazards and the seatbox.")
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 14) {
            if scooterManager.bluetoothState == .unauthorized {
                Button(action: openSettings) {
                    Label("Open Settings", systemImage: "gearshape.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("Bluetooth access is required to connect to your scooter. Enable it in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            } else {
                Button {
                    showConnect = true
                } label: {
                    Label("Connect your scooter", systemImage: "bolt.horizontal.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle(enabled: bluetoothReady))
                .disabled(!bluetoothReady)

                if !bluetoothReady {
                    Label(scooterManager.statusMessage, systemImage: "antenna.radiowaves.left.and.right.slash")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

// MARK: - Feature row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer(minLength: 0)
        }
    }
}
