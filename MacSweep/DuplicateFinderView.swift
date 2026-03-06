import SwiftUI
import AppKit
import CryptoKit

// MARK: - Duplicate Finder View
struct DuplicateFinderView: View {
    @ObservedObject var engine: DuplicateEngine
    @State private var selectedGroupId: String?
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            if !engine.isScanning && !engine.hasScanned {
                landingScreen
            } else {
                dupHeader
                Divider()
                HStack(spacing: 0) {
                    dupGroupList
                    Divider()
                    if let gid = selectedGroupId,
                       let group = engine.groups.first(where: { $0.id == gid }) {
                        dupItemList(group: group)
                    } else {
                        emptyState
                    }
                }
                Divider()
                dupFooter
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Remove Duplicates?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                engine.removeSelected()
            }
        } message: {
            Text("This will move \(engine.selectedCount) duplicate file(s) to the Trash. You can restore them from Trash if needed.")
        }
    }

    // MARK: - Landing
    private var landingScreen: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A0533"), Color(hex: "2D1054"), Color(hex: "4A1A7A"), Color(hex: "1A0533")],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(colors: [Color(hex: "9C27B0").opacity(0.6), Color(hex: "E040FB").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "9C27B0").opacity(0.4), radius: 30, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )

                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "E1BEE7")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.bottom, 28)

                Text("Duplicate Finder")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Find and remove duplicate files to\nreclaim valuable disk space.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 24)

                Button(action: {
                    engine.selectDirectory()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(Color(hex: "E040FB"))
                        Text(engine.selectedDirectory?.lastPathComponent ?? FileManager.default.homeDirectoryForCurrentUser.lastPathComponent)
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 32)

                ToolPrimaryActionButton(
                    title: "Find Duplicates",
                    colors: [Color(hex: "9C27B0"), Color(hex: "E040FB")],
                    icon: "magnifyingglass"
                ) {
                    engine.hasScanned = true
                    engine.scanAll()
                }

                Spacer()
            }
        }
    }

    // MARK: - Header
    var dupHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color(hex: "9C27B0"), Color(hex: "E040FB")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Duplicate Finder")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Find identical files across your folders")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if engine.isScanning {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Scanning…")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(engine.groups.count) groups")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "9C27B0"))
                    Text(ByteCountFormatter.string(fromByteCount: engine.totalWastedSize, countStyle: .file) + " wasted")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Group List
    var dupGroupList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(engine.groups) { group in
                    DupGroupRow(
                        group: group,
                        isSelected: selectedGroupId == group.id,
                        onTap: { selectedGroupId = group.id }
                    )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .frame(width: 220)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Item List
    func dupItemList(group: DuplicateGroup) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: group.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "9C27B0"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.fileName)
                        .font(.system(size: 16, weight: .bold))
                    Text("\(group.files.count) copies · \(group.sizeFormatted) each")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    engine.autoSelectDuplicates(groupId: group.id)
                } label: {
                    Text("Keep First")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(group.files.enumerated()), id: \.element.id) { idx, file in
                        DupFileRow(
                            file: file,
                            index: idx,
                            onToggle: { engine.toggleFile(groupId: group.id, fileId: file.id) }
                        )
                        Divider().padding(.leading, 56)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Select a duplicate group")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer
    var dupFooter: some View {
        HStack(spacing: 12) {
            Button {
                engine.scanAll()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            if !engine.isScanning {
                Text("\(engine.selectedCount) files selected · \(ByteCountFormatter.string(fromByteCount: engine.selectedSize, countStyle: .file))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Button {
                showConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("Remove Duplicates")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(engine.selectedCount == 0
                              ? AnyShapeStyle(Color.gray)
                              : AnyShapeStyle(LinearGradient(colors: [Color(hex: "9C27B0"), Color(hex: "E040FB")],
                                                             startPoint: .leading, endPoint: .trailing)))
                )
            }
            .buttonStyle(.plain)
            .disabled(engine.selectedCount == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Duplicate Group Row
struct DupGroupRow: View {
    let group: DuplicateGroup
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected
                              ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "9C27B0"), Color(hex: "E040FB")], startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Color.clear))
                        .frame(width: 28, height: 28)
                    Image(systemName: group.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.fileName)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    Text("\(group.files.count) copies · \(group.sizeFormatted)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(group.files.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(hex: "9C27B0").cornerRadius(4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: "9C27B0").opacity(0.08) : (hovered ? Color.gray.opacity(0.06) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }
}

// MARK: - Duplicate File Row
struct DupFileRow: View {
    let file: DuplicateFile
    let index: Int
    let onToggle: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: file.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(file.isSelected ? AppTheme.accent : .secondary)
            }
            .buttonStyle(.plain)

            if index == 0 {
                Text("ORIGINAL")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.success.cornerRadius(3))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(file.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(file.sizeFormatted)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            if hovered {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
                } label: {
                    Text("Reveal")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(hovered ? Color.gray.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }
}

// MARK: - Duplicate Engine
@MainActor
class DuplicateEngine: ObservableObject {
    @Published var groups: [DuplicateGroup] = []
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var selectedDirectory: URL? = nil

    var totalWastedSize: Int64 {
        groups.reduce(0) { total, group in
            // Wasted = (count - 1) * size (since one copy is original)
            total + Int64(max(group.files.count - 1, 0)) * group.fileSize
        }
    }
    var selectedCount: Int { groups.flatMap(\.files).filter(\.isSelected).count }
    var selectedSize: Int64 { groups.flatMap(\.files).filter(\.isSelected).reduce(0) { $0 + $1.size } }

    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Folder to Scan for Duplicates"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK {
            self.selectedDirectory = panel.url
            self.hasScanned = false
            self.groups = []
        }
    }

    func scanAll() {
        isScanning = true
        groups = []

        Task {
            let targetURL = self.selectedDirectory
            let found = await Task.detached(priority: .userInitiated) {
                self.findDuplicates(in: targetURL)
            }.value

            await MainActor.run {
                self.groups = found
                self.isScanning = false
            }
        }
    }

    nonisolated func findDuplicates(in target: URL?) -> [DuplicateGroup] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        
        let dirs: [String]
        if let targetURL = target {
            dirs = [targetURL.path]
        } else {
            dirs = [
                "\(home)/Documents",
                "\(home)/Downloads",
                "\(home)/Desktop",
                "\(home)/Pictures",
                "\(home)/Movies",
                "\(home)/Music"
            ]
        }

        // Phase 1: Group files by size (only files > 4KB)
        var sizeMap: [Int64: [String]] = [:]
        for dir in dirs {
            guard let enumerator = fm.enumerator(atPath: dir) else { continue }
            while let file = enumerator.nextObject() as? String {
                let fullPath = "\(dir)/\(file)"
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else { continue }
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let size = attrs[.size] as? Int64, size > 4096 else { continue }
                sizeMap[size, default: []].append(fullPath)
            }
        }

        // Phase 2: For files with same size, compare MD5 hash
        var hashGroups: [String: [String]] = [:]
        for (_, paths) in sizeMap where paths.count >= 2 {
            for path in paths {
                if let hash = Self.md5Hash(of: path) {
                    hashGroups[hash, default: []].append(path)
                }
            }
        }

        // Phase 3: Build duplicate groups
        var results: [DuplicateGroup] = []
        for (hash, paths) in hashGroups where paths.count >= 2 {
            let sortedPaths = paths.sorted()
            let fileName = (sortedPaths.first! as NSString).lastPathComponent
            let fileSize = (try? fm.attributesOfItem(atPath: sortedPaths.first!))?[.size] as? Int64 ?? 0

            let files = sortedPaths.enumerated().map { idx, path in
                DuplicateFile(
                    name: (path as NSString).lastPathComponent,
                    path: path,
                    size: fileSize,
                    isSelected: false // Don't auto-select any
                )
            }

            let ext = (fileName as NSString).pathExtension.lowercased()
            let icon: String
            switch ext {
            case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff":
                icon = "photo"
            case "mp4", "mov", "avi", "mkv":
                icon = "film"
            case "mp3", "aac", "wav", "flac", "m4a":
                icon = "music.note"
            case "pdf":
                icon = "doc.richtext"
            case "zip", "rar", "7z", "dmg":
                icon = "archivebox"
            case "doc", "docx", "txt", "rtf", "pages":
                icon = "doc.text"
            case "xls", "xlsx", "csv", "numbers":
                icon = "tablecells"
            default:
                icon = "doc"
            }

            results.append(DuplicateGroup(
                hash: hash,
                fileName: fileName,
                fileSize: fileSize,
                files: files,
                icon: icon
            ))
        }

        return results.sorted { $0.fileSize * Int64($0.files.count) > $1.fileSize * Int64($1.files.count) }
    }

    nonisolated static func md5Hash(of path: String) -> String? {
        guard let file = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? file.close() }
        
        var hasher = Insecure.MD5()
        let bufferSize = 1024 * 1024 // 1MB chunk size
        
        while true {
            do {
                guard let data = try file.read(upToCount: bufferSize) else { break }
                hasher.update(data: data)
            } catch {
                return nil
            }
        }
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func toggleFile(groupId: String, fileId: UUID) {
        guard let gi = groups.firstIndex(where: { $0.id == groupId }),
              let fi = groups[gi].files.firstIndex(where: { $0.id == fileId }) else { return }
        groups[gi].files[fi].isSelected.toggle()
    }

    func autoSelectDuplicates(groupId: String) {
        guard let gi = groups.firstIndex(where: { $0.id == groupId }) else { return }
        // Keep first file, select all others for removal
        for fi in groups[gi].files.indices {
            groups[gi].files[fi].isSelected = fi > 0
        }
    }

    func removeSelected() {
        let fm = FileManager.default
        for gi in groups.indices {
            groups[gi].files.removeAll { file in
                guard file.isSelected else { return false }
                do {
                    try fm.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                    return true
                } catch {
                    return false
                }
            }
        }
        // Remove groups that now have 1 or fewer files
        groups.removeAll { $0.files.count <= 1 }
    }
}

// MARK: - Data Models
struct DuplicateGroup: Identifiable {
    var id: String { hash }
    let hash: String
    let fileName: String
    let fileSize: Int64
    var files: [DuplicateFile]
    let icon: String

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

struct DuplicateFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    var isSelected: Bool

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
