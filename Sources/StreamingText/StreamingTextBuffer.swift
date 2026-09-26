import Foundation

/// A pure value type that holds streamed text and decides how much of it is visible.
///
/// It works on `Character`s (extended grapheme clusters), so emoji, flags and
/// combining marks are never split in half.
public struct StreamingTextBuffer: Sendable {
    public var pacing: StreamingPacing

    /// Everything received so far.
    public private(set) var fullText: String = ""
    /// The part of ``fullText`` that should be on screen.
    public private(set) var revealedText: String = ""

    private var characters: [Character] = []
    private var revealedCount = 0
    private var carry: Double = 0

    public init(pacing: StreamingPacing = .natural) {
        self.pacing = pacing
    }

    /// Number of received characters that are not visible yet.
    public var backlog: Int { characters.count - revealedCount }

    public var hasBacklog: Bool { backlog > 0 }

    /// Appends a chunk from the source, for example a token delta from an LLM.
    public mutating func append(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        // Re-segment the boundary: a chunk may start with a combining mark or
        // the second half of an emoji sequence that belongs to the previous one.
        let tailStart = max(revealedCount, characters.count - 1)
        let tail = String(characters[tailStart...]) + chunk
        characters.removeSubrange(tailStart...)
        characters.append(contentsOf: tail)
        fullText += chunk
    }

    /// Moves time forward by `seconds` and reveals the characters due by then.
    /// - Returns: The number of characters revealed.
    @discardableResult
    public mutating func advance(by seconds: Double) -> Int {
        let backlog = backlog
        guard backlog > 0, seconds > 0 else { return 0 }
        let rate = pacing.rate(backlog: backlog)
        let count: Int
        if rate.isInfinite {
            count = backlog
            carry = 0
        } else {
            let exact = carry + rate * seconds
            let whole = min(backlog, Int(exact))
            carry = whole == backlog ? 0 : exact - Double(whole)
            count = whole
        }
        reveal(count)
        return count
    }

    /// Reveals everything immediately.
    public mutating func revealAll() {
        reveal(backlog)
        carry = 0
    }

    /// Clears all text.
    public mutating func reset() {
        fullText = ""
        revealedText = ""
        characters = []
        revealedCount = 0
        carry = 0
    }

    private mutating func reveal(_ count: Int) {
        guard count > 0 else { return }
        let end = revealedCount + count
        revealedText.append(contentsOf: characters[revealedCount..<end])
        revealedCount = end
    }
}
