//
//  DebugMenuView.swift
//  Scootie
//
//  Created by Lasse Blomenkemper on 20.05.25.
//

import SwiftUI
import CoreBluetooth

struct DebugMenuView: View {
    @ObservedObject var scooterManager: UnuScooterManager
    @Environment(\.dismiss) private var dismiss
    @State private var commandText = ""

    var body: some View {
        ZStack {
            DeckTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    commandPanel
                    statePanel
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
        HStack(spacing: 8) {
            Text("DEBUG")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(DeckTheme.ink)

            Text("DEV")
                .deckLabel(11)
                .foregroundStyle(DeckTheme.onLime)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(DeckTheme.lime))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DeckTheme.ink, lineWidth: 2))

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
    }

    // MARK: - Send command

    private var commandPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SEND COMMAND")
                .deckLabel(12)
                .foregroundStyle(DeckTheme.ink.opacity(0.55))

            TextField("scooter:state unlock", text: $commandText)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(DeckTheme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(DeckTheme.paper))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DeckTheme.ink, lineWidth: 2))

            DeckButton(title: "SEND",
                       systemImage: "paperplane.fill",
                       enabled: !commandText.isEmpty) {
                scooterManager.sendCustomCommand(commandText)
                commandText = ""
            }
        }
        .padding(16)
        .deckPanel(fill: DeckTheme.panel)
    }

    // MARK: - Live state

    private var statePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LIVE STATE")
                .deckLabel(12)
                .foregroundStyle(DeckTheme.ink.opacity(0.55))
                .padding(.bottom, 10)

            stateRow("PHASE", phaseText)
            divider
            stateRow("CONNECTED", scooterManager.isConnected ? "YES" : "NO")
            divider
            stateRow("LOCK", scooterManager.isLocked ? "LOCKED" : "UNLOCKED")
            divider
            stateRow("STATE", stateText)
            divider
            stateRow("BLUETOOTH", bluetoothText)
            divider
            stateRow("CHARGING", scooterManager.cbbIsCharging ? "YES" : "NO")
            divider
            stateRow("BATTERY", batteryText)
        }
        .padding(16)
        .deckPanel(fill: DeckTheme.panel)
    }

    private var divider: some View {
        Rectangle()
            .fill(DeckTheme.ink.opacity(0.12))
            .frame(height: 1)
    }

    private func stateRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .deckLabel(12)
                .foregroundStyle(DeckTheme.ink.opacity(0.55))
            Spacer()
            Text(value)
                .deckLabel(13)
                .foregroundStyle(DeckTheme.ink)
        }
        .padding(.vertical, 9)
    }

    // MARK: - Readouts

    private var phaseText: String {
        switch scooterManager.connectionPhase {
        case .idle:       return "IDLE"
        case .scanning:   return "SCANNING"
        case .connecting: return "CONNECTING"
        case .pairing:    return "PAIRING"
        case .connected:  return "CONNECTED"
        case .failed:     return "FAILED"
        }
    }

    private var stateText: String {
        switch scooterManager.currentState {
        case .standby:      return "STANDBY"
        case .unlocked:     return "UNLOCKED"
        case .riding:       return "RIDING"
        case .parked:       return "PARKED"
        case .charging:     return "CHARGING"
        case .linking:      return "LINKING"
        case .disconnected: return "DISCONNECTED"
        case .shuttingDown: return "SHUTTING DOWN"
        case .unknown(let s): return s.uppercased()
        }
    }

    private var bluetoothText: String {
        switch scooterManager.bluetoothState {
        case .poweredOn:    return "ON"
        case .poweredOff:   return "OFF"
        case .unauthorized: return "UNAUTHORIZED"
        case .unsupported:  return "UNSUPPORTED"
        case .resetting:    return "RESETTING"
        case .unknown:      return "UNKNOWN"
        @unknown default:   return "?"
        }
    }

    private var batteryText: String {
        "P\(scooterManager.primaryBatteryPercent) · S\(scooterManager.secondaryBatteryPercent) · C\(scooterManager.cbbBatteryPercent) · A\(scooterManager.auxBatteryPercent)"
    }
}

#Preview {
    DebugMenuView(scooterManager: UnuScooterManager())
}
