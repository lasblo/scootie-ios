//
//  DebugMenuView.swift
//  unu pro
//
//  Created by Lasse Blomenkemper on 20.05.25.
//

import SwiftUI

struct DebugMenuView: View {
    @ObservedObject var scooterManager: UnuScooterManager
    @Environment(\.dismiss) private var dismiss
    @State private var commandText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Send Command") {
                    HStack {
                        TextField("Command", text: $commandText)
                        Button("Send") {
                            scooterManager.sendCustomCommand(commandText)
                            commandText = ""
                        }
                        .disabled(commandText.isEmpty)
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DebugMenuView(scooterManager: UnuScooterManager())
}
