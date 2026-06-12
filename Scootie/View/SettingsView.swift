//
//  SettingsView.swift
//  Scootie
//
//  Deck-styled settings: auto-unlock (with a minimum signal threshold) and
//  auto-open-seat on unlock.
//

import SwiftUI

enum SettingsKeys {
    static let autoUnlock = "autoUnlockOnOpen"
    static let autoUnlockMinRSSI = "autoUnlockMinRSSI"   // default -65
    static let autoOpenSeat = "autoOpenSeatOnUnlock"
    static let lastSeen = "scooterLastSeen"              // Double, since 1970

    static let defaultMinRSSI = -65
    static let minRSSIRange: ClosedRange<Double> = -85...(-55)
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKeys.autoUnlock) private var autoUnlock = false
    @AppStorage(SettingsKeys.autoUnlockMinRSSI) private var minRSSI = SettingsKeys.defaultMinRSSI
    @AppStorage(SettingsKeys.autoOpenSeat) private var autoOpenSeat = false

    var body: some View {
        ZStack {
            DeckTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    sectionLabel("UNLOCKING")
                    toggleRow(title: "AUTO-UNLOCK ON OPEN",
                              subtitle: "Unlock the scooter when you open the app.",
                              isOn: $autoUnlock)
                    if autoUnlock { signalPanel }

                    toggleRow(title: "OPEN SEAT ON UNLOCK",
                              subtitle: "Pop the seatbox whenever the scooter unlocks.",
                              isOn: $autoOpenSeat)

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .tint(DeckTheme.ink)
        .presentationDragIndicator(.visible)
        .presentationBackground(DeckTheme.paper)
        .presentationDetents([.medium, .large])
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("SETTINGS")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(DeckTheme.ink)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(DeckTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DeckTheme.panel))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DeckTheme.ink, lineWidth: 2))
            }
        }
        .padding(.top, 8)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .deckLabel(12)
            .foregroundStyle(DeckTheme.ink.opacity(0.55))
            .padding(.top, 4)
    }

    // MARK: - Toggle row

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .deckLabel(14)
                    .foregroundStyle(DeckTheme.ink)
                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DeckTheme.ink.opacity(0.6))
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(DeckTheme.lime)
        }
        .padding(16)
        .deckPanel(fill: DeckTheme.panel)
    }

    // MARK: - Signal threshold

    private var signalPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MIN. SIGNAL")
                    .deckLabel(13)
                    .foregroundStyle(DeckTheme.ink)
                Spacer()
                Text("\(minRSSI) dBm")
                    .deckLabel(14)
                    .foregroundStyle(DeckTheme.onLime)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(DeckTheme.lime))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DeckTheme.ink, lineWidth: 2))
            }

            Slider(
                value: Binding(
                    get: { Double(minRSSI) },
                    set: { minRSSI = Int(($0 / 5).rounded() * 5) }
                ),
                in: SettingsKeys.minRSSIRange,
                step: 5
            )
            .tint(DeckTheme.lime)

            HStack {
                Text("FARTHER").deckLabel(11).foregroundStyle(DeckTheme.ink.opacity(0.5))
                Spacer()
                Text("CLOSER").deckLabel(11).foregroundStyle(DeckTheme.ink.opacity(0.5))
            }

            Text("Only auto-unlock when the scooter is at least this close.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(DeckTheme.ink.opacity(0.6))
        }
        .padding(16)
        .deckPanel(fill: DeckTheme.panel)
    }
}
