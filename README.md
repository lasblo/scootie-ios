# Scootie

A fast, fully native iOS app for controlling **unu pro** scooters over Bluetooth.

Its whole point is speed: it connects to the scooter in about a second — versus 10+ for the stock app — and stays responsive throughout. Built with Swift, SwiftUI and CoreBluetooth.

> Unofficial. Not affiliated with or endorsed by emco electroroller GmbH. Use at your own risk.

<p align="middle">
   <img src="home.jpeg" width="32%" />
   <img src="battery.jpeg" width="32%" />
   <img src="lockfail.jpeg" width="32%" />
</p>

## Features

- **Slide to lock / unlock** — with handlebar-state feedback and retry if locking fails
- **Auto-unlock** when you open the app in range (configurable signal threshold)
- **Open the seatbox** and toggle **hazard lights**
- **Live battery** for every pack (primary, secondary, CBB, aux)
- **Persistent auto-reconnect** — no app restart needed after a dropout
- Wakes the scooter from hibernation before sending commands
- Debug menu (long-press the title) for sending raw commands

## Requirements

- iOS 18.2+ / Xcode 16.2+
- A unu pro scooter (CoreBluetooth doesn't work in the Simulator — run on a device)

## Build

Open `Scootie.xcodeproj`, then build and run on a real device. Grant Bluetooth access on first launch and connect to your scooter.

## Credits

- [reunu/tech-reference](https://github.com/reunu/tech-reference) — BLE service/characteristic docs
- [reunu/unustasis](https://github.com/reunu/unustasis) — original scooter communication insights

## License

[GNU GPL v3.0](LICENSE)
