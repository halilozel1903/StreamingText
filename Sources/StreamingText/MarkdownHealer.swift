import Foundation

/// Makes half-streamed Markdown render cleanly.
///
/// While a response streams in, emphasis and code spans are often open:
/// `"This is **impor"`. Rendered as-is, the user sees raw asterisks flicker.
/// `MarkdownHealer` closes open inline markers and drops a marker that has no
/// content yet, so every intermediate frame renders as formatted text.
///
/// Supported inline markers: `**strong**`, `*emphasis*`, `~~strikethrough~~`
/// and `` `code` ``. Backslash escapes are respected.
public enum MarkdownHealer {
    /// Returns `text` with open inline markers closed.
    public static func heal(_ text: String) -> String {
        let chars = Array(text)
        var stack: [(marker: String, contentStart: Int)] = []
        var index = 0

        func isWhitespace(_ position: Int) -> Bool {
            guard chars.indices.contains(position) else { return true }
            return chars[position].isWhitespace
        }

        func toggle(_ marker: String, at position: Int) {
            let length = marker.count
            if let open = stack.lastIndex(where: { $0.marker == marker }), !isWhitespace(position - 1) {
                // A closing marker must follow a non-space character.
                stack.removeSubrange(open...)
            } else if position + length >= chars.count || !isWhitespace(position + length) {
                // An opening marker must be followed by a non-space character,
                // or sit at the very end (it may be completed by the next chunk).
                stack.append((marker, position + length))
            }
            index = position + length
        }

        while index < chars.count {
            let char = chars[index]

            if char == "\\" {
                index += 2
                continue
            }

            if char == "`" {
                if stack.last?.marker == "`" {
                    stack.removeLast()
                } else {
                    stack.append(("`", index + 1))
                }
                index += 1
                continue
            }

            // Inside a code span everything is literal.
            if stack.last?.marker == "`" {
                index += 1
                continue
            }

            if char == "*", index + 1 < chars.count, chars[index + 1] == "*" {
                toggle("**", at: index)
            } else if char == "~", index + 1 < chars.count, chars[index + 1] == "~" {
                toggle("~~", at: index)
            } else if char == "*" {
                toggle("*", at: index)
            } else {
                index += 1
            }
        }

        guard !stack.isEmpty else { return text }

        var healed = chars
        // Drop markers that have nothing after them yet ("Hello **").
        while let last = stack.last, last.contentStart >= healed.count {
            healed.removeSubrange((last.contentStart - last.marker.count)..<last.contentStart)
            stack.removeLast()
        }
        // Drop trailing whitespace before the closers so "**bold **" doesn't break.
        var result = String(healed)
        if !stack.isEmpty {
            while result.last?.isWhitespace == true { result.removeLast() }
            result += stack.reversed().map(\.marker).joined()
        }
        return result
    }

    /// Parses healed inline Markdown into an `AttributedString`, falling back to plain text.
    public static func attributedString(from text: String) -> AttributedString {
        let healed = heal(text)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: healed, options: options)) ?? AttributedString(text)
    }
}
