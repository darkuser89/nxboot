import Foundation

/// Atomic metadata persistence. Payloads remain at their original locations.
struct LibraryStore {
    let url: URL
    struct State {
        var payloads: [Payload] = []
        var automaticPayloadID: UUID?
        var automaticEnabled = false
    }
    private struct Document: Codable {
        let version: Int
        var payloads: [Payload]
        var automaticPayloadID: UUID?
        var automaticEnabled: Bool?
    }
    static var standard: LibraryStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return LibraryStore(url: support.appendingPathComponent("NXBootModern/library.json"))
    }
    func load() throws -> [Payload] {
        try loadState().payloads
    }
    func loadState() throws -> State {
        guard FileManager.default.fileExists(atPath: url.path) else { return State() }
        let doc = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
        guard doc.version == 1, Set(doc.payloads.map(\.id)).count == doc.payloads.count else {
            throw PayloadError.unsupportedLibrary
        }
        let id = doc.automaticPayloadID.flatMap { id in doc.payloads.contains { $0.id == id } ? id : nil }
        return State(payloads: doc.payloads, automaticPayloadID: id,
                     automaticEnabled: id != nil && doc.automaticEnabled == true)
    }
    func save(_ payloads: [Payload], automaticPayloadID: UUID? = nil, automaticEnabled: Bool = false) throws {
        let data = try JSONEncoder().encode(Document(version: 1, payloads: payloads,
                            automaticPayloadID: automaticPayloadID, automaticEnabled: automaticEnabled))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
