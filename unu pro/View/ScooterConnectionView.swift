//
//  ScooterConnectionView.swift
//  unu pro
//
//  Created by Lasse on 24.01.25.
//


import SwiftUI

struct ScooterConnectionView: View {
    @EnvironmentObject var scooterManager: UnuScooterManager
    @Environment(\.dismiss) private var dismiss
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        ZStack {
            DeckTheme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                ConnectionHeroPanel(style: heroStyle)
                    .animation(.easeInOut(duration: 0.3), value: heroStyle)

                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(DeckTheme.ink)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DeckTheme.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 30)

                Spacer(minLength: 24)

                actions
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .padding(.vertical, 24)
        }
        .tint(DeckTheme.ink)
        .presentationDragIndicator(.visible)
        .presentationBackground(DeckTheme.paper)
        .onAppear {
            scooterManager.startScanning()
        }
        .onDisappear {
            if !scooterManager.isConnected {
                scooterManager.stopScanning()
            }
        }
    }

    // MARK: - Phase mapping

    private var heroStyle: ConnectionHeroPanel.Style {
        switch scooterManager.connectionPhase {
        case .idle, .scanning:       return .scanning
        case .connecting, .pairing:  return .working
        case .connected:             return .success
        case .failed:                return .failed
        }
    }

    private var title: String {
        switch scooterManager.connectionPhase {
        case .idle, .scanning:  return "Looking for your scooter"
        case .connecting:       return "Connecting…"
        case .pairing:          return "Pair your scooter"
        case .connected:        return "You're all set!"
        case .failed(let msg):  return msg
        }
    }

    private var subtitle: String {
        switch scooterManager.connectionPhase {
        case .idle, .scanning:
            return "Make sure your unu pro is nearby, powered on and unlocked."
        case .connecting:
            return "Establishing a secure connection to your scooter."
        case .pairing:
            return "Enter the code shown on your scooter when prompted."
        case .connected:
            return "Your unu pro is connected and ready to ride."
        case .failed:
            return "Make sure your scooter is nearby, powered on and unlocked, then try again."
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch scooterManager.connectionPhase {
        case .connected:
            DeckButton(title: "GET STARTED", systemImage: "checkmark") {
                scooterManager.handlePostOnboardingConnection()
                dismiss()
                hasCompletedOnboarding = true
            }

        case .failed:
            VStack(spacing: 12) {
                DeckButton(title: "TRY AGAIN", systemImage: "arrow.clockwise") {
                    scooterManager.startScanning()
                }
                DeckButton(title: "CANCEL",
                           fill: DeckTheme.panel,
                           textColor: DeckTheme.ink) {
                    scooterManager.stopScanning()
                    dismiss()
                }
            }

        case .idle, .scanning:
            DeckButton(title: "CANCEL",
                       fill: DeckTheme.panel,
                       textColor: DeckTheme.ink) {
                scooterManager.stopScanning()
                dismiss()
            }

        case .connecting, .pairing:
            // No disruptive action mid-connect / mid-pairing.
            EmptyView()
        }
    }
}

// MARK: - Connection hero panel

struct ConnectionHeroPanel: View {
    enum Style { case scanning, working, success, failed }

    var style: Style

    private var panelFill: Color {
        switch style {
        case .success: return DeckTheme.lime
        case .failed:  return DeckTheme.signal
        default:       return DeckTheme.panel
        }
    }

    private var glyphColor: Color {
        switch style {
        case .success: return DeckTheme.onLime
        case .failed:  return DeckTheme.onSignal
        default:       return DeckTheme.ink
        }
    }

    private var glyph: String {
        switch style {
        case .success: return "checkmark"
        case .failed:  return "exclamationmark.triangle.fill"
        default:       return "scooter"
        }
    }

    private var showScan: Bool {
        style == .scanning || style == .working
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: glyph)
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(glyphColor)
                .frame(width: 220, height: 168)
                .deckPanel(fill: panelFill)

            // Indeterminate "scan" sweep while searching / connecting.
            ScanBar()
                .frame(width: 220)
                .opacity(showScan ? 1 : 0)
        }
    }
}

// MARK: - Sweeping scan bar

private struct ScanBar: View {
    @State private var t: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            let segW = g.size.width * 0.34
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(DeckTheme.paper)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(DeckTheme.lime)
                        .frame(width: segW)
                        .offset(x: t * (g.size.width - segW))
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(DeckTheme.ink, lineWidth: 2)
                )
        }
        .frame(height: 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                t = 1
            }
        }
    }
}
