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
            OnboardingBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                ConnectionHero(style: heroStyle)
                    .id(heroStyle == .success)   // re-trigger the success transition

                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)

                Spacer(minLength: 24)

                actions
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
            .padding(.vertical, 24)
            .animation(.easeInOut(duration: 0.35), value: heroStyle)
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .presentationBackground(OnboardingTheme.bgTop)
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

    private var heroStyle: ConnectionHero.Style {
        switch scooterManager.connectionPhase {
        case .idle, .scanning:        return .scanning
        case .connecting, .pairing:   return .working
        case .connected:              return .success
        case .failed:                 return .failed
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
            return "Make sure your unu pro scooter is nearby, powered on and unlocked."
        case .connecting:
            return "Establishing a secure connection to your scooter."
        case .pairing:
            return "Enter the code shown on your scooter when prompted."
        case .connected:
            return "Your unu pro scooter is connected and ready to ride."
        case .failed:
            return "Make sure your scooter is nearby, powered on and unlocked, then try again."
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch scooterManager.connectionPhase {
        case .connected:
            Button("Get Started") {
                scooterManager.handlePostOnboardingConnection()
                dismiss()
                hasCompletedOnboarding = true
            }
            .buttonStyle(PrimaryButtonStyle())

        case .failed:
            VStack(spacing: 12) {
                Button("Try Again") {
                    scooterManager.startScanning()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Cancel") {
                    scooterManager.stopScanning()
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }

        case .idle, .scanning:
            Button("Cancel") {
                scooterManager.stopScanning()
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())

        case .connecting, .pairing:
            // No disruptive action mid-connect / mid-pairing.
            EmptyView()
        }
    }
}
