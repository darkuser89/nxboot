import AppKit
import CoreServices
import Darwin
import ImageIO
import Security
import UniformTypeIdentifiers

/// Serial, local updates of this ad-hoc-signed app. The running executable's inode is never modified.
actor FinderIconService {
    static let shared = FinderIconService()
    private let files = FileManager.default
    private let bundleID = "de.nxboot.modern"

    func apply(_ image: CGImage, accent: JoyConAccent, to appURL: URL) throws {
        let url = appURL.resolvingSymlinksInPath()
        guard url.isFileURL, url.pathExtension.lowercased() == "app",
              files.isWritableFile(atPath: url.path),
              files.isWritableFile(atPath: url.deletingLastPathComponent().path) else {
            throw failure("Die App und ihr Ordner müssen für dich beschreibbar sein.")
        }
        try Task.checkCancellation()

        // This one short-lived exchange tree is on the same filesystem as the installed app.
        let work = url.deletingLastPathComponent().appendingPathComponent(".NXBootModern-icon-update", isDirectory: true)
        let lockURL = url.deletingLastPathComponent().appendingPathComponent(".NXBootModern-icon.lock")
        let fd = open(lockURL.path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw failure("Der Icon-Wechsel konnte nicht vorbereitet werden.") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            throw failure("Ein anderer Icon-Wechsel läuft bereits. Bitte kurz erneut versuchen.")
        }
        defer { flock(fd, LOCK_UN) }
        try checkLocalIdentity(url)
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        let infoData = try Data(contentsOf: infoURL)
        guard var info = try PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == bundleID else {
            throw failure("Das App-Paket konnte nicht zugeordnet werden.")
        }
        if files.fileExists(atPath: work.path) { try files.removeItem(at: work) }
        if info["NXBootFinderAccent"] as? String == accent.rawValue,
           (try? validate(url, strict: true)) != nil { return }
        try files.createDirectory(at: work, withIntermediateDirectories: true)
        var cleanupWork = true
        defer { if cleanupWork { try? files.removeItem(at: work) } }
        let staged = work.appendingPathComponent("NXBoot Modern.app", isDirectory: true)
        try files.copyItem(at: url, to: staged)

        // Migrate only the old Finder metadata created by our previous setIcon implementation.
        let oldCustomIcon = staged.appendingPathComponent("Icon\r")
        if files.fileExists(atPath: oldCustomIcon.path) { try files.removeItem(at: oldCustomIcon) }
        _ = removexattr(staged.path, "com.apple.FinderInfo", 0)
        _ = removexattr(staged.path, "com.apple.ResourceFork", 0)

        let resources = staged.appendingPathComponent("Contents/Resources", isDirectory: true)
        let filename = "AppIcon-\(accent.rawValue).icns"
        let iconURL = resources.appendingPathComponent(filename)
        let oldName = info["CFBundleIconFile"] as? String
        try writeIcon(image, to: iconURL, work: work)
        if let oldName, oldName != filename, oldName.hasPrefix("AppIcon"),
           (oldName as NSString).lastPathComponent == oldName,
           (oldName as NSString).pathExtension == "icns" {
            let old = resources.appendingPathComponent(oldName)
            if files.fileExists(atPath: old.path) { try files.removeItem(at: old) }
        }
        info["CFBundleIconFile"] = filename
        info["NXBootFinderAccent"] = accent.rawValue
        let version = Int(info["CFBundleVersion"] as? String ?? "1") ?? 1
        info["CFBundleVersion"] = String(version == Int.max ? 1 : version + 1)
        let updatedInfo = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try updatedInfo.write(to: staged.appendingPathComponent("Contents/Info.plist"), options: .atomic)
        try Task.checkCancellation()
        try run("/usr/bin/codesign", ["--force", "--sign", "-", staged.path])
        // Finder keys its small-icon cache on the outer bundle's modification time.
        // copyItem preserves that time, although the embedded resource has changed.
        try files.setAttributes([.modificationDate: Date()], ofItemAtPath: staged.path)
        try validate(staged, strict: true)
        try Task.checkCancellation()

        // Both names exchange atomically. The live process continues using its unchanged old inode.
        guard renameatx_np(AT_FDCWD, staged.path, AT_FDCWD, url.path, UInt32(RENAME_SWAP)) == 0 else {
            throw failure("Das geprüfte App-Paket konnte nicht eingesetzt werden (\(errno)).")
        }
        do {
            try validate(url, strict: true)
        } catch {
            if renameatx_np(AT_FDCWD, staged.path, AT_FDCWD, url.path, UInt32(RENAME_SWAP)) != 0 {
                // Retain the only recovery item if the filesystem prevents a rollback.
                cleanupWork = false
                throw failure("App-Austausch fehlgeschlagen. Der Austauschbestand liegt unter \(work.path).")
            }
            throw error
        }
        // Register a new bundle version/icon resource, rather than adding Finder extended attributes.
        _ = LSRegisterURL(url as CFURL, true)
    }

    private func checkLocalIdentity(_ url: URL) throws {
        let code = try staticCode(url)
        var raw: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &raw) == errSecSuccess,
              let signing = raw as? [String: Any],
              signing[kSecCodeInfoIdentifier as String] as? String == bundleID,
              let flags = signing[kSecCodeInfoFlags as String] as? NSNumber,
              flags.uint32Value & SecCodeSignatureFlags.adhoc.rawValue != 0 else {
            throw failure("Dieser Finder-Farbwechsel ist für die lokal signierte NXBoot-App vorgesehen.")
        }
        // Never mask pre-existing code/resource corruption. Legacy Finder metadata is allowed only here.
        try validate(url, strict: false)
    }

    private func staticCode(_ url: URL) throws -> SecStaticCode {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &code) == errSecSuccess,
              let code else { throw failure("Die App-Signatur konnte nicht gelesen werden.") }
        return code
    }

    private func validate(_ url: URL, strict: Bool) throws {
        let flags = UInt32(kSecCSCheckNestedCode) | UInt32(kSecCSCheckAllArchitectures) |
            (strict ? UInt32(kSecCSStrictValidate) : 0)
        let status = SecStaticCodeCheckValidity(try staticCode(url), SecCSFlags(rawValue: flags), nil)
        guard status == errSecSuccess else {
            throw failure("Der Icon-Wechsel wurde wegen einer fehlgeschlagenen Signaturprüfung nicht übernommen (\(status)).")
        }
    }

    private func writeIcon(_ image: CGImage, to output: URL, work: URL) throws {
        let iconset = work.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try files.createDirectory(at: iconset, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
                guard let context = CGContext(data: nil, width: pixels, height: pixels,
                    bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                    throw failure("Das farbige Icon konnte nicht erzeugt werden.")
                }
                context.interpolationQuality = .high
                context.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
                let pngURL = iconset.appendingPathComponent(name)
                guard let bitmap = context.makeImage(),
                      let destination = CGImageDestinationCreateWithURL(pngURL as CFURL,
                            UTType.png.identifier as CFString, 1, nil) else {
                    throw failure("Das farbige Icon konnte nicht gespeichert werden.")
                }
                CGImageDestinationAddImage(destination, bitmap, nil)
                guard CGImageDestinationFinalize(destination) else {
                    throw failure("Das farbige Icon konnte nicht gespeichert werden.")
                }
            }
        }
        if files.fileExists(atPath: output.path) { try files.removeItem(at: output) }
        try run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", output.path])
    }

    private func run(_ path: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw failure("Das farbige App-Paket konnte nicht erstellt oder signiert werden.")
        }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "NXBootModern.FinderIcon", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
