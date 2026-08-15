import Foundation

/// A monochrome sidebar glyph preset: a named SF Symbol bound to a private
/// four-character OSType code.
struct SidebarGlyphPreset {
    let name: String      // CLI spelling, e.g. "star"
    let symbol: String    // SF Symbol name, e.g. "star.fill"
    let code: String      // OSType code, e.g. "S002"
}

/// Monochrome sidebar glyphs for the `icon` command.
///
/// Finder draws sidebar favorites as a flat, single-color silhouette tinted to
/// the sidebar (color there is impossible — a macOS rule). The glyph is chosen
/// by the `com.apple.LSSharedFileList.OverrideIcon.OSType` property, a
/// four-character code that Finder resolves to an SF Symbol through Launch
/// Services UTI declarations. `ensureHelperBundleRegistered()` installs a tiny
/// no-op helper app that declares each preset's code, so arbitrary SF Symbol
/// *shapes* work from a plain CLI with no background process and no Xcode.
enum SidebarGlyph {

    /// All glyph presets, in declaration order (index derives the OSType code).
    static let presets: [SidebarGlyphPreset] = {
        let entries: [(name: String, symbol: String)] = [
            ("folder",    "folder.fill"),
            ("star",      "star.fill"),
            ("heart",     "heart.fill"),
            ("briefcase", "briefcase.fill"),
            ("hammer",    "hammer.fill"),
            ("tag",       "tag.fill"),
            ("bookmark",  "bookmark.fill"),
            ("trash",     "trash.fill"),
            ("house",     "house.fill"),
            ("gearshape", "gearshape.fill"),
            ("pencil",    "pencil"),
            ("photo",     "photo.fill"),
            ("music",     "music.note"),
            ("doc",       "doc.fill"),
            ("link",      "link"),
            ("flag",      "flag.fill"),
            ("clock",     "clock.fill"),
            ("calendar",  "calendar"),
            ("envelope",  "envelope.fill"),
            ("cart",      "cart.fill"),
        ]
        return entries.enumerated().map { index, entry in
            SidebarGlyphPreset(name: entry.name, symbol: entry.symbol, code: code(forIndex: index))
        }
    }()

    /// The glyph spelling that clears a favorite back to its default folder icon.
    static let resetName = "none"

    /// All preset names, in declaration order.
    static var presetNames: [String] { presets.map(\.name) }

    /// The preset matching `name`, or `nil`.
    static func preset(named name: String) -> SidebarGlyphPreset? {
        presets.first { $0.name == name }
    }

    /// "S000" ... "S999". The uppercase `S` prefix keeps our codes out of the
    /// lowercase namespace Apple's own sidebar codes use (`fldr`, `docs`, ...).
    private static func code(forIndex index: Int) -> String {
        String(format: "S%03d", index)
    }

    // MARK: - Helper bundle

    static let bundleIdentifier = "com.seakrebel.mysides.icons"
    private static let utiPrefix = "com.seakrebel.mysides.icon."
    private static let executableName = "mysides-icons"
    private static let bundleVersion = "1" // Bump when the preset list changes.
    private static let executableScript = "#!/bin/sh\nexit 0\n"

    /// Where the helper bundle lives.
    static func helperBundleURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("mysides", isDirectory: true)
            .appendingPathComponent("Icons.app", isDirectory: true)
    }

    /// Builds and registers the helper bundle unless it is already installed at
    /// the current version. Returns `true` when the bundle was (re)registered
    /// this run, which means Finder should be restarted to pick up the change.
    @discardableResult
    static func ensureHelperBundleRegistered() throws -> Bool {
        let fm = FileManager.default
        let bundleURL = helperBundleURL()
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        let executableURL = macOSURL.appendingPathComponent(executableName)
        let plistURL = contentsURL.appendingPathComponent("Info.plist")

        // Already installed at the current version: nothing to do.
        if fm.fileExists(atPath: executableURL.path),
           let existing = NSDictionary(contentsOf: plistURL),
           existing["CFBundleIdentifier"] as? String == bundleIdentifier,
           existing["CFBundleVersion"] as? String == bundleVersion {
            return false
        }

        try fm.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try Data(executableScript.utf8).write(to: executableURL, options: [.atomic])
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        let typeDeclarations: [[String: Any]] = presets.map { preset in
            [
                "UTTypeIdentifier": utiPrefix + preset.code.lowercased(),
                "UTTypeDescription": "\(preset.name) sidebar icon",
                "UTTypeConformsTo": ["public.folder"],
                "UTTypeTagSpecification": ["com.apple.ostype": [preset.code]],
                "UTTypeIcons": ["UTTypeSymbolName": preset.symbol]
            ]
        }

        let plist: [String: Any] = [
            "CFBundleExecutable": executableName,
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": "mysides icons",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": mysidesVersion,
            "CFBundleVersion": bundleVersion,
            "LSMinimumSystemVersion": "13.0",
            "LSUIElement": true,
            "LSBackgroundOnly": true,
            "UTExportedTypeDeclarations": typeDeclarations
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: [.atomic])

        try registerWithLaunchServices(bundleURL)
        return true
    }

    private static func registerWithLaunchServices(_ bundleURL: URL) throws {
        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: lsregister)
        process.arguments = ["-f", "-R", "-trusted", bundleURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw SidebarError.helperFailed("lsregister failed with status \(process.terminationStatus)")
        }
    }
}
