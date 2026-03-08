import Foundation
import SwiftUI
import AppKit
import UserNotifications

// MARK: - Notification Manager

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func playSound(_ name: String) {
        NSSound(named: name)?.play()
    }

    func notifyThreatDetected(threatCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "MacSweep — Threat Detected"
        content.body  = "\(threatCount) suspicious file\(threatCount == 1 ? "" : "s") found. Open MacSweep to review."
        content.sound = .default
        deliver(content, id: "threat-\(Date().timeIntervalSince1970)")
    }

    func notifyIntegrityAlert(description: String) {
        let content = UNMutableNotificationContent()
        content.title = "MacSweep — System Integrity Alert"
        content.body  = description
        content.sound = .default
        deliver(content, id: "integrity-\(Date().timeIntervalSince1970)")
    }

    private func deliver(_ content: UNMutableNotificationContent, id: String) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

// MARK: - Threat Severity

enum ThreatSeverity: String, CaseIterable {
    case low      = "Low"
    case medium   = "Medium"
    case high     = "High"
    case critical = "Critical"

    var color: Color {
        switch self {
        case .low:      return Color(hex: "38A858")
        case .medium:   return Color(hex: "F5A623")
        case .high:     return Color(hex: "E07030")
        case .critical: return Color(hex: "E03A3A")
        }
    }

    var icon: String {
        switch self {
        case .low:      return "checkmark.shield.fill"
        case .medium:   return "exclamationmark.triangle.fill"
        case .high:     return "xmark.shield.fill"
        case .critical: return "flame.fill"
        }
    }
}

// MARK: - Threat Category

enum ThreatCategory: String, CaseIterable {
    case malware      = "Malware"
    case adware       = "Adware"
    case spyware      = "Spyware"
    case trojan       = "Trojan"
    case ransomware   = "Ransomware"
    case pup          = "Potentially Unwanted"
    case hackTool     = "Hack Tool"
    case suspicious   = "Suspicious"

    var icon: String {
        switch self {
        case .malware:    return "ant.fill"
        case .adware:     return "rectangle.badge.minus"
        case .spyware:    return "eye.fill"
        case .trojan:     return "theatermasks.fill"
        case .ransomware: return "lock.fill"
        case .pup:        return "questionmark.circle.fill"
        case .hackTool:   return "terminal.fill"
        case .suspicious: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Threat Item

struct ThreatItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let severity: ThreatSeverity
    let category: ThreatCategory
    let description: String
    let detectedAt: Date
    var isQuarantined: Bool = false

    var url: URL { URL(fileURLWithPath: path) }

    var sizeFormatted: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Quarantine Item

struct QuarantineItem: Identifiable, Codable {
    let id: UUID
    let originalPath: String
    let quarantinePath: String
    let name: String
    let threatName: String
    let severity: String
    let quarantinedAt: Date

    init(id: UUID = UUID(), originalPath: String, quarantinePath: String,
         name: String, threatName: String, severity: ThreatSeverity, quarantinedAt: Date = Date()) {
        self.id = id
        self.originalPath = originalPath
        self.quarantinePath = quarantinePath
        self.name = name
        self.threatName = threatName
        self.severity = severity.rawValue
        self.quarantinedAt = quarantinedAt
    }

    var severityEnum: ThreatSeverity { ThreatSeverity(rawValue: severity) ?? .medium }

    var sizeFormatted: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: quarantinePath),
              let size = attrs[.size] as? Int64 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var dateFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: quarantinedAt)
    }
}

// MARK: - Quarantine Manager

class QuarantineManager: ObservableObject {
    @Published var items: [QuarantineItem] = []

    static let quarantineDir: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("MacSweep/Quarantine", isDirectory: true)
    }()

    private let dbURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("MacSweep/quarantine_db.json")
    }()

    init() {
        createQuarantineDirectory()
        loadDB()
    }

    private func createQuarantineDirectory() {
        try? FileManager.default.createDirectory(at: Self.quarantineDir, withIntermediateDirectories: true)
    }

    func quarantine(threat: ThreatItem) throws -> QuarantineItem {
        let dest = Self.quarantineDir.appendingPathComponent(UUID().uuidString + "_" + threat.url.lastPathComponent)
        try FileManager.default.moveItem(at: threat.url, to: dest)

        let item = QuarantineItem(
            originalPath: threat.path,
            quarantinePath: dest.path,
            name: threat.name,
            threatName: "\(threat.category.rawValue): \(threat.name)",
            severity: threat.severity,
            quarantinedAt: Date()
        )
        DispatchQueue.main.async { self.items.append(item) }
        saveDB()
        return item
    }

    func restore(_ item: QuarantineItem) throws {
        let dest = URL(fileURLWithPath: item.originalPath)
        try FileManager.default.moveItem(at: URL(fileURLWithPath: item.quarantinePath), to: dest)
        DispatchQueue.main.async { self.items.removeAll { $0.id == item.id } }
        saveDB()
    }

    func delete(_ item: QuarantineItem) throws {
        try FileManager.default.removeItem(at: URL(fileURLWithPath: item.quarantinePath))
        DispatchQueue.main.async { self.items.removeAll { $0.id == item.id } }
        saveDB()
    }

    private func saveDB() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(items) {
            try? data.write(to: dbURL)
        }
    }

    private func loadDB() {
        guard let data = try? Data(contentsOf: dbURL),
              let decoded = try? JSONDecoder().decode([QuarantineItem].self, from: data) else { return }
        // Filter out items whose quarantine file no longer exists
        items = decoded.filter { FileManager.default.fileExists(atPath: $0.quarantinePath) }
    }
}

// MARK: - Malware Scan Engine

enum SecurityScanMode: String, CaseIterable {
    case quick  = "Quick Scan"
    case full   = "Full Scan"
    case custom = "Custom Scan"

    var icon: String {
        switch self {
        case .quick:  return "bolt.fill"
        case .full:   return "shield.lefthalf.filled"
        case .custom: return "folder.badge.gear"
        }
    }

    var description: String {
        switch self {
        case .quick:  return "Scans common threat locations (~2 min)"
        case .full:   return "Deep scan of entire system (~10 min)"
        case .custom: return "Scan a folder you choose"
        }
    }

    var targets: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .quick:
            return [
                home + "/Downloads",
                home + "/Desktop",
                home + "/Library/LaunchAgents",
                "/Library/LaunchAgents",
                "/Library/LaunchDaemons",
                "/tmp"
            ]
        case .full:
            return [home, "/Applications", "/Library", "/usr/local/bin"]
        case .custom:
            return []
        }
    }
}

class MalwareScanEngine: ObservableObject {
    @Published var isScanning = false
    @Published var currentPath = ""
    @Published var threats: [ThreatItem] = []
    @Published var scannedCount = 0
    @Published var progress: Double = 0
    @Published var scanMode: SecurityScanMode = .quick
    @Published var customTarget: URL? = nil
    @Published var lastScanDate: Date? = nil
    @Published var selectedThreats: Set<UUID> = []

    func toggleSelection(_ threatID: UUID) {
        if selectedThreats.contains(threatID) {
            selectedThreats.remove(threatID)
        } else {
            selectedThreats.insert(threatID)
        }
    }

    func selectAll() {
        selectedThreats = Set(threats.map { $0.id })
    }

    func deselectAll() {
        selectedThreats = []
    }

    func quarantineSelected() {
        let targets = threats.filter { selectedThreats.contains($0.id) }
        for threat in targets {
            quarantine(threat)
        }
        selectedThreats = []
    }

    func deleteSelected() {
        let targets = threats.filter { selectedThreats.contains($0.id) }
        for threat in targets {
            delete(threat)
        }
        selectedThreats = []
    }

    private var scanTask: Task<Void, Never>?

    var quarantineManager = QuarantineManager()

    // MARK: Heuristic Signatures

    // Known legitimate security tools whose names contain suspicious keywords
    private let trustedVendorPrefixes: [String] = [
        "com.malwarebytes.", "com.bitdefender.", "com.avast.", "com.symantec.",
        "com.norton.", "com.kaspersky.", "com.sophos.", "com.carbonblack.",
        "com.crowdstrike.", "com.sentinelone.", "com.eset.", "com.webroot.",
        "com.trendmicro.", "com.intego.", "com.objective-see.",
        "com.apple.", "com.google.", "com.microsoft.", "com.adobe."
    ]

    private func isTrustedVendor(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.lowercased()
        return trustedVendorPrefixes.contains(where: { name.hasPrefix($0) })
    }

    private let suspiciousNames: Set<String> = [
        "keystroke", "keylogger", "spyware", "backdoor", "rootkit",
        "cryptominer", "coinminer", "trojan", "ransom",
        "stealer", "injector", "loader", "dropper",
        "osascript_helper", "applescript_helper", "macspy", "macstealer"
    ]

    private let suspiciousExtensions: Set<String> = [
        "pkg.sh", "install.sh", "update.sh", "run.sh"
    ]

    private let highRiskPaths: Set<String> = [
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
        NSHomeDirectory() + "/Library/LaunchAgents"
    ]

    func startScan(mode: SecurityScanMode, custom: URL? = nil) {
        guard !isScanning else { return }
        scanTask?.cancel()
        isScanning = true
        threats = []
        scannedCount = 0
        progress = 0
        scanMode = mode
        customTarget = custom

        scanTask = Task {
            let targets: [String]
            if mode == .custom, let url = custom {
                targets = [url.path]
            } else {
                targets = mode.targets
            }
            await runHeuristicScan(targets: targets)
            await MainActor.run {
                self.isScanning = false
                self.progress = 1.0
                self.lastScanDate = Date()
                NotificationManager.shared.playSound("Submarine")
                if !self.threats.isEmpty {
                    NotificationManager.shared.notifyThreatDetected(threatCount: self.threats.count)
                }
            }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        isScanning = false
    }

    private func runHeuristicScan(targets: [String]) async {
        let fm = FileManager.default
        var allFiles: [String] = []

        // Enumerate files
        for target in targets {
            guard !Task.isCancelled else { return }
            let enumerator = fm.enumerator(atPath: target)
            while let relative = enumerator?.nextObject() as? String {
                allFiles.append((target as NSString).appendingPathComponent(relative))
            }
        }

        let total = max(allFiles.count, 1)
        for (i, filePath) in allFiles.enumerated() {
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.currentPath = filePath
                self.scannedCount = i + 1
                self.progress = Double(i + 1) / Double(total)
            }

            if let threat = checkHeuristics(path: filePath) {
                await MainActor.run { self.threats.append(threat) }
            }

            // Yield every 50 files to keep UI responsive
            if i % 50 == 0 {
                try? await Task.sleep(nanoseconds: 1_000_000)
            }
        }
    }

    private func checkHeuristics(path: String) -> ThreatItem? {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        let fm = FileManager.default

        // Skip directories
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else { return nil }

        // Skip very large files (> 500MB) — not typical malware
        if let attrs = try? fm.attributesOfItem(atPath: path),
           let size = attrs[.size] as? Int64, size > 500_000_000 { return nil }

        // Skip known trusted security vendors (avoid false positives)
        if isTrustedVendor(path) { return nil }

        // Check name for suspicious keywords
        for keyword in suspiciousNames {
            if name.contains(keyword) {
                return ThreatItem(
                    name: url.lastPathComponent,
                    path: path,
                    severity: .high,
                    category: .suspicious,
                    description: "File name contains known suspicious pattern: '\(keyword)'",
                    detectedAt: Date()
                )
            }
        }

        // Check for executable scripts in auto-start paths
        if (ext == "sh" || ext == "py" || ext == "rb") {
            for riskPath in highRiskPaths {
                if path.hasPrefix(riskPath) {
                    return ThreatItem(
                        name: url.lastPathComponent,
                        path: path,
                        severity: .medium,
                        category: .suspicious,
                        description: "Executable script found in auto-run location",
                        detectedAt: Date()
                    )
                }
            }
        }

        // Check for LaunchAgent/Daemon plist pointing to suspicious locations
        if ext == "plist" {
            for riskPath in highRiskPaths {
                if path.hasPrefix(riskPath) {
                    if let dict = NSDictionary(contentsOfFile: path),
                       let program = dict["ProgramArguments"] as? [String],
                       let first = program.first {
                        let programName = (first as NSString).lastPathComponent.lowercased()
                        for keyword in suspiciousNames {
                            if programName.contains(keyword) {
                                return ThreatItem(
                                    name: url.lastPathComponent,
                                    path: path,
                                    severity: .critical,
                                    category: .malware,
                                    description: "LaunchAgent/Daemon targeting suspicious executable: \(first)",
                                    detectedAt: Date()
                                )
                            }
                        }
                    }
                }
            }
        }

        return nil
    }

    @Published var lastQuarantineError: String? = nil
    @Published var quarantineSuccessCount: Int = 0

    func quarantine(_ threat: ThreatItem) {
        do {
            _ = try quarantineManager.quarantine(threat: threat)
            threats.removeAll { $0.id == threat.id }
            quarantineSuccessCount += 1
        } catch {
            // File likely needs elevated permissions (system LaunchDaemons etc.)
            lastQuarantineError = "Cannot quarantine '\(threat.name)': \(error.localizedDescription). Try revealing it in Finder and removing manually."
        }
    }

    func quarantineAll() {
        lastQuarantineError = nil
        quarantineSuccessCount = 0
        var failed: [String] = []
        for threat in threats {
            do {
                _ = try quarantineManager.quarantine(threat: threat)
                quarantineSuccessCount += 1
            } catch {
                failed.append(threat.name)
            }
        }
        threats.removeAll { _ in true }
        if !failed.isEmpty {
            lastQuarantineError = "\(failed.count) file(s) could not be moved (require elevated permissions): \(failed.joined(separator: ", ")). Reveal them in Finder to remove manually."
        }
    }

    func delete(_ threat: ThreatItem) {
        do {
            try FileManager.default.removeItem(at: threat.url)
            threats.removeAll { $0.id == threat.id }
        } catch {
            lastQuarantineError = "Cannot delete '\(threat.name)': requires elevated permissions."
        }
    }

    func ignore(_ threat: ThreatItem) {
        threats.removeAll { $0.id == threat.id }
    }

    func revealInFinder(_ threat: ThreatItem) {
        NSWorkspace.shared.activateFileViewerSelecting([threat.url])
    }

    func openFile(_ threat: ThreatItem) {
        NSWorkspace.shared.open(threat.url)
    }
}

// MARK: - Adware Item

struct AdwareItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let type: AdwareType
    var isSelected: Bool = false   // default unselected; suspicious items get selected
    var isSuspicious: Bool = false

    enum AdwareType: String {
        case launchAgent  = "Launch Agent"
        case launchDaemon = "Launch Daemon"
        case loginItem    = "Login Item"
        case browserExt   = "Browser Extension"
    }

    var typeIcon: String {
        switch type {
        case .launchAgent:  return "gearshape.2.fill"
        case .launchDaemon: return "server.rack"
        case .loginItem:    return "arrow.right.circle.fill"
        case .browserExt:   return "puzzlepiece.extension.fill"
        }
    }

    var url: URL { URL(fileURLWithPath: path) }
}

// MARK: - Adware Cleaner Engine

class AdwareCleanEngine: ObservableObject {
    @Published var isScanning = false
    @Published var items: [AdwareItem] = []
    @Published var progress: Double = 0

    private let knownAdwareNames: Set<String> = [
        "genieo", "conduit", "vsearch", "spigot", "installmac",
        "mackeeper", "cleanmymac_adware", "vidx", "shopperr",
        "weknow", "lasso", "searchmarquis", "searchbaron",
        "purifier", "sweetplayer", "chumsearch"
    ]

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        items = []
        progress = 0

        Task {
            var found: [AdwareItem] = []
            let locations: [(String, AdwareItem.AdwareType)] = [
                (NSHomeDirectory() + "/Library/LaunchAgents", .launchAgent),
                ("/Library/LaunchAgents", .launchAgent),
                ("/Library/LaunchDaemons", .launchDaemon),
            ]

            let total = locations.count
            for (i, (dir, type)) in locations.enumerated() {
                await MainActor.run { self.progress = Double(i) / Double(total) }
                found.append(contentsOf: scanDirectory(dir, type: type))
            }

            // Login Items
            found.append(contentsOf: scanLoginItems())

            // Browser Extensions
            found.append(contentsOf: scanBrowserExtensions())

            let finalFound = found
            await MainActor.run {
                self.items = finalFound
                self.isScanning = false
                self.progress = 1.0
                NotificationManager.shared.playSound("Hero")
            }
        }
    }

    private func isSuspiciousName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return knownAdwareNames.contains(where: { lower.contains($0) })
    }

    private func scanDirectory(_ path: String, type: AdwareItem.AdwareType) -> [AdwareItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        var found: [AdwareItem] = []

        for file in contents {
            guard !file.hasPrefix(".") else { continue }
            let fullPath = (path as NSString).appendingPathComponent(file)

            // Check name against known adware list
            var suspicious = isSuspiciousName(file)

            // Also check plist ProgramArguments executable name
            if !suspicious, file.hasSuffix(".plist") {
                if let dict = NSDictionary(contentsOfFile: fullPath),
                   let args = dict["ProgramArguments"] as? [String],
                   let first = args.first {
                    let exe = (first as NSString).lastPathComponent
                    suspicious = isSuspiciousName(exe)
                }
            }

            // Include ALL items; mark suspicious ones
            found.append(AdwareItem(name: file, path: fullPath, type: type,
                                    isSelected: suspicious, isSuspicious: suspicious))
        }
        return found
    }

    private func scanLoginItems() -> [AdwareItem] {
        var found: [AdwareItem] = []
        let fm = FileManager.default

        // Modern login items location (macOS 13+)
        let loginItemsDirs = [
            NSHomeDirectory() + "/Library/Application Support/com.apple.backgroundtaskmanagementagent",
            "/Library/LaunchAgents"  // system-wide agents often used as login items
        ]

        for dir in loginItemsDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for file in contents {
                guard !file.hasPrefix(".") else { continue }
                let full = (dir as NSString).appendingPathComponent(file)
                let suspicious = isSuspiciousName(file)
                found.append(AdwareItem(name: file, path: full, type: .loginItem,
                                        isSelected: suspicious, isSuspicious: suspicious))
            }
        }

        // Also try reading com.apple.loginitems via defaults
        let loginPlist = NSHomeDirectory() + "/Library/Preferences/com.apple.loginitems.plist"
        if let dict = NSDictionary(contentsOfFile: loginPlist),
           let items = dict["SessionItems"] as? [String: Any],
           let customList = items["CustomListItems"] as? [[String: Any]] {
            for item in customList {
                if let name = item["Name"] as? String {
                    let suspicious = isSuspiciousName(name)
                    found.append(AdwareItem(name: name, path: name, type: .loginItem,
                                            isSelected: suspicious, isSuspicious: suspicious))
                }
            }
        }

        return found
    }

    private func scanBrowserExtensions() -> [AdwareItem] {
        var found: [AdwareItem] = []
        let home = NSHomeDirectory()
        let fm = FileManager.default

        let extPaths: [String] = [
            home + "/Library/Application Support/Google/Chrome/Default/Extensions",
            home + "/Library/Application Support/Microsoft Edge/Default/Extensions",
            home + "/Library/Application Support/BraveSoftware/Brave-Browser/Default/Extensions",
            home + "/Library/Application Support/Firefox/Profiles",
        ]

        for extPath in extPaths {
            guard let extIDs = try? fm.contentsOfDirectory(atPath: extPath) else { continue }
            for extID in extIDs {
                guard !extID.hasPrefix(".") else { continue }
                let extDir = (extPath as NSString).appendingPathComponent(extID)

                // Chrome/Edge/Brave: look inside version subfolder for manifest.json
                if let versions = try? fm.contentsOfDirectory(atPath: extDir),
                   let version = versions.sorted().last {
                    let manifestPath = ((extDir as NSString).appendingPathComponent(version) as NSString)
                        .appendingPathComponent("manifest.json")
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let name = json["name"] as? String,
                       !name.hasPrefix("__") {  // skip internal Chrome extensions
                        let suspicious = isSuspiciousName(name)
                        found.append(AdwareItem(name: name, path: extDir, type: .browserExt,
                                                isSelected: suspicious, isSuspicious: suspicious))
                    }
                }
            }
        }
        return found
    }

    func remove(_ item: AdwareItem) {
        try? FileManager.default.removeItem(at: item.url)
        items.removeAll { $0.id == item.id }
    }

    func removeSelected() {
        let selected = items.filter { $0.isSelected }
        for item in selected { try? FileManager.default.removeItem(at: item.url) }
        items.removeAll { $0.isSelected }
    }
}

// MARK: - Network Connection

struct NetworkConnection: Identifiable {
    let id = UUID()
    let pid: Int
    let processName: String
    let localAddress: String
    let localPort: Int
    let remoteAddress: String
    let remotePort: Int
    let state: String
    let protocol_: String
    var isSuspicious: Bool = false
    var isBlocked: Bool = false

    var remoteDisplay: String {
        remoteAddress.isEmpty ? "—" : "\(remoteAddress):\(remotePort)"
    }

    var riskColor: Color {
        if isBlocked { return DS.danger }
        if isSuspicious { return DS.warning }
        return DS.success
    }
}

// MARK: - Network Monitor Engine

class NetworkMonitorEngine: ObservableObject {
    @Published var connections: [NetworkConnection] = []
    @Published var isMonitoring = false
    @Published var blockedIPs: Set<String> = []

    private var monitorTask: Task<Void, Never>?

    private let suspiciousPorts: Set<Int> = [
        4444, 1337, 31337, 5555, 9001, 9050, // Common C2/RAT ports
        6667, 6697, // IRC
        23, // Telnet
    ]

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitorTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        isMonitoring = false
    }

    func refresh() async {
        let parsed = await parseNetstat()
        await MainActor.run { self.connections = parsed }
    }

    private func parseNetstat() async -> [NetworkConnection] {
        // Use lsof for richer output including process name and PID
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        // -i tcp: TCP only, -n: no hostname resolve, -P: no port names, -F pcn: field output (pid/cmd/name)
        process.arguments = ["-i", "tcp", "-n", "-P", "-sTCP:ESTABLISHED,CLOSE_WAIT,SYN_SENT", "-F", "pcn"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Fallback to netstat if lsof fails
            return await parseNetstatFallback()
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            return await parseNetstatFallback()
        }

        var connections: [NetworkConnection] = []
        // lsof output: each record has multiple lines starting with field codes
        // p=pid, c=command, n=network address (local->remote)
        var currentPID = 0
        var currentName = "System"

        for line in output.components(separatedBy: "\n") {
            guard !line.isEmpty else { continue }
            let code = line.prefix(1)
            let value = String(line.dropFirst())

            switch code {
            case "p": currentPID = Int(value) ?? 0
            case "c": currentName = value
            case "n":
                // Format: "local->remote" or just "local" for LISTEN
                if value.contains("->") {
                    let parts = value.components(separatedBy: "->")
                    guard parts.count == 2 else { continue }
                    let (localAddr, localPort) = splitLsofAddr(parts[0])
                    let (remoteAddr, remotePort) = splitLsofAddr(parts[1])
                    guard !remoteAddr.isEmpty, remoteAddr != "*" else { continue }
                    let isSuspicious = suspiciousPorts.contains(remotePort) || blockedIPs.contains(remoteAddr)
                    connections.append(NetworkConnection(
                        pid: currentPID,
                        processName: currentName,
                        localAddress: localAddr,
                        localPort: localPort,
                        remoteAddress: remoteAddr,
                        remotePort: remotePort,
                        state: "ESTABLISHED",
                        protocol_: "tcp",
                        isSuspicious: isSuspicious,
                        isBlocked: blockedIPs.contains(remoteAddr)
                    ))
                }
            default: break
            }
        }

        // Deduplicate by remote address+port
        var seen = Set<String>()
        return connections.filter { conn in
            let key = "\(conn.remoteAddress):\(conn.remotePort)"
            return seen.insert(key).inserted
        }
    }

    private func parseNetstatFallback() async -> [NetworkConnection] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-p", "tcp", "-an"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run(); process.waitUntilExit() } catch { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var connections: [NetworkConnection] = []
        for line in output.components(separatedBy: "\n").dropFirst(2) {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 5, String(parts[0]).hasPrefix("tcp") else { continue }
            let localFull = String(parts[3])
            let remoteFull = String(parts[4])
            let state = parts.count >= 6 ? String(parts[5]) : ""
            let (localAddr, localPort) = splitAddressPort(localFull)
            let (remoteAddr, remotePort) = splitAddressPort(remoteFull)
            guard !remoteAddr.isEmpty, remoteAddr != "*" else { continue }
            let isSuspicious = suspiciousPorts.contains(remotePort) || blockedIPs.contains(remoteAddr)
            connections.append(NetworkConnection(
                pid: 0, processName: "System",
                localAddress: localAddr, localPort: localPort,
                remoteAddress: remoteAddr, remotePort: remotePort,
                state: state, protocol_: "tcp",
                isSuspicious: isSuspicious, isBlocked: blockedIPs.contains(remoteAddr)
            ))
        }
        return connections
    }

    private func splitLsofAddr(_ addr: String) -> (String, Int) {
        // lsof format: "192.168.1.1:443" or "[::1]:443"
        if addr.hasPrefix("[") {
            // IPv6: [::1]:port
            if let closeBracket = addr.firstIndex(of: "]") {
                let ipv6 = String(addr[addr.index(after: addr.startIndex)..<closeBracket])
                let rest = String(addr[addr.index(after: closeBracket)...])
                let port = Int(rest.dropFirst()) ?? 0  // drop the ":"
                return (ipv6, port)
            }
            return (addr, 0)
        }
        if let lastColon = addr.lastIndex(of: ":") {
            let ip = String(addr[addr.startIndex..<lastColon])
            let port = Int(addr[addr.index(after: lastColon)...]) ?? 0
            return (ip, port)
        }
        return (addr, 0)
    }

    private func splitAddressPort(_ fullAddr: String) -> (String, Int) {
        // Handle IPv6 like [::1].53 or *.443 or 192.168.1.1.443
        if fullAddr == "*.*" || fullAddr == "*" { return ("", 0) }

        if let dotRange = fullAddr.range(of: ".", options: .backwards) {
            let addr = String(fullAddr[fullAddr.startIndex..<dotRange.lowerBound])
            let port = Int(fullAddr[dotRange.upperBound...]) ?? 0
            return (addr, port)
        }
        return (fullAddr, 0)
    }

    func blockConnection(_ conn: NetworkConnection) {
        blockedIPs.insert(conn.remoteAddress)
        if let idx = connections.firstIndex(where: { $0.id == conn.id }) {
            connections[idx].isBlocked = true
        }
    }

    func allowConnection(_ conn: NetworkConnection) {
        blockedIPs.remove(conn.remoteAddress)
        if let idx = connections.firstIndex(where: { $0.id == conn.id }) {
            connections[idx].isBlocked = false
        }
    }
}

// MARK: - Ransomware Guard Engine

struct FileChangeEvent: Identifiable {
    let id = UUID()
    let path: String
    let eventType: String
    let timestamp: Date

    var fileName: String { (path as NSString).lastPathComponent }
    var timeFormatted: String {
        let f = DateFormatter()
        f.timeStyle = .medium
        return f.string(from: timestamp)
    }
}

class RansomwareGuardEngine: ObservableObject {
    @Published var isMonitoring = false
    @Published var recentEvents: [FileChangeEvent] = []
    @Published var encryptionRate: Int = 0
    @Published var alertLevel: AlertLevel = .safe
    @Published var blockedProcesses: [String] = []

    enum AlertLevel: String {
        case safe     = "Protected"
        case warning  = "Unusual Activity"
        case critical = "Ransomware Suspected"

        var color: Color {
            switch self {
            case .safe:     return DS.success
            case .warning:  return DS.warning
            case .critical: return DS.danger
            }
        }

        var icon: String {
            switch self {
            case .safe:     return "checkmark.shield.fill"
            case .warning:  return "exclamationmark.triangle.fill"
            case .critical: return "flame.fill"
            }
        }
    }

    // Snapshot: directory path → (filename → modification date)
    private var snapshots: [String: [String: Date]] = [:]
    private var monitorTimer: Timer?

    private let watchedDirs: [String] = [
        NSHomeDirectory() + "/Documents",
        NSHomeDirectory() + "/Desktop",
        NSHomeDirectory() + "/Downloads",
        NSHomeDirectory() + "/Pictures"
    ]

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        alertLevel = .safe

        // Take initial baseline snapshots (no events on first pass)
        for dir in watchedDirs {
            snapshots[dir] = snapshotDirectory(dir)
        }

        // Poll every 4 seconds for real file changes
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTimer?.invalidate()
        monitorTimer = nil
        snapshots = [:]
        alertLevel = .safe
        encryptionRate = 0
    }

    /// Returns a flat snapshot: fileName → modificationDate for 1-level deep scan
    private func snapshotDirectory(_ path: String) -> [String: Date] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return [:] }
        var result: [String: Date] = [:]
        for file in contents {
            let full = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: full),
               let modified = attrs[.modificationDate] as? Date {
                result[full] = modified
            }
        }
        return result
    }

    private func checkForChanges() {
        for dir in watchedDirs {
            let current = snapshotDirectory(dir)
            let previous = snapshots[dir] ?? [:]

            // New or modified files
            for (filePath, modDate) in current {
                if let prevDate = previous[filePath] {
                    if modDate > prevDate {
                        addEvent(filePath, type: "Modified")
                    }
                } else {
                    addEvent(filePath, type: "Created")
                }
            }

            // Deleted files
            for filePath in previous.keys where current[filePath] == nil {
                addEvent(filePath, type: "Deleted")
            }

            snapshots[dir] = current
        }

        // Update rate and alert level
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        let recentCount = recentEvents.filter { $0.timestamp > oneMinuteAgo }.count
        DispatchQueue.main.async {
            self.encryptionRate = recentCount
            if recentCount > 50 {
                self.alertLevel = .critical
            } else if recentCount > 20 {
                self.alertLevel = .warning
            } else {
                self.alertLevel = .safe
            }
        }
    }

    func addEvent(_ path: String, type: String) {
        let event = FileChangeEvent(path: path, eventType: type, timestamp: Date())
        DispatchQueue.main.async {
            self.recentEvents.insert(event, at: 0)
            if self.recentEvents.count > 200 {
                self.recentEvents = Array(self.recentEvents.prefix(200))
            }
        }
    }

    func clearEvents() {
        recentEvents = []
        encryptionRate = 0
        alertLevel = .safe
    }
}

// MARK: - Realtime Protection Engine (FSEvents-based)

class RealtimeProtectionEngine: ObservableObject {
    @Published var isEnabled = false
    @Published var activityLog: [ActivityLogEntry] = []
    @Published var threatsBlocked: Int = 0
    @Published var filesScanned: Int = 0

    struct ActivityLogEntry: Identifiable {
        let id = UUID()
        let message: String
        let level: LogLevel
        let timestamp: Date

        var timeFormatted: String {
            let f = DateFormatter()
            f.timeStyle = .medium
            return f.string(from: timestamp)
        }

        enum LogLevel: String {
            case info    = "Info"
            case warning = "Warning"
            case threat  = "Threat"
            case blocked = "Blocked"

            var color: Color {
                switch self {
                case .info:    return DS.textMuted
                case .warning: return DS.warning
                case .threat:  return Color(hex: "E07030")
                case .blocked: return DS.danger
                }
            }

            var icon: String {
                switch self {
                case .info:    return "info.circle"
                case .warning: return "exclamationmark.triangle"
                case .threat:  return "xmark.shield"
                case .blocked: return "shield.slash"
                }
            }
        }
    }

    // MARK: - FSEvents stream
    private var eventStream: FSEventStreamRef?
    private let watchedPaths: [String] = [
        NSHomeDirectory() + "/Downloads",
        NSHomeDirectory() + "/Desktop",
        NSHomeDirectory() + "/Documents",
        "/private/tmp"
    ]

    // Known files snapshot to detect new/modified files
    private var knownFiles: [String: Date] = [:]  // path → mod date

    // Heuristic signatures (shared with MalwareScanEngine concept)
    private let suspiciousNames: Set<String> = [
        "keystroke", "keylogger", "spyware", "backdoor", "rootkit",
        "cryptominer", "coinminer", "trojan", "ransom",
        "stealer", "injector", "loader", "dropper",
        "osascript_helper", "applescript_helper", "macspy", "macstealer"
    ]

    private let suspiciousExtensions: Set<String> = [
        "command", "scpt", "scptd"
    ]

    private let highRiskExtensions: Set<String> = [
        "dmg", "pkg", "app", "sh", "py", "rb", "pl"
    ]

    // MARK: - Enable / Disable

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        log("Real-time protection enabled", level: .info)

        // Take baseline snapshot of watched directories
        takeBaselineSnapshot()

        // Start FSEvents stream
        startFSEventsStream()
    }

    func disable() {
        isEnabled = false
        stopFSEventsStream()
        knownFiles = [:]
        log("Real-time protection disabled", level: .warning)
    }

    // MARK: - Baseline Snapshot

    private func takeBaselineSnapshot() {
        let fm = FileManager.default
        for dir in watchedPaths {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for file in contents {
                let fullPath = (dir as NSString).appendingPathComponent(file)
                if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                   let modDate = attrs[.modificationDate] as? Date {
                    knownFiles[fullPath] = modDate
                }
            }
        }
        log("Baseline: tracking \(knownFiles.count) files across \(watchedPaths.count) directories", level: .info)
    }

    // MARK: - FSEvents Stream

    private func startFSEventsStream() {
        let pathsToWatch = watchedPaths as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { (
            streamRef, clientCallBackInfo, numEvents, eventPaths,
            eventFlags, eventIds
        ) in
            guard let info = clientCallBackInfo else { return }
            let engine = Unmanaged<RealtimeProtectionEngine>.fromOpaque(info).takeUnretainedValue()
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

            for i in 0..<numEvents {
                let path = paths[i]
                let flags = eventFlags[i]
                // Only process item-level events (file created, modified, renamed)
                let itemFlags: UInt32 = UInt32(kFSEventStreamEventFlagItemCreated)
                    | UInt32(kFSEventStreamEventFlagItemModified)
                    | UInt32(kFSEventStreamEventFlagItemRenamed)

                if flags & itemFlags != 0 {
                    engine.handleFileEvent(path: path, flags: flags)
                }
            }
        }

        eventStream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.5, // latency in seconds — batch events for efficiency
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        )

        if let stream = eventStream {
            // macOS 13+: dispatch-queue scheduling replaces run-loop scheduling.
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
            log("FSEvents monitor started", level: .info)
        }
    }

    private func stopFSEventsStream() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    // MARK: - Handle File Events

    private func handleFileEvent(path: String, flags: UInt32) {
        let fm = FileManager.default

        // Skip directories
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            // File was deleted — just note it
            if knownFiles.removeValue(forKey: path) != nil {
                // File we were tracking was removed — not suspicious by itself
            }
            return
        }
        if isDir.boolValue { return }

        // Skip hidden files and system files
        let fileName = (path as NSString).lastPathComponent
        if fileName.hasPrefix(".") { return }

        // Check if this is a new or modified file
        let currentModDate = (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        let previousModDate = knownFiles[path]
        let isNew = (previousModDate == nil)
        let isModified = !isNew && currentModDate != previousModDate

        guard isNew || isModified else { return }

        // Update snapshot
        if let date = currentModDate {
            knownFiles[path] = date
        }

        // Run heuristic check on the file
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.scanFile(path: path, isNew: isNew)
        }
    }

    // MARK: - Heuristic File Scan

    private func scanFile(path: String, isNew: Bool) {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        DispatchQueue.main.async { self.filesScanned += 1 }

        // Check for suspicious filename keywords
        for keyword in suspiciousNames {
            if name.contains(keyword) {
                DispatchQueue.main.async {
                    self.threatsBlocked += 1
                    self.log("⚠️ Suspicious file detected: \(url.lastPathComponent) (pattern: '\(keyword)')", level: .threat)
                }
                return
            }
        }

        // Check for risky extensions on new files
        if isNew && highRiskExtensions.contains(ext) {
            DispatchQueue.main.async {
                self.log("New \(ext.uppercased()) file: \(url.lastPathComponent)", level: .warning)
            }
            return
        }

        // Check for executable scripts
        if suspiciousExtensions.contains(ext) {
            DispatchQueue.main.async {
                self.log("Executable script detected: \(url.lastPathComponent)", level: .warning)
            }
            return
        }

        // Check for double extensions (e.g., photo.jpg.app, document.pdf.sh)
        let components = name.components(separatedBy: ".")
        if components.count >= 3 {
            let secondToLast = components[components.count - 2]
            let hiddenTypes = ["jpg", "jpeg", "png", "gif", "pdf", "doc", "docx", "mp3", "mp4", "mov"]
            if hiddenTypes.contains(secondToLast) && highRiskExtensions.contains(ext) {
                DispatchQueue.main.async {
                    self.threatsBlocked += 1
                    self.log("⚠️ Hidden extension trick: \(url.lastPathComponent) — executable disguised as \(secondToLast.uppercased())", level: .threat)
                }
                return
            }
        }

        // File is clean — log sparingly (only every 10th clean file to avoid log spam)
        if filesScanned % 10 == 0 {
            let shortPath = path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
            DispatchQueue.main.async {
                self.log("OK: \(shortPath)", level: .info)
            }
        }
    }

    // MARK: - Logging

    func log(_ message: String, level: ActivityLogEntry.LogLevel) {
        let entry = ActivityLogEntry(message: message, level: level, timestamp: Date())
        DispatchQueue.main.async {
            self.activityLog.insert(entry, at: 0)
            if self.activityLog.count > 300 { self.activityLog = Array(self.activityLog.prefix(300)) }
        }
    }

    func clearLog() {
        activityLog = []
    }

    deinit {
        stopFSEventsStream()
    }
}
// MARK: - System Integrity Monitor (SIM)

struct IntegrityItem: Identifiable {
    enum Kind: String, CaseIterable {
        case launchAgent      = "Launch Agent"
        case launchDaemon     = "Launch Daemon"
        case loginItem        = "Login Item"
        case cronJob          = "Cron Job"
        case hosts            = "/etc/hosts"
        case sshConfig        = "SSH Config"
        case systemExtension  = "System Extension"
        case kernelExtension  = "Kernel Extension"
        case tccPermission    = "TCC Permission"
        case unknown          = "Unknown"

        var icon: String {
            switch self {
            case .launchAgent:     return "bolt.circle"
            case .launchDaemon:    return "bolt.shield"
            case .loginItem:       return "person.badge.key"
            case .cronJob:         return "clock.badge.exclamationmark"
            case .hosts:           return "network"
            case .sshConfig:       return "lock.laptopcomputer"
            case .systemExtension: return "puzzlepiece.extension"
            case .kernelExtension: return "cpu"
            case .tccPermission:   return "hand.raised"
            case .unknown:         return "questionmark.diamond"
            }
        }

        /// Short label for filter chips
        var shortLabel: String {
            switch self {
            case .launchAgent:     return "Agents"
            case .launchDaemon:    return "Daemons"
            case .loginItem:       return "Login"
            case .cronJob:         return "Cron"
            case .hosts:           return "Hosts"
            case .sshConfig:       return "SSH"
            case .systemExtension: return "SysExt"
            case .kernelExtension: return "Kext"
            case .tccPermission:   return "TCC"
            case .unknown:         return "Other"
            }
        }
    }

    enum Risk: String, Comparable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"

        var color: Color {
            switch self {
            case .low: return DS.success
            case .medium: return DS.warning
            case .high: return Color(hex: "E07030")
            case .critical: return DS.danger
            }
        }

        var icon: String {
            switch self {
            case .low:      return "checkmark.shield"
            case .medium:   return "exclamationmark.triangle"
            case .high:     return "exclamationmark.shield"
            case .critical: return "xmark.shield.fill"
            }
        }

        private var severityRank: Int {
            switch self {
            case .low: return 0
            case .medium: return 1
            case .high: return 2
            case .critical: return 3
            }
        }

        static func < (lhs: Risk, rhs: Risk) -> Bool {
            return lhs.severityRank < rhs.severityRank
        }
    }

    let id = UUID()
    let kind: Kind
    let name: String
    let path: String
    let targetExecutable: String?
    let teamIdentifier: String?
    let codeSigned: Bool
    let firstSeen: Date
    var lastChanged: Date
    var risk: Risk
    var isWhitelisted: Bool = false
    var detail: String? = nil

    var sizeFormatted: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

final class IntegrityMonitorEngine: ObservableObject {
    // MARK: Published State
    @Published private(set) var items: [IntegrityItem] = []
    @Published var isMonitoring: Bool = false
    @Published var lastBaselineDate: Date? = nil
    @Published var lastError: String? = nil
    @Published private(set) var monitoringStartDate: Date? = nil

    // MARK: Health Status
    enum HealthStatus: String {
        case healthy  = "Healthy"
        case warning  = "Attention"
        case critical = "Critical"

        var color: Color {
            switch self {
            case .healthy:  return DS.success
            case .warning:  return DS.warning
            case .critical: return DS.danger
            }
        }
        var icon: String {
            switch self {
            case .healthy:  return "checkmark.shield.fill"
            case .warning:  return "exclamationmark.triangle.fill"
            case .critical: return "xmark.shield.fill"
            }
        }
    }

    var healthStatus: HealthStatus {
        let critCount = items.filter { !$0.isWhitelisted && $0.risk == .critical }.count
        let highCount = items.filter { !$0.isWhitelisted && $0.risk == .high }.count
        if critCount > 0 { return .critical }
        if highCount > 2 { return .critical }
        if highCount > 0 { return .warning }
        let medCount = items.filter { !$0.isWhitelisted && $0.risk == .medium }.count
        if medCount > 3 { return .warning }
        return .healthy
    }

    var highRiskCount: Int {
        items.filter { !$0.isWhitelisted && ($0.risk == .high || $0.risk == .critical) }.count
    }

    var kindCounts: [IntegrityItem.Kind: Int] {
        Dictionary(grouping: items, by: \.kind).mapValues(\.count)
    }

    // MARK: Private State
    private var eventStream: FSEventStreamRef?
    private var baseline: [String: IntegrityItem] = [:]
    private var whitelist: Set<String> = []
    private var rescanTimer: Timer?

    private let fm = FileManager.default
    private let watchedDirs: [String] = [
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
        NSHomeDirectory() + "/Library/LaunchAgents"
    ]

    // Well-known domains that should NOT be redirected in /etc/hosts
    private let suspiciousHostRedirectDomains: Set<String> = [
        "google.com", "apple.com", "icloud.com", "microsoft.com",
        "github.com", "amazonaws.com", "cloudflare.com",
        "facebook.com", "twitter.com", "ocsp.apple.com",
        "updates.apple.com", "swscan.apple.com"
    ]

    // MARK: - Public API

    func establishBaseline() {
        let snapshot = scanAll()
        baseline = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.path, $0) })
        items = snapshot
        lastBaselineDate = Date()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        if baseline.isEmpty { establishBaseline() }
        isMonitoring = true
        monitoringStartDate = Date()
        startEvents()
        startRescanTimer()
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringStartDate = nil
        stopEvents()
        stopRescanTimer()
    }

    func rescan() {
        let snapshot = scanAll()
        DispatchQueue.main.async {
            self.reconcile(with: snapshot)
        }
    }

    func toggleWhitelist(path: String) {
        if whitelist.contains(path) { whitelist.remove(path) } else { whitelist.insert(path) }
        for i in items.indices where items[i].path == path {
            items[i].isWhitelisted.toggle()
            items[i].risk = items[i].isWhitelisted ? .low : items[i].risk
        }
    }

    func reveal(_ item: IntegrityItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
    }

    func disable(_ item: IntegrityItem) throws {
        guard item.kind == .launchAgent || item.kind == .launchDaemon else { return }
        // Try to unload first
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = ["bootout", item.kind == .launchDaemon ? "system" : "gui/\(getuid())", item.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        // Then move to trash
        try fm.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
        rescan()
    }

    /// Generate a plain-text report of all items
    func exportReport() -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        var lines: [String] = []
        lines.append("╔══════════════════════════════════════════════════╗")
        lines.append("║       MacSweep — System Integrity Report        ║")
        lines.append("╚══════════════════════════════════════════════════╝")
        lines.append("")
        lines.append("Generated: \(df.string(from: Date()))")
        lines.append("Health: \(healthStatus.rawValue)")
        lines.append("Total Items: \(items.count)")
        lines.append("High/Critical: \(highRiskCount)")
        if let base = lastBaselineDate {
            lines.append("Baseline: \(df.string(from: base))")
        }
        lines.append("")
        lines.append(String(repeating: "─", count: 60))

        let sorted = items.sorted { $0.risk > $1.risk }
        for item in sorted {
            let wl = item.isWhitelisted ? " [WHITELISTED]" : ""
            let sig = item.codeSigned ? "✓ Signed" : "✗ Unsigned"
            lines.append("")
            lines.append("[\(item.risk.rawValue.uppercased())]\(wl) \(item.name)")
            lines.append("  Kind: \(item.kind.rawValue)")
            lines.append("  Path: \(item.path)")
            if let target = item.targetExecutable {
                lines.append("  Target: \(target)")
            }
            lines.append("  Code Sign: \(sig)")
            if let team = item.teamIdentifier, team != "not set" {
                lines.append("  Team ID: \(team)")
            }
            if let detail = item.detail {
                lines.append("  Detail: \(detail)")
            }
        }
        lines.append("")
        lines.append(String(repeating: "─", count: 60))
        lines.append("End of report")
        return lines.joined(separator: "\n")
    }

    // MARK: - Periodic Rescan Timer

    private func startRescanTimer() {
        stopRescanTimer()
        rescanTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.rescan()
            }
        }
        rescanTimer?.tolerance = 30
    }

    private func stopRescanTimer() {
        rescanTimer?.invalidate()
        rescanTimer = nil
    }

    // MARK: - Scanning

    private func scanAll() -> [IntegrityItem] {
        var result: [IntegrityItem] = []

        // 1. LaunchAgents / LaunchDaemons
        for (dir, kind) in [
            (NSHomeDirectory() + "/Library/LaunchAgents", IntegrityItem.Kind.launchAgent),
            ("/Library/LaunchAgents", IntegrityItem.Kind.launchAgent),
            ("/Library/LaunchDaemons", IntegrityItem.Kind.launchDaemon)
        ] {
            result.append(contentsOf: scanLaunchPlists(in: dir, kind: kind))
        }

        // 2. /etc/hosts
        result.append(contentsOf: scanHostsFile())

        // 3. Cron jobs
        result.append(contentsOf: scanCronJobs())

        // 4. Login Items (BTM agent plist)
        result.append(contentsOf: scanLoginItems())

        // 5. System Extensions
        result.append(contentsOf: scanSystemExtensions())

        // 6. Kernel Extensions
        result.append(contentsOf: scanKernelExtensions())

        // 7. SSH Config
        result.append(contentsOf: scanSSHConfig())

        return result.sorted { $0.riskPriority > $1.riskPriority }
    }

    // MARK: Launch Plists

    private func scanLaunchPlists(in directory: String, kind: IntegrityItem.Kind) -> [IntegrityItem] {
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }
        var found: [IntegrityItem] = []
        for file in contents where file.hasSuffix(".plist") && !file.hasPrefix(".") {
            let full = (directory as NSString).appendingPathComponent(file)
            let dict = NSDictionary(contentsOfFile: full)
            let programArgs = dict?["ProgramArguments"] as? [String]
            let program = dict?["Program"] as? String
            let target = programArgs?.first ?? program
            let item = buildIntegrityItem(kind: kind, path: full, name: file, target: target)
            found.append(item)
        }
        return found
    }

    // MARK: Hosts File

    private func scanHostsFile() -> [IntegrityItem] {
        let hostsPath = "/etc/hosts"
        guard fm.fileExists(atPath: hostsPath),
              let content = try? String(contentsOfFile: hostsPath, encoding: .utf8) else { return [] }

        var risk: IntegrityItem.Risk = .low
        var detail: String? = nil
        var suspiciousEntries: [String] = []

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }
            let ip = parts[0]
            let domain = parts[1].lowercased()
            // Skip localhost entries
            if domain == "localhost" || domain == "broadcasthost" { continue }
            // Check if a well-known domain is being redirected
            for suspicious in suspiciousHostRedirectDomains {
                if domain.contains(suspicious) && ip != "0.0.0.0" && ip != "127.0.0.1" {
                    suspiciousEntries.append("\(domain) → \(ip)")
                    risk = max(risk, .high)
                }
            }
        }

        let customEntries = lines.filter { l in
            let t = l.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && !t.hasPrefix("#") && !t.contains("localhost") && !t.contains("broadcasthost")
        }.count

        if customEntries > 20 { risk = max(risk, .medium) }
        if !suspiciousEntries.isEmpty {
            detail = "Suspicious redirections: \(suspiciousEntries.joined(separator: ", "))"
        } else if customEntries > 0 {
            detail = "\(customEntries) custom entries"
        }

        var item = buildIntegrityItem(kind: .hosts, path: hostsPath, name: "Hosts File", target: nil)
        item.risk = max(item.risk, risk)
        item.detail = detail
        return [item]
    }

    // MARK: Cron Jobs

    private func scanCronJobs() -> [IntegrityItem] {
        var found: [IntegrityItem] = []
        let user = NSUserName()

        // User crontab
        let userCrontab = "/usr/lib/cron/tabs/\(user)"
        if fm.fileExists(atPath: userCrontab) {
            var item = buildIntegrityItem(kind: .cronJob, path: userCrontab, name: "User Crontab (\(user))", target: nil)
            if let content = try? String(contentsOfFile: userCrontab, encoding: .utf8) {
                let jobs = content.components(separatedBy: .newlines).filter { !$0.hasPrefix("#") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                item.detail = "\(jobs.count) scheduled job\(jobs.count == 1 ? "" : "s")"
            }
            found.append(item)
        }

        // /etc/crontab
        let systemCrontab = "/etc/crontab"
        if fm.fileExists(atPath: systemCrontab) {
            var item = buildIntegrityItem(kind: .cronJob, path: systemCrontab, name: "System Crontab", target: nil)
            item.detail = "System-wide scheduled tasks"
            found.append(item)
        }

        // Periodic scripts
        for period in ["daily", "weekly", "monthly"] {
            let dir = "/etc/periodic/\(period)"
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for file in contents where !file.hasPrefix(".") {
                let full = (dir as NSString).appendingPathComponent(file)
                var item = buildIntegrityItem(kind: .cronJob, path: full, name: "\(period)/\(file)", target: full)
                item.detail = "Periodic \(period) script"
                found.append(item)
            }
        }

        return found
    }

    // MARK: Login Items

    private func scanLoginItems() -> [IntegrityItem] {
        var found: [IntegrityItem] = []
        // Modern login items (backgrounditems.btm)
        let btmPath = NSHomeDirectory() + "/Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm"
        if fm.fileExists(atPath: btmPath) {
            var item = buildIntegrityItem(kind: .loginItem, path: btmPath, name: "Background Task Items", target: nil)
            item.risk = .low
            item.detail = "macOS Background Task Management database"
            found.append(item)
        }

        // Legacy login items via shared file list
        let loginItemsDir = NSHomeDirectory() + "/Library/Application Support/com.apple.backgroundtaskmanagementagent"
        if fm.fileExists(atPath: loginItemsDir) {
            if let contents = try? fm.contentsOfDirectory(atPath: loginItemsDir) {
                for file in contents where file.hasSuffix(".plist") && file != "backgrounditems.btm" {
                    let full = (loginItemsDir as NSString).appendingPathComponent(file)
                    var item = buildIntegrityItem(kind: .loginItem, path: full, name: file, target: nil)
                    item.detail = "Legacy login item configuration"
                    found.append(item)
                }
            }
        }
        return found
    }

    // MARK: System Extensions

    private func scanSystemExtensions() -> [IntegrityItem] {
        var found: [IntegrityItem] = []
        let sysExtDir = "/Library/SystemExtensions"
        guard let contents = try? fm.contentsOfDirectory(atPath: sysExtDir) else { return [] }
        for dir in contents where !dir.hasPrefix(".") {
            let full = (sysExtDir as NSString).appendingPathComponent(dir)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            // Look for .systemextension bundles inside
            if let subContents = try? fm.contentsOfDirectory(atPath: full) {
                for ext in subContents where ext.hasSuffix(".systemextension") {
                    let extPath = (full as NSString).appendingPathComponent(ext)
                    let name = (ext as NSString).deletingPathExtension
                    var item = buildIntegrityItem(kind: .systemExtension, path: extPath, name: name, target: nil)
                    item.detail = "System Extension in \(dir)"
                    found.append(item)
                }
            }
        }
        return found
    }

    // MARK: Kernel Extensions

    private func scanKernelExtensions() -> [IntegrityItem] {
        var found: [IntegrityItem] = []
        let kextDir = "/Library/Extensions"
        guard let contents = try? fm.contentsOfDirectory(atPath: kextDir) else { return [] }
        for file in contents where file.hasSuffix(".kext") {
            let full = (kextDir as NSString).appendingPathComponent(file)
            let name = (file as NSString).deletingPathExtension
            // Check code signature of the kext bundle
            let plistPath = "\(full)/Contents/Info.plist"
            let bundleId = (NSDictionary(contentsOfFile: plistPath)?["CFBundleIdentifier"] as? String) ?? ""
            var item = buildIntegrityItem(kind: .kernelExtension, path: full, name: name, target: nil)
            item.detail = bundleId.isEmpty ? "Third-party kernel extension" : bundleId
            // Non-Apple kexts get elevated risk
            if !bundleId.lowercased().contains("apple") && !item.codeSigned {
                item.risk = max(item.risk, .high)
            }
            found.append(item)
        }
        return found
    }

    // MARK: SSH Config

    private func scanSSHConfig() -> [IntegrityItem] {
        var found: [IntegrityItem] = []

        let userSSH = NSHomeDirectory() + "/.ssh/config"
        if fm.fileExists(atPath: userSSH) {
            var risk: IntegrityItem.Risk = .low
            var detail: String? = nil
            if let content = try? String(contentsOfFile: userSSH, encoding: .utf8) {
                let lower = content.lowercased()
                if lower.contains("passwordauthentication yes") {
                    risk = max(risk, .medium)
                    detail = "PasswordAuthentication enabled"
                }
                if lower.contains("stricthostkeychecking no") {
                    risk = max(risk, .medium)
                    detail = (detail ?? "") + (detail != nil ? ", " : "") + "StrictHostKeyChecking disabled"
                }
                let hostCount = content.components(separatedBy: .newlines).filter { $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("host ") }.count
                if detail == nil { detail = "\(hostCount) host entries" }
            }
            var item = buildIntegrityItem(kind: .sshConfig, path: userSSH, name: "SSH Config (~/.ssh/config)", target: nil)
            item.risk = max(item.risk, risk)
            item.detail = detail
            found.append(item)
        }

        let systemSSH = "/etc/ssh/sshd_config"
        if fm.fileExists(atPath: systemSSH) {
            var risk: IntegrityItem.Risk = .low
            var detail: String? = "SSHD server configuration"
            if let content = try? String(contentsOfFile: systemSSH, encoding: .utf8) {
                let lower = content.lowercased()
                if lower.contains("permitrootlogin yes") {
                    risk = .high
                    detail = "PermitRootLogin enabled — high risk"
                }
                if lower.contains("passwordauthentication yes") {
                    risk = max(risk, .medium)
                    detail = (detail ?? "") + (detail != nil ? ", " : "") + "Password auth enabled"
                }
            }
            var item = buildIntegrityItem(kind: .sshConfig, path: systemSSH, name: "SSHD Config", target: nil)
            item.risk = max(item.risk, risk)
            item.detail = detail
            found.append(item)
        }

        return found
    }

    // MARK: - Build Item

    private func buildIntegrityItem(kind: IntegrityItem.Kind, path: String, name: String, target: String?) -> IntegrityItem {
        var teamId: String? = nil
        var signed = false
        var risk: IntegrityItem.Risk = .low
        let exec = target ?? ""
        if !exec.isEmpty && fm.fileExists(atPath: exec) {
            let info = codeSignInfo(for: exec)
            teamId = info.teamId
            signed = info.signed
        }

        // Risk scoring rules
        let lower = exec.lowercased()
        if lower.hasPrefix("/private/tmp") || lower.hasPrefix("/tmp") { risk = .high }
        if !signed && !exec.isEmpty && fm.fileExists(atPath: exec) { risk = max(risk, .high) }
        if exec.isEmpty && (kind == .launchAgent || kind == .launchDaemon) { risk = max(risk, .medium) }
        if !name.lowercased().contains("apple") && (kind == .launchDaemon) { risk = max(risk, .medium) }

        // World-writable location check
        if !exec.isEmpty, let attrs = try? fm.attributesOfItem(atPath: exec),
           let perms = attrs[.posixPermissions] as? Int, perms & 0o002 != 0 {
            risk = max(risk, .high)
        }

        // Baseline comparison
        if let base = baseline[path], base.targetExecutable != exec {
            risk = .critical
        }

        let firstSeen = baseline[path]?.firstSeen ?? Date()
        let lastChanged = Date()

        var item = IntegrityItem(
            kind: kind,
            name: name,
            path: path,
            targetExecutable: exec.isEmpty ? nil : exec,
            teamIdentifier: teamId,
            codeSigned: signed,
            firstSeen: firstSeen,
            lastChanged: lastChanged,
            risk: risk,
            isWhitelisted: whitelist.contains(path)
        )
        if item.isWhitelisted { item.risk = .low }
        return item
    }

    // MARK: Code Sign Info

    private func codeSignInfo(for path: String) -> (signed: Bool, teamId: String?) {
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { return (false, nil) }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        p.arguments = ["-dv", "--verbose=4", url.path]
        let out = Pipe(); let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        let sem = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in sem.signal() }
        do { try p.run() } catch { return (false, nil) }
        _ = sem.wait(timeout: .now() + 5.0)
        if p.isRunning { p.terminate() }
        let data = err.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return (false, nil) }
        let signed = text.contains("Executable=\"") || text.contains("TeamIdentifier=")
        let teamId = matchValue(in: text, prefix: "TeamIdentifier=")
        return (signed, teamId)
    }

    private func matchValue(in text: String, prefix: String) -> String? {
        for line in text.components(separatedBy: "\n") where line.contains(prefix) {
            if let range = line.range(of: prefix) {
                return String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    // MARK: Reconcile

    private func reconcile(with snapshot: [IntegrityItem]) {
        let wl = whitelist
        let oldHighRiskCount = highRiskCount
        
        items = snapshot.map { item in
            var i = item
            i.isWhitelisted = wl.contains(i.path)
            if i.isWhitelisted { i.risk = .low }
            return i
        }
        
        let newHighRiskCount = highRiskCount
        if newHighRiskCount > oldHighRiskCount {
            NotificationManager.shared.notifyIntegrityAlert(description: "New high-risk system modification detected.")
            NotificationManager.shared.playSound("Basso")
        }
    }

    // MARK: FSEvents

    private func startEvents() {
        let paths = watchedDirs as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { (_, info, numEvents, eventPaths, eventFlags, _) in
            guard let info = info else { return }
            let engine = Unmanaged<IntegrityMonitorEngine>.fromOpaque(info).takeUnretainedValue()
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            if numEvents > 0 && !paths.isEmpty {
                engine.rescan()
            }
        }
        eventStream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        )
        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
            FSEventStreamStart(stream)
        }
    }

    private func stopEvents() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }
}

private extension IntegrityItem.Risk {
    var priority: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}

private extension IntegrityItem {
    var riskPriority: Int { risk.priority }
}

