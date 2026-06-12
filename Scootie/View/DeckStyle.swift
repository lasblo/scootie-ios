//
//  DeckStyle.swift
//  Scootie
//
//  "Control deck" visual language: heavy ink outlines, hard offset shadows
//  (no blur), monospaced technical labels and a single electric-lime accent.
//  Everything inverts paper <-> ink between light and dark mode.
//

import SwiftUI
import UIKit

// MARK: - Color helpers

private extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue:  CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// A single tone, identical in light and dark.
    init(rgb: UInt) { self = Color(uiColor: UIColor(rgb: rgb)) }

    /// A tone that swaps between light and dark appearance.
    init(light: UInt, dark: UInt) {
        self = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

// MARK: - Theme

enum DeckTheme {
    static let paper = Color(light: 0xEDE7D9, dark: 0x141209)   // page background
    static let panel = Color(light: 0xFBF8F0, dark: 0x211D12)   // raised surface
    static let ink   = Color(light: 0x16130B, dark: 0xF1EBDC)   // outlines + text (contrast)
    static let lime  = Color(rgb: 0xC4F042)                     // electric accent
    static let signal = Color(rgb: 0xFF5A38)                    // hazard / alert
    static let onLime  = Color(rgb: 0x16130B)                   // text on lime (always dark)
    static let onSignal = Color(rgb: 0xFFF3EC)                  // text on signal (always light)

    static let radius: CGFloat = 14
    static let border: CGFloat = 2.5
    static let drop: CGFloat = 5            // hard-shadow offset
}

// MARK: - Hard-shadow panel (non-interactive surfaces)

private struct DeckPanel: ViewModifier {
    var fill: Color
    var radius: CGFloat = DeckTheme.radius

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(DeckTheme.ink, lineWidth: DeckTheme.border)
            )
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DeckTheme.ink)
                    .offset(x: DeckTheme.drop, y: DeckTheme.drop)
            )
    }
}

extension View {
    func deckPanel(fill: Color = DeckTheme.panel, radius: CGFloat = DeckTheme.radius) -> some View {
        modifier(DeckPanel(fill: fill, radius: radius))
    }
}

// MARK: - Tile button (presses down into its shadow)

struct DeckTileStyle: ButtonStyle {
    var fill: Color = DeckTheme.panel
    var radius: CGFloat = DeckTheme.radius

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        // Use .background/.overlay (which size to the content) rather than a
        // ZStack with a bare shape — a bare shape is greedy and would stretch
        // the button to fill its container.
        return configuration.label
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(DeckTheme.ink, lineWidth: DeckTheme.border)
            )
            .offset(x: pressed ? DeckTheme.drop : 0,
                    y: pressed ? DeckTheme.drop : 0)
            // Static hard shadow behind, sized to the content (does not move on press).
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DeckTheme.ink)
                    .offset(x: DeckTheme.drop, y: DeckTheme.drop)
            )
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

// MARK: - Full-width deck button

struct DeckButton: View {
    let title: String
    var systemImage: String? = nil
    var fill: Color = DeckTheme.lime
    var textColor: Color = DeckTheme.onLime
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .black))
                }
                Text(title).deckLabel(15)
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(DeckTileStyle(fill: fill))
        .disabled(!enabled)
    }
}

// MARK: - Monospaced "instrument" label

extension Text {
    func deckLabel(_ size: CGFloat = 13, weight: Font.Weight = .black) -> Text {
        self.font(.system(size: size, weight: weight, design: .monospaced))
            .kerning(0.5)
    }
}
