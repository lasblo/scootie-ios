//
//  BatteryDetailsView.swift
//  unu pro
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

    var body: some View {
        ZStack {
            DeckTheme.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header

                sectionLabel("MAIN")
                batteryRow("PRIMARY", primaryPercent)
                batteryRow("SECONDARY", secondaryPercent)

                sectionLabel("SYSTEM")
                batteryRow("CBB", cbbPercent, charging: isCharging)
                batteryRow("AUX", auxPercent)

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

    // MARK: - Row

    private func batteryRow(_ title: String, _ percent: Int, charging: Bool = false) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .deckLabel(14)
                .foregroundStyle(DeckTheme.ink)
                .frame(width: 96, alignment: .leading)

            gauge(percent)

            if charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(DeckTheme.ink)
            }

            Text("\(percent)%")
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
