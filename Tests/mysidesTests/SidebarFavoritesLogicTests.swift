import XCTest
@testable import mysides

final class SidebarFavoritesLogicTests: XCTestCase {

    // MARK: - URL validation

    func testParseURLRejectsEmptyString() {
        XCTAssertThrowsError(try SidebarFavorites.parseURL("")) { error in
            XCTAssertEqual(error as? SidebarError, .invalidURL(""))
        }
    }

    func testParseURLRejectsMalformedString() {
        XCTAssertThrowsError(try SidebarFavorites.parseURL("ht!tp://::not a url")) { error in
            guard case .invalidURL = error as? SidebarError else {
                return XCTFail("Expected invalidURL, got \(error)")
            }
        }
    }

    func testParseURLRejectsSchemeLessPath() {
        XCTAssertThrowsError(try SidebarFavorites.parseURL("/tmp")) { error in
            guard case .invalidURL = error as? SidebarError else {
                return XCTFail("Expected invalidURL, got \(error)")
            }
        }
    }

    func testParseURLAcceptsFileURL() throws {
        let url = try SidebarFavorites.parseURL("file:///tmp")
        XCTAssertEqual(url.absoluteString, "file:///tmp")
    }

    func testParseURLAcceptsHTTPSURL() throws {
        let url = try SidebarFavorites.parseURL("https://example.com/a")
        XCTAssertEqual(url.absoluteString, "https://example.com/a")
    }

    // MARK: - remove-all matching

    func testIsRemoveAllMatchesLowercase() {
        XCTAssertTrue(SidebarFavorites.isRemoveAll("all"))
    }

    func testIsRemoveAllMatchesUppercase() {
        XCTAssertTrue(SidebarFavorites.isRemoveAll("ALL"))
    }

    func testIsRemoveAllMatchesMixedCase() {
        XCTAssertTrue(SidebarFavorites.isRemoveAll("AlL"))
    }

    func testIsRemoveAllRejectsOtherNames() {
        XCTAssertFalse(SidebarFavorites.isRemoveAll("Documents"))
        XCTAssertFalse(SidebarFavorites.isRemoveAll("all-other"))
        XCTAssertFalse(SidebarFavorites.isRemoveAll(""))
    }

    // MARK: - error descriptions

    func testErrorDescriptionsAreStable() {
        XCTAssertEqual(
            SidebarError.couldNotOpenList.description,
            "Unable to create sidebar list, LSSharedFileListCreate() fails."
        )
        XCTAssertEqual(
            SidebarError.invalidURL("x").description,
            "Invalid URI: x"
        )
        XCTAssertEqual(
            SidebarError.notFound(name: "Foo").description,
            "Could not find sidebar item with display name: Foo"
        )
        XCTAssertEqual(
            SidebarError.invalidShape("bogus").description,
            "Unknown glyph: bogus"
        )
        XCTAssertEqual(
            SidebarError.setShapeFailed(name: "Foo").description,
            "Could not set glyph for sidebar item: Foo"
        )
        XCTAssertEqual(
            SidebarError.helperFailed("boom").description,
            "Icon helper failed: boom"
        )
    }

    // MARK: - SidebarItem equatable

    func testSidebarItemEquatable() {
        XCTAssertEqual(SidebarItem(name: "A", url: nil), SidebarItem(name: "A", url: nil))
        XCTAssertEqual(
            SidebarItem(name: "A", url: URL(string: "file:///tmp")),
            SidebarItem(name: "A", url: URL(string: "file:///tmp"))
        )
        XCTAssertNotEqual(
            SidebarItem(name: "A", url: nil),
            SidebarItem(name: "B", url: nil)
        )
    }

    // MARK: - sidebar glyph presets

    func testSidebarGlyphPresetLookup() {
        XCTAssertNotNil(SidebarGlyph.preset(named: "star"))
        XCTAssertEqual(SidebarGlyph.preset(named: "star")?.symbol, "star.fill")
        XCTAssertNil(SidebarGlyph.preset(named: "bogus"))
    }

    func testSidebarGlyphCodesAreFourCharacters() {
        for preset in SidebarGlyph.presets {
            XCTAssertEqual(preset.code.count, 4, "\(preset.name) code must be 4 chars")
        }
    }
}
