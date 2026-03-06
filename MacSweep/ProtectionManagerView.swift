import SwiftUI
import AppKit

// MARK: - Protection Manager View
struct ProtectionManagerView: View {
    @ObservedObject var scanEngine: ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @ObservedObject var engine: ProtectionEngine
    @State private var selectedGroup: ProtectionGroup.Kind? = .safari
    @State private var showConfirm = false
    @State private var showResult = false
    @State private var resultMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            if !engine.isScanning && !engine.hasScanned {
                landingScreen
            } else {
                protHeader
                Divider()
                HStack(spacing: 0) {
                    protGroupList
                    Divider()
                    if let kind = selectedGroup,
                       let group = engine.groups.first(where: { $0.kind == kind }) {
                        protItemList(group: group)
                    } else {
                        emptyState
                    }
                }
                Divider()
                protFooter
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Cleanup Complete", isPresented: $showResult) {
            Button("OK") { engine.scanAll() }
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: - Landing
    private var landingScreen: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "06122C"), Color(hex: "0A244D"), Color(hex: "0F3C7E"), Color(hex: "06122C")],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()

                // 3D Glass Icon for Protection
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(colors: [Color(hex: "0F2027").opacity(0.6), Color(hex: "2C5364").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "0F2027").opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Image(systemName: "lock.shield")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "B2EBF2")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.bottom, 28)

                Text("Privacy & Protection")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Scan all browsers, privacy traces, recent activity,\ncrash reports, and system data in one click.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 48)

                ToolPrimaryActionButton(
                    title: "Scan",
                    colors: [Color(hex: "0F2027"), Color(hex: "2C5364")],
                    icon: "sparkles"
                ) {
                    engine.hasScanned = true
                    engine.scanAll()
                }

                Spacer()
            }
        }
    }

    // MARK: - Header
    var protHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color(hex: "0F2027"), Color(hex: "2C5364")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: "lock.shield")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Privacy & Protection")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Browsers, privacy data, activity traces & crash reports")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if engine.isScanning {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Scanning…")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteCountFormatter.string(fromByteCount: engine.totalSize, countStyle: .file))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "2C5364"))
                    Text("privacy traces found")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Group List
    var protGroupList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(engine.groups) { group in
                    ProtGroupRow(
                        group: group,
                        isSelected: selectedGroup == group.kind,
                        onTap: { selectedGroup = group.kind }
                    )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .frame(width: 200)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Item List
    func protItemList(group: ProtectionGroup) -> some View {
        VStack(spacing: 0) {
            // Group header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(group.gradient)
                        .frame(width: 36, height: 36)
                    Image(systemName: group.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.system(size: 16, weight: .bold))
                    Text("\(group.items.count) traces • \(ByteCountFormatter.string(fromByteCount: group.totalSize, countStyle: .file))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    engine.toggleAllInGroup(group.kind)
                } label: {
                    Text(group.allSelected ? "Deselect All" : "Select All")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if group.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.success.opacity(0.6))
                    Text("No \(group.name.lowercased()) traces found")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("Your privacy is clean in this category.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(engine.groups.first(where: { $0.kind == group.kind })?.items ?? []) { item in
                            ProtItemRow(item: item) {
                                engine.toggleItem(kind: group.kind, itemId: item.id)
                            }
                            Divider().padding(.leading, 56)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Select a category to view traces")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer
    var protFooter: some View {
        HStack(spacing: 12) {
            Button {
                engine.scanAll()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            if !engine.isScanning {
                Text("\(engine.selectedCount) traces (\(ByteCountFormatter.string(fromByteCount: engine.selectedSize, countStyle: .file)))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Button {
                showConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                    Text("Clear Selected")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(engine.selectedCount == 0
                              ? AnyShapeStyle(Color.gray)
                              : AnyShapeStyle(LinearGradient(colors: [Color(hex: "0F2027"), Color(hex: "2C5364")],
                                                             startPoint: .leading, endPoint: .trailing)))
                )
            }
            .buttonStyle(.plain)
            .disabled(engine.selectedCount == 0)
            .confirmationDialog(
                "Clear \(engine.selectedCount) privacy traces?",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Now", role: .destructive) {
                    let cleared = engine.clearSelected()
                    if cleared > 0 {
                        scanEngine.recordFreed(bytes: cleared, description: "Privacy trace cleanup")
                    }
                    resultMessage = "Cleared \(ByteCountFormatter.string(fromByteCount: cleared, countStyle: .file)) of privacy traces."
                    showResult = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete selected browser history, cookies, caches, and other privacy-sensitive data.")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Protection Group Row
struct ProtGroupRow: View {
    let group: ProtectionGroup
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? group.gradient : AnyShapeStyle(Color.clear))
                        .frame(width: 28, height: 28)
                    Image(systemName: group.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    Text(group.isScanning ? "Scanning…" :
                         group.items.isEmpty ? "Clean" :
                         ByteCountFormatter.string(fromByteCount: group.totalSize, countStyle: .file))
                        .font(.system(size: 10))
                        .foregroundColor(group.items.isEmpty ? AppTheme.success : .secondary)
                }
                Spacer()
                if group.totalSize > 0 {
                    Text("\(group.items.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "2C5364").cornerRadius(4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: "2C5364").opacity(0.08) : (hovered ? Color.gray.opacity(0.06) : Color.clear))
            )
            .shadow(color: hovered ? Color.black.opacity(0.12) : .clear, radius: hovered ? 8 : 0, y: 3)
            .scaleEffect(hovered ? 1.01 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }
}

// MARK: - Protection Item Row
struct ProtItemRow: View {
    let item: ProtectionItem
    let onToggle: () -> Void
    @State private var hovered = false

    var riskColor: Color {
        switch item.risk {
        case .low:    return AppTheme.success
        case .medium: return AppTheme.warning
        case .high:   return AppTheme.danger
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(item.isSelected ? AppTheme.accent : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(item.risk.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(riskColor.opacity(0.8).cornerRadius(3))
                }
                Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(item.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.sizeFormatted)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(item.isSelected ? .primary : .secondary)
                if hovered {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                    } label: {
                        Text("Reveal")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(hovered ? Color.gray.opacity(0.04) : Color.clear)
        .shadow(color: hovered ? Color.black.opacity(0.10) : .clear, radius: hovered ? 8 : 0, y: 3)
        .scaleEffect(hovered ? 1.005 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onToggle() }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }
}

// MARK: - Protection Engine
@MainActor
class ProtectionEngine: ObservableObject {
    @Published var groups: [ProtectionGroup] = []
    @Published var isScanning = false
    @Published var hasScanned = false

    var totalSize: Int64 { groups.flatMap(\.items).reduce(0) { $0 + $1.size } }
    var selectedCount: Int { groups.flatMap(\.items).filter(\.isSelected).count }
    var selectedSize: Int64 { groups.flatMap(\.items).filter(\.isSelected).reduce(0) { $0 + $1.size } }

    private let fm = FileManager.default
    private var home: String { fm.homeDirectoryForCurrentUser.path }

    func scanAll() {
        isScanning = true
        groups = ProtectionGroup.Kind.allCases.map { kind in
            ProtectionGroup(kind: kind, items: [], isScanning: true)
        }

        Task {
            await withTaskGroup(of: (ProtectionGroup.Kind, [ProtectionItem]).self) { tg in
                for kind in ProtectionGroup.Kind.allCases {
                    tg.addTask { [home] in
                        let items = ProtectionEngine.scanTraces(kind: kind, home: home)
                        return (kind, items)
                    }
                }

                for await (kind, items) in tg {
                    if let idx = groups.firstIndex(where: { $0.kind == kind }) {
                        groups[idx].items = items
                        groups[idx].isScanning = false
                    }
                }
            }
            isScanning = false
        }
    }

    func toggleItem(kind: ProtectionGroup.Kind, itemId: UUID) {
        guard let gi = groups.firstIndex(where: { $0.kind == kind }),
              let ii = groups[gi].items.firstIndex(where: { $0.id == itemId }) else { return }
        groups[gi].items[ii].isSelected.toggle()
    }

    func toggleAllInGroup(_ kind: ProtectionGroup.Kind) {
        guard let gi = groups.firstIndex(where: { $0.kind == kind }) else { return }
        let allSelected = groups[gi].items.allSatisfy(\.isSelected)
        for ii in groups[gi].items.indices {
            groups[gi].items[ii].isSelected = !allSelected
        }
    }

    func clearSelected() -> Int64 {
        var total: Int64 = 0
        for gi in groups.indices {
            for item in groups[gi].items where item.isSelected {
                do {
                    try fm.removeItem(atPath: item.path)
                    total += item.size
                } catch {}
            }
        }
        return total
    }

    // MARK: - Trace Scanning
    nonisolated static func scanTraces(kind: ProtectionGroup.Kind, home: String) -> [ProtectionItem] {
        switch kind {
        case .safari:    return scanSafari(home: home)
        case .chrome:    return scanChrome(home: home)
        case .firefox:   return scanFirefox(home: home)
        case .brave:     return scanBrave(home: home)
        case .edge:      return scanEdge(home: home)
        case .arc:       return scanArc(home: home)
        case .mail:      return scanMailData(home: home)
        case .photos:    return scanPhotoJunk(home: home)
        case .privacy:   return scanPrivacyData(home: home)
        case .system:    return scanSystemTraces(home: home)
        case .crashes:   return scanCrashReports(home: home)
        }
    }

    // MARK: - Safari
    nonisolated static func scanSafari(home: String) -> [ProtectionItem] {
        let base = "\(home)/Library/Safari"
        let caches = "\(home)/Library/Caches/com.apple.Safari"
        return scanPaths([
            (name: "Safari History", path: "\(base)/History.db", desc: "Browsing history database", risk: .high),
            (name: "Safari History (Shm)", path: "\(base)/History.db-shm", desc: "History DB shared memory", risk: .high),
            (name: "Safari History (Wal)", path: "\(base)/History.db-wal", desc: "History DB write-ahead log", risk: .high),
            (name: "Safari LocalStorage", path: "\(base)/LocalStorage", desc: "Website local storage data", risk: .medium),
            (name: "Safari Databases", path: "\(base)/Databases", desc: "Website database storage", risk: .medium),
            (name: "Safari Cache", path: caches, desc: "Cached web content", risk: .low),
            (name: "Safari Downloads", path: "\(base)/Downloads.plist", desc: "Recent downloads list", risk: .medium),
            (name: "Safari Extensions (Cache)", path: "\(home)/Library/Caches/com.apple.Safari.SafeBrowsing", desc: "Safe browsing cache", risk: .low),
        ], icon: "safari")
    }

    // MARK: - Chrome
    nonisolated static func scanChrome(home: String) -> [ProtectionItem] {
        let base = "\(home)/Library/Application Support/Google/Chrome/Default"
        let caches = "\(home)/Library/Caches/Google/Chrome/Default"
        return scanPaths([
            (name: "Chrome History", path: "\(base)/History", desc: "Browsing history and visits", risk: .high),
            (name: "Chrome Cookies", path: "\(base)/Cookies", desc: "Website cookies", risk: .high),
            (name: "Chrome Cache", path: caches, desc: "Cached web content and media", risk: .low),
            (name: "Chrome Sessions", path: "\(base)/Sessions", desc: "Open tab sessions", risk: .medium),
            (name: "Chrome Top Sites", path: "\(base)/Top Sites", desc: "Most visited sites data", risk: .medium),
            (name: "Chrome Login Data", path: "\(base)/Login Data", desc: "Saved passwords (encrypted)", risk: .high),
            (name: "Chrome Web Data", path: "\(base)/Web Data", desc: "Autofill and form data", risk: .high),
            (name: "Chrome Favicons", path: "\(base)/Favicons", desc: "Saved website icons", risk: .low),
            (name: "Chrome Media History", path: "\(base)/Media History", desc: "Media playback history", risk: .medium),
            (name: "Chrome Network Action", path: "\(base)/Network Action Predictor", desc: "URL prediction data", risk: .medium),
        ], icon: "globe")
    }

    // MARK: - Firefox
    nonisolated static func scanFirefox(home: String) -> [ProtectionItem] {
        let profiles = "\(home)/Library/Application Support/Firefox/Profiles"
        let fm = FileManager.default
        guard fm.fileExists(atPath: profiles),
              let dirs = try? fm.contentsOfDirectory(atPath: profiles) else { return [] }

        var items: [ProtectionItem] = []
        for dir in dirs {
            let profilePath = "\(profiles)/\(dir)"
            let profileItems = scanPaths([
                (name: "Firefox History", path: "\(profilePath)/places.sqlite", desc: "Bookmarks & browsing history", risk: .high),
                (name: "Firefox Cookies", path: "\(profilePath)/cookies.sqlite", desc: "Website cookies", risk: .high),
                (name: "Firefox Cache", path: "\(profilePath)/cache2", desc: "Cached web content", risk: .low),
                (name: "Firefox Sessions", path: "\(profilePath)/sessionstore-backups", desc: "Session restore data", risk: .medium),
                (name: "Firefox Form History", path: "\(profilePath)/formhistory.sqlite", desc: "Autofill form data", risk: .high),
                (name: "Firefox Storage", path: "\(profilePath)/storage", desc: "Website local storage", risk: .medium),
            ], icon: "flame")
            items.append(contentsOf: profileItems)
        }
        return items
    }

    // MARK: - Brave
    nonisolated static func scanBrave(home: String) -> [ProtectionItem] {
        let base = "\(home)/Library/Application Support/BraveSoftware/Brave-Browser/Default"
        let caches = "\(home)/Library/Caches/BraveSoftware/Brave-Browser/Default"
        return scanPaths([
            (name: "Brave History", path: "\(base)/History", desc: "Browsing history", risk: .high),
            (name: "Brave Cookies", path: "\(base)/Cookies", desc: "Website cookies", risk: .high),
            (name: "Brave Cache", path: caches, desc: "Cached web content", risk: .low),
            (name: "Brave Sessions", path: "\(base)/Sessions", desc: "Tab sessions", risk: .medium),
            (name: "Brave Login Data", path: "\(base)/Login Data", desc: "Saved passwords", risk: .high),
        ], icon: "shield")
    }

    // MARK: - Edge
    nonisolated static func scanEdge(home: String) -> [ProtectionItem] {
        let base = "\(home)/Library/Application Support/Microsoft Edge/Default"
        let caches = "\(home)/Library/Caches/Microsoft Edge/Default"
        return scanPaths([
            (name: "Edge History", path: "\(base)/History", desc: "Browsing history", risk: .high),
            (name: "Edge Cookies", path: "\(base)/Cookies", desc: "Website cookies", risk: .high),
            (name: "Edge Cache", path: caches, desc: "Cached web content", risk: .low),
            (name: "Edge Sessions", path: "\(base)/Sessions", desc: "Tab sessions", risk: .medium),
            (name: "Edge Login Data", path: "\(base)/Login Data", desc: "Saved passwords", risk: .high),
        ], icon: "globe.americas")
    }

    // MARK: - Arc
    nonisolated static func scanArc(home: String) -> [ProtectionItem] {
        let base = "\(home)/Library/Application Support/Arc/User Data/Default"
        let caches = "\(home)/Library/Caches/company.thebrowser.Browser"
        return scanPaths([
            (name: "Arc History", path: "\(base)/History", desc: "Browsing history", risk: .high),
            (name: "Arc Cookies", path: "\(base)/Cookies", desc: "Website cookies", risk: .high),
            (name: "Arc Cache", path: caches, desc: "Cached web content", risk: .low),
            (name: "Arc Sessions", path: "\(base)/Sessions", desc: "Tab sessions", risk: .medium),
        ], icon: "circle.hexagongrid")
    }

    // MARK: - Privacy Data
    nonisolated static func scanPrivacyData(home: String) -> [ProtectionItem] {
        return scanPaths([
            (name: "Recent Items", path: "\(home)/Library/Application Support/com.apple.sharedfilelist", desc: "Recently opened files, apps, and servers", risk: .medium),
            (name: "Cookies", path: "\(home)/Library/Cookies", desc: "HTTP cookies from all applications", risk: .high),
            (name: "Saved App State", path: "\(home)/Library/Saved Application State", desc: "Window positions and state from apps", risk: .low),
            (name: "Spotlight Shortcuts", path: "\(home)/Library/Application Support/com.apple.spotlight.Shortcuts", desc: "Spotlight search shortcuts history", risk: .low),
            (name: "Recently Used", path: "\(home)/Library/RecentServers", desc: "Recently connected servers", risk: .medium),
        ], icon: "hand.raised.fill")
    }

    // MARK: - System Traces
    nonisolated static func scanSystemTraces(home: String) -> [ProtectionItem] {
        return scanPaths([
            (name: "Recent Applications", path: "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments", desc: "Recently opened app records", risk: .medium),
            (name: "Recent Documents", path: "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments.sfl2", desc: "Recently opened files", risk: .medium),
            (name: "Recent Servers", path: "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentServers.sfl2", desc: "Recently connected servers", risk: .medium),
            (name: "Quarantine Events", path: "\(home)/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2", desc: "Downloaded file quarantine log", risk: .high),
            (name: "CUPS Print Jobs", path: "\(home)/Library/Logs/CUPS", desc: "Print job history logs", risk: .low),
        ], icon: "desktopcomputer")
    }

    // MARK: - Crash Reports
    nonisolated static func scanCrashReports(home: String) -> [ProtectionItem] {
        return scanPaths([
            (name: "User Crash Reports", path: "\(home)/Library/Logs/DiagnosticReports", desc: "Application crash & hang reports", risk: .low),
            (name: "System Crash Reports", path: "/Library/Logs/DiagnosticReports", desc: "System-wide diagnostic reports", risk: .low),
            (name: "CoreAnalytics", path: "\(home)/Library/Logs/CoreAnalytics", desc: "macOS analytics & telemetry data", risk: .medium),
        ], icon: "exclamationmark.triangle.fill")
    }

    // MARK: - Mail Attachments
    nonisolated static func scanMailData(home: String) -> [ProtectionItem] {
        return scanPaths([
            (name: "Mail Downloads", path: "\(home)/Library/Mail Downloads", desc: "Downloaded email attachments", risk: .medium),
            (name: "Mail Container Data", path: "\(home)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads", desc: "Sandboxed Mail attachment downloads", risk: .medium),
            (name: "Mail Envelope Index", path: "\(home)/Library/Mail/V10/MailData/Envelope Index", desc: "Mail message index database", risk: .high),
            (name: "Mail Caches", path: "\(home)/Library/Caches/com.apple.mail", desc: "Mail application caches", risk: .low),
            (name: "Mail Bundles", path: "\(home)/Library/Mail/Bundles", desc: "Mail plugin bundles", risk: .low),
        ], icon: "envelope.fill")
    }

    // MARK: - Photo Junk
    nonisolated static func scanPhotoJunk(home: String) -> [ProtectionItem] {
        let photosLib = "\(home)/Pictures/Photos Library.photoslibrary"
        return scanPaths([
            (name: "Photo Derivatives", path: "\(photosLib)/resources/derivatives", desc: "Generated thumbnails and previews", risk: .low),
            (name: "Photo Caches", path: "\(photosLib)/resources/cpl", desc: "Cloud Photo Library caches", risk: .low),
            (name: "Photo Analysis", path: "\(photosLib)/resources/analysis", desc: "Face recognition and scene analysis data", risk: .low),
            (name: "Photos App Cache", path: "\(home)/Library/Containers/com.apple.Photos/Data/Library/Caches", desc: "Photos application caches", risk: .low),
            (name: "Photo Booth Pictures", path: "\(home)/Pictures/Photo Booth Library", desc: "Photo Booth captured images", risk: .medium),
        ], icon: "photo.fill")
    }

    // MARK: - Helper
    nonisolated static func scanPaths(_ defs: [(name: String, path: String, desc: String, risk: ProtectionItem.Risk)], icon: String) -> [ProtectionItem] {
        let fm = FileManager.default
        var items: [ProtectionItem] = []
        for def in defs {
            guard fm.fileExists(atPath: def.path) else { continue }
            let size = ScanEngine.calcSize(path: def.path)
            guard size > 0 else { continue }
            items.append(ProtectionItem(
                name: def.name,
                path: def.path,
                size: size,
                icon: icon,
                description: def.desc,
                risk: def.risk,
                isSelected: def.risk == .low || def.risk == .medium
            ))
        }
        return items.sorted { $0.size > $1.size }
    }
}

// MARK: - Protection Group
struct ProtectionGroup: Identifiable {
    let id = UUID()
    let kind: Kind
    var items: [ProtectionItem] = []
    var isScanning = true

    enum Kind: String, CaseIterable, Identifiable {
        case safari   = "Safari"
        case chrome   = "Chrome"
        case firefox  = "Firefox"
        case brave    = "Brave"
        case edge     = "Edge"
        case arc      = "Arc"
        case mail     = "Mail Attachments"
        case photos   = "Photo Junk"
        case privacy  = "Privacy Data"
        case system   = "System Traces"
        case crashes  = "Crash Reports"

        var id: String { rawValue }
    }

    var name: String { kind.rawValue }

    var icon: String {
        switch kind {
        case .safari:   return "safari"
        case .chrome:   return "globe"
        case .firefox:  return "flame"
        case .brave:    return "shield"
        case .edge:     return "globe.americas"
        case .arc:      return "circle.hexagongrid"
        case .mail:     return "envelope.fill"
        case .photos:   return "photo.fill"
        case .privacy:  return "hand.raised.fill"
        case .system:   return "desktopcomputer"
        case .crashes:  return "exclamationmark.triangle.fill"
        }
    }

    var gradientColors: [Color] {
        switch kind {
        case .safari:   return [Color(hex: "007AFF"), Color(hex: "5AC8FA")]
        case .chrome:   return [Color(hex: "4285F4"), Color(hex: "EA4335")]
        case .firefox:  return [Color(hex: "FF7139"), Color(hex: "FF3E5F")]
        case .brave:    return [Color(hex: "FB542B"), Color(hex: "343546")]
        case .edge:     return [Color(hex: "0078D7"), Color(hex: "00BCF2")]
        case .arc:      return [Color(hex: "FC5C7D"), Color(hex: "6A82FB")]
        case .mail:     return [Color(hex: "1A73E8"), Color(hex: "4FC3F7")]
        case .photos:   return [Color(hex: "00C853"), Color(hex: "64DD17")]
        case .privacy:  return [Color(hex: "FF416C"), Color(hex: "FF4B2B")]
        case .system:   return [Color(hex: "0F2027"), Color(hex: "203A43")]
        case .crashes:  return [Color(hex: "FF5858"), Color(hex: "D0021B")]
        }
    }

    var gradient: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var allSelected: Bool { !items.isEmpty && items.allSatisfy(\.isSelected) }
}

// MARK: - Protection Item
struct ProtectionItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let icon: String
    let description: String
    let risk: Risk
    var isSelected: Bool

    enum Risk: String {
        case low    = "Low"
        case medium = "Medium"
        case high   = "High"
    }

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
