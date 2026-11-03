import SwiftUI

struct StatePickerBar: View {
    @Binding var selection: JourneyState
    @Environment(\.copy) private var copy

    var body: some View {
        Menu {
            Picker(copy.momentOfDay, selection: $selection) {
                ForEach(JourneyState.allCases) { state in
                    Text(copy.state(state).title).tag(state)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Nova.orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: Nova.orange, radius: 6)
                Text(copy.state(selection).title)
                    .font(Typeface.body.weight(.medium))
                    .foregroundStyle(Nova.bone)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Nova.bone.opacity(0.6))
            }
            .padding(.horizontal, 22)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .background(Capsule().fill(Nova.surface.opacity(0.85)))
            )
            .overlay(Capsule().strokeBorder(Nova.hairline, lineWidth: 1))
        }
        .accessibilityLabel("\(copy.momentOfDay): \(copy.state(selection).title)")
    }
}
