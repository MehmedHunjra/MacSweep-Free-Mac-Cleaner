import SwiftUI
import AppKit

// MARK: - Dev Cleaner View
struct DevCleanerView: View {
    @ObservedObject var devEngine: DevCleanEngine
    @State private var selectedGroup: DevGroup? = nil
    @State private var isCleaning = false
    @State private var cleanDone = false
    @State private var cleanedBytes: Int64 = 0
    @State private var showCleanSheet = false
    @State private var showResultSheet = false
    @State private var showFDAAlert = false
    @State private var showNodeModulesSheet = false
    @State private var showBuildArtifactsSheet = false
    @State private var showCLIToolsSheet = false
    @EnvironmentObject var navManager: NavigationManager

    var body: some View {
        VStack(spacing: 0) {
            if !devEngine.isScanning && !devEngine.hasScanned {
                VStack(spacing: 0) {
                    navHeader(isLanding: true)
                    landingScreen
                }
            } else if devEngine.isScanning {
                ToolScanningView(
                    section: .devCleaner,
                    scanningTitle: "Scanning Developer Areas...",
                    currentPath: .constant("Looking for node_modules, build artifacts, and caches..."),
                    onStop: { devEngine.cancelScan() }
                )
            } else {
                VStack(spacing: 0) {
                    navHeader(isLanding: false)
                    devHeader
                    Divider()
                    devQuickActions
                    Divider()
                    HStack(spacing: 0) {
                        devGroupList
                        Rectangle().fill(Color.gray.opacity(0.15)).frame(width: 1)
                        if let group = selectedGroup ?? devEngine.groups.first {
                            devItemList(group: group)
                        } else {
                            emptyState
                        }
                    }
                    Divider()
                    devFooter
                }
            }
        }
        .sheet(isPresented: $showNodeModulesSheet) {
            DeepScanResultSheet(
                title: "node_modules Found",
                items: devEngine.nodeModulesResults,
                isScanning: devEngine.isDeepScanning,
                onClean: { devEngine.cleanDeepScanResults(type: .nodeModules) },
                onDismiss: { showNodeModulesSheet = false }
            )
        }
        .sheet(isPresented: $showBuildArtifactsSheet) {
            DeepScanResultSheet(
                title: "Build Artifacts Found",
                items: devEngine.buildArtifactResults,
                isScanning: devEngine.isDeepScanning,
                onClean: { devEngine.cleanDeepScanResults(type: .buildArtifacts) },
                onDismiss: { showBuildArtifactsSheet = false }
            )
        }
        .sheet(isPresented: $showCLIToolsSheet) {
            CLIToolsSheet(engine: devEngine, onDismiss: { showCLIToolsSheet = false })
        }
    }

    // MARK: - Landing
    private var landingScreen: some View {
        ZStack {
            // DS bg with section radial glow
            DS.bg
                .ignoresSafeArea()
            RadialGradient(
                colors: [SectionTheme.theme(for: .devCleaner).glow.opacity(0.10), .clear],
                center: .center, startRadius: 0, endRadius: 350
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 3D Glass Icon for Dev Cleanup
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(SectionTheme.theme(for: .devCleaner).linearGradient)
                        .frame(width: 120, height: 120)
                        .shadow(color: SectionTheme.theme(for: .devCleaner).glow.opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(RadialGradient(colors: [Color.white.opacity(0.2), .clear], center: .init(x: 0.3, y: 0.25), startRadius: 0, endRadius: 80))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.white, SectionTheme.theme(for: .devCleaner).glow], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.bottom, 28)

                Text("Dev Cleaner")
                    .font(MSFont.heroTitle)
                    .foregroundColor(DS.textPrimary)
                    .padding(.bottom, 8)

                Text("Optimize your developer machine by cleaning IDE caches,\nbuild artifacts, and redundant SDK symbol files.")
                    .font(MSFont.body)
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 48)

                ToolPrimaryActionButton(
                    title: "Scan",
                    colors: SectionTheme.theme(for: .devCleaner).gradient,
                    icon: "sparkles"
                ) {
                    devEngine.hasScanned = true
                    devEngine.scanAll()
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Navigation Header
    func navHeader(isLanding: Bool) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Button {
                    if !isLanding {
                        devEngine.hasScanned = false
                    } else {
                        navManager.goBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor((isLanding && !navManager.canGoBack) ? DS.textMuted.opacity(0.5) : DS.textSecondary)
                        .frame(width: 32, height: 32)
                        .background((isLanding && !navManager.canGoBack) ? DS.bgElevated.opacity(0.5) : DS.bgElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isLanding && !navManager.canGoBack)

                Button {
                    navManager.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(navManager.canGoForward ? DS.textSecondary : DS.textMuted.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .background(navManager.canGoForward ? DS.bgElevated : DS.bgElevated.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!navManager.canGoForward)
            }

            if !isLanding {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SectionTheme.theme(for: .devCleaner).linearGradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Developer Cleaner")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                    Text("IDE caches, build artifacts & SDK symbols")
                        .font(.system(size: 11))
                        .foregroundColor(DS.textMuted)
                }
                
                Spacer()
                
                Button {
                    devEngine.scanAll()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Rescan")
                    }
                    .font(MSFont.caption)
                    .foregroundColor(DS.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DS.bgElevated)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Header
    var devHeader: some View {
        HStack(spacing: 0) {
            // Header bar removed here as it's now in navHeader
        }
    }

    // MARK: - Quick Actions Bar
    var devQuickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Select All Safe
                devChip("Select Safe", icon: "checkmark.circle.fill", color: DS.success) { devEngine.selectAllSafe() }
                devChip("Deselect All", icon: "xmark.circle", color: DS.textSecondary) { devEngine.deselectAll() }

                Rectangle().fill(DS.borderSubtle).frame(width: 1, height: 18)

                devChip("node_modules", icon: "folder.fill.badge.questionmark", color: Color(hex: "CB3837")) {
                    showNodeModulesSheet = true
                    devEngine.deepScanNodeModules()
                }
                devChip("Build Artifacts", icon: "hammer.circle.fill", color: Color(hex: "3A70E0")) {
                    showBuildArtifactsSheet = true
                    devEngine.deepScanBuildArtifacts()
                }
                devChip("CLI Tools", icon: "wrench.and.screwdriver", color: SectionTheme.theme(for: .devCleaner).glow) {
                    showCLIToolsSheet = true
                    devEngine.scanCLITools()
                }
                devChip("Terminal", icon: "terminal", color: DS.textSecondary) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(DS.bgPanel)
    }

    // MARK: - Group List
    var devGroupList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(devEngine.groups) { group in
                    DevGroupRow(
                        group: group,
                        isSelected: (selectedGroup ?? devEngine.groups.first)?.id == group.id
                    ) {
                        selectedGroup = group
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .frame(width: 200)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Item List
    @ViewBuilder
    func devItemList(group: DevGroup) -> some View {
        VStack(spacing: 0) {
            // Group header
            HStack(spacing: 12) {
                if let appIcon = group.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .cornerRadius(8)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(group.gradient)
                            .frame(width: 36, height: 36)
                        Image(systemName: group.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.system(size: 16, weight: .bold))
                    Text("\(group.items.count) items • \(ByteCountFormatter.string(fromByteCount: group.totalSize, countStyle: .file)) found")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Reveal in Finder
                if group.totalSize > 0 {
                    Button {
                        if let first = group.items.first {
                            NSWorkspace.shared.selectFile(first.path, inFileViewerRootedAtPath: (first.path as NSString).deletingLastPathComponent)
                        }
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.gray.opacity(0.1).cornerRadius(6))
                    }.buttonStyle(.plain).help("Reveal in Finder")
                }
                // Select/Deselect all
                Button {
                    devEngine.toggleAllInGroup(group.id)
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
                    Text("Nothing to clean in \(group.name)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("All \(group.name) caches are already clean.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(devEngine.groups.first(where: { $0.id == group.id })?.items ?? []) { item in
                            DevItemRow(item: item) {
                                devEngine.toggleItem(groupId: group.id, itemId: item.id)
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
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(DS.textMuted)
            Text("Select a category to view items")
                .font(MSFont.body)
                .foregroundColor(DS.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.bg)
    }

    private func devChip(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer
    var devFooter: some View {
        HStack(spacing: 12) {
            Button {
                devEngine.scanAll()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Rescan")
                }
                .font(MSFont.caption)
                .foregroundColor(DS.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(DS.bgElevated)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            if !devEngine.isScanning {
                Text("\(devEngine.totalSelected) items selected")
                    .font(MSFont.caption)
                    .foregroundColor(DS.textMuted)
            }

            Button {
                showCleanSheet = true
            } label: {
                HStack(spacing: 8) {
                    if isCleaning {
                        ProgressView().scaleEffect(0.7).tint(.white)
                        Text("Cleaning...")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Clean \(ByteCountFormatter.string(fromByteCount: devEngine.totalSelectedSize, countStyle: .file))")
                    }
                }
                .font(MSFont.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(devEngine.totalSelected == 0
                              ? AnyShapeStyle(DS.textMuted)
                              : AnyShapeStyle(SectionTheme.theme(for: .devCleaner).linearGradient))
                )
            }
            .buttonStyle(.plain)
            .disabled(devEngine.totalSelected == 0 || isCleaning)
            .confirmationDialog(
                "Clean \(devEngine.totalSelected) items (\(ByteCountFormatter.string(fromByteCount: devEngine.totalSelectedSize, countStyle: .file)))?",
                isPresented: $showCleanSheet,
                titleVisibility: .visible
            ) {
                Button("Clean Now", role: .destructive) {
                    Task {
                        isCleaning = true
                        cleanedBytes = await devEngine.cleanSelected()
                        isCleaning = false
                        if cleanedBytes == 0 {
                            showFDAAlert = true
                        } else {
                            showResultSheet = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the selected caches and build artifacts. Xcode and other tools will regenerate what they need.")
            }
            .sheet(isPresented: $showResultSheet) {
                DevCleanResultSheet(cleanedBytes: cleanedBytes) {
                    showResultSheet = false
                }
            }
            .alert("Full Disk Access Required", isPresented: $showFDAAlert) {
                Button("Open System Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("MacSweep needs Full Disk Access to delete dev caches.\n\nGo to System Settings → Privacy & Security → Full Disk Access and enable MacSweep.")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Dev Group Row
struct DevGroupRow: View {
    let group: DevGroup
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if let appIcon = group.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .cornerRadius(6)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? group.gradient : AnyShapeStyle(Color.clear))
                            .frame(width: 28, height: 28)
                        Image(systemName: group.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    Text(group.isScanning ? "Scanning..." :
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
                        .background(AppTheme.accent.cornerRadius(4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AppTheme.accent.opacity(0.08) : (hovered ? Color.gray.opacity(0.06) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Dev Item Row
struct DevItemRow: View {
    let item: DevCleanItem
    let onToggle: () -> Void
    @State private var hovered = false

    var safetyColor: Color {
        switch item.safety {
        case .safe:    return AppTheme.success
        case .caution: return AppTheme.warning
        case .manual:  return AppTheme.danger
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(item.isSelected ? AppTheme.accent : .secondary)
            }
            .buttonStyle(.plain)

            // Icon
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20)

            // Name + path
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    // Safety badge
                    Text(item.safety.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(safetyColor.opacity(0.8).cornerRadius(3))
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

            // Size + reveal
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
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onToggle() }
    }
}

// MARK: - Dev Clean Result Sheet
struct DevCleanResultSheet: View {
    let cleanedBytes: Int64
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            // Animated checkmark
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "E94560"), Color(hex: "764BA2")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .scaleEffect(appeared ? 1 : 0.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(appeared ? 1 : 0)
            }

            VStack(spacing: 8) {
                Text("Dev Cleanup Complete!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(ByteCountFormatter.string(fromByteCount: cleanedBytes, countStyle: .file))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "E94560"), Color(hex: "764BA2")],
                                                   startPoint: .leading, endPoint: .trailing))
                Text("freed from IDE caches and build artifacts")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Button("Done") { onDismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 10)
                .background(LinearGradient(colors: [Color(hex: "E94560"), Color(hex: "764BA2")],
                                           startPoint: .leading, endPoint: .trailing))
                .cornerRadius(10)
                .buttonStyle(.plain)
        }
        .padding(40)
        .frame(width: 380)
        .onAppear {
            withAnimation(.spring(duration: 0.5)) { appeared = true }
        }
    }
}

// MARK: - Dev Clean Engine
@MainActor
class DevCleanEngine: ObservableObject {
    @Published var groups: [DevGroup] = []
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var isDeepScanning = false
    @Published var nodeModulesResults: [DeepScanItem] = []
    @Published var buildArtifactResults: [DeepScanItem] = []

    enum DeepScanType { case nodeModules, buildArtifacts }

    var totalSelected: Int { groups.flatMap(\.items).filter(\.isSelected).count }
    var totalSelectedSize: Int64 { groups.flatMap(\.items).filter(\.isSelected).reduce(0) { $0 + $1.size } }

    private let fm = FileManager.default
    private var home: String { fm.homeDirectoryForCurrentUser.path }

    func scanAll() {
        isScanning = true
        groups = DevGroup.allGroups(home: home)
        let groupDefs = groups.map { (id: $0.id, items: $0.itemDefinitions) }
        Task {
            await withTaskGroup(of: (UUID, [DevCleanItem]).self) { tg in
                for groupDef in groupDefs {
                    tg.addTask {
                        let scanned = DevCleanEngine.scanItems(groupDef.items)
                        return (groupDef.id, scanned.sorted { $0.size > $1.size })
                    }
                }

                for await (groupId, scannedItems) in tg {
                    if let idx = self.groups.firstIndex(where: { $0.id == groupId }) {
                        self.groups[idx].items = scannedItems
                        self.groups[idx].isScanning = false
                    }
                }
            }
            isScanning = false
        }
    }

    func cancelScan() {
        hasScanned = true
        isScanning = false
    }

    func toggleItem(groupId: UUID, itemId: UUID) {
        guard let gi = groups.firstIndex(where: { $0.id == groupId }),
              let ii = groups[gi].items.firstIndex(where: { $0.id == itemId }) else { return }
        groups[gi].items[ii].isSelected.toggle()
    }

    func toggleAllInGroup(_ groupId: UUID) {
        guard let gi = groups.firstIndex(where: { $0.id == groupId }) else { return }
        let allSelected = groups[gi].items.allSatisfy(\.isSelected)
        for ii in groups[gi].items.indices {
            groups[gi].items[ii].isSelected = !allSelected
        }
    }

    func cleanSelected() async -> Int64 {
        var totalCleaned: Int64 = 0
        for gi in groups.indices {
            for item in groups[gi].items where item.isSelected {
                let size = item.size
                do {
                    try fm.removeItem(atPath: item.path)
                    totalCleaned += size
                } catch {}
            }
        }
        return totalCleaned
    }

    nonisolated static func scanItems(_ itemDefs: [DevCleanItem]) -> [DevCleanItem] {
        let fm = FileManager.default
        var items: [DevCleanItem] = []

        for itemDef in itemDefs {
            guard fm.fileExists(atPath: itemDef.path) else { continue }
            let size = ScanEngine.calcSize(path: itemDef.path)
            guard size > 0 else { continue }
            var item = itemDef
            item.size = size
            items.append(item)
        }

        return items
    }

    // MARK: - Select All Safe / Deselect All
    func selectAllSafe() {
        for gi in groups.indices {
            for ii in groups[gi].items.indices {
                groups[gi].items[ii].isSelected = groups[gi].items[ii].safety == .safe
            }
        }
    }

    func deselectAll() {
        for gi in groups.indices {
            for ii in groups[gi].items.indices {
                groups[gi].items[ii].isSelected = false
            }
        }
    }

    // MARK: - Deep Scan: node_modules
    func deepScanNodeModules() {
        isDeepScanning = true
        nodeModulesResults = []
        Task.detached { [home] in
            let found = DevCleanEngine.findDirectories(named: "node_modules", under: home)
            await MainActor.run {
                self.nodeModulesResults = found
                self.isDeepScanning = false
            }
        }
    }

    // MARK: - Deep Scan: Build Artifacts
    func deepScanBuildArtifacts() {
        isDeepScanning = true
        buildArtifactResults = []
        Task.detached { [home] in
            let names = ["build", "dist", ".build", "DerivedData", ".next", ".nuxt", ".output", "__pycache__", "target"]
            var allResults: [DeepScanItem] = []
            for name in names {
                allResults.append(contentsOf: DevCleanEngine.findDirectories(named: name, under: home))
            }
            allResults.sort { $0.size > $1.size }
            let finalResults = allResults
            await MainActor.run { [weak self] in
                self?.buildArtifactResults = finalResults
                self?.isDeepScanning = false
            }
        }
    }

    nonisolated static func findDirectories(named target: String, under root: String) -> [DeepScanItem] {
        let fm = FileManager.default
        var results: [DeepScanItem] = []
        let skipDirs: Set<String> = ["Library", ".Trash", "Pictures", "Music", "Movies", ".git"]

        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: root),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return results }

        while let url = enumerator.nextObject() as? URL {
            let name = url.lastPathComponent
            // Skip certain directories to avoid deep recursion
            if skipDirs.contains(name) {
                enumerator.skipDescendants()
                continue
            }
            // If we find target directory
            if name == target {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir else { continue }
                let size = ScanEngine.calcSize(path: url.path)
                if size > 0 {
                    results.append(DeepScanItem(
                        path: url.path,
                        size: size,
                        parentProject: url.deletingLastPathComponent().lastPathComponent
                    ))
                }
                enumerator.skipDescendants() // Don't recurse into it
                continue
            }
        }
        return results
    }

    func cleanDeepScanResults(type: DeepScanType) {
        let items: [DeepScanItem]
        switch type {
        case .nodeModules: items = nodeModulesResults.filter(\.isSelected)
        case .buildArtifacts: items = buildArtifactResults.filter(\.isSelected)
        }
        for item in items {
            try? fm.removeItem(atPath: item.path)
        }
        switch type {
        case .nodeModules: deepScanNodeModules()
        case .buildArtifacts: deepScanBuildArtifacts()
        }
    }

    // MARK: - CLI Tools Scanning
    @Published var cliPackages: [CLIPackage] = []
    @Published var isScanningCLI = false

    func scanCLITools() {
        isScanningCLI = true
        cliPackages = []
        Task.detached {
            var packages: [CLIPackage] = []

            // Homebrew
            if let brewPath = DevCleanEngine.findCommand("brew") {
                let output = DevCleanEngine.runShell("\(brewPath) list --formula -1")
                for line in output.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    let name = line.trimmingCharacters(in: .whitespaces)
                    // Get info for size
                    let infoOut = DevCleanEngine.runShell("\(brewPath) info \(name) 2>/dev/null | head -3")
                    packages.append(CLIPackage(name: name, manager: .homebrew, info: infoOut))
                }
                // Also casks
                let casksOut = DevCleanEngine.runShell("\(brewPath) list --cask -1")
                for line in casksOut.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    let name = line.trimmingCharacters(in: .whitespaces)
                    packages.append(CLIPackage(name: name, manager: .homebrewCask, info: "Homebrew Cask"))
                }
            }

            // npm global packages
            if let npmPath = DevCleanEngine.findCommand("npm") {
                let output = DevCleanEngine.runShell("\(npmPath) list -g --depth=0 2>/dev/null")
                for line in output.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.contains("@"), !trimmed.isEmpty else { continue }
                    // Format: "├── package@version" or "└── package@version"
                    let cleaned = trimmed.replacingOccurrences(of: "├── ", with: "")
                        .replacingOccurrences(of: "└── ", with: "")
                        .replacingOccurrences(of: "┬─ ", with: "")
                        .replacingOccurrences(of: "─ ", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    guard !cleaned.isEmpty, !cleaned.hasPrefix("/"), cleaned.contains("@") else { continue }
                    let parts = cleaned.components(separatedBy: "@")
                    let pkgName = parts.dropLast().joined(separator: "@")
                    let version = parts.last ?? ""
                    guard !pkgName.isEmpty, pkgName != "npm" else { continue }
                    packages.append(CLIPackage(name: pkgName, manager: .npm, info: "v\(version)"))
                }
            }

            // pip3 packages
            if let pipPath = DevCleanEngine.findCommand("pip3") {
                let output = DevCleanEngine.runShell("\(pipPath) list --format=columns 2>/dev/null")
                for line in output.components(separatedBy: "\n").dropFirst(2) {
                    let parts = line.split(separator: " ", maxSplits: 1)
                    guard parts.count >= 1 else { continue }
                    let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let version = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
                    guard !name.isEmpty, name != "pip", name != "setuptools", name != "wheel" else { continue }
                    packages.append(CLIPackage(name: name, manager: .pip, info: version))
                }
            }

            // gem packages
            if let gemPath = DevCleanEngine.findCommand("gem") {
                let output = DevCleanEngine.runShell("\(gemPath) list --no-details 2>/dev/null")
                for line in output.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !trimmed.hasPrefix("***") else { continue }
                    let parts = trimmed.components(separatedBy: " (")
                    let name = parts[0].trimmingCharacters(in: .whitespaces)
                    let version = parts.count > 1 ? parts[1].replacingOccurrences(of: ")", with: "") : ""
                    // Skip built-in gems
                    let builtIn: Set<String> = ["bigdecimal", "bundler", "cgi", "csv", "date", "delegate",
                        "did_you_mean", "digest", "drb", "english", "erb", "error_highlight",
                        "etc", "fcntl", "fiddle", "fileutils", "find", "forwardable",
                        "io-console", "io-nonblock", "io-wait", "ipaddr", "irb", "json",
                        "logger", "minitest", "mutex_m", "net-http", "net-protocol",
                        "observer", "open-uri", "open3", "openssl", "optparse",
                        "ostruct", "pathname", "power_assert", "pp", "prettyprint",
                        "pstore", "psych", "racc", "rdoc", "readline", "readline-ext",
                        "reline", "resolv", "resolv-replace", "rexml", "rinda", "ruby2_keywords",
                        "securerandom", "set", "shellwords", "singleton", "stringio", "strscan",
                        "syntax_suggest", "syslog", "tempfile", "test-unit", "time", "timeout",
                        "tmpdir", "tsort", "typeprof", "un", "uri", "weakref",
                        "win32ole", "yaml", "zlib"]
                    guard !builtIn.contains(name) else { continue }
                    packages.append(CLIPackage(name: name, manager: .gem, info: version))
                }
            }

            let finalPackages = packages
            await MainActor.run { [weak self] in
                self?.cliPackages = finalPackages
                self?.isScanningCLI = false
            }
        }
    }

    nonisolated static func findCommand(_ name: String) -> String? {
        let paths = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"]
        for p in paths {
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        // Try which
        let result = runShell("/usr/bin/which \(name) 2>/dev/null")
        let path = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    nonisolated static func runShell(_ command: String, timeout: TimeInterval = 30.0) -> String {
        let proc = Process()
        let pipe = Pipe()
        proc.launchPath = "/bin/zsh"
        proc.arguments = ["-c", command]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        proc.environment = ProcessInfo.processInfo.environment
        let sema = DispatchSemaphore(value: 0)
        proc.terminationHandler = { _ in sema.signal() }
        do { try proc.run() } catch { return "" }
        if sema.wait(timeout: .now() + timeout) == .timedOut {
            proc.terminate()
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func uninstallCLIPackages(_ packages: [CLIPackage]) {
        Task.detached {
            for pkg in packages {
                let cmd: String
                switch pkg.manager {
                case .homebrew:
                    cmd = "\(DevCleanEngine.findCommand("brew") ?? "brew") uninstall \(pkg.name) 2>/dev/null"
                case .homebrewCask:
                    cmd = "\(DevCleanEngine.findCommand("brew") ?? "brew") uninstall --cask \(pkg.name) 2>/dev/null"
                case .npm:
                    cmd = "\(DevCleanEngine.findCommand("npm") ?? "npm") uninstall -g \(pkg.name) 2>/dev/null"
                case .pip:
                    cmd = "\(DevCleanEngine.findCommand("pip3") ?? "pip3") uninstall -y \(pkg.name) 2>/dev/null"
                case .gem:
                    cmd = "\(DevCleanEngine.findCommand("gem") ?? "gem") uninstall \(pkg.name) -x 2>/dev/null"
                }
                _ = DevCleanEngine.runShell(cmd)
            }
            await MainActor.run {
                self.scanCLITools() // Re-scan after removal
            }
        }
    }
}

// MARK: - CLI Package Model
struct CLIPackage: Identifiable {
    let id = UUID()
    let name: String
    let manager: PackageManager
    let info: String
    var isSelected = false

    enum PackageManager: String, CaseIterable {
        case homebrew = "Homebrew"
        case homebrewCask = "Brew Cask"
        case npm = "npm (Global)"
        case pip = "pip3"
        case gem = "gem"

        var icon: String {
            switch self {
            case .homebrew, .homebrewCask: return "cup.and.saucer.fill"
            case .npm: return "shippingbox.fill"
            case .pip: return "terminal.fill"
            case .gem: return "diamond.fill"
            }
        }

        var color: Color {
            switch self {
            case .homebrew, .homebrewCask: return Color(hex: "FBB040")
            case .npm: return Color(hex: "CB3837")
            case .pip: return Color(hex: "3776AB")
            case .gem: return Color(hex: "CC342D")
            }
        }

        var uninstallLabel: String {
            switch self {
            case .homebrew: return "brew uninstall"
            case .homebrewCask: return "brew uninstall --cask"
            case .npm: return "npm uninstall -g"
            case .pip: return "pip3 uninstall"
            case .gem: return "gem uninstall"
            }
        }
    }
}

// MARK: - CLI Tools Sheet
struct CLIToolsSheet: View {
    @ObservedObject var engine: DevCleanEngine
    let onDismiss: () -> Void
    @State private var selectedManager: CLIPackage.PackageManager? = nil
    @State private var searchText = ""
    @State private var showUninstallConfirm = false

    var filteredPackages: [CLIPackage] {
        var pkgs = engine.cliPackages
        if let mgr = selectedManager {
            pkgs = pkgs.filter { $0.manager == mgr }
        }
        if !searchText.isEmpty {
            pkgs = pkgs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return pkgs
    }

    var selectedCount: Int { engine.cliPackages.filter(\.isSelected).count }

    var managerCounts: [(CLIPackage.PackageManager, Int)] {
        CLIPackage.PackageManager.allCases.compactMap { mgr in
            let count = engine.cliPackages.filter { $0.manager == mgr }.count
            return count > 0 ? (mgr, count) : nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Installed CLI Tools & Packages")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    if engine.isScanningCLI {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6)
                            Text("Scanning package managers...").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    } else {
                        Text("\(engine.cliPackages.count) packages found across \(managerCounts.count) package managers")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button {
                    engine.scanCLITools()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }.buttonStyle(.plain).help("Rescan")

                Button("Done") { onDismiss() }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.gray.opacity(0.15).cornerRadius(6))
            }
            .padding(16)

            // Filter tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button {
                        selectedManager = nil
                    } label: {
                        Text("All (\(engine.cliPackages.count))")
                            .font(.system(size: 11, weight: selectedManager == nil ? .bold : .medium))
                            .foregroundColor(selectedManager == nil ? .white : .primary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background((selectedManager == nil ? AppTheme.accent : Color.gray.opacity(0.15)).cornerRadius(6))
                    }.buttonStyle(.plain)

                    ForEach(managerCounts, id: \.0) { mgr, count in
                        Button {
                            selectedManager = mgr
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: mgr.icon).font(.system(size: 9))
                                Text("\(mgr.rawValue) (\(count))")
                            }
                            .font(.system(size: 11, weight: selectedManager == mgr ? .bold : .medium))
                            .foregroundColor(selectedManager == mgr ? .white : .primary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background((selectedManager == mgr ? mgr.color : Color.gray.opacity(0.15)).cornerRadius(6))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 6)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search packages...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.gray.opacity(0.1).cornerRadius(8))
            .padding(.horizontal, 16).padding(.bottom, 6)

            Divider()

            // Package List
            if filteredPackages.isEmpty && !engine.isScanningCLI {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundColor(AppTheme.success.opacity(0.6))
                    Text("No packages found").font(.system(size: 13)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredPackages.indices, id: \.self) { idx in
                    let globalIdx = engine.cliPackages.firstIndex(where: { $0.id == filteredPackages[idx].id })
                    HStack(spacing: 10) {
                        Button {
                            if let gi = globalIdx {
                                engine.cliPackages[gi].isSelected.toggle()
                            }
                        } label: {
                            Image(systemName: engine.cliPackages[globalIdx ?? 0].isSelected ? "checkmark.square.fill" : "square")
                                .font(.system(size: 15))
                                .foregroundColor(engine.cliPackages[globalIdx ?? 0].isSelected ? Color(hex: "E94560") : .secondary)
                        }.buttonStyle(.plain)

                        // Manager badge
                        Image(systemName: filteredPackages[idx].manager.icon)
                            .font(.system(size: 11))
                            .foregroundColor(filteredPackages[idx].manager.color)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(filteredPackages[idx].name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text("\(filteredPackages[idx].manager.rawValue) • \(filteredPackages[idx].info)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()

                        Text(filteredPackages[idx].manager.uninstallLabel)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1).cornerRadius(4))
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider()

            // Footer
            HStack {
                Button {
                    for idx in engine.cliPackages.indices { engine.cliPackages[idx].isSelected = true }
                } label: {
                    Text("Select All").font(.system(size: 11, weight: .medium))
                }.buttonStyle(.plain)

                Button {
                    for idx in engine.cliPackages.indices { engine.cliPackages[idx].isSelected = false }
                } label: {
                    Text("Deselect All").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                }.buttonStyle(.plain)

                Spacer()

                if selectedCount > 0 {
                    Text("\(selectedCount) selected for removal")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }

                Button {
                    showUninstallConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Uninstall Selected")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedCount > 0
                                  ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "E94560"), Color(hex: "764BA2")], startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.gray))
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedCount == 0)
                .confirmationDialog(
                    "Uninstall \(selectedCount) packages?",
                    isPresented: $showUninstallConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Uninstall", role: .destructive) {
                        let toRemove = engine.cliPackages.filter(\.isSelected)
                        engine.uninstallCLIPackages(toRemove)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will run uninstall commands for each selected package. This action cannot be undone.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 700, height: 550)
    }
}

// MARK: - Deep Scan Item
struct DeepScanItem: Identifiable {
    let id = UUID()
    let path: String
    let size: Int64
    let parentProject: String
    var isSelected = false

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Deep Scan Result Sheet
struct DeepScanResultSheet: View {
    let title: String
    @State var items: [DeepScanItem]
    let isScanning: Bool
    let onClean: () -> Void
    let onDismiss: () -> Void

    var selectedSize: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    var selectedCount: Int { items.filter(\.isSelected).count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    if isScanning {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.6)
                            Text("Scanning directories...").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    } else {
                        Text("\(items.count) directories found — \(ByteCountFormatter.string(fromByteCount: items.reduce(0) { $0 + $1.size }, countStyle: .file)) total")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Done") { onDismiss() }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.gray.opacity(0.15).cornerRadius(6))
            }
            .padding(16)

            Divider()

            // Item List
            if items.isEmpty && !isScanning {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundColor(AppTheme.success.opacity(0.6))
                    Text("No directories found — clean!").font(.system(size: 13)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items.indices, id: \.self) { idx in
                    HStack(spacing: 10) {
                        Button {
                            items[idx].isSelected.toggle()
                        } label: {
                            Image(systemName: items[idx].isSelected ? "checkmark.square.fill" : "square")
                                .font(.system(size: 15))
                                .foregroundColor(items[idx].isSelected ? AppTheme.accent : .secondary)
                        }.buttonStyle(.plain)

                        Image(systemName: "folder.fill")
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(items[idx].parentProject)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text(items[idx].path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(items[idx].sizeFormatted)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)

                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: items[idx].path)])
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }.buttonStyle(.plain)
                    }
                    .padding(.vertical, 3)
                }
            }

            Divider()

            // Footer
            HStack {
                Button {
                    for idx in items.indices { items[idx].isSelected = true }
                } label: {
                    Text("Select All").font(.system(size: 11, weight: .medium))
                }.buttonStyle(.plain)

                Button {
                    for idx in items.indices { items[idx].isSelected = false }
                } label: {
                    Text("Deselect All").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                }.buttonStyle(.plain)

                Spacer()

                if selectedCount > 0 {
                    Text("\(selectedCount) selected — \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }

                Button {
                    onClean()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete Selected")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedCount > 0
                                  ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "E94560"), Color(hex: "764BA2")], startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.gray))
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 650, height: 500)
    }
}

// MARK: - Dev Group Model
struct DevGroup: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let gradientColors: [Color]
    var items: [DevCleanItem] = []
    var isScanning = true
    let itemDefinitions: [DevCleanItem]
    let appIcon: NSImage?

    init(name: String, icon: String, gradientColors: [Color], itemDefinitions: [DevCleanItem], bundleIds: [String] = []) {
        self.name = name
        self.icon = icon
        self.gradientColors = gradientColors
        self.itemDefinitions = itemDefinitions
        self.appIcon = Self.iconForApp(bundleIds: bundleIds, appName: name)
    }

    var gradient: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var allSelected: Bool { !items.isEmpty && items.allSatisfy(\.isSelected) }

    /// Look up real app icon from bundle IDs or app name
    static func iconForApp(bundleIds: [String], appName: String) -> NSImage? {
        // Try bundle IDs first
        for bid in bundleIds {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        // Fallback: search /Applications by name
        let fm = FileManager.default
        let searchDirs = ["/Applications", fm.homeDirectoryForCurrentUser.path + "/Applications"]
        for dir in searchDirs {
            let appPath = "\(dir)/\(appName).app"
            if fm.fileExists(atPath: appPath) {
                return NSWorkspace.shared.icon(forFile: appPath)
            }
        }
        return nil
    }

    static func allGroups(home: String) -> [DevGroup] {
        var groups: [DevGroup] = [
            DevGroup(
                name: "Xcode", icon: "hammer.fill",
                gradientColors: [Color(hex: "007AFF"), Color(hex: "5AC8FA")],
                itemDefinitions: xcodeItems(home: home),
                bundleIds: ["com.apple.dt.Xcode"]
            ),
            DevGroup(
                name: "VS Code", icon: "curlybraces",
                gradientColors: [Color(hex: "007ACC"), Color(hex: "1E1E1E")],
                itemDefinitions: vscodeItems(home: home),
                bundleIds: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92"]
            ),
            DevGroup(
                name: "Android Studio", icon: "ant.fill",
                gradientColors: [Color(hex: "3DDC84"), Color(hex: "073042")],
                itemDefinitions: androidItems(home: home),
                bundleIds: ["com.google.android.studio"]
            ),
            DevGroup(
                name: "JetBrains IDEs", icon: "bold",
                gradientColors: [Color(hex: "FE2857"), Color(hex: "F97A12")],
                itemDefinitions: jetbrainsItems(home: home),
                bundleIds: ["com.jetbrains.intellij", "com.jetbrains.intellij.ce", "com.jetbrains.pycharm", "com.jetbrains.pycharm.ce", "com.jetbrains.WebStorm", "com.jetbrains.CLion", "com.jetbrains.goland", "com.jetbrains.rider", "com.jetbrains.rubymine", "com.jetbrains.PhpStorm", "com.jetbrains.fleet"]
            ),
            DevGroup(
                name: "Sublime Text", icon: "text.cursor",
                gradientColors: [Color(hex: "FF9800"), Color(hex: "4A4A4A")],
                itemDefinitions: sublimeItems(home: home),
                bundleIds: ["com.sublimetext.4", "com.sublimetext.3", "com.sublimetext.2"]
            ),
            DevGroup(
                name: "npm / Yarn / pnpm", icon: "shippingbox.fill",
                gradientColors: [Color(hex: "CB3837"), Color(hex: "F7DF1E")],
                itemDefinitions: nodePackageItems(home: home),
                bundleIds: ["com.apple.Terminal"]
            ),
            DevGroup(
                name: "Python / pip", icon: "terminal.fill",
                gradientColors: [Color(hex: "3776AB"), Color(hex: "FFD43B")],
                itemDefinitions: pythonItems(home: home),
                bundleIds: ["org.python.IDLE", "com.continuum.anaconda", "com.googleusercontent.apps.jupyterlab"]
            ),
            DevGroup(
                name: "Ruby / Gems", icon: "diamond.fill",
                gradientColors: [Color(hex: "CC342D"), Color(hex: "FF6B6B")],
                itemDefinitions: rubyItems(home: home),
                bundleIds: ["com.apple.Terminal"]
            ),
            DevGroup(
                name: "Rust / Cargo", icon: "gearshape.2.fill",
                gradientColors: [Color(hex: "DEA584"), Color(hex: "000000")],
                itemDefinitions: rustItems(home: home),
                bundleIds: ["com.apple.Terminal"]
            ),
            DevGroup(
                name: "Go Modules", icon: "arrow.right.circle.fill",
                gradientColors: [Color(hex: "00ADD8"), Color(hex: "005F87")],
                itemDefinitions: goItems(home: home),
                bundleIds: ["com.apple.Terminal"]
            ),
            DevGroup(
                name: "Flutter / Dart", icon: "arrow.triangle.branch",
                gradientColors: [Color(hex: "02569B"), Color(hex: "45D1FD")],
                itemDefinitions: flutterItems(home: home),
                bundleIds: ["io.flutter.flutter"]
            ),
            DevGroup(
                name: "CocoaPods", icon: "cube.fill",
                gradientColors: [Color(hex: "EE3322"), Color(hex: "FF6B6B")],
                itemDefinitions: cocoapodsItems(home: home),
                bundleIds: ["com.apple.Terminal"]
            ),
            DevGroup(
                name: "Homebrew", icon: "cup.and.saucer.fill",
                gradientColors: [Color(hex: "FBB040"), Color(hex: "F37021")],
                itemDefinitions: homebrewItems(home: home),
                bundleIds: ["com.apple.Terminal"]
            ),
            DevGroup(
                name: "Swift / SPM", icon: "swift",
                gradientColors: [Color(hex: "F05138"), Color(hex: "FF9900")],
                itemDefinitions: swiftItems(home: home),
                bundleIds: ["com.apple.dt.Xcode"]
            ),
            DevGroup(
                name: "Docker", icon: "shippingbox.and.arrow.backward.fill",
                gradientColors: [Color(hex: "2496ED"), Color(hex: "003F8E")],
                itemDefinitions: dockerItems(home: home),
                bundleIds: ["com.docker.docker", "com.electron.dockerdesktop"]
            ),
            DevGroup(
                name: "CLI / Version Mgrs", icon: "terminal",
                gradientColors: [Color(hex: "4EC9B0"), Color(hex: "1E1E1E")],
                itemDefinitions: cliToolItems(home: home),
                bundleIds: ["com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable"]
            ),
            DevGroup(
                name: "Crash Logs", icon: "exclamationmark.triangle.fill",
                gradientColors: [DS.danger, Color(hex: "D0021B")],
                itemDefinitions: crashItems(home: home),
                bundleIds: ["com.apple.Console"]
            ),
        ]

        // Dynamically detect additional IDEs/dev tools from /Applications
        let detected = detectedIDEGroups(home: home)
        groups.append(contentsOf: detected)
        return groups
    }

    // MARK: - Dynamic IDE/Dev Tool Detection (Full /Applications Scan)
    /// Scan ALL apps in /Applications to find developer tools, IDEs, editors, terminals
    static func detectedIDEGroups(home: String) -> [DevGroup] {
        let fm = FileManager.default
        let support = "\(home)/Library/Application Support"
        let caches  = "\(home)/Library/Caches"
        let logs    = "\(home)/Library/Logs"

        // Bundle IDs already covered by hardcoded groups
        let coveredBundles: Set<String> = [
            "com.apple.dt.Xcode", "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders",
            "com.google.android.studio",
            "com.jetbrains.intellij", "com.jetbrains.intellij.ce", "com.jetbrains.pycharm", "com.jetbrains.pycharm.ce",
            "com.jetbrains.WebStorm", "com.jetbrains.CLion", "com.jetbrains.goland", "com.jetbrains.rider",
            "com.jetbrains.rubymine", "com.jetbrains.PhpStorm", "com.jetbrains.fleet",
            "com.sublimetext.4", "com.sublimetext.3", "com.sublimetext.2",
            "com.docker.docker", "com.electron.dockerdesktop",
            "com.apple.Terminal", "com.apple.Console",
        ]

        // Keywords that indicate a dev/coding tool (precise, no false positives)
        let devKeywords: Set<String> = [
            // IDEs & Editors
            "xcode", "vscode", "visual studio", "intellij", "pycharm", "webstorm", "clion",
            "goland", "rider", "rubymine", "phpstorm", "fleet", "nova", "bbedit",
            "textmate", "sublime", "eclipse", "netbeans", "coderunner", "coteditor",
            "macvim", "neovim", "emacs", "brackets", "atom", "cursor", "zed",
            "coda", "espresso", "gedit", "komodo",
            // Terminals
            "iterm", "warp", "ghostty", "kitty", "hyper", "tabby", "alacritty", "terminal",
            // Git clients
            "sourcetree", "gitkraken", "tower", "fork", "gitfox", "gitup",
            // API / Network Dev
            "postman", "insomnia", "proxyman", "charles", "paw", "rapidapi", "httpie", "altair",
            // Database
            "tableplus", "sequel pro", "sequel ace", "dbeaver", "datagrip", "navicat",
            "mongodb compass", "pgadmin", "redis", "postico", "querious",
            // Containers & DevOps
            "docker", "kubernetes", "podman", "vagrant",
            // Game Engines
            "unity", "unreal", "godot", "gamemaker",
            // Design (dev-adjacent)
            "figma", "sketch",
        ]

        // Only this one category is reliable for dev tools
        let devCategories: Set<String> = [
            "public.app-category.developer-tools",
        ]

        // Bundle ID prefixes that are definitely dev tools
        let devBundlePrefixes = [
            "com.jetbrains.", "com.sublimetext.", "com.sublimemerge",
            "com.microsoft.VSCode", "com.google.android.studio",
            "com.panic.Nova", "com.barebones.bbedit", "com.macromates.",
            "dev.zed.", "com.github.atom", "io.brackets.",
            "com.googlecode.iterm2", "dev.warp.", "com.mitchellh.ghostty",
            "net.kovidgoyal.kitty", "co.zeit.hyper",
            "com.postmanlabs.", "com.insomnia.",
            "com.tinyapp.TablePlus", "com.sequel-ace.",
            "org.eclipse.", "org.netbeans.",
            "com.docker.", "com.figma.",
            "com.todesktop.", "com.krill.CodeRunner",
            "com.coteditor.", "org.vim.",
        ]

        // Scan these directories for .app bundles
        let searchDirs = ["/Applications", "\(home)/Applications", "/Applications/Utilities"]

        var discovered: [DevGroup] = []
        var seenBundles: Set<String> = coveredBundles

        for searchDir in searchDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: searchDir) else { continue }

            for item in contents where item.hasSuffix(".app") {
                let appPath = "\(searchDir)/\(item)"
                let plistPath = "\(appPath)/Contents/Info.plist"
                guard let plist = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else { continue }

                let bundleId = plist["CFBundleIdentifier"] as? String ?? ""
                guard !bundleId.isEmpty, !seenBundles.contains(bundleId) else { continue }

                // Check if this is a dev tool
                let category = plist["LSApplicationCategoryType"] as? String ?? ""
                let appName = (item as NSString).deletingPathExtension
                let nameLower = appName.lowercased()
                let bundleLower = bundleId.lowercased()

                let isDevCategory = devCategories.contains(category)
                let isDevByName = devKeywords.contains(where: { nameLower.contains($0) })
                let isDevByBundle = devBundlePrefixes.contains(where: { bundleLower.hasPrefix($0.lowercased()) })
                let isJetBrains = bundleLower.contains("jetbrains")

                guard isDevCategory || isDevByName || isDevByBundle || isJetBrains else { continue }

                // Skip non-dev apps that might match keywords accidentally
                let skipBundles: Set<String> = [
                    // Apple system apps
                    "com.apple.systempreferences", "com.apple.finder", "com.apple.Safari",
                    "com.apple.mail", "com.apple.iCal", "com.apple.AddressBook",
                    "com.apple.ActivityMonitor", "com.apple.DiskUtility",
                    "com.apple.Accessibility-Settings", "com.apple.Notes",
                    "com.apple.reminders", "com.apple.Preview", "com.apple.Photos",
                    "com.apple.Music", "com.apple.TV", "com.apple.Podcasts",
                    "com.apple.Maps", "com.apple.FaceTime", "com.apple.iWork.Keynote",
                    "com.apple.iWork.Pages", "com.apple.iWork.Numbers",
                    "com.apple.ScriptEditor2", "com.apple.Automator",
                    // Messaging & Social
                    "ru.keepcoder.Telegram", "com.telegram.desktop",
                    "com.tinyspeck.slackmacgap", "com.hnc.Discord",
                    "org.whispersystems.signal-desktop", "com.facebook.archon",
                    "us.zoom.xos", "com.microsoft.teams", "com.microsoft.teams2",
                    "com.skype.skype", "com.viber.osx",
                    // Media & Entertainment
                    "com.spotify.client", "com.plexapp.plexmediaserver",
                    "tv.plex.desktop", "com.colliderli.iina", "org.videolan.vlc",
                    "com.obsproject.obs-studio",
                    // Browsers
                    "com.google.Chrome", "org.mozilla.firefox", "com.brave.Browser",
                    "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
                    "company.thebrowser.Browser", "com.microsoft.edgemac",
                    // Productivity
                    "com.microsoft.Word", "com.microsoft.Excel", "com.microsoft.Powerpoint",
                    "com.microsoft.Outlook", "com.microsoft.onenote.mac",
                    "md.obsidian", "com.notion.id", "com.todoist.mac.Todoist",
                    "com.readdle.PDFExpert-Mac", "com.agilebits.onepassword7",
                    "com.1password.1password",
                    // Cloud storage
                    "com.getdropbox.dropbox", "com.google.drivefs",
                    // VPN / Security
                    "com.nordvpn.macos", "com.expressvpn.ExpressVPN",
                    // Misc
                    "com.if.Amphetamine", "com.bjango.istatmenus",
                    "com.hegenberg.BetterTouchTool", "com.flexibits.fantastical2.mac",
                    "cc.ffitch.shottr", "com.raycast.macos",
                    "com.loom.desktop", "com.grammarly.ProjectLlama",
                ]
                guard !skipBundles.contains(bundleId) else { continue }

                seenBundles.insert(bundleId)

                // Generate cache items
                var items: [DevCleanItem] = []

                // Application Support (by app name)
                let supportPath = "\(support)/\(appName)"
                if fm.fileExists(atPath: supportPath) {
                    items.append(DevCleanItem(
                        name: "\(appName) App Data",
                        path: supportPath,
                        icon: "folder.fill",
                        description: "\(appName) application support data",
                        safety: .caution, isSelected: false
                    ))
                }

                // Caches (by bundle ID)
                let cachePath = "\(caches)/\(bundleId)"
                if fm.fileExists(atPath: cachePath) {
                    items.append(DevCleanItem(
                        name: "\(appName) Cache",
                        path: cachePath,
                        icon: "internaldrive",
                        description: "Application cache files — safely deletable",
                        safety: .safe, isSelected: true
                    ))
                }

                // Logs
                let logPath = "\(logs)/\(appName)"
                if fm.fileExists(atPath: logPath) {
                    items.append(DevCleanItem(
                        name: "\(appName) Logs",
                        path: logPath,
                        icon: "doc.text",
                        description: "Application log files",
                        safety: .safe, isSelected: true
                    ))
                }

                // Container Data (sandboxed apps)
                let containerPath = "\(home)/Library/Containers/\(bundleId)"
                if fm.fileExists(atPath: containerPath) {
                    items.append(DevCleanItem(
                        name: "\(appName) Container",
                        path: "\(containerPath)/Data",
                        icon: "shippingbox",
                        description: "Sandboxed container data — caution",
                        safety: .manual, isSelected: false
                    ))
                }

                // Saved Application State
                let savedState = "\(home)/Library/Saved Application State/\(bundleId).savedState"
                if fm.fileExists(atPath: savedState) {
                    items.append(DevCleanItem(
                        name: "\(appName) Saved State",
                        path: savedState,
                        icon: "clock.arrow.circlepath",
                        description: "Window restore / session data",
                        safety: .safe, isSelected: true
                    ))
                }

                // Preferences
                let prefsPath = "\(home)/Library/Preferences/\(bundleId).plist"
                if fm.fileExists(atPath: prefsPath) {
                    items.append(DevCleanItem(
                        name: "\(appName) Preferences",
                        path: prefsPath,
                        icon: "gearshape",
                        description: "App preference file — removes all settings",
                        safety: .manual, isSelected: false
                    ))
                }

                guard !items.isEmpty else { continue }

                discovered.append(DevGroup(
                    name: appName, icon: "app.fill",
                    gradientColors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                    itemDefinitions: items,
                    bundleIds: [bundleId]
                ))
            }
        }

        return discovered.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // MARK: - Xcode Items
    static func xcodeItems(home: String) -> [DevCleanItem] {
        let dev = "\(home)/Library/Developer"
        return [
            DevCleanItem(name: "Derived Data",
                         path: "\(dev)/Xcode/DerivedData",
                         icon: "hammer",
                         description: "Xcode build products and indexes — safely regenerated",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Archives",
                         path: "\(dev)/Xcode/Archives",
                         icon: "archivebox",
                         description: "App archives — uncheck if you need old archives",
                         safety: .caution, isSelected: false),
            DevCleanItem(name: "iOS Device Support",
                         path: "\(dev)/Xcode/iOS DeviceSupport",
                         icon: "iphone",
                         description: "Symbol files for iOS devices — large, safe to remove",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "watchOS Device Support",
                         path: "\(dev)/Xcode/watchOS DeviceSupport",
                         icon: "applewatch",
                         description: "Symbol files for Apple Watch devices",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "tvOS Device Support",
                         path: "\(dev)/Xcode/tvOS DeviceSupport",
                         icon: "appletv",
                         description: "Symbol files for Apple TV devices",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "visionOS Device Support",
                         path: "\(dev)/Xcode/visionOS DeviceSupport",
                         icon: "visionpro",
                         description: "Symbol files for Apple Vision Pro",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Simulator Data",
                         path: "\(dev)/CoreSimulator/Devices",
                         icon: "iphone.gen3",
                         description: "iOS/watchOS/tvOS simulator data — recreated on demand",
                         safety: .caution, isSelected: false),
            DevCleanItem(name: "CoreSimulator Caches",
                         path: "\(dev)/CoreSimulator/Caches",
                         icon: "internaldrive",
                         description: "Simulator runtime caches",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Xcode Caches",
                         path: "\(home)/Library/Caches/com.apple.dt.Xcode",
                         icon: "folder.fill",
                         description: "Xcode cache files",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Old Documentation",
                         path: "\(dev)/Shared/Documentation",
                         icon: "doc.text",
                         description: "Downloaded Xcode documentation sets",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - VS Code Items
    static func vscodeItems(home: String) -> [DevCleanItem] {
        let support = "\(home)/Library/Application Support"
        let caches  = "\(home)/Library/Caches"
        return [
            DevCleanItem(name: "Workspace Storage",
                         path: "\(support)/Code/User/workspaceStorage",
                         icon: "folder.fill",
                         description: "Per-workspace extension data",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "VS Code Logs",
                         path: "\(support)/Code/logs",
                         icon: "doc.text",
                         description: "VS Code application logs",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Extension Host Logs",
                         path: "\(support)/Code/exthost",
                         icon: "doc.text",
                         description: "Extension host logs and cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "VS Code Cache",
                         path: "\(caches)/com.microsoft.VSCode",
                         icon: "internaldrive",
                         description: "VS Code application cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Insiders Workspace Storage",
                         path: "\(support)/Code - Insiders/User/workspaceStorage",
                         icon: "folder.fill",
                         description: "VS Code Insiders workspace data",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Cursor Workspace Storage",
                         path: "\(support)/Cursor/User/workspaceStorage",
                         icon: "cursor.rays",
                         description: "Cursor AI editor workspace data",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - Android Studio Items
    static func androidItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "Gradle Caches",
                         path: "\(home)/.gradle/caches",
                         icon: "cube.fill",
                         description: "Gradle build caches — will be re-downloaded",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Gradle Daemon Logs",
                         path: "\(home)/.gradle/daemon",
                         icon: "doc.text",
                         description: "Gradle daemon log files",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "AVD Data",
                         path: "\(home)/.android/avd",
                         icon: "iphone.gen1",
                         description: "Android Virtual Device images — large",
                         safety: .caution, isSelected: false),
            DevCleanItem(name: "Android Cache",
                         path: "\(home)/.android/cache",
                         icon: "internaldrive",
                         description: "Android SDK download cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Studio System Cache",
                         path: "\(home)/Library/Caches/Google/AndroidStudio*",
                         icon: "folder.fill",
                         description: "Android Studio system caches",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - JetBrains Items
    static func jetbrainsItems(home: String) -> [DevCleanItem] {
        let support = "\(home)/Library/Application Support/JetBrains"
        let caches  = "\(home)/Library/Caches/JetBrains"
        let logs    = "\(home)/Library/Logs/JetBrains"
        return [
            DevCleanItem(name: "JetBrains Caches",
                         path: caches,
                         icon: "internaldrive",
                         description: "IntelliJ/PyCharm/WebStorm system caches",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "JetBrains Logs",
                         path: logs,
                         icon: "doc.text",
                         description: "All JetBrains IDE log files",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "JetBrains System",
                         path: support,
                         icon: "folder.fill",
                         description: "JetBrains application support data",
                         safety: .caution, isSelected: false),
        ]
    }

    // MARK: - Node Package Items
    static func nodePackageItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "npm Cache",
                         path: "\(home)/.npm/_cacache",
                         icon: "shippingbox.fill",
                         description: "npm package download cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "npm Logs",
                         path: "\(home)/.npm/_logs",
                         icon: "doc.text",
                         description: "npm debug log files",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Yarn Cache",
                         path: "\(home)/Library/Caches/yarn",
                         icon: "shippingbox",
                         description: "Yarn v1 package cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Yarn Berry Cache",
                         path: "\(home)/.yarn/berry/cache",
                         icon: "shippingbox",
                         description: "Yarn v2/v3 package cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "pnpm Store",
                         path: "\(home)/.pnpm-store",
                         icon: "square.stack.3d.up.fill",
                         description: "pnpm content-addressable store",
                         safety: .caution, isSelected: false),
            DevCleanItem(name: "Bun Cache",
                         path: "\(home)/.bun/install/cache",
                         icon: "bolt.fill",
                         description: "Bun package manager cache",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - CocoaPods Items
    static func cocoapodsItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "CocoaPods Cache",
                         path: "\(home)/Library/Caches/CocoaPods",
                         icon: "cube.fill",
                         description: "Downloaded pod archives cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "CocoaPods Repos",
                         path: "\(home)/.cocoapods/repos",
                         icon: "folder.fill",
                         description: "Pod spec repositories — run 'pod setup' to restore",
                         safety: .caution, isSelected: false),
        ]
    }

    // MARK: - Homebrew Items
    static func homebrewItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "Homebrew Download Cache",
                         path: "/Library/Caches/Homebrew",
                         icon: "cup.and.saucer.fill",
                         description: "Cached formula downloads — run 'brew cleanup' to target",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "User Homebrew Cache",
                         path: "\(home)/Library/Caches/Homebrew",
                         icon: "cup.and.saucer",
                         description: "Per-user Homebrew download cache",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - Swift / SPM Items
    static func swiftItems(home: String) -> [DevCleanItem] {
        let dev = "\(home)/Library/Developer"
        return [
            DevCleanItem(name: "SPM Package Cache",
                         path: "\(home)/Library/Caches/org.swift.swiftpm",
                         icon: "swift",
                         description: "Swift Package Manager download cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "SPM Checkouts",
                         path: "\(dev)/Xcode/DerivedData/.swiftpm",
                         icon: "folder.fill",
                         description: "SPM checkout data inside DerivedData",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Swift Toolchain Cache",
                         path: "\(home)/.swiftpm",
                         icon: "wrench.fill",
                         description: "Local Swift package manager cache",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - Docker Items
    static func dockerItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "Docker VM Data",
                         path: "\(home)/Library/Containers/com.docker.docker/Data/vms",
                         icon: "shippingbox.and.arrow.backward.fill",
                         description: "Docker VM disk images — caution: removes all containers",
                         safety: .manual, isSelected: false),
            DevCleanItem(name: "Docker Extension Data",
                         path: "\(home)/Library/Containers/com.docker.docker/Data/extensions",
                         icon: "puzzlepiece.extension.fill",
                         description: "Docker Desktop extension data",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - Sublime Text Items
    static func sublimeItems(home: String) -> [DevCleanItem] {
        let support = "\(home)/Library/Application Support"
        let caches  = "\(home)/Library/Caches"
        return [
            DevCleanItem(name: "Sublime Text Cache",
                         path: "\(caches)/com.sublimetext.4",
                         icon: "internaldrive",
                         description: "Sublime Text application cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Sublime Text 3 Cache",
                         path: "\(caches)/com.sublimetext.3",
                         icon: "internaldrive",
                         description: "Sublime Text 3 application cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Sublime Session",
                         path: "\(support)/Sublime Text/Local/Session.sublime_session",
                         icon: "doc.text",
                         description: "Workspace session state — caution removes open state",
                         safety: .caution, isSelected: false),
            DevCleanItem(name: "Package Control Cache",
                         path: "\(support)/Sublime Text/Backup",
                         icon: "folder.fill",
                         description: "Sublime Text package backups",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - Python Items
    static func pythonItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "pip Cache",
                         path: "\(home)/Library/Caches/pip",
                         icon: "shippingbox.fill",
                         description: "Downloaded pip packages cache — 'pip cache purge'",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "pip http Cache",
                         path: "\(home)/.cache/pip",
                         icon: "shippingbox",
                         description: "pip download cache (Linux-style path)",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Conda Package Cache",
                         path: "\(home)/.conda/pkgs",
                         icon: "cube.fill",
                         description: "Conda downloaded packages — 'conda clean --all'",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Conda Environments",
                         path: "\(home)/.conda/envs",
                         icon: "folder.fill",
                         description: "Conda virtual environments — caution: removes all envs",
                         safety: .manual, isSelected: false),
            DevCleanItem(name: "Miniconda Cache",
                         path: "\(home)/miniconda3/pkgs",
                         icon: "cube",
                         description: "Miniconda package cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Python __pycache__",
                         path: "\(home)/.local/lib",
                         icon: "doc.text.fill",
                         description: "Compiled Python bytecode caches",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Jupyter Data",
                         path: "\(home)/Library/Jupyter",
                         icon: "doc.richtext",
                         description: "Jupyter notebook runtime data & kernels",
                         safety: .caution, isSelected: false),
            DevCleanItem(name: "IPython Cache",
                         path: "\(home)/.ipython",
                         icon: "terminal",
                         description: "IPython history and profile data",
                         safety: .caution, isSelected: false),
        ]
    }

    // MARK: - Ruby Items
    static func rubyItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "Ruby Gem Cache",
                         path: "\(home)/.gem",
                         icon: "diamond.fill",
                         description: "Downloaded gem packages and build cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "rbenv Versions",
                         path: "\(home)/.rbenv/versions",
                         icon: "folder.fill",
                         description: "Installed Ruby versions via rbenv — caution: removes all",
                         safety: .manual, isSelected: false),
            DevCleanItem(name: "rbenv Cache",
                         path: "\(home)/.rbenv/cache",
                         icon: "internaldrive",
                         description: "rbenv download cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Bundler Cache",
                         path: "\(home)/.bundle/cache",
                         icon: "shippingbox",
                         description: "Bundler gem download cache",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - Rust Items
    static func rustItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "Cargo Registry Cache",
                         path: "\(home)/.cargo/registry/cache",
                         icon: "cube.fill",
                         description: "Downloaded crate archives — 'cargo cache -a'",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Cargo Registry Src",
                         path: "\(home)/.cargo/registry/src",
                         icon: "doc.text.fill",
                         description: "Extracted crate source code",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Cargo Git Checkouts",
                         path: "\(home)/.cargo/git",
                         icon: "arrow.triangle.branch",
                         description: "Git-based dependency checkouts",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Rustup Toolchains",
                         path: "\(home)/.rustup/toolchains",
                         icon: "wrench.fill",
                         description: "Installed Rust toolchains — caution: removes all toolchains",
                         safety: .manual, isSelected: false),
            DevCleanItem(name: "Rustup Downloads",
                         path: "\(home)/.rustup/downloads",
                         icon: "arrow.down",
                         description: "Rustup download cache",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - Go Items
    static func goItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "Go Module Cache",
                         path: "\(home)/go/pkg/mod/cache",
                         icon: "cube.fill",
                         description: "Go module download cache — 'go clean -modcache'",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Go Build Cache",
                         path: "\(home)/Library/Caches/go-build",
                         icon: "hammer",
                         description: "Go compilation cache — 'go clean -cache'",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Go Test Cache",
                         path: "\(home)/Library/Caches/go-test",
                         icon: "checkmark.circle",
                         description: "Go test result cache — 'go clean -testcache'",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Go Bin",
                         path: "\(home)/go/bin",
                         icon: "terminal",
                         description: "Installed Go binaries — caution: removes CLI tools",
                         safety: .caution, isSelected: false),
        ]
    }

    // MARK: - Flutter / Dart Items
    static func flutterItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "Dart Pub Cache",
                         path: "\(home)/.pub-cache",
                         icon: "shippingbox.fill",
                         description: "Dart/Flutter package download cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "Flutter Tool Cache",
                         path: "\(home)/.flutter",
                         icon: "arrow.triangle.branch",
                         description: "Flutter SDK settings and cache",
                         safety: .caution, isSelected: false),
            DevCleanItem(name: "Flutter .dart_tool",
                         path: "\(home)/.dartServer",
                         icon: "folder.fill",
                         description: "Dart analysis server cache",
                         safety: .safe, isSelected: true),
        ]
    }

    // MARK: - CLI / Version Manager Items
    static func cliToolItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "nvm (Node Versions)",
                         path: "\(home)/.nvm/versions",
                         icon: "terminal.fill",
                         description: "All installed Node.js versions via nvm — caution",
                         safety: .manual, isSelected: false),
            DevCleanItem(name: "nvm Cache",
                         path: "\(home)/.nvm/.cache",
                         icon: "internaldrive",
                         description: "nvm download cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "pyenv Versions",
                         path: "\(home)/.pyenv/versions",
                         icon: "terminal.fill",
                         description: "Installed Python versions via pyenv — caution",
                         safety: .manual, isSelected: false),
            DevCleanItem(name: "pyenv Cache",
                         path: "\(home)/.pyenv/cache",
                         icon: "internaldrive",
                         description: "pyenv download cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "SDKMAN Candidates",
                         path: "\(home)/.sdkman/candidates",
                         icon: "terminal",
                         description: "SDKMAN installed SDKs (Java, Kotlin, Gradle, etc.)",
                         safety: .manual, isSelected: false),
            DevCleanItem(name: "SDKMAN Archives",
                         path: "\(home)/.sdkman/archives",
                         icon: "archivebox",
                         description: "SDKMAN download archive cache",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "volta Tools",
                         path: "\(home)/.volta",
                         icon: "bolt.fill",
                         description: "Volta JS tool manager — caution: removes all",
                         safety: .manual, isSelected: false),
            DevCleanItem(name: "asdf Data",
                         path: "\(home)/.asdf",
                         icon: "cylinder.fill",
                         description: "asdf version manager installs — caution: removes all",
                         safety: .manual, isSelected: false),
        ]
    }

    // MARK: - Crash Log Items
    static func crashItems(home: String) -> [DevCleanItem] {
        return [
            DevCleanItem(name: "User Diagnostic Reports",
                         path: "\(home)/Library/Logs/DiagnosticReports",
                         icon: "exclamationmark.triangle.fill",
                         description: "App crash and hang reports",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "System Diagnostic Reports",
                         path: "/Library/Logs/DiagnosticReports",
                         icon: "exclamationmark.octagon.fill",
                         description: "System-wide crash reports",
                         safety: .safe, isSelected: true),
            DevCleanItem(name: "User Application Logs",
                         path: "\(home)/Library/Logs",
                         icon: "doc.text.fill",
                         description: "All user application log files",
                         safety: .safe, isSelected: true),
        ]
    }
}

// MARK: - Dev Clean Item Model
struct DevCleanItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String
    let description: String
    let safety: SafetyLevel
    var isSelected: Bool
    var size: Int64 = 0

    enum SafetyLevel: String {
        case safe    = "Safe"
        case caution = "Caution"
        case manual  = "Manual"
    }

    var sizeFormatted: String {
        size == 0 ? "—" : ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
