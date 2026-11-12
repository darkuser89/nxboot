import AppKit
import CryptoKit
import Darwin
import ImageIO

/// Runs against the one current local app, without launching it or accessing USB.
@main
struct FinderIconSignatureCheck {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "IconSignatureCheck", code: 1,
                                       userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func info(_ app: URL) throws -> [String: Any] {
        try PropertyListSerialization.propertyList(from: Data(contentsOf:
            app.appendingPathComponent("Contents/Info.plist")), format: nil) as! [String: Any]
    }
    static func verify(_ app: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", app.path]
        try process.run()
        process.waitUntilExit()
        try require(process.terminationStatus == 0, "Strict signature check failed")
    }
    @MainActor
    static func verifyFinderColor(_ app: URL, accent: JoyConAccent) throws {
        let icon = NSWorkspace.shared.icon(forFile: app.path)
        var rect = CGRect(x: 0, y: 0, width: 128, height: 128)
        guard let image = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw NSError(domain: "IconSignatureCheck", code: 3)
        }
        var bytes = [UInt8](repeating: 0, count: 128 * 128 * 4)
        bytes.withUnsafeMutableBytes { pointer in
            let context = CGContext(data: pointer.baseAddress, width: 128, height: 128,
                bitsPerComponent: 8, bytesPerRow: 128 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: 128, height: 128))
        }
        var sum = [Double](repeating: 0, count: 3)
        var colored = 0
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            let rgb = (0..<3).map { Double(bytes[offset + $0]) / 255 }
            let value = rgb.max()!, minimum = rgb.min()!
            if bytes[offset + 3] > 240, value > 0.25, (value - minimum) / value > 0.35 {
                colored += 1
                for channel in 0..<3 { sum[channel] += rgb[channel] }
            }
        }
        if accent == .gray {
            try require(colored < 128 * 128 / 50, "Finder retained a colored icon for gray")
        } else {
            try require(colored > 128 * 128 / 30, "Finder did not return the colored icon")
            let (r, g, b) = accent.rgb
            let target = [r, g, b]
            for channel in 0..<3 {
                try require(abs(sum[channel] / sum.max()! - target[channel] / target.max()!) < 0.2,
                            "Finder color readback mismatch: \(accent.rawValue)")
            }
        }
    }
    @MainActor
    static func verifyFinderColorEventually(_ app: URL, accent: JoyConAccent) async throws {
        // IconServices renders/caches new bundled icons asynchronously after registration.
        for _ in 0..<30 {
            let reader = Process()
            reader.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            reader.arguments = ["--read-finder-color", app.path, accent.rawValue]
            reader.standardError = FileHandle.nullDevice
            try reader.run()
            reader.waitUntilExit()
            if reader.terminationStatus == 0 { return }
            try await Task.sleep(for: .milliseconds(150))
        }
        throw NSError(domain: "IconSignatureCheck", code: 4,
                      userInfo: [NSLocalizedDescriptionKey: "Finder readback failed for \(accent.rawValue)"])
    }
    @MainActor
    static func main() async {
        do { try await run() }
        catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    @MainActor
    static func run() async throws {
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--read-finder-color" {
            try verifyFinderColor(URL(fileURLWithPath: CommandLine.arguments[2]),
                                  accent: JoyConAccent(rawValue: CommandLine.arguments[3])!)
            return
        }
        setbuf(stdout, nil)
        let app = URL(fileURLWithPath: CommandLine.arguments[1])
        let template = app.appendingPathComponent("Contents/Resources/AppIconTemplate.png")
        let masterHash = try Data(SHA256.hash(data: Data(contentsOf: template)))
        let renderer = AppIconRenderer(iconURL: template)
        let service = FinderIconService()
        let executable = app.appendingPathComponent("Contents/MacOS/NXBootModern")
        let liveHandle = try FileHandle(forReadingFrom: executable)
        defer { try? liveHandle.close() }
        let originalExecutable = try liveHandle.readToEnd()!
        let saved = UserDefaults(suiteName: "de.nxboot.modern")?.string(forKey: "joyConAccent") ?? "gray"
        let restore = JoyConAccent(rawValue: saved) ?? .gray

        // Upgrade the metadata-based implementation without losing the existing color.
        let migrationImage = await renderer.render(.pink)!
        try require(NSWorkspace.shared.setIcon(NSImage(cgImage: migrationImage, size: NSSize(width: 512, height: 512)),
                                               forFile: app.path, options: []), "Legacy icon setup failed")
        try await service.apply(migrationImage, accent: .pink, to: app)
        try verify(app)
        print("Migration from legacy Finder metadata: strict signature valid")

        for accent in JoyConAccent.allCases {
            guard let rendered = await renderer.render(accent) else {
                throw NSError(domain: "IconSignatureCheck", code: 2)
            }
            try await service.apply(rendered, accent: accent, to: app)
            try verify(app)
            try await verifyFinderColorEventually(app, accent: accent)
            let document = try info(app)
            try require(document["NXBootFinderAccent"] as? String == accent.rawValue, "Accent metadata mismatch")
            let filename = document["CFBundleIconFile"] as! String
            try require(filename == "AppIcon-\(accent.rawValue).icns", "Wrong icon resource")
            let icon = app.appendingPathComponent("Contents/Resources/\(filename)")
            try require(FileManager.default.fileExists(atPath: icon.path), "Icon resource missing")
            try liveHandle.seek(toOffset: 0)
            let unchanged = try liveHandle.readToEnd() == originalExecutable
            try require(unchanged, "The old executable inode was overwritten")
            let currentMasterHash = try Data(SHA256.hash(data: Data(contentsOf: template)))
            try require(currentMasterHash == masterHash, "The immutable template changed")
            try require(!FileManager.default.fileExists(atPath: app.appendingPathComponent("Icon\r").path),
                        "Legacy icon resource remains")
            try require(!FileManager.default.fileExists(atPath:
                app.deletingLastPathComponent().appendingPathComponent(".NXBootModern-icon-update").path),
                        "Exchange tree was retained")
            print("\(accent.rawValue): Finder color and strict/deep signature valid, live inode and template unchanged")
        }
        // Matching colors are a no-op: no re-signing or unnecessary exchange copies.
        let before = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        try await service.apply(await renderer.render(.pink)!, accent: .pink, to: app)
        let after = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        try require(before == after, "An unchanged color rewrote the app")
        try await service.apply(await renderer.render(restore)!, accent: restore, to: app)
        try verify(app)
        // A legitimate icon change must never silently re-sign already corrupted resources.
        let originalTemplate = try Data(contentsOf: template)
        do {
            defer { try? originalTemplate.write(to: template, options: .atomic) }
            var modified = originalTemplate
            modified.append(0)
            try modified.write(to: template, options: .atomic)
            var rejected = false
            do { try await service.apply(migrationImage, accent: .pink, to: app) }
            catch { rejected = true }
            try require(rejected, "A corrupted resource was silently re-signed")
        }
        try verify(app)
        print("Corrupted resources rejected without re-signing; restored app passes strict verification")
        print("Saved color restored: \(restore.rawValue). No app launch or USB operations performed.")
    }
}
