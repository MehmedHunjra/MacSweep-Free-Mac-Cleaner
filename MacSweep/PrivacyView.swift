import SwiftUI

struct PrivacyView: View {
    @ObservedObject var scanEngine:  ScanEngine
    @ObservedObject var cleanEngine: CleanEngine
    @State private var showConfirm = false
    @State private var showResult  = false
    @State private var isScanning  = false
    @State private var privacyItems: [PrivacyItem] = []
    @State private var scanDone = false

    var selectedSize: Int64 {
        privacyItems.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isScanning {
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Scanning for privacy-sensitive data...")
                        .font(.headline)
                    Spacer()
                }
            } else if scanDone {
                VStack(spacing: 0) {
                    // Header (Compact for results)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.sectionGradient(.privacy))
                                Text("Privacy")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                            }
                            Text("Protect your digital footprint by clearing sensitive data")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        Spacer()
                        GradientButton(
                            title: "Rescan",
                            icon: "arrow.clockwise",
                            gradient: AppSection.privacy.gradient,
                            disabled: isScanning
                        ) {
                            scanPrivacy()
                        }
                    }
                    .padding(24)

                    Divider()

                    // Summary
                    HStack(spacing: 16) {
                        SummaryPill(
                            icon: "hand.raised.fill",
                            label: "Privacy Data",
                            value: "\(privacyItems.filter(\.isSelected).count) items · \(ByteCountFormatter.string(fromByteCount: privacyItems.reduce(0) { $0 + $1.size }, countStyle: .file))",
                            color: Color(hex: "FF416C")
                        )
                        Spacer()
                        HStack(spacing: 6) {
                            Button("All") {
                                for i in privacyItems.indices { privacyItems[i].isSelected = true }
                            }.buttonStyle(.bordered).controlSize(.small)
                            Button("None") {
                                for i in privacyItems.indices { privacyItems[i].isSelected = false }
                            }.buttonStyle(.bordered).controlSize(.small)
                        }
                        GradientButton(
                            title: "Clean",
                            icon: "trash.fill",
                            gradient: [AppTheme.danger, Color(hex: "FF5858")],
                            disabled: selectedSize == 0
                        ) {
                            showConfirm = true
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color(NSColor.windowBackgroundColor))

                    Divider()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(Array(privacyItems.enumerated()), id: \.element.id) { index, item in
                                PrivacyRow(item: $privacyItems[index])
                            }
                        }
                        .padding(20)
                    }
                }
            } else {
                landingScreen
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Clear Privacy Data?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearPrivacyData()
            }
        } message: {
            Text("This will clear \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)) of privacy-sensitive data.")
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

                // 3D Glass Icon for Privacy
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(colors: [Color(hex: "FF416C").opacity(0.6), Color(hex: "FF4B2B").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "FF416C").opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "FFB2C5")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.bottom, 28)

                Text("Privacy")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Protect your digital footprint by clearing sensitive data,\nbrowser history, and activity traces.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 48)

                ToolPrimaryActionButton(
                    title: "Scan",
                    colors: [Color(hex: "FF416C"), Color(hex: "FF4B2B")],
                    icon: "sparkles"
                ) {
                    scanPrivacy()
                }

                Spacer(minLength: 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
    }

    private func scanPrivacy() {
        isScanning = true
        privacyItems = []

        Task {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let paths: [(String, String, String, Color)] = [
                ("Recent Items", "\(home)/Library/Application Support/com.apple.sharedfilelist", "clock.fill", Color(hex: "FF416C")),
                ("Safari History", "\(home)/Library/Safari/History.db", "safari.fill", Color(hex: "4A90D9")),
                ("Safari Downloads", "\(home)/Library/Safari/Downloads.plist", "arrow.down.circle.fill", Color(hex: "7ED321")),
                ("Chrome History", "\(home)/Library/Application Support/Google/Chrome/Default/History", "globe", Color(hex: "F5A623")),
                ("Chrome Cookies", "\(home)/Library/Application Support/Google/Chrome/Default/Cookies", "link", Color(hex: "BD10E0")),
                ("Firefox Data", "\(home)/Library/Application Support/Firefox/Profiles", "flame.fill", Color(hex: "D0021B")),
                ("Recent Documents", "\(home)/Library/RecentServers", "doc.fill", Color(hex: "667EEA")),
                ("Saved Application State", "\(home)/Library/Saved Application State", "app.badge.fill", Color(hex: "9B9B9B")),
                ("Diagnostic Reports", "\(home)/Library/Logs/DiagnosticReports", "exclamationmark.triangle.fill", Color(hex: "F8E71C")),
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
        let bytesToClear = selectedSize
        let fm = FileManager.default
        for item in privacyItems where item.isSelected {
            try? fm.removeItem(atPath: item.path)
        }
        if bytesToClear > 0 {
            scanEngine.recordFreed(bytes: bytesToClear, description: "Privacy cleanup")
        }
        scanPrivacy()
    }
}

struct PrivacyItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let icon: String
    let color: Color
    var isSelected: Bool

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

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
                    .fill(item.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .foregroundColor(item.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
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

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            } label: {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.secondary.opacity(isHovered ? 1 : 0.5))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 6 : 3, y: 1)
        )
        .onHover { hovering in isHovered = hovering }
    }
}
