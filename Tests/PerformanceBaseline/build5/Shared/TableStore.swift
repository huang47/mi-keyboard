import Foundation
import Darwin

struct TableStore {
    let directory: URL
    private let fileURL: URL
    private let cache = Cache()
    private static let bundledCache = Cache()

    /// A store retains at most one custom table. Atomic replacements have a new file identity.
    private final class Cache {
        let lock = NSLock()
        var signature: Signature?
        var table: CodeTable?
        var bundledURL: URL?
    }

    private struct Signature: Equatable {
        let fileNumber: UInt64
        let size: Int64
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int

        init(attributes: stat) {
            self.fileNumber = UInt64(attributes.st_ino)
            self.size = attributes.st_size
            self.modifiedSeconds = attributes.st_mtimespec.tv_sec
            self.modifiedNanoseconds = attributes.st_mtimespec.tv_nsec
        }
    }

    init(directory: URL) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("code-table.json")
    }

    private func fileSignature() throws -> Signature? {
        var attributes = stat()
        let (result, errorCode) = fileURL.withUnsafeFileSystemRepresentation { filePath in
            guard let filePath else { return (Int32(-1), EINVAL) }
            let result = fstatat(AT_FDCWD, filePath, &attributes, 0)
            return (result, errno)
        }
        guard result == 0 else {
            if errorCode == ENOENT { return nil }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errorCode))
        }
        return Signature(attributes: attributes)
    }

    enum StoreError: LocalizedError {
        case unavailable
        var errorDescription: String? {
            "共享儲存空間未設定。請確認 App 與鍵盤使用相同的 App Group 簽署。"
        }
    }

    static func shared() throws -> TableStore {
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw StoreError.unavailable
        }
        return TableStore(directory: directory)
    }

    func load() throws -> CodeTable? {
        cache.lock.lock()
        defer { cache.lock.unlock() }
        guard let signature = try fileSignature() else {
            cache.table = nil
            cache.signature = nil
            return try Self.bundled()
        }
        guard signature.size <= 64 * 1024 * 1024 else {
            throw TableError.fileTooLarge
        }
        if cache.signature == signature, let table = cache.table { return table }
        // Never keep a stale table if a replacement fails validation.
        cache.table = nil
        cache.signature = nil
        let table = try TableJSON.decode(Data(contentsOf: fileURL))
        try table.validate()
        cache.table = table
        cache.signature = signature
        return table
    }

    static func bundled(in bundle: Bundle = .main) throws -> CodeTable? {
        guard let url = bundle.url(forResource: "boshiamy", withExtension: "bin")
            ?? bundle.url(forResource: "boshiamy", withExtension: "json") else { return nil }
        bundledCache.lock.lock()
        defer { bundledCache.lock.unlock() }
        if bundledCache.bundledURL == url, let table = bundledCache.table { return table }
        let data = try Data(contentsOf: url)
        let table: CodeTable
        if url.pathExtension == "bin" { table = try PackedCodeTable.decode(data) }
        else {
            table = try TableJSON.decode(data)
            try table.validate()
        }
        bundledCache.bundledURL = url
        bundledCache.table = table
        return table
    }

    /// Only the containing app writes. Extension access stays read-only.
    func save(_ table: CodeTable) throws {
        try table.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: ["version": table.version,
            "name": table.name, "entries": table.entries])
        cache.lock.lock()
        defer { cache.lock.unlock() }
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cache.table = nil
        cache.signature = nil
    }

    func remove() throws {
        cache.lock.lock()
        defer { cache.lock.unlock() }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        cache.table = nil
        cache.signature = nil
    }

    func importFile(_ url: URL) throws -> CodeTable {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= TableParser.maximumBytes else { throw TableError.fileTooLarge }
        let table = try TableParser.parse(Data(contentsOf: url), fileName: url.lastPathComponent)
        try save(table)
        return table
    }
}
