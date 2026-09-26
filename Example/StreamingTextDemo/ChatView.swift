import StreamingText
import SwiftUI

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    let model: StreamingTextModel
}

struct ChatView: View {
    @State private var messages: [ChatMessage] = ScreenshotScene.current?.messages() ?? [
        ChatMessage(role: .assistant, model: StreamingTextModel(
            text: "Hi! Ask me anything and watch the answer **stream** in."
        )),
    ]
    @State private var draft = ""
    @State private var speed: Speed = .natural
    @State private var responseTask: Task<Void, Never>?

    enum Speed: String, CaseIterable, Identifiable {
        case natural = "Natural"
        case fast = "Fast"
        case instant = "Instant"

        var id: Self { self }

        var pacing: StreamingPacing {
            switch self {
            case .natural: .natural
            case .fast: .fast
            case .instant: .instant
            }
        }
    }

    private var isResponding: Bool {
        messages.last.map { $0.role == .assistant && $0.model.isActive } ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: messages.last?.model.displayedText) {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .navigationTitle("StreamingText")
            .toolbar {
                ToolbarItem {
                    Picker("Speed", selection: $speed) {
                        ForEach(Speed.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            if isResponding {
                Button {
                    stop()
                } label: {
                    Image(systemName: "stop.circle.fill").font(.title)
                }
                .accessibilityLabel("Stop")
            } else {
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send")
            }
        }
        .padding()
        .background(.bar)
    }

    private func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        draft = ""
        messages.append(ChatMessage(role: .user, model: StreamingTextModel(text: prompt)))

        let reply = StreamingTextModel(pacing: speed.pacing)
        messages.append(ChatMessage(role: .assistant, model: reply))
        responseTask = Task {
            try? await reply.stream(FakeLanguageModel.stream(answering: prompt))
        }
    }

    private func stop() {
        responseTask?.cancel()
        messages.last?.model.revealAll()
    }
}

struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                StreamingTextView(message.model, caret: nil)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        case .assistant:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                    .padding(.top, 2)
                StreamingTextView(message.model, caret: .dot)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }
}

#Preview {
    ChatView()
}
