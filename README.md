# MacSweep — Free Open Source Mac Cleaner & Optimizer for macOS

> The best free alternative to CleanMyMac, CCleaner, and DaisyDisk — built in SwiftUI, open source, no subscription, no tracking.

[![Build](https://github.com/MehmedHunjra/MacSweep/actions/workflows/build.yml/badge.svg)](https://github.com/MehmedHunjra/MacSweep/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue.svg)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](#requirements)
[![Version](https://img.shields.io/badge/version-3.3-brightgreen.svg)](#)
[![Made by besttech.pk](https://img.shields.io/badge/Made%20by-besttech.pk-teal.svg)](https://besttech.pk)

---

[![Download MacSweep v3.3](https://img.shields.io/badge/Download%20MacSweep%20v3.3-.DMG%20Installer-169677?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/MehmedHunjra/MacSweep/releases/latest/download/MacSweep-Installer-v3.3.dmg)

> macOS 13 Ventura or later — Apple Silicon & Intel — No subscription required

---

**MacSweep** is a powerful, fully open source Mac cleaning and optimization app for macOS 13 Ventura and later. It covers everything — system junk cleaning, duplicate removal, malware scanning, memory optimization, startup management, disk visualization, browser privacy, and real-time security protection — all in one native SwiftUI app with no paywalls.

---

## Screenshots

| Dashboard | Smart Scan | Security |
| --------- | ---------- | -------- |
| ![Dashboard](screenshots/dashboard.png) | ![Smart Scan](screenshots/smart-scan.png) | ![Security](screenshots/security.png) |

| Menu Bar | Space Lens | Dev Cleaner |
| -------- | ---------- | ----------- |
| ![Menu Bar](screenshots/menubar.png) | ![Space Lens](screenshots/space-lens.png) | ![Dev Cleaner](screenshots/dev-cleaner.png) |

---

## Why MacSweep vs Other Mac Cleaners?

| Feature | MacSweep | CleanMyMac X | CCleaner | DaisyDisk |
| ------- | -------- | ------------ | -------- | --------- |
| Free | **Yes** | No ($39.95/yr) | Partial | No ($9.99) |
| Open Source | **Yes** | No | No | No |
| No Subscription | **Yes** | No | No | Yes |
| Malware Scanner | **Yes** | Yes | No | No |
| Real-Time Protection | **Yes** | Yes | No | No |
| System Integrity Monitor | **Yes** | No | No | No |
| Network Monitor | **Yes** | No | No | No |
| Ransomware Guard | **Yes** | No | No | No |
| Menu Bar Quick Actions | **Yes** | Yes | No | No |
| Space Lens / Disk Map | **Yes** | Yes | No | **Yes** |
| Dev Cleaner (Xcode/npm/pip) | **Yes** | Yes | No | No |
| App Manager | **Yes** | Yes | No | No |
| No Tracking / No Analytics | **Yes** | Unknown | No | Yes |
| Native SwiftUI | **Yes** | No | No | No |

---

## Features

### Cleaning & Storage

- **Smart Scan** — one-click intelligent scan across all junk categories
- **System Junk** — caches, logs, temp files, mail attachments, photo junk
- **Large Files** — find files taking up the most disk space
- **Duplicate Finder** — detect and remove duplicate files
- **App Leftovers** — clean leftover data from uninstalled apps
- **Browser Privacy** — clear cookies, caches, history from Chrome, Safari, Firefox, Brave, Edge
- **Dev Cleaner** — Xcode DerivedData, simulator caches, npm/pip/gem packages, IDE caches
- **Space Lens** — interactive disk usage treemap to see exactly what is using space

### Performance

- **Memory Optimizer** — view top memory consumers and purge inactive RAM
- **Startup Optimizer** — manage login items, launch agents, launch daemons
- **Maintenance** — run macOS daily/weekly/monthly scripts, repair permissions, flush caches
- **App Manager** — view all installed apps by size and last-used date, remove with leftovers

### Security

- **Malware Scanner** — heuristic deep scan for suspicious files, scripts, and auto-run threats
- **Real-Time Protection** — FSEvents-based live monitoring of Downloads, Desktop, Documents
- **Adware Cleaner** — remove browser extensions, login items, and launch agents linked to adware
- **Ransomware Guard** — file-change rate monitoring with encryption pattern detection
- **Network Monitor** — live view of all active TCP connections with suspicious port flagging
- **Quarantine Manager** — safely quarantine threats and restore false positives
- **System Integrity Monitor** — scan launch agents, daemons, hosts file, SSH config, kernel extensions

### Privacy

- **Privacy Cleaner** — erase recent document lists, clipboard history, browser traces
- **Privacy & Protection** — scan and clear browser saved passwords, autofill, download history

### Menu Bar

- Always-on menu bar icon with live CPU, RAM, disk, and network stats
- **Quick Actions panel** — 24 instant actions (Empty Trash, Free RAM, Flush DNS, and more)
- **All Tools grid** — launch any of the 21 tools directly from the menu bar

---

## Download & Install (.DMG)

### Option 1 — Build DMG from Source

```bash
git clone https://github.com/MehmedHunjra/MacSweep.git
cd MacSweep
bash build-dmg.sh
```

This builds the app and produces `dist/MacSweep-Installer-v3.3.dmg`.
Open the DMG, drag MacSweep to Applications, and launch.

### Option 2 — Manual Xcode Build

```bash
git clone https://github.com/MehmedHunjra/MacSweep.git
open MacSweep.xcodeproj
```

Select **MacSweep** scheme → **My Mac** destination → press **Run** (⌘R).

---

## Requirements

| | |
| -- | -- |
| **macOS** | 13 Ventura or later |
| **Xcode** | 15 or later (for building) |
| **Swift** | 5.9+ |
| **Architecture** | Apple Silicon & Intel |

No third-party dependencies. No Swift Package Manager packages required.

---

## Project Structure

```text
MacSweep/
├── MacSweepApp.swift              # App entry, MenuBarExtra, live stats label
├── ContentView.swift              # Main window, section routing
├── Models.swift                   # AppSettings, AppSection, design system (DS)
├── NavigationManager.swift        # Navigation history & routing
├── ScanEngine.swift               # Disk, CPU, RAM, network stats
├── CleanEngine.swift              # File deletion engine
├── SecurityEngine.swift           # Malware, Adware, Network, Ransomware,
│                                  # Realtime, Integrity, Notifications
│
├── SmartScanView.swift
├── SystemJunkView.swift
├── LargeFilesView.swift
├── DuplicateFinderView.swift
├── BrowserCleanerView.swift
├── AppLeftoversView.swift
├── DevCleanerView.swift
├── SpaceLensView.swift
│
├── MemoryOptimizerView.swift
├── PerformanceManagerView.swift
├── MaintenanceView.swift
├── ApplicationsManagerView.swift
│
├── MalwareScannerView.swift
├── RealtimeProtectionView.swift
├── AdwareCleanerView.swift
├── RansomwareGuardView.swift
├── NetworkMonitorView.swift
├── QuarantineManagerView.swift
├── IntegrityMonitorView.swift
│
├── PrivacyView.swift
├── ProtectionManagerView.swift
├── DashboardView.swift
├── SidebarView.swift
├── MenuBarView.swift
├── SettingsView.swift
└── Assets.xcassets/
```

---

## Built with Vibe Coding — AI-Powered Development (2026)

MacSweep was built in **2026** using **vibe coding** — writing software by describing ideas in plain English and iterating with AI tools. No prior macOS or Swift expertise was required.

**AI Tools Used:**

| Tool | Role |
| ---- | ---- |
| **Claude Code** (Anthropic) | Primary architecture, SwiftUI views, all engines, bug fixes, CI/CD |
| **OpenAI Codex** | Code suggestions, logic patterns, algorithm optimization |
| **Google Gemini** | Research, API references, problem solving |

> This project proves that anyone — with the right AI tools and determination — can build a professional, fully functional native Mac application from scratch in 2026.

---

## Contributors

| Contributor | Role |
| ----------- | ---- |
| **Mehmed Hunjra** ([@MehmedHunjra](https://github.com/MehmedHunjra)) | Founder, Product Vision, Project Lead |
| **Claude Code** — Anthropic | AI Pair Programmer — architecture, SwiftUI, engines, CI |
| **OpenAI Codex** | AI Code Assistant — logic, algorithms |
| **Google Gemini** | AI Research Assistant |
| **besttech.pk** | Software House — Made with love in 2026 |

---

## Made by besttech.pk

**MacSweep** is a product of **[besttech.pk](https://besttech.pk)** — a software house and digital agency building apps, websites, and digital products.

besttech.pk is a place where developers, designers, and entrepreneurs come together to build software, websites, and digital marketing solutions. If you have an idea — we can help you build it.

---

## Contributing

We welcome contributions from developers worldwide. Read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a PR.

**Quick start:**

1. Fork the repo
2. Create a branch: `git checkout -b feature/your-idea`
3. Make your changes
4. Open a Pull Request

---

## Keywords

mac cleaner, mac optimizer, macos cleaner, free mac cleaner, open source mac cleaner, cleanmymac alternative, ccleaner mac, macos junk cleaner, mac malware scanner, mac privacy cleaner, mac duplicate finder, mac memory optimizer, mac startup manager, mac disk cleaner, mac app cleaner, system junk cleaner, macos performance, swiftui mac app, mac security app, mac cleaner 2026

---

## License

MIT License — free to use, modify, and distribute. See [LICENSE](LICENSE).

---

## Disclaimer

MacSweep performs real system operations (file deletion, DNS flush, memory purge, system scans). Always review items before confirming any cleaning operation. The authors are not responsible for data loss caused by misuse.

---

Made with love by [besttech.pk](https://besttech.pk) — Built in 2026 using AI vibe coding
