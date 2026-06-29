# DNS Tool

A lightweight macOS **menu bar** app for managing DNS in one click — flush the DNS cache, switch to Cloudflare's resolver, or reset to automatic, without ever opening Terminal.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Language](https://img.shields.io/badge/swift-5-orange)

## Features

- 🔄 **Flush DNS Cache** — clears the system resolver cache instantly
- ☁️ **Set DNS → Cloudflare** — points Wi-Fi at `1.1.1.1` / `1.0.0.1`
- ↩️ **Reset DNS → Automatic** — restores your router's default (DHCP)
- 📡 **Live status line** — shows your current DNS servers right in the menu
- ⌨️ **Configurable shortcuts** — rebind any action to your own key combo
- 🚀 **Launch at Login** — optional auto-start (toggle in the menu)
- 🪶 **Menu bar only** — no Dock icon, no window clutter

## Install

1. Download `DNS Tool.dmg` from the [Releases](../../releases) page.
2. Open it and drag **DNS Tool** into **Applications**.
3. Launch it — the network icon appears in your menu bar.

> First launch: right-click the app → **Open** (the app is self-signed, so Gatekeeper asks once). After that it opens normally.

## Usage

Click the menu bar icon:

| Item | Default shortcut | What it does |
|------|------------------|--------------|
| Flush DNS Cache | ⌘F | Clears the DNS cache |
| Set DNS → Cloudflare | ⌘C | Uses `1.1.1.1` / `1.0.0.1` |
| Reset DNS → Automatic | ⌘R | Back to DHCP / router DNS |
| Launch at Login | — | Toggle auto-start |
| Settings… | ⌘, | Rebind shortcuts |

Actions that change network settings prompt for your Mac password (required by macOS).

## Build from source

Requires the Xcode command-line tools.

```bash
swiftc -O src/main.swift -o "DNS Tool.app/Contents/MacOS/DNSTool"
```

The repo includes:
- `src/main.swift` — the app
- `src/makeicon.swift` — helper that crops/rounds the source artwork into a macOS icon set

## Notes

- DNS changes apply to the **Wi-Fi** service.
- Tested on macOS 13+ (uses `SMAppService` for the login item).
<img width="349" height="257" alt="Screenshot 2026-06-30 at 1 48 31 AM" src="https://github.com/user-attachments/assets/7971490a-ba44-4441-ade1-e1aa78cfd105" />

## License
GPL v3.0.
