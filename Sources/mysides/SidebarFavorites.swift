import Foundation
import CoreServices

/// A single entry in the Finder sidebar favorites list.
struct SidebarItem: Equatable {
    var name: String
    var url: URL?
}

/// Errors surfaced by the sidebar wrapper.
enum SidebarError: Error, Equatable, CustomStringConvertible {
    case couldNotOpenList
    case invalidURL(String)
    case notFound(name: String)
    case invalidShape(String)
    case setShapeFailed(name: String)
    case helperFailed(String)

    var description: String {
        switch self {
        case .couldNotOpenList:
            return "Unable to create sidebar list, LSSharedFileListCreate() fails."
        case .invalidURL(let string):
            return "Invalid URI: \(string)"
        case .notFound(let name):
            return "Could not find sidebar item with display name: \(name)"
        case .invalidShape(let spec):
            return "Unknown glyph: \(spec)"
        case .setShapeFailed(let name):
            return "Could not set glyph for sidebar item: \(name)"
        case .helperFailed(let detail):
            return "Icon helper failed: \(detail)"
        }
    }
}

/// Thin Swift wrapper around the deprecated-but-unreplaced `LSSharedFileList`
/// API for the Finder favorites ("Favorite Items") list.
///
/// `LSSharedFileList` was deprecated in macOS 10.11 and has no public
/// replacement, but it still functions for reading and mutating sidebar
/// favorites. The older Carbon-style functions are imported as `Unmanaged`, so
/// "Copy"/"Create" results are explicitly taken with `takeRetainedValue()` and
/// the global constants use `takeUnretainedValue()`.
@available(macOS, deprecated: 10.11, message: "Intentionally uses the deprecated LSSharedFileList API; no public replacement.")
enum SidebarFavorites {
    /// `kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes`
    private static let resolutionFlags =
        UInt32(kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes)

    /// The integer sentinels `kLSSharedFileListItemLast` (2) and
    /// `kLSSharedFileListItemBeforeFirst` (1) as raw pointers.
    private static let insertLast = UnsafeRawPointer(kLSSharedFileListItemLast.toOpaque())
    private static let insertFirst = UnsafeRawPointer(kLSSharedFileListItemBeforeFirst.toOpaque())

    /// Opens the favorites list or throws `couldNotOpenList`.
    private static func openList() throws -> LSSharedFileList {
        guard let list = LSSharedFileListCreate(
            kCFAllocatorDefault,
            kLSSharedFileListFavoriteItems.takeUnretainedValue(),
            nil
        )?.takeRetainedValue() else {
            throw SidebarError.couldNotOpenList
        }
        return list
    }

    /// Parses and validates a user-supplied URI string.
    /// Rejects empty, malformed, and scheme-less input before touching the API.
    static func parseURL(_ string: String) throws -> URL {
        guard let url = URL(string: string), url.scheme != nil else {
            throw SidebarError.invalidURL(string)
        }
        return url
    }

    /// True when `name` is the case-insensitive "remove everything" sentinel.
    static func isRemoveAll(_ name: String) -> Bool {
        return name.lowercased() == "all"
    }

    /// Returns every favorite in the list, preserving order.
    static func list() throws -> [SidebarItem] {
        let list = try openList()
        guard let items = try snapshot(of: list) else {
            return []
        }

        return items.map { item in
            let name = LSSharedFileListItemCopyDisplayName(item).takeRetainedValue() as String
            let resolved = LSSharedFileListItemCopyResolvedURL(item, resolutionFlags, nil)?.takeRetainedValue()
            return SidebarItem(name: name, url: resolved as URL?)
        }
    }

    /// Appends a favorite to the end of the list.
    static func add(name: String, url: URL) throws {
        let list = try openList()
        _ = insertItemURL(list, insertLast, name as CFString, nil, url as CFURL, nil, nil)?.takeRetainedValue()
    }

    /// Inserts a favorite at the start of the list.
    static func insert(name: String, url: URL) throws {
        let list = try openList()
        _ = insertItemURL(list, insertFirst, name as CFString, nil, url as CFURL, nil, nil)?.takeRetainedValue()
    }

    /// Removes the first favorite whose display name matches `name`.
    /// Throws `notFound` when no item matches.
    static func remove(name: String) throws {
        let list = try openList()
        guard let items = try snapshot(of: list) else {
            throw SidebarError.notFound(name: name)
        }

        for item in items {
            let displayName = LSSharedFileListItemCopyDisplayName(item).takeRetainedValue() as String
            if displayName == name {
                LSSharedFileListItemRemove(list, item)
                return
            }
        }
        throw SidebarError.notFound(name: name)
    }

    /// Removes every favorite from the list.
    static func removeAll() throws {
        let list = try openList()
        LSSharedFileListRemoveAllItems(list)
    }

    /// The property Finder reads to override a favorite's sidebar glyph. Its
    /// value is a four-character OSType code (set) or `kCFNull` (cleared).
    static let overrideIconKey = "com.apple.LSSharedFileList.OverrideIcon.OSType"

    /// Sets (or, with `code == nil`, clears) the sidebar glyph override for the
    /// favorite whose display name matches `name`. Throws `notFound` when no
    /// item matches.
    static func setOverrideIcon(code: String?, forName name: String) throws {
        let list = try openList()
        guard let items = try snapshot(of: list) else {
            throw SidebarError.notFound(name: name)
        }

        for item in items {
            let displayName = LSSharedFileListItemCopyDisplayName(item).takeRetainedValue() as String
            if displayName == name {
                let value: CFTypeRef
                if let code = code {
                    value = code as NSString
                } else {
                    value = kCFNull!
                }
                let status = LSSharedFileListItemSetProperty(item, overrideIconKey as CFString, value)
                guard status == noErr else {
                    throw SidebarError.setShapeFailed(name: name)
                }
                return
            }
        }
        throw SidebarError.notFound(name: name)
    }

    /// Snapshot of the list's items, or `nil` if unavailable.
    private static func snapshot(of list: LSSharedFileList) throws -> [LSSharedFileListItem]? {
        var seed: UInt32 = 0
        guard let snapshot = LSSharedFileListCopySnapshot(list, &seed)?.takeRetainedValue() else {
            return nil
        }
        return snapshot as? [LSSharedFileListItem]
    }
}

/// Calls `LSSharedFileListInsertItemURL` with a raw-pointer item argument.
///
/// The Clang importer types `insertAfterThisItem` as an ARC-managed
/// `LSSharedFileListItem`, but `kLSSharedFileListItemLast` and
/// `kLSSharedFileListItemBeforeFirst` are integer sentinels (2 and 1), not
/// real objects. Passing them through the typed signature makes Swift call
/// `objc_retain` on the fake pointer and crash, so the symbol is redeclared
/// with a raw pointer to sidestep ARC.
@_silgen_name("LSSharedFileListInsertItemURL")
private func insertItemURL(
    _ inList: LSSharedFileList,
    _ insertAfterThisItem: UnsafeRawPointer,
    _ inDisplayName: CFString?,
    _ inIconRef: UnsafeRawPointer?,
    _ inURL: CFURL,
    _ inPropertiesToSet: CFDictionary?,
    _ inPropertiesToClear: CFArray?
) -> Unmanaged<LSSharedFileListItem>?
