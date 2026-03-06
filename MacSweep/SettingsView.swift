import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications
import ApplicationServices
#if canImport(CoreLocation)
import CoreLocation
#endif

struct SettingsView: View {
    @ObservedObject var scanEngine: ScanEngine
    @ObservedObject var settings: AppSettings
    @State private var selectedSection: SettingsSection = .general
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
#if canImport(CoreLocation)
    @State private var locationAuthStatus: CLAuthorizationStatus = .notDetermined
#endif
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    enum SettingsSection: String, CaseIterable {
        case general   = "General"
        case menuBar   = "Menu Bar"
        case scanning  = "Scanning"
        case history   = "History"
        case about     = "About"

        var icon: String {
            switch self {
            case .general:  return "gearshape.fill"
            case .menuBar:  return "menubar.rectangle"
            case .scanning: return "sparkles.rectangle.stack"
            case .history:  return "clock.arrow.circlepath"
            case .about:    return "info.circle.fill"
            }
        }
        var color: Color {
            switch self {
            case .general:  return Color(hex: "636e72")
            case .menuBar:  return Color(hex: "667EEA")
            case .scanning: return Color(hex: "11998E")
            case .history:  return Color(hex: "F5A623")
            case .about:    return Color(hex: "764BA2")
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Settings sidebar
            VStack(alignment: .leading, spacing: 2) {
                Text("SETTINGS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(1.2)
                    .padding(.leading, 12)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                ForEach(SettingsSection.allCases, id: \.self) { sec in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedSection = sec }
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedSection == sec ? sec.color : sec.color.opacity(0.15))
                                    .frame(width: 24, height: 24)
                                Image(systemName: sec.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(selectedSection == sec ? .white : sec.color)
                            }
                            Text(sec.rawValue)
                                .font(.system(size: 13, weight: selectedSection == sec ? .semibold : .regular))
                                .foregroundColor(selectedSection == sec ? .primary : .secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(selectedSection == sec ? AppTheme.accent.opacity(0.08) : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .frame(width: 180)
            .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))

            Rectangle().fill(Color.gray.opacity(0.15)).frame(width: 1)

            // Settings content
            ScrollView(showsIndicators: false) {
                Group {
                    switch selectedSection {
                    case .general:  generalSettings
                    case .menuBar:  menuBarSettings
                    case .scanning: scanningSettings
                    case .history:  historySettings
                    case .about:    aboutView
                    }
                }
                .padding(28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if let restored = SettingsSection(rawValue: settings.settingsSectionRaw) {
                selectedSection = restored
            }
            refreshPermissionStatuses()
            registerLoginItem(enabled: settings.launchAtLogin)
        }
        .onChange(of: selectedSection) { _, newValue in
            if settings.settingsSectionRaw != newValue.rawValue {
                settings.settingsSectionRaw = newValue.rawValue
            }
        }
        .onChange(of: settings.settingsSectionRaw) { _, newRaw in
            if let section = SettingsSection(rawValue: newRaw), selectedSection != section {
                selectedSection = section
            }
        }
    }

    // MARK: - General Settings
    var generalSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsHeader(icon: "gearshape.fill", title: "General", color: Color(hex: "636e72"))

            SettingsCard {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "power",
                        iconColor: Color(hex: "11998E"),
                        title: "Launch at Login",
                        subtitle: "MacSweep starts automatically when you log in"
                    ) {
                        Toggle("", isOn: $settings.launchAtLogin)
                            .labelsHidden()
                            .onChange(of: settings.launchAtLogin) { _, newVal in
                                registerLoginItem(enabled: newVal)
                            }
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "menubar.rectangle",
                        iconColor: Color(hex: "667EEA"),
                        title: "Launch as Menu Bar Only",
                        subtitle: "At login, start hidden in menu bar (default)"
                    ) {
                        Toggle("", isOn: $settings.launchAtLoginMenuBarOnly)
                            .labelsHidden()
                            .disabled(!settings.launchAtLogin)
                    }
                    .opacity(settings.launchAtLogin ? 1.0 : 0.45)

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "dock.rectangle",
                        iconColor: Color(hex: "4776E6"),
                        title: "Show in Dock",
                        subtitle: "Display MacSweep icon in the Dock"
                    ) {
                        Toggle("", isOn: $settings.showDockIcon)
                            .labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "bell.fill",
                        iconColor: Color(hex: "F5A623"),
                        title: "Notifications",
                        subtitle: "Show alerts when scans complete"
                    ) {
                        Toggle("", isOn: $settings.notificationsEnabled)
                            .labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "arrow.clockwise",
                        iconColor: AppTheme.accent,
                        title: "Refresh Interval",
                        subtitle: "How often to update system stats"
                    ) {
                        Picker("", selection: $settings.refreshInterval) {
                            Text("2s").tag(2.0)
                            Text("5s").tag(5.0)
                            Text("10s").tag(10.0)
                            Text("30s").tag(30.0)
                        }
                        .labelsHidden()
                        .frame(width: 70)
                        .onChange(of: settings.refreshInterval) { _, interval in
                            scanEngine.startRefreshTimer(interval: interval)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("PERMISSIONS & SHORTCUTS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(1.2)

                SettingsCard {
                    VStack(spacing: 0) {
                        PermissionShortcutRow(
                            icon: "figure.wave",
                            iconColor: Color(hex: "667EEA"),
                            title: "Accessibility",
                            subtitle: "Needed for app control actions",
                            statusText: accessibilityStatusText
                        ) {
                            openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                        }

                        Divider().padding(.leading, 44)

                        PermissionShortcutRow(
                            icon: "externaldrive.fill.badge.checkmark",
                            iconColor: Color(hex: "11998E"),
                            title: "Full Disk Access",
                            subtitle: "Needed for deep scanning and cleanup",
                            statusText: "Open macOS setting"
                        ) {
                            openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
                        }

                        Divider().padding(.leading, 44)

                        PermissionShortcutRow(
                            icon: "rectangle.on.rectangle",
                            iconColor: Color(hex: "8E54E9"),
                            title: "Screen Recording",
                            subtitle: "Needed for advanced overlay/screen tools",
                            statusText: "Open macOS setting"
                        ) {
                            openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
                        }

                        Divider().padding(.leading, 44)

                        PermissionShortcutRow(
                            icon: "gearshape.2.fill",
                            iconColor: Color(hex: "F857A6"),
                            title: "Automation",
                            subtitle: "Allow controlled actions between apps",
                            statusText: "Open macOS setting"
                        ) {
                            openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
                        }

                        Divider().padding(.leading, 44)

                        PermissionShortcutRow(
                            icon: "location.fill",
                            iconColor: Color(hex: "38EF7D"),
                            title: "Location Services",
                            subtitle: "Used for accurate Wi-Fi network details",
                            statusText: locationStatusText
                        ) {
                            openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
                        }

                        Divider().padding(.leading, 44)

                        PermissionShortcutRow(
                            icon: "bell.badge.fill",
                            iconColor: Color(hex: "F5A623"),
                            title: "Notifications Permission",
                            subtitle: "Allow scan alerts and task updates",
                            statusText: notificationStatusText
                        ) {
                            openSystemSettings("x-apple.systempreferences:com.apple.preference.notifications")
                        }

                        Divider().padding(.leading, 44)

                        PermissionShortcutRow(
                            icon: "keyboard",
                            iconColor: AppTheme.accent,
                            title: "Keyboard Shortcuts",
                            subtitle: "Open macOS shortcuts settings",
                            statusText: "Open macOS setting"
                        ) {
                            openSystemSettings("x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts")
                        }
                    }
                }

                Text("Tip: once permission is granted in macOS, MacSweep won't ask again unless you revoke it.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Menu Bar Settings
    var menuBarSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsHeader(icon: "menubar.rectangle", title: "Menu Bar", color: Color(hex: "667EEA"))

            SettingsCard {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "cpu",
                        iconColor: Color(hex: "4776E6"),
                        title: "Show CPU Usage",
                        subtitle: "Display CPU load percentage in menu bar"
                    ) {
                        Toggle("", isOn: $settings.menuBarShowCPU).labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "memorychip",
                        iconColor: Color(hex: "38EF7D"),
                        title: "Show RAM Usage",
                        subtitle: "Display memory usage in menu bar"
                    ) {
                        Toggle("", isOn: $settings.menuBarShowRAM).labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "internaldrive.fill",
                        iconColor: AppTheme.accent,
                        title: "Show Disk Available",
                        subtitle: "Display available disk space in menu bar"
                    ) {
                        Toggle("", isOn: $settings.menuBarShowDisk).labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "wifi",
                        iconColor: Color(hex: "53C7FF"),
                        title: "Show Network Speed",
                        subtitle: "Display download/upload speed in menu bar"
                    ) {
                        Toggle("", isOn: $settings.menuBarShowNetwork).labelsHidden()
                    }
                }
            }

            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image("MenuBarIcon")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 14)
                    if settings.menuBarShowCPU {
                        Text("12%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    if settings.menuBarShowRAM {
                        Text("8.4G")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    if settings.menuBarShowDisk {
                        Text("142G")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    if settings.menuBarShowNetwork {
                        Text("↓1.2M ↑280K")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(radius: 2)
                )
            }
        }
    }

    // MARK: - Scanning Settings
    var scanningSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsHeader(icon: "sparkles.rectangle.stack", title: "Scanning", color: Color(hex: "11998E"))

            SettingsCard {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "checklist",
                        iconColor: Color(hex: "11998E"),
                        title: "User Caches",
                        subtitle: "Scan application caches"
                    ) {
                        Toggle("", isOn: $settings.scanIncludeUserCaches)
                            .labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "doc.text.fill",
                        iconColor: Color(hex: "F5A623"),
                        title: "Log Files",
                        subtitle: "Scan application and system logs"
                    ) {
                        Toggle("", isOn: $settings.scanIncludeLogs)
                            .labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "globe",
                        iconColor: Color(hex: "56AB2F"),
                        title: "Browser Caches",
                        subtitle: "Scan browser caches and web data"
                    ) {
                        Toggle("", isOn: $settings.scanIncludeBrowserCaches)
                            .labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "hammer.fill",
                        iconColor: Color(hex: "E94560"),
                        title: "Development Junk",
                        subtitle: "Scan Xcode/npm/gradle/cocoapods artifacts"
                    ) {
                        Toggle("", isOn: $settings.scanIncludeDevelopment)
                            .labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "clock.arrow.circlepath",
                        iconColor: Color(hex: "9B9B9B"),
                        title: "Temporary Files",
                        subtitle: "Scan temporary files and trash data"
                    ) {
                        Toggle("", isOn: $settings.scanIncludeTempFiles)
                            .labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "envelope.badge.fill",
                        iconColor: Color(hex: "4A90D9"),
                        title: "Mail Attachments",
                        subtitle: "Scan cached Mail downloads"
                    ) {
                        Toggle("", isOn: $settings.scanIncludeMailAttachments)
                            .labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "trash.fill",
                        iconColor: Color(hex: "ED4264"),
                        title: "App Leftovers",
                        subtitle: "Scan leftover data from removed apps"
                    ) {
                        Toggle("", isOn: $settings.scanIncludeAppLeftovers)
                            .labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "arrow.up.doc.fill",
                        iconColor: Color(hex: "F857A6"),
                        title: "Large Files",
                        subtitle: "Scan large files in user folders"
                    ) {
                        Toggle("", isOn: $settings.scanIncludeLargeFiles)
                            .labelsHidden()
                    }

                    Divider().padding(.leading, 44)

                    SettingsRow(
                        icon: "arrow.up.doc.fill",
                        iconColor: Color(hex: "F857A6"),
                        title: "Large File Threshold",
                        subtitle: "Files larger than this are flagged"
                    ) {
                        HStack(spacing: 6) {
                            Slider(value: $settings.largeFileThresholdMB, in: 50...1000, step: 50)
                                .frame(width: 120)
                            Text("\(Int(settings.largeFileThresholdMB)) MB")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                }
            }

            // Scan scope info
            VStack(alignment: .leading, spacing: 10) {
                Text("SCAN LOCATIONS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(1.2)

                let locations = [
                    ("~/Library/Caches", "User application caches"),
                    ("~/Library/Logs", "Application log files"),
                    ("~/Library/Developer/Xcode", "Xcode derived data"),
                    ("~/.npm, ~/.gradle", "Development tool caches"),
                    ("/private/tmp", "System temporary files"),
                    ("~/Library/Application Support", "App leftover data"),
                    ("~/Documents, ~/Downloads, etc.", "Large file search")
                ]

                SettingsCard {
                    VStack(spacing: 0) {
                        ForEach(Array(locations.enumerated()), id: \.0) { i, loc in
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.accent)
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(loc.0)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    Text(loc.1)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            if i < locations.count - 1 {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                }
            }

            Text("These switches control Smart Scan defaults. Dedicated tools still scan their own category when opened directly.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - History Settings
    var historySettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsHeader(icon: "clock.arrow.circlepath", title: "Cleanup History", color: Color(hex: "F5A623"))

            // Total freed banner
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.success.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.success)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(ByteCountFormatter.string(fromByteCount: scanEngine.totalFreedBytes, countStyle: .file))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [AppTheme.success, AppTheme.accent], startPoint: .leading, endPoint: .trailing))
                    Text("Total freed across all sessions")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.success.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.success.opacity(0.15), lineWidth: 1)
                    )
            )

            // History list
            if scanEngine.freedHistory.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("No cleanup history yet")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 30)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("SESSIONS (\(scanEngine.freedHistory.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                            .tracking(1.2)
                        Spacer()
                        Button("Clear History") {
                            scanEngine.clearFreedHistory()
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.danger)
                        .buttonStyle(.plain)
                    }

                    SettingsCard {
                        VStack(spacing: 0) {
                            ForEach(Array(scanEngine.freedHistory.enumerated()), id: \.element.id) { i, rec in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(AppTheme.success.opacity(0.12))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppTheme.success)
                                            .font(.system(size: 14))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rec.description)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1)
                                        Text(rec.dateFormatted)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(rec.sizeFormatted)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.success)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                if i < scanEngine.freedHistory.count - 1 {
                                    Divider().padding(.leading, 58)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - About
    var aboutView: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsHeader(icon: "info.circle.fill", title: "About MacSweep", color: Color(hex: "764BA2"))

            // Logo + name + BestTech.pk
            HStack(spacing: 20) {
                LogoView(size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("MacSweep")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Version \(appVersion)  •  By Mehmed Hunjra")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    // BestTech.pk badge
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://besttech.pk")!)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .black))
                            Text("Powered by BestTech.pk")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(colors: [Color(hex: "FF416C"), Color(hex: "FF4B2B")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                // Share button
                Button {
                    let items: [Any] = [
                        "I use MacSweep — the free open-source Mac cleaner by @MehmedHunjra! 🍃✨",
                        URL(string: "https://github.com/MehmedHunjra/MacSweep")!
                    ]
                    let picker = NSSharingServicePicker(items: items)
                    if let button = NSApp.keyWindow?.contentView {
                        picker.show(relativeTo: .zero, of: button, preferredEdge: .minY)
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(NSColor.controlBackgroundColor))
            )

            // ── Follow Me / Social Links ─────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Text("FOLLOW ME")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(1.2)

                HStack(spacing: 10) {
                    SocialButton(icon: "x-logo", label: "X / Twitter", username: "@MehmedHunjra",
                                 gradient: [Color(hex: "000000"), Color(hex: "333333")],
                                 url: "https://x.com/MehmedHunjra")
                    SocialButton(icon: "github-logo", label: "GitHub", username: "MehmedHunjra",
                                 gradient: [Color(hex: "24292E"), Color(hex: "586069")],
                                 url: "https://github.com/MehmedHunjra")
                    SocialButton(icon: "linkedin-logo", label: "LinkedIn", username: "MehmedHunjra",
                                 gradient: [Color(hex: "0077B5"), Color(hex: "00A0DC")],
                                 url: "https://linkedin.com/in/MehmedHunjra")
                }
            }

            // ── Donate ──────────────────────────────────────────
            Button {
                NSWorkspace.shared.open(URL(string: "https://ko-fi.com/mehmedhunjra")!)
            } label: {
                HStack(spacing: 12) {
                    Text("☕")
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Buy Me a Coffee")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("Support MacSweep development — totally optional!")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 18))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [Color(hex: "FFDD00"), Color(hex: "FF9900")],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Info cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                AboutCard(icon: "lock.open.fill", title: "Open Source", subtitle: "Free for everyone, forever", color: Color(hex: "11998E"))
                AboutCard(icon: "hand.raised.fill", title: "Privacy First", subtitle: "No telemetry, no tracking", color: Color(hex: "667EEA"))
                AboutCard(icon: "bolt.fill", title: "Native Swift", subtitle: "Built with SwiftUI for macOS 13+", color: Color(hex: "F5A623"))
                AboutCard(icon: "star.fill", title: "CleanMyMac Level", subtitle: "Professional cleaning tools", color: Color(hex: "BD10E0"))
            }

            // Features list
            VStack(alignment: .leading, spacing: 10) {
                Text("ALL FEATURES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(1.2)

                let features: [(String, String, Color)] = [
                    ("sparkles.rectangle.stack", "Smart Scan — deep system junk scanner", Color(hex: "11998E")),
                    ("xmark.bin.fill", "System Junk — caches, logs, temp files", Color(hex: "FC5C7D")),
                    ("arrow.up.doc.fill", "Large Files — find space hogs instantly", Color(hex: "F857A6")),
                    ("trash.fill", "App Leftovers — clean uninstalled app data", Color(hex: "ED4264")),
                    ("globe", "Browser Privacy — clear history and cookies", Color(hex: "56AB2F")),
                    ("wrench.and.screwdriver.fill", "Maintenance — flush DNS, free RAM, more", Color(hex: "3A1C71")),
                    ("hand.raised.fill", "Privacy — clear sensitive data trails", Color(hex: "FF416C")),
                    ("chart.pie.fill", "Space Lens — visual disk usage map", Color(hex: "4776E6")),
                    ("chevron.left.forwardslash.chevron.right", "Dev Cleaner — Xcode, VS Code, npm, CocoaPods", Color(hex: "E94560")),
                    ("menubar.rectangle", "Menu Bar — always-on system monitor", AppTheme.accent),
                    ("square.stack.3d.up.fill", "Process Manager — quit apps from menu bar", Color(hex: "764BA2")),
                    ("gearshape.fill", "Settings — full control of every feature", Color(hex: "636e72")),
                ]

                SettingsCard {
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.0) { i, feat in
                            HStack(spacing: 10) {
                                Image(systemName: feat.0)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(feat.2)
                                    .frame(width: 16)
                                Text(feat.1)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.success)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            if i < features.count - 1 {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                }
            }

            // ── Legal ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Text("LEGAL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(1.2)

                SettingsCard {
                    VStack(spacing: 0) {
                        Button {
                            showPrivacyPolicy = true
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(hex: "667EEA").opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "667EEA"))
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Privacy Policy")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("How we handle your data")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 52)

                        Button {
                            showTermsOfService = true
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(hex: "11998E").opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "11998E"))
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Terms of Service")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Your responsibilities when using MacSweep")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                LegalSheet(type: .privacy)
            }
            .sheet(isPresented: $showTermsOfService) {
                LegalSheet(type: .terms)
            }
        }
    }

    // MARK: - Helpers

    private var accessibilityStatusText: String {
        AXIsProcessTrusted() ? "Granted" : "Not Granted"
    }

    private var notificationStatusText: String {
        switch notificationAuthStatus {
        case .authorized, .provisional, .ephemeral: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not Granted"
        @unknown default: return "Unknown"
        }
    }

    private var locationStatusText: String {
        #if canImport(CoreLocation)
        switch locationAuthStatus {
        case .authorizedAlways, .authorizedWhenInUse: return "Granted"
        case .denied, .restricted: return "Denied"
        case .notDetermined: return "Not Granted"
        @unknown default: return "Unknown"
        }
        #else
        return "Unknown"
        #endif
    }

    private func refreshPermissionStatuses() {
        UNUserNotificationCenter.current().getNotificationSettings { notif in
            DispatchQueue.main.async {
                notificationAuthStatus = notif.authorizationStatus
            }
        }
        #if canImport(CoreLocation)
        locationAuthStatus = CLLocationManager().authorizationStatus
        #endif
    }

    private func openSystemSettings(_ deepLink: String) {
        guard let url = URL(string: deepLink) else { return }
        NSWorkspace.shared.open(url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            refreshPermissionStatuses()
        }
    }

    @ViewBuilder
    func settingsHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
    }

    func registerLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Login item registration failed: \(error)")
            }
        }
    }
}

// MARK: - Settings Card
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.12), lineWidth: 1)
            )
    }
}

// MARK: - Settings Row
struct SettingsRow<Control: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct PermissionShortcutRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let statusText: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Button("Open") { action() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.accent.opacity(0.12))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Social Button
struct SocialButton: View {
    let icon: String
    let label: String
    let username: String
    let gradient: [Color]
    let url: String
    @State private var hovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(URL(string: url)!)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    // Use SF Symbols as stand-ins for brand icons
                    Image(systemName: iconName(for: icon))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(hovered ? 1.08 : 1.0)

                VStack(spacing: 1) {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                    Text(username)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(hovered ? Color(gradient[0]) : Color.gray.opacity(0.12), lineWidth: hovered ? 1.5 : 1)
                    )
            )
            .animation(.spring(duration: 0.2), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    func iconName(for brand: String) -> String {
        switch brand {
        case "x-logo":        return "x.circle.fill"
        case "github-logo":   return "chevron.left.slash.chevron.right"
        case "linkedin-logo": return "person.crop.square.filled.and.at.rectangle"
        default:              return "link"
        }
    }
}

// MARK: - About Card
struct AboutCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(size: 12, weight: .bold))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
