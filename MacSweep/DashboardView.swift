import SwiftUI

struct DashboardView: View {
    @ObservedObject var scanEngine: ScanEngine
    @Binding var selected: AppSection
    @State private var animateCards = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // Hero section
                heroSection

                // Quick status cards
                if let disk = scanEngine.diskInfo {
                    DiskUsageCard(disk: disk)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(duration: 0.5).delay(0.1), value: animateCards)
                }

                // Storage Timeline
                StorageTimelineCard(scanEngine: scanEngine)
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 20)
                    .animation(.spring(duration: 0.5).delay(0.12), value: animateCards)

                // Feature cards grid
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tools")
                        .font(.title3.bold())
                        .padding(.leading, 4)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        FeatureCard(
                            title: "Smart Scan",
                            subtitle: "One-click scan for all junk",
                            icon: "sparkles.rectangle.stack",
                            gradient: AppSection.smartScan.gradient,
                            section: .smartScan,
                            selected: $selected
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(duration: 0.5).delay(0.15), value: animateCards)

                        FeatureCard(
                            title: "System Junk",
                            subtitle: "Deep clean system caches",
                            icon: "xmark.bin.fill",
                            gradient: AppSection.systemJunk.gradient,
                            section: .systemJunk,
                            selected: $selected
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(duration: 0.5).delay(0.2), value: animateCards)

                        FeatureCard(
                            title: "Large Files",
                            subtitle: "Find space-hogging files",
                            icon: "arrow.up.doc.fill",
                            gradient: AppSection.largeFiles.gradient,
                            section: .largeFiles,
                            selected: $selected
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(duration: 0.5).delay(0.25), value: animateCards)

                        FeatureCard(
                            title: "Duplicates",
                            subtitle: "Find & remove duplicate files",
                            icon: "doc.on.doc.fill",
                            gradient: AppSection.duplicates.gradient,
                            section: .duplicates,
                            selected: $selected
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(duration: 0.5).delay(0.28), value: animateCards)

                        FeatureCard(
                            title: "Privacy & Protection",
                            subtitle: "Browser traces & privacy data",
                            icon: "lock.shield",
                            gradient: AppSection.protection.gradient,
                            section: .protection,
                            selected: $selected
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(duration: 0.5).delay(0.3), value: animateCards)

                        FeatureCard(
                            title: "Optimize & Maintain",
                            subtitle: "Performance & maintenance",
                            icon: "bolt.shield",
                            gradient: AppSection.performance.gradient,
                            section: .performance,
                            selected: $selected
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(duration: 0.5).delay(0.35), value: animateCards)

                        FeatureCard(
                            title: "Applications",
                            subtitle: "Manage apps & leftovers",
                            icon: "square.stack.3d.up.fill",
                            gradient: AppSection.applications.gradient,
                            section: .applications,
                            selected: $selected
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(duration: 0.5).delay(0.4), value: animateCards)

                        FeatureCard(
                            title: "Space Lens",
                            subtitle: "Visualize disk usage",
                            icon: "chart.pie.fill",
                            gradient: AppSection.spaceLens.gradient,
                            section: .spaceLens,
                            selected: $selected
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(duration: 0.5).delay(0.45), value: animateCards)

                        FeatureCard(
                            title: "Dev Cleaner",
                            subtitle: "Clean IDE & build files",
                            icon: "chevron.left.forwardslash.chevron.right",
                            gradient: AppSection.devCleaner.gradient,
                            section: .devCleaner,
                            selected: $selected
                        )
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 20)
                        .animation(.spring(duration: 0.5).delay(0.5), value: animateCards)
                    }
                }
            }
            .padding(32)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateCards = true
            }
        }
    }

    var heroSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to MacSweep")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Keep your Mac clean, fast, and clutter-free.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                withAnimation { selected = .smartScan }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Quick Scan")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.brandGradient)
                )
            }
            .buttonStyle(.plain)
        }
        .opacity(animateCards ? 1 : 0)
        .animation(.spring(duration: 0.5), value: animateCards)
    }
}

// MARK: - Disk Usage Card
struct DiskUsageCard: View {
    let disk: DiskInfo
    @State private var isHovered = false

    var usageColor: Color {
        if disk.usedPercentage > 0.9 { return AppTheme.danger }
        if disk.usedPercentage > 0.75 { return AppTheme.warning }
        return AppTheme.accent
    }

    var body: some View {
        HStack(spacing: 24) {
            // Circular gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.1), lineWidth: 10)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: disk.usedPercentage)
                    .stroke(
                        LinearGradient(
                            colors: [usageColor, usageColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(disk.usedPercentage * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "internaldrive.fill")
                        .foregroundColor(usageColor)
                    Text("Macintosh HD")
                        .font(.headline.bold())
                }

                HStack(spacing: 20) {
                    DiskStat(label: "Total", value: disk.totalFormatted, color: .primary)
                    DiskStat(label: "Used", value: disk.usedFormatted, color: usageColor)
                    DiskStat(label: "Available", value: disk.freeFormatted, color: .green)
                }
            }

            Spacer()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(isHovered ? 0.1 : 0.06), radius: isHovered ? 12 : 8, y: isHovered ? 5 : 3)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

struct DiskStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(color)
        }
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let section: AppSection
    @Binding var selected: AppSection
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selected = section }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(isHovered ? 0.1 : 0.04), radius: isHovered ? 12 : 6, y: isHovered ? 4 : 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Storage Timeline Card
struct StorageTimelineCard: View {
    @ObservedObject var scanEngine: ScanEngine
    @State private var history: [StorageDataPoint] = []
    
    private let historyKey = "MacSweep_StorageHistory"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Storage Timeline")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Disk usage over the last 30 days")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let freed = totalFreed {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(freed)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.success)
                        Text("freed this month")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if history.count >= 2 {
                GeometryReader { geo in
                    let maxFree = history.map(\.freeSpace).max() ?? 1
                    let minFree = history.map(\.freeSpace).min() ?? 0
                    let range = max(maxFree - minFree, 1)
                    
                    ZStack {
                        ForEach(0..<4, id: \.self) { i in
                            let y = geo.size.height * CGFloat(i) / 3
                            Path { p in
                                p.move(to: CGPoint(x: 0, y: y))
                                p.addLine(to: CGPoint(x: geo.size.width, y: y))
                            }
                            .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                        }
                        
                        Path { path in
                            for (i, point) in history.enumerated() {
                                let x = geo.size.width * CGFloat(i) / CGFloat(max(history.count - 1, 1))
                                let y = geo.size.height * (1.0 - CGFloat(point.freeSpace - minFree) / CGFloat(range))
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.success.opacity(0.15), AppTheme.success.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        
                        Path { path in
                            for (i, point) in history.enumerated() {
                                let x = geo.size.width * CGFloat(i) / CGFloat(max(history.count - 1, 1))
                                let y = geo.size.height * (1.0 - CGFloat(point.freeSpace - minFree) / CGFloat(range))
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(
                            LinearGradient(colors: [AppTheme.success, Color(hex: "38EF7D")], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        
                        if let last = history.last {
                            let x = geo.size.width
                            let y = geo.size.height * (1.0 - CGFloat(last.freeSpace - minFree) / CGFloat(range))
                            Circle()
                                .fill(AppTheme.success)
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(height: 80)
                
                HStack {
                    if let first = history.first {
                        Text(dateLabel(first.date))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Today")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("Tracking will start building over time")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 80)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
        .onAppear { loadAndRecord() }
    }
    
    var totalFreed: String? {
        guard history.count >= 2 else { return nil }
        let first = history.first!.freeSpace
        let last = history.last!.freeSpace
        let diff = last - first
        guard diff > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: diff, countStyle: .file)
    }
    
    func dateLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
    
    func loadAndRecord() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([StorageDataPoint].self, from: data) {
            history = decoded
        }
        
        guard let disk = scanEngine.diskInfo else { return }
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastDate = history.last?.date,
           Calendar.current.isDate(lastDate, inSameDayAs: today) {
            history[history.count - 1] = StorageDataPoint(date: today, freeSpace: disk.freeSpace)
        } else {
            history.append(StorageDataPoint(date: today, freeSpace: disk.freeSpace))
        }
        
        if history.count > 30 { history = Array(history.suffix(30)) }
        
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
}

struct StorageDataPoint: Codable {
    let date: Date
    let freeSpace: Int64
}
