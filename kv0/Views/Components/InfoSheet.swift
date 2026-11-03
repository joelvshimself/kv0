import SwiftUI

/// The words behind the info button: rest ideas when a break is due, appreciation
/// for the day's work once it's done.
struct InfoSheet: View {
    let text: StateCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(text.suggestionsTitle)
                .font(Typeface.sentence)
                .tracking(Typeface.tracking(for: 30))
                .foregroundStyle(Nova.bone)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(text.suggestions, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Circle()
                            .fill(Nova.orange)
                            .frame(width: 6, height: 6)
                            .shadow(color: Nova.orange, radius: 4)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                        Text(line)
                            .font(Typeface.body)
                            .foregroundStyle(Nova.bone.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Space.margin)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Nova.void.opacity(0.92))
    }
}
