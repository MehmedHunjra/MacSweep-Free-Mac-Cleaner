import SwiftUI
import AppKit

struct AppLeftoversView: View {
    @ObservedObject var scanEngine:  ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @State private var showConfirm = false
    @State private var showResult  = false
    @State private var showReview  = false

    var leftovers: [ScanItem] {
        scanEngine.scanItems
            .filter { $0.category == .appLeftovers }
            .sorted { $0.size > $1.size }
    }

    var selectedSize: Int64 {
        leftovers.filter(\.isSelected).reduce(0) { $0 + $1.size }
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
                            Image(systemName: "trash.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.sectionGradient(.appLeftovers))
                            Text("App Leftovers")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                    }
                    Spacer()
                    if scanEngine.scanComplete && !leftovers.isEmpty {
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
                            Task { await scanEngine.startScan(mode: .categories([.appLeftovers])) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Rescan")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.sectionGradient(.appLeftovers))
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
                } else if scanEngine.scanComplete && !leftovers.isEmpty {
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            SummaryPill(icon: "trash.fill", label: "Leftovers", value: "\(leftovers.count) apps", color: Color(hex: "ED4264"))
                            SummaryPill(icon: "checkmark.circle.fill", label: "Selected", value: "\(leftovers.filter(\.isSelected).count) items · \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))", color: AppTheme.success)
                            Spacer()
                            HStack(spacing: 6) {
                                Button("All") {
                                    for item in leftovers where !item.isSelected { scanEngine.toggleItem(item.id) }
                                }.buttonStyle(.bordered).controlSize(.small)
                                Button("None") {
                                    for item in leftovers where item.isSelected { scanEngine.toggleItem(item.id) }
                                }.buttonStyle(.bordered).controlSize(.small)
                            }
                            GradientButton(title: "Remove Selected", icon: "trash.fill", gradient: [AppTheme.danger, Color(hex: "FF5858")], disabled: selectedSize == 0) { showConfirm = true }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color(NSColor.windowBackgroundColor))

                        Divider()

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(leftovers) { item in
                                    LeftoverRow(item: item, scanEngine: scanEngine)
                                }
                            }
                            .padding(20)
                        }
                    }
                } else if scanEngine.scanComplete {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundColor(.green)
                        Text("No App Leftovers Found").font(.title3.bold())
                        Text("Your Mac is clean of uninstalled app data.").foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Remove App Leftovers?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    await cleanEngine.clean(items: leftovers)
                    if cleanEngine.cleanedSize > 0 {
                        scanEngine.recordFreed(bytes: cleanEngine.cleanedSize, description: "App Leftovers cleanup")
                    }
                    await scanEngine.startScan(mode: .categories([.appLeftovers]))
                    showResult = true
                }
            }
        } message: {
            Text("This will remove \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)) of leftover data.")
        }
        .sheet(isPresented: $showResult) { CleanResultSheet(cleanEngine: cleanEngine, scanEngine: scanEngine, isPresented: $showResult) }
        .sheet(isPresented: $showReview) {
            ReviewManagerSheet(
                scanEngine: scanEngine,
                cleanEngine: cleanEngine,
                scope: .appLeftovers
            )
        }
    }

    // MARK: - Landing
    private var landingScreen: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1F1C2C"), Color(hex: "928DAB"), Color(hex: "1F1C2C")],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 36)

                // 3D Glass Icon for App Leftovers
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(colors: [Color(hex: "ED4264").opacity(0.6), Color(hex: "FFEDBC").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "ED4264").opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Image(systemName: "trash.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "FFC3A0")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.bottom, 28)

                Text("App Leftovers")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Find and remove leftover files from applications\nthat have already been uninstalled.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 48)

                ToolPrimaryActionButton(
                    title: "Scan",
                    colors: [Color(hex: "ED4264"), Color(hex: "FF9A7A")],
                    icon: "sparkles"
                ) {
                    Task { await scanEngine.startScan(mode: .categories([.appLeftovers])) }
                }

                Spacer(minLength: 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
    }
}

struct LeftoverRow: View {
    let item: ScanItem
    @ObservedObject var scanEngine: ScanEngine
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            Toggle("", isOn: Binding(get: { item.isSelected }, set: { _ in scanEngine.toggleItem(item.id) }))
                .labelsHidden().toggleStyle(.checkbox)

            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(hex: "ED4264").opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "app.dashed").font(.system(size: 18)).foregroundColor(Color(hex: "ED4264"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.path).font(.caption2).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(item.sizeFormatted).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.secondary)

            Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: {
                Image(systemName: "arrow.right.circle").foregroundColor(.secondary)
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.windowBackgroundColor)).shadow(color: .black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 6 : 3, y: 1))
        .onHover { hovering in isHovered = hovering }
    }
}
