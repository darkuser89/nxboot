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

enum PayloadError: LocalizedAppError {
    case notLocal, empty, tooLarge, notRegular, missing, unsupportedLibrary
    var message: AppMessage {
        switch self {
        case .notLocal: return AppMessage("error.notLocal")
        case .empty: return AppMessage("error.empty")
        case .tooLarge: return AppMessage("error.tooLarge", String(NXPayloadSizeLimit()))
        case .notRegular: return AppMessage("error.notRegular")
        case .missing: return AppMessage("error.missing")
        case .unsupportedLibrary: return AppMessage("error.libraryFormat")
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
