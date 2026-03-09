import SwiftUI
import AppKit

// MARK: - Filter / Sort / Tab Enums
enum AppFilter: String, CaseIterable {
    case all = "All"
    case userApps = "User"
    case systemApps = "System"
    case utilities = "Utils"
    case largeApps = "Large"
    case unusedApps = "Unused"
    case withLeftovers = "Leftovers"
    case needsUpdate = "Updates"
}

enum AppSort: String, CaseIterable {
    case name = "Name"
    case size = "Size"
    case leftovers = "Leftovers"
}

enum DetailTab: String, CaseIterable {
    case leftovers = "Leftovers"
    case appData = "App Data"
    case scratchDisks = "Scratch Disks"
    case updates = "Updates"
    case appInfo = "App Info"
}

// MARK: - Applications Manager View
struct ApplicationsManagerView: View {
    @ObservedObject var engine: ApplicationsEngine
    @State private var selectedAppId: UUID?
    @State private var showUninstallConfirm = false
    @State private var showResetConfirm = false
    @State private var showClearAllConfirm = false
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var showFDAAlert = false
    @State private var searchText = ""
    @State private var activeFilter: AppFilter = .all
    @State private var activeSort: AppSort = .name
    @State private var activeDetailTab: DetailTab = .leftovers
    @State private var showBatchCleanConfirm = false
    @State private var showBatchScratchConfirm = false
    @State private var scratchRefreshId = UUID()

    @EnvironmentObject var navManager: NavigationManager

    var filteredApps: [InstalledApp] {
        var apps = engine.apps

        // Filter by search
        if !searchText.isEmpty {
            apps = apps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleId.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by category
        switch activeFilter {
        case .all: break
        case .userApps:
            apps = apps.filter { $0.path.hasPrefix("/Applications") && !$0.path.contains("/Utilities/") && !$0.path.hasPrefix("/System") }
        case .systemApps:
            apps = apps.filter { $0.path.hasPrefix("/System/Applications") }
        case .utilities:
            apps = apps.filter { $0.path.contains("/Utilities/") }
        case .largeApps:
            apps = apps.filter { $0.size > 1024 * 1024 * 1024 } // > 1GB
        case .unusedApps:
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            apps = apps.filter { app in
                guard let lastUsed = app.lastUsed else { return false }
                return lastUsed < thirtyDaysAgo
            }
        case .withLeftovers:
            apps = apps.filter { !$0.leftovers.isEmpty }
        case .needsUpdate:
            apps = apps.filter { $0.updateInfo != nil }
        }

        // Sort
        switch activeSort {
        case .name:
            apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            apps.sort { $0.size > $1.size }
        case .leftovers:
            apps.sort { $0.leftovers.count > $1.leftovers.count }
        }

        return apps
    }

    var selectedApp: InstalledApp? {
        guard let id = selectedAppId else { return nil }
        return engine.apps.first(where: { $0.id == id })
    }

    var body: some View {
        VStack(spacing: 0) {
            if !engine.isScanning && !engine.hasScanned {
                landingScreen
            } else if engine.isScanning {
                ToolScanningView(
                    section: .applications,
                    scanningTitle: "Scanning Applications...",
                    currentPath: $engine.currentScanPath,
                    onStop: { engine.cancelScan() }
                )
            } else {
                appsHeader
                Divider()
                HStack(spacing: 0) {
                    appsList
                    Divider()
                    if let app = selectedApp {
                        appDetailView(app: app)
                    } else {
                        emptyState
                    }
                }
                Divider()
                appsFooter
            }
        }
        .background(DS.bg)
        .onChange(of: navManager.currentState) { _, newState in
            if newState.section == .applications {
                if newState.subState == nil || newState.subState == "landing" {
                    engine.hasScanned = false
                    engine.cancelScan()
                } else if newState.subState == "scanning" {
                    engine.hasScanned = true
                }
            }
        }
        .alert("Action Complete", isPresented: $showResult) {
            Button("OK") { }
        } message: {
            Text(resultMessage)
        }
        .alert("Full Disk Access Required", isPresented: $showFDAAlert) {
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("MacSweep needs Full Disk Access to clean app files.\n\nGo to System Settings → Privacy & Security → Full Disk Access and enable MacSweep.")
        }
    }

    // MARK: - Landing
    private var landingScreen: some View {
        VStack(spacing: 0) {
            landingHeader
            ToolLandingView(
                section: .applications,
                subtitle: "Completely uninstall apps and their hidden leftovers,\nor reset them to their original state.",
                actionLabel: "Scan",
                onAction: {
                    engine.hasScanned = true
                    navManager.navigate(to: .applications, subState: "scanning")
                    engine.scanAll()
                }
            )
        }
    }

    private var landingHeader: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Button {
                        if !navManager.goBackToPreviousSection() {
                            navManager.goBack()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(navManager.canGoBack ? DS.textSecondary : DS.textMuted.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .background(DS.bgElevated.opacity(0.6))
                            .overlay(Circle().strokeBorder(DS.borderSubtle, lineWidth: 1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!navManager.canGoBack)

                    Button {
                        if !navManager.goForwardToNextSection() {
                            navManager.goForward()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(navManager.canGoForward ? DS.textSecondary : DS.textMuted.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .background(DS.bgElevated.opacity(0.6))
                            .overlay(Circle().strokeBorder(DS.borderSubtle, lineWidth: 1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!navManager.canGoForward)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            Divider().background(DS.borderSubtle.opacity(0.5))
        }
    }

    // MARK: - Header
    var appsHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Button {
                        if engine.isScanning {
                            engine.cancelScan()
                        }
                        // Keep back behavior consistent with other tools:
                        // first return to this tool's landing state, then navigate out.
                        if engine.hasScanned {
                            engine.hasScanned = false
                            return
                        }
                        if !navManager.goBackToPreviousSection() {
                            navManager.goBack()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DS.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(DS.bgElevated.opacity(0.6))
                            .overlay(Circle().strokeBorder(DS.borderSubtle, lineWidth: 1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        // Forward action if needed
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DS.textMuted.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .background(DS.bgElevated.opacity(0.6))
                            .overlay(Circle().strokeBorder(DS.borderSubtle, lineWidth: 1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                }

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [Color(hex: "6A11CB"), Color(hex: "2575FC")],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Applications Manager")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(DS.textPrimary)
                        Text("\(engine.apps.count) total apps")
                            .font(.system(size: 10))
                            .foregroundColor(DS.textMuted)
                    }
                }

                Spacer()
                
                if !engine.isScanning {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ByteCountFormatter.string(fromByteCount: engine.totalSize, countStyle: .file))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "6A11CB"))
                        Text("Total potential space")
                            .font(.system(size: 9))
                            .foregroundColor(DS.textMuted)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            Divider().background(DS.borderSubtle.opacity(0.5))
        }
    }

    // MARK: - App List
    var appsList: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("Search apps…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // Filter chips — wrap into rows so all visible
            let columns = [GridItem(.adaptive(minimum: 60, maximum: 100), spacing: 4)]
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(AppFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { activeFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 10, weight: activeFilter == filter ? .bold : .medium))
                            .foregroundColor(activeFilter == filter ? .white : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule().fill(activeFilter == filter
                                    ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "6A11CB"), Color(hex: "2575FC")], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Color.gray.opacity(0.12)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // Sort picker
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Picker("", selection: $activeSort) {
                    ForEach(AppSort.allCases, id: \.self) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // App count
            HStack {
                Text("\(filteredApps.count) apps")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 4)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(filteredApps) { app in
                        AppListRow(
                            app: app,
                            isSelected: selectedAppId == app.id,
                            showLastUsed: activeFilter == .unusedApps,
                            onTap: {
                                selectedAppId = app.id
                                activeDetailTab = .leftovers
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 260)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - App Detail (Tabbed)
    func appDetailView(app: InstalledApp) -> some View {
        VStack(spacing: 0) {
            // App header with Open/Reveal
            HStack(spacing: 14) {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable().frame(width: 48, height: 48).cornerRadius(10)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Color(hex: "6A11CB"), Color(hex: "2575FC")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "app.fill").font(.system(size: 22)).foregroundColor(.white))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).font(.system(size: 16, weight: .bold))
                    Text("v\(app.version)  •  \(app.sizeFormatted)").font(.system(size: 11)).foregroundColor(.secondary)
                    Text(app.bundleId).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
                Button { NSWorkspace.shared.open(URL(fileURLWithPath: app.path)) } label: {
                    HStack(spacing: 3) { Image(systemName: "play.fill").font(.system(size: 8)); Text("Open").font(.system(size: 10, weight: .medium)) }
                        .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 5).background(Color(hex: "2575FC").cornerRadius(5))
                }.buttonStyle(.plain)
                Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)]) } label: {
                    HStack(spacing: 3) { Image(systemName: "folder").font(.system(size: 8)); Text("Reveal").font(.system(size: 10, weight: .medium)) }
                        .foregroundColor(.secondary).padding(.horizontal, 8).padding(.vertical, 5).background(Color.gray.opacity(0.15).cornerRadius(5))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.vertical, 14).background(Color(NSColor.controlBackgroundColor))

            // Tab bar
            HStack(spacing: 0) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button { withAnimation(.easeInOut(duration: 0.12)) { activeDetailTab = tab } } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: tabIcon(tab)).font(.system(size: 10))
                                Text(tab.rawValue).font(.system(size: 11, weight: activeDetailTab == tab ? .semibold : .regular))
                            }
                            .foregroundColor(activeDetailTab == tab ? Color(hex: "6A11CB") : .secondary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            Rectangle().fill(activeDetailTab == tab ? Color(hex: "6A11CB") : Color.clear).frame(height: 2)
                        }
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tab content
            switch activeDetailTab {
            case .leftovers:  leftoversTabContent(app: app)
            case .appData:    appDataTabContent(app: app)
            case .scratchDisks: scratchDisksTabContent(app: app)
            case .updates: updatesTabContent(app: app)
            case .appInfo:    appInfoTabContent(app: app)
            }
        }
    }

    private func tabIcon(_ tab: DetailTab) -> String {
        switch tab {
        case .leftovers: return "trash"
        case .appData: return "externaldrive.fill"
        case .scratchDisks: return "internaldrive"
        case .updates: return "arrow.down.circle"
        case .appInfo: return "info.circle"
        }
    }

    // MARK: - Leftovers Tab
    @ViewBuilder func leftoversTabContent(app: InstalledApp) -> some View {
        if app.leftovers.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundColor(AppTheme.success.opacity(0.6))
                Text("No leftover data found").font(.callout).foregroundColor(.secondary)
                Text("This application has no detectable leftover files.").font(.caption).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("\(app.leftovers.count) leftover items").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    Spacer()
                    Button {
                        for gi in engine.apps.indices where engine.apps[gi].id == app.id {
                            for li in engine.apps[gi].leftovers.indices { engine.apps[gi].leftovers[li].isSelected.toggle() }
                        }
                    } label: { Text("Toggle All").font(.system(size: 10, weight: .medium)).foregroundColor(AppTheme.accent) }.buttonStyle(.plain)
                }.padding(.horizontal, 16).padding(.vertical, 8)
                Divider()
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(engine.apps.first(where: { $0.id == app.id })?.leftovers ?? []) { leftover in
                            AppManagerLeftoverRow(item: leftover) { engine.toggleLeftover(appId: app.id, leftoverId: leftover.id) }
                            Divider().padding(.leading, 56)
                        }
                    }.padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - App Data Tab
    @ViewBuilder func appDataTabContent(app: InstalledApp) -> some View {
        let cats = app.dataCategories
        if cats.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.checkmark").font(.system(size: 36)).foregroundColor(AppTheme.success.opacity(0.6))
                Text("No app data found").font(.callout).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    // Summary header
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Data Breakdown")
                                .font(.system(size: 14, weight: .bold))
                            Text("Last used: \(app.lastUsedFormatted)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        let totalData = cats.reduce(Int64(0)) { $0 + $1.size }
                        Text(ByteCountFormatter.string(fromByteCount: totalData, countStyle: .file))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().padding(.horizontal, 16)

                    ForEach(Array(cats.enumerated()), id: \.offset) { _, cat in
                        let maxSize = cats.map(\.size).max() ?? 1
                        HStack(spacing: 12) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(cat.name)
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: cat.size, countStyle: .file))
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.gray.opacity(0.15))
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(LinearGradient(colors: AppSection.applications.gradient, startPoint: .leading, endPoint: .trailing))
                                            .frame(width: g.size.width * CGFloat(cat.size) / CGFloat(maxSize))
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Scratch Disks Tab
    @ViewBuilder func scratchDisksTabContent(app: InstalledApp) -> some View {
        let items = engine.scratchDiskItems(for: app)
        let _ = scratchRefreshId // force SwiftUI to re-evaluate when this changes
        if items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "internaldrive").font(.system(size: 36)).foregroundColor(.secondary.opacity(0.4))
                Text("No scratch disk data found").font(.callout).foregroundColor(.secondary)
                Text("This app doesn't have temporary or scratch files.").font(.caption).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack {
                    let totalSize = items.reduce(Int64(0)) { $0 + $1.size }
                    Text("\(items.count) items · \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                        .font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    Spacer()
                    Button {
                        showBatchScratchConfirm = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Clean All Scratch")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.orange.cornerRadius(4))
                    }.buttonStyle(.plain)
                    .confirmationDialog("Clean All Scratch Data?", isPresented: $showBatchScratchConfirm, titleVisibility: .visible) {
                        Button("Delete All Temporary Data for \(app.name)", role: .destructive) {
                            var cleaned: Int64 = 0
                            var failed = 0
                            for item in items {
                                if engine.deleteScratchItem(path: item.path) {
                                    cleaned += item.size
                                } else {
                                    failed += 1
                                }
                            }
                            scratchRefreshId = UUID()
                            if failed == 0 {
                                resultMessage = "Cleaned \(ByteCountFormatter.string(fromByteCount: cleaned, countStyle: .file)) of scratch data from \(app.name)."
                            } else {
                                resultMessage = "Cleaned \(ByteCountFormatter.string(fromByteCount: cleaned, countStyle: .file)) from \(app.name), \(failed) item(s) could not be removed."
                            }
                            showResult = true
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }.padding(.horizontal, 16).padding(.vertical, 8)
                Divider()
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)).frame(width: 36, height: 36)
                                    Image(systemName: "internaldrive.fill").font(.system(size: 15)).foregroundColor(.orange)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.system(size: 13, weight: .medium))
                                    Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.orange)
                                Button {
                                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: (item.path as NSString).deletingLastPathComponent)
                                } label: {
                                    Image(systemName: "folder").font(.system(size: 13)).foregroundColor(.secondary)
                                }.buttonStyle(.plain).help("Reveal in Finder")
                                Button {
                                    let size = item.size
                                    let name = item.name
                                    if engine.deleteScratchItem(path: item.path) {
                                        scratchRefreshId = UUID()
                                        resultMessage = "Cleaned \(name) (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))"
                                    } else {
                                        resultMessage = "Failed to clean \(name). It may be protected or in use."
                                    }
                                    showResult = true
                                } label: {
                                    Image(systemName: "trash").font(.system(size: 13)).foregroundColor(.red.opacity(0.8))
                                }.buttonStyle(.plain).help("Delete this item")
                            }.padding(10).background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.windowBackgroundColor)))
                        }
                    }.padding(16)
                }
            }
        }
    }

    // MARK: - Updates Tab
    @ViewBuilder func updatesTabContent(app: InstalledApp) -> some View {
        if let info = app.updateInfo {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Update available card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 20)).foregroundColor(.orange)
                            Text("Update Available").font(.system(size: 16, weight: .bold))
                            Spacer()
                        }
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Installed").font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                                Text("v\(app.version)").font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundColor(.red.opacity(0.8))
                            }
                            Image(systemName: "arrow.right").foregroundColor(.secondary).padding(.horizontal, 8)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Latest").font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                                Text("v\(info.latestVersion)").font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundColor(.green)
                            }
                            Spacer()
                        }
                        if !info.releaseDate.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar").font(.system(size: 10)).foregroundColor(.secondary)
                                Text("Released: \(info.releaseDate)").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                        }
                        if info.fileSizeBytes > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.doc").font(.system(size: 10)).foregroundColor(.secondary)
                                Text("Update size: \(ByteCountFormatter.string(fromByteCount: info.fileSizeBytes, countStyle: .file))")
                                    .font(.system(size: 11)).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))

                    // Release notes
                    if !info.releaseNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("What's New").font(.system(size: 13, weight: .bold))
                            Text(info.releaseNotes)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(20)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.windowBackgroundColor)))
                    }

                    // Source info
                    HStack(spacing: 6) {
                        Image(systemName: app.isFromAppStore ? "applelogo" : "globe").font(.system(size: 11))
                        Text(app.isFromAppStore ? "Mac App Store" : "Third Party").font(.system(size: 11, weight: .medium))
                    }.foregroundColor(.secondary)

                    // Actions
                    HStack(spacing: 8) {
                        if app.isFromAppStore, let url = URL(string: info.trackViewUrl) {
                            Button { NSWorkspace.shared.open(url) } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Update in App Store")
                                }
                                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(LinearGradient(colors: [Color(hex: "2575FC"), Color(hex: "6A11CB")], startPoint: .leading, endPoint: .trailing).cornerRadius(8))
                            }.buttonStyle(.plain)
                        }
                        Button {
                            engine.checkForUpdate(appId: app.id)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Re-check")
                            }
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.primary)
                            .padding(.horizontal, 10).padding(.vertical, 7).background(Color.gray.opacity(0.15).cornerRadius(6))
                        }.buttonStyle(.plain)
                    }
                }.padding(20)
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 40)).foregroundColor(.green.opacity(0.6))
                Text("Up to Date").font(.system(size: 16, weight: .bold))
                Text(app.isFromAppStore ? "This app is from the Mac App Store and has no updates available." : "This is a third-party app. Update checks via the developer's website.")
                    .font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 30)

                Button {
                    engine.checkForUpdate(appId: app.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Check for Update")
                    }
                    .font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(hex: "2575FC").cornerRadius(8))
                }.buttonStyle(.plain)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - App Info Tab
    func appInfoTabContent(app: InstalledApp) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                appInfoRow(label: "Name", value: app.name)
                appInfoRow(label: "Bundle ID", value: app.bundleId)
                appInfoRow(label: "Version", value: app.version)
                appInfoRow(label: "Size", value: app.sizeFormatted)
                appInfoRow(label: "Path", value: app.path)
                appInfoRow(label: "Architecture", value: appArchitecture(path: app.path))
                appInfoRow(label: "Code Signed", value: appCodeSigned(path: app.path) ? "✅ Yes" : "❌ No")
                appInfoRow(label: "Last Opened", value: appLastOpened(path: app.path))
                Divider()
                Text("Quick Actions").font(.system(size: 13, weight: .bold))
                HStack(spacing: 8) {
                    Button { NSWorkspace.shared.open(URL(fileURLWithPath: app.path)) } label: {
                        Label("Launch App", systemImage: "play.fill").font(.system(size: 11, weight: .medium)).foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(LinearGradient(colors: [Color(hex: "2575FC"), Color(hex: "6A11CB")], startPoint: .leading, endPoint: .trailing).cornerRadius(6))
                    }.buttonStyle(.plain)
                    Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)]) } label: {
                        Label("Show in Finder", systemImage: "folder").font(.system(size: 11, weight: .medium)).foregroundColor(.primary)
                            .padding(.horizontal, 12).padding(.vertical, 6).background(Color.gray.opacity(0.15).cornerRadius(6))
                    }.buttonStyle(.plain)
                    if !app.bundleId.isEmpty {
                        Button {
                            if let encoded = app.bundleId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                               let url = URL(string: "https://www.google.com/search?q=\(encoded)") { NSWorkspace.shared.open(url) }
                        } label: {
                            Label("Search Online", systemImage: "globe").font(.system(size: 11, weight: .medium)).foregroundColor(.primary)
                                .padding(.horizontal, 12).padding(.vertical, 6).background(Color.gray.opacity(0.15).cornerRadius(6))
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20)
        }
    }

    private func appInfoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).frame(width: 100, alignment: .leading)
            Text(value).font(.system(size: 12, design: .monospaced)).foregroundColor(.primary).textSelection(.enabled)
            Spacer()
        }
    }
    private func appArchitecture(path: String) -> String {
        let execPath = "\(path)/Contents/MacOS"
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: execPath), let exec = contents.first else { return "Unknown" }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/file"); p.arguments = ["\(execPath)/\(exec)"]
        let pipe = Pipe(); p.standardOutput = pipe
        let s1 = DispatchSemaphore(value: 0); p.terminationHandler = { _ in s1.signal() }
        try? p.run(); _ = s1.wait(timeout: .now() + 5.0); if p.isRunning { p.terminate() }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if out.contains("arm64") && out.contains("x86_64") { return "Universal" }
        if out.contains("arm64") { return "Apple Silicon" }
        if out.contains("x86_64") { return "Intel" }
        return "Unknown"
    }
    private func appCodeSigned(path: String) -> Bool {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); p.arguments = ["-v", path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        let s2 = DispatchSemaphore(value: 0); p.terminationHandler = { _ in s2.signal() }
        try? p.run(); _ = s2.wait(timeout: .now() + 5.0); if p.isRunning { p.terminate() }
        return p.terminationStatus == 0
    }
    private func appLastOpened(path: String) -> String {
        guard let vals = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.contentAccessDateKey]),
              let date = vals.contentAccessDate else { return "Unknown" }
        let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .short; return fmt.string(from: date)
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill").font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
            Text("Select an application to view details").foregroundColor(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer
    var appsFooter: some View {
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

            // Batch clean all
            let appsWithLeftovers = engine.apps.filter { !$0.leftovers.isEmpty }.count
            if appsWithLeftovers > 0 {
                Button { showBatchCleanConfirm = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Clean All Leftovers")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(LinearGradient(colors: [Color(hex: "F7971E"), Color(hex: "FFD200")], startPoint: .leading, endPoint: .trailing).cornerRadius(8))
                }
                .buttonStyle(.plain)
                .confirmationDialog("Clean All App Leftovers?", isPresented: $showBatchCleanConfirm, titleVisibility: .visible) {
                    Button("Clean Selected Leftovers from \(appsWithLeftovers) Apps", role: .destructive) {
                        let cleaned = engine.batchCleanAllLeftovers()
                        if cleaned == 0 {
                            showFDAAlert = true
                        } else {
                            resultMessage = "Cleaned \(ByteCountFormatter.string(fromByteCount: cleaned, countStyle: .file)) from \(appsWithLeftovers) apps."
                            showResult = true
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove all selected leftover data (caches, logs) from \(appsWithLeftovers) apps.")
                }
            }

            Spacer()

            if let app = selectedApp {
                let leftoverSize = app.leftovers.filter(\.isSelected).reduce(Int64(0)) { $0 + $1.size }
                let leftoverCount = app.leftovers.filter(\.isSelected).count
                if leftoverCount > 0 {
                    Text("\(leftoverCount) leftovers (\(ByteCountFormatter.string(fromByteCount: leftoverSize, countStyle: .file)))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Reset button
                Button {
                    showResetConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset App")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(leftoverCount == 0
                                  ? AnyShapeStyle(Color.gray)
                                  : AnyShapeStyle(LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                                                 startPoint: .leading, endPoint: .trailing)))
                    )
                }
                .buttonStyle(.plain)
                .disabled(leftoverCount == 0)
                .confirmationDialog("Reset \(app.name)?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                    Button("Reset (Delete Leftovers)", role: .destructive) {
                        let cleaned = engine.resetApp(appId: app.id)
                        if cleaned == 0 {
                            showFDAAlert = true
                        } else {
                            resultMessage = "Cleaned \(ByteCountFormatter.string(fromByteCount: cleaned, countStyle: .file)) from \(app.name)."
                            showResult = true
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }

                // Clear All Data (Deep Clean)
                Button { showClearAllConfirm = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Clear All Data")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LinearGradient(colors: [Color(hex: "FF512F"), Color(hex: "DD2476")], startPoint: .leading, endPoint: .trailing).cornerRadius(8))
                }
                .buttonStyle(.plain)
                .confirmationDialog("Clear All App Data for \(app.name)?", isPresented: $showClearAllConfirm, titleVisibility: .visible) {
                    Button("Deep Clean (Delete Leftovers + Scratch)", role: .destructive) {
                        let cleaned = engine.clearAllAppData(appId: app.id)
                        if cleaned == 0 {
                            showFDAAlert = true
                        } else {
                            resultMessage = "Deep cleaned \(ByteCountFormatter.string(fromByteCount: cleaned, countStyle: .file)) from \(app.name)."
                            showResult = true
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("This will move ALL detected caches, logs, preferences, and temporary files for this app to Trash when possible.") }

                // Uninstall button
                Button {
                    showUninstallConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Uninstall")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color(hex: "E94560"), Color(hex: "D0021B")],
                                                 startPoint: .leading, endPoint: .trailing))
                    )
                }
                .buttonStyle(.plain)
                .confirmationDialog("Uninstall \(app.name)?", isPresented: $showUninstallConfirm, titleVisibility: .visible) {
                    Button("Uninstall (Move to Trash)", role: .destructive) {
                        let success = engine.uninstallApp(appId: app.id)
                        if success {
                            resultMessage = "Moved \(app.name) to Trash and cleaned selected leftovers."
                            selectedAppId = nil
                        } else {
                            resultMessage = "Could not uninstall \(app.name). It may be running."
                        }
                        showResult = true
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - App List Row
struct AppListRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let showLastUsed: Bool
    let onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: "app.fill").font(.system(size: 13)).foregroundColor(.secondary))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    if showLastUsed {
                        Text("Last used: \(app.lastUsedFormatted)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(app.sizeFormatted)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if !app.leftovers.isEmpty {
                    Text("\(app.leftovers.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "6A11CB").cornerRadius(4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: "6A11CB").opacity(0.08) : (hovered ? Color.gray.opacity(0.06) : Color.clear))
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

// MARK: - Leftover Row
struct AppManagerLeftoverRow: View {
    let item: AppLeftoverItem
    let onToggle: () -> Void
    @State private var hovered = false

    var safetyColor: Color {
        switch item.kind {
        case .caches, .logs:     return AppTheme.success
        case .preferences:       return AppTheme.warning
        case .appSupport, .containers, .savedState: return AppTheme.warning
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
                    Text(item.kind.rawValue)
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

// MARK: - Applications Engine
@MainActor
class ApplicationsEngine: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var currentScanPath = ""

    var totalSize: Int64 { apps.reduce(0) { $0 + $1.size } }

    private let fm = FileManager.default
    private var home: String { fm.homeDirectoryForCurrentUser.path }

    private func removeItemSafely(atPath path: String) throws {
        let url = URL(fileURLWithPath: path)
        do {
            try fm.trashItem(at: url, resultingItemURL: nil)
        } catch {
            try fm.removeItem(at: url)
        }
    }

    func scanAll() {
        isScanning = true
        apps = []

        Task {
            let scanned = await scanApplications()
            await MainActor.run {
                apps = scanned
                isScanning = false
            }
            // Auto-check for updates in background
            await checkAllForUpdates()
        }
    }

    func cancelScan() {
        hasScanned = true
        isScanning = false
    }

    // MARK: - Update Checker (iTunes Search API)
    func checkForUpdate(appId: UUID) {
        guard let ai = apps.firstIndex(where: { $0.id == appId }) else { return }
        let app = apps[ai]
        guard !app.bundleId.isEmpty else { return }

        Task {
            let info = await Self.lookupUpdate(bundleId: app.bundleId, installedVersion: app.version)
            await MainActor.run {
                if let idx = self.apps.firstIndex(where: { $0.id == appId }) {
                    self.apps[idx].updateInfo = info
                }
            }
        }
    }

    func checkAllForUpdates() async {
        // Only check App Store apps (they have receipts)
        let appStoreApps = await MainActor.run { apps.filter { $0.isFromAppStore } }

        for app in appStoreApps {
            let info = await Self.lookupUpdate(bundleId: app.bundleId, installedVersion: app.version)
            if let info = info {
                await MainActor.run {
                    if let idx = self.apps.firstIndex(where: { $0.id == app.id }) {
                        self.apps[idx].updateInfo = info
                    }
                }
            }
        }
    }

    nonisolated static func lookupUpdate(bundleId: String, installedVersion: String) async -> AppUpdateInfo? {
        guard let encoded = bundleId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(encoded)&entity=macSoftware&limit=1") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let result = results.first,
                  let latestVersion = result["version"] as? String else { return nil }

            // Compare versions — only report if latest > installed
            if latestVersion.compare(installedVersion, options: .numeric) != .orderedDescending { return nil }

            let releaseNotes = result["releaseNotes"] as? String ?? ""
            let releaseDate = result["currentVersionReleaseDate"] as? String ?? ""
            let trackViewUrl = result["trackViewUrl"] as? String ?? ""
            let fileSizeStr = result["fileSizeBytes"] as? String ?? "0"
            let fileSizeBytes = Int64(fileSizeStr) ?? 0

            // Format date
            var formattedDate = releaseDate
            let isoFmt = ISO8601DateFormatter()
            if let date = isoFmt.date(from: releaseDate) {
                let displayFmt = DateFormatter()
                displayFmt.dateStyle = .medium
                formattedDate = displayFmt.string(from: date)
            }

            return AppUpdateInfo(
                latestVersion: latestVersion,
                releaseNotes: releaseNotes,
                releaseDate: formattedDate,
                trackViewUrl: trackViewUrl,
                fileSizeBytes: fileSizeBytes
            )
        } catch {
            return nil
        }
    }

    func toggleLeftover(appId: UUID, leftoverId: UUID) {
        guard let ai = apps.firstIndex(where: { $0.id == appId }),
              let li = apps[ai].leftovers.firstIndex(where: { $0.id == leftoverId }) else { return }
        apps[ai].leftovers[li].isSelected.toggle()
    }

    func resetApp(appId: UUID) -> Int64 {
        guard let ai = apps.firstIndex(where: { $0.id == appId }) else { return 0 }
        var cleaned: Int64 = 0
        for leftover in apps[ai].leftovers where leftover.isSelected {
            do {
                try removeItemSafely(atPath: leftover.path)
                cleaned += leftover.size
            } catch {}
        }
        // Rescan leftovers for this app
        let bundleId = apps[ai].bundleId
        let name = apps[ai].name
        apps[ai].leftovers = scanLeftoversSync(bundleId: bundleId, appName: name)
        return cleaned
    }

    func uninstallApp(appId: UUID) -> Bool {
        guard let ai = apps.firstIndex(where: { $0.id == appId }) else { return false }
        let app = apps[ai]

        // Move app bundle to Trash
        do {
            try fm.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
        } catch {
            return false
        }

        // Delete selected leftovers
        for leftover in app.leftovers where leftover.isSelected {
            try? removeItemSafely(atPath: leftover.path)
        }

        apps.remove(at: ai)
        return true
    }

    // MARK: - Scratch Disk Scanner
    struct ScratchDiskItem: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let size: Int64
    }

    func scratchDiskItems(for app: InstalledApp) -> [ScratchDiskItem] {
        let fm = FileManager.default
        var items: [ScratchDiskItem] = []
        let bundleId = app.bundleId
        let appName = app.name

        // Scratch/temp paths to check per app
        let candidates: [(String, String)] = [
            ("\(home)/Library/Application Support/Adobe/\(appName)/Scratch", "Adobe Scratch Disk"),
            ("\(home)/Library/Application Support/\(appName)/Temp", "App Temp Files"),
            ("\(home)/Library/Application Support/\(bundleId)/tmp", "App Tmp"),
            ("\(home)/Library/Application Support/\(appName)/Cache", "App Cache"),
            ("\(home)/Library/Caches/\(bundleId)", "Caches (ID)"),
            ("\(home)/Library/Caches/\(appName)", "Caches (Name)"),
            ("/tmp/\(bundleId)", "System Temp"),
        ]

        // Xcode-specific
        if bundleId.contains("com.apple.dt.Xcode") || appName == "Xcode" {
            let derivedData = "\(home)/Library/Developer/Xcode/DerivedData"
            if fm.fileExists(atPath: derivedData) {
                let sz = ScanEngine.calcSize(path: derivedData)
                if sz > 0 { items.append(ScratchDiskItem(name: "Xcode DerivedData", path: derivedData, size: sz)) }
            }
            let archives = "\(home)/Library/Developer/Xcode/Archives"
            if fm.fileExists(atPath: archives) {
                let sz = ScanEngine.calcSize(path: archives)
                if sz > 0 { items.append(ScratchDiskItem(name: "Xcode Archives", path: archives, size: sz)) }
            }
        }

        for (path, name) in candidates {
            guard fm.fileExists(atPath: path) else { continue }
            let sz = ScanEngine.calcSize(path: path)
            if sz > 0 { items.append(ScratchDiskItem(name: name, path: path, size: sz)) }
        }

        return items.sorted { $0.size > $1.size }
    }

    func deleteScratchItem(path: String) -> Bool {
        do {
            try removeItemSafely(atPath: path)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Batch Clean All Leftovers
    func batchCleanAllLeftovers() -> Int64 {
        var totalCleaned: Int64 = 0
        for ai in apps.indices {
            for leftover in apps[ai].leftovers where leftover.isSelected {
                do {
                    try removeItemSafely(atPath: leftover.path)
                    totalCleaned += leftover.size
                } catch {}
            }
            let bundleId = apps[ai].bundleId
            let name = apps[ai].name
            apps[ai].leftovers = scanLeftoversSync(bundleId: bundleId, appName: name)
        }
        return totalCleaned
    }

    func clearAllAppData(appId: UUID) -> Int64 {
        guard let ai = apps.firstIndex(where: { $0.id == appId }) else { return 0 }
        let app = apps[ai]
        var cleaned: Int64 = 0

        // 1. Delete all detected leftovers (even if not selected)
        for leftover in app.leftovers {
            do {
                try removeItemSafely(atPath: leftover.path)
                cleaned += leftover.size
            } catch {}
        }

        // 2. Delete all scratch disk items
        let scratch = scratchDiskItems(for: app)
        for item in scratch {
            do {
                try removeItemSafely(atPath: item.path)
                cleaned += item.size
            } catch {}
        }

        // Rescan leftovers
        apps[ai].leftovers = scanLeftoversSync(bundleId: app.bundleId, appName: app.name)
        return cleaned
    }

    // MARK: - Scanning
    private func scanApplications() async -> [InstalledApp] {
        await Task.detached(priority: .userInitiated) { [home] in
            let fm = FileManager.default
            var results: [InstalledApp] = []
            var seenBundleIds = Set<String>()

            // All directories where macOS apps can live
            let dirs = [
                "/Applications",
                "\(home)/Applications",
                "/System/Applications",
                "/System/Applications/Utilities",
                "/Applications/Utilities",
            ]

            // Homebrew Cask directories
            let homebrewCask = "/opt/homebrew/Caskroom"
            let intelHomebrewCask = "/usr/local/Caskroom"

            // Recursive .app finder
            func findApps(in directory: String, maxDepth: Int = 3, currentDepth: Int = 0) {
                guard currentDepth < maxDepth,
                      fm.fileExists(atPath: directory),
                      let contents = try? fm.contentsOfDirectory(atPath: directory) else { return }

                for item in contents {
                    let fullPath = "\(directory)/\(item)"

                    if item.hasSuffix(".app") {
                        let plistPath = "\(fullPath)/Contents/Info.plist"
                        guard fm.fileExists(atPath: plistPath),
                              let data = fm.contents(atPath: plistPath),
                              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                        else { continue }

                        let bundleId = plist["CFBundleIdentifier"] as? String ?? ""

                        // Skip duplicates
                        if !bundleId.isEmpty && seenBundleIds.contains(bundleId) { continue }
                        if !bundleId.isEmpty { seenBundleIds.insert(bundleId) }

                        let name = plist["CFBundleName"] as? String
                            ?? plist["CFBundleDisplayName"] as? String
                            ?? item.replacingOccurrences(of: ".app", with: "")
                        let version = plist["CFBundleShortVersionString"] as? String ?? "—"

                        let icon = NSWorkspace.shared.icon(forFile: fullPath)
                        icon.size = NSSize(width: 48, height: 48)

                        let size = ScanEngine.calcSize(path: fullPath)

                        let leftovers = ApplicationsEngine.scanLeftoversStatic(
                            bundleId: bundleId, appName: name, home: home
                        )

                        let lastUsed = (try? URL(fileURLWithPath: fullPath).resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate

                        results.append(InstalledApp(
                            name: name,
                            bundleId: bundleId,
                            version: version,
                            path: fullPath,
                            size: size,
                            icon: icon,
                            leftovers: leftovers,
                            lastUsed: lastUsed
                        ))
                    } else {
                        // Recurse into subdirectories (skip hidden dirs and .app internals)
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: fullPath, isDirectory: &isDir),
                           isDir.boolValue,
                           !item.hasPrefix("."),
                           item != "Contents" {
                            findApps(in: fullPath, maxDepth: maxDepth, currentDepth: currentDepth + 1)
                        }
                    }
                }
            }

            // Scan all standard directories
            for dir in dirs {
                findApps(in: dir, maxDepth: 2)
            }

            // Scan Homebrew Cask (apps nested deeper)
            findApps(in: homebrewCask, maxDepth: 4)
            findApps(in: intelHomebrewCask, maxDepth: 4)

            return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value
    }

    private func scanLeftoversSync(bundleId: String, appName: String) -> [AppLeftoverItem] {
        ApplicationsEngine.scanLeftoversStatic(bundleId: bundleId, appName: appName, home: home)
    }

    nonisolated static func scanLeftoversStatic(bundleId: String, appName: String, home: String) -> [AppLeftoverItem] {
        let fm = FileManager.default
        var leftovers: [AppLeftoverItem] = []

        let candidates: [(String, String, String, AppLeftoverItem.Kind)] = [
            ("\(home)/Library/Application Support/\(appName)", "App Support", "folder.fill", .appSupport),
            ("\(home)/Library/Application Support/\(bundleId)", "App Support (ID)", "folder.fill", .appSupport),
            ("\(home)/Library/Caches/\(bundleId)", "Caches", "internaldrive", .caches),
            ("\(home)/Library/Preferences/\(bundleId).plist", "Preferences", "gearshape", .preferences),
            ("\(home)/Library/Logs/\(appName)", "Logs", "doc.text", .logs),
            ("\(home)/Library/Containers/\(bundleId)", "Container", "shippingbox", .containers),
            ("\(home)/Library/Saved Application State/\(bundleId).savedState", "Saved State", "clock.arrow.circlepath", .savedState),
            ("\(home)/Library/HTTPStorages/\(bundleId)", "HTTP Storage", "network", .caches),
            ("\(home)/Library/WebKit/\(bundleId)", "WebKit Data", "globe", .caches),
            // Enhanced scanning
            ("\(home)/Library/Group Containers/\(bundleId)", "Group Container", "rectangle.stack", .containers),
            ("\(home)/Library/Cookies/\(bundleId).binarycookies", "Cookies", "circle.grid.3x3", .caches),
        ]

        for (path, name, icon, kind) in candidates {
            guard fm.fileExists(atPath: path) else { continue }
            let size = ScanEngine.calcSize(path: path)
            guard size > 0 else { continue }
            leftovers.append(AppLeftoverItem(
                name: name,
                path: path,
                size: size,
                icon: icon,
                kind: kind,
                isSelected: kind == .caches || kind == .logs
            ))
        }

        // Check for crash reports
        let crashDir = "\(home)/Library/Logs/DiagnosticReports"
        if fm.fileExists(atPath: crashDir),
           let crashFiles = try? fm.contentsOfDirectory(atPath: crashDir) {
            let matchingCrashes = crashFiles.filter { $0.contains(appName) || $0.contains(bundleId) }
            if !matchingCrashes.isEmpty {
                var totalCrashSize: Int64 = 0
                for f in matchingCrashes { totalCrashSize += ScanEngine.calcSize(path: "\(crashDir)/\(f)") }
                if totalCrashSize > 0 {
                    leftovers.append(AppLeftoverItem(
                        name: "Crash Reports (\(matchingCrashes.count))",
                        path: crashDir,
                        size: totalCrashSize,
                        icon: "exclamationmark.triangle",
                        kind: .logs,
                        isSelected: true
                    ))
                }
            }
        }

        return leftovers.sorted { $0.size > $1.size }
    }
}

// MARK: - Models
struct AppUpdateInfo {
    let latestVersion: String
    let releaseNotes: String
    let releaseDate: String
    let trackViewUrl: String // App Store link
    let fileSizeBytes: Int64
}

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
    let version: String
    let path: String
    let size: Int64
    let icon: NSImage?
    var leftovers: [AppLeftoverItem]
    var updateInfo: AppUpdateInfo?
    var lastUsed: Date?

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var leftoverSize: Int64 {
        leftovers.reduce(0) { $0 + $1.size }
    }

    var isFromAppStore: Bool {
        FileManager.default.fileExists(atPath: "\(path)/Contents/_MASReceipt/receipt")
    }

    var lastUsedFormatted: String {
        guard let date = lastUsed else { return "Unknown" }
        let days = Int(-date.timeIntervalSinceNow / 86400)
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 30 { return "\(days) days ago" }
        if days < 365 { return "\(days / 30) months ago" }
        return "\(days / 365) years ago"
    }

    var dataCategories: [(name: String, kind: AppLeftoverItem.Kind, size: Int64, icon: String)] {
        let grouped = Dictionary(grouping: leftovers, by: \.kind)
        func sizeFor(_ k: AppLeftoverItem.Kind) -> Int64 {
            grouped[k]?.reduce(0) { $0 + $1.size } ?? 0
        }
        let all: [(name: String, kind: AppLeftoverItem.Kind, size: Int64, icon: String)] = [
            ("Caches", .caches, sizeFor(.caches), "archivebox"),
            ("Containers", .containers, sizeFor(.containers), "shippingbox"),
            ("App Support", .appSupport, sizeFor(.appSupport), "folder.fill"),
            ("Preferences", .preferences, sizeFor(.preferences), "gearshape"),
            ("Logs", .logs, sizeFor(.logs), "doc.text"),
            ("Saved State", .savedState, sizeFor(.savedState), "bookmark"),
        ]
        return all.filter { $0.size > 0 }
    }
}

struct AppLeftoverItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let icon: String
    let kind: Kind
    var isSelected: Bool

    enum Kind: String {
        case caches      = "Cache"
        case logs        = "Logs"
        case preferences = "Prefs"
        case appSupport  = "Support"
        case containers  = "Container"
        case savedState  = "State"
    }

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
