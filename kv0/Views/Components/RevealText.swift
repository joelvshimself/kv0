import SwiftUI

/// Nova's headline treatment: characters light up one after another.
/// Recreate the view (e.g. with `.id`) to replay the reveal.
struct RevealText: View {
    let text: String
    @State private var shown: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ text: String, revealOnAppear: Bool = true) {
        self.text = text
        _shown = State(initialValue: revealOnAppear ? 0 : text.count)
    }

    var body: some View {
        Array(text).enumerated().reduce(Text("")) { line, item in
            line + Text(String(item.element))
                .foregroundStyle(item.offset < shown ? Nova.bone : Nova.bone.opacity(0.08))
        }
        .accessibilityLabel(text)
        .task {
            guard shown < text.count else { return }
            if reduceMotion {
                shown = text.count
                return
            }
            for index in shown...text.count {
                shown = index
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
}
