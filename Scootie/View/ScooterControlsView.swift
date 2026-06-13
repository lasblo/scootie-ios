//
//  ScooterControlsView.swift
//  Scootie
//
//  Created by Lasse on 24.01.25.
//

import SwiftUI

struct ScooterControlsView: View {
    @EnvironmentObject var scooterManager: UnuScooterManager
    @State private var showBatteryDetails = false
    @State private var showDebugMenu = false
    @State private var showSettings = false

    // For the custom drag gesture on the lock slider
    @GestureState private var dragState = DragState.inactive
    enum DragState {
        case inactive
        case dragging(translation: CGFloat)

        var translation: CGFloat {
            switch self {
            case .inactive:               return 0
            case .dragging(let distance): return distance
            }
        }
    }

    var body: some View {
        ZStack {
            DeckTheme.paper.ignoresSafeArea()

            // Fill at least the viewport so the Spacer pushes the controls down
            // into the thumb zone; still scrolls on very small screens.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 22) {
                        masthead
                        if scooterManager.autoUnlockArmed {
                            autoUnlockBanner
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        displayPanel          // hero card grows to fill the height
                        HStack(spacing: 14) {
                            storageTile
                            hazardTile
                        }
                        .padding(.top, 6)     // a touch more so it visually matches the tiles↔lock gap
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                    .frame(minHeight: geo.size.height)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: scooterManager.autoUnlockArmed)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
        }
        .tint(DeckTheme.ink)
        // Lock control pinned to the bottom — the primary action, kept in
        // easy thumb reach on large phones.
        .safeAreaInset(edge: .bottom) {
            lockSlider
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(DeckTheme.paper)
        }
        .sheet(isPresented: $showDebugMenu) {
            DebugMenuView(scooterManager: scooterManager)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showBatteryDetails) {
            BatteryDetailsView(
                primaryPercent: scooterManager.primaryBatteryPercent,
                secondaryPercent: scooterManager.secondaryBatteryPercent,
                cbbPercent: scooterManager.cbbBatteryPercent,
                auxPercent: scooterManager.auxBatteryPercent,
                isCharging: scooterManager.cbbIsCharging
            )
            .presentationDetents([.medium, .large])
        }
        .alert(scooterManager.lockAlertMessage, isPresented: $scooterManager.showLockAlert) {
            Button("Ignore", role: .destructive) {}
            Button("Retry") { scooterManager.restartAndLock() }
        }
        .onAppear {
            scooterManager.beginConnecting()
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Scootie")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(DeckTheme.ink)
                .onLongPressGesture { showDebugMenu = true }

            Spacer()

            statusChip

            if canRetry {
                retryButton
            }

            settingsButton
        }
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(DeckTheme.ink)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(DeckTheme.panel))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DeckTheme.ink, lineWidth: 2))
        }
    }

    // Show a retry affordance in any disconnected state that isn't currently
    // trying to (re)connect.
    private var canRetry: Bool {
        if case .failed = scooterManager.connectionPhase { return true }
        return false
    }

    private var retryButton: some View {
        Button {
            scooterManager.beginConnecting()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(DeckTheme.onLime)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(DeckTheme.lime))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DeckTheme.ink, lineWidth: 2))
        }
    }

    private var statusChip: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(scooterManager.isConnected ? DeckTheme.lime : DeckTheme.signal)
                .frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(DeckTheme.ink, lineWidth: 1.5))

            Text((scooterManager.isConnected ? "live" : scooterManager.statusMessage).uppercased())
                .deckLabel(12, weight: .bold)
                .foregroundStyle(DeckTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)   // match the 40pt settings / retry buttons
        .background(RoundedRectangle(cornerRadius: 8).fill(DeckTheme.panel))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DeckTheme.ink, lineWidth: 2))
    }

    // MARK: - Auto-unlock banner

    private var autoUnlockBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(DeckTheme.onLime)

            VStack(alignment: .leading, spacing: 2) {
                Text("AUTO-UNLOCK ARMED")
                    .deckLabel(12)
                    .foregroundStyle(DeckTheme.onLime)
                Text(scooterManager.isConnected
                     ? "Unlocking as soon as you're close"
                     : "Unlocks once connected & you're close")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DeckTheme.onLime.opacity(0.7))
            }

            Spacer(minLength: 8)

            Button { scooterManager.cancelAutoUnlock() } label: {
                Text("CANCEL")
                    .deckLabel(12)
                    .foregroundStyle(DeckTheme.onLime)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DeckTheme.onLime, lineWidth: 2))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: DeckTheme.radius, style: .continuous).fill(DeckTheme.lime))
        .overlay(RoundedRectangle(cornerRadius: DeckTheme.radius, style: .continuous).strokeBorder(DeckTheme.ink, lineWidth: DeckTheme.border))
    }

    // MARK: - Scooter display panel

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private var lastSeenText: String {
        if scooterManager.isConnected { return "CONNECTED" }
        guard let seen = scooterManager.lastSeen else { return "NOT CONNECTED YET" }
        return "LAST SEEN " + Self.relativeFormatter.localizedString(for: seen, relativeTo: Date()).uppercased()
    }

    private var displayPanel: some View {
        Button {
            showBatteryDetails = true
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("YOUR RIDE")
                            .deckLabel(12)
                            .foregroundStyle(DeckTheme.ink)
                        Text(lastSeenText)
                            .deckLabel(10, weight: .bold)
                            .foregroundStyle(DeckTheme.ink.opacity(0.5))
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: scooterManager.cbbIsCharging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 11, weight: .black))
                        Text(scooterManager.isConnected && scooterManager.primaryBatteryPercent > 0
                             ? "\(scooterManager.primaryBatteryPercent)%" : "--")
                            .deckLabel(12)
                    }
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 10)

                // Battery instrument along the base — tap the panel for details.
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(DeckTheme.ink)
                    Text("BATTERY")
                        .deckLabel(12)
                        .foregroundStyle(DeckTheme.ink)

                    gauge(scooterManager.isConnected ? scooterManager.primaryBatteryPercent : 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(DeckTheme.ink)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 14)
            }
        }
        .buttonStyle(DeckTileStyle(fill: DeckTheme.panel))
    }

    // MARK: - Slide to lock / unlock

    private var lockSlider: some View {
        let knob: CGFloat = 58
        let pad: CGFloat = 6
        let unlocked = !scooterManager.isLocked
        let connected = scooterManager.isConnected

        return GeometryReader { geo in
            let maxX = max(0, geo.size.width - knob - pad * 2)

            ZStack {
                // hard shadow
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DeckTheme.ink)
                    .offset(x: DeckTheme.drop, y: DeckTheme.drop)

                // track
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill((connected && unlocked) ? DeckTheme.lime : DeckTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(DeckTheme.ink, lineWidth: DeckTheme.border)
                    )

                Text(connected ? (unlocked ? "SLIDE TO LOCK" : "SLIDE TO UNLOCK") : "SCOOTER OFFLINE")
                    .deckLabel(15)
                    .foregroundStyle((connected && unlocked) ? DeckTheme.onLime : DeckTheme.ink)
                    .offset(x: knob / 2)

                // knob
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DeckTheme.ink)
                        Image(systemName: scooterManager.isLocked ? "lock.fill" : "lock.open.fill")
                            .font(.system(size: 21, weight: .heavy))
                            .foregroundStyle(DeckTheme.paper)
                    }
                    .frame(width: knob, height: knob)
                    .offset(x: dragState.translation)
                    .gesture(
                        DragGesture()
                            .updating($dragState) { value, state, _ in
                                let t = min(max(0, value.translation.width), maxX)
                                state = .dragging(translation: t)
                            }
                            .onEnded { value in
                                if value.translation.width > geo.size.width * 0.5 {
                                    if scooterManager.isLocked {
                                        scooterManager.unlock()
                                    } else {
                                        scooterManager.lock()
                                    }
                                }
                            }
                    )

                    Spacer()
                }
                .padding(pad)
            }
        }
        .frame(height: 70)
        .opacity(connected ? 1 : 0.5)
        .allowsHitTesting(connected)
    }

    // MARK: - Action tiles

    private var hazardTile: some View {
        let on = scooterManager.hazardLightsOn
        return Button {
            scooterManager.sendBlinkerCommand(state: on ? "off" : "both")
            scooterManager.hazardLightsOn.toggle()
        } label: {
            VStack(spacing: 10) {
                BlinkingImage(systemName: "exclamationmark.triangle.fill",
                              isBlinking: on,
                              color: on ? DeckTheme.onSignal : DeckTheme.ink)
                Text(on ? "HAZARDS ON" : "HAZARDS")
                    .deckLabel(13)
                    .foregroundStyle(on ? DeckTheme.onSignal : DeckTheme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .buttonStyle(DeckTileStyle(fill: on ? DeckTheme.signal : DeckTheme.panel))
        .disabled(!scooterManager.isConnected)
        .opacity(scooterManager.isConnected ? 1 : 0.4)
    }

    private var storageTile: some View {
        Button {
            scooterManager.openSeat()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(DeckTheme.ink)
                Text("STORAGE")
                    .deckLabel(13)
                    .foregroundStyle(DeckTheme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .buttonStyle(DeckTileStyle(fill: DeckTheme.panel))
        .disabled(!scooterManager.isConnected)
        .opacity(scooterManager.isConnected ? 1 : 0.4)
    }

    // MARK: - Battery gauge

    private func gauge(_ pct: Int) -> some View {
        let clamped = CGFloat(max(0, min(100, pct))) / 100
        let fill = pct <= 15 ? DeckTheme.signal : DeckTheme.lime
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5).fill(DeckTheme.paper)
                RoundedRectangle(cornerRadius: 5)
                    .fill(fill)
                    .frame(width: g.size.width * clamped)
            }
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(DeckTheme.ink, lineWidth: 2))
        }
        .frame(height: 22)
    }
}

// MARK: - BlinkingImage

struct BlinkingImage: View {
    let systemName: String
    let isBlinking: Bool
    var color: Color = DeckTheme.ink

    @State private var isVisible = true

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 24, weight: .black))
            .foregroundStyle(color)
            .opacity(isBlinking ? (isVisible ? 1 : 0.25) : 1)
            .onChange(of: isBlinking) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                        isVisible.toggle()
                    }
                } else {
                    withAnimation(.none) {
                        isVisible = true
                    }
                }
            }
    }
}
