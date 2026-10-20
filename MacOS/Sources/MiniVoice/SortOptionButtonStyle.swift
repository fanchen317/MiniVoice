import SwiftUI

struct SortOptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    private struct Row: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(hovered || configuration.isPressed ? Color.white : Color.primary)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hovered || configuration.isPressed ? Color.accentColor : Color.clear)
                }
                .onHover { hovered = $0 }
        }
    }
}
