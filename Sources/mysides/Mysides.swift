import ArgumentParser
import Foundation

/// Single source of truth for the version string.
let mysidesVersion = "2.0.0"

/// Maps a `SidebarError` to a process exit code.
private extension SidebarError {
    var exitCode: Int32 {
        switch self {
        case .couldNotOpenList:
            return 2
        case .invalidURL, .notFound:
            return 1
        }
    }
}

/// Writes `error` to stderr and returns the matching exit code.
private func report(_ error: SidebarError) -> ExitCode {
    let message = "mysides: \(error.description)\n"
    FileHandle.standardError.write(Data(message.utf8))
    return ExitCode(error.exitCode)
}

/// A command whose body throws only `SidebarError`s from the wrapper.
private protocol SidebarCommand: ParsableCommand {}

extension SidebarCommand {
    /// Runs `body`, converting wrapper errors into messages + exit codes.
    func runSidebar(_ body: () throws -> Void) -> ExitCode {
        do {
            try body()
            return ExitCode.success
        } catch let error as SidebarError {
            return report(error)
        } catch {
            // The wrapper only throws `SidebarError`; treat anything else as a bug.
            FileHandle.standardError.write(Data("mysides: unexpected failure\n".utf8))
            return ExitCode.failure
        }
    }
}

@main
struct Mysides: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mysides",
        abstract: "Modify the Finder sidebar favorites list.",
        version: mysidesVersion,
        subcommands: [
            List.self,
            Add.self,
            Insert.self,
            Remove.self,
            Version.self
        ]
    )
}

struct List: SidebarCommand {
    static let configuration = CommandConfiguration(
        abstract: "List sidebar favorites."
    )

    @available(macOS, deprecated: 10.11, message: "Intentionally uses the deprecated LSSharedFileList API.")
    func run() throws {
        throw runSidebar {
            for item in try SidebarFavorites.list() {
                if let url = item.url {
                    print("\(item.name) -> \(url.absoluteString)")
                } else {
                    print("\(item.name) -> NOTFOUND")
                }
            }
        }
    }
}

struct Add: SidebarCommand {
    static let configuration = CommandConfiguration(
        abstract: "Append a favorite to the end of the sidebar."
    )

    @Argument(help: "Display name for the new favorite.")
    var name: String

    @Argument(help: "File URL of the favorite (e.g. file:///path/to/folder).")
    var uri: String

    @available(macOS, deprecated: 10.11, message: "Intentionally uses the deprecated LSSharedFileList API.")
    func run() throws {
        throw runSidebar {
            let url = try SidebarFavorites.parseURL(uri)
            try SidebarFavorites.add(name: name, url: url)
            print("Added sidebar item with name: \(name)")
        }
    }
}

struct Insert: SidebarCommand {
    static let configuration = CommandConfiguration(
        abstract: "Insert a favorite at the start of the sidebar."
    )

    @Argument(help: "Display name for the new favorite.")
    var name: String

    @Argument(help: "File URL of the favorite (e.g. file:///path/to/folder).")
    var uri: String

    @available(macOS, deprecated: 10.11, message: "Intentionally uses the deprecated LSSharedFileList API.")
    func run() throws {
        throw runSidebar {
            let url = try SidebarFavorites.parseURL(uri)
            try SidebarFavorites.insert(name: name, url: url)
            print("Inserted sidebar item at beginning of list with name: \(name)")
        }
    }
}

struct Remove: SidebarCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove a sidebar favorite by name (or 'all' to remove every favorite)."
    )

    @Argument(help: "Display name of the favorite to remove, or 'all'.")
    var name: String

    @available(macOS, deprecated: 10.11, message: "Intentionally uses the deprecated LSSharedFileList API.")
    func run() throws {
        throw runSidebar {
            if SidebarFavorites.isRemoveAll(name) {
                try SidebarFavorites.removeAll()
                print("Removed all sidebar items.")
            } else {
                try SidebarFavorites.remove(name: name)
                print("Removed sidebar item with name: \(name)")
            }
        }
    }
}

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the version."
    )

    func run() {
        print(mysidesVersion)
    }
}
