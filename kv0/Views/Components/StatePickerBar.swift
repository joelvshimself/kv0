import SwiftUI

struct StatePickerBar: View {
    @Binding var selection: JourneyState

    var body: some View {
        Menu {
            Picker("Moment of the day", selection: $selection) {
                ForEach(JourneyState.allCases) { state in
                    Text(state.title).tag(state)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Nova.orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: Nova.orange, radius: 6)
                Text(selection.title)
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
        .accessibilityLabel("Moment of the day: \(selection.title)")
    }
}
