import SwiftUI
import AppKit

// MARK: - Memory Optimizer View
struct MemoryOptimizerView: View {
    @ObservedObject var engine: MemoryEngine
    @State private var showKillConfirm = false
    @State private var processToKill: AppProcessInfo?
    
    var body: some View {
        VStack(spacing: 0) {
            // Memory Overview
            memoryOverview
            
            Divider()
            
            // Process List
            processListView
            
            Divider()
            
            // Footer
            memoryFooter
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear { engine.startMonitoring() }
        .onDisappear { engine.stopMonitoring() }
        .alert("Quit Process?", isPresented: $showKillConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Force Quit", role: .destructive) {
                if let p = processToKill {
                    engine.killProcess(pid: p.pid)
                }
            }
        } message: {
            Text("Force quitting \"\(processToKill?.name ?? "")\" may cause data loss. Are you sure?")
        }
    }
    
    // MARK: - Memory Overview
    var memoryOverview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Circular gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: engine.memoryPressure)
                        .stroke(
                            LinearGradient(colors: pressureGradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.5), value: engine.memoryPressure)
                    VStack(spacing: 0) {
                        Text("\(Int(engine.memoryPressure * 100))%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("used")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Stats
                VStack(alignment: .leading, spacing: 6) {
                    memStat(label: "Used", value: engine.usedMemory, color: Color(hex: "FF6B6B"))
                    memStat(label: "Wired", value: engine.wiredMemory, color: Color(hex: "FFA502"))
                    memStat(label: "Compressed", value: engine.compressedMemory, color: Color(hex: "7C4DFF"))
                    memStat(label: "Free", value: engine.freeMemoryStr, color: AppTheme.success)
                }
                
                Spacer()
                
                // Total RAM
                VStack(alignment: .trailing, spacing: 4) {
                    Text(engine.totalMemoryFormatted)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Total RAM")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    var pressureGradient: [Color] {
        if engine.memoryPressure > 0.85 { return [Color(hex: "FF416C"), Color(hex: "FF4B2B")] }
        if engine.memoryPressure > 0.65 { return [Color(hex: "F7971E"), Color(hex: "FFD200")] }
        return [AppTheme.success, Color(hex: "38EF7D")]
    }
    
    func memStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
    }
    
    // MARK: - Process List
    var processListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Top Processes by Memory")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("\(engine.processes.count) processes")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Column headers
            HStack(spacing: 0) {
                Text("Process")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("PID")
                    .frame(width: 55, alignment: .trailing)
                Text("Memory")
                    .frame(width: 75, alignment: .trailing)
                Text("")
                    .frame(width: 60)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(engine.processes) { proc in
                        ProcessRow(process: proc) {
                            processToKill = proc
                            showKillConfirm = true
                        }
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }
    
    // MARK: - Footer
    var memoryFooter: some View {
        HStack(spacing: 12) {
            Button {
                engine.refreshProcesses()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Auto-refreshes every 5s")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Button {
                engine.freeUpMemory()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "memorychip")
                    Text("Free Memory")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                             startPoint: .leading, endPoint: .trailing))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Process Row
struct ProcessRow: View {
    let process: AppProcessInfo
    let onKill: () -> Void
    @State private var hovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                Text(process.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("\(process.pid)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 55, alignment: .trailing)
            
            Text(process.memoryFormatted)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(process.memoryMB > 500 ? Color(hex: "FF6B6B") : .primary)
                .frame(width: 75, alignment: .trailing)
            
            Group {
                if hovered {
                    Button(action: onKill) {
                        Text("Quit")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.cornerRadius(4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(hovered ? Color.gray.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.1), value: hovered)
    }
}

// MARK: - Memory Engine
@MainActor
class MemoryEngine: ObservableObject {
    @Published var processes: [AppProcessInfo] = []
    @Published var memoryPressure: CGFloat = 0
    @Published var usedMemory: String = "0 GB"
    @Published var wiredMemory: String = "0 GB"
    @Published var compressedMemory: String = "0 GB"
    @Published var freeMemoryStr: String = "0 GB"
    @Published var totalMemoryFormatted: String = "0 GB"
    
    private var timer: Timer?
    
    func startMonitoring() {
        updateMemoryStats()
        refreshProcesses()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryStats()
                self?.refreshProcesses()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func updateMemoryStats() {
        let totalRAM = Foundation.ProcessInfo.processInfo.physicalMemory
        totalMemoryFormatted = ByteCountFormatter.string(fromByteCount: Int64(totalRAM), countStyle: .memory)
        
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let pageSize = vm_kernel_page_size
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        let free = UInt64(stats.free_count) * UInt64(pageSize)
        let active = UInt64(stats.active_count) * UInt64(pageSize)
        let inactive = UInt64(stats.inactive_count) * UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        let used = active + inactive + wired
        
        freeMemoryStr = ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .memory)
        usedMemory = ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory)
        wiredMemory = ByteCountFormatter.string(fromByteCount: Int64(wired), countStyle: .memory)
        compressedMemory = ByteCountFormatter.string(fromByteCount: Int64(compressed), countStyle: .memory)
        
        memoryPressure = CGFloat(used) / CGFloat(totalRAM)
    }
    
    func refreshProcesses() {
        Task {
            let procs = await Task.detached(priority: .userInitiated) {
                Self.getTopProcesses()
            }.value
            processes = procs
        }
    }
    
    nonisolated static func getTopProcesses() -> [AppProcessInfo] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid,rss,comm", "-r"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return [] }
        
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var results: [AppProcessInfo] = []
        
        for line in output.components(separatedBy: "\n").dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 2)
            guard parts.count >= 3,
                  let pid = Int32(parts[0]),
                  let rssKB = Int64(parts[1]) else { continue }
            
            let name = String(parts[2]).components(separatedBy: "/").last ?? String(parts[2])
            let memoryMB = Double(rssKB) / 1024.0
            guard memoryMB > 10 else { continue } // Only show processes > 10 MB
            
            let icon = NSRunningApplication.runningApplications(withBundleIdentifier: "").isEmpty ? nil :
                NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid })?.icon
            
            results.append(AppProcessInfo(
                pid: pid,
                name: name,
                memoryMB: memoryMB,
                icon: icon
            ))
        }
        
        return Array(results.prefix(30))
    }
    
    func killProcess(pid: Int32) {
        kill(pid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshProcesses()
        }
    }
    
    func freeUpMemory() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.updateMemoryStats()
        }
    }
}

// MARK: - Process Info Model
struct AppProcessInfo: Identifiable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let memoryMB: Double
    let icon: NSImage?
    
    var memoryFormatted: String {
        if memoryMB >= 1024 {
            return String(format: "%.1f GB", memoryMB / 1024)
        }
        return String(format: "%.0f MB", memoryMB)
    }
}
