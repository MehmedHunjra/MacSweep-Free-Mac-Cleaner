import SwiftUI
import AppKit

// MARK: =========  SPACE LENS VIEW (PRO)  =========
struct SpaceLensView: View {
    @ObservedObject var scanEngine: ScanEngine
    @ObservedObject var engine: SpaceLensEngine
    @State private var showReviewSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if engine.currentPath.isEmpty && !engine.isScanning {
                landingScreen
            } else {
                topBar
                Divider().opacity(0.3)
                mainContent
                Divider().opacity(0.3)
                footerBar
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Landing
    @State private var scanTarget = NSHomeDirectory() // default scan target

    private var landingScreen: some View {
        ZStack {
            // Background gradient matching CleanMyMac purple theme
            LinearGradient(
                colors: [
                    Color(hex: "1A0740"),
                    Color(hex: "200952"),
                    Color(hex: "2A0D60"),
                    Color(hex: "1A0740")
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 30)

                // Big Space Lens icon
                ZStack {
                    // Background glow
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "6A1B9A").opacity(0.6),
                                    Color(hex: "4A148C").opacity(0.4),
                                    Color(hex: "311B92").opacity(0.5)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "7C4DFF").opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(
                                    RadialGradient(
                                        colors: [Color.white.opacity(0.2), Color.clear],
                                        center: .init(x: 0.3, y: 0.25),
                                        startRadius: 0, endRadius: 80
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    // Magnifying glass icon
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white.opacity(0.9), Color(hex: "B388FF")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.bottom, 28)

                // Title
                Text("Space Lens")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                // Subtitle
                Text("Visualize what's taking up the most disk space\nand clean up your storage quickly.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 28)

                // Folder selector dropdown
                Menu {
                    Button {
                        scanTarget = "/"
                    } label: {
                        Label("Macintosh HD (Entire Disk)", systemImage: "internaldrive.fill")
                    }
                    Button {
                        scanTarget = NSHomeDirectory()
                    } label: {
                        Label("Home Folder", systemImage: "house.fill")
                    }
                    Divider()
                    Button {
                        selectCustomFolder()
                    } label: {
                        Label("Choose Folder…", systemImage: "folder.badge.plus")
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: scanTarget == "/" ? "internaldrive.fill" : "folder.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "B388FF"))
                        Text(scanTargetName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .frame(width: 260)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .menuStyle(.borderlessButton)
                .padding(.bottom, 36)

                ToolPrimaryActionButton(
                    title: "Scan",
                    colors: [Color(hex: "7C4DFF"), Color(hex: "651FFF")],
                    icon: "sparkles"
                ) {
                    engine.navigateTo(path: scanTarget)
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
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a folder to analyze"
        if panel.runModal() == .OK, let url = panel.url {
            scanTarget = url.path
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    engine.startOver()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Start Over")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()
                Text("Space Lens")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Color.clear.frame(width: 100, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Breadcrumb
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    navButton(icon: "chevron.left", enabled: engine.canGoBack) { engine.goBack() }
                    navButton(icon: "chevron.right", enabled: engine.canGoForward) { engine.goForward() }
                }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(Array(engine.breadcrumbs.enumerated()), id: \.element.id) { idx, crumb in
                                if idx > 0 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.secondary.opacity(0.35))
                                }
                                Button { engine.navigateTo(path: crumb.path) } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: crumb.icon)
                                            .font(.system(size: 10))
                                            .foregroundColor(crumb.isActive ? Color(hex: "F8E71C") : .secondary)
                                        Text(crumb.name)
                                            .font(.system(size: 12, weight: crumb.isActive ? .bold : .medium))
                                            .foregroundColor(crumb.isActive ? .primary : .secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(crumb.isActive ? Color(hex: "4776E6").opacity(0.12) : Color.clear)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .id(crumb.id)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: engine.currentPath) { _, _ in
                        if let last = engine.breadcrumbs.last {
                            withAnimation { proxy.scrollTo(last.id) }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        }
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(enabled ? .primary : .gray.opacity(0.25))
                .frame(width: 26, height: 26)
                .background(Color.gray.opacity(enabled ? 0.1 : 0.04))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Main Content
    private var mainContent: some View {
        Group {
            if engine.isScanning {
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView().scaleEffect(1.5)
                    Text("Scanning \(engine.currentDirName)…")
                        .font(.system(size: 15, weight: .semibold))
                    Text(engine.scanStatus)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    fileListPanel.frame(width: 320)
                    Divider().opacity(0.3)
                    bubbleCanvas
                }
            }
        }
    }

    // MARK: - File List
    private var fileListPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color(hex: "4776E6").opacity(0.15), Color(hex: "8E54E9").opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: engine.currentPath == "/" ? "internaldrive.fill" : "folder.fill")
                        .font(.system(size: 18))
                        .foregroundColor(engine.currentPath == "/" ? Color(hex: "4776E6") : Color(hex: "F8E71C"))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(engine.currentDirName)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(ByteCountFormatter.string(fromByteCount: engine.currentDirSize, countStyle: .file))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text("|")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("\(engine.totalItemCount) items")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Select bar
            HStack(spacing: 6) {
                Text("Select:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Menu {
                    Button("All") { engine.selectAll() }
                    Button("None") { engine.deselectAll() }
                    Button("Files Only") { engine.selectFilesOnly() }
                    Button("Folders Only") { engine.selectFoldersOnly() }
                    Divider()
                    Button("Large Items (> 100 MB)") { engine.selectLargeItems() }
                } label: {
                    HStack(spacing: 3) {
                        Text(engine.selectionLabel)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "4776E6"))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            Divider().opacity(0.3)

            // File rows
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(engine.entries) { entry in
                        SLFileRow(
                            entry: entry,
                            parentSize: engine.currentDirSize,
                            isHighlighted: engine.hoveredEntryId == entry.id,
                            onToggle: { engine.toggleEntry(entry.id) },
                            onNavigate: {
                                if entry.isDirectory {
                                    engine.navigateTo(path: entry.path)
                                }
                            },
                            onHover: { hovering in
                                engine.hoveredEntryId = hovering ? entry.id : nil
                            }
                        )
                    }
                }
            }

            if engine.otherItemsSize > 0 {
                Divider().opacity(0.3)
                HStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Other items")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: engine.otherItemsSize, countStyle: .file))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.03))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Bubble Canvas
    private var bubbleCanvas: some View {
        ZStack {
            // Dark purple gradient
            LinearGradient(
                colors: [
                    Color(hex: "0D0221"),
                    Color(hex: "150535"),
                    Color(hex: "1A0740"),
                    Color(hex: "230A52")
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Center glow
            RadialGradient(
                colors: [Color(hex: "4776E6").opacity(0.06), Color.clear],
                center: .center, startRadius: 20, endRadius: 400
            )

            // Bubbles from cached layout
            ForEach(engine.cachedBubbles) { bubble in
                SLBubbleView(
                    bubble: bubble,
                    isHighlighted: engine.hoveredEntryId == bubble.entry.id,
                    onTap: {
                        if bubble.entry.isDirectory {
                            engine.navigateTo(path: bubble.entry.path)
                        } else {
                            engine.toggleEntry(bubble.entry.id)
                        }
                    },
                    onHover: { hovering in
                        engine.hoveredEntryId = hovering ? bubble.entry.id : nil
                    }
                )
                .position(x: bubble.x, y: bubble.y)
            }
        }
        .onAppear { engine.computeLayoutIfNeeded() }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            if abs(newSize.width - engine.lastCanvasSize.width) > 20 ||
               abs(newSize.height - engine.lastCanvasSize.height) > 20 {
                engine.lastCanvasSize = newSize
                engine.recomputeLayout()
            }
        }
    }

    // MARK: - Footer
    private var footerBar: some View {
        HStack(spacing: 10) {
            if let disk = scanEngine.diskInfo {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Macintosh HD")
                        .font(.system(size: 11, weight: .medium))

                    let fraction = disk.totalSpace > 0
                        ? CGFloat(disk.usedSpace) / CGFloat(disk.totalSpace) : 0
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.12))
                            .frame(width: 100, height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [Color(hex: "4776E6"), Color(hex: "8E54E9")],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: 100 * fraction, height: 5)
                    }
                    .frame(width: 100, height: 5)

                    Text("\(ByteCountFormatter.string(fromByteCount: disk.usedSpace, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: disk.totalSpace, countStyle: .file)) used")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if engine.selectedCount > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "4776E6"))
                    Text("\(engine.selectedCount) items selected")
                        .font(.system(size: 11))
                    Text("•")
                        .foregroundColor(.gray.opacity(0.4))
                    Text(ByteCountFormatter.string(fromByteCount: engine.selectedSize, countStyle: .file))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.secondary)
            }

            Button {
                showReviewSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text("Review and Remove")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(engine.selectedCount > 0
                              ? AnyShapeStyle(LinearGradient(
                                    colors: [Color(hex: "E94560"), Color(hex: "C2185B")],
                                    startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color.gray.opacity(0.3)))
                )
            }
            .buttonStyle(.plain)
            .disabled(engine.selectedCount == 0)
            .sheet(isPresented: $showReviewSheet) {
                SLReviewSheet(engine: engine, scanEngine: scanEngine) {
                    showReviewSheet = false
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: =========  FILE ROW  =========
struct SLFileRow: View {
    let entry: SpaceLensEntry
    let parentSize: Int64
    let isHighlighted: Bool
    let onToggle: () -> Void
    let onNavigate: () -> Void
    let onHover: (Bool) -> Void
    @State private var hovered = false

    private var barFraction: CGFloat {
        guard parentSize > 0 else { return 0 }
        return CGFloat(entry.size) / CGFloat(parentSize)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Info button
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: entry.path)])
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(hovered ? 0.7 : 0.3))
            }
            .buttonStyle(.plain)
            .frame(width: 24)

            // Checkbox
            Button(action: onToggle) {
                Image(systemName: entry.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundColor(entry.isSelected ? Color(hex: "E94560") : .secondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .frame(width: 24)

            // Icon
            Image(systemName: entry.isDirectory ? "folder.fill" : entry.fileIcon)
                .font(.system(size: 13))
                .foregroundColor(entry.isDirectory ? Color(hex: "F8E71C") : .secondary.opacity(0.7))
                .frame(width: 22)

            // Name
            Text(entry.name)
                .font(.system(size: 12, weight: entry.isSelected || isHighlighted ? .semibold : .regular))
                .foregroundColor(entry.name.hasPrefix(".") ? .secondary : .primary)
                .lineLimit(1)
                .padding(.leading, 6)

            Spacer()

            // Size
            Text(entry.sizeFormatted)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            ZStack(alignment: .leading) {
                if barFraction > 0.01 {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(entry.isSelected
                                  ? Color(hex: "E94560").opacity(0.06)
                                  : Color(hex: "4776E6").opacity(0.04))
                            .frame(width: geo.size.width * min(barFraction, 1.0))
                    }
                }
                if hovered || isHighlighted {
                    Color(hex: "4776E6").opacity(0.06)
                }
            }
        )
        .contentShape(Rectangle())
        .onHover { h in
            hovered = h
            onHover(h)
        }
        .onTapGesture {
            if entry.isDirectory {
                onNavigate()
            } else {
                onToggle()
            }
        }
    }
}

// MARK: =========  BUBBLE VIEW  =========
struct SLBubbleView: View {
    let bubble: BubbleLayout
    let isHighlighted: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    @State private var localHover = false
    @State private var tooltipEntry: SpaceLensEntry? = nil

    private var isHovered: Bool { localHover || isHighlighted }

    private var gradient: LinearGradient {
        if bubble.entry.isSelected {
            return LinearGradient(
                colors: [Color(hex: "E94560").opacity(0.8), Color(hex: "C2185B").opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(
            colors: [
                Color(hex: "4A1080").opacity(isHovered ? 0.8 : 0.55),
                Color(hex: "6A1B9A").opacity(isHovered ? 0.6 : 0.4),
                Color(hex: "8E24AA").opacity(isHovered ? 0.45 : 0.3)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            // Outer glow
            if isHovered {
                Circle()
                    .fill(Color(hex: "8E54E9").opacity(0.2))
                    .frame(width: bubble.radius * 2 + 16, height: bubble.radius * 2 + 16)
                    .blur(radius: 10)
            }

            // Main circle
            Circle()
                .fill(gradient)
                .frame(width: bubble.radius * 2, height: bubble.radius * 2)
                // Glass highlight
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.15), Color.clear],
                                center: .init(x: 0.35, y: 0.25),
                                startRadius: 0,
                                endRadius: bubble.radius * 0.9
                            )
                        )
                )
                // Border
                .overlay(
                    Circle()
                        .strokeBorder(
                            isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.1),
                            lineWidth: isHovered ? 1.5 : 0.5
                        )
                )
                .shadow(
                    color: (bubble.entry.isSelected ? Color(hex: "E94560") : Color(hex: "8E54E9"))
                        .opacity(isHovered ? 0.5 : 0.15),
                    radius: isHovered ? 20 : 6, y: 2
                )

            // Labels
            if bubble.radius > 22 {
                VStack(spacing: bubble.radius > 50 ? 3 : 1) {
                    Image(systemName: bubble.entry.isDirectory ? "folder.fill" : bubble.entry.fileIcon)
                        .font(.system(size: iconSize))
                        .foregroundColor(bubble.entry.isDirectory ? Color(hex: "F8E71C") : .white.opacity(0.8))

                    if bubble.radius > 35 {
                        Text(bubble.entry.name)
                            .font(.system(size: nameSize, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(bubble.radius > 55 ? 2 : 1)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: bubble.radius * 1.5)
                    }
                    if bubble.radius > 45 {
                        Text(bubble.entry.sizeFormatted)
                            .font(.system(size: sizeSize, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .scaleEffect(isHovered ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { h in
            localHover = h
            onHover(h)
        }
        .onTapGesture { onTap() }
        // Tooltip as overlay instead of popover to prevent flicker
        .overlay(alignment: .top) {
            if isHovered && bubble.radius > 10 {
                SLTooltipCard(entry: bubble.entry)
                    .offset(y: -(bubble.radius + 8))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(999)
            }
        }
    }

    private var iconSize: CGFloat { bubble.radius > 65 ? 22 : (bubble.radius > 45 ? 16 : 12) }
    private var nameSize: CGFloat { bubble.radius > 65 ? 12 : (bubble.radius > 45 ? 10 : 9) }
    private var sizeSize: CGFloat { bubble.radius > 65 ? 11 : 9 }
}

// MARK: =========  TOOLTIP CARD (overlay, not popover)  =========
struct SLTooltipCard: View {
    let entry: SpaceLensEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.name)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
            Text(entry.isDirectory ? "Folder" : entry.fileType)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            HStack(spacing: 10) {
                Text("Size: \(entry.sizeFormatted)")
                    .font(.system(size: 10, weight: .medium))
                if entry.itemCount > 0 {
                    Text("\(formatCount(entry.itemCount)) items")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            if let date = entry.modifiedDate {
                Text("Modified: \(date, format: .dateTime.month(.abbreviated).day().year())")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        )
        .frame(width: 200)
        .allowsHitTesting(false) // Don't steal mouse events!
    }

    func formatCount(_ c: Int) -> String {
        if c >= 1_000_000 { return String(format: "%.1fM", Double(c) / 1_000_000.0) }
        if c >= 1_000 { return String(format: "%.1fK", Double(c) / 1_000.0) }
        return "\(c)"
    }
}

// MARK: =========  REVIEW SHEET  =========
struct SLReviewSheet: View {
    @ObservedObject var engine: SpaceLensEngine
    let scanEngine: ScanEngine
    let onDismiss: () -> Void
    @State private var isRemoving = false
    @State private var removedSize: Int64 = 0
    @State private var showDone = false

    private var selected: [SpaceLensEntry] { engine.entries.filter(\.isSelected) }

    var body: some View {
        VStack(spacing: 0) {
            if showDone {
                completionView
            } else {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Review and Remove")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("\(selected.count) items • \(ByteCountFormatter.string(fromByteCount: engine.selectedSize, countStyle: .file)) will be moved to Trash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                Divider()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(selected) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.isDirectory ? "folder.fill" : item.fileIcon)
                                    .font(.system(size: 14))
                                    .foregroundColor(item.isDirectory ? Color(hex: "F8E71C") : .secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                    Text(item.path)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(item.sizeFormatted)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Button {
                                    engine.toggleEntry(item.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary.opacity(0.4))
                                        .frame(width: 20, height: 20)
                                        .background(Color.gray.opacity(0.08))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            Divider().padding(.leading, 50)
                        }
                    }
                }

                Divider()
                HStack {
                    Button("Cancel") { onDismiss() }
                        .font(.system(size: 13))
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        isRemoving = true
                        Task {
                            removedSize = await engine.removeSelected()
                            scanEngine.recordFreed(bytes: removedSize, description: "Space Lens cleanup")
                            isRemoving = false
                            showDone = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isRemoving {
                                ProgressView().scaleEffect(0.7).tint(.white)
                                Text("Moving to Trash…")
                            } else {
                                Image(systemName: "trash")
                                Text("Remove \(ByteCountFormatter.string(fromByteCount: engine.selectedSize, countStyle: .file))")
                            }
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "E94560"), Color(hex: "C2185B")],
                                    startPoint: .leading, endPoint: .trailing))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRemoving || selected.isEmpty)
                }
                .padding(20)
            }
        }
        .frame(width: 560, height: 460)
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "E94560"), Color(hex: "764BA2")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "E94560").opacity(0.4), radius: 20)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Cleanup Complete!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(ByteCountFormatter.string(fromByteCount: removedSize, countStyle: .file))
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Color(hex: "E94560"), Color(hex: "764BA2")],
                    startPoint: .leading, endPoint: .trailing))
            Text("freed from your disk")
                .foregroundColor(.secondary)
            Spacer()
            Button("Done") {
                onDismiss()
                engine.rescan()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 10)
            .background(LinearGradient(colors: [Color(hex: "4776E6"), Color(hex: "8E54E9")],
                                       startPoint: .leading, endPoint: .trailing))
            .cornerRadius(10)
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
    }
}

// MARK: ==========================================================
// MARK: - ENGINE
// MARK: ==========================================================

@MainActor
class SpaceLensEngine: ObservableObject {
    @Published var entries: [SpaceLensEntry] = []
    @Published var currentPath: String = ""
    @Published var isScanning = false
    @Published var scanStatus = ""
    @Published var otherItemsSize: Int64 = 0
    @Published var totalItemCount: Int = 0
    @Published var hoveredEntryId: UUID? = nil
    @Published var cachedBubbles: [BubbleLayout] = []
    var lastCanvasSize: CGSize = .zero

    private var backStack: [String] = []
    private var forwardStack: [String] = []
    private let fm = FileManager.default
    private let maxDisplayItems = 20

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    var currentDirName: String {
        if currentPath == "/" { return "Macintosh HD" }
        return (currentPath as NSString).lastPathComponent
    }

    var currentDirSize: Int64 { entries.reduce(0) { $0 + $1.size } + otherItemsSize }
    var selectedCount: Int { entries.filter(\.isSelected).count }
    var selectedSize: Int64 { entries.filter(\.isSelected).reduce(0) { $0 + $1.size } }

    var selectionLabel: String {
        let s = selectedCount, t = entries.count
        if s == 0 { return "None" }
        if s == t { return "All" }
        return "Manually"
    }

    var breadcrumbs: [BreadcrumbItem] {
        guard !currentPath.isEmpty else { return [] }
        var items: [BreadcrumbItem] = []
        var p = currentPath
        while !p.isEmpty && p != "/" {
            let name = (p as NSString).lastPathComponent
            items.insert(BreadcrumbItem(name: name, path: p, icon: "folder.fill",
                                         isActive: p == currentPath), at: 0)
            p = (p as NSString).deletingLastPathComponent
        }
        items.insert(BreadcrumbItem(name: "Macintosh HD", path: "/", icon: "internaldrive.fill",
                                     isActive: currentPath == "/"), at: 0)
        return items
    }

    // MARK: Navigation
    func navigateTo(path: String) {
        if !currentPath.isEmpty && currentPath != path {
            backStack.append(currentPath)
        }
        forwardStack.removeAll()
        currentPath = path
        scanDirectory()
    }

    func goBack() {
        guard let prev = backStack.popLast() else { return }
        forwardStack.append(currentPath)
        currentPath = prev
        scanDirectory()
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentPath)
        currentPath = next
        scanDirectory()
    }

    func startOver() {
        backStack.removeAll()
        forwardStack.removeAll()
        entries = []
        cachedBubbles = []
        currentPath = ""
        otherItemsSize = 0
        totalItemCount = 0
    }

    func rescan() { scanDirectory() }

    // MARK: Selection
    func toggleEntry(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].isSelected.toggle()
        updateBubbleSelections()
    }
    func selectAll() {
        for i in entries.indices { entries[i].isSelected = true }
        updateBubbleSelections()
    }
    func deselectAll() {
        for i in entries.indices { entries[i].isSelected = false }
        updateBubbleSelections()
    }
    func selectFilesOnly() {
        for i in entries.indices { entries[i].isSelected = !entries[i].isDirectory }
        updateBubbleSelections()
    }
    func selectFoldersOnly() {
        for i in entries.indices { entries[i].isSelected = entries[i].isDirectory }
        updateBubbleSelections()
    }
    func selectLargeItems() {
        for i in entries.indices { entries[i].isSelected = entries[i].size > 100_000_000 }
        updateBubbleSelections()
    }

    private func updateBubbleSelections() {
        // Update isSelected in cached bubbles without recalculating positions
        for i in cachedBubbles.indices {
            if let entryIdx = entries.firstIndex(where: { $0.id == cachedBubbles[i].entryId }) {
                cachedBubbles[i].isSelected = entries[entryIdx].isSelected
            }
        }
    }

    // MARK: Remove
    func removeSelected() async -> Int64 {
        var freed: Int64 = 0
        for item in entries.filter(\.isSelected) {
            do {
                try fm.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
                freed += item.size
            } catch {}
        }
        return freed
    }

    // MARK: Scan
    func scanDirectory() {
        isScanning = true
        scanStatus = "Reading contents…"
        entries = []
        cachedBubbles = []
        otherItemsSize = 0
        totalItemCount = 0

        let path = currentPath
        let limit = maxDisplayItems

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                SpaceLensEngine.scanDir(path: path, maxItems: limit)
            }.value

            await MainActor.run {
                entries = result.items
                otherItemsSize = result.otherSize
                totalItemCount = result.totalCount
                isScanning = false
                scanStatus = ""
                recomputeLayout()
            }
        }
    }

    // MARK: Layout (cached, stable)
    func computeLayoutIfNeeded() {
        if cachedBubbles.isEmpty && !entries.isEmpty && lastCanvasSize.width > 0 {
            recomputeLayout()
        }
    }

    func recomputeLayout() {
        guard !entries.isEmpty, lastCanvasSize.width > 50, lastCanvasSize.height > 50 else {
            cachedBubbles = []
            return
        }
        cachedBubbles = Self.packBubbles(entries: entries, in: lastCanvasSize)
    }

    nonisolated static func packBubbles(entries: [SpaceLensEntry], in size: CGSize) -> [BubbleLayout] {
        let totalSize = max(entries.reduce(Int64(0)) { $0 + $1.size }, 1)
        let usableArea = size.width * size.height * 0.50
        let cx = size.width / 2
        let cy = size.height / 2
        let sorted = entries.sorted { $0.size > $1.size }

        var placed: [(x: CGFloat, y: CGFloat, r: CGFloat)] = []
        var result: [BubbleLayout] = []

        for (idx, entry) in sorted.enumerated() {
            let fraction = Double(entry.size) / Double(totalSize)
            let area = usableArea * fraction
            var r = sqrt(area / .pi)
            r = max(12, min(r, min(size.width, size.height) * 0.38))

            var bx = cx, by = cy

            if idx > 0 {
                var found = false
                // Spiral outward from center using golden angle
                let goldenAngle: CGFloat = 2.39996
                var angle: CGFloat = CGFloat(idx) * goldenAngle
                var dist: CGFloat = (placed.first?.r ?? 0) + r + 6

                for _ in 0..<500 {
                    let tx = cx + cos(angle) * dist
                    let ty = cy + sin(angle) * dist

                    if tx - r >= 2 && tx + r <= size.width - 2 &&
                       ty - r >= 2 && ty + r <= size.height - 2 {
                        let overlaps = placed.contains { c in
                            let dx = tx - c.x, dy = ty - c.y
                            return sqrt(dx * dx + dy * dy) < (r + c.r + 5)
                        }
                        if !overlaps {
                            bx = tx; by = ty; found = true; break
                        }
                    }
                    angle += goldenAngle * 0.4
                    dist += 2.5
                }

                if !found {
                    r = max(12, r * 0.4)
                    bx = cx + CGFloat(idx * 30 % Int(size.width / 2)) - size.width / 4
                    by = cy + CGFloat(idx * 25 % Int(size.height / 2)) - size.height / 4
                    bx = max(r + 2, min(bx, size.width - r - 2))
                    by = max(r + 2, min(by, size.height - r - 2))
                }
            }

            placed.append((bx, by, r))
            result.append(BubbleLayout(
                entryId: entry.id, entry: entry,
                x: bx, y: by, radius: r,
                isSelected: entry.isSelected
            ))
        }

        return result
    }

    // MARK: Static Scanner
    nonisolated static func scanDir(path: String, maxItems: Int) -> (items: [SpaceLensEntry], otherSize: Int64, totalCount: Int) {
        let fm = FileManager.default
        let contents: [String]

        if path == "/" {
            contents = ["Users", "Applications", "System", "Library",
                        "private", "opt", "usr", "bin", "sbin", "tmp", "var"]
                .filter { fm.fileExists(atPath: "/\($0)") }
        } else {
            guard let c = try? fm.contentsOfDirectory(atPath: path) else { return ([], 0, 0) }
            contents = c
        }

        var all: [SpaceLensEntry] = []
        let totalCount = contents.count

        for name in contents {
            let full = path == "/" ? "/\(name)" : "\(path)/\(name)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir) else { continue }

            let attrs = try? fm.attributesOfItem(atPath: full)
            let modDate = attrs?[.modificationDate] as? Date
            let size: Int64
            var itemCount = 0

            if isDir.boolValue {
                size = ScanEngine.calcSize(path: full)
                itemCount = (try? fm.contentsOfDirectory(atPath: full))?.count ?? 0
            } else {
                size = (attrs?[.size] as? Int64) ?? 0
            }

            all.append(SpaceLensEntry(
                name: name, path: full, size: size,
                isDirectory: isDir.boolValue, isSelected: false,
                itemCount: itemCount, modifiedDate: modDate
            ))
        }

        all.sort { $0.size > $1.size }

        if all.count > maxItems {
            let displayed = Array(all.prefix(maxItems))
            let other = all.dropFirst(maxItems).reduce(Int64(0)) { $0 + $1.size }
            return (displayed, other, totalCount)
        }
        return (all, 0, totalCount)
    }
}

// MARK: ==========================================================
// MARK: - MODELS
// MARK: ==========================================================

struct SpaceLensEntry: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    var isSelected: Bool
    let itemCount: Int
    let modifiedDate: Date?

    var sizeFormatted: String {
        if size < 1024 { return "< 1 KB" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var fileIcon: String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff": return "photo.fill"
        case "mp4", "mov", "avi", "mkv", "m4v": return "film.fill"
        case "mp3", "aac", "wav", "flac", "m4a": return "music.note"
        case "zip", "gz", "tar", "rar", "7z", "xz": return "doc.zipper"
        case "dmg", "iso": return "opticaldisc.fill"
        case "app": return "app.fill"
        case "plist", "json", "xml", "yaml", "yml": return "doc.text.fill"
        case "swift", "py", "js", "ts", "c", "cpp", "h", "m", "rs", "go": return "chevron.left.forwardslash.chevron.right"
        default: return "doc.fill"
        }
    }

    var fileType: String {
        if isDirectory { return "Folder" }
        let ext = (name as NSString).pathExtension
        if ext.isEmpty { return "File" }
        return "\(ext.uppercased()) file"
    }
}

struct BreadcrumbItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String
    let isActive: Bool
}

struct BubbleLayout: Identifiable {
    let id = UUID()
    let entryId: UUID
    let entry: SpaceLensEntry
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    var isSelected: Bool
}
