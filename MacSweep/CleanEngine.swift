import Foundation

@MainActor
class CleanEngine: ObservableObject {

    @Published var isCleaning    = false
    @Published var cleanProgress = 0.0
    @Published var currentPath   = ""
    @Published var cleanedSize   : Int64 = 0
    @Published var cleanComplete = false
    @Published var errors        : [String] = []

    private let fm = FileManager.default

    func clean(items: [ScanItem]) async {
        let toDelete = items.filter(\.isSelected)
        guard !toDelete.isEmpty else { return }

        isCleaning    = true
        cleanComplete = false
        cleanedSize   = 0
        cleanProgress = 0
        errors        = []

        let total = Double(toDelete.count)

        for (index, item) in toDelete.enumerated() {
            currentPath = item.path

            if !fm.fileExists(atPath: item.path) {
                cleanProgress = Double(index + 1) / total
                continue
            }

            do {
                let url   = URL(fileURLWithPath: item.path)
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

                if isDir {
                    if let contents = try? fm.contentsOfDirectory(atPath: item.path) {
                        for name in contents {
                            try? fm.removeItem(atPath: "\(item.path)/\(name)")
                        }
                    }
                } else {
                    try fm.removeItem(at: url)
                }
                cleanedSize += item.size
            } catch {
                errors.append("\(item.name): \(error.localizedDescription)")
            }

            cleanProgress = Double(index + 1) / total
        }

        isCleaning    = false
        cleanComplete = true
        currentPath   = ""
    }
}
