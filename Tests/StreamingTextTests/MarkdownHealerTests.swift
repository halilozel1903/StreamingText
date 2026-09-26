import Testing
@testable import StreamingText

@Suite("MarkdownHealer")
struct MarkdownHealerTests {
    @Test(arguments: [
        ("Plain text", "Plain text"),
        ("This is **bold**", "This is **bold**"),
        ("This is **impor", "This is **impor**"),
        ("This is *ital", "This is *ital*"),
        ("Use `let x", "Use `let x`"),
        ("Old ~~price", "Old ~~price~~"),
        ("**bold and *both", "**bold and *both***"),
    ])
    func closesOpenMarkers(input: String, expected: String) {
        #expect(MarkdownHealer.heal(input) == expected)
    }

    @Test(arguments: [
        ("Hello **", "Hello "),
        ("Hello *", "Hello "),
        ("Hello `", "Hello "),
        ("**bold*", "**bold**"),
    ])
    func dropsMarkersWithoutContent(input: String, expected: String) {
        #expect(MarkdownHealer.heal(input) == expected)
    }

    @Test func ignoresMarkersInsideCode() {
        #expect(MarkdownHealer.heal("`a * b") == "`a * b`")
    }

    @Test func ignoresListBulletsAndArithmetic() {
        #expect(MarkdownHealer.heal("* item") == "* item")
        #expect(MarkdownHealer.heal("2 * 3 * 4") == "2 * 3 * 4")
    }

    @Test func respectsEscapes() {
        #expect(MarkdownHealer.heal(#"Price \*50"#) == #"Price \*50"#)
    }

    @Test func trimsWhitespaceBeforeClosing() {
        #expect(MarkdownHealer.heal("**bold ") == "**bold**")
    }

    @Test func attributedStringHasNoRawAsterisks() {
        let attributed = MarkdownHealer.attributedString(from: "Hello **wor")
        #expect(String(attributed.characters) == "Hello wor")
    }
}
