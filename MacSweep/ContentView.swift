import SwiftUI

struct ContentView: View {
    @ObservedObject var scanEngine: ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @ObservedObject var settings: AppSettings
    
    // Hosted Engines for background execution
    @StateObject private var appsEngine = ApplicationsEngine()
    @StateObject private var protectionEngine = ProtectionEngine()
    @StateObject private var perfEngine = PerformanceEngine()
    @StateObject private var dupEngine = DuplicateEngine()
    @StateObject private var memoryEngine = MemoryEngine()
    @StateObject private var spaceEngine = SpaceLensEngine()
    @StateObject private var devEngine = DevCleanEngine()

    @State private var selected: AppSection = .dashboard
    @State private var hoverSection: AppSection?

    var body: some View {
        HStack(spacing: 0) {
            // Custom Sidebar
            SidebarView(
                selected: $selected,
                hoverSection: $hoverSection,
                scanEngine: scanEngine,
                settings: settings,
                appsEngine: appsEngine,
                protectionEngine: protectionEngine,
                perfEngine: perfEngine,
                dupEngine: dupEngine,
                memoryEngine: memoryEngine,
                spaceEngine: spaceEngine,
                devEngine: devEngine
            )
                .frame(width: 240)

            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)

            // Detail View with transition animation
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity
                ))
                .animation(.easeInOut(duration: 0.25), value: selected)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            if selected != settings.mainSection {
                selected = settings.mainSection
            }
            scanEngine.refreshDiskInfo()
            scanEngine.refreshRunningApps()
        }
        .onChange(of: settings.mainSectionRaw) { _, newRaw in
            let target = AppSection(rawValue: newRaw) ?? .dashboard
            if selected != target {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selected = target
                }
            }
        }
        .onChange(of: selected) { _, newValue in
            if settings.mainSection != newValue {
                settings.mainSection = newValue
            }
        }
        .background(
            MainWindowAccessor { window in
                guard let window else { return }
                if window.identifier?.rawValue != "MacSweepMainWindow" {
                    window.identifier = NSUserInterfaceItemIdentifier("MacSweepMainWindow")
                }
                window.isReleasedWhenClosed = false
                window.collectionBehavior.insert(.moveToActiveSpace)
                AppDelegate.mainWindow = window
            }
        )
    }

    @ViewBuilder
    var detailView: some View {
        switch selected {
        case .dashboard:
            DashboardView(scanEngine: scanEngine, selected: $selected)
        case .smartScan:
            SmartScanView(scanEngine: scanEngine, cleanEngine: cleanEngine, settings: settings)
        case .systemJunk:
            SystemJunkView(scanEngine: scanEngine, cleanEngine: cleanEngine)
        case .largeFiles:
            LargeFilesView(scanEngine: scanEngine, cleanEngine: cleanEngine)
        case .appLeftovers:
            ApplicationsManagerView(engine: appsEngine)
        case .browser:
            ProtectionManagerView(scanEngine: scanEngine, cleanEngine: cleanEngine, engine: protectionEngine)
        case .maintenance:
            PerformanceManagerView(engine: perfEngine, memoryEngine: memoryEngine)
        case .privacy:
            ProtectionManagerView(scanEngine: scanEngine, cleanEngine: cleanEngine, engine: protectionEngine)
        case .spaceLens:
            SpaceLensView(scanEngine: scanEngine, engine: spaceEngine)
        case .devCleaner:
            DevCleanerView(devEngine: devEngine)
        case .performance:
            PerformanceManagerView(engine: perfEngine, memoryEngine: memoryEngine)
        case .applications:
            ApplicationsManagerView(engine: appsEngine)
        case .protection:
            ProtectionManagerView(scanEngine: scanEngine, cleanEngine: cleanEngine, engine: protectionEngine)
        case .duplicates:
            DuplicateFinderView(engine: dupEngine)
        case .settings:
            SettingsView(scanEngine: scanEngine, settings: settings)
        }
    }
}

private struct MainWindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowHookView()
        view.onWindowChange = onResolve
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let hook = nsView as? WindowHookView else {
            DispatchQueue.main.async { onResolve(nsView.window) }
            return
        }
        hook.onWindowChange = onResolve
        DispatchQueue.main.async { onResolve(hook.window) }
    }
}

private final class WindowHookView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
