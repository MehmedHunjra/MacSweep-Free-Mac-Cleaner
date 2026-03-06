import SwiftUI
import AppKit

struct LargeFilesView: View {
    @ObservedObject var scanEngine:  ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @AppStorage("largeFileThresholdMB") private var largeFileThresholdMB: Double = 100
    @State private var showConfirm = false
    @State private var showResult  = false
    @State private var showReview  = false

    var largeFiles: [ScanItem] {
        scanEngine.scanItems
            .filter { $0.category == .largeFiles }
            .sorted { $0.size > $1.size }
    }

    var selectedLargeSize: Int64 {
        largeFiles.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    @State private var scanTarget = NSHomeDirectory()

    var body: some View {
        VStack(spacing: 0) {
            if !scanEngine.isScanning && !scanEngine.scanComplete {
                landingScreen
            } else {
                // Toolbar/Header when scanning or showing results
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.sectionGradient(.largeFiles))
                            Text("Large Files")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                    }
                    Spacer()
                    if scanEngine.scanComplete && !largeFiles.isEmpty {
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
                            Task { await scanEngine.startScan(mode: .custom(path: scanTarget, categories: [.largeFiles])) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Rescan")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.sectionGradient(.largeFiles))
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
                } else if scanEngine.scanComplete && !largeFiles.isEmpty {
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            SummaryPill(icon: "arrow.up.doc.fill", label: "Large Files", value: "\(largeFiles.count) files", color: Color(hex: "F857A6"))
                            SummaryPill(icon: "checkmark.circle.fill", label: "Selected", value: "\(largeFiles.filter(\.isSelected).count) items · \(ByteCountFormatter.string(fromByteCount: selectedLargeSize, countStyle: .file))", color: AppTheme.success)
                            Spacer()
                            HStack(spacing: 6) {
                                Button("All") {
                                    for item in largeFiles where !item.isSelected { scanEngine.toggleItem(item.id) }
                                }.buttonStyle(.bordered).controlSize(.small)
                                Button("None") {
                                    for item in largeFiles where item.isSelected { scanEngine.toggleItem(item.id) }
                                }.buttonStyle(.bordered).controlSize(.small)
                            }
                            GradientButton(title: "Delete Selected", icon: "trash.fill", gradient: [AppTheme.danger, Color(hex: "FF5858")], disabled: selectedLargeSize == 0) { showConfirm = true }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color(NSColor.windowBackgroundColor))

                        Divider()

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(largeFiles) { item in
                                    LargeFileRow(item: item, scanEngine: scanEngine)
                                }
                            }
                            .padding(20)
                        }
                    }
                } else if scanEngine.scanComplete {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundColor(.green)
                        Text("No Large Files Found").font(.title3.bold())
                            .foregroundColor(.secondary)
                        Button("Scan Another Folder") {
                            scanEngine.scanComplete = false
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Delete Selected Files?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await cleanEngine.clean(items: largeFiles)
                    if cleanEngine.cleanedSize > 0 {
                        scanEngine.recordFreed(bytes: cleanEngine.cleanedSize, description: "Large Files cleanup")
                    }
                    await scanEngine.startScan(mode: .categories([.largeFiles]))
                    showResult = true
                }
            }
        } message: {
            Text("This will permanently delete \(ByteCountFormatter.string(fromByteCount: selectedLargeSize, countStyle: .file)).")
        }
        .sheet(isPresented: $showResult) { CleanResultSheet(cleanEngine: cleanEngine, scanEngine: scanEngine, isPresented: $showResult) }
        .sheet(isPresented: $showReview) {
            ReviewManagerSheet(
                scanEngine: scanEngine,
                cleanEngine: cleanEngine,
                scope: .largeFiles
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
                Spacer(minLength: 30)

                // 3D Glass Icon for Large Files
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(colors: [Color(hex: "F857A6").opacity(0.6), Color(hex: "FF5858").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "F857A6").opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "FFEDBC")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.bottom, 28)

                Text("Large & Old Files")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Locate and remove massive files that are\ncluttering your storage.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 28)

                // Folder selector
                Menu {
                    Button { scanTarget = NSHomeDirectory() } label: { Label("Home Folder", systemImage: "house.fill") }
                    Button { scanTarget = "/" } label: { Label("Macintosh HD", systemImage: "internaldrive.fill") }
                    Divider()
                    Button { selectCustomFolder() } label: { Label("Choose Folder…", systemImage: "folder.badge.plus") }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: scanTarget == "/" ? "internaldrive.fill" : "folder.fill")
                            .foregroundColor(Color(hex: "F857A6"))
                        Text(scanTargetName).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12).frame(width: 260)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.1), lineWidth: 1)))
                }
                .menuStyle(.borderlessButton)
                .padding(.bottom, 36)

                ToolPrimaryActionButton(
                    title: "Scan",
                    colors: [Color(hex: "F857A6"), Color(hex: "FF5858")],
                    icon: "sparkles"
                ) {
                    Task { await scanEngine.startScan(mode: .custom(path: scanTarget, categories: [.largeFiles])) }
                }

                Spacer(minLength: 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
    }

    private var scanTargetName: String {
        if scanTarget == "/" { return "Macintosh HD" }
        return (scanTarget as NSString).lastPathComponent
    }

    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            scanTarget = url.path
        }
    }
}

struct LargeFileRow: View {
    let item: ScanItem
    @ObservedObject var scanEngine: ScanEngine
    @State private var isHovered = false

    var fileIcon: String {
        let ext = (item.name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        case "dmg", "iso", "zip", "gz", "tar": return "doc.zipper"
        case "app": return "app.fill"
        case "mp3", "wav", "m4a", "aac": return "music.note"
        case "jpg", "png", "heic", "tiff": return "photo.fill"
        case "pdf": return "doc.text.fill"
        default: return "doc.fill"
        }
    }

    var fileColor: Color {
        let ext = (item.name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "avi", "mkv": return Color(hex: "BD10E0")
        case "dmg", "iso", "zip", "gz": return Color(hex: "F5A623")
        case "app": return Color(hex: "667EEA")
        default: return Color(hex: "9B9B9B")
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Toggle("", isOn: Binding(get: { item.isSelected }, set: { _ in scanEngine.toggleItem(item.id) }))
                .labelsHidden().toggleStyle(.checkbox)

            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(fileColor.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: fileIcon).font(.system(size: 18)).foregroundColor(fileColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(item.path).font(.caption2).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(item.sizeFormatted).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Color(hex: "F857A6"))

            Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: {
                Image(systemName: "arrow.right.circle").foregroundColor(.secondary)
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.windowBackgroundColor)).shadow(color: .black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 6 : 3, y: 1))
        .onHover { hovering in isHovered = hovering }
    }
}
