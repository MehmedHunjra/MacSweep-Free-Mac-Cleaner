import SwiftUI
import AppKit

// MARK: - Performance Manager View
struct PerformanceManagerView: View {
    @ObservedObject var engine: PerformanceEngine
    @ObservedObject var memoryEngine: MemoryEngine
    
    @State private var selectedGroup: PerformanceGroup.Kind? = .loginItems
    @State private var showResult = false
    @State private var resultMessage = ""

    @State private var selectedTab = 0  // 0 = Performance, 1 = Maintenance, 2 = Memory

    var body: some View {
        VStack(spacing: 0) {
            if !engine.isScanning && !engine.hasScanned && selectedTab == 0 {
                landingScreen
            } else if selectedTab == 1 {
                // Maintenance tab
                MaintenanceView()
            } else if selectedTab == 2 {
                // Memory Optimizer tab
                MemoryOptimizerView(engine: memoryEngine)
            } else {
                perfHeader
                Divider()
                HStack(spacing: 0) {
                    perfGroupList
                    Divider()
                    if let kind = selectedGroup,
                       let group = engine.groups.first(where: { $0.kind == kind }) {
                        perfItemList(group: group)
                    } else {
                        emptyState
                    }
                }
                Divider()
                perfFooter
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Action Complete", isPresented: $showResult) {
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

                // 3D Glass Icon for Performance
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(colors: [Color(hex: "F7971E").opacity(0.6), Color(hex: "FFD200").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "F7971E").opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Image(systemName: "bolt.shield")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "FFF9C4")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.bottom, 28)

                Text("Optimize & Maintain")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Manage login items, launch agents, and run\nsystem maintenance tasks to keep your Mac fast.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 48)

                HStack(spacing: 12) {
                    ToolPrimaryActionButton(
                        title: "Scan Performance",
                        colors: [Color(hex: "F7971E"), Color(hex: "FFD200")],
                        icon: "sparkles"
                    ) {
                        selectedTab = 0
                        engine.hasScanned = true
                        engine.scanAll()
                    }

                    ToolPrimaryActionButton(
                        title: "Run Maintenance",
                        colors: [Color(hex: "3A1C71"), Color(hex: "D76D77")],
                        icon: "wrench.and.screwdriver"
                    ) {
                        selectedTab = 1
                    }

                    ToolPrimaryActionButton(
                        title: "Memory Optimizer",
                        colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                        icon: "memorychip"
                    ) {
                        selectedTab = 2
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Header
    var perfHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color(hex: "F7971E"), Color(hex: "FFD200")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: "bolt.shield")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Optimize & Maintain")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Login items, launch agents & system maintenance")
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
                    Text("\(engine.totalItemCount) items")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "F7971E"))
                    Text("found on this Mac")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Group List
    var perfGroupList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(engine.groups) { group in
                    PerfGroupRow(
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
    func perfItemList(group: PerformanceGroup) -> some View {
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
                    Text("\(group.items.count) items found")
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
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.success.opacity(0.6))
                    Text("No \(group.name.lowercased()) found")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("Your system is clean in this category.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(engine.groups.first(where: { $0.kind == group.kind })?.items ?? []) { item in
                            PerfItemRow(item: item,
                                       onToggle: { engine.toggleItem(kind: group.kind, itemId: item.id) },
                                       onDisable: { toggleAgent(item) },
                                       onRemove: { removeAgent(item) },
                                       onReveal: { revealAgent(item) })
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
            Image(systemName: "speedometer")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Select a category to view items")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer
    var perfFooter: some View {
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

            Button {
                selectedTab = 1
            } label: {
                Label("Maintenance", systemImage: "wrench.and.screwdriver")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(hex: "3A1C71").opacity(0.15))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button {
                selectedTab = 2
            } label: {
                Label("Memory", systemImage: "memorychip")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(hex: "667EEA").opacity(0.15))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            if !engine.isScanning {
                Text("\(engine.selectedCount) items selected")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Button {
                removeSelectedAgents()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("Remove Selected")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(engine.selectedCount == 0
                              ? AnyShapeStyle(Color.gray)
                              : AnyShapeStyle(LinearGradient(colors: [Color(hex: "F7971E"), Color(hex: "FFD200")],
                                                             startPoint: .leading, endPoint: .trailing)))
                )
            }
            .buttonStyle(.plain)
            .disabled(engine.selectedCount == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Actions
    private func toggleAgent(_ item: PerformanceItem) {
        let success = engine.toggleAgentEnabled(item)
        if !success {
            resultMessage = "Cannot toggle \(item.name). System-level items require administrator privileges.\n\nGo to System Settings → General → Login Items to manage."
            showResult = true
        }
    }

    private func removeAgent(_ item: PerformanceItem) {
        let success = engine.removeAgent(item)
        if success {
            resultMessage = "Removed \(item.name) successfully."
        } else {
            resultMessage = "Cannot remove \(item.name). It may be a system item requiring admin access.\n\nGo to System Settings → General → Login Items to manage."
        }
        showResult = true
    }

    private func revealAgent(_ item: PerformanceItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
    }

    private func removeSelectedAgents() {
        var removed = 0
        var failed = 0
        for group in engine.groups {
            for item in group.items where item.isSelected {
                if engine.removeAgent(item) {
                    removed += 1
                } else {
                    failed += 1
                }
            }
        }
        resultMessage = "Removed \(removed) item(s)." + (failed > 0 ? " \(failed) item(s) could not be removed (system-level)." : "")
        showResult = true
    }
}

// MARK: - Performance Group Row
struct PerfGroupRow: View {
    let group: PerformanceGroup
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
                         "\(group.items.count) items")
                        .font(.system(size: 10))
                        .foregroundColor(group.items.isEmpty ? AppTheme.success : .secondary)
                }
                Spacer()
                if !group.items.isEmpty {
                    Text("\(group.items.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "F7971E").cornerRadius(4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: "F7971E").opacity(0.08) : (hovered ? Color.gray.opacity(0.06) : Color.clear))
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

// MARK: - Performance Item Row
struct PerfItemRow: View {
    let item: PerformanceItem
    let onToggle: () -> Void
    let onDisable: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void
    @State private var hovered = false

    var statusColor: Color {
        switch item.status {
        case .enabled:  return AppTheme.success
        case .disabled: return AppTheme.warning
        case .unknown:  return .secondary
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
                    Text(item.status.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(statusColor.opacity(0.8).cornerRadius(3))
                    if !item.canModify {
                        Text("System")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.6).cornerRadius(3))
                    }
                }
                Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if !item.label.isEmpty {
                    Text("Label: \(item.label)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()

            if hovered {
                HStack(spacing: 6) {
                    if item.canModify {
                        Button(action: onDisable) {
                            Text(item.status == .enabled ? "Disable" : "Enable")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.accent.opacity(0.1).cornerRadius(4))
                        }
                        .buttonStyle(.plain)

                        Button(action: onRemove) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.danger)
                                .padding(4)
                                .background(AppTheme.danger.opacity(0.1).cornerRadius(4))
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: onReveal) {
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
        .animation(.easeOut(duration: 0.12), value: hovered)
    }
}

// MARK: - Performance Engine
@MainActor
class PerformanceEngine: ObservableObject {
    @Published var groups: [PerformanceGroup] = []
    @Published var isScanning = false
    @Published var hasScanned = false

    var totalItemCount: Int { groups.flatMap(\.items).count }
    var selectedCount: Int { groups.flatMap(\.items).filter(\.isSelected).count }

    private let fm = FileManager.default
    private var home: String { fm.homeDirectoryForCurrentUser.path }

    func scanAll() {
        isScanning = true
        groups = PerformanceGroup.Kind.allCases.map { kind in
            PerformanceGroup(kind: kind, items: [], isScanning: true)
        }

        Task {
            // Scan user agents
            let userAgents = await scanLaunchItems(
                directory: "\(home)/Library/LaunchAgents",
                canModify: true
            )
            await MainActor.run {
                if let idx = groups.firstIndex(where: { $0.kind == .loginItems }) {
                    groups[idx].items = userAgents
                    groups[idx].isScanning = false
                }
            }

            // Scan system agents
            let systemAgents = await scanLaunchItems(
                directory: "/Library/LaunchAgents",
                canModify: false
            )
            await MainActor.run {
                if let idx = groups.firstIndex(where: { $0.kind == .systemAgents }) {
                    groups[idx].items = systemAgents
                    groups[idx].isScanning = false
                }
            }

            // Scan launch daemons
            let daemons = await scanLaunchItems(
                directory: "/Library/LaunchDaemons",
                canModify: false
            )
            await MainActor.run {
                if let idx = groups.firstIndex(where: { $0.kind == .launchDaemons }) {
                    groups[idx].items = daemons
                    groups[idx].isScanning = false
                }
            }

            await MainActor.run { isScanning = false }
        }
    }

    func toggleItem(kind: PerformanceGroup.Kind, itemId: UUID) {
        guard let gi = groups.firstIndex(where: { $0.kind == kind }),
              let ii = groups[gi].items.firstIndex(where: { $0.id == itemId }) else { return }
        groups[gi].items[ii].isSelected.toggle()
    }

    func toggleAllInGroup(_ kind: PerformanceGroup.Kind) {
        guard let gi = groups.firstIndex(where: { $0.kind == kind }) else { return }
        let allSelected = groups[gi].items.allSatisfy(\.isSelected)
        for ii in groups[gi].items.indices {
            groups[gi].items[ii].isSelected = !allSelected
        }
    }

    func toggleAgentEnabled(_ item: PerformanceItem) -> Bool {
        guard item.canModify else { return false }
        let action = item.status == .enabled ? "bootout" : "bootstrap"
        let domain = "gui/\(getuid())"
        let task = Process()
        task.launchPath = "/bin/launchctl"
        if action == "bootout" {
            task.arguments = [action, domain, item.path]
        } else {
            task.arguments = [action, domain, item.path]
        }
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    func removeAgent(_ item: PerformanceItem) -> Bool {
        guard item.canModify else { return false }
        // First try to unload if enabled
        if item.status == .enabled {
            _ = toggleAgentEnabled(item)
        }
        do {
            try fm.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Scan Helpers
    private func scanLaunchItems(directory: String, canModify: Bool) async -> [PerformanceItem] {
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            guard fm.fileExists(atPath: directory) else { return [] }
            guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

            var items: [PerformanceItem] = []
            for file in contents where file.hasSuffix(".plist") {
                let path = "\(directory)/\(file)"
                guard let data = fm.contents(atPath: path),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                else { continue }

                let label = plist["Label"] as? String ?? file.replacingOccurrences(of: ".plist", with: "")
                let program = plist["Program"] as? String
                    ?? (plist["ProgramArguments"] as? [String])?.first
                    ?? ""
                let disabled = plist["Disabled"] as? Bool ?? false
                let keepAlive = plist["KeepAlive"] as? Bool ?? false

                let displayName = Self.friendlyName(from: label)
                let icon = keepAlive ? "arrow.clockwise.circle.fill" : "bolt.fill"

                items.append(PerformanceItem(
                    name: displayName,
                    label: label,
                    path: path,
                    program: program,
                    icon: icon,
                    status: disabled ? .disabled : .enabled,
                    canModify: canModify,
                    isSelected: false
                ))
            }
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value
    }

    nonisolated static func friendlyName(from label: String) -> String {
        // Convert "com.apple.something" → "Apple Something"
        let parts = label.split(separator: ".")
        if parts.count >= 3 {
            let meaningful = parts.dropFirst(2).joined(separator: " ")
            let vendor = String(parts[1]).capitalized
            return "\(vendor) — \(meaningful.capitalized)"
        }
        return label
    }
}

// MARK: - Performance Group
struct PerformanceGroup: Identifiable {
    let id = UUID()
    let kind: Kind
    var items: [PerformanceItem] = []
    var isScanning = true

    enum Kind: String, CaseIterable, Identifiable {
        case loginItems    = "Login Items"
        case systemAgents  = "System Agents"
        case launchDaemons = "Launch Daemons"

        var id: String { rawValue }
    }

    var name: String { kind.rawValue }

    var icon: String {
        switch kind {
        case .loginItems:    return "person.fill.checkmark"
        case .systemAgents:  return "gearshape.2.fill"
        case .launchDaemons: return "server.rack"
        }
    }

    var gradientColors: [Color] {
        switch kind {
        case .loginItems:    return [Color(hex: "F7971E"), Color(hex: "FFD200")]
        case .systemAgents:  return [Color(hex: "667EEA"), Color(hex: "764BA2")]
        case .launchDaemons: return [Color(hex: "E94560"), Color(hex: "0F2027")]
        }
    }

    var gradient: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    var allSelected: Bool { !items.isEmpty && items.allSatisfy(\.isSelected) }
}

// MARK: - Performance Item
struct PerformanceItem: Identifiable {
    let id = UUID()
    let name: String
    let label: String
    let path: String
    let program: String
    let icon: String
    let status: Status
    let canModify: Bool
    var isSelected: Bool

    enum Status: String {
        case enabled  = "Enabled"
        case disabled = "Disabled"
        case unknown  = "Unknown"
    }
}
