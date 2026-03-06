import SwiftUI

struct SidebarView: View {
    @Binding var selected: AppSection
    @Binding var hoverSection: AppSection?
    @ObservedObject var scanEngine: ScanEngine
    @ObservedObject var settings: AppSettings
    
    @ObservedObject var appsEngine: ApplicationsEngine
    @ObservedObject var protectionEngine: ProtectionEngine
    @ObservedObject var perfEngine: PerformanceEngine
    @ObservedObject var dupEngine: DuplicateEngine
    @ObservedObject var memoryEngine: MemoryEngine
    @ObservedObject var spaceEngine: SpaceLensEngine
    @ObservedObject var devEngine: DevCleanEngine

    private let cleaningTools: [AppSection] = [.smartScan, .systemJunk, .largeFiles, .duplicates]
    private let protectionTools: [AppSection] = [.protection]
    private let managementTools: [AppSection] = [.performance, .applications]
    private let utilityTools: [AppSection] = [.spaceLens, .devCleaner]
    private var displayCPUPercent: Int { scanEngine.cpuUsagePercent }
    private var displayMemoryUsedCompact: String { scanEngine.memoryUsedCompact }
    private var displayMemoryUsagePercent: Int { scanEngine.memoryUsagePercent }
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private func isScanning(section: AppSection) -> Bool {
        switch section {
        case .smartScan: return scanEngine.isScanning
        case .systemJunk, .largeFiles: return scanEngine.isScanning
        case .duplicates: return dupEngine.isScanning
        case .protection: return protectionEngine.isScanning
        case .performance: return perfEngine.isScanning
        case .applications: return appsEngine.isScanning
        case .spaceLens: return spaceEngine.isScanning
        case .devCleaner: return devEngine.isScanning
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Logo header
            HStack(spacing: 10) {
                LogoView(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MacSweep")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("v\(appVersion)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Disk usage widget
            if let disk = scanEngine.diskInfo {
                DiskWidget(disk: disk)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }

            // System health pill row
            HStack(spacing: 8) {
                SystemPill(label: "CPU", value: "\(displayCPUPercent)%",
                           color: displayCPUPercent > 80 ? .red : .orange)
                SystemPill(label: "RAM", value: displayMemoryUsedCompact,
                           color: displayMemoryUsagePercent > 80 ? .red : Color(hex: "38EF7D"))
                SystemPill(label: "Apps", value: "\(scanEngine.runningAppCount)",
                           color: AppTheme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 14)

            // Navigation sections
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    // Dashboard
                    SidebarItem(section: .dashboard, selected: $selected, hoverSection: $hoverSection, isScanning: false)
                        .padding(.top, 8)

                    SectionHeader(title: "CLEANING")
                    ForEach(cleaningTools, id: \.self) { section in
                        SidebarItem(section: section, selected: $selected, hoverSection: $hoverSection, isScanning: isScanning(section: section))
                    }

                    SectionHeader(title: "PROTECTION")
                    ForEach(protectionTools, id: \.self) { section in
                        SidebarItem(section: section, selected: $selected, hoverSection: $hoverSection, isScanning: isScanning(section: section))
                    }

                    SectionHeader(title: "MANAGEMENT")
                    ForEach(managementTools, id: \.self) { section in
                        SidebarItem(section: section, selected: $selected, hoverSection: $hoverSection, isScanning: isScanning(section: section))
                    }

                    SectionHeader(title: "UTILITIES")
                    ForEach(utilityTools, id: \.self) { section in
                        SidebarItem(section: section, selected: $selected, hoverSection: $hoverSection, isScanning: isScanning(section: section))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Spacer()

            // Freed space badge
            if scanEngine.totalFreedBytes > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.success)
                    Text(ByteCountFormatter.string(fromByteCount: scanEngine.totalFreedBytes, countStyle: .file) + " freed")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.success)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
            }

            Divider().padding(.horizontal, 14)

            // Settings + Support row at bottom
            HStack(spacing: 8) {
                SidebarItem(section: .settings, selected: $selected, hoverSection: $hoverSection)
                    .frame(maxWidth: .infinity)

                SidebarCoffeeMiniButton()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // Version footer
            HStack {
                Text("Free & Open Source")
                    .font(.caption2)
                    .foregroundColor(AppTheme.accent.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
        )
    }
}

// MARK: - System Pill
struct SystemPill: View {
    let label: String
    let value: String
    let color: Color
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(isHovered ? 0.2 : 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(isHovered ? 0.35 : 0.15), lineWidth: 1)
        )
        .shadow(color: color.opacity(isHovered ? 0.25 : 0.0), radius: isHovered ? 8 : 0, y: 2)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help("\(label): \(value)")
    }
}

// MARK: - Sidebar Item
struct SidebarItem: View {
    let section: AppSection
    @Binding var selected: AppSection
    @Binding var hoverSection: AppSection?
    var isScanning: Bool = false

    var isSelected: Bool { selected == section }
    var isHovered: Bool { hoverSection == section }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selected = section
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isSelected
                            ? AnyShapeStyle(AppTheme.sectionGradient(section))
                            : AnyShapeStyle(Color.clear)
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: section.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                Spacer()
                
                if isScanning {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 6, height: 6)
                        .shadow(color: AppTheme.success.opacity(0.8), radius: 3)
                        .opacity(isHovered || isSelected ? 1.0 : 0.7)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AppTheme.accent.opacity(0.1) : (isHovered ? Color.gray.opacity(0.08) : Color.clear))
            )
            .shadow(color: isHovered ? .black.opacity(0.1) : .clear, radius: isHovered ? 8 : 0, y: 2)
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoverSection = hovering ? section : nil
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary.opacity(0.6))
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
}

private struct SidebarCoffeeMiniButton: View {
    @State private var isHovered = false

    var body: some View {
        Button {
            guard let url = URL(string: "https://ko-fi.com/mehmedhunjra") else { return }
            NSWorkspace.shared.open(url)
        } label: {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.supportText)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.supportGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.42), lineWidth: 1)
                )
                .shadow(color: Color(hex: "FFCA28").opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 12 : 7, y: 3)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Buy Me a Coffee")
    }
}

// MARK: - Disk Widget
struct DiskWidget: View {
    let disk: DiskInfo
    @State private var isHovered = false

    var usageColor: Color {
        if disk.usedPercentage > 0.9 { return AppTheme.danger }
        if disk.usedPercentage > 0.75 { return AppTheme.warning }
        return AppTheme.accent
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "internaldrive.fill")
                    .foregroundColor(usageColor)
                    .font(.caption)
                Text("Macintosh HD")
                    .font(.caption.bold())
                Spacer()
                Text(disk.freeFormatted + " available")
                    .font(.caption2.bold())
                    .foregroundColor(usageColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [usageColor, usageColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * disk.usedPercentage)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(disk.usedFormatted) used")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(disk.totalFormatted) total")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(NSColor.windowBackgroundColor).opacity(isHovered ? 0.78 : 0.6),
                            usageColor.opacity(isHovered ? 0.12 : 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(usageColor.opacity(isHovered ? 0.35 : 0.16), lineWidth: 1)
        )
        .shadow(color: usageColor.opacity(isHovered ? 0.22 : 0), radius: isHovered ? 12 : 0, y: 3)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .help("Used: \(disk.usedFormatted) of \(disk.totalFormatted). Free: \(disk.freeFormatted).")
    }
}

// MARK: - Visual Effect View
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Logo View (Brand Logo from PNG)
struct LogoView: View {
    var size: CGFloat = 40

    var body: some View {
        Image("BrandLogo")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}

// MARK: - MacSweep Icon Shape (matches SVG logo)
struct MacSweepIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Simplified version of the SVG "M" sweep path
        // Left vertical bar of M
        path.move(to: CGPoint(x: w * 0.05, y: h * 0.95))
        path.addLine(to: CGPoint(x: w * 0.05, y: h * 0.05))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.05))

        // First diagonal up-stroke
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.55))

        // Inner V
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.05))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.05))

        // Second bar top
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.05))
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.65))

        // Big sweep curve to the right (the signature "sweep" of MacSweep)
        path.addCurve(
            to: CGPoint(x: w * 0.95, y: h * 0.35),
            control1: CGPoint(x: w * 0.68, y: h * 0.65),
            control2: CGPoint(x: w * 0.92, y: h * 0.60)
        )
        // Top of sweep
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.15),
            control1: CGPoint(x: w * 0.98, y: h * 0.15),
            control2: CGPoint(x: w * 0.85, y: h * 0.10)
        )
        // Return sweep down
        path.addCurve(
            to: CGPoint(x: w * 0.62, y: h * 0.40),
            control1: CGPoint(x: w * 0.65, y: h * 0.18),
            control2: CGPoint(x: w * 0.62, y: h * 0.30)
        )

        // Close the left bar
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.40))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.95))
        path.closeSubpath()

        return path
    }
}
