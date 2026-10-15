import Foundation

/// Readings retain their tone marks. Polyphonic seeds search each recorded reading.
struct HomophoneTable: Decodable {
    let version: Int
    let readings: [String: [String]]
    let groups: [String: [String]]

    // Only the first homophone lookup loads this resource; ordinary typing stays unchanged.
    static let bundled: HomophoneTable? = load(in: .main)

    static func load(in bundle: Bundle) -> HomophoneTable? {
        guard let url = bundle.url(forResource: "homophones", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode(Self.self, from: data),
              table.version == 1 else { return nil }
        return table
    }

    func candidates(for seed: String) -> [String] {
        guard seed.count == 1, let sounds = readings[seed] else { return [] }
        var seen: Set<String> = [seed]
        var result = [seed]
        for sound in sounds {
            for word in groups[sound] ?? [] where seen.insert(word).inserted { result.append(word) }
        }
        return result
    }
}
