import SwiftUI
import AppKit

@main
struct MacSweepApp: App {
    @StateObject private var scanEngine  = ScanEngine()
    @StateObject private var cleanEngine = CleanEngine()
    @StateObject private var settings    = AppSettings()
    @StateObject private var updateEngine = AppUpdateEngine()
    @StateObject private var autoPolicyEngine = AutoPolicyEngine()
    @StateObject private var wifiLocationPermission = WiFiLocationPermissionManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView(
                    scanEngine: scanEngine,
                    cleanEngine: cleanEngine,
                    settings: settings,
                    updateEngine: updateEngine
                )
                    .frame(minWidth: 1240, minHeight: 900)
                    .onAppear {
                        // Apply saved dock icon setting
                        if !settings.showDockIcon {
                            NSApp.setActivationPolicy(.accessory)
                        }
                        autoPolicyEngine.configure(
                            scanEngine: scanEngine,
                            cleanEngine: cleanEngine,
                            settings: settings
                        )
                        updateEngine.configure(settings: settings)
                        wifiLocationPermission.requestIfNeeded()

                        // If launched at login in menu-bar-only mode, hide main window immediately.
                        if AppDelegate.launchedAsMenuBarOnly {
                            NSApp.setActivationPolicy(.accessory)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                for window in NSApp.windows where window.canBecomeMain {
                                    window.orderOut(nil)
                                }
                                NSApp.deactivate()
                            }
                        }
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .frame(minWidth: 700, minHeight: 520)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1380, height: 920)
        .commands {
            CommandGroup(replacing: .newItem) {}
            // Replace "Quit" with "Hide" so ⌘Q hides window instead of quitting
            CommandGroup(replacing: .appTermination) {
                Button("Hide MacSweep") {
                    hideApp()
                }
                .keyboardShortcut("q", modifiers: [.command])

                Divider()

                Button("Quit MacSweep Completely") {
                    NSApp.reply(toApplicationShouldTerminate: true)
                    AppDelegate.forceQuit = true
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command, .shift])
            }
            CommandGroup(after: .appInfo) {
                Button("Open MacSweep") {
                    appDelegate.openMainWindowFromMenuBar(nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }

        // Menu Bar — always visible, even when main window is closed/quit
        MenuBarExtra {
            MenuBarView(
                scanEngine: scanEngine,
                cleanEngine: cleanEngine,
                settings: settings,
                updateEngine: updateEngine
            )
        } label: {
            MenuBarLabel(scanEngine: scanEngine, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }

    private func hideApp() {
        // Hide windows and remove dock icon; menu bar stays alive.
        for window in NSApp.windows where window.canBecomeMain {
            window.orderOut(nil)
        }
        NSApp.setActivationPolicy(.accessory)
        NSApp.deactivate()
    }

}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    static var forceQuit = false
    /// Set to `true` during `didFinishLaunching` when the app was launched by a login-item
    /// and the user has "Launch as Menu Bar Only" enabled.
    static var launchedAsMenuBarOnly = false
    static weak var mainWindow: NSWindow?
    private let mainWindowIdentifier = "MacSweepMainWindow"
    static let preferredMainWindowSize = NSSize(width: 1380, height: 920)
    static let minimumMainWindowSize = NSSize(width: 1240, height: 820)
    private var allowSystemTermination = false
    private var workspaceObservers: [NSObjectProtocol] = []

    static func ensureMainWindowGeometry(_ window: NSWindow, forcePreferred: Bool = false) {
        window.minSize = minimumMainWindowSize

        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame

        let targetWidth = max(min(preferredMainWindowSize.width, visible.width - 24), minimumMainWindowSize.width)
        let targetHeight = max(min(preferredMainWindowSize.height, visible.height - 24), minimumMainWindowSize.height)

        let needsResize = forcePreferred
            || window.frame.width < minimumMainWindowSize.width
            || window.frame.height < minimumMainWindowSize.height

        guard needsResize else { return }

        // Position window in the center of the screen
        let targetRect = NSRect(
            x: visible.midX - targetWidth / 2,
            y: visible.midY - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
        window.setFrame(targetRect, display: true, animate: false)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerSystemTerminationObserver()

        // Detect login-item launch: at this earliest point the app is not yet active
        // when launched automatically by the system login-item mechanism.
        let ud = UserDefaults.standard
        let launchAtLogin = ud.object(forKey: "launchAtLogin") as? Bool ?? true
        let menuBarOnly   = ud.object(forKey: "launchAtLoginMenuBarOnly") as? Bool ?? true
        if launchAtLogin && menuBarOnly && !NSApp.isActive {
            AppDelegate.launchedAsMenuBarOnly = true
            NSApp.setActivationPolicy(.accessory)
            NSLog("[MacSweep] Login-item launch detected → menu bar only mode")
        }

        let debugSession = isDebuggerAttached()
        let bundleID = Bundle.main.bundleIdentifier ?? "com.mehmed.MacSweep"
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningInstances.count > 1 {
            // During Xcode debug runs, allow launching this instance without enforcing single-instance.
            if debugSession {
                NSLog("[MacSweep] Debug session detected; skipping single-instance enforcement")
                return
            }
            for app in runningInstances where app != NSRunningApplication.current {
                app.activate(options: [.activateAllWindows])
            }
            AppDelegate.forceQuit = true
            NSApp.terminate(nil)
            return
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Only allow FULL termination for:
        //   1. Explicit "Quit MacSweep Completely" (⇧⌘Q) which sets forceQuit = true
        //   2. System shutdown/restart (willPowerOffNotification sets allowSystemTermination)
        // Everything else (Dock "Quit", ⌘Q, window close) just hides windows → menu bar stays alive.
        if AppDelegate.forceQuit || allowSystemTermination {
            return .terminateNow
        }

        // Hide all main windows AND remove dock icon. Menu bar stays alive.
        DispatchQueue.main.async {
            for window in NSApp.windows where window.canBecomeMain {
                window.orderOut(nil)
            }
            NSApp.setActivationPolicy(.accessory)
            NSApp.deactivate()
        }

        return .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openMainWindowFromMenuBar(nil) }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func registerSystemTerminationObserver() {
        let center = NSWorkspace.shared.notificationCenter

        let powerOffObserver = center.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.allowSystemTermination = true
            AppDelegate.forceQuit = true
        }
        workspaceObservers.append(powerOffObserver)

        // Also handle system sleep so we never block a sleep transition.
        let sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.allowSystemTermination = true
        }
        workspaceObservers.append(sleepObserver)
    }

    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.size
        let result = mib.withUnsafeMutableBufferPointer { pointer in
            sysctl(pointer.baseAddress, u_int(pointer.count), &info, &size, nil, 0)
        }
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    // ── The single entry-point for showing the main window ──────────

    @objc func openMainWindowFromMenuBar(_ sender: Any?) {
        NSLog("[MacSweep] openMainWindowFromMenuBar called")
        NSLog("[MacSweep] Total windows: %d", NSApp.windows.count)
        for (i, w) in NSApp.windows.enumerated() {
            NSLog("[MacSweep] Window %d: visible=%d mini=%d canMain=%d id=%@ frame=%.0fx%.0f class=%@",
                  i, w.isVisible ? 1 : 0, w.isMiniaturized ? 1 : 0,
                  w.canBecomeMain ? 1 : 0,
                  w.identifier?.rawValue ?? "nil",
                  w.frame.width, w.frame.height,
                  String(describing: type(of: w)))
        }

        // Break out of MenuBarExtra event loop, then retry
        DispatchQueue.main.async { self.restoreWindow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.restoreWindow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.restoreWindow() }
    }

    private func restoreWindow() {
        // Ensure regular activation policy
        NSApp.setActivationPolicy(.regular)

        // First: un-minimize any main windows so they can be restored.
        for window in NSApp.windows {
            if window.isMiniaturized {
                NSLog("[MacSweep] Found miniaturized window, deminiaturizing")
                window.deminiaturize(nil)
            }
        }

        // Try to find the main window (hidden or otherwise)
        let target = findMainWindow()
        if let window = target {
            NSLog("[MacSweep] Showing window: id=%@", window.identifier?.rawValue ?? "nil")
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            AppDelegate.ensureMainWindowGeometry(window, forcePreferred: true)
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSLog("[MacSweep] No main window found, trying fallbacks")

        // Fallback 1: any titled window at all
        for window in NSApp.windows where window.canBecomeMain && window.styleMask.contains(.titled) {
            NSLog("[MacSweep] Trying canBecomeMain window")
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            AppDelegate.ensureMainWindowGeometry(window, forcePreferred: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            AppDelegate.mainWindow = window
            return
        }

        // Fallback 2: AppleScript activate (same as dock click)
        NSLog("[MacSweep] Using AppleScript activate")
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "MacSweep"
        let script = NSAppleScript(source: "tell application \"\(bundleName)\" to activate")
        script?.executeAndReturnError(nil)

        // Fallback 3: create new window via WindowGroup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !self.hasVisibleMainWindow() {
                NSLog("[MacSweep] Creating new window via WindowGroup")
                _ = NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func hasVisibleMainWindow() -> Bool {
        NSApp.windows.contains { $0.canBecomeMain && $0.isVisible && !$0.isMiniaturized }
    }

    private func findMainWindow() -> NSWindow? {
        // 1. Stored reference
        if let w = AppDelegate.mainWindow {
            return w
        }
        // 2. By identifier
        for w in NSApp.windows {
            if w.identifier?.rawValue == mainWindowIdentifier { return w }
        }
        // 3. By size
        for w in NSApp.windows {
            if w.styleMask.contains(.titled), w.frame.width >= 900 { return w }
        }
        return nil
    }
}

// MARK: - Menu Bar Label
struct MenuBarLabel: View {
    @ObservedObject var scanEngine: ScanEngine
    @ObservedObject var settings: AppSettings

    private var displayCPUPercent: Int { scanEngine.cpuUsagePercent }
    private var displayMemoryUsedCompact: String { scanEngine.memoryUsedCompact.replacingOccurrences(of: " ", with: "") }
    private var displayDiskAvailableCompact: String {
        guard let disk = scanEngine.diskInfo else { return "0G" }
        let gib = max(0, Int((Double(disk.freeSpace) / 1_073_741_824.0).rounded()))
        return "\(gib)G"
    }
    private var displayNetworkCompact: String {
        "↓\(formatRate(scanEngine.networkDownBytes)) ↑\(formatRate(scanEngine.networkUpBytes))"
    }
    private var metricTokens: [String] {
        var tokens: [String] = []
        if settings.menuBarShowCPU { tokens.append("\(displayCPUPercent)%") }
        if settings.menuBarShowRAM { tokens.append(displayMemoryUsedCompact) }
        if settings.menuBarShowDisk { tokens.append(displayDiskAvailableCompact) }
        if settings.menuBarShowNetwork { tokens.append(displayNetworkCompact) }
        if tokens.isEmpty { tokens.append("\(displayCPUPercent)%") }
        return tokens
    }
    private var metricsText: String { metricTokens.joined(separator: " ") }
    private var iconHeight: CGFloat { 16.0 }
    private var maxMetricsWidth: CGFloat {
        settings.menuBarShowNetwork ? 86 : 64
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(metricsText)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(displayCPUPercent > 80 ? .red : .primary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: maxMetricsWidth, alignment: .trailing)

            // Keep icon at right edge; values grow/collapse to the left.
            Image("MenuBarIcon")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: iconHeight)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func formatRate(_ bytesPerSecond: Int64) -> String {
        let value = Double(max(bytesPerSecond, 0))
        if value >= 1_000_000_000 { return String(format: "%.1fG", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0fK", value / 1_000) }
        return "\(Int(value))B"
    }
}
