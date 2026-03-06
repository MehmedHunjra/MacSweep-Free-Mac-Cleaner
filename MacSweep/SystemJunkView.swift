import SwiftUI

struct SystemJunkView: View {
    @ObservedObject var scanEngine:  ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @State private var showConfirm = false
    @State private var showResult  = false
    @State private var showReview  = false

    var systemCategories: [ScanCategory] {
        [.userCaches, .logs, .tempFiles, .mailAttach]
    }

    var systemItems: [ScanItem] {
        scanEngine.scanItems.filter { systemCategories.contains($0.category) }
    }

    var selectedSystemItems: [ScanItem] {
        systemItems.filter(\.isSelected)
    }

    var selectedSystemSize: Int64 {
        selectedSystemItems.reduce(0) { $0 + $1.size }
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
                            Image(systemName: "xmark.bin.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.sectionGradient(.systemJunk))
                            Text("System Junk")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                    }
                    Spacer()
                    if scanEngine.scanComplete && !systemItems.isEmpty {
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
                            Task { await scanEngine.startScan(mode: .categories([.userCaches, .logs, .tempFiles, .mailAttach])) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Rescan")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.sectionGradient(.systemJunk))
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
                    VStack(spacing: 0) {
                        // Summary
                        HStack(spacing: 16) {
                            SummaryPill(
                                icon: "xmark.bin.fill",
                                label: "System Junk",
                                value: ByteCountFormatter.string(fromByteCount: systemItems.reduce(0) { $0 + $1.size }, countStyle: .file),
                                color: Color(hex: "FC5C7D")
                            )
                            SummaryPill(
                                icon: "checkmark.circle.fill",
                                label: "Selected",
                                value: "\(selectedSystemItems.count) items · \(ByteCountFormatter.string(fromByteCount: selectedSystemSize, countStyle: .file))",
                                color: AppTheme.success
                            )
                            Spacer()

                            HStack(spacing: 6) {
                                Button("All") {
                                    for cat in systemCategories { scanEngine.selectAll(in: cat) }
                                }.buttonStyle(.bordered).controlSize(.small)
                                Button("None") {
                                    for cat in systemCategories { scanEngine.deselectAll(in: cat) }
                                }.buttonStyle(.bordered).controlSize(.small)
                            }

                            GradientButton(
                                title: "Clean",
                                icon: "trash.fill",
                                gradient: [AppTheme.danger, Color(hex: "FF5858")],
                                disabled: selectedSystemSize == 0
                            ) {
                                showConfirm = true
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color(NSColor.windowBackgroundColor))

                        Divider()

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(systemCategories, id: \.self) { category in
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
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Clean System Junk?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task {
                    await cleanEngine.clean(items: systemItems)
                    if cleanEngine.cleanedSize > 0 {
                        scanEngine.recordFreed(bytes: cleanEngine.cleanedSize, description: "System Junk cleanup")
                    }
                    await scanEngine.startScan(mode: .categories([.userCaches, .logs, .tempFiles, .mailAttach]))
                    showResult = true
                }
            }
        } message: {
            Text("This will remove \(ByteCountFormatter.string(fromByteCount: selectedSystemSize, countStyle: .file)) of system junk.")
        }
        .sheet(isPresented: $showResult) {
            CleanResultSheet(cleanEngine: cleanEngine, scanEngine: scanEngine, isPresented: $showResult)
        }
        .sheet(isPresented: $showReview) {
            ReviewManagerSheet(
                scanEngine: scanEngine,
                cleanEngine: cleanEngine,
                scope: .systemJunk
            )
        }
    }

    // MARK: - Landing
    private var landingScreen: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A0740"), Color(hex: "200952"), Color(hex: "2A0D60"), Color(hex: "1A0740")],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 36)

                // 3D Glass Icon for System Junk
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(colors: [Color(hex: "FC5C7D").opacity(0.6), Color(hex: "6A82FB").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "FC5C7D").opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Image(systemName: "xmark.bin.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "D091FF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.bottom, 28)

                Text("System Junk")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Remove deep system caches, logs, and\ntemporary files to reclaim space.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 48)

                ToolPrimaryActionButton(
                    title: "Scan",
                    colors: [Color(hex: "FC5C7D"), Color(hex: "6A82FB")],
                    icon: "sparkles"
                ) {
                    Task { await scanEngine.startScan(mode: .categories([.userCaches, .logs, .tempFiles, .mailAttach])) }
                }

                Spacer(minLength: 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
    }
}
