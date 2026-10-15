import Foundation

/// The dictionary ships with each app/extension and is cached for its process.
enum TableStore {
    private static let lock = NSLock()
    private static var cachedURL: URL?
    private static var cachedTable: CodeTable?

    static func bundled(in bundle: Bundle = .main) throws -> CodeTable? {
        guard let url = bundle.url(forResource: "boshiamy", withExtension: "bin") else { return nil }
        lock.lock()
        defer { lock.unlock() }
        if cachedURL == url, let table = cachedTable { return table }
        let table = try PackedCodeTable.decode(Data(contentsOf: url))
        cachedURL = url
        cachedTable = table
        return table
    }
}
