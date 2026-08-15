import XCTest
import ArgumentParser
@testable import mysides

final class ArgumentParsingTests: XCTestCase {

    func testListParsesWithNoArguments() throws {
        _ = try List.parse([])
    }

    func testAddParsesNameAndURI() throws {
        let command = try Add.parse(["MyFolder", "file:///tmp"])
        XCTAssertEqual(command.name, "MyFolder")
        XCTAssertEqual(command.uri, "file:///tmp")
    }

    func testAddRequiresURI() {
        XCTAssertThrowsError(try Add.parse(["MyFolder"]))
    }

    func testAddRequiresNameAndURI() {
        XCTAssertThrowsError(try Add.parse([]))
    }

    func testInsertParsesNameAndURI() throws {
        let command = try Insert.parse(["First", "file:///tmp"])
        XCTAssertEqual(command.name, "First")
        XCTAssertEqual(command.uri, "file:///tmp")
    }

    func testRemoveRequiresName() {
        XCTAssertThrowsError(try Remove.parse([]))
    }

    func testRemoveParsesName() throws {
        let command = try Remove.parse(["MyFolder"])
        XCTAssertEqual(command.name, "MyFolder")
        XCTAssertFalse(SidebarFavorites.isRemoveAll(command.name))
    }

    func testRemoveParsesAllCaseInsensitively() throws {
        for spelling in ["all", "ALL", "AlL"] {
            let command = try Remove.parse([spelling])
            XCTAssertEqual(command.name, spelling)
            XCTAssertTrue(SidebarFavorites.isRemoveAll(command.name))
        }
    }

    func testAddRejectsExtraArguments() {
        XCTAssertThrowsError(try Add.parse(["Name", "file:///tmp", "extra"]))
    }

    func testIconParsesNameAndGlyph() throws {
        let command = try Icon.parse(["MyFolder", "star"])
        XCTAssertEqual(command.name, "MyFolder")
        XCTAssertEqual(command.glyph, "star")
    }

    func testIconRequiresGlyph() {
        XCTAssertThrowsError(try Icon.parse(["MyFolder"]))
    }

    func testIconRequiresNameAndGlyph() {
        XCTAssertThrowsError(try Icon.parse([]))
    }
}
