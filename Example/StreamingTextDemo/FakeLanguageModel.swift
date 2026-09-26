import Foundation

/// Simulates an LLM that streams tokens with irregular network timing.
/// Swap it for your real client (OpenAI, Anthropic, Foundation Models, …).
enum FakeLanguageModel {
    static func stream(answering prompt: String) -> AsyncThrowingStream<String, Error> {
        let answer = response(for: prompt)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Time to first token.
                    try await Task.sleep(for: .milliseconds(Int.random(in: 300...700)))
                    for token in tokenize(answer) {
                        try Task.checkCancellation()
                        continuation.yield(token)
                        // Bursty delivery: sometimes a pause, sometimes a flood.
                        let delay = Int.random(in: 0...10) == 0 ? Int.random(in: 150...400) : Int.random(in: 5...40)
                        try await Task.sleep(for: .milliseconds(delay))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Splits text into word-ish tokens, the way LLM deltas usually arrive.
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == " " || character == "\n" || current.count >= 6 {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func response(for prompt: String) -> String {
        """
        Great question about *\(prompt)*! Here is what **StreamingText** does for you:

        • Reveals tokens at a **steady, human rhythm** instead of jumping in bursts.
        • Speeds up automatically when the model outpaces the typing, so it never lags.
        • Heals half-streamed Markdown, so you never see raw `**` flicker on screen.
        • Keeps emoji like 👩‍💻 and 🇹🇷 intact while typing.

        Tap the ⏹ button at any time to ~~wait~~ reveal the rest instantly.
        """
    }
}
