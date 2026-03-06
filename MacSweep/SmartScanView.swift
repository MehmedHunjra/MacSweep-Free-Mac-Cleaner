import SwiftUI

struct SmartScanView: View {
    @ObservedObject var scanEngine:  ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @ObservedObject var settings: AppSettings
    @State private var showConfirm = false
    @State private var showResult  = false
    @State private var showReview  = false

    var body: some View {
        VStack(spacing: 0) {
            if !scanEngine.isScanning && !scanEngine.scanComplete {
                landingScreen
            } else {
                // Toolbar/Header when scanning or showing results
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.title2)
                                .foregroundStyle(AppTheme.sectionGradient(.smartScan))
                            Text("Smart Scan")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                    }
                    Spacer()
                    if scanEngine.scanComplete {
                        Button("Review") {
                            showReview = true
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                        
                        Button("Configure") {
                            settings.settingsSectionRaw = "Scanning"
                            settings.mainSection = .settings
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    if !scanEngine.isScanning {
                        Button {
                            Task { await scanEngine.startScan() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Rescan")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.sectionGradient(.smartScan))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()

                if scanEngine.isScanning {
                    AnimatedScanView(scanEngine: scanEngine)
                } else if scanEngine.scanComplete {
                    ScanResultsView(
                        scanEngine: scanEngine,
                        cleanEngine: cleanEngine,
                        showConfirm: $showConfirm,
                        showResult: $showResult
                    )
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Landing
    private var landingScreen: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F0C29"), Color(hex: "302B63"), Color(hex: "24243E"), Color(hex: "0F0C29")],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 30)

                // 3D Glass Icon for Smart Scan
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(colors: [Color(hex: "4facfe").opacity(0.6), Color(hex: "00f2fe").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "4facfe").opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "A6FFCB")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.bottom, 28)

                Text("Smart Scan")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Your Mac's comprehensive health check.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 32)

                // Benefit List
                VStack(alignment: .leading, spacing: 14) {
                    benefitRow(icon: "shield.fill", text: "Remove tracking cookies & privacy risks")
                    benefitRow(icon: "trash.fill", text: "Delete system junk & application caches")
                    benefitRow(icon: "cpu.fill", text: "Optimize performance & free up RAM")
                    benefitRow(icon: "doc.text.fill", text: "Find large hidden files & old downloads")
                }
                .padding(.bottom, 54)

                ToolPrimaryActionButton(
                    title: "Scan",
                    colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")],
                    icon: "sparkles"
                ) {
                    Task { await scanEngine.startScan() }
                }

                Spacer(minLength: 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
        .alert("Clean Selected Files?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task {
                    await cleanEngine.clean(items: scanEngine.scanItems)
                    if cleanEngine.cleanedSize > 0 {
                        scanEngine.recordFreed(bytes: cleanEngine.cleanedSize, description: "Smart Scan cleanup")
                    }
                    await scanEngine.startScan()
                    showResult = true
                }
            }
        } message: {
            Text("This will permanently delete \(ByteCountFormatter.string(fromByteCount: scanEngine.selectedSize, countStyle: .file)) of selected files. This cannot be undone.")
        }
        .sheet(isPresented: $showResult) {
            CleanResultSheet(cleanEngine: cleanEngine, scanEngine: scanEngine, isPresented: $showResult)
        }
        .sheet(isPresented: $showReview) {
            ReviewManagerSheet(
                scanEngine: scanEngine,
                cleanEngine: cleanEngine,
                scope: .smartScan
            )
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.accent)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Scan Ready View
struct ScanReadyView: View {
    let section: AppSection
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: section.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            .opacity(0.1)
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .fill(
                        LinearGradient(colors: section.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            .opacity(0.2)
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: section.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(colors: section.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            Text("Ready to Scan")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("Click the button above to find junk files on your Mac.\nAll safe files will be selected automatically.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.body)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { pulse = true }
    }
}

// MARK: - Animated Scan View
struct AnimatedScanView: View {
    @ObservedObject var scanEngine: ScanEngine
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.gray.opacity(0.1), lineWidth: 8)
                    .frame(width: 180, height: 180)

                // Progress ring
                Circle()
                    .trim(from: 0, to: scanEngine.scanProgress)
                    .stroke(
                        LinearGradient(
                            colors: AppSection.smartScan.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.5), value: scanEngine.scanProgress)

                // Spinning indicator
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(AppTheme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(rotation))

                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(scanEngine.scanProgress * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.gradient)

                    if scanEngine.totalFoundSize > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: scanEngine.totalFoundSize, countStyle: .file))
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text("Scanning your Mac...")
                .font(.headline)

            Text(scanEngine.currentPath)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 400)

            // Found items counter
            if !scanEngine.scanItems.isEmpty {
                HStack(spacing: 16) {
                    StatBadge(
                        icon: "doc.fill",
                        value: "\(scanEngine.scanItems.count)",
                        label: "items found"
                    )
                    StatBadge(
                        icon: "internaldrive.fill",
                        value: ByteCountFormatter.string(fromByteCount: scanEngine.totalFoundSize, countStyle: .file),
                        label: "to clean"
                    )
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 14, weight: .bold, design: .rounded))
                Text(label).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.accent.opacity(0.08))
        )
    }
}

// MARK: - Scan Results View
struct ScanResultsView: View {
    @ObservedObject var scanEngine:  ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @Binding var showConfirm: Bool
    @Binding var showResult:  Bool

    let safeCategories: [ScanCategory] = [
        .userCaches, .logs, .browserCaches, .development, .tempFiles, .mailAttach
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack(spacing: 16) {
                SummaryPill(
                    icon: "magnifyingglass",
                    label: "Found",
                    value: ByteCountFormatter.string(fromByteCount: scanEngine.totalFoundSize, countStyle: .file),
                    color: AppTheme.accent
                )
                SummaryPill(
                    icon: "checkmark.circle.fill",
                    label: "Selected",
                    value: ByteCountFormatter.string(fromByteCount: scanEngine.selectedSize, countStyle: .file),
                    color: AppTheme.success
                )
                Spacer()
                GradientButton(
                    title: "Clean Selected",
                    icon: "trash.fill",
                    gradient: [AppTheme.danger, Color(hex: "FF5858")],
                    disabled: scanEngine.selectedSize == 0
                ) {
                    showConfirm = true
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Categories list
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(safeCategories, id: \.self) { category in
                        let items = scanEngine.itemsByCategory[category] ?? []
                        if !items.isEmpty {
                            CategoryCard(category: category, items: items, scanEngine: scanEngine)
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category:   ScanCategory
    let items:      [ScanItem]
    @ObservedObject var scanEngine: ScanEngine
    @State private var expanded = true

    var categoryTotal: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedCount: Int   { items.filter(\.isSelected).count }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(category.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: category.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(category.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue).font(.system(size: 14, weight: .semibold))
                        Text("\(items.count) item\(items.count == 1 ? "" : "s") \u{00B7} \(ByteCountFormatter.string(fromByteCount: categoryTotal, countStyle: .file))")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()

                    HStack(spacing: 6) {
                        Button("All")  { scanEngine.selectAll(in: category) }
                            .buttonStyle(.bordered).controlSize(.mini)
                        Button("None") { scanEngine.deselectAll(in: category) }
                            .buttonStyle(.bordered).controlSize(.mini)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.horizontal, 14)
                ForEach(items) { item in
                    ScanItemRow(item: item, scanEngine: scanEngine)
                    if item.id != items.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        )
    }
}

// MARK: - Scan Item Row
struct ScanItemRow: View {
    let item: ScanItem
    @ObservedObject var scanEngine: ScanEngine
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in scanEngine.toggleItem(item.id) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(item.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(item.sizeFormatted)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(minWidth: 60, alignment: .trailing)

            // Reveal in Finder
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            } label: {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.secondary.opacity(isHovered ? 1 : 0.5))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        .cornerRadius(6)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Summary Pill
struct SummaryPill: View {
    let icon:  String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundColor(.secondary)
                Text(value).font(.system(size: 14, weight: .bold, design: .rounded))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Gradient Button
struct GradientButton: View {
    let title: String
    let icon: String
    let gradient: [Color]
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: disabled ? [.gray] : gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Review Manager
enum ReviewScope {
    case smartScan
    case systemJunk
    case browser
    case appLeftovers
    case largeFiles

    var title: String {
        switch self {
        case .smartScan: return "Smart Scan Review"
        case .systemJunk: return "System Junk Review"
        case .browser: return "Browser Privacy Review"
        case .appLeftovers: return "App Leftovers Review"
        case .largeFiles: return "Large Files Review"
        }
    }

    var cleanupDescription: String {
        switch self {
        case .smartScan: return "Smart Scan cleanup"
        case .systemJunk: return "System Junk cleanup"
        case .browser: return "Browser cleanup"
        case .appLeftovers: return "App Leftovers cleanup"
        case .largeFiles: return "Large Files cleanup"
        }
    }

    var allowedCategories: Set<ScanCategory> {
        switch self {
        case .smartScan:
            return Set(ScanCategory.allCases)
        case .systemJunk:
            return [.userCaches, .logs, .tempFiles, .mailAttach]
        case .browser:
            return [.browserCaches]
        case .appLeftovers:
            return [.appLeftovers]
        case .largeFiles:
            return [.largeFiles]
        }
    }

    var scanMode: ScanMode {
        switch self {
        case .smartScan:
            return .smart
        case .systemJunk:
            return .categories([.userCaches, .logs, .tempFiles, .mailAttach])
        case .browser:
            return .categories([.browserCaches])
        case .appLeftovers:
            return .categories([.appLeftovers])
        case .largeFiles:
            return .categories([.largeFiles])
        }
    }
}

enum ReviewTab: String, CaseIterable, Identifiable {
    case all = "All Items"
    case cleanup = "Cleanup"
    case applications = "Applications"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .cleanup: return "sparkles.rectangle.stack.fill"
        case .applications: return "app.badge.fill"
        }
    }

    func includes(_ category: ScanCategory) -> Bool {
        switch self {
        case .all:
            return true
        case .cleanup:
            return [.userCaches, .logs, .browserCaches, .development, .tempFiles, .mailAttach].contains(category)
        case .applications:
            return [.appLeftovers, .largeFiles].contains(category)
        }
    }
}

struct ReviewManagerSheet: View {
    @ObservedObject var scanEngine: ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    let scope: ReviewScope

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ReviewTab = .all
    @State private var showConfirm = false
    @State private var isCleaning = false

    private var visibleItems: [ScanItem] {
        scanEngine.scanItems.filter { item in
            scope.allowedCategories.contains(item.category) && selectedTab.includes(item.category)
        }
    }

    private var groupedItems: [(category: ScanCategory, items: [ScanItem])] {
        let grouped = Dictionary(grouping: visibleItems, by: \.category)
        return ScanCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items.sorted { $0.size > $1.size })
        }
    }

    private var selectedVisibleCount: Int {
        visibleItems.filter(\.isSelected).count
    }

    private var selectedVisibleSize: Int64 {
        visibleItems.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    private var totalVisibleSize: Int64 {
        visibleItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(scope.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Review found items, select what to remove, then clean safely.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            HStack(spacing: 8) {
                ForEach(ReviewTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? AppTheme.accent : Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Select All") {
                    for item in visibleItems where !item.isSelected {
                        scanEngine.toggleItem(item.id)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(visibleItems.isEmpty)

                Button("Select None") {
                    for item in visibleItems where item.isSelected {
                        scanEngine.toggleItem(item.id)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(visibleItems.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            if visibleItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.green)
                    Text("Nothing to review in this tab.")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 12) {
                        ForEach(groupedItems, id: \.category) { group in
                            ReviewCategorySection(
                                category: group.category,
                                items: group.items,
                                scanEngine: scanEngine
                            )
                        }
                    }
                    .padding(16)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedVisibleCount) item\(selectedVisibleCount == 1 ? "" : "s") selected")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(ByteCountFormatter.string(fromByteCount: selectedVisibleSize, countStyle: .file)) selected of \(ByteCountFormatter.string(fromByteCount: totalVisibleSize, countStyle: .file))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                GradientButton(
                    title: isCleaning ? "Cleaning..." : "Clean Selected",
                    icon: "trash.fill",
                    gradient: [AppTheme.danger, Color(hex: "FF5858")],
                    disabled: isCleaning || selectedVisibleCount == 0
                ) {
                    showConfirm = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 920, minHeight: 620)
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Clean Selected Files?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task {
                    isCleaning = true
                    await cleanEngine.clean(items: visibleItems)
                    if cleanEngine.cleanedSize > 0 {
                        scanEngine.recordFreed(bytes: cleanEngine.cleanedSize, description: scope.cleanupDescription)
                    }
                    await scanEngine.startScan(mode: scope.scanMode)
                    isCleaning = false
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete \(ByteCountFormatter.string(fromByteCount: selectedVisibleSize, countStyle: .file)) of selected files.")
        }
    }
}

struct ReviewCategorySection: View {
    let category: ScanCategory
    let items: [ScanItem]
    @ObservedObject var scanEngine: ScanEngine
    @State private var expanded = true

    private var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    private var selectedCount: Int {
        items.filter(\.isSelected).count
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: category.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(category.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(selectedCount)/\(items.count) selected · \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    HStack(spacing: 6) {
                        Button("All") { scanEngine.selectAll(in: category) }
                            .buttonStyle(.bordered).controlSize(.mini)
                        Button("None") { scanEngine.deselectAll(in: category) }
                            .buttonStyle(.bordered).controlSize(.mini)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.leading, 12)
                ForEach(items) { item in
                    ReviewScanItemRow(item: item, scanEngine: scanEngine)
                    if item.id != items.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
        )
    }
}

struct ReviewScanItemRow: View {
    let item: ScanItem
    @ObservedObject var scanEngine: ScanEngine
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in scanEngine.toggleItem(item.id) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(item.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(item.sizeFormatted)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)

            // Reveal in Finder
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            } label: {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.secondary.opacity(isHovered ? 1 : 0.5))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        .cornerRadius(6)
        .onHover { isHovered = $0 }
    }
}
