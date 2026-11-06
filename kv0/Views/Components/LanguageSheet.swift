import SwiftUI

struct LanguageSheet: View {
    @Binding var language: AppLanguage
    var viewModel: DayViewModel
    @Environment(\.copy) private var copy
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                section(title: copy.language) {
                    VStack(spacing: 10) {
                        ForEach(AppLanguage.allCases) { option in
                            languageRow(option)
                        }
                    }
                }

                section(title: "Health") {
                    healthBlock
                }

                section(title: "Alerts") {
                    notificationsBlock
                }

                if viewModel.mode == .manual {
                    Button(copy.liveMode) {
                        viewModel.returnToLive()
                        dismiss()
                    }
                    .font(Typeface.body.weight(.medium))
                    .foregroundStyle(Nova.ember)
                }
            }
            .padding(Space.margin)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Nova.void.opacity(0.92))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(copy.settings)
                .font(Typeface.sentence)
                .tracking(Typeface.tracking(for: 30))
                .foregroundStyle(Nova.bone)
            Spacer()
            Button(copy.done) { dismiss() }
                .font(Typeface.body.weight(.medium))
                .foregroundStyle(Nova.ember)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Typeface.caption)
                .foregroundStyle(Nova.muted)
            content()
        }
    }

    private func languageRow(_ option: AppLanguage) -> some View {
        Button {
            language = option
            viewModel.updateLanguage(option)
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

    @ViewBuilder
    private var healthBlock: some View {
        if viewModel.isHealthConnected {
            statusPill(copy.healthConnected)
        } else if viewModel.healthStatus == .unavailable {
            statusPill(copy.healthUnavailable)
        } else {
            Button {
                Task { await viewModel.connectHealth() }
            } label: {
                actionLabel(copy.connectHealth, systemImage: "heart.text.square")
            }
            .buttonStyle(.plain)
        }

        if viewModel.prediction.sleepDebtMinutes > 0 {
            Text("\(copy.sleepDebt): \(copy.duration(viewModel.prediction.sleepDebtMinutes))")
                .font(Typeface.caption)
                .foregroundStyle(Nova.bone.opacity(0.65))
        }
    }

    @ViewBuilder
    private var notificationsBlock: some View {
        if viewModel.notificationsAllowed {
            statusPill(copy.notificationsOn)
        } else {
            Button {
                Task { await viewModel.enableNotifications() }
            } label: {
                actionLabel(copy.enableNotifications, systemImage: "bell")
            }
            .buttonStyle(.plain)
        }
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(Typeface.body)
            .foregroundStyle(Nova.bone.opacity(0.85))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 52)
            .background(Capsule().fill(Color.white.opacity(0.05)))
            .overlay(Capsule().strokeBorder(Nova.hairline, lineWidth: 1))
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Nova.orange)
            Text(title)
                .font(Typeface.body.weight(.medium))
                .foregroundStyle(Nova.bone)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(Nova.orange.opacity(0.35), lineWidth: 1))
    }
}
