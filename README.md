# mysides

A small macOS command-line tool for modifying the Finder sidebar favorites
("Favorite Items") list.

This is a from-scratch Swift rewrite of the original Objective-C
[`mysides`](https://github.com/mosen/mysides), keeping the same commands and
mental model. It is a Swift Package Manager package (no Xcode project) and uses
[Swift ArgumentParser](https://github.com/apple/swift-argument-parser).

## Requirements

- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`) for `swift build`

## Build & install

```sh
swift build -c release
# the binary is at .build/release/mysides
```

To install into `/usr/local/bin`:

```sh
install -m 0755 .build/release/mysides /usr/local/bin/mysides
```

Or run it directly without installing:

```sh
swift run mysides list
```

## Usage

```
OVERVIEW: Modify the Finder sidebar favorites list.

USAGE: mysides <subcommand>

SUBCOMMANDS:
  list                    List sidebar favorites.
  add                     Append a favorite to the end of the sidebar.
  insert                  Insert a favorite at the start of the sidebar.
  remove                  Remove a sidebar favorite by name (or 'all' to remove
                          every favorite).
  icon                    Set a monochrome sidebar glyph on a favorite.
  version                 Print the version.
```

Examples:

```sh
mysides list
mysides add example file:///Users/Shared/example
mysides insert example file:///Users/Shared/example
mysides remove example
mysides remove all        # remove every favorite
mysides icon example star      # set a star glyph
mysides icon example none      # reset to the default folder glyph
mysides --version
mysides --help
```

`list` prints one favorite per line as `name -> url`, or `name -> NOTFOUND`
when an item's URL can no longer be resolved.

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | Success |
| 1    | Item not found, invalid URI, or unknown glyph |
| 2    | Failed to open the shared file list, set a glyph, or register the icon helper |
| 64   | Usage error (invalid/missing arguments, via ArgumentParser) |

Errors are written to stderr; normal output goes to stdout.

## Notes

`mysides` wraps `LSSharedFileList` with the `kLSSharedFileListFavoriteItems`
list type. Apple deprecated this API in macOS 10.11 and has shipped no public
replacement (the `sfltool` sidebar operations were removed after Sierra), but
the API still functions for reading and mutating sidebar favorites on macOS 13+.

Because the API is deprecated and unsupported, its behavior on modern macOS is
best-effort. The favorites list is keyed by URL: adding a favorite whose URL is
already in the list renames the existing entry instead of creating a duplicate,
and a URL that does not resolve to an existing file or folder is silently
dropped. Distinct, existing URLs each appear as separate favorites. This
behavior comes from the operating system (the API has no public replacement),
not from `mysides` itself.

### Sidebar glyphs

Finder draws sidebar favorites as a flat, single-color silhouette tinted to the
sidebar — color there is impossible (a macOS rule). `mysides icon <name> <glyph>`
instead sets the favorite's *shape* to a monochrome SF Symbol:

- Presets: `folder`, `star`, `heart`, `briefcase`, `hammer`, `tag`, `bookmark`,
  `trash`, `house`, `gearshape`, `pencil`, `photo`, `music`, `doc`, `link`,
  `flag`, `clock`, `calendar`, `envelope`, `cart`.
- `none` resets a favorite back to its default folder glyph.

```sh
mysides icon example star
mysides icon example none
```

The glyph is applied immediately (no Finder restart needed). Under the hood it
sets the favorite's `com.apple.LSSharedFileList.OverrideIcon.OSType` property to
a private four-character code, which Finder resolves to an SF Symbol through a
small helper bundle that `mysides` generates and registers with Launch Services
on first use (at `~/Library/Application Support/mysides/Icons.app`).

Note: a folder that carries its own custom icon (set via Finder's Get Info)
takes precedence and can override the sidebar glyph.

## Tests

Unit tests cover URI validation, the case-insensitive `all` sentinel for
`remove`, error descriptions, and argument parsing:

```sh
swift test
```

Tests require a full Xcode installation (`XCTest` is not shipped with the
Command Line Tools alone).

## Credits

- Original Objective-C tool: [mosen/mysides](https://github.com/mosen/mysides)
- "Portions (l) copyleft 2011 Adam Strzelecki nanoant.com", without whom the
  `LSSharedFileList` API usage would not be documented.
- Swift rewrite of this fork: seakrebel

## License

MIT. See [LICENSE](LICENSE).
