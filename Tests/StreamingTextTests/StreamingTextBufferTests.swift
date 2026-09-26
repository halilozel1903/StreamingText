import Testing
@testable import StreamingText

@Suite("StreamingTextBuffer")
struct StreamingTextBufferTests {
    @Test func revealsAtBaseRate() {
        var buffer = StreamingTextBuffer(pacing: .init(charactersPerSecond: 10, catchUpDuration: 100))
        buffer.append("Hello, world")

        #expect(buffer.advance(by: 0.5) == 5)
        #expect(buffer.revealedText == "Hello")
        #expect(buffer.backlog == 7)
    }

    @Test func carriesFractionsBetweenFrames() {
        var buffer = StreamingTextBuffer(pacing: .init(charactersPerSecond: 10, catchUpDuration: 100))
        buffer.append("abcdef")

        // 0.05 s at 10 cps = half a character per frame.
        buffer.advance(by: 0.05)
        #expect(buffer.revealedText.isEmpty)
        buffer.advance(by: 0.05)
        #expect(buffer.revealedText == "a")
    }

    @Test func speedsUpToDrainLargeBacklog() {
        // 100 characters must be gone within 1 s, even though the base rate is 10 cps.
        var buffer = StreamingTextBuffer(pacing: .init(charactersPerSecond: 10, catchUpDuration: 1))
        buffer.append(String(repeating: "x", count: 100))

        #expect(buffer.advance(by: 0.5) == 50)
    }

    @Test func instantRevealsEverything() {
        var buffer = StreamingTextBuffer(pacing: .instant)
        buffer.append("All at once")
        buffer.advance(by: 0.016)
        #expect(buffer.revealedText == "All at once")
        #expect(!buffer.hasBacklog)
    }

    @Test func neverSplitsEmoji() {
        var buffer = StreamingTextBuffer(pacing: .init(charactersPerSecond: 1, catchUpDuration: 100))
        buffer.append("👩‍👩‍👧‍👦🇹🇷")
        buffer.advance(by: 1)
        #expect(buffer.revealedText == "👩‍👩‍👧‍👦")
        buffer.advance(by: 1)
        #expect(buffer.revealedText == "👩‍👩‍👧‍👦🇹🇷")
    }

    @Test func mergesGraphemesSplitAcrossChunks() {
        var buffer = StreamingTextBuffer(pacing: .instant)
        buffer.append("e")
        buffer.append("\u{301}") // combining acute accent
        buffer.revealAll()
        #expect(buffer.revealedText == "é")
        #expect(buffer.revealedText.count == 1)
    }

    @Test func resetClearsState() {
        var buffer = StreamingTextBuffer()
        buffer.append("Something")
        buffer.revealAll()
        buffer.reset()
        #expect(buffer.fullText.isEmpty)
        #expect(buffer.revealedText.isEmpty)
        #expect(buffer.backlog == 0)
    }
}

@MainActor
@Suite("StreamingTextModel")
struct StreamingTextModelTests {
    @Test func streamsAsyncSequenceToCompletion() async throws {
        let model = StreamingTextModel(pacing: .fast)
        let chunks = AsyncStream<String> { continuation in
            for chunk in ["Hello", ", ", "**world**", "!"] {
                continuation.yield(chunk)
            }
            continuation.finish()
        }

        try await model.stream(chunks)
        #expect(model.fullText == "Hello, **world**!")
        #expect(!model.isReceiving)

        // Let the reveal animation catch up.
        for _ in 0..<100 where model.isRevealing {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(model.displayedText == "Hello, **world**!")
        #expect(!model.isActive)
    }

    @Test func revealAllSkipsAnimation() {
        let model = StreamingTextModel(pacing: .natural)
        model.append("A long answer that would take a while to type out.")
        model.revealAll()
        #expect(model.displayedText == model.fullText)
        #expect(!model.isRevealing)
    }

    @Test func historyInitializerShowsTextImmediately() {
        let model = StreamingTextModel(text: "Loaded from history")
        #expect(model.displayedText == "Loaded from history")
        #expect(!model.isActive)
    }
}
