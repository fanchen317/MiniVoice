import SwiftUI

struct TranslationDisplayToggle: View {
    let lines: [LyricLine]
    @AppStorage("MiniVoice.showLyricsTranslation") private var showTranslation = true

    var body: some View {
        if lines.contains(where: { $0.translation != nil }) {
            Button { showTranslation.toggle() } label: {
                Text("译文").font(.caption.weight(.medium))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .foregroundStyle(showTranslation ? TimedLyricText.activeColor : Color.secondary)
                    .background(showTranslation ? TimedLyricText.activeColor.opacity(0.12) : Color.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain).help(showTranslation ? "隐藏译文" : "显示译文")
                .accessibilityLabel(showTranslation ? "隐藏译文" : "显示译文")
        }
    }
}
