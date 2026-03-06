import Foundation
import SwiftUI
import AppKit

// MARK: - Scan Category
enum ScanCategory: String, CaseIterable, Identifiable {
    case userCaches    = "User Caches"
    case logs          = "Log Files"
    case browserCaches = "Browser Caches"
    case development   = "Development Junk"
    case tempFiles     = "Temp Files"
    case appLeftovers  = "App Leftovers"
    case largeFiles    = "Large Files"
    case mailAttach    = "Mail Attachments"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .userCaches:    return "internaldrive"
        case .logs:          return "doc.text"
        case .browserCaches: return "globe"
        case .development:   return "hammer"
        case .tempFiles:     return "clock.arrow.circlepath"
        case .appLeftovers:  return "trash"
        case .largeFiles:    return "arrow.up.doc"
        case .mailAttach:    return "envelope.badge.fill"
        }
    }

    var color: Color {
        switch self {
        case .userCaches:    return Color(hex: "5B8DEF")
        case .logs:          return Color(hex: "F5A623")
        case .browserCaches: return Color(hex: "7ED321")
        case .development:   return Color(hex: "F8E71C")
        case .tempFiles:     return Color(hex: "9B9B9B")
        case .appLeftovers:  return Color(hex: "D0021B")
        case .largeFiles:    return Color(hex: "BD10E0")
        case .mailAttach:    return Color(hex: "4A90D9")
        }
    }

    var description: String {
        switch self {
        case .userCaches:    return "App cache files that can be safely regenerated"
        case .logs:          return "System and app log files"
        case .browserCaches: return "Chrome, Safari and Firefox cache data"
        case .development:   return "Xcode, npm, gradle and other dev tool junk"
        case .tempFiles:     return "Temporary files no longer needed"
        case .appLeftovers:  return "Leftover data from uninstalled apps"
        case .largeFiles:    return "Large files taking up significant space"
        case .mailAttach:    return "Cached mail attachments and downloads"
        }
    }

    var isSafeByDefault: Bool {
        switch self {
        case .userCaches, .logs, .browserCaches, .development, .tempFiles, .mailAttach:
            return true
        case .appLeftovers, .largeFiles:
            return false
        }
    }
}

// MARK: - App Section
enum AppSection: String, CaseIterable {
    case dashboard     = "Dashboard"
    case smartScan     = "Smart Scan"
    case systemJunk    = "System Junk"
    case largeFiles    = "Large Files"
    case appLeftovers  = "App Leftovers"
    case browser       = "Browser Privacy"
    case maintenance   = "Maintenance"
    case privacy       = "Privacy"
    case spaceLens     = "Space Lens"
    case devCleaner    = "Dev Cleaner"
    case performance   = "Optimize & Maintain"
    case applications  = "Applications"
    case protection    = "Privacy & Protection"
    case duplicates    = "Duplicates"
    case settings      = "Settings"

    var icon: String {
        switch self {
        case .dashboard:    return "gauge.medium"
        case .smartScan:    return "sparkles.rectangle.stack"
        case .systemJunk:   return "xmark.bin.fill"
        case .largeFiles:   return "arrow.up.doc.fill"
        case .appLeftovers: return "trash.fill"
        case .browser:      return "globe"
        case .maintenance:  return "wrench.and.screwdriver.fill"
        case .privacy:      return "hand.raised.fill"
        case .spaceLens:    return "chart.pie.fill"
        case .devCleaner:   return "chevron.left.forwardslash.chevron.right"
        case .performance:  return "bolt.shield"
        case .applications: return "square.stack.3d.up.fill"
        case .protection:   return "lock.shield"
        case .duplicates:   return "doc.on.doc.fill"
        case .settings:     return "gearshape.fill"
        }
    }

    var gradient: [Color] {
        switch self {
        case .dashboard:    return [Color(hex: "667EEA"), Color(hex: "764BA2")]
        case .smartScan:    return [Color(hex: "11998E"), Color(hex: "38EF7D")]
        case .systemJunk:   return [Color(hex: "FC5C7D"), Color(hex: "6A82FB")]
        case .largeFiles:   return [Color(hex: "F857A6"), Color(hex: "FF5858")]
        case .appLeftovers: return [Color(hex: "ED4264"), Color(hex: "FFEDBC")]
        case .browser:      return [Color(hex: "56AB2F"), Color(hex: "A8E063")]
        case .maintenance:  return [Color(hex: "3A1C71"), Color(hex: "D76D77")]
        case .privacy:      return [Color(hex: "FF416C"), Color(hex: "FF4B2B")]
        case .spaceLens:    return [Color(hex: "4776E6"), Color(hex: "8E54E9")]
        case .devCleaner:   return [Color(hex: "1A1A2E"), Color(hex: "E94560")]
        case .performance:  return [Color(hex: "F7971E"), Color(hex: "FFD200")]
        case .applications: return [Color(hex: "6A11CB"), Color(hex: "2575FC")]
        case .protection:   return [Color(hex: "0F2027"), Color(hex: "2C5364"), Color(hex: "203A43")]
        case .duplicates:   return [Color(hex: "9C27B0"), Color(hex: "E040FB")]
        case .settings:     return [Color(hex: "636e72"), Color(hex: "b2bec3")]
        }
    }
}

// MARK: - Scan Item
struct ScanItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let category: ScanCategory
    var isSelected: Bool

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var url: URL {
        URL(fileURLWithPath: path)
    }
}

// MARK: - Disk Info
struct DiskInfo {
    let totalSpace: Int64
    let freeSpace: Int64

    var usedSpace: Int64 { totalSpace - freeSpace }

    var usedPercentage: Double {
        totalSpace > 0 ? Double(usedSpace) / Double(totalSpace) : 0
    }

    var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSpace, countStyle: .file)
    }

    var freeFormatted: String {
        ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
    }

    var usedFormatted: String {
        ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }
}

// MARK: - Storage Category for Space Lens
struct StorageCategory: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let color: Color
    let icon: String

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Maintenance Task
struct MaintenanceTask: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let color: Color
    var isSelected: Bool = true
    var isCompleted: Bool = false
}

// MARK: - Running App Info
struct RunningAppInfo: Identifiable {
    let id: pid_t
    let name: String
    let bundleId: String
    let icon: NSImage?
    var cpuPercent: Double
    var memoryMB: Double
    var isActive: Bool

    var memoryFormatted: String {
        if memoryMB >= 1024 {
            return String(format: "%.1f GB", memoryMB / 1024)
        }
        return String(format: "%.0f MB", memoryMB)
    }

    var cpuFormatted: String {
        String(format: "%.1f%%", cpuPercent)
    }
}

// MARK: - Freed Space Record
struct FreedSpaceRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let bytes: Int64
    let description: String

    init(id: UUID = UUID(), date: Date = Date(), bytes: Int64, description: String) {
        self.id = id
        self.date = date
        self.bytes = bytes
        self.description = description
    }

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var dateFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - App Settings (ObservableObject)
class AppSettings: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    @Published var launchAtLoginMenuBarOnly: Bool {
        didSet { UserDefaults.standard.set(launchAtLoginMenuBarOnly, forKey: "launchAtLoginMenuBarOnly") }
    }
    @Published var showMenuBarAlways: Bool {
        didSet { UserDefaults.standard.set(showMenuBarAlways, forKey: "showMenuBarAlways") }
    }
    @Published var showDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDockIcon, forKey: "showDockIcon")
            NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        }
    }
    @Published var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }
    @Published var menuBarShowCPU: Bool {
        didSet { UserDefaults.standard.set(menuBarShowCPU, forKey: "menuBarShowCPU") }
    }
    @Published var menuBarShowRAM: Bool {
        didSet { UserDefaults.standard.set(menuBarShowRAM, forKey: "menuBarShowRAM") }
    }
    @Published var menuBarShowDisk: Bool {
        didSet { UserDefaults.standard.set(menuBarShowDisk, forKey: "menuBarShowDisk") }
    }
    @Published var menuBarShowNetwork: Bool {
        didSet { UserDefaults.standard.set(menuBarShowNetwork, forKey: "menuBarShowNetwork") }
    }
    @Published var largeFileThresholdMB: Double {
        didSet { UserDefaults.standard.set(largeFileThresholdMB, forKey: "largeFileThresholdMB") }
    }
    @Published var scanIncludeUserCaches: Bool {
        didSet { UserDefaults.standard.set(scanIncludeUserCaches, forKey: "scanIncludeUserCaches") }
    }
    @Published var scanIncludeLogs: Bool {
        didSet { UserDefaults.standard.set(scanIncludeLogs, forKey: "scanIncludeLogs") }
    }
    @Published var scanIncludeBrowserCaches: Bool {
        didSet { UserDefaults.standard.set(scanIncludeBrowserCaches, forKey: "scanIncludeBrowserCaches") }
    }
    @Published var scanIncludeDevelopment: Bool {
        didSet { UserDefaults.standard.set(scanIncludeDevelopment, forKey: "scanIncludeDevelopment") }
    }
    @Published var scanIncludeTempFiles: Bool {
        didSet { UserDefaults.standard.set(scanIncludeTempFiles, forKey: "scanIncludeTempFiles") }
    }
    @Published var scanIncludeMailAttachments: Bool {
        didSet { UserDefaults.standard.set(scanIncludeMailAttachments, forKey: "scanIncludeMailAttachments") }
    }
    @Published var scanIncludeAppLeftovers: Bool {
        didSet { UserDefaults.standard.set(scanIncludeAppLeftovers, forKey: "scanIncludeAppLeftovers") }
    }
    @Published var scanIncludeLargeFiles: Bool {
        didSet { UserDefaults.standard.set(scanIncludeLargeFiles, forKey: "scanIncludeLargeFiles") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var menuBarTab: String {
        didSet { UserDefaults.standard.set(menuBarTab, forKey: "menuBarTab") }
    }
    @Published var settingsSectionRaw: String {
        didSet { UserDefaults.standard.set(settingsSectionRaw, forKey: "settingsSectionRaw") }
    }
    @Published var mainSectionRaw: String {
        didSet { UserDefaults.standard.set(mainSectionRaw, forKey: "mainSectionRaw") }
    }

    init() {
        let ud = UserDefaults.standard
        // First-run defaults: launch at login in menu bar mode.
        if ud.object(forKey: "launchAtLogin") == nil {
            ud.set(true, forKey: "launchAtLogin")
        }
        if ud.object(forKey: "launchAtLoginMenuBarOnly") == nil {
            ud.set(true, forKey: "launchAtLoginMenuBarOnly")
        }
        if ud.object(forKey: "scanIncludeUserCaches") == nil {
            ud.set(true, forKey: "scanIncludeUserCaches")
        }
        if ud.object(forKey: "scanIncludeLogs") == nil {
            ud.set(true, forKey: "scanIncludeLogs")
        }
        if ud.object(forKey: "scanIncludeBrowserCaches") == nil {
            ud.set(true, forKey: "scanIncludeBrowserCaches")
        }
        if ud.object(forKey: "scanIncludeDevelopment") == nil {
            ud.set(true, forKey: "scanIncludeDevelopment")
        }
        if ud.object(forKey: "scanIncludeTempFiles") == nil {
            ud.set(true, forKey: "scanIncludeTempFiles")
        }
        if ud.object(forKey: "scanIncludeMailAttachments") == nil {
            ud.set(true, forKey: "scanIncludeMailAttachments")
        }
        if ud.object(forKey: "scanIncludeAppLeftovers") == nil {
            ud.set(true, forKey: "scanIncludeAppLeftovers")
        }
        if ud.object(forKey: "scanIncludeLargeFiles") == nil {
            ud.set(true, forKey: "scanIncludeLargeFiles")
        }
        launchAtLogin       = ud.object(forKey: "launchAtLogin") as? Bool ?? true
        launchAtLoginMenuBarOnly = ud.object(forKey: "launchAtLoginMenuBarOnly") as? Bool ?? true
        showMenuBarAlways   = ud.object(forKey: "showMenuBarAlways") as? Bool ?? true
        showDockIcon        = ud.object(forKey: "showDockIcon") as? Bool ?? true
        refreshInterval     = ud.object(forKey: "refreshInterval") as? Double ?? 2.0
        menuBarShowCPU      = ud.object(forKey: "menuBarShowCPU") as? Bool ?? true
        menuBarShowRAM      = ud.object(forKey: "menuBarShowRAM") as? Bool ?? true
        menuBarShowDisk     = ud.object(forKey: "menuBarShowDisk") as? Bool ?? true
        menuBarShowNetwork  = ud.object(forKey: "menuBarShowNetwork") as? Bool ?? false
        largeFileThresholdMB = ud.object(forKey: "largeFileThresholdMB") as? Double ?? 100
        scanIncludeUserCaches = ud.object(forKey: "scanIncludeUserCaches") as? Bool ?? true
        scanIncludeLogs = ud.object(forKey: "scanIncludeLogs") as? Bool ?? true
        scanIncludeBrowserCaches = ud.object(forKey: "scanIncludeBrowserCaches") as? Bool ?? true
        scanIncludeDevelopment = ud.object(forKey: "scanIncludeDevelopment") as? Bool ?? true
        scanIncludeTempFiles = ud.object(forKey: "scanIncludeTempFiles") as? Bool ?? true
        scanIncludeMailAttachments = ud.object(forKey: "scanIncludeMailAttachments") as? Bool ?? true
        scanIncludeAppLeftovers = ud.object(forKey: "scanIncludeAppLeftovers") as? Bool ?? true
        scanIncludeLargeFiles = ud.object(forKey: "scanIncludeLargeFiles") as? Bool ?? true
        notificationsEnabled = ud.object(forKey: "notificationsEnabled") as? Bool ?? true
        menuBarTab          = ud.string(forKey: "menuBarTab") ?? "Overview"
        settingsSectionRaw  = ud.string(forKey: "settingsSectionRaw") ?? "General"
        mainSectionRaw      = ud.string(forKey: "mainSectionRaw") ?? AppSection.dashboard.rawValue
    }

    var mainSection: AppSection {
        get { AppSection(rawValue: mainSectionRaw) ?? .dashboard }
        set { mainSectionRaw = newValue.rawValue }
    }

    // Backward compatibility for existing references.
    @available(*, deprecated, renamed: "largeFileThresholdMB")
    var largFileThresholdMB: Double {
        get { largeFileThresholdMB }
        set { largeFileThresholdMB = newValue }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme
struct AppTheme {
    // Brand colors from SVG logo
    static let brandCyan   = Color(hex: "35F8F7")
    static let brandBlue   = Color(hex: "4063EE")
    static let brandDarkBg = Color(hex: "1E242F")
    static let brandDark   = Color(hex: "080D18")
    static let brandBorder = Color(hex: "494D5A")

    static let accent      = Color(hex: "3AABF2") // Mid-point of brand gradient
    static let accentAlt   = Color(hex: "4063EE")
    static let success     = Color(hex: "38EF7D")
    static let warning     = Color(hex: "F5A623")
    static let danger      = Color(hex: "D0021B")
    static let cardBg      = Color(NSColor.controlBackgroundColor)
    static let windowBg    = Color(NSColor.windowBackgroundColor)
    static let sidebarBg   = Color(NSColor.underPageBackgroundColor)
    static let supportYellow = Color(hex: "FFD54A")
    static let supportAmber = Color(hex: "FFB300")
    static let supportText = Color(hex: "2B1B00")

    static let gradient = LinearGradient(
        colors: [accent, accentAlt],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Brand gradient matching SVG: cyan → blue
    static let brandGradient = LinearGradient(
        colors: [brandCyan, Color(hex: "37D5F4"), Color(hex: "3AABF2"), brandBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let supportGradient = LinearGradient(
        colors: [supportYellow, supportAmber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func sectionGradient(_ section: AppSection) -> LinearGradient {
        LinearGradient(
            colors: section.gradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct SupportCoffeeButton: View {
    var compact: Bool = true
    @State private var isHovered = false

    var body: some View {
        Button {
            guard let url = URL(string: "https://ko-fi.com/mehmedhunjra") else { return }
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: compact ? 6 : 10) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: compact ? 11 : 14, weight: .bold))
                Text("Buy Me a Coffee")
                    .font(.system(size: compact ? 11 : 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundColor(AppTheme.supportText)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 6 : 10)
            .background(
                RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                    .fill(AppTheme.supportGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: Color(hex: "FFCA28").opacity(isHovered ? 0.45 : 0.22), radius: isHovered ? 14 : 8, y: 3)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.14), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct ToolPrimaryActionButton: View {
    let title: String
    let colors: [Color]
    var icon: String? = nil
    var minWidth: CGFloat = 176
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(minWidth: minWidth)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(
                color: colors.first?.opacity(isHovered ? 0.42 : 0.22) ?? .black.opacity(0.2),
                radius: isHovered ? 14 : 8,
                y: 4
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct WindowSupportOverlay: ViewModifier {
    var hidden: Bool
    var topPadding: CGFloat = 10
    var trailingPadding: CGFloat = 14

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            if !hidden {
                HStack {
                    Spacer(minLength: 0)
                    SupportCoffeeButton(compact: true)
                }
                .padding(.top, topPadding)
                .padding(.bottom, 6)
                .padding(.trailing, trailingPadding)
            }
        }
    }
}

extension View {
    func windowSupportOverlay(hidden: Bool = false, topPadding: CGFloat = 10, trailingPadding: CGFloat = 14) -> some View {
        modifier(WindowSupportOverlay(hidden: hidden, topPadding: topPadding, trailingPadding: trailingPadding))
    }
}
