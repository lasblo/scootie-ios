import SwiftUI

struct WelcomeScreen: View {
    @EnvironmentObject var scooterManager: UnuScooterManager
    @Environment(\.openURL) private var openURL
    @Binding var hasCompletedOnboarding: Bool

    @State private var appeared = false
    @State private var showConnect = false

    private var bluetoothReady: Bool { scooterManager.bluetoothState == .poweredOn }

    var body: some View {
        ZStack {
            DeckTheme.paper.ignoresSafeArea()

            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        masthead
                        headline
                        scooterPanel
                        features
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .tint(DeckTheme.ink)
        .safeAreaInset(edge: .bottom) {
            actions
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(DeckTheme.paper)
        }
        .sheet(isPresented: $showConnect) {
            ScooterConnectionView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack(spacing: 7) {
            Text("unu")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(DeckTheme.ink)
            Text("PRO")
                .deckLabel(14)
                .foregroundStyle(DeckTheme.onLime)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(DeckTheme.lime))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DeckTheme.ink, lineWidth: 2))
            Spacer()
        }
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LET'S GET\nROLLING.")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(DeckTheme.ink)
                .lineSpacing(2)

            Text("Connect your unu pro and control it straight from your phone.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DeckTheme.ink.opacity(0.6))
        }
    }

    // MARK: - Scooter panel

    private var scooterPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("YOUR RIDE")
                    .deckLabel(12)
                    .foregroundStyle(DeckTheme.ink)
                Spacer()
                Text("ELECTRIC")
                    .deckLabel(11)
                    .foregroundStyle(DeckTheme.onLime)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(DeckTheme.lime))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DeckTheme.ink, lineWidth: 2))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Image("scooter")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .deckPanel(fill: DeckTheme.panel)
    }

    // MARK: - Features

    private var features: some View {
        VStack(spacing: 16) {
            FeatureRow(icon: "lock.open.fill",
                       title: "LOCK & UNLOCK",
                       subtitle: "Secure your scooter with one slide.")
            FeatureRow(icon: "bolt.fill",
                       title: "BATTERY & RANGE",
                       subtitle: "Every charge level at a glance.")
            FeatureRow(icon: "lightbulb.fill",
                       title: "LIGHTS & STORAGE",
                       subtitle: "Hazards and the seatbox, remote.")
        }
        .padding(.top, 2)
    }

    // MARK: - Actions (pinned)

    @ViewBuilder
    private var actions: some View {
        if scooterManager.bluetoothState == .unauthorized {
            VStack(spacing: 8) {
                Text("Bluetooth access is required. Enable it in Settings.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DeckTheme.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                DeckButton(title: "OPEN SETTINGS", systemImage: "gearshape.fill", action: openSettings)
            }
        } else {
            VStack(spacing: 8) {
                if !bluetoothReady {
                    Text(scooterManager.statusMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DeckTheme.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                DeckButton(title: "CONNECT SCOOTER",
                           systemImage: "bolt.horizontal.circle.fill",
                           enabled: bluetoothReady) {
                    showConnect = true
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
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(DeckTheme.onLime)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 10).fill(DeckTheme.lime))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DeckTheme.ink, lineWidth: 2))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .deckLabel(13)
                    .foregroundStyle(DeckTheme.ink)
                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DeckTheme.ink.opacity(0.6))
            }

            Spacer(minLength: 0)
        }
    }
}
