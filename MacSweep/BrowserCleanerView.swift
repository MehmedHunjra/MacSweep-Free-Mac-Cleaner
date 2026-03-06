import SwiftUI

struct BrowserCleanerView: View {
    @ObservedObject var scanEngine:  ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @State private var showConfirm = false
    @State private var showResult  = false
    @State private var showReview  = false

    var browserItems: [ScanItem] {
        scanEngine.scanItems.filter { $0.category == .browserCaches }
    }

    var selectedBrowserSize: Int64 {
        browserItems.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !scanEngine.isScanning && !scanEngine.scanComplete {
                landingScreen
            } else {
                // Toolbar/Header when scanning or showing results
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.title2)
                                .foregroundStyle(AppTheme.sectionGradient(.browser))
                            Text("Browser Privacy")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                    }
                    Spacer()
                    if scanEngine.scanComplete && !browserItems.isEmpty {
                        Button("Review") {
                            showReview = true
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    if !scanEngine.isScanning {
                        Button {
                            Task { await scanEngine.startScan(mode: .categories([.browserCaches])) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Rescan")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.sectionGradient(.browser))
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
                } else if scanEngine.scanComplete && !browserItems.isEmpty {
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            SummaryPill(icon: "globe", label: "Browser Data", value: ByteCountFormatter.string(fromByteCount: browserItems.reduce(0) { $0 + $1.size }, countStyle: .file), color: Color(hex: "56AB2F"))
                            SummaryPill(icon: "checkmark.circle.fill", label: "Selected", value: "\(browserItems.filter(\.isSelected).count) items · \(ByteCountFormatter.string(fromByteCount: selectedBrowserSize, countStyle: .file))", color: AppTheme.success)
                            Spacer()
                            HStack(spacing: 6) {
                                Button("All") {
                                    for item in browserItems where !item.isSelected { scanEngine.toggleItem(item.id) }
                                }.buttonStyle(.bordered).controlSize(.small)
                                Button("None") {
                                    for item in browserItems where item.isSelected { scanEngine.toggleItem(item.id) }
                                }.buttonStyle(.bordered).controlSize(.small)
                            }
                            GradientButton(title: "Clean Browsers", icon: "trash.fill", gradient: [AppTheme.danger, Color(hex: "FF5858")], disabled: selectedBrowserSize == 0) { showConfirm = true }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color(NSColor.windowBackgroundColor))

                        Divider()

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                // Chrome section
                                BrowserSection(
                                    name: "Google Chrome",
                                    icon: "globe.americas.fill",
                                    color: Color(hex: "4285F4"),
                                    items: browserItems.filter { $0.path.contains("Chrome") },
                                    scanEngine: scanEngine
                                )

                                // Safari section
                                BrowserSection(
                                    name: "Safari",
                                    icon: "safari.fill",
                                    color: Color(hex: "006CFF"),
                                    items: browserItems.filter { $0.path.contains("Safari") },
                                    scanEngine: scanEngine
                                )

                                // Firefox section
                                BrowserSection(
                                    name: "Firefox",
                                    icon: "flame.fill",
                                    color: Color(hex: "FF6611"),
                                    items: browserItems.filter { $0.path.contains("Firefox") },
                                    scanEngine: scanEngine
                                )
                            }
                            .padding(20)
                        }
                    }
                } else if scanEngine.scanComplete {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundColor(.green)
                        Text("Browsers are Clean").font(.title3.bold())
                        Spacer()
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Clear Browser Data?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task {
                    await cleanEngine.clean(items: browserItems)
                    if cleanEngine.cleanedSize > 0 {
                        scanEngine.recordFreed(bytes: cleanEngine.cleanedSize, description: "Browser cleanup")
                    }
                    await scanEngine.startScan(mode: .categories([.browserCaches]))
                    showResult = true
                }
            }
        } message: {
            Text("This will clear \(ByteCountFormatter.string(fromByteCount: selectedBrowserSize, countStyle: .file)) of browser data.")
        }
        .sheet(isPresented: $showResult) { CleanResultSheet(cleanEngine: cleanEngine, scanEngine: scanEngine, isPresented: $showResult) }
        .sheet(isPresented: $showReview) {
            ReviewManagerSheet(
                scanEngine: scanEngine,
                cleanEngine: cleanEngine,
                scope: .browser
            )
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
                Spacer(minLength: 36)

                // 3D Glass Icon for Browsers
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(colors: [Color(hex: "56AB2F").opacity(0.6), Color(hex: "A8E063").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "56AB2F").opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Image(systemName: "globe")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "DFFFCA")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.bottom, 28)

                Text("Browser Privacy")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Protect your privacy by clearing cookies,\nhistories, and cache from your browsers.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 48)

                ToolPrimaryActionButton(
                    title: "Scan",
                    colors: [Color(hex: "56AB2F"), Color(hex: "8ED95B")],
                    icon: "sparkles"
                ) {
                    Task { await scanEngine.startScan(mode: .categories([.browserCaches])) }
                }

                Spacer(minLength: 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
    }
}

struct BrowserSection: View {
    let name: String
    let icon: String
    let color: Color
    let items: [ScanItem]
    @ObservedObject var scanEngine: ScanEngine
    @State private var expanded = true

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    var body: some View {
        if !items.isEmpty {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(duration: 0.25)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(.system(size: 15, weight: .semibold))
                            Text("\(items.count) item\(items.count == 1 ? "" : "s") \u{00B7} \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
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
                        BrowserCacheRow(item: item, scanEngine: scanEngine, color: color)
                        if item.id != items.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)).shadow(color: .black.opacity(0.04), radius: 4, y: 1))
        }
    }
}

struct BrowserCacheRow: View {
    let item: ScanItem
    @ObservedObject var scanEngine: ScanEngine
    let color: Color
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { item.isSelected }, set: { _ in scanEngine.toggleItem(item.id) }))
                .labelsHidden().toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 13)).lineLimit(1)
                Text(item.path).font(.caption2).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(item.sizeFormatted).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(color)

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
