import SwiftUI

struct LanguageSheet: View {
    @Binding var language: AppLanguage
    @Environment(\.copy) private var copy
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text(copy.language)
                    .font(Typeface.sentence)
                    .tracking(Typeface.tracking(for: 30))
                    .foregroundStyle(Nova.bone)
                Spacer()
                Button(copy.done) { dismiss() }
                    .font(Typeface.body.weight(.medium))
                    .foregroundStyle(Nova.ember)
            }

            VStack(spacing: 10) {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        language = option
                    } label: {
                        HStack {
                            Text(option.displayName)
                                .font(Typeface.body)
                                .foregroundStyle(Nova.bone)
                            Spacer()
                            if option == language {
                                Circle()
                                    .fill(Nova.orange)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: Nova.orange, radius: 6)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                        .background(Capsule().fill(Color.white.opacity(option == language ? 0.08 : 0.03)))
                        .overlay(Capsule().strokeBorder(Nova.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == language ? .isSelected : [])
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Space.margin)
        .padding(.top, 12)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Nova.void.opacity(0.92))
    }
}
