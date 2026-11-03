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
            HStack {
                Text(selection.title)
                    .font(Typeface.body)
                    .foregroundStyle(Ink.sumi)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Ink.inkSoft)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Ink.washiDeep.opacity(0.85))
                    .shadow(color: Ink.sumi.opacity(0.08), radius: 10, y: 4)
            )
        }
        .accessibilityLabel("Moment of the day: \(selection.title)")
    }
}
