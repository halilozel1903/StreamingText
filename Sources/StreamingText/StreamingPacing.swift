import Foundation

/// Controls how fast buffered text is revealed.
///
/// Text is revealed at `charactersPerSecond`, but when the backlog grows
/// (the model is producing faster than we type), the speed rises so the
/// backlog drains in about `catchUpDuration` seconds. The result is a steady,
/// human-looking typing rhythm that never lags far behind the network.
public struct StreamingPacing: Sendable, Hashable {
    /// Base typing speed.
    public var charactersPerSecond: Double
    /// Upper bound, in seconds, for how far the display may lag behind the source.
    public var catchUpDuration: Double

    public init(charactersPerSecond: Double, catchUpDuration: Double) {
        self.charactersPerSecond = max(0, charactersPerSecond)
        self.catchUpDuration = max(0, catchUpDuration)
    }

    /// Relaxed chat rhythm, about 45 characters per second.
    public static let natural = StreamingPacing(charactersPerSecond: 45, catchUpDuration: 1.5)
    /// Snappy, about 120 characters per second.
    public static let fast = StreamingPacing(charactersPerSecond: 120, catchUpDuration: 0.6)
    /// No animation: text appears as soon as it arrives.
    public static let instant = StreamingPacing(charactersPerSecond: .infinity, catchUpDuration: 0)

    /// Characters per second to use for a given backlog.
    func rate(backlog: Int) -> Double {
        guard backlog > 0 else { return 0 }
        guard catchUpDuration > 0 else { return .infinity }
        return max(charactersPerSecond, Double(backlog) / catchUpDuration)
    }
}
