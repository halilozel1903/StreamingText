import StreamingText
import SwiftUI

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
enum ScreenshotScene: String {
    case chat
    case streaming

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }

    @MainActor
    func messages() -> [ChatMessage] {
        let question = "How do I share state between SwiftUI views?"
        let answer = """
        Use **@State** for values a view owns, and pass a **Binding** to children that edit them. \
        For shared models, mark the class `@Observable` and put it in the *environment*:

        • `.environment(model)` at the root
        • `@Environment(Model.self)` where you need it

        No more ~~ObservableObject~~ boilerplate. 🎉
        """
        switch self {
        case .chat:
            return [
                ChatMessage(role: .user, model: StreamingTextModel(text: question)),
                ChatMessage(role: .assistant, model: StreamingTextModel(text: answer)),
            ]
        case .streaming:
            // Stop mid-word inside bold text to show Markdown healing and the caret.
            let cut = answer.range(of: "shared mo")!.upperBound
            let reply = StreamingTextModel(pacing: .instant)
            reply.beginReceiving()
            reply.append(String(answer[..<cut]).replacingOccurrences(of: "For shared mo", with: "For **shared mo"))
            return [
                ChatMessage(role: .user, model: StreamingTextModel(text: question)),
                ChatMessage(role: .assistant, model: reply),
            ]
        }
    }
}
