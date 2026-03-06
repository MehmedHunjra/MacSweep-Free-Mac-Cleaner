import SwiftUI

struct MaintenanceView: View {
    @State private var tasks: [MaintenanceTask] = [
        MaintenanceTask(name: "Flush DNS Cache", description: "Clear the DNS resolver cache to fix connection issues", icon: "network", color: Color(hex: "667EEA")),
        MaintenanceTask(name: "Rebuild Spotlight Index", description: "Reindex Spotlight for faster and more accurate search", icon: "magnifyingglass", color: Color(hex: "F5A623")),
        MaintenanceTask(name: "Repair Disk Permissions", description: "Fix incorrect file permissions that may cause issues", icon: "lock.shield.fill", color: Color(hex: "7ED321")),
        MaintenanceTask(name: "Free Purgeable Space", description: "Ask macOS to release purgeable disk space", icon: "internaldrive.fill", color: Color(hex: "BD10E0")),
        MaintenanceTask(name: "Clear Font Caches", description: "Remove corrupted font caches that slow down apps", icon: "textformat", color: Color(hex: "D0021B")),
        MaintenanceTask(name: "Rebuild Launch Services", description: "Fix duplicate 'Open With' menu entries", icon: "arrow.up.forward.app.fill", color: Color(hex: "4A90D9")),
        MaintenanceTask(name: "Clear System Caches", description: "Remove outdated system cache files", icon: "gearshape.fill", color: Color(hex: "9B9B9B")),
        MaintenanceTask(name: "Run Maintenance Scripts", description: "Execute macOS daily, weekly, and monthly scripts", icon: "terminal.fill", color: Color(hex: "38EF7D")),
    ]

    @State private var isRunning = false
    @State private var progress  = 0.0
    @State private var currentTask = ""
    @State private var completed = false
    @State private var results: [String] = []

    var selectedTasks: [MaintenanceTask] { tasks.filter(\.isSelected) }

    var body: some View {
        VStack(spacing: 0) {
            if !isRunning && !completed {
                landingScreen
            } else if isRunning {
                // Progress view
                VStack(spacing: 24) {
                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.1), lineWidth: 8)
                            .frame(width: 160, height: 160)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LinearGradient(colors: AppSection.maintenance.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(duration: 0.5), value: progress)
                            .shadow(color: Color.purple.opacity(0.5), radius: 10)

                        VStack(spacing: 4) {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.sectionGradient(.maintenance))
                        }
                    }

                    Text(currentTask)
                        .font(.headline)
                    Text("Please wait while maintenance tasks run...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if completed {
                // Results
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(AppTheme.success)
                            .padding(.top, 32)

                        Text("Maintenance Complete")
                            .font(.system(size: 22, weight: .bold, design: .rounded))

                        ForEach(results, id: \.self) { result in
                            let isFailure = result.hasPrefix("✗")
                            HStack(spacing: 10) {
                                Image(systemName: isFailure ? "xmark.octagon.fill" : "checkmark.circle.fill")
                                    .foregroundColor(isFailure ? .orange : .green)
                                    .font(.system(size: 14))
                                Text(result)
                                    .font(.system(size: 13))
                                    .foregroundColor(isFailure ? .orange : .primary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.windowBackgroundColor))
                            )
                        }

                        HStack(spacing: 12) {
                            Button {
                                completed = false
                                results = []
                                runMaintenance()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Run Again")
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Done") {
                                completed = false
                                results = []
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Landing
    private var landingScreen: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A0740"), Color(hex: "200952"), Color(hex: "2A0D60"), Color(hex: "1A0740")],
                startPoint: .top, endPoint: .bottom
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // 3D Glass Icon for Maintenance
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(LinearGradient(colors: [Color(hex: "3A1C71").opacity(0.6), Color(hex: "D76D77").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 120, height: 120)
                            .shadow(color: Color(hex: "3A1C71").opacity(0.4), radius: 30, y: 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )

                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 50, weight: .semibold))
                            .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "FFEDBC")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .padding(.bottom, 28)

                    Text("Maintenance")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.bottom, 8)

                    Text("Optimize your Mac's performance and fix\ncommon system issues automatically.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.bottom, 40)

                    // Task List (Glassy overlay)
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(selectedTasks.count) Tasks Selected")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Button(tasks.allSatisfy(\.isSelected) ? "Deselect All" : "Select All") {
                                let target = !tasks.allSatisfy(\.isSelected)
                                for i in tasks.indices { tasks[i].isSelected = target }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "D76D77"))
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)

                        VStack(spacing: 1) {
                            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                                MaintenanceTaskRowPro(task: $tasks[index])
                            }
                        }
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 48)

                    ToolPrimaryActionButton(
                        title: "Run Tasks",
                        colors: [Color(hex: "3A1C71"), Color(hex: "D76D77")],
                        icon: "play.fill"
                    ) {
                        runMaintenance()
                    }
                    .disabled(selectedTasks.isEmpty)
                    .opacity(selectedTasks.isEmpty ? 0.5 : 1.0)

                    Spacer().frame(height: 60)
                }
            }
        }
    }
}

struct MaintenanceTaskRowPro: View {
    @Binding var task: MaintenanceTask
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            Toggle("", isOn: $task.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(task.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: task.icon)
                    .font(.system(size: 14))
                    .foregroundColor(task.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(task.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

extension MaintenanceView {
    private func runMaintenance() {
        isRunning = true
        progress = 0
        results = []
        completed = false

        let selectedNames = selectedTasks.map(\.name)
        let total = Double(max(selectedNames.count, 1))

        Task {
            // Run all privileged commands in one authorization prompt.
            let adminTaskNames = selectedNames.filter {
                MaintenanceRunner.skipReason(for: $0) == nil
                    && MaintenanceRunner.maintenanceCommand(for: $0)?.requiresAdmin == true
            }
            let adminBatch: (results: [String: Bool], canceled: Bool)
            if adminTaskNames.isEmpty {
                adminBatch = ([:], false)
            } else {
                currentTask = "Authorizing maintenance tasks..."
                adminBatch = await Task.detached(priority: .userInitiated) {
                    MaintenanceRunner.runPrivilegedCommandBatch(taskNames: adminTaskNames)
                }.value
            }

            for (idx, taskName) in selectedNames.enumerated() {
                currentTask = taskName

                let taskResult = await Task.detached(priority: .userInitiated) {
                    MaintenanceRunner.runMaintenanceTask(
                        named: taskName,
                        adminResults: adminBatch.results,
                        adminCanceled: adminBatch.canceled
                    )
                }.value

                if taskResult.success {
                    if taskResult.message == "done" {
                        results.append("✓ \(taskName)")
                    } else {
                        results.append("✓ \(taskName) (\(taskResult.message))")
                    }
                } else {
                    results.append("✗ \(taskName) (\(taskResult.message))")
                }
                progress = Double(idx + 1) / total
            }

            isRunning = false
            completed = true
        }
    }
}

private enum MaintenanceRunner {
    struct TaskResult {
        let success: Bool
        let message: String
    }

    static func runMaintenanceTask(
        named name: String,
        adminResults: [String: Bool],
        adminCanceled: Bool
    ) -> TaskResult {
        if let skip = skipReason(for: name) {
            return TaskResult(success: true, message: skip)
        }

        guard let config = maintenanceCommand(for: name) else {
            return TaskResult(success: true, message: "not available on this macOS")
        }

        if config.requiresAdmin {
            if adminCanceled {
                return TaskResult(success: false, message: "canceled by user")
            }
            let ok = adminResults[name] ?? false
            return TaskResult(success: ok, message: ok ? "done" : "failed")
        }

        let ok = runShellCommand(config.command)
        return TaskResult(success: ok, message: ok ? "done" : "failed")
    }

    static func skipReason(for name: String) -> String? {
        switch name {
        case "Repair Disk Permissions":
            return "not required on modern macOS"
        case "Rebuild Spotlight Index":
            guard FileManager.default.isExecutableFile(atPath: "/usr/bin/mdutil") else {
                return "not available on this macOS"
            }
            if let enabled = spotlightIndexingEnabled(), !enabled {
                return "indexing is disabled"
            }
            return nil
        case "Free Purgeable Space":
            if purgeExecutablePath() != nil {
                return nil
            }
            let hasTMUtil = FileManager.default.isExecutableFile(atPath: "/usr/bin/tmutil")
            guard hasTMUtil else { return "not available on this macOS" }
            return hasLocalSnapshots() ? nil : "no local snapshots to thin"
        case "Clear System Caches", "Run Maintenance Scripts":
            return periodicExecutablePath() == nil ? "not available on this macOS" : nil
        default:
            return nil
        }
    }

    private static func spotlightIndexingEnabled() -> Bool? {
        let result = runShellCommandWithOutput("/usr/bin/mdutil -s /")
        guard !result.output.isEmpty else { return nil }
        let lower = result.output.lowercased()
        if lower.contains("indexing disabled") { return false }
        if lower.contains("indexing enabled") { return true }
        return nil
    }

    private static func hasLocalSnapshots() -> Bool {
        let result = runShellCommandWithOutput("/usr/bin/tmutil listlocalsnapshots /")
        guard result.status == 0 else { return false }
        return result.output.lowercased().contains("com.apple.timemachine.")
    }

    static func periodicExecutablePath() -> String? {
        let candidates = ["/usr/sbin/periodic", "/usr/bin/periodic"]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    static func purgeExecutablePath() -> String? {
        let candidates = ["/usr/sbin/purge", "/usr/bin/purge"]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    static func maintenanceCommand(for name: String) -> (command: String, requiresAdmin: Bool)? {
        switch name {
        case "Flush DNS Cache":
            return ("/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder", true)
        case "Rebuild Spotlight Index":
            return ("/usr/bin/mdutil -E /", true)
        case "Repair Disk Permissions":
            return ("/usr/sbin/diskutil resetUserPermissions / $(id -u)", true)
        case "Free Purgeable Space":
            if let purge = purgeExecutablePath() {
                return ("\(purge)", true)
            }
            if FileManager.default.isExecutableFile(atPath: "/usr/bin/tmutil") {
                return ("/usr/bin/tmutil thinlocalsnapshots / 10000000000 4", true)
            }
            return nil
        case "Clear Font Caches":
            return ("/usr/bin/atsutil databases -remove; /usr/bin/atsutil server -shutdown; /usr/bin/atsutil server -ping", false)
        case "Rebuild Launch Services":
            let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
            guard FileManager.default.isExecutableFile(atPath: lsregister) else { return nil }
            return ("\(lsregister) -seed -r -domain local -domain system -domain user >/dev/null 2>&1; code=$?; [ $code -eq 0 ] || [ $code -eq 2 ]", false)
        case "Clear System Caches":
            guard let periodic = periodicExecutablePath() else { return nil }
            return ("\(periodic) daily", true)
        case "Run Maintenance Scripts":
            guard let periodic = periodicExecutablePath() else { return nil }
            return ("\(periodic) daily weekly monthly", true)
        default:
            return nil
        }
    }

    static func runPrivilegedCommandBatch(taskNames: [String]) -> (results: [String: Bool], canceled: Bool) {
        let privilegedTasks = taskNames.compactMap { name -> (name: String, command: String)? in
            guard let config = maintenanceCommand(for: name), config.requiresAdmin else { return nil }
            return (name, config.command)
        }

        guard !privilegedTasks.isEmpty else {
            return ([:], false)
        }

        let script = privilegedTasks.enumerated().map { idx, task in
            "if \(task.command) >/dev/null 2>&1; then echo __MACSWEEP_OK__\(idx); else echo __MACSWEEP_FAIL__\(idx); fi"
        }.joined(separator: "; ")

        let process = Process()
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        let escaped = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        process.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]

        do {
            try process.run()
            process.waitUntilExit()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            var results = Dictionary(uniqueKeysWithValues: privilegedTasks.map { ($0.name, false) })

            for lineSub in output.split(whereSeparator: \.isNewline) {
                let line = String(lineSub)
                if line.hasPrefix("__MACSWEEP_OK__") {
                    let indexText = line.replacingOccurrences(of: "__MACSWEEP_OK__", with: "")
                    if let idx = Int(indexText), idx >= 0, idx < privilegedTasks.count {
                        results[privilegedTasks[idx].name] = true
                    }
                } else if line.hasPrefix("__MACSWEEP_FAIL__") {
                    let indexText = line.replacingOccurrences(of: "__MACSWEEP_FAIL__", with: "")
                    if let idx = Int(indexText), idx >= 0, idx < privilegedTasks.count {
                        results[privilegedTasks[idx].name] = false
                    }
                }
            }

            if process.terminationStatus != 0 {
                let lowered = output.lowercased()
                if lowered.contains("user canceled") || lowered.contains("user cancelled") || lowered.contains("cancel") {
                    return (results, true)
                }
            }
            return (results, false)
        } catch {
            return (Dictionary(uniqueKeysWithValues: privilegedTasks.map { ($0.name, false) }), true)
        }
    }

    static func runShellCommand(_ command: String) -> Bool {
        let process = Process()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func runShellCommandWithOutput(_ command: String) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (1, "")
        }
    }
}

struct MaintenanceTaskRow: View {
    @Binding var task: MaintenanceTask
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            Toggle("", isOn: $task.isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(task.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: task.icon)
                    .font(.system(size: 16))
                    .foregroundColor(task.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.system(size: 14, weight: .semibold))
                Text(task.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
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
