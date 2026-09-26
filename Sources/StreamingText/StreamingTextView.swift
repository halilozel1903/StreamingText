import SwiftUI

/// Displays the text of a ``StreamingTextModel`` with inline Markdown and a blinking caret.
///
/// ```swift
/// @State private var reply = StreamingTextModel()
///
/// var body: some View {
///     StreamingTextView(reply)
///         .task { try? await reply.stream(client.stream(prompt)) }
/// }
/// ```
public struct StreamingTextView: View {
    private let model: StreamingTextModel
    private let rendersMarkdown: Bool
    private let caret: StreamingCaret?

    @State private var caretVisible = true

    /// - Parameters:
    ///   - model: The model that owns the text.
    ///   - rendersMarkdown: Renders inline Markdown (bold, italic, code, links, strikethrough).
    ///   - caret: The caret shown while text is streaming, or `nil` for none.
    public init(
        _ model: StreamingTextModel,
        rendersMarkdown: Bool = true,
        caret: StreamingCaret? = .block
    ) {
        self.model = model
        self.rendersMarkdown = rendersMarkdown
        self.caret = caret
    }

    private var showsCaret: Bool { caret != nil && model.isActive }

    public var body: some View {
        Text(content)
            .contentTransition(.identity)
            .accessibilityLabel(Text(model.fullText))
            .task(id: showsCaret) {
                caretVisible = true
                guard showsCaret else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(530))
                    caretVisible.toggle()
                }
            }
    }

    private var content: AttributedString {
        var text = rendersMarkdown
            ? MarkdownHealer.attributedString(from: model.displayedText)
            : AttributedString(model.displayedText)
        if showsCaret, let caret {
            var caretText = AttributedString(caret.symbol)
            caretText[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] =
                caretVisible ? caret.color : .clear
            text.append(caretText)
        }
        return text
    }
}

/// The caret drawn at the end of streaming text.
public struct StreamingCaret: Sendable, Hashable {
    public var symbol: String
    public var color: Color

    public init(symbol: String, color: Color = .accentColor) {
        self.symbol = symbol
        self.color = color
    }

    /// A block caret: `▍`
    public static let block = StreamingCaret(symbol: "\u{258D}")
    /// A dot, popular in chat apps: `●`
    public static let dot = StreamingCaret(symbol: " \u{25CF}")
    /// A thin bar: `|`
    public static let bar = StreamingCaret(symbol: "|")
}
