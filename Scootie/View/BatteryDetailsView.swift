//
//  BatteryDetailsView.swift
//  Scootie
//
//  Created by Lasse Blomenkemper on 24.01.25.
//

import SwiftUI

struct BatteryDetailsView: View {
    let primaryPercent: Int
    let secondaryPercent: Int
    let cbbPercent: Int
    let auxPercent: Int
    let isCharging: Bool

    private struct Battery: Identifiable {
        var id: String { title }
        let title: String
        let percent: Int
        var charging: Bool = false
    }

    // A 0% reading means the scooter doesn't report that pack — hide it.
    private var main: [Battery] {
        [Battery(title: "PRIMARY", percent: primaryPercent),
         Battery(title: "SECONDARY", percent: secondaryPercent)]
            .filter { $0.percent > 0 }
    }
    private var system: [Battery] {
        [Battery(title: "CBB", percent: cbbPercent, charging: isCharging),
         Battery(title: "AUX", percent: auxPercent)]
            .filter { $0.percent > 0 }
    }
    private var hasAny: Bool { !main.isEmpty || !system.isEmpty }

    var body: some View {
        ZStack {
            DeckTheme.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header

                if hasAny {
                    if !main.isEmpty {
                        sectionLabel("MAIN")
                        ForEach(main) { batteryRow($0) }
                    }
                    if !system.isEmpty {
                        sectionLabel("SYSTEM")
                        ForEach(system) { batteryRow($0) }
                    }
                } else {
                    emptyState
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(DeckTheme.paper)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("BATTERY")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(DeckTheme.ink)

            Spacer()

            if isCharging {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .black))
                    Text("CHARGING").deckLabel(12)
                }
                .foregroundStyle(DeckTheme.onLime)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(DeckTheme.lime))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DeckTheme.ink, lineWidth: 2))
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(DeckTheme.ink.opacity(0.5))
            Text("NO BATTERY DATA")
                .deckLabel(13)
                .foregroundStyle(DeckTheme.ink)
            Text("Connect your scooter to see battery levels.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(DeckTheme.ink.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .deckPanel(fill: DeckTheme.panel)
    }

    // MARK: - Row

    private func batteryRow(_ battery: Battery) -> some View {
        HStack(spacing: 14) {
            Text(battery.title)
                .deckLabel(14)
                .foregroundStyle(DeckTheme.ink)
                .frame(width: 96, alignment: .leading)

            gauge(battery.percent)

            if battery.charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(DeckTheme.ink)
            }

            Text("\(battery.percent)%")
                .deckLabel(16)
                .foregroundStyle(DeckTheme.ink)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .deckPanel(fill: DeckTheme.panel)
    }

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
        .frame(height: 20)
    }
}
