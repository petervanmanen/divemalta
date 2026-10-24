import CoreLocation
import Foundation
import Observation

/// Your own dives, read from the FIT files in a folder you choose (for example an iCloud Drive folder
/// your dive computer's app exports to). Dives in Malta are matched to the nearest dive site, which
/// is then shown as visited. Everything stays on the phone.
@MainActor @Observable
final class DiveLog {
    struct Dive: Identifiable, Hashable {
        let file: String          // path inside the chosen folder
        let fit: FitFile.Dive
        var id: String { file }
    }

    /// A dive counts for a site when it starts within this distance of it. Dive computers get their
    /// position at the surface, so this is where you got in (shore) or where the boat was.
    static let matchDistance: CLLocationDistance = 400

    private(set) var folderName: String?
    private(set) var isScanning = false
    private(set) var error: String?
    /// All dives found in the folder, also outside Malta.
    private(set) var dives: [Dive] = []
    private(set) var fitFileCount = 0
    /// Dives per site id, newest first.
    private(set) var visits: [String: [Dive]] = [:]
    /// Dives in Malta that aren't near any known site.
    private(set) var unmatched: [Dive] = []

    var maltaDiveCount: Int { visits.values.reduce(0) { $0 + $1.count } + unmatched.count }

    private let sites: [DiveSite]
    private static let bookmarkKey = "diveLogFolderBookmark"
    nonisolated private static let cacheURL = URL.applicationSupportDirectory.appendingPathComponent("dive-log-cache.json")

    init(sites: [DiveSite]) {
        self.sites = sites
    }

    /// Remembers the folder (picked in the Files browser) and reads it.
    func choose(folder url: URL) async {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            try? FileManager.default.removeItem(at: Self.cacheURL)
        } catch {
            self.error = "Couldn't keep access to this folder: \(error.localizedDescription)"
            return
        }
        await scan()
    }

    func forget() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        try? FileManager.default.removeItem(at: Self.cacheURL)
        folderName = nil
        error = nil
        dives = []
        fitFileCount = 0
        match()
    }

    /// Reads the folder again. Files that haven't changed since the last scan come from the cache.
    /// ContentView calls this at start and whenever the app comes back to the foreground, so newly
    /// exported dives show up.
    func scan() async {
        guard !isScanning else { return }
        var stale = false
        let folder: URL
        if let debug = Self.debugFolder {
            folder = debug
        } else if ScreenshotScene.current != nil {
            return      // App Store screenshots show the app without a dive log
        } else {
            guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
            guard let resolved = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) else {
                error = "The dive log folder can't be found any more. Choose it again."
                return
            }
            folder = resolved
        }
        isScanning = true
        defer { isScanning = false }
        folderName = folder.lastPathComponent
        let result = await Task.detached(priority: .utility) { Self.read(folder: folder) }.value
        if stale, let fresh = result.bookmark {
            UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
        }
        error = result.error
        fitFileCount = result.fitFiles
        dives = result.dives.sorted { ($0.fit.start ?? .distantPast) > ($1.fit.start ?? .distantPast) }
        match()
    }

    /// For testing in the simulator: `-diveLogFolder <path on the Mac>` reads that folder without the picker.
    private static var debugFolder: URL? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-diveLogFolder"), i + 1 < args.count {
            return URL(fileURLWithPath: args[i + 1], isDirectory: true)
        }
        #endif
        return nil
    }

    private func match() {
        var visits: [String: [Dive]] = [:]
        var unmatched: [Dive] = []
        for dive in dives where MapView.contains(.init(latitude: dive.fit.latitude, longitude: dive.fit.longitude)) {
            let here = CLLocation(latitude: dive.fit.latitude, longitude: dive.fit.longitude)
            let nearest = sites
                .map { ($0, here.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lon))) }
                .min { $0.1 < $1.1 }
            if let (site, distance) = nearest, distance <= Self.matchDistance {
                visits[site.id, default: []].append(dive)
            } else {
                unmatched.append(dive)
            }
        }
        self.visits = visits
        self.unmatched = unmatched
    }

    // MARK: Reading the folder (off the main thread)

    private struct CacheEntry: Codable {
        let size: Int
        let modified: Date
        let dive: FitFile.Dive?
    }

    private struct ReadResult: Sendable {
        var dives: [Dive] = []
        var fitFiles = 0
        var error: String?
        var bookmark: Data?
    }

    nonisolated private static func read(folder: URL) -> ReadResult {
        var result = ReadResult()
        // Folders from the picker need this; if it fails, reading below reports the problem.
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        result.bookmark = try? folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)

        let cache = (try? Data(contentsOf: cacheURL)).flatMap { try? JSONDecoder().decode([String: CacheEntry].self, from: $0) } ?? [:]
        var newCache: [String: CacheEntry] = [:]
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]

        // Coordinated access makes iCloud Drive list (and below, download) files that aren't on the phone yet.
        var files: [URL] = []
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: [], error: &coordinationError) { dir in
            let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: keys)
            while let url = enumerator?.nextObject() as? URL {
                var name = url.lastPathComponent
                // An iCloud file that isn't downloaded can show up as ".name.fit.icloud".
                if name.hasPrefix("."), name.hasSuffix(".icloud") {
                    name = String(name.dropFirst().dropLast(".icloud".count))
                    let real = url.deletingLastPathComponent().appendingPathComponent(name)
                    try? FileManager.default.startDownloadingUbiquitousItem(at: real)
                    if name.lowercased().hasSuffix(".fit") { files.append(real) }
                } else if name.lowercased().hasSuffix(".fit") {
                    files.append(url)
                }
            }
        }
        if let coordinationError {
            result.error = "Couldn't read the folder: \(coordinationError.localizedDescription)"
            return result
        }

        let base = folder.standardizedFileURL.path
        for url in files {
            result.fitFiles += 1
            let path = url.standardizedFileURL.path
            let relative = path.hasPrefix(base) ? String(path.dropFirst(base.count)).trimmingCharacters(in: ["/"]) : url.lastPathComponent
            let values = try? url.resourceValues(forKeys: Set(keys))
            let size = values?.fileSize ?? -1
            let modified = values?.contentModificationDate ?? .distantPast

            let entry: CacheEntry
            if let cached = cache[relative], cached.size == size, cached.modified == modified, size >= 0 {
                entry = cached
            } else {
                var data: Data?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: nil) { data = try? Data(contentsOf: $0) }
                guard let data else { continue }    // not downloaded yet; tried again next scan
                entry = CacheEntry(size: data.count, modified: modified, dive: try? FitFile.dive(in: data))
            }
            newCache[relative] = entry
            if let dive = entry.dive { result.dives.append(Dive(file: relative, fit: dive)) }
        }

        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(newCache).write(to: cacheURL, options: .atomic)
        return result
    }
}
