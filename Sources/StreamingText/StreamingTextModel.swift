import Observation
import SwiftUI

/// Observable driver for ``StreamingTextView``.
///
/// Feed it chunks with ``append(_:)`` or hand it a whole `AsyncSequence` with
/// ``stream(_:)``; it reveals the text at a smooth, adaptive pace.
@MainActor
@Observable
public final class StreamingTextModel {
    /// The text that is currently visible.
    public private(set) var displayedText: String = ""
    /// `true` while the source is still producing text.
    public private(set) var isReceiving = false
    /// `true` while buffered text is still being revealed.
    public private(set) var isRevealing = false

    /// `true` from the first chunk until the last character is on screen.
    public var isActive: Bool { isReceiving || isRevealing }

    /// Everything received so far, including text that is not visible yet.
    public var fullText: String { buffer.fullText }

    public var pacing: StreamingPacing {
        get { buffer.pacing }
        set { buffer.pacing = newValue }
    }

    @ObservationIgnored private var buffer: StreamingTextBuffer
    @ObservationIgnored private var ticker: Task<Void, Never>?

    public init(pacing: StreamingPacing = .natural) {
        buffer = StreamingTextBuffer(pacing: pacing)
    }

    /// Creates a model that already shows `text`, for example a message loaded from history.
    public convenience init(text: String, pacing: StreamingPacing = .natural) {
        self.init(pacing: pacing)
        buffer.append(text)
        buffer.revealAll()
        displayedText = buffer.revealedText
    }

    // MARK: - Input

    /// Appends a chunk and starts revealing it.
    public func append(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        buffer.append(chunk)
        startTickerIfNeeded()
    }

    /// Marks the start of a response. Called for you by ``stream(_:)``.
    public func beginReceiving() {
        isReceiving = true
    }

    /// Marks the end of a response. The remaining backlog keeps animating.
    public func finishReceiving() {
        isReceiving = false
    }

    /// Consumes an async sequence of chunks, such as an LLM token stream.
    ///
    /// ```swift
    /// try await model.stream(client.streamResponse(for: prompt))
    /// ```
    public func stream<Source: AsyncSequence>(_ source: Source) async throws
        where Source.Element == String
    {
        beginReceiving()
        defer { finishReceiving() }
        for try await chunk in source {
            try Task.checkCancellation()
            append(chunk)
        }
    }

    /// Shows all buffered text immediately, for example when the user taps "Skip".
    public func revealAll() {
        buffer.revealAll()
        displayedText = buffer.revealedText
        stopTicker()
    }

    /// Clears everything so the model can be reused for a new response.
    public func reset() {
        stopTicker()
        buffer.reset()
        displayedText = ""
        isReceiving = false
    }

    // MARK: - Animation

    private func startTickerIfNeeded() {
        guard ticker == nil else { return }
        isRevealing = true
        ticker = Task { [weak self] in
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16), clock: clock)
                let now = clock.now
                let elapsed = (now - last).timeInterval
                last = now
                guard let self, self.tick(elapsed) else { return }
            }
        }
    }

    /// Reveals what is due. Returns `false` when there is nothing left to reveal.
    private func tick(_ elapsed: Double) -> Bool {
        if buffer.advance(by: elapsed) > 0 {
            displayedText = buffer.revealedText
        }
        guard buffer.hasBacklog else {
            ticker = nil
            isRevealing = false
            return false
        }
        return true
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
        isRevealing = false
    }
}

extension Duration {
    var timeInterval: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
