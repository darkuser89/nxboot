import Foundation
import ModernUSB

struct Payload: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var bookmark: Data
    var filename: String
    var byteCount: Int
    var isFavorite = true
    var addedAt = Date()
    var lastSentAt: Date?
}

enum PayloadError: LocalizedError {
    case notLocal, empty, tooLarge, notRegular, missing, unsupportedLibrary
    var errorDescription: String? {
        switch self {
        case .notLocal: return "Bitte eine lokale Payload-Datei auswählen."
        case .empty: return "Die Payload-Datei ist leer."
        case .tooLarge: return "Der Payload ist zu groß. Maximal \(Int(NXPayloadSizeLimit())) Bytes sind möglich."
        case .notRegular: return "Bitte eine einzelne .bin-Datei auswählen."
        case .missing: return "Die Datei ist nicht mehr erreichbar. Bitte über ‚Datei neu zuordnen‘ auswählen."
        case .unsupportedLibrary: return "Diese Mediathek hat ein unbekanntes Format. Sie wird nicht überschrieben."
        }
    }
}

enum PayloadFile {
    static func read(_ url: URL) throws -> Data {
        guard url.isFileURL else { throw PayloadError.notLocal }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, url.pathExtension.lowercased() == "bin" else {
            throw PayloadError.notRegular
        }
        guard let size = values.fileSize, size > 0 else { throw PayloadError.empty }
        guard size <= Int(NXPayloadSizeLimit()) else { throw PayloadError.tooLarge }
        // Bounded read also protects against a file growing after its metadata was checked.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: Int(NXPayloadSizeLimit()) + 1) ?? Data()
        guard !data.isEmpty else { throw PayloadError.empty }
        guard data.count <= Int(NXPayloadSizeLimit()) else { throw PayloadError.tooLarge }
        return data
    }

    static func bookmark(_ url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil,
                             relativeTo: nil)
    }

    static func resolve(_ payload: Payload) throws -> (url: URL, stale: Bool) {
        var stale = false
        let url = try URL(resolvingBookmarkData: payload.bookmark,
                          options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil,
                          bookmarkDataIsStale: &stale)
        return (url, stale)
    }
}
