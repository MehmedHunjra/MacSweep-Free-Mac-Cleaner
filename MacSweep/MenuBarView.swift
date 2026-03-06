import SwiftUI
import AppKit
#if canImport(CoreWLAN)
import CoreWLAN
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif

#if canImport(CoreLocation)
final class WiFiLocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestIfNeeded() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}
}
#else
final class WiFiLocationPermissionManager: ObservableObject {
    func requestIfNeeded() {}
}
#endif

// MARK: - Menu Bar Root View (Premium Dark UI + All Features)
struct MenuBarView: View {
    @ObservedObject var scanEngine:  ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @ObservedObject var settings:    AppSettings
    @State private var tab: MenuTab = .overview
    @State private var appSearch = ""
    @State private var redrawTick = 0
    @StateObject private var wifiLocationPermission = WiFiLocationPermissionManager()
    @State private var selectedOverviewDetail: OverviewDetail?
    @State private var selectedAppPID: pid_t?
    @State private var networkUploadHistory: [Double] = Array(repeating: 0, count: 28)
    @State private var networkDownloadHistory: [Double] = Array(repeating: 0, count: 28)
    @State private var cpuUsageHistory: [Double] = Array(repeating: 0, count: 28)
    @State private var gpuUsageHistory: [Double] = Array(repeating: 0, count: 28)
    @State private var cachedNetworkDisplay: (name: String, icon: String) = ("Network", "network")
    @State private var cachedExternalVolumes: [String] = []
    @State private var cachedExternalVolumeDetails: [(name: String, total: Int64, free: Int64)] = []
    @State private var cachedTrashSizeBytes: Int64 = 0
    @State private var cachedStartupItemCount: Int = 0
    private let lastKnownWiFiNameKey = "last_known_wifi_name"

    enum MenuTab: String, CaseIterable {
        case overview = "Overview"
        case apps     = "Apps"
        case actions  = "Actions"

        var icon: String {
            switch self {
            case .overview: return "gauge.medium"
            case .apps:     return "square.stack.3d.up.fill"
            case .actions:  return "bolt.fill"
            }
        }
    }

    enum OverviewDetail: String, Identifiable {
        case disk
        case memory
        case cpu
        case gpu
        case network
        case externalDrives

        var id: String { rawValue }
    }

    // Dark premium gradient
    private let bgGradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.08, blue: 0.20),
            Color(red: 0.08, green: 0.06, blue: 0.18),
            Color(red: 0.06, green: 0.04, blue: 0.14)
        ],
        startPoint: .top, endPoint: .bottom
    )
    private var displayCPUPercent: Int { scanEngine.cpuUsagePercent }
    private var displayCPUUsage: Double { Double(displayCPUPercent) / 100.0 }
    private var displayMemoryUsedCompact: String { scanEngine.memoryUsedCompact }
    private var displayMemoryPercent: Int { scanEngine.memoryUsagePercent }
    private var displayMemoryUsage: Double { Double(displayMemoryPercent) / 100.0 }
    private var selectedRunningApp: RunningAppInfo? {
        if let pid = selectedAppPID, let app = scanEngine.runningApps.first(where: { $0.id == pid }) {
            return app
        }
        return scanEngine.runningApps.first
    }

    var body: some View {
        HStack(spacing: 12) {
            leftPanel
                .frame(width: 440, height: 560)

            mainPanel
                .frame(width: 380)
        }
        .frame(width: 840)
        .background(bgGradient)
        .animation(.easeInOut(duration: 0.22), value: settings.menuBarTab)
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            // Keep menu popup values fresh while it is open.
            redrawTick &+= 1
            appendNetworkHistoryPoint()
            appendUtilizationHistoryPoint()

            let focusNeedsFastRefresh = selectedOverviewDetail == .network || selectedOverviewDetail == .externalDrives
            let cadence = focusNeedsFastRefresh ? 2 : 6
            if settings.menuBarTab == "Overview", redrawTick % cadence == 0 {
                refreshPopupCaches()
            }
        }
        .onAppear {
            wifiLocationPermission.requestIfNeeded()
            appendNetworkHistoryPoint()
            appendUtilizationHistoryPoint()
            refreshPopupCaches()
            if selectedOverviewDetail == nil {
                selectedOverviewDetail = .disk
            }
            syncSelectedAppSelection()
        }
        .onChange(of: settings.menuBarTab) { _, newValue in
            if newValue == "Overview", selectedOverviewDetail == nil {
                selectedOverviewDetail = .disk
            }
            if newValue == "Apps" {
                syncSelectedAppSelection()
            }
        }
        .onChange(of: scanEngine.runningApps.map(\.id)) { _, _ in
            syncSelectedAppSelection()
        }
    }

    @ViewBuilder
    private var leftPanel: some View {
        switch settings.menuBarTab {
        case "Apps":
            appsDetailPanel
        case "Actions":
            actionsDetailPanel
        default:
            overviewDetailPanel(selectedOverviewDetail ?? .disk)
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            // ── Health Header ──────────────────
            healthHeader

            // ── Tab Picker ─────────────────────
            tabPicker

            // ── Content ────────────────────────
            Group {
                switch settings.menuBarTab {
                case "Apps":    appsTab
                case "Actions": actionsTab
                default:        overviewTab
                }
            }
            .frame(minHeight: 260)

            // ── Footer ─────────────────────────
            footerBar
        }
    }

    // MARK: - Health Header
    private var healthHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Mac Health:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(healthStatus)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(healthColor)
                }
                Text("Your Mac Status")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Stats indicator (Desktop icon)
            Image(systemName: "desktopcomputer")
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.3))
                .shadow(color: healthColor.opacity(0.3), radius: 6)

            // Quit App (Prominent in TOP BAR as requested)
            Button {
                AppDelegate.forceQuit = true
                NSApp.terminate(nil)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.red)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Quit MacSweep Completely")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var healthStatus: String {
        let cpu = displayCPUUsage
        let mem = displayMemoryUsage
        let disk = scanEngine.diskInfo?.usedPercentage ?? 0
        if cpu > 0.9 || mem > 0.95 || disk > 0.95 { return "Critical" }
        if cpu > 0.7 || mem > 0.85 || disk > 0.85 { return "Fair" }
        if cpu > 0.5 || mem > 0.7 || disk > 0.7 { return "Good" }
        return "Excellent"
    }

    private var healthColor: Color {
        switch healthStatus {
        case "Excellent": return Color(hex: "00E5FF")
        case "Good": return Color(hex: "38EF7D")
        case "Fair": return .orange
        default: return .red
        }
    }

    // MARK: - Tab Picker (Dark themed)
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(MenuTab.allCases, id: \.self) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { 
                        settings.menuBarTab = t.rawValue 
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon)
                            .font(.system(size: 11, weight: .medium))
                        Text(t.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(settings.menuBarTab == t.rawValue ? Color(hex: "00E5FF") : .white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(settings.menuBarTab == t.rawValue ? Color.white.opacity(0.06) : Color.clear)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) {
                        if settings.menuBarTab == t.rawValue {
                            Rectangle()
                                .fill(Color(hex: "00E5FF"))
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                if t != MenuTab.allCases.last {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 0.5)
                }
            }
        }
        .frame(height: 48)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Overview Tab
    private var overviewTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                // Topbar quick tools
                topUtilityRow

                // 2x2 card grid — each card is clickable with a real action
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    // Disk details popup
                    if let disk = scanEngine.diskInfo {
                        DarkStatCard(
                            icon: "internaldrive.fill",
                            title: "Macintosh HD",
                            value: "Available: \(disk.freeFormatted)",
                            valueColor: Color(hex: "00E5FF"),
                            action: "Free Up",
                            actionColor: Color(hex: "00E5FF"),
                            progress: disk.usedPercentage,
                            progressColor: disk.usedPercentage > 0.85 ? .red : disk.usedPercentage > 0.7 ? .orange : Color(hex: "00E5FF"),
                            isSelected: selectedOverviewDetail == .disk,
                            onAction: {
                                openMainApp(section: .smartScan, startSmartScan: true)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleOverviewDetail(.disk)
                        }
                    }

                    // Memory details popup
                    DarkStatCard(
                        icon: "memorychip",
                        title: "Memory",
                        value: "Used: \(displayMemoryUsedCompact) (\(displayMemoryPercent)%)",
                        valueColor: .white.opacity(0.6),
                        action: "Optimize",
                        actionColor: Color(hex: "FFD600"),
                        progress: displayMemoryUsage,
                        progressColor: displayMemoryUsage > 0.85 ? .red : displayMemoryUsage > 0.7 ? .orange : Color(hex: "38EF7D"),
                        isSelected: selectedOverviewDetail == .memory,
                        onAction: {
                            openMainApp(section: .maintenance)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleOverviewDetail(.memory)
                    }

                    // CPU details popup
                    DarkStatCard(
                        icon: "cpu",
                        title: "CPU",
                        value: "Load: \(displayCPUPercent)%",
                        valueColor: .white.opacity(0.6),
                        action: "Top Apps",
                        actionColor: Color(hex: "4776E6"),
                        progress: displayCPUUsage,
                        progressColor: displayCPUUsage > 0.8 ? .red : displayCPUUsage > 0.6 ? .orange : Color(hex: "4776E6"),
                        isSelected: selectedOverviewDetail == .cpu,
                        onAction: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.menuBarTab = "Apps"
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleOverviewDetail(.cpu)
                    }

                    // GPU details popup
                    DarkStatCard(
                        icon: "camera.filters",
                        title: scanEngine.gpuName,
                        value: scanEngine.vramTotalMB > 0
                            ? "\(scanEngine.vramTotalMB) MB \(scanEngine.gpuName.localizedCaseInsensitiveContains("unified") ? "Shared" : "VRAM")"
                            : "GPU Memory",
                        valueColor: .white.opacity(0.6),
                        action: "Top Apps",
                        actionColor: Color(hex: "BD10E0"),
                        progress: scanEngine.vramTotalMB > 0
                            ? Double(scanEngine.vramUsedMB) / Double(max(scanEngine.vramTotalMB, 1))
                            : scanEngine.memoryUsage,
                        progressColor: Color(hex: "BD10E0"),
                        isSelected: selectedOverviewDetail == .gpu,
                        onAction: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.menuBarTab = "Apps"
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleOverviewDetail(.gpu)
                    }
                }

                // Network row
                networkRow

                // External drives
                externalDrivesRow

                // Running apps count
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "00E5FF"))
                    Text("\(scanEngine.runningAppCount) apps running")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Button("View All") { withAnimation { settings.menuBarTab = "Apps" } }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "00E5FF"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))

                // Freed space history
                if !scanEngine.freedHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(Color(hex: "38EF7D"))
                                .font(.system(size: 11))
                            Text("Cleanup History")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(scanEngine.freedHistory.count) sessions")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                        }

                        Text("Total freed: \(ByteCountFormatter.string(fromByteCount: scanEngine.totalFreedBytes, countStyle: .file))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "38EF7D"))

                        ForEach(scanEngine.freedHistory.prefix(3)) { rec in
                            HStack {
                                Text("• \(rec.description)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineLimit(1)
                                Spacer()
                                Text(rec.sizeFormatted)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(hex: "38EF7D"))
                            }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "38EF7D").opacity(0.07)))
                }
            }
            .padding(12)
        }
    }

    private var topUtilityRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "8B9DC3"))
                    Text("Trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(ByteCountFormatter.string(fromByteCount: cachedTrashSizeBytes, countStyle: .file))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "FF5A74"))
                HStack {
                    Spacer()
                    Button("Release") {
                        releaseTrash()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "53C7FF"))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "8B9DC3"))
                    Text("Startup item management")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Text("\(cachedStartupItemCount) startup items detected")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                Text("Startup items dragging down boot time")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
                HStack {
                    Spacer()
                    Button("Manage") {
                        openMainApp(section: .performance)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "53C7FF"))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            )
        }
    }

    // MARK: - Network Row
    private var networkRow: some View {
        let network = cachedNetworkDisplay
        return HStack(spacing: 10) {
            Image(systemName: network.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "6DFFB8"))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(network.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label(formatSpeed(scanEngine.networkUpBytes), systemImage: "arrow.up")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "6DFFB8"))
                    Label(formatSpeed(scanEngine.networkDownBytes), systemImage: "arrow.down")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "53C7FF"))
                }
            }

            Spacer()

            Button("Test Speed") {
                openSpeedTest()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(hex: "53C7FF"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: selectedOverviewDetail == .network
                            ? [Color(hex: "4A2B97").opacity(0.8), Color(hex: "2A205A").opacity(0.9)]
                            : [Color.white.opacity(0.07), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    selectedOverviewDetail == .network ? Color(hex: "53C7FF").opacity(0.9) : Color.white.opacity(0.08),
                    lineWidth: selectedOverviewDetail == .network ? 1.2 : 0.8
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleOverviewDetail(.network)
        }
    }

    // MARK: - External Drives
    private var externalDrivesRow: some View {
        Group {
            if !cachedExternalVolumes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8B9DC3"))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("External Drives")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text(cachedExternalVolumes.joined(separator: ", "))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        for vol in cachedExternalVolumes {
                            let task = Process()
                            task.launchPath = "/usr/bin/hdiutil"
                            task.arguments = ["detach", "/Volumes/\(vol)"]
                            try? task.run()
                        }
                    } label: {
                        Image(systemName: "eject.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "00E5FF"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            selectedOverviewDetail == .externalDrives
                                ? Color(hex: "2A205A").opacity(0.9)
                                : Color.white.opacity(0.04)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            selectedOverviewDetail == .externalDrives ? Color(hex: "53C7FF").opacity(0.9) : Color.clear,
                            lineWidth: 1.2
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleOverviewDetail(.externalDrives)
                }
            }
        }
    }

    // MARK: - Apps Tab
    private var appsTab: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                TextField("Search apps...", text: $appSearch)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                if !appSearch.isEmpty {
                    Button { appSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)

            let filtered = appSearch.isEmpty
                ? scanEngine.runningApps
                : scanEngine.runningApps.filter { $0.name.localizedCaseInsensitiveContains(appSearch) }

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.2))
                    Text(appSearch.isEmpty ? "Loading..." : "No apps found")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { app in
                            DarkRunningAppRow(app: app) { forceQuit in
                                scanEngine.quitApp(app, force: forceQuit)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedAppPID == app.id ? Color(hex: "2A205A").opacity(0.7) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAppPID = app.id
                            }
                            if app.id != filtered.last?.id {
                                Rectangle()
                                    .fill(Color.white.opacity(0.04))
                                    .frame(height: 0.5)
                                    .padding(.leading, 48)
                            }
                        }
                    }
                }
            }

            // Total row
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)
            HStack {
                Text("\(filtered.count) of \(scanEngine.runningAppCount) apps")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Button {
                    scanEngine.refreshRunningApps()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "00E5FF"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.03))
        }
    }

    // MARK: - Actions Tab
    private var actionsTab: some View {
        ScrollView(showsIndicators: false) {
            actionsButtonsStack
                .padding(12)
        }
    }

    private var actionsButtonsStack: some View {
        VStack(spacing: 6) {
            DarkActionButton(
                icon: "trash.fill",
                title: "Empty Trash",
                subtitle: "Remove items in Trash permanently",
                color: .red
            ) {
                let task = Process()
                task.launchPath = "/usr/bin/osascript"
                task.arguments  = ["-e", "tell application \"Finder\" to empty trash"]
                try? task.run()
            }

            DarkActionButton(
                icon: "wind",
                title: "Free RAM (Purge)",
                subtitle: "Release inactive memory to free up RAM",
                color: Color(hex: "38EF7D")
            ) {
                runPrivilegedPurge()
            }

            DarkActionButton(
                icon: "network.slash",
                title: "Flush DNS Cache",
                subtitle: "Clear DNS resolver cache",
                color: Color(hex: "4776E6")
            ) {
                let task = Process()
                task.launchPath = "/usr/bin/dscacheutil"
                task.arguments  = ["-flushcache"]
                try? task.run()
            }

            DarkActionButton(
                icon: "star.fill",
                title: "Run Maintenance Scripts",
                subtitle: "Run daily, weekly, monthly scripts",
                color: Color(hex: "F5A623")
            ) {
                let task = Process()
                task.launchPath = "/usr/sbin/periodic"
                task.arguments  = ["daily", "weekly", "monthly"]
                try? task.run()
            }

            DarkActionButton(
                icon: "sparkles.rectangle.stack",
                title: "Quick Scan",
                subtitle: "Open MacSweep and scan for junk files",
                color: Color(hex: "00E5FF")
            ) {
                openMainApp(section: .smartScan, startSmartScan: true)
            }

            DarkActionButton(
                icon: "arrow.clockwise",
                title: "Refresh All Stats",
                subtitle: "Update disk, RAM, CPU, and app stats",
                color: .white.opacity(0.5)
            ) {
                scanEngine.refreshDiskInfo()
                scanEngine.refreshRunningApps()
            }
        }
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack(spacing: 10) {
            LogoView(size: 24)

            Button {
                openMainApp(section: settings.mainSection)
            } label: {
                Text("Open MacSweep")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            Spacer()

            // Buy a Coffee
            Button {
                if let url = URL(string: "https://ko-fi.com/mehmedhunjra") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("☕")
                        .font(.system(size: 11))
                    Text("Buy Me a Coffee")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Color(hex: "FFD600"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "FFD600").opacity(0.12)))
            }
            .buttonStyle(.plain)

            // Settings gear
            Button {
                openMainApp(section: .settings)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Detail Popups
    private func toggleOverviewDetail(_ detail: OverviewDetail) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedOverviewDetail = detail
        }
        if detail == .memory || detail == .cpu || detail == .gpu {
            scanEngine.refreshRunningApps()
        }
        if detail == .network || detail == .externalDrives {
            refreshPopupCaches()
        }
    }

    private func syncSelectedAppSelection() {
        if let pid = selectedAppPID, scanEngine.runningApps.contains(where: { $0.id == pid }) {
            return
        }
        selectedAppPID = scanEngine.runningApps.first?.id
    }

    private func appendNetworkHistoryPoint() {
        let upKB = Double(max(scanEngine.networkUpBytes, 0)) / 1_000
        let downKB = Double(max(scanEngine.networkDownBytes, 0)) / 1_000
        networkUploadHistory.append(upKB)
        networkDownloadHistory.append(downKB)
        if networkUploadHistory.count > 28 { networkUploadHistory.removeFirst() }
        if networkDownloadHistory.count > 28 { networkDownloadHistory.removeFirst() }
    }

    private func appendUtilizationHistoryPoint() {
        let cpu = min(max(Double(displayCPUPercent) / 100.0, 0), 1)
        let gpu = scanEngine.vramTotalMB > 0
            ? min(max(Double(scanEngine.vramUsedMB) / Double(scanEngine.vramTotalMB), 0), 1)
            : 0

        cpuUsageHistory.append(cpu)
        gpuUsageHistory.append(gpu)
        if cpuUsageHistory.count > 28 { cpuUsageHistory.removeFirst() }
        if gpuUsageHistory.count > 28 { gpuUsageHistory.removeFirst() }
    }

    private func overviewDetailPanel(_ detail: OverviewDetail) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(detailTitle(detail))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            ScrollView(showsIndicators: false) {
                detailBody(detail)
                    .padding(16)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "3B1772"), Color(hex: "200944"), Color(hex: "12052D")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "7B5BFF").opacity(0.45), lineWidth: 1.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }

    @ViewBuilder
    private func detailBody(_ detail: OverviewDetail) -> some View {
        switch detail {
        case .disk:
            diskDetailView
        case .memory:
            memoryDetailView
        case .cpu:
            cpuDetailView
        case .gpu:
            gpuDetailView
        case .network:
            networkDetailView
        case .externalDrives:
            externalDrivesDetailView
        }
    }

    private func detailTitle(_ detail: OverviewDetail) -> String {
        switch detail {
        case .disk: return "Macintosh HD"
        case .memory: return "Memory"
        case .cpu: return "CPU"
        case .gpu: return scanEngine.gpuName
        case .network: return "Network"
        case .externalDrives: return "External Drives"
        }
    }

    private var diskDetailView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let disk = scanEngine.diskInfo {
                HStack(alignment: .center, spacing: 16) {
                    PopupDonutRing(
                        segments: diskSegments(),
                        centerTop: disk.freeFormatted,
                        centerBottom: "of \(disk.totalFormatted)\navailable"
                    )
                    .frame(width: 200, height: 200)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(diskLegendItems(), id: \.name) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)
                                Text(item.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                                Spacer()
                                Text(item.value)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        HStack {
                            Spacer()
                            Button {
                                guard !scanEngine.isAnalyzingSpace else { return }
                                Task { await scanEngine.analyzeSpace() }
                            } label: {
                                Group {
                                    if scanEngine.isAnalyzingSpace {
                                        HStack(spacing: 6) {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(Color(hex: "53C7FF"))
                                            Text("Analyzing...")
                                        }
                                    } else {
                                        Label("Analyze categories", systemImage: "chart.pie")
                                    }
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "53C7FF"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            .disabled(scanEngine.isAnalyzingSpace)
                        }
                        .padding(.top, 8)
                    }
                }

                ActionInfoCard(
                    title: "Free Up",
                    value: disk.freeFormatted,
                    subtitle: "Click to open Smart Scan and clear junk safely."
                ) {
                    openMainApp(section: .smartScan, startSmartScan: true)
                }
            }
        }
    }

    private var memoryDetailView: some View {
        let topMemory = scanEngine.runningApps
            .sorted { $0.memoryMB > $1.memoryMB }
            .prefix(6)
        return VStack(alignment: .leading, spacing: 14) {
            if scanEngine.memoryTotal > 0 {
                PopupDonutRing(
                    segments: memorySegments(),
                    centerTop: displayMemoryUsedCompact,
                    centerBottom: "of \(ByteCountFormatter.string(fromByteCount: scanEngine.memoryTotal, countStyle: .memory)) used"
                )
                .frame(height: 210)
            }

            HStack(spacing: 10) {
                DetailBadge(title: "Pressure", value: "\(displayMemoryPercent)%", subtitle: "Current memory load")
                DetailBadge(
                    title: "Top App",
                    value: topMemory.first?.name ?? "n/a",
                    subtitle: topMemory.first?.memoryFormatted ?? "0 MB"
                )
            }

            if topMemory.isEmpty {
                Text("No app memory data yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("Top Consumers")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                ForEach(Array(topMemory.enumerated()), id: \.offset) { _, app in
                    DetailAppRow(
                        appIcon: app.icon,
                        appName: app.name,
                        valueText: app.memoryFormatted,
                        accent: Color(hex: "53C7FF")
                    )
                }
            }
        }
    }

    private var cpuDetailView: some View {
        let topCPU = scanEngine.runningApps
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(6)
        return VStack(alignment: .leading, spacing: 14) {
            PopupLinePanel(
                title: "Load",
                value: "\(displayCPUPercent)%",
                points: cpuUsageHistory,
                color: displayCPUPercent > 80 ? .red : Color(hex: "53C7FF")
            )
            .frame(height: 170)

            HStack(spacing: 10) {
                DetailBadge(title: "CPU Load", value: "\(displayCPUPercent)%", subtitle: "Total processor use")
                DetailBadge(
                    title: "Uptime",
                    value: formatUptime(ProcessInfo.processInfo.systemUptime),
                    subtitle: "Since last restart"
                )
            }

            Text("Top Consumers")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            if topCPU.isEmpty {
                Text("No CPU process data yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                ForEach(Array(topCPU.enumerated()), id: \.offset) { _, app in
                    DetailAppRow(
                        appIcon: app.icon,
                        appName: app.name,
                        valueText: app.cpuFormatted,
                        accent: Color(hex: "FF9C42")
                    )
                }
            }
        }
    }

    private var gpuDetailView: some View {
        let gpuPercent = scanEngine.vramTotalMB > 0
            ? min(max(Double(scanEngine.vramUsedMB) / Double(scanEngine.vramTotalMB), 0), 1)
            : 0
        return VStack(alignment: .leading, spacing: 14) {
            PopupLinePanel(
                title: scanEngine.gpuName,
                value: "\(Int(gpuPercent * 100))%",
                points: gpuUsageHistory,
                color: Color(hex: "BD10E0")
            )
            .frame(height: 170)

            HStack(spacing: 10) {
                DetailBadge(
                    title: "GPU Memory",
                    value: scanEngine.vramTotalMB > 0 ? "\(scanEngine.vramUsedMB) / \(scanEngine.vramTotalMB) MB" : "n/a",
                    subtitle: scanEngine.gpuName.localizedCaseInsensitiveContains("unified") ? "Shared memory" : "VRAM usage"
                )
                DetailBadge(title: "Status", value: healthStatus, subtitle: "Overall performance")
            }

            Text("Top Consumers")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            ForEach(Array(scanEngine.runningApps.prefix(5).enumerated()), id: \.offset) { _, app in
                DetailAppRow(
                    appIcon: app.icon,
                    appName: app.name,
                    valueText: appGPUText(app),
                    accent: Color(hex: "BD10E0")
                )
            }
        }
    }

    private var networkDetailView: some View {
        let network = cachedNetworkDisplay
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "wifi")
                        .foregroundColor(Color(hex: "6DFFB8"))
                    Text(network.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                Text("Upload \(formatSpeed(scanEngine.networkUpBytes))  •  Download \(formatSpeed(scanEngine.networkDownBytes))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "53C7FF"))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

            HStack(spacing: 10) {
                PopupLinePanel(
                    title: "Download",
                    value: formatSpeed(scanEngine.networkDownBytes),
                    points: networkDownloadHistory.map { min($0 / 3000, 1.0) },
                    color: Color(hex: "53C7FF")
                )
                PopupLinePanel(
                    title: "Upload",
                    value: formatSpeed(scanEngine.networkUpBytes),
                    points: networkUploadHistory.map { min($0 / 3000, 1.0) },
                    color: Color(hex: "FF7A7A")
                )
            }
            .frame(height: 130)

            ActionInfoCard(
                title: "Test Your Connection",
                value: "Open Speed Test",
                subtitle: "Run a real-time network speed test in your browser."
            ) {
                openSpeedTest()
            }
        }
    }

    private var externalDrivesDetailView: some View {
        let drives = cachedExternalVolumeDetails
        return VStack(alignment: .leading, spacing: 14) {
            if drives.isEmpty {
                Text("No external drives detected.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
            } else {
                ForEach(drives, id: \.name) { drive in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                                .foregroundColor(Color(hex: "8B9DC3"))
                            Text(drive.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: drive.total, countStyle: .file))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        GeometryReader { geo in
                            let usedRatio = drive.total > 0
                                ? Double(drive.total - drive.free) / Double(drive.total)
                                : 0
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.12))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "F8E71C"))
                                    .frame(width: geo.size.width * min(max(usedRatio, 0), 1))
                            }
                        }
                        .frame(height: 6)
                        HStack {
                            Text("Free: \(ByteCountFormatter.string(fromByteCount: drive.free, countStyle: .file))")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Button("Open") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/Volumes/\(drive.name)"))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(Color(hex: "53C7FF"))
                            .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                }
            }
        }
    }

    private func memorySegments() -> [PopupDonutRing.Segment] {
        let total = Double(max(scanEngine.memoryTotal, 1))
        let appMemoryMB = scanEngine.runningApps.reduce(0.0) { $0 + $1.memoryMB }
        let appBytes = appMemoryMB * 1_000_000
        let systemBytes = max(Double(scanEngine.memoryUsed) - appBytes, 0)
        let freeBytes = max(total - Double(scanEngine.memoryUsed), 0)
        return [
            .init(
                name: "Applications",
                value: appBytes,
                valueText: ByteCountFormatter.string(fromByteCount: Int64(appBytes), countStyle: .memory),
                color: Color(hex: "53C7FF")
            ),
            .init(
                name: "System",
                value: systemBytes,
                valueText: ByteCountFormatter.string(fromByteCount: Int64(systemBytes), countStyle: .memory),
                color: Color(hex: "667EEA")
            ),
            .init(
                name: "Free",
                value: freeBytes,
                valueText: ByteCountFormatter.string(fromByteCount: Int64(freeBytes), countStyle: .memory),
                color: .white.opacity(0.35)
            )
        ]
    }

    private func diskSegments() -> [PopupDonutRing.Segment] {
        guard let disk = scanEngine.diskInfo else {
            return [.init(name: "Used", value: 1, valueText: "0 B", color: .white.opacity(0.3))]
        }

        if scanEngine.storageCategories.isEmpty {
            return [
                .init(
                    name: "Used",
                    value: Double(disk.usedSpace),
                    valueText: disk.usedFormatted,
                    color: Color(hex: "F8E71C")
                ),
                .init(
                    name: "Free",
                    value: Double(max(disk.freeSpace, 1)),
                    valueText: disk.freeFormatted,
                    color: .white.opacity(0.35)
                )
            ]
        }

        var segments = scanEngine.storageCategories.prefix(5).map {
            PopupDonutRing.Segment(
                name: $0.name,
                value: Double($0.size),
                valueText: $0.sizeFormatted,
                color: $0.color
            )
        }
        segments.append(
            .init(
                name: "Free",
                value: Double(max(disk.freeSpace, 1)),
                valueText: disk.freeFormatted,
                color: .white.opacity(0.35)
            )
        )
        return segments
    }

    private func diskLegendItems() -> [(name: String, value: String, color: Color)] {
        if !scanEngine.storageCategories.isEmpty {
            let rows = scanEngine.storageCategories.prefix(5).map {
                (name: $0.name, value: $0.sizeFormatted, color: $0.color)
            }
            if let disk = scanEngine.diskInfo {
                return rows + [(name: "Free", value: disk.freeFormatted, color: .white.opacity(0.65))]
            }
            return rows
        }

        guard let disk = scanEngine.diskInfo else { return [] }
        return [
            (name: "Used", value: disk.usedFormatted, color: Color(hex: "F8E71C")),
            (name: "Free", value: disk.freeFormatted, color: .white.opacity(0.65))
        ]
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        if days > 0 { return "\(days)d \(hours)h" }
            return "\(hours)h"
    }

    private var appsDetailPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Apps")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if let app = selectedRunningApp {
                        HStack(spacing: 10) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: 42, height: 42)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.18))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Image(systemName: "app.fill")
                                            .foregroundColor(.white.opacity(0.8))
                                    )
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(.white)
                                Text("PID \(app.id) • \(app.isActive ? "Active" : "Background")")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                        HStack(spacing: 10) {
                            DetailBadge(title: "CPU", value: app.cpuFormatted, subtitle: "Current usage")
                            DetailBadge(title: "RAM", value: app.memoryFormatted, subtitle: "Current memory")
                            DetailBadge(title: "GPU", value: appGPUText(app), subtitle: "Estimated share")
                        }

                        HStack(spacing: 8) {
                            DetailCommandButton(title: "Open", color: Color(hex: "53C7FF")) {
                                openRunningApp(app)
                            }
                            DetailCommandButton(title: "Quit", color: .orange) {
                                quitRunningApp(app)
                            }
                            DetailCommandButton(title: "Force Quit", color: .red) {
                                forceQuitRunningApp(app)
                            }
                            DetailCommandButton(title: "Restart", color: Color(hex: "BD10E0")) {
                                restartRunningApp(app)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bundle ID")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            Text(app.bundleId.isEmpty ? "Unknown" : app.bundleId)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    } else {
                        Text("No running apps found.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.75))
                    }

                    Text("Running Apps")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 4)

                    ForEach(scanEngine.runningApps.prefix(14)) { app in
                        Button {
                            selectedAppPID = app.id
                        } label: {
                            HStack(spacing: 10) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 18, height: 18)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 18, height: 18)
                                }
                                Text(app.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Text(app.cpuFormatted)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "FF9C42"))
                                Text(app.memoryFormatted)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "53C7FF"))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedAppPID == app.id ? Color(hex: "2A205A").opacity(0.85) : Color.white.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "3B1772"), Color(hex: "200944"), Color(hex: "12052D")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "7B5BFF").opacity(0.45), lineWidth: 1.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }

    private var actionsDetailPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Actions")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Maintenance")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Run cleanup and optimization actions instantly from this panel.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.72))
                    actionsButtonsStack
                }
                .padding(16)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "3B1772"), Color(hex: "200944"), Color(hex: "12052D")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "7B5BFF").opacity(0.45), lineWidth: 1.0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }

    private func getExternalVolumeDetails() -> [(name: String, total: Int64, free: Int64)] {
        let names = cachedExternalVolumes
        return names.compactMap { name in
            let url = URL(fileURLWithPath: "/Volumes/\(name)")
            guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
                  let total = values.volumeTotalCapacity,
                  let free = values.volumeAvailableCapacity else {
                return nil
            }
            return (name: name, total: Int64(total), free: Int64(free))
        }
    }

    private func refreshPopupCaches() {
        DispatchQueue.global(qos: .utility).async {
            let network = self.getActiveNetworkDisplay()
            let volumes = self.getExternalVolumes() ?? []
            let details = volumes.compactMap { name -> (name: String, total: Int64, free: Int64)? in
                let url = URL(fileURLWithPath: "/Volumes/\(name)")
                guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
                      let total = values.volumeTotalCapacity,
                      let free = values.volumeAvailableCapacity else {
                    return nil
                }
                return (name: name, total: Int64(total), free: Int64(free))
            }
            let trashSize = self.getTrashSizeBytes()
            let startupCount = self.getStartupItemCount()
            DispatchQueue.main.async {
                self.cachedNetworkDisplay = network
                self.cachedExternalVolumes = volumes
                self.cachedExternalVolumeDetails = details
                self.cachedTrashSizeBytes = trashSize
                self.cachedStartupItemCount = startupCount
            }
        }
    }

    private func releaseTrash() {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "tell application \"Finder\" to empty trash"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            refreshPopupCaches()
        }
    }

    private func getTrashSizeBytes() -> Int64 {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let trashPath = "\(home)/.Trash"
        guard FileManager.default.fileExists(atPath: trashPath) else { return 0 }
        return ScanEngine.calcSize(path: trashPath)
    }

    private func getStartupItemCount() -> Int {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let dirs = [
            "\(home)/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons"
        ]
        var total = 0
        for dir in dirs {
            guard fm.fileExists(atPath: dir),
                  let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            total += contents.filter { $0.hasSuffix(".plist") }.count
        }
        return total
    }

    private func appGPUText(_ app: RunningAppInfo) -> String {
        guard scanEngine.vramTotalMB > 0 else { return "n/a" }
        let totalCPU = scanEngine.runningApps.reduce(0.0) { $0 + max($1.cpuPercent, 0) }
        guard totalCPU > 0 else { return "n/a" }
        let ratio = max(app.cpuPercent, 0) / totalCPU
        let estimated = Int64((Double(scanEngine.vramUsedMB) * ratio).rounded())
        return estimated > 0 ? "\(estimated) MB est." : "n/a"
    }

    private func openRunningApp(_ app: RunningAppInfo) {
        if let running = NSRunningApplication(processIdentifier: app.id) {
            running.activate(options: [.activateAllWindows])
            return
        }
        guard !app.bundleId.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleId) else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    private func quitRunningApp(_ app: RunningAppInfo) {
        scanEngine.quitApp(app, force: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            scanEngine.refreshRunningApps()
        }
    }

    private func forceQuitRunningApp(_ app: RunningAppInfo) {
        scanEngine.quitApp(app, force: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            scanEngine.refreshRunningApps()
        }
    }

    private func restartRunningApp(_ app: RunningAppInfo) {
        let appURL: URL? = app.bundleId.isEmpty ? nil : NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleId)
        scanEngine.quitApp(app, force: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if let appURL {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            }
            scanEngine.refreshRunningApps()
        }
    }

    private func openMainApp(section: AppSection, startSmartScan: Bool = false) {
        settings.mainSection = section
        // Route through app delegate first so all open actions use one robust window-restore path.
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.openMainWindowFromMenuBar(nil)
        } else {
            // Fallback (should rarely happen)
            DispatchQueue.main.async {
                self.ensureMainWindowVisibleFallback()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.ensureMainWindowVisibleFallback()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.ensureMainWindowVisibleFallback()
            }
        }
        if startSmartScan, !scanEngine.isScanning {
            Task { await scanEngine.startScan() }
        }
    }

    private func hasVisibleMainWindow() -> Bool {
        NSApp.windows.contains { win in
            guard win.canBecomeMain else { return false }
            guard win.styleMask.contains(.titled) else { return false }
            let likelyMain = win.identifier?.rawValue == "MacSweepMainWindow"
                || (win.frame.width >= 1000 && win.frame.height >= 650)
            return likelyMain && win.isVisible
        }
    }

    private func ensureMainWindowVisibleFallback() {
        if hasVisibleMainWindow() {
            // Window exists and is visible — just center and activate it
            for win in NSApp.windows where win.canBecomeMain && win.isVisible {
                win.center()
                win.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let existing = AppDelegate.mainWindow {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }
            existing.collectionBehavior.insert(.moveToActiveSpace)
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            existing.center()
            return
        }

        let host = NSHostingController(
            rootView: ContentView(
                scanEngine: scanEngine,
                cleanEngine: cleanEngine,
                settings: settings
            )
            .frame(minWidth: 1100, minHeight: 720)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacSweep"
        window.contentViewController = host
        window.identifier = NSUserInterfaceItemIdentifier("MacSweepMainWindow")
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)
        AppDelegate.mainWindow = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.center()
    }

    // MARK: - Helpers
    private func runPrivilegedPurge() {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "do shell script \"/usr/bin/purge\" with administrator privileges"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try? task.run()
    }

    private func getActiveNetworkDisplay() -> (name: String, icon: String) {
        guard let iface = getDefaultRouteInterface() ?? getWifiInterfaceName() else {
            return ("Network", "network")
        }

        if let wifiIface = getWifiInterfaceName(), iface == wifiIface {
            if let ssid = getWiFiNetworkName(interface: iface) {
                return (ssid, "wifi")
            }
            if let cached = getCachedWiFiName(), !isGenericWiFiName(cached) {
                return (cached, "wifi")
            }
            if let serviceName = getNetworkServiceName(for: iface), !isGenericWiFiName(serviceName) {
                return (serviceName, "wifi")
            }
            if let hotspotHint = getHotspotHintFromIPConfig(interface: iface) {
                return (hotspotHint, "wifi")
            }
            return ("Wi-Fi", "wifi")
        }

        if iface.hasPrefix("utun") {
            return ("VPN", "lock.shield")
        }

        if let port = getHardwarePortName(for: iface), !port.isEmpty {
            return (port, "network")
        }

        return (iface.uppercased(), "network")
    }

    private func getWiFiNetworkName(interface: String) -> String? {
        #if canImport(CoreWLAN)
        if let wifiInterface = CWWiFiClient.shared().interface(withName: interface) ?? CWWiFiClient.shared().interface(),
           let ssid = wifiInterface.ssid(),
           !ssid.isEmpty {
            cacheWiFiName(ssid)
            return ssid
        }
        #endif

        if let scutilSSID = getWiFiNameFromSystemState(interface: interface) {
            cacheWiFiName(scutilSSID)
            return scutilSSID
        }

        if let ipconfigSSID = getWiFiNameFromIPConfig(interface: interface) {
            cacheWiFiName(ipconfigSSID)
            return ipconfigSSID
        }

        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-getairportnetwork", interface]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lower = output.lowercased()
                if lower.contains("not associated") || lower.contains("error") {
                    return nil
                }
                if let range = output.range(of: ":") {
                    let name = output[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if let cleaned = sanitizeWiFiName(name) {
                        cacheWiFiName(cleaned)
                        return cleaned
                    }
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    private func getWiFiNameFromSystemState(interface: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/scutil"
        task.arguments = ["show", "State:/Network/Interface/\(interface)/AirPort"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        for raw in output.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("SSID_STR :") else { continue }
            let value = line.replacingOccurrences(of: "SSID_STR :", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return sanitizeWiFiName(value)
        }
        return nil
    }

    private func getWiFiNameFromIPConfig(interface: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/ipconfig"
        task.arguments = ["getsummary", interface]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        var ssidValue: String?
        var networkIDValue: String?
        for raw in output.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("SSID :") {
                let value = line.replacingOccurrences(of: "SSID :", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                ssidValue = sanitizeWiFiName(value)
                continue
            }
            if line.hasPrefix("NetworkID :") {
                let value = line.replacingOccurrences(of: "NetworkID :", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                networkIDValue = sanitizeWiFiName(value)
            }
        }
        return ssidValue ?? networkIDValue
    }

    private func sanitizeWiFiName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if trimmed.isEmpty || lower == "<redacted>" || lower == "n/a" || lower == "none" || lower == "<null>" {
            return nil
        }
        return trimmed
    }

    private func isGenericWiFiName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "wi-fi" || normalized == "wifi" || normalized == "airport"
    }

    private func cacheWiFiName(_ name: String) {
        UserDefaults.standard.set(name, forKey: lastKnownWiFiNameKey)
    }

    private func getCachedWiFiName() -> String? {
        guard let cached = UserDefaults.standard.string(forKey: lastKnownWiFiNameKey) else { return nil }
        return sanitizeWiFiName(cached)
    }

    private func getHotspotHintFromIPConfig(interface: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/ipconfig"
        task.arguments = ["getsummary", interface]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.uppercased() else { return nil }
        if output.contains("ANDROID_METERED") { return "Android Hotspot" }
        if output.contains("APPLE_MOBILE") || output.contains("IPHONE") { return "iPhone Hotspot" }
        return nil
    }

    private func getNetworkServiceName(for interface: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-listnetworkserviceorder"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        let lines = output.components(separatedBy: .newlines)
        var currentService: String?
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("("), line.contains(")") {
                if let close = line.firstIndex(of: ")") {
                    let start = line.index(after: close)
                    let name = String(line[start...]).trimmingCharacters(in: .whitespaces)
                    currentService = name.isEmpty ? nil : name
                }
                continue
            }
            if line.contains("Device: \(interface)") {
                return currentService
            }
        }
        return nil
    }

    private func formatSpeed(_ bytes: Int64) -> String {
        if bytes >= 1_000_000_000 {
            return String(format: "%.2f GB/sec", Double(bytes) / 1_000_000_000)
        } else if bytes >= 1_000_000 {
            return String(format: "%.1f MB/sec", Double(bytes) / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.1f KB/sec", Double(bytes) / 1_000)
        } else {
            return "\(bytes) B/sec"
        }
    }

    private func openSpeedTest() {
        guard let url = URL(string: "https://speed.cloudflare.com") else { return }
        NSWorkspace.shared.open(url)
    }

    private func getWifiInterfaceName() -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-listallhardwareports"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        let lines = output.components(separatedBy: .newlines)
        var inWiFiBlock = false
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Hardware Port:") {
                let lower = line.lowercased()
                inWiFiBlock = lower.contains("wi-fi") || lower.contains("airport")
                continue
            }
            if inWiFiBlock, line.hasPrefix("Device:") {
                let iface = line.replacingOccurrences(of: "Device:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return iface.isEmpty ? nil : iface
            }
        }
        return nil
    }

    private func getHardwarePortName(for interface: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-listallhardwareports"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        let lines = output.components(separatedBy: .newlines)

        var currentPortName: String?
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Hardware Port:") {
                currentPortName = line.replacingOccurrences(of: "Hardware Port:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.hasPrefix("Device:") {
                let iface = line.replacingOccurrences(of: "Device:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if iface == interface {
                    return currentPortName
                }
            }
        }
        return nil
    }

    private func getDefaultRouteInterface() -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/route"
        task.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        for raw in output.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("interface:") {
                let iface = line.replacingOccurrences(of: "interface:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return iface.isEmpty ? nil : iface
            }
        }
        return nil
    }

    private func getExternalVolumes() -> [String]? {
        let fm = FileManager.default
        guard let vols = try? fm.contentsOfDirectory(atPath: "/Volumes") else { return nil }
        let exclude = ["Macintosh HD", "Macintosh HD - Data", "Recovery"]
        let filtered = vols.filter { name in
            if name.starts(with: ".") { return false }
            if exclude.contains(name) { return false }
            if name.starts(with: "MacSweep") { return false }
            // Only show volumes on external/removable physical media
            let url = URL(fileURLWithPath: "/Volumes/\(name)")
            if let values = try? url.resourceValues(forKeys: [
                .volumeIsRemovableKey, .volumeIsInternalKey, .volumeIsLocalKey
            ]) {
                // Must be removable OR external (not internal)
                if values.volumeIsRemovable == true { return true }
                if values.volumeIsInternal == false && values.volumeIsLocal == true { return true }
            }
            return false
        }
        return filtered.isEmpty ? nil : Array(filtered.prefix(3))
    }
}

// MARK: - Dark Stat Card
struct DarkStatCard: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color
    let action: String?
    let actionColor: Color
    let progress: Double
    let progressColor: Color
    let isSelected: Bool
    let onAction: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "8B9DC3"))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(valueColor)
                .lineLimit(1)

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [progressColor, progressColor.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * min(progress, 1.0))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 3)

            if let action = action {
                if let onAction {
                    Button(action) {
                        onAction()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(actionColor)
                } else {
                    Text(action)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(actionColor)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                        ? Color(hex: "2A205A").opacity(0.9)
                        : (isHovered ? Color.white.opacity(0.10) : Color.white.opacity(0.06))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? Color(hex: "53C7FF").opacity(0.9) : Color.white.opacity(0.06),
                    lineWidth: isSelected ? 1.2 : 0.5
                )
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Dark Running App Row
struct DarkRunningAppRow: View {
    let app: RunningAppInfo
    let onQuit: (Bool) -> Void
    @State private var isHovered = false
    @State private var showConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 28, height: 28)
                    .overlay(Image(systemName: "app").foregroundColor(.white.opacity(0.3)))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(app.name)
                        .font(.system(size: 12, weight: app.isActive ? .semibold : .regular))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if app.isActive {
                        Circle()
                            .fill(Color(hex: "38EF7D"))
                            .frame(width: 5, height: 5)
                    }
                }
                HStack(spacing: 8) {
                    Label(app.cpuFormatted, systemImage: "cpu")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(app.cpuPercent > 50 ? .orange : .white.opacity(0.4))
                    Label(app.memoryFormatted, systemImage: "memorychip")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(app.memoryMB > 1000 ? .orange : .white.opacity(0.4))
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    Button {
                        onQuit(false)
                    } label: {
                        Text("Quit")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange.cornerRadius(4))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showConfirm = true
                    } label: {
                        Text("Force")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red.cornerRadius(4))
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Force quit \(app.name)?", isPresented: $showConfirm) {
                        Button("Force Quit", role: .destructive) { onQuit(true) }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Unsaved data in \(app.name) may be lost.")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isHovered ? Color.white.opacity(0.06) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Dark Action Button
struct DarkActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    @State private var isDone = false

    var body: some View {
        Button {
            action()
            withAnimation { isDone = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { isDone = false }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isDone
                            ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "38EF7D"), Color(hex: "38EF7D").opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: isDone ? "checkmark" : icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(isDone ? "Done!" : subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(isDone ? Color(hex: "38EF7D") : .white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Detail Popup Components
struct PopupDonutRing: View {
    struct Segment {
        let name: String
        let value: Double
        let valueText: String
        let color: Color
    }

    let segments: [Segment]
    let centerTop: String
    let centerBottom: String
    @State private var hoveredIndex: Int? = nil

    private var total: Double {
        max(segments.reduce(0) { $0 + max($1.value, 0) }, 1)
    }

    private var displayTop: String {
        guard let idx = hoveredIndex, segments.indices.contains(idx) else { return centerTop }
        return segments[idx].valueText
    }

    private var displayBottom: String {
        guard let idx = hoveredIndex, segments.indices.contains(idx) else { return centerBottom }
        let segment = segments[idx]
        let pct = Int(((segment.value / total) * 100).rounded())
        return "\(segment.name)\n\(pct)% of total"
    }

    private var hoveredSegment: Segment? {
        guard let idx = hoveredIndex, segments.indices.contains(idx) else { return nil }
        return segments[idx]
    }

    private var hoveredPercent: Int {
        guard let idx = hoveredIndex, segments.indices.contains(idx) else { return 0 }
        let segment = segments[idx]
        return Int(((segment.value / total) * 100).rounded())
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 22)
            ForEach(Array(segments.enumerated()), id: \.offset) { idx, segment in
                let previous = segments.prefix(idx).reduce(0) { $0 + max($1.value, 0) }
                let start = previous / total
                let end = (previous + max(segment.value, 0)) / total
                Circle()
                    .trim(from: start, to: end)
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: hoveredIndex == idx ? 28 : 22, lineCap: .round)
                    )
                    .opacity(hoveredIndex == nil || hoveredIndex == idx ? 1 : 0.45)
                    .shadow(color: hoveredIndex == idx ? segment.color.opacity(0.5) : .clear, radius: 6)
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 4) {
                Text(displayTop)
                    .font(.system(size: 33, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(displayBottom)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 10)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: hoveredIndex)
        .overlay {
            GeometryReader { geo in
                if let idx = hoveredIndex, segments.indices.contains(idx), let segment = hoveredSegment {
                    let point = tooltipPosition(for: idx, in: geo.size)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(segment.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 7, height: 7)
                            Text(segment.valueText)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.95))
                            Text("(\(hoveredPercent)%)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.black.opacity(0.46))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    .position(point)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .overlay {
            GeometryReader { geo in
                Color.clear
                    .contentShape(Circle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoveredIndex = segmentIndex(at: location, in: geo.size)
                        case .ended:
                            hoveredIndex = nil
                        }
                    }
                    .onHover { inside in
                        if !inside { hoveredIndex = nil }
                    }
            }
        }
    }

    private func segmentIndex(at location: CGPoint, in size: CGSize) -> Int? {
        let minSide = min(size.width, size.height)
        guard minSide > 40 else { return nil }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        let lineWidth: CGFloat = 22
        let radius = (minSide / 2) - (lineWidth / 2)
        let ringTolerance: CGFloat = 8
        let minRadius = radius - (lineWidth / 2) - ringTolerance
        let maxRadius = radius + (lineWidth / 2) + ringTolerance
        guard distance >= minRadius, distance <= maxRadius else { return nil }

        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        let fraction = Double(degrees / 360)

        var cumulative = 0.0
        for idx in segments.indices {
            let value = max(segments[idx].value, 0)
            let width = value / total
            let next = cumulative + width
            if fraction >= cumulative && fraction <= next {
                return idx
            }
            cumulative = next
        }
        return nil
    }

    private func tooltipPosition(for idx: Int, in size: CGSize) -> CGPoint {
        let minSide = min(size.width, size.height)
        let lineWidth: CGFloat = 22
        let radius = (minSide / 2) - (lineWidth / 2)
        let tooltipRadius = radius + 34

        let previous = segments.prefix(idx).reduce(0) { $0 + max($1.value, 0) }
        let segmentValue = max(segments[idx].value, 0)
        let mid = (previous + (segmentValue / 2)) / total

        let degrees = (mid * 360) - 90
        let radians = degrees * .pi / 180

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let rawX = center.x + CGFloat(cos(radians)) * tooltipRadius
        let rawY = center.y + CGFloat(sin(radians)) * tooltipRadius

        // Keep tooltip inside ring bounds.
        let x = min(max(rawX, 56), size.width - 56)
        let y = min(max(rawY, 18), size.height - 18)
        return CGPoint(x: x, y: y)
    }
}

struct DetailBadge: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.62))
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
    }
}

struct DetailAppRow: View {
    let appIcon: NSImage?
    let appName: String
    let valueText: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(accent.opacity(0.75))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: "app.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    )
            }
            Text(appName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            Spacer()
            Text(valueText)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
    }
}

struct PopupLinePanel: View {
    let title: String
    let value: String
    let points: [Double]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.82))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                    Path { path in
                        guard points.count > 1 else { return }
                        for idx in points.indices {
                            let x = geo.size.width * CGFloat(idx) / CGFloat(points.count - 1)
                            let y = geo.size.height * CGFloat(1 - min(max(points[idx], 0), 1))
                            if idx == points.startIndex {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, lineWidth: 2)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
    }
}

struct ActionInfoCard: View {
    let title: String
    let value: String
    let subtitle: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(value)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "53C7FF"))
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.08))
            )
            .shadow(color: isHovered ? .black.opacity(0.18) : .clear, radius: isHovered ? 10 : 0, y: 3)
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

struct DetailCommandButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? color.opacity(0.65) : color.opacity(0.45))
                )
                .shadow(color: color.opacity(isHovered ? 0.35 : 0), radius: isHovered ? 8 : 0, y: 2)
                .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Menu Bar Status Row (compatibility)
struct MenuBarStatusRow: View {
    let icon: String
    let title: String
    let value: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Text(value).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: geo.size.width * min(progress, 1.0))
                }
            }
            .frame(height: 4)
        }
    }
}
