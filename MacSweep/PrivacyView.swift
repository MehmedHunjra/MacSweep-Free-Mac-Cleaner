import SwiftUI

struct PrivacyView: View {
    @ObservedObject var scanEngine:  ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @State private var showConfirm  = false
    @State private var showResult   = false
    @State private var showFDAAlert = false
    @State private var isScanning   = false
    @State private var privacyItems: [PrivacyItem] = []
    @State private var scanDone     = false
    @EnvironmentObject var navManager: NavigationManager

    private let theme = SectionTheme.theme(for: .privacy)

    var selectedSize: Int64 {
        privacyItems.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isScanning {
                scanningView
            } else if scanDone {
                VStack(spacing: 0) {
                    navHeader(isLanding: false)
                    resultsView
                }
            } else {
                VStack(spacing: 0) {
                    navHeader(isLanding: true)
                    ToolLandingView(
                        section: .privacy,
                        subtitle: "Protect your digital footprint by clearing sensitive\ndata, browser history, and activity traces.",
                        actionLabel: "Scan",
                        onAction: { scanPrivacy() }
                    )
                }
            }
        }
        .background(DS.bg)
        .alert("Clear Privacy Data?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { clearPrivacyData() }
        } message: {
            Text("This will clear \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)) of privacy-sensitive data.")
        }
        .alert("Full Disk Access Required", isPresented: $showFDAAlert) {
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("MacSweep needs Full Disk Access to clear privacy data.\n\nGo to System Settings → Privacy & Security → Full Disk Access and enable MacSweep.")
        }
    }

    // MARK: - Scanning View
    private var scanningView: some View {
        ToolScanningView(
            section: .privacy,
            scanningTitle: "Scanning for privacy-sensitive data...",
            currentPath: .constant("Checking browser history, cookies, and logs..."),
            onStop: { isScanning = false }
        )
    }

    // MARK: - Navigation Header
    func navHeader(isLanding: Bool) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Button {
                    if !isLanding {
                        scanDone = false
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.linearGradient)
                        .frame(width: 36, height: 36)
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("Privacy")
                    .font(MSFont.title2)
                    .foregroundColor(DS.textPrimary)
                
                Spacer()
                
                Button {
                    scanPrivacy()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Rescan")
                    }
                    .font(MSFont.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(theme.linearGradient)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isScanning)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Footer bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Button("All") {
                        for i in privacyItems.indices { privacyItems[i].isSelected = true }
                    }
                    .font(MSFont.caption)
                    .foregroundColor(DS.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DS.bgElevated)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)

                    Button("None") {
                        for i in privacyItems.indices { privacyItems[i].isSelected = false }
                    }
                    .font(MSFont.caption)
                    .foregroundColor(DS.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DS.bgElevated)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }

                Spacer()

                GradientButton(
                    title: "Clean",
                    icon: "trash.fill",
                    gradient: [DS.danger, DS.danger],
                    disabled: selectedSize == 0
                ) {
                    showConfirm = true
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(DS.bgPanel)
            .overlay(Rectangle().fill(DS.borderSubtle).frame(height: 1), alignment: .bottom)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(privacyItems.enumerated()), id: \.element.id) { index, _ in
                        PrivacyRow(item: $privacyItems[index])
                    }
                }
                .padding(20)
            }
            .background(DS.bg)
        }
    }

    private func scanPrivacy() {
        isScanning = true
        scanDone = false
        privacyItems = []

        Task {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let paths: [(String, String, String, Color)] = [
                ("Recent Items", "\(home)/Library/Application Support/com.apple.sharedfilelist", "clock.fill", DS.danger),
                ("Safari History", "\(home)/Library/Safari/History.db", "safari.fill", Color(hex: "4A90D9")),
                ("Safari Downloads", "\(home)/Library/Safari/Downloads.plist", "arrow.down.circle.fill", DS.success),
                ("Chrome History", "\(home)/Library/Application Support/Google/Chrome/Default/History", "globe", DS.warning),
                ("Chrome Cookies", "\(home)/Library/Application Support/Google/Chrome/Default/Cookies", "link", Color(hex: "9B4DFF")),
                ("Firefox Data", "\(home)/Library/Application Support/Firefox/Profiles", "flame.fill", Color(hex: "FF6611")),
                ("Recent Documents", "\(home)/Library/RecentServers", "doc.fill", Color(hex: "3A70E0")),
                ("Saved Application State", "\(home)/Library/Saved Application State", "app.badge.fill", DS.textMuted),
                ("Diagnostic Reports", "\(home)/Library/Logs/DiagnosticReports", "exclamationmark.triangle.fill", DS.warning),
            ]

            for (name, path, icon, color) in paths {
                let fm = FileManager.default
                guard fm.fileExists(atPath: path) else { continue }
                let size = await Task.detached(priority: .background) {
                    ScanEngine.calcSize(path: path)
                }.value
                guard size > 0 else { continue }

                await MainActor.run {
                    privacyItems.append(PrivacyItem(
                        name: name, path: path, size: size,
                        icon: icon, color: color, isSelected: true
                    ))
                }
            }

            await MainActor.run {
                isScanning = false
                scanDone = true
            }
        }
    }

    private func clearPrivacyData() {
        let fm = FileManager.default
        var actualCleared: Int64 = 0
        for item in privacyItems where item.isSelected {
            let url = URL(fileURLWithPath: item.path)
            let deleted: Bool
            if (try? fm.trashItem(at: url, resultingItemURL: nil)) != nil {
                deleted = true
            } else if (try? fm.removeItem(at: url)) != nil {
                deleted = true
            } else {
                deleted = false
            }
            if deleted { actualCleared += item.size }
        }
        if actualCleared == 0 {
            showFDAAlert = true
            return
        }
        scanEngine.recordFreed(bytes: actualCleared, description: "Privacy cleanup")
        DS.playCleanComplete()
        scanPrivacy()
    }
}

// MARK: - Privacy Item Model

struct PrivacyItem: Identifiable {
    let id    = UUID()
    let name:  String
    let path:  String
    let size:  Int64
    let icon:  String
    let color: Color
    var isSelected: Bool

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Privacy Row

struct PrivacyRow: View {
    @Binding var item: PrivacyItem
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            Toggle("", isOn: $item.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.color.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .foregroundColor(item.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(MSFont.headline)
                    .foregroundColor(DS.textPrimary)
                Text(item.path)
                    .font(MSFont.mono)
                    .foregroundColor(DS.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(item.sizeFormatted)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(DS.textSecondary)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            } label: {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(isHovered ? DS.textSecondary : DS.textMuted)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? DS.bgElevated : DS.bgPanel)
                .animation(Motion.fast, value: isHovered)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(DS.borderSubtle, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(Motion.fast) { isHovered = hovering }
        }
    }
}
