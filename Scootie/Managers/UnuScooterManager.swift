//
//  UnuScooterManager.swift
//  Scootie
//
//  Created by Lasse on 24.01.25.
//

import SwiftUI
import CoreBluetooth
import Combine

@MainActor
class UnuScooterManager: NSObject, ObservableObject {
    
    // MARK: - Published & Public Properties
    
    @Published private(set) var isScanning = false
    @Published private(set) var isConnected = false
    @Published private(set) var isLocked = true
    @Published private(set) var isPairing = false
    @Published private(set) var needsPairing = false
    @Published private(set) var statusMessage = ""
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var currentState: ScooterState = .disconnected
    @Published private(set) var pendingStartScan = false
    @Published private(set) var connectionPhase: ConnectionPhase = .idle
    
    
    @Published var hazardLightsOn = false
    
    // Battery Percentages
    @Published private(set) var primaryBatteryPercent: Int = 0
    @Published private(set) var secondaryBatteryPercent: Int = 0
    @Published private(set) var cbbBatteryPercent: Int = 0
    @Published private(set) var auxBatteryPercent: Int = 0
    @Published private(set) var cbbIsCharging: Bool = false
    
    // Alert handling (for lock/wake issues)
    @Published var showLockAlert = false
    @Published var lockAlertMessage = ""

    // Last time we had a live connection to the scooter (persisted).
    @Published private(set) var lastSeen: Date?

    // Armed on app-open when auto-unlock is enabled; consumed once we read RSSI.
    // Auto-unlock is "armed" from app-open until it fires, the user cancels,
    // or the app backgrounds. While armed we poll RSSI and unlock once the
    // scooter is close enough.
    @Published private(set) var autoUnlockArmed = false
    private var autoUnlockPolling = false

    // MARK: - Settings (read from UserDefaults)

    private var autoUnlockEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.autoUnlock)
    }
    private var autoUnlockMinRSSI: Int {
        (UserDefaults.standard.object(forKey: SettingsKeys.autoUnlockMinRSSI) as? Int)
            ?? SettingsKeys.defaultMinRSSI
    }
    private var autoOpenSeatOnUnlock: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.autoOpenSeat)
    }

    // MARK: - Private Properties

    private var centralManager: CBCentralManager!
    private var scooter: CBPeripheral?

    // Staged discovery: command+main services first (fast unlock), battery after.
    private var didStageRestDiscovery = false
    
    // Characteristics
    private var commandCharacteristic: CBCharacteristic?
    private var stateCharacteristic: CBCharacteristic?
    private var powerStateCharacteristic: CBCharacteristic?
    private var handlebarCharacteristic: CBCharacteristic?
    private var hibernationCommandCharacteristic: CBCharacteristic?
    
    // Battery-specific characteristics
    private var auxSOCCharacteristic: CBCharacteristic?
    private var cbbSOCCharacteristic: CBCharacteristic?
    private var cbbChargingCharacteristic: CBCharacteristic?
    private var primarySOCCharacteristic: CBCharacteristic?
    private var secondarySOCCharacteristic: CBCharacteristic?
    
    // Timers & Combine
    private var stateUpdateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // App storage
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // MARK: - Services
    
    private let commandServiceUUID = CBUUID(string: "9a590000-6e67-5d0d-aab9-ad9126b66f91")
    private let mainServiceUUID    = CBUUID(string: "9a590020-6e67-5d0d-aab9-ad9126b66f91")
    private let powerServiceUUID   = CBUUID(string: "9a5900a0-6e67-5d0d-aab9-ad9126b66f91")
    private let auxServiceUUID     = CBUUID(string: "9a590040-6e67-5d0d-aab9-ad9126b66f91")
    private let cbbServiceUUID     = CBUUID(string: "9a590060-6e67-5d0d-aab9-ad9126b66f91")
    private let primaryServiceUUID = CBUUID(string: "9a5900e0-6e67-5d0d-aab9-ad9126b66f91")
    
    // MARK: - Characteristics
    
    private let commandCharUUID            = CBUUID(string: "9a590001-6e67-5d0d-aab9-ad9126b66f91")
    private let hibernationCommandCharUUID = CBUUID(string: "9a590002-6e67-5d0d-aab9-ad9126b66f91")
    private let stateCharUUID              = CBUUID(string: "9a590021-6e67-5d0d-aab9-ad9126b66f91")
    private let powerStateCharUUID         = CBUUID(string: "9a5900a1-6e67-5d0d-aab9-ad9126b66f91")
    private let handlebarCharUUID          = CBUUID(string: "9a590023-6e67-5d0d-aab9-ad9126b66f91")
    
    private let auxSOCCharUUID       = CBUUID(string: "9a590044-6e67-5d0d-aab9-ad9126b66f91")
    private let cbbSOCCharUUID       = CBUUID(string: "9a590061-6e67-5d0d-aab9-ad9126b66f91")
    private let cbbChargingCharUUID  = CBUUID(string: "9a590072-6e67-5d0d-aab9-ad9126b66f91")
    private let primarySOCCharUUID   = CBUUID(string: "9a5900e9-6e67-5d0d-aab9-ad9126b66f91")
    private let secondarySOCCharUUID = CBUUID(string: "9a5900f5-6e67-5d0d-aab9-ad9126b66f91")
    
    // States that are considered "awake"
    private let awakeStates: Set<ScooterState> = [
        .standby, .parked, .unlocked, .riding, .charging, .linking
    ]
    
    // MARK: - Connection Phase

    /// High-level phase of the onboarding connection flow, used to drive the UI
    /// unambiguously instead of inferring state from several separate flags.
    enum ConnectionPhase: Equatable {
        case idle
        case scanning
        case connecting
        case pairing
        case connected
        case failed(String)   // user-facing reason
    }

    // MARK: - Scooter State

    enum ScooterState: Equatable, Hashable {
        case standby
        case unlocked
        case riding
        case parked
        case charging
        case linking
        case disconnected
        case shuttingDown
        case unknown(String)
        
        init(fromString string: String) {
            switch string.lowercased() {
            case "standby", "stand-by":
                self = .standby
            case "unlocked":
                self = .unlocked
            case "riding":
                self = .riding
            case "parked":
                self = .parked
            case "charging":
                self = .charging
            case "linking":
                self = .linking
            case "disconnected":
                self = .disconnected
            case "shutting-down":
                self = .shuttingDown
            default:
                self = .unknown(string)
            }
        }
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .standby:      hasher.combine(0)
            case .unlocked:     hasher.combine(1)
            case .riding:       hasher.combine(2)
            case .parked:       hasher.combine(3)
            case .charging:     hasher.combine(4)
            case .linking:      hasher.combine(5)
            case .disconnected: hasher.combine(6)
            case .shuttingDown: hasher.combine(7)
            case .unknown(let s):
                hasher.combine(8)
                hasher.combine(s)
            }
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Default these ON for new installs (an existing user's explicit choice
        // is preserved — register only fills in absent keys).
        UserDefaults.standard.register(defaults: [
            SettingsKeys.autoUnlock: true,
            SettingsKeys.autoOpenSeat: true,
            SettingsKeys.autoUnlockMinRSSI: SettingsKeys.defaultMinRSSI
        ])
        if let t = UserDefaults.standard.object(forKey: SettingsKeys.lastSeen) as? Double {
            lastSeen = Date(timeIntervalSince1970: t)
        }
        centralManager = CBCentralManager(delegate: self, queue: nil)
        setupAppLifecycleObservers()
    }

    /// Record that we currently have a live connection (persisted for "last seen").
    private func markSeen() {
        let now = Date()
        lastSeen = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: SettingsKeys.lastSeen)
    }
    
    deinit {
        stateUpdateTimer?.invalidate()
        stateUpdateTimer = nil
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Private Methods
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Arm auto-unlock for this app-open if enabled (stays armed and
                // keeps polling until the scooter is close enough or cancelled).
                if self.autoUnlockEnabled { self.armAutoUnlock() }

                guard self.hasCompletedOnboarding,
                      self.centralManager.state == .poweredOn else { return }

                if !self.isConnected {
                    if let scooter = self.scooter {
                        self.centralManager.connect(scooter, options: nil)
                    } else {
                        self.startScanning()
                    }
                }
            }
            .store(in: &cancellables)

        // Stop scanning and disarm auto-unlock when entering background.
        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.autoUnlockArmed = false
                self?.stopScanning()
            }
            .store(in: &cancellables)
    }

    // MARK: - Auto-unlock

    /// Cancel a pending auto-unlock (user-facing).
    func cancelAutoUnlock() {
        autoUnlockArmed = false
    }

    private func armAutoUnlock() {
        guard autoUnlockEnabled else { return }
        autoUnlockArmed = true
        startAutoUnlockPolling()
    }

    private func startAutoUnlockPolling() {
        guard !autoUnlockPolling else { return }
        autoUnlockPolling = true
        autoUnlockTick()
    }

    /// While armed: keep trying to connect as the user approaches, and once
    /// connected, poll RSSI until the scooter is within the configured range,
    /// then unlock. Re-evaluates continuously (not just once at connect) so it
    /// works whether the app was opened near or far from the scooter.
    private func autoUnlockTick() {
        guard autoUnlockArmed else { autoUnlockPolling = false; return }

        if isConnected {
            if isLocked {
                scooter?.readRSSI()      // evaluated in didReadRSSI
            } else {
                autoUnlockArmed = false  // already unlocked — nothing to do
                autoUnlockPolling = false
                return
            }
        } else if !isScanning, scooter == nil, centralManager.state == .poweredOn {
            startScanning()              // keep looking for it as we get closer
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.autoUnlockTick()
        }
    }

    // MARK: - Public Methods
    
    func handlePostOnboardingConnection() {
        hasCompletedOnboarding = true
        startStateUpdateTimer()
    }
    
    func startScanning() {
        pendingStartScan = true
        if centralManager.state == .poweredOn {
            initiateScanning()
        }
    }
    
    func initiateScanning() {
        print("🔍 startScanning() - Scanning for Scooter...")
        statusMessage = "Searching..."
        isScanning = true
        connectionPhase = .scanning
        
        // Unfiltered scan
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Timeout after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.centralManager.stopScan()
            self.isScanning = false
            self.statusMessage = "No scooter found."
            self.connectionPhase = .failed("No scooter found.")
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        connectionPhase = .idle
    }
    
    func disconnect() {
        guard let scooter = scooter else { return }
        centralManager.cancelPeripheralConnection(scooter)
    }
    
    // Lock/Unlock commands
    func unlock(wake: Bool = true) {
        Task {
            // Auto-unlock passes wake:false so it never blocks on the wake-and-
            // wait — if we're connected the scooter is responsive enough to take
            // the unlock immediately.
            if wake {
                guard await ensureScooterAwakeIfPossible() else { return }
            }

            guard let characteristic = commandCharacteristic,
                  let scooter = scooter else {
                return
            }
            
            let command = "scooter:state unlock"
            if let data = command.data(using: .ascii) {
                scooter.writeValue(data, for: characteristic, type: .withResponse)
                statusMessage = "Unlocking..."
                print("🔓 Sending unlock command...")
                
                // Check handlebar after 2s
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await verifyHandlebarState()

                // Optionally pop the seat whenever we unlock (auto or manual).
                if autoOpenSeatOnUnlock {
                    openSeat()
                }
            }
        }
    }

    func lock() {
        Task {
            guard await ensureScooterAwakeIfPossible() else { return }
            
            guard let characteristic = commandCharacteristic,
                  let scooter = scooter else {
                return
            }
            
            let command = "scooter:state lock"
            if let data = command.data(using: .ascii) {
                scooter.writeValue(data, for: characteristic, type: .withResponse)
                statusMessage = "Locking..."
                print("🔒 Sending lock command...")
                
                // Check handlebar after 2s
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await verifyHandlebarState()
                
                // If still unlocked, show alert
                if !isLocked {
                    print("⚠️ Lock failed, handlebar is still unlocked.")
                    showLockFailedAlert(message: """
                    The handlebar wasn't in a lockable position.
                    The scooter is off but still unlocked.
                    """)
                }
            }
        }
    }
    
    func openSeat() {
        guard let characteristic = commandCharacteristic,
              let scooter = scooter else {
            return
        }
        
        let command = "scooter:seatbox open"
        if let data = command.data(using: .ascii) {
            scooter.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
    
    func sendBlinkerCommand(state: String) {
        guard let characteristic = commandCharacteristic,
              let scooter = scooter else { return }
        
        let command = "scooter:blinker \(state)"
        if let data = command.data(using: .ascii) {
            scooter.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
    
     func sendCustomCommand(_ command: String) {
         guard let characteristic = commandCharacteristic,
               let scooter = scooter else { return }

         if let data = command.data(using: .ascii) {
             scooter.writeValue(data, for: characteristic, type: .withResponse)
         }
     }
    
    // MARK: - Private Helpers
    
    /// Handles the scooter being connected but not paired (encryption code incorrect/missing)
    private func handleInsufficientEncryption() {
        needsPairing = true
        isPairing = true
        statusMessage = "Please enter pairing code shown on scooter"
        connectionPhase = .pairing
        print("❌ Insufficient encryption")
    }
    
    /// Wakes the scooter from hibernation if the hibernation characteristic is available
    private func wakeUpScooter() async {
        guard let hibernationCharacteristic = hibernationCommandCharacteristic,
              let scooter = scooter else {
            print("No hibernation characteristic found; skipping wake-up attempt.")
            return
        }
        
        if let data = "wakeup".data(using: .ascii) {
            scooter.writeValue(data, for: hibernationCharacteristic, type: .withResponse)
            statusMessage = "Waking scooter..."
            print("🤖 Sent wakeup command")
        }
    }
    
    /// Ensures the scooter is awake if possible, returning false if it fails to wake.
    private func ensureScooterAwakeIfPossible() async -> Bool {
        let canWake = (hibernationCommandCharacteristic != nil)
        // Don't treat a stale state (e.g. .disconnected right after connect,
        // before the state characteristic has been read) as "asleep".
        let asleep = !awakeStates.contains(currentState) && currentState != .disconnected
        if asleep && canWake {
            await wakeUpScooter()
            let awake = await waitForScooterState(.standby, timeout: 12)
            if !awake {
                statusMessage = "Could not wake scooter."
                print("⚠️ Could not wake scooter to standby.")
                showLockFailedAlert(message: "Could not wake scooter to standby.")
                return false
            }
        }
        return true
    }
    
    /// Waits for a certain scooter state or times out.
    private func waitForScooterState(_ targetState: ScooterState,
                                     timeout: TimeInterval = 20) async -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if currentState == targetState {
                return true
            }
            if let stateChar = stateCharacteristic,
               let scooter = scooter {
                scooter.readValue(for: stateChar)
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        return (currentState == targetState)
    }
    
    /// Reads the handlebar characteristic to verify lock state.
    private func verifyHandlebarState() async {
        guard let handlebarChar = handlebarCharacteristic,
              let scooter = scooter else {
            return
        }
        
        scooter.readValue(for: handlebarChar)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    /// Show an alert in SwiftUI by setting published properties
    private func showLockFailedAlert(message: String) {
        lockAlertMessage = message
        showLockAlert = true
    }
    
    /// Re-attempt waking & locking if user chooses "Retry" from the alert
    func restartAndLock() {
        Task {
            // Attempt to unlock (which wakes the scooter if possible)
            unlock()
            let awake = await waitForScooterState(.standby, timeout: 30)
            if !awake {
                showLockFailedAlert(message: """
                The scooter did not acknowledge our wake-up request.
                """)
                return
            }
            // Now try to lock again
            lock()
        }
    }
    
    /// Update the statusMessage based on currentState + lock state
    private func updateStatusMessage() {
        switch currentState {
        case .unlocked, .riding:
            statusMessage = isLocked ? "Warning: mismatch" : "Unlocked"
        case .standby:
            statusMessage = "Standby"
        case .parked:
            statusMessage = "Parked"
        case .charging:
            statusMessage = "Charging"
        case .linking:
            statusMessage = "Linking"
        case .disconnected:
            statusMessage = "Disconnected"
        case .shuttingDown:
            statusMessage = "Shutting Down"
        case .unknown(let unknown):
            statusMessage = unknown
        }
    }
    
    /// Parses a battery SoC value from Data to an Int percent.
    private func parseSoC(data: Data, isCbb: Bool) -> Int? {
        // For CBB, typically 1 byte. For main or aux batteries, 4 bytes (little-endian).
        if isCbb {
            guard data.count >= 1 else { return nil }
            return Int(data[0])
        } else {
            guard data.count == 4 else { return nil }
            let b0 = data[0]
            let b1 = data[1]
            let b2 = data[2]
            let b3 = data[3]
            let value = UInt32(b0)
                    + (UInt32(b1) << 8)
                    + (UInt32(b2) << 16)
                    + (UInt32(b3) << 24)
            return max(0, min(100, Int(value)))
        }
    }
    
    // MARK: - State Update Timer
    
    func startStateUpdateTimer() {
        stopStateUpdateTimer()
        stateUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // The timer fires on the main run loop, so it is safe to assume the
            // main actor and call the @MainActor-isolated manager directly.
            MainActor.assumeIsolated {
                self?.verifyConnectionState()
            }
        }
    }
    
    func stopStateUpdateTimer() {
        stateUpdateTimer?.invalidate()
        stateUpdateTimer = nil
    }
    
    // MARK: - Connection Verification
    
    private func verifyConnectionState() {
        guard bluetoothState == .poweredOn else { return }
        
        if let scooter = scooter {
            switch scooter.state {
            case .connected:
                markSeen()
                if !isConnected && !needsPairing {
                    // Only set connected if we don't need pairing
                    isConnected = true
                    resubscribeToCharacteristics()
                }
            case .disconnected:
                handleDisconnection()
            case .connecting:
                statusMessage = "Connecting..."
            case .disconnecting:
                statusMessage = "Disconnecting..."
            @unknown default:
                break
            }
        }
    }
    
    private func handleDisconnection() {
        isConnected = false
        clearCharacteristics()
        statusMessage = "Disconnected."

        // Always reconnect automatically if Bluetooth is still on
        if centralManager.state == .poweredOn, let scooter = scooter {
            statusMessage = "Reconnecting..."
            connectionPhase = .connecting
            centralManager.connect(scooter, options: nil)
        } else {
            connectionPhase = .failed("Disconnected")
        }
    }
    
    private func resubscribeToCharacteristics() {
        guard let scooter = scooter else { return }
        [
            stateCharacteristic,
            handlebarCharacteristic,
            auxSOCCharacteristic,
            cbbSOCCharacteristic,
            cbbChargingCharacteristic,
            primarySOCCharacteristic,
            secondarySOCCharacteristic
        ]
        .compactMap { $0 }
        .forEach {
            scooter.setNotifyValue(true, for: $0)
        }
    }
    
    private func clearCharacteristics() {
        commandCharacteristic = nil
        stateCharacteristic = nil
        powerStateCharacteristic = nil
        handlebarCharacteristic = nil
        hibernationCommandCharacteristic = nil
        auxSOCCharacteristic = nil
        cbbSOCCharacteristic = nil
        cbbChargingCharacteristic = nil
        primarySOCCharacteristic = nil
        secondarySOCCharacteristic = nil
    }
}

// MARK: - CBCentralManagerDelegate

extension UnuScooterManager: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        print("centralManagerDidUpdateState: \(central.state.rawValue)")
        
        // Only initiate scanning if there's a pending scan request
        if central.state == .poweredOn && pendingStartScan {
            pendingStartScan = false
            initiateScanning()
        }
        
        print(isConnected)
        
        // Just update the status message based on Bluetooth state
        switch central.state {
        case .poweredOff:
            statusMessage = "Please turn on Bluetooth"
            print("ℹ️ Bluetooth is off")
            isConnected = false
            scooter = nil
        case .unauthorized:
            statusMessage = "Bluetooth permission required"
            print("ℹ️ Bluetooth permission required")
            isConnected = false
            scooter = nil
        case .unsupported:
            statusMessage = "Bluetooth not supported"
            print("❌ Bluetooth not supported")
        case .resetting:
            statusMessage = "Bluetooth is resetting"
            print("❌ Bluetooth is resetting")
        case .unknown:
            statusMessage = "Bluetooth state unknown"
            print("❌ Bluetooth state unknown")
        case .poweredOn:
            print("ℹ️ Bluetooth is on")
            // Bluetooth (re)gained — reconnect if we were connected before.
            if hasCompletedOnboarding && !isConnected {
                if let scooter = scooter {
                    statusMessage = "Reconnecting…"
                    connectionPhase = .connecting
                    centralManager.connect(scooter, options: nil)
                } else if !isScanning && !pendingStartScan {
                    startScanning()
                }
            } else if !isConnected && !isScanning && !pendingStartScan {
                statusMessage = "Ready"
            }
        @unknown default:
            statusMessage = "Unknown Bluetooth state"
            print("❌ Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any],
                       rssi RSSI: NSNumber) {
        print("Found peripheral: \(peripheral.name ?? "Unnamed"), RSSI: \(RSSI)")
        
        // Check if this is "unu Scooter" by name
        if peripheral.name == "unu Scooter" {
            scooter = peripheral
            finishPeripheralDiscovery()
        }
    }
    
    private func finishPeripheralDiscovery() {
        centralManager.stopScan()
        isScanning = false
        statusMessage = "Connecting..."
        connectionPhase = .connecting
        if let scooter = scooter {
            centralManager.connect(scooter, options: nil)

            // Timeout if the connection (or subsequent pairing) never completes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self = self, self.connectionPhase == .connecting else { return }
                self.centralManager.cancelPeripheralConnection(scooter)
                self.scooter = nil
                self.statusMessage = "Couldn't connect."
                self.connectionPhase = .failed("Couldn't connect.")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                       didConnect peripheral: CBPeripheral) {
        print("🔌 Initial connection to scooter established")
        peripheral.delegate = self
        statusMessage = "Verifying connection..."
        // Backstop: keep verifying/repairing the connection while we're connected.
        startStateUpdateTimer()

        // Staged discovery: command + main first so lock/unlock and state are
        // ready ASAP; battery services follow (see didDiscoverCharacteristics).
        didStageRestDiscovery = false
        peripheral.discoverServices([commandServiceUUID, mainServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        print("❌ Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        statusMessage = "Connection failed."
        connectionPhase = .failed("Connection failed.")

        if peripheral == self.scooter {
            self.scooter = nil
            isConnected = false
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        print("📵 Disconnected: \(error?.localizedDescription ?? "No error")")
        guard peripheral == self.scooter else { return }

        if isPairing {
            // A disconnect mid-pairing means the user cancelled or mistyped the
            // system pairing dialog. Reset so onboarding can offer a clean retry.
            print("⚠️ Disconnected during pairing — treating as pairing failure")
            isPairing = false
            needsPairing = false
            isConnected = false
            self.scooter = nil
            statusMessage = "Pairing failed. Please try again."
            connectionPhase = .failed("Pairing failed. Please try again.")
            return
        }

        isConnected = false
        clearCharacteristics()

        // Keep the peripheral reference and let CoreBluetooth reconnect
        // automatically as soon as the scooter is back in range — connect()
        // has no timeout, so no app restart is needed.
        if centralManager.state == .poweredOn {
            statusMessage = "Reconnecting…"
            connectionPhase = .connecting
            centralManager.connect(peripheral, options: nil)
        } else {
            statusMessage = "Connection lost"
            connectionPhase = .failed("Connection lost")
        }
    }
}

// MARK: - CBPeripheralDelegate

extension UnuScooterManager: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ Error discovering services: \(error.localizedDescription)")
            statusMessage = "Service discovery error: \(error.localizedDescription)"
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            switch service.uuid {
            case commandServiceUUID:
                peripheral.discoverCharacteristics([commandCharUUID, hibernationCommandCharUUID],
                                                   for: service)
            case mainServiceUUID:
                peripheral.discoverCharacteristics([stateCharUUID, handlebarCharUUID],
                                                   for: service)
            case powerServiceUUID:
                peripheral.discoverCharacteristics([powerStateCharUUID],
                                                   for: service)
            case auxServiceUUID:
                peripheral.discoverCharacteristics([auxSOCCharUUID],
                                                   for: service)
            case cbbServiceUUID:
                peripheral.discoverCharacteristics([cbbSOCCharUUID, cbbChargingCharUUID],
                                                   for: service)
            case primaryServiceUUID:
                peripheral.discoverCharacteristics([primarySOCCharUUID, secondarySOCCharUUID],
                                                   for: service)
            default:
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            print("❌ Error discovering characteristics: \(error.localizedDescription)")
            statusMessage = "Characteristic discovery error: \(error.localizedDescription)"
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case commandCharUUID:
                commandCharacteristic = characteristic
            case hibernationCommandCharUUID:
                hibernationCommandCharacteristic = characteristic
            case stateCharUUID:
                stateCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            case powerStateCharUUID:
                powerStateCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            case handlebarCharUUID:
                handlebarCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            case auxSOCCharUUID:
                auxSOCCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            case cbbSOCCharUUID:
                cbbSOCCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            case cbbChargingCharUUID:
                cbbChargingCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            case primarySOCCharUUID:
                primarySOCCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            case secondarySOCCharUUID:
                secondarySOCCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }

        // Once the main service (state + handlebar) is in, lock/unlock is ready —
        // now discover the battery services in the background so they don't
        // delay the first connect/unlock.
        if service.uuid == mainServiceUUID && !didStageRestDiscovery {
            didStageRestDiscovery = true
            peripheral.discoverServices([powerServiceUUID, auxServiceUUID, cbbServiceUUID, primaryServiceUUID])
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("❌ Error changing notification state for \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        if characteristic.isNotifying {
            print("👂 Listening for updates on \(characteristic.uuid)")
        } else {
            print("🔕 Stopped updates on \(characteristic.uuid)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        // Only acts while auto-unlock is armed. A reading below the threshold is
        // ignored (the poll keeps going as the user gets closer) — we only
        // disarm + unlock once the scooter is actually within range.
        guard autoUnlockArmed, error == nil else { return }
        print("📶 Auto-unlock RSSI \(RSSI) (min \(autoUnlockMinRSSI))")
        if RSSI.intValue >= autoUnlockMinRSSI && isLocked {
            autoUnlockArmed = false
            unlock(wake: false)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("❌ Error reading characteristic value: \(error.localizedDescription)")
            
            if error.localizedDescription.contains("Encryption is insufficient") {
                handleInsufficientEncryption()
            }
            return
        }
        
        // If we get here, we have successful communication with the scooter
        needsPairing = false
        isPairing = false
        isConnected = true
        connectionPhase = .connected
        markSeen()
        print("🔓 Pairing successful, connection established")

        guard let data = characteristic.value else {
            print("⚠️ No data for characteristic \(characteristic.uuid)")
            return
        }
        
        let rawString = String(data: data, encoding: .ascii) ?? ""
        let trimmed = rawString.trimmingCharacters(
            in: .whitespacesAndNewlines.union(.controlCharacters)
        )
        
        print("📱 Received update for \(characteristic.uuid): \(trimmed)")
        
        switch characteristic.uuid {
        case handlebarCharUUID:
            isLocked = (trimmed != "unlocked")
        case stateCharUUID:
            currentState = ScooterState(fromString: trimmed)
            updateStatusMessage()
        case powerStateCharUUID:
            // e.g., "running", "charging", ...
            break
        case auxSOCCharUUID:
            if let soc = parseSoC(data: data, isCbb: false) {
                auxBatteryPercent = soc
            }
        case cbbSOCCharUUID:
            if let soc = parseSoC(data: data, isCbb: true) {
                cbbBatteryPercent = soc
            }
        case cbbChargingCharUUID:
            cbbIsCharging = (trimmed == "charging")
        case primarySOCCharUUID:
            if let soc = parseSoC(data: data, isCbb: false) {
                primaryBatteryPercent = soc
            }
        case secondarySOCCharUUID:
            if let soc = parseSoC(data: data, isCbb: false) {
                secondaryBatteryPercent = soc
            }
        default:
            break
        }
    }
}
