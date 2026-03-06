import Foundation
import AppKit
import SwiftUI
#if canImport(Metal)
import Metal
#endif

enum ScanMode {
    case smart
    case categories(Set<ScanCategory>)
    case custom(path: String, categories: Set<ScanCategory>)
}

@MainActor
class ScanEngine: ObservableObject {

    // MARK: - Published State
    @Published var isScanning    = false
    @Published var scanProgress  = 0.0
    @Published var currentPath   = ""
    @Published var scanItems     : [ScanItem] = []
    @Published var scanComplete  = false
    @Published var diskInfo      : DiskInfo?

    // Space Lens
    @Published var storageCategories: [StorageCategory] = []
    @Published var isAnalyzingSpace = false

    // System info — menu bar + dashboard
    @Published var cpuUsage: Double = 0
    @Published var cpuUsagePercent: Int = 0
    @Published var memoryUsage: Double = 0
    @Published var memoryUsagePercent: Int = 0
    @Published var memoryUsed: Int64 = 0
    @Published var memoryUsedCompact: String = "0.0G"
    @Published var memoryTotal: Int64 = 0
    @Published var lastMetricsUpdate: Date = .distantPast
    @Published var vramTotalMB: Int64 = 0
    @Published var vramUsedMB: Int64 = 0
    @Published var gpuName: String = "GPU"

    // Running apps
    @Published var runningApps: [RunningAppInfo] = []
    @Published var runningAppCount: Int = 0

    // Network monitoring
    @Published var networkUpBytes: Int64 = 0
    @Published var networkDownBytes: Int64 = 0
    private var lastNetUp: Int64 = 0
    private var lastNetDown: Int64 = 0

    // Freed space history (persisted)
    @Published var freedHistory: [FreedSpaceRecord] = []
    @Published var totalFreedBytes: Int64 = 0

    private let fm       = FileManager.default
    private var homeDir  : String { fm.homeDirectoryForCurrentUser.path }
    private var refreshTimer: Timer?
    private var systemStatsTimer: Timer?
    private var prevCpuInfo: [processor_cpu_load_info] = []
    private var lastCpuUpdate: Date = .distantPast
    private var lastNetUpdate: Date = .distantPast
    private let legacySeedDescription = "Initial system cleanup (Photoshop scratch disk + system junk)"
    private let liveCPUPercentKey = "live_cpu_percent"
    private let liveMemoryUsedCompactKey = "live_memory_used_compact"
    private let liveMemoryUsagePercentKey = "live_memory_usage_percent"
    private let liveMetricsSeqKey = "live_metrics_seq"
    private var largeFileThresholdBytes: Int64 {
        let thresholdMB = UserDefaults.standard.object(forKey: "largeFileThresholdMB") as? Double ?? 100
        return max(Int64(thresholdMB * 1_000_000), 1)
    }

    private func smartScanEnabledCategories() -> Set<ScanCategory> {
        let ud = UserDefaults.standard
        var enabled: Set<ScanCategory> = []
        if ud.object(forKey: "scanIncludeUserCaches") as? Bool ?? true { enabled.insert(.userCaches) }
        if ud.object(forKey: "scanIncludeLogs") as? Bool ?? true { enabled.insert(.logs) }
        if ud.object(forKey: "scanIncludeBrowserCaches") as? Bool ?? true { enabled.insert(.browserCaches) }
        if ud.object(forKey: "scanIncludeDevelopment") as? Bool ?? true { enabled.insert(.development) }
        if ud.object(forKey: "scanIncludeTempFiles") as? Bool ?? true { enabled.insert(.tempFiles) }
        if ud.object(forKey: "scanIncludeMailAttachments") as? Bool ?? true { enabled.insert(.mailAttach) }
        if ud.object(forKey: "scanIncludeAppLeftovers") as? Bool ?? true { enabled.insert(.appLeftovers) }
        if ud.object(forKey: "scanIncludeLargeFiles") as? Bool ?? true { enabled.insert(.largeFiles) }
        return enabled
    }

    private func categories(for mode: ScanMode) -> Set<ScanCategory> {
        switch mode {
        case .smart:
            return smartScanEnabledCategories()
        case .categories(let set):
            return set
        case .custom(_, let set):
            return set
        }
    }

    // MARK: - Init
    init() {
        loadFreedHistory()
        let savedRefreshInterval = UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 2.0
        startRefreshTimer(interval: savedRefreshInterval)
        startSystemStatsTimer()
        refreshDiskInfo()
        refreshRunningApps()
        updateSystemInfo()
    }

    // MARK: - Computed
    var itemsByCategory: [ScanCategory: [ScanItem]] {
        Dictionary(grouping: scanItems, by: \.category)
    }

    var selectedItems: [ScanItem] { scanItems.filter(\.isSelected) }
    var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.size } }
    var totalFoundSize: Int64 { scanItems.reduce(0) { $0 + $1.size } }

    // MARK: - Timer
    func startRefreshTimer(interval: Double = 2.0) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDiskInfo()
                self?.refreshRunningApps()
            }
        }
    }

    private func startSystemStatsTimer(interval: Double = 1.0) {
        systemStatsTimer?.invalidate()
        systemStatsTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateSystemInfo()
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
        systemStatsTimer?.invalidate()
    }

    // MARK: - Disk Info
    func refreshDiskInfo() {
        guard let attrs = try? fm.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64 else { return }

        // Match macOS Storage semantics by preferring "available" capacity.
        let rootURL = URL(fileURLWithPath: "/")
        let values = try? rootURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])
        let importantAny = values?.allValues[.volumeAvailableCapacityForImportantUsageKey]
        let standardAny = values?.allValues[.volumeAvailableCapacityKey]

        func toInt64(_ value: Any?) -> Int64? {
            if let v = value as? Int64 { return v }
            if let v = value as? Int { return Int64(v) }
            if let v = value as? NSNumber { return v.int64Value }
            return nil
        }

        let available = toInt64(importantAny)
            ?? toInt64(standardAny)
            ?? (attrs[.systemFreeSize] as? Int64)
            ?? 0

        diskInfo = DiskInfo(totalSpace: total, freeSpace: available)
    }

    func updateSystemInfo() {
        let now = Date()
        // Prevent rapid re-calculation which causes 100% CPU spikes and jittery network stats
        guard now.timeIntervalSince(lastCpuUpdate) > 0.8 || lastCpuUpdate == .distantPast else { return }

        let totalMem = Int64(ProcessInfo.processInfo.physicalMemory)
        memoryTotal = totalMem

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let pageSize = Int64(vm_kernel_page_size)
            let active   = Int64(stats.active_count) * pageSize
            let wired    = Int64(stats.wire_count) * pageSize
            let compressed = Int64(stats.compressor_page_count) * pageSize
            memoryUsed = active + wired + compressed
            memoryUsage = Double(memoryUsed) / Double(totalMem)
        }

        // Real-time CPU Usage (Guarded to avoid spikes from rapid triggers)
        let cpuInterval = now.timeIntervalSince(lastCpuUpdate)
        
        if cpuInterval > 0.5 { // Only update if at least 0.5s passed
            var cpuCount: mach_msg_type_number_t = 0
            var infoArray: processor_info_array_t?
            var infoCount: mach_msg_type_number_t = 0
            
            let resultC = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &infoArray, &infoCount)
            if resultC == KERN_SUCCESS, let info = infoArray {
                let infoPointer = info.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(cpuCount)) { $0 }
                var currentInfo: [processor_cpu_load_info] = []
                for i in 0..<Int(cpuCount) {
                    currentInfo.append(infoPointer[i])
                }
                
                if prevCpuInfo.count == Int(cpuCount) {
                    var totalDiff: UInt64 = 0
                    var idleDiff: UInt64 = 0
                    for i in 0..<Int(cpuCount) {
                        let prev = prevCpuInfo[i]
                        let curr = currentInfo[i]
                        
                        // Use UInt64 for intermediate diffs to avoid overflow
                        let u = UInt64(curr.cpu_ticks.0) > UInt64(prev.cpu_ticks.0) ? UInt64(curr.cpu_ticks.0) - UInt64(prev.cpu_ticks.0) : 0
                        let s = UInt64(curr.cpu_ticks.1) > UInt64(prev.cpu_ticks.1) ? UInt64(curr.cpu_ticks.1) - UInt64(prev.cpu_ticks.1) : 0
                        // processor_cpu_load_info order is: user, system, idle, nice
                        let id = UInt64(curr.cpu_ticks.2) > UInt64(prev.cpu_ticks.2) ? UInt64(curr.cpu_ticks.2) - UInt64(prev.cpu_ticks.2) : 0
                        let n = UInt64(curr.cpu_ticks.3) > UInt64(prev.cpu_ticks.3) ? UInt64(curr.cpu_ticks.3) - UInt64(prev.cpu_ticks.3) : 0
                        
                        idleDiff += id
                        totalDiff += u + s + n + id
                    }
                    if totalDiff > 0 {
                        let rawUsage = 1.0 - Double(idleDiff) / Double(totalDiff)
                        let clamped = min(max(rawUsage, 0.0), 1.0)
                        cpuUsage = cpuUsage == 0 ? clamped : (cpuUsage * 0.7 + clamped * 0.3)
                    }
                }
                prevCpuInfo = currentInfo
                lastCpuUpdate = now
                let infoSize = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), infoSize)
            }
        }
        lastMetricsUpdate = now

        // Shared display snapshot to keep all app surfaces in sync.
        cpuUsagePercent = Int((cpuUsage * 100).rounded())
        memoryUsagePercent = Int((memoryUsage * 100).rounded())
        memoryUsedCompact = String(format: "%.1fG", Double(memoryUsed) / 1_073_741_824.0)
        publishLiveDisplaySnapshot()

        // Real-time GPU/VRAM info
        Task { [weak self] in
            let stats = await Task.detached(priority: .background) {
                ScanEngine.queryGPUStats()
            }.value
            guard let self = self else { return }
            self.gpuName = stats.name
            self.vramTotalMB = stats.totalMB
            self.vramUsedMB = stats.usedMB
        }

        // Network speed monitoring (calculated per second)
        Task { [weak self] in
            let (up, down) = await Task.detached(priority: .background) {
                ScanEngine.getNetworkBytes()
            }.value
            guard let self = self else { return }
            let now = Date()
            let timeDiff = now.timeIntervalSince(self.lastNetUpdate)

            if self.lastNetUpdate != .distantPast && timeDiff > 0.1 {
                let dUp = Double(max(0, up - self.lastNetUp))
                let dDown = Double(max(0, down - self.lastNetDown))
                self.networkUpBytes = Int64(dUp / timeDiff)
                self.networkDownBytes = Int64(dDown / timeDiff)
            }
            self.lastNetUp = up
            self.lastNetDown = down
            self.lastNetUpdate = now
        }
    }

    // MARK: - Network Bytes
    nonisolated static func getNetworkBytes() -> (up: Int64, down: Int64) {
        let task = Process()
        task.launchPath = "/usr/sbin/netstat"
        task.arguments = ["-ib", "-n"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return (0, 0) }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return (0, 0) }

        var totalIn: Int64 = 0
        var totalOut: Int64 = 0
        
        let lines = output.split(whereSeparator: \.isNewline)
        guard let headerLine = lines.first else { return (0, 0) }

        let headers = headerLine.split(whereSeparator: { $0 == " " || $0 == "\t" })
        let iBytesIndex = headers.firstIndex(of: "Ibytes") ?? 6
        let oBytesIndex = headers.firstIndex(of: "Obytes") ?? 9

        let preferred = preferredNetworkInterfaces()
        func collect(using filter: (String) -> Bool) -> [String: (inBytes: Int64, outBytes: Int64)] {
            var ifaceMax: [String: (inBytes: Int64, outBytes: Int64)] = [:]
            for line in lines.dropFirst() {
                let cols = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                guard cols.count > max(iBytesIndex, oBytesIndex) else { continue }
                let iface = String(cols[0])
                guard !iface.hasPrefix("lo") else { continue }
                guard filter(iface) else { continue }
                guard let ib = Int64(cols[iBytesIndex]), let ob = Int64(cols[oBytesIndex]) else { continue }
                let current = ifaceMax[iface] ?? (0, 0)
                ifaceMax[iface] = (max(current.inBytes, ib), max(current.outBytes, ob))
            }
            return ifaceMax
        }

        var ifaceMax: [String: (inBytes: Int64, outBytes: Int64)] = [:]
        if preferred.isEmpty {
            ifaceMax = collect { iface in
                iface.hasPrefix("en")
                    || iface.hasPrefix("bridge")
                    || iface.hasPrefix("pdp_ip")
                    || iface.hasPrefix("utun")
            }
        } else {
            ifaceMax = collect { preferred.contains($0) }
            let preferredTotals = ifaceMax.values.reduce((inBytes: Int64(0), outBytes: Int64(0))) { acc, item in
                (acc.inBytes + item.inBytes, acc.outBytes + item.outBytes)
            }
            // Fallback when the preferred interface is missing or effectively inactive.
            if ifaceMax.isEmpty || (preferredTotals.inBytes == 0 && preferredTotals.outBytes == 0) {
                ifaceMax = collect { iface in
                    iface.hasPrefix("en")
                        || iface.hasPrefix("bridge")
                        || iface.hasPrefix("pdp_ip")
                        || iface.hasPrefix("utun")
                }
            }
        }

        for (_, pair) in ifaceMax {
            totalIn += pair.inBytes
            totalOut += pair.outBytes
        }
        return (totalOut, totalIn)
    }

    private func publishLiveDisplaySnapshot() {
        let defaults = UserDefaults.standard
        defaults.set(cpuUsagePercent, forKey: liveCPUPercentKey)
        defaults.set(memoryUsedCompact, forKey: liveMemoryUsedCompactKey)
        defaults.set(memoryUsagePercent, forKey: liveMemoryUsagePercentKey)
        let nextSeq = defaults.integer(forKey: liveMetricsSeqKey) + 1
        defaults.set(nextSeq, forKey: liveMetricsSeqKey)
    }

    nonisolated private static func preferredNetworkInterfaces() -> Set<String> {
        if let route = defaultRouteInterface() {
            return [route]
        }
        if let wifi = wifiInterfaceName() {
            return [wifi]
        }
        return []
    }

    nonisolated private static func defaultRouteInterface() -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/route"
        task.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("interface:") {
                let parts = line.split(separator: ":")
                if parts.count >= 2 {
                    let iface = parts[1].trimmingCharacters(in: .whitespaces)
                    return iface.isEmpty ? nil : iface
                }
            }
        }
        return nil
    }

    nonisolated private static func wifiInterfaceName() -> String? {
        guard let output = runCommand(
            executable: "/usr/sbin/networksetup",
            arguments: ["-listallhardwareports"]
        ) else { return nil }

        let lines = output.components(separatedBy: .newlines)
        var inWiFiBlock = false
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Hardware Port:") {
                let lower = line.lowercased()
                inWiFiBlock = lower.contains("wi-fi") || lower.contains("airport")
                continue
            }
            if inWiFiBlock, line.hasPrefix("Device:") {
                let iface = line.replacingOccurrences(of: "Device:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return iface.isEmpty ? nil : iface
            }
        }
        return nil
    }

    // MARK: - Running Apps
    func refreshRunningApps() {
        let ws = NSWorkspace.shared
        let apps = ws.runningApplications
            .filter { $0.activationPolicy == .regular }

        runningAppCount = apps.count

        // Get CPU/memory via ps
        Task { [weak self] in
            let stats = await Task.detached(priority: .background) {
                ScanEngine.fetchProcessStats()
            }.value
            guard let self = self else { return }
            var infos: [RunningAppInfo] = []
            for app in apps {
                guard let name = app.localizedName else { continue }
                let pid = app.processIdentifier
                let stat = stats[pid] ?? (cpu: 0, mem: 0)
                infos.append(RunningAppInfo(
                    id: pid,
                    name: name,
                    bundleId: app.bundleIdentifier ?? "",
                    icon: app.icon,
                    cpuPercent: stat.cpu,
                    memoryMB: stat.mem,
                    isActive: app.isActive
                ))
            }
            // Sort by CPU then memory
            infos.sort { a, b in
                if a.cpuPercent != b.cpuPercent { return a.cpuPercent > b.cpuPercent }
                return a.memoryMB > b.memoryMB
            }
            self.runningApps = infos
        }
    }

    func quitApp(_ info: RunningAppInfo, force: Bool = false) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == info.id }) else { return }
        if force {
            app.forceTerminate()
        } else {
            app.terminate()
        }
        // Remove from list immediately for responsiveness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.runningApps.removeAll { $0.id == info.id }
        }
    }

    // MARK: - Freed Space History
    func recordFreed(bytes: Int64, description: String) {
        let record = FreedSpaceRecord(bytes: bytes, description: description)
        freedHistory.insert(record, at: 0)
        totalFreedBytes += bytes
        saveFreedHistory()
    }

    private func loadFreedHistory() {
        if let data = UserDefaults.standard.data(forKey: "freedHistory"),
           let records = try? JSONDecoder().decode([FreedSpaceRecord].self, from: data) {
            // Remove legacy seeded demo record from older builds.
            let cleaned = records.filter { rec in
                !(rec.description == legacySeedDescription && rec.bytes == 68_719_476_736)
            }
            freedHistory = cleaned
            totalFreedBytes = cleaned.reduce(0) { $0 + $1.bytes }
            if cleaned.count != records.count {
                saveFreedHistory()
            }
        } else {
            freedHistory = []
            totalFreedBytes = 0
        }
    }

    private func saveFreedHistory() {
        if let data = try? JSONEncoder().encode(freedHistory) {
            UserDefaults.standard.set(data, forKey: "freedHistory")
        }
    }

    func clearFreedHistory() {
        freedHistory = []
        totalFreedBytes = 0
        UserDefaults.standard.removeObject(forKey: "freedHistory")
    }

    // MARK: - Start Scan
    func startScan(mode: ScanMode = .smart) async {
        isScanning   = true
        scanComplete = false
        scanItems    = []
        scanProgress = 0
        refreshDiskInfo()

        let enabledCategories = categories(for: mode)
        var customPath: String? = nil
        if case .custom(let path, _) = mode {
            customPath = path
        }
        
        let home = homeDir

        let scanMap: [(ScanCategory, [String])] = [
            (.userCaches, [
                "\(home)/Library/Caches",
                "\(home)/Library/Application Support/Caches"
            ]),
            (.logs, [
                "\(home)/Library/Logs",
                "/private/var/log"
            ]),
            (.browserCaches, [
                "\(home)/Library/Application Support/Google/Chrome/Default/Cache",
                "\(home)/Library/Application Support/Google/Chrome/Default/Code Cache",
                "\(home)/Library/Application Support/Google/Chrome/Default/Service Worker",
                "\(home)/Library/Application Support/Google/Chrome/Default/GPUCache",
                "\(home)/Library/Caches/com.apple.Safari",
                "\(home)/Library/Safari/LocalStorage",
                "\(home)/Library/Application Support/Firefox/Profiles"
            ]),
            (.development, [
                "\(home)/Library/Developer/Xcode/DerivedData",
                "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
                "\(home)/Library/Developer/CoreSimulator/Devices",
                "\(home)/.gradle/caches",
                "\(home)/.npm/_cacache",
                "\(home)/.m2/repository",
                "\(home)/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel"
            ]),
            (.tempFiles, [
                "/private/tmp",
                "\(home)/.Trash"
            ]),
            (.mailAttach, [
                "\(home)/Library/Mail Downloads",
                "\(home)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"
            ])
        ]

        var totalSteps = Double(scanMap.filter { enabledCategories.contains($0.0) }.count)
        if enabledCategories.contains(.appLeftovers) {
            totalSteps += 1
        }
        if enabledCategories.contains(.largeFiles) {
            totalSteps += 1
        }

        if totalSteps <= 0 {
            isScanning = false
            scanComplete = true
            currentPath = ""
            return
        }

        var step = 0.0

        for (category, paths) in scanMap {
            guard enabledCategories.contains(category) else { continue }
            for path in paths {
                await addScanItem(path: path, category: category)
            }
            step += 1
            scanProgress = step / totalSteps
        }

        if enabledCategories.contains(.appLeftovers) {
            currentPath = "Scanning for app leftovers..."
            await scanAppLeftovers(home: home)
            step += 1
            scanProgress = step / totalSteps
        }

        if enabledCategories.contains(.largeFiles) {
            currentPath = "Scanning for large files..."
            await scanLargeFiles(home: home, customPath: customPath)
        }
        scanProgress = 1.0

        isScanning   = false
        scanComplete = true
        currentPath  = ""
        refreshDiskInfo()
    }

    // MARK: - Space Lens
    func analyzeSpace() async {
        isAnalyzingSpace = true
        storageCategories = []
        refreshDiskInfo()
        let home = homeDir

        let folders: [(String, String, Color, String)] = [
            ("Documents", "\(home)/Documents", Color(hex: "667EEA"), "doc.fill"),
            ("Downloads", "\(home)/Downloads", Color(hex: "F5A623"), "arrow.down.circle.fill"),
            ("Desktop",   "\(home)/Desktop",   Color(hex: "7ED321"), "desktopcomputer"),
            ("Movies",    "\(home)/Movies",     Color(hex: "BD10E0"), "film.fill"),
            ("Music",     "\(home)/Music",      Color(hex: "D0021B"), "music.note"),
            ("Pictures",  "\(home)/Pictures",   Color(hex: "4A90D9"), "photo.fill"),
            ("Applications", "/Applications",   Color(hex: "F8E71C"), "app.fill"),
            ("Library",   "\(home)/Library",    Color(hex: "9B9B9B"), "folder.fill"),
            ("Developer", "\(home)/Developer",  Color(hex: "38EF7D"), "chevron.left.forwardslash.chevron.right"),
        ]

        for (name, path, color, icon) in folders {
            guard fm.fileExists(atPath: path) else { continue }
            let size = await Task.detached(priority: .background) {
                ScanEngine.calcSize(path: path)
            }.value
            if size > 0 {
                storageCategories.append(StorageCategory(
                    name: name, path: path, size: size, color: color, icon: icon
                ))
            }
        }

        let analyzedBytes = storageCategories.reduce(Int64(0)) { $0 + $1.size }
        if let usedBytes = diskInfo?.usedSpace {
            let remainder = max(usedBytes - analyzedBytes, 0)
            if remainder > 512_000_000 {
                storageCategories.append(StorageCategory(
                    name: "System & Other",
                    path: "/",
                    size: remainder,
                    color: Color(hex: "6E6E73"),
                    icon: "internaldrive.fill"
                ))
            }
        }

        storageCategories.sort { $0.size > $1.size }
        isAnalyzingSpace = false
    }

    // MARK: - Helpers

    private func addScanItem(path: String, category: ScanCategory) async {
        currentPath = path
        guard fm.fileExists(atPath: path) else { return }
        let size = await Task.detached(priority: .background) {
            ScanEngine.calcSize(path: path)
        }.value
        guard size > 0 else { return }
        let item = ScanItem(
            name: (path as NSString).lastPathComponent,
            path: path,
            size: size,
            category: category,
            isSelected: category.isSafeByDefault
        )
        scanItems.append(item)
    }

    private func scanAppLeftovers(home: String) async {
        let installedApps = getInstalledAppNames()
        let supportDir    = "\(home)/Library/Application Support"
        guard let entries = try? fm.contentsOfDirectory(atPath: supportDir) else { return }

        for entry in entries {
            guard !entry.hasPrefix("com.apple."),
                  !entry.hasPrefix("Apple"),
                  !entry.hasPrefix("MobileSync") else { continue }

            let path       = "\(supportDir)/\(entry)"
            let normalized = entry.lowercased()
                .replacingOccurrences(of: "com.", with: "")
                .replacingOccurrences(of: "net.", with: "")
                .replacingOccurrences(of: ".app", with: "")

            let hasApp = installedApps.contains { app in
                let a = app.lowercased().replacingOccurrences(of: " ", with: "")
                return a.contains(normalized) || normalized.contains(a)
            }
            guard !hasApp else { continue }

            let size = await Task.detached(priority: .background) {
                ScanEngine.calcSize(path: path)
            }.value
            guard size > 1_000_000 else { continue }

            scanItems.append(ScanItem(
                name: entry,
                path: path,
                size: size,
                category: .appLeftovers,
                isSelected: false
            ))
        }
    }

    private func scanLargeFiles(home: String, customPath: String? = nil) async {
        let roots: [String]
        if let cp = customPath {
            roots = [cp]
        } else {
            roots = [
                "\(home)/Documents",
                "\(home)/Downloads",
                "\(home)/Desktop",
                "\(home)/Movies",
                "\(home)/Music"
            ]
        }

        let threshold = largeFileThresholdBytes
        let found: [(String, String, Int64)] = await Task.detached(priority: .background) {
            ScanEngine.findLargeFiles(in: roots, minBytes: threshold)
        }.value

        for (name, path, size) in found {
            scanItems.append(ScanItem(
                name: name,
                path: path,
                size: size,
                category: .largeFiles,
                isSelected: false
            ))
        }
    }

    func getInstalledAppNames() -> [String] {
        let home = homeDir
        let dirs = ["/Applications", "\(home)/Applications"]
        return dirs.flatMap { dir in
            (try? fm.contentsOfDirectory(atPath: dir))?
                .filter { $0.hasSuffix(".app") }
                .map    { $0.replacingOccurrences(of: ".app", with: "") }
            ?? []
        }
    }

    // MARK: - Static Helpers (nonisolated for Task.detached)

    nonisolated static func calcSize(path: String) -> Int64 {
        let fm = FileManager.default
        var size: Int64 = 0
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (try? fm.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
        }
        for item in enumerator {
            if let url = item as? URL,
               let s = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                size += Int64(s)
            }
        }
        return size
    }

    nonisolated static func findLargeFiles(in roots: [String], minBytes: Int64) -> [(String, String, Int64)] {
        var results: [(String, String, Int64)] = []
        let fm = FileManager.default

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in enumerator {
                guard let url = item as? URL,
                      let res = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                      res.isDirectory == false,
                      let size = res.fileSize,
                      Int64(size) > minBytes else { continue }
                results.append((url.lastPathComponent, url.path, Int64(size)))
            }
        }

        return results
    }

    nonisolated static func fetchProcessStats() -> [pid_t: (cpu: Double, mem: Double)] {
        var result: [pid_t: (cpu: Double, mem: Double)] = [:]
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments  = ["-eo", "pid,pcpu,rss"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data   = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            for line in output.components(separatedBy: "\n").dropFirst() {
                let parts = line.split(separator: " ")
                guard parts.count >= 3,
                      let pid  = pid_t(parts[0]),
                      let cpu  = Double(parts[1]),
                      let rss  = Double(parts[2]) else { continue }
                result[pid] = (cpu: cpu, mem: rss / 1024.0) // KB -> MB
            }
        } catch {}
        return result
    }

    nonisolated static func queryGPUStats() -> (name: String, totalMB: Int64, usedMB: Int64) {
        struct GPUCache {
            static let lock = NSLock()
            static var identity: (name: String, totalMB: Int64, unified: Bool)?
        }

        let identity: (name: String, totalMB: Int64, unified: Bool) = {
            GPUCache.lock.lock()
            defer { GPUCache.lock.unlock() }
            if let cached = GPUCache.identity {
                return cached
            }

            var name = "GPU"
            var totalMB: Int64 = 0
            var unified = false

            #if canImport(Metal)
            if let device = MTLCreateSystemDefaultDevice() {
                name = device.name
                unified = device.hasUnifiedMemory
                let recommended = Int64(device.recommendedMaxWorkingSetSize)
                if recommended > 0 {
                    totalMB = recommended / (1024 * 1024)
                }
            }
            #endif

            if let sp = queryGPUFromSystemProfiler() {
                if !sp.name.isEmpty { name = sp.name }
                if sp.totalMB > 0 { totalMB = sp.totalMB }
                unified = unified || sp.unified
            }

            if totalMB == 0, unified {
                let physicalMB = Int64(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
                totalMB = max(physicalMB / 2, 2048)
            }

            if unified && !name.localizedCaseInsensitiveContains("unified") {
                name += " (Unified)"
            }

            let resolved = (name, totalMB, unified)
            GPUCache.identity = resolved
            return resolved
        }()

        let ioUsage = queryGPUUsageFromIORegistry()
        var usedMB = ioUsage.usedMB
        var totalMB = identity.totalMB
        var name = identity.name

        if totalMB == 0, ioUsage.totalMB > 0 {
            totalMB = ioUsage.totalMB
        }
        if !ioUsage.name.isEmpty {
            name = ioUsage.name
            if identity.unified && !name.localizedCaseInsensitiveContains("unified") {
                name += " (Unified)"
            }
        }

        if usedMB <= 0 && totalMB > 0 && identity.unified {
            usedMB = Int64(Double(totalMB) * currentSystemMemoryUsageFraction())
        }

        if totalMB > 0 {
            usedMB = max(0, min(usedMB, totalMB))
        } else {
            usedMB = max(0, usedMB)
        }

        return (name, totalMB, usedMB)
    }

    nonisolated private static func queryGPUUsageFromIORegistry() -> (name: String, totalMB: Int64, usedMB: Int64) {
        guard let output = runCommand(
            executable: "/usr/sbin/ioreg",
            arguments: ["-c", "IOAccelerator", "-r", "-l"]
        ) else {
            return ("", 0, 0)
        }

        var gpuName = ""
        var totalMB: Int64 = 0
        var freeMB: Int64 = -1

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if line.contains("\"vram-total-size\""), let bytes = extractTrailingInteger(from: line) {
                totalMB = bytes / (1024 * 1024)
            } else if line.contains("\"vram-free-size\""), let bytes = extractTrailingInteger(from: line) {
                freeMB = bytes / (1024 * 1024)
            } else if line.contains("\"model\""), let model = extractQuotedValue(from: line), !model.isEmpty {
                gpuName = model
            }
        }

        var usedMB: Int64 = 0
        if totalMB > 0 && freeMB >= 0 {
            usedMB = max(0, totalMB - freeMB)
        }
        return (gpuName, totalMB, usedMB)
    }

    nonisolated private static func queryGPUFromSystemProfiler() -> (name: String, totalMB: Int64, unified: Bool)? {
        guard let output = runCommand(
            executable: "/usr/sbin/system_profiler",
            arguments: ["SPDisplaysDataType", "-json"]
        ), let data = output.data(using: .utf8),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let displays = root["SPDisplaysDataType"] as? [[String: Any]],
           let first = displays.first else {
            return nil
        }

        let model = (first["sppci_model"] as? String) ?? (first["_name"] as? String) ?? ""
        let vramString = (first["spdisplays_vram"] as? String)
            ?? (first["spdisplays_vram_shared"] as? String)
            ?? (first["spdisplays_vram_dynamic"] as? String)
        let totalMB = parseSizeStringToMB(vramString) ?? 0
        let unified = model.localizedCaseInsensitiveContains("Apple")
        return (model, totalMB, unified)
    }

    nonisolated private static func currentSystemMemoryUsageFraction() -> Double {
        let totalMem = Int64(ProcessInfo.processInfo.physicalMemory)
        guard totalMem > 0 else { return 0.0 }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0.0 }

        let pageSize = Int64(vm_kernel_page_size)
        let used = Int64(stats.active_count + stats.wire_count + stats.compressor_page_count) * pageSize
        let fraction = Double(used) / Double(totalMem)
        return min(max(fraction, 0.0), 1.0)
    }

    nonisolated private static func runCommand(executable: String, arguments: [String]) -> String? {
        let task = Process()
        task.launchPath = executable
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }
        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    nonisolated private static func extractTrailingInteger(from line: String) -> Int64? {
        let digits = line.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        return Int64(digits)
    }

    nonisolated private static func extractQuotedValue(from line: String) -> String? {
        guard let firstQuote = line.firstIndex(of: "\""),
              let secondQuote = line[line.index(after: firstQuote)...].firstIndex(of: "\""),
              let thirdQuote = line[secondQuote...].dropFirst().firstIndex(of: "\""),
              let fourthQuote = line[thirdQuote...].dropFirst().firstIndex(of: "\"") else {
            return nil
        }
        return String(line[line.index(after: thirdQuote)..<fourthQuote])
    }

    nonisolated private static func parseSizeStringToMB(_ text: String?) -> Int64? {
        guard let text else { return nil }
        let cleaned = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let numberPart = cleaned.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
        guard let value = Double(numberPart) else { return nil }
        if cleaned.contains("tb") { return Int64(value * 1024.0 * 1024.0) }
        if cleaned.contains("gb") { return Int64(value * 1024.0) }
        if cleaned.contains("mb") { return Int64(value) }
        if cleaned.contains("kb") { return Int64(value / 1024.0) }
        return nil
    }

    // MARK: - Selection helpers
    func toggleItem(_ id: UUID) {
        guard let i = scanItems.firstIndex(where: { $0.id == id }) else { return }
        scanItems[i].isSelected.toggle()
    }

    func selectAll(in category: ScanCategory) {
        for i in scanItems.indices where scanItems[i].category == category {
            scanItems[i].isSelected = true
        }
    }

    func deselectAll(in category: ScanCategory) {
        for i in scanItems.indices where scanItems[i].category == category {
            scanItems[i].isSelected = false
        }
    }
}
