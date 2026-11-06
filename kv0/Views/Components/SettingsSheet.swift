import SwiftUI
import UIKit

struct SettingsSheet: View {
    @Binding var language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.copy) private var copy
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var notifications: NotificationManager
    @AppStorage(NotificationManager.enabledKey) private var remindersOn = true
    @AppStorage(NotificationManager.leadKey) private var leadMinutes = 30

    private var prefs: SettingsCopy { copy.prefs }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                section(prefs.health) { healthCard }
                section(prefs.driving) { drivingCard }
                section(prefs.reminders) { remindersCard }
                section(copy.language) { languageOptions }
                footer
            }
            .padding(Space.margin)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(StarfieldBackground().ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationBackground(Nova.void)
        .preferredColorScheme(.dark)
        .task { await notifications.refreshStatus() }
        .onChange(of: remindersOn) { _, isOn in
            Task {
                if isOn, notifications.status == .notDetermined {
                    await notifications.requestAuthorization()
                }
                await appState.rescheduleReminder()
            }
        }
        .onChange(of: leadMinutes) { _, _ in
            Task { await appState.rescheduleReminder() }
        }
    }

    // MARK: Layout

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

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(Typeface.caption.weight(.medium))
                .tracking(1.2)
                .foregroundStyle(Nova.muted)
                .padding(.leading, 4)
            content()
        }
    }

    // MARK: Apple Health

    private var healthCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    IconBadge(systemImage: "heart.fill")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(prefs.health)
                            .font(Typeface.body.weight(.medium))
                            .foregroundStyle(Nova.bone)
                        HStack(spacing: 6) {
                            StatusDot(isOn: appState.healthStatus == .connected)
                            Text(healthStatusText)
                                .font(Typeface.caption)
                                .foregroundStyle(Nova.bone.opacity(0.6))
                        }
                    }
                    Spacer(minLength: 0)
                    if appState.isRefreshing {
                        ProgressView().tint(Nova.bone.opacity(0.6))
                    }
                }

                if let model = appState.model {
                    HStack(spacing: 0) {
                        Stat(value: copy.duration(model.lastNight.night.asleepMinutes),
                             label: prefs.lastNight)
                        StatDivider()
                        Stat(value: "\(model.lastNight.score)", label: prefs.score)
                        StatDivider()
                        Stat(value: copy.duration(model.sleepDebtMinutes), label: prefs.debt)
                    }
                } else if let hint = healthHint {
                    Text(hint)
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.bone.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if appState.healthStatus != .unavailable {
                    HStack(spacing: 10) {
                        if appState.healthStatus == .notConnected {
                            Button(prefs.connect) {
                                Task { await appState.connectHealth() }
                            }
                            .buttonStyle(PillButtonStyle(prominent: true))
                        } else {
                            Button(prefs.openHealth) {
                                if let url = URL(string: "x-apple-health://") { openURL(url) }
                            }
                            .buttonStyle(PillButtonStyle(prominent: appState.healthStatus == .noData))
                        }
                        Button(prefs.refresh) {
                            Task { await appState.refresh() }
                        }
                        .buttonStyle(PillButtonStyle(prominent: false))
                        .disabled(appState.isRefreshing)
                    }
                }

                if let updated = appState.lastUpdated, appState.healthStatus == .connected {
                    Text("\(prefs.updated) \(updated.formatted(.relative(presentation: .named).locale(copy.locale)))")
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.muted)
                }
            }
        }
    }

    private var healthStatusText: String {
        switch appState.healthStatus {
        case .connected: prefs.healthConnected
        case .noData: prefs.healthNoData
        case .notConnected: prefs.healthNotConnected
        case .unavailable: prefs.healthUnavailable
        }
    }

    private var healthHint: String? {
        switch appState.healthStatus {
        case .noData: prefs.healthNoDataHint
        case .notConnected: prefs.healthNotConnectedHint
        case .connected, .unavailable: nil
        }
    }

    // MARK: Driving

    private var drivingCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    IconBadge(systemImage: "car.fill")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(prefs.driving)
                            .font(Typeface.body.weight(.medium))
                            .foregroundStyle(Nova.bone)
                        HStack(spacing: 6) {
                            StatusDot(isOn: appState.driveStatus == .authorized)
                            Text(drivingStatusText)
                                .font(Typeface.caption)
                                .foregroundStyle(Nova.bone.opacity(0.6))
                        }
                    }
                    Spacer(minLength: 0)
                }

                if appState.driveStatus == .authorized, let day = appState.driveDay {
                    HStack(spacing: 0) {
                        Stat(value: copy.duration(day.minutes), label: prefs.drivenToday)
                        StatDivider()
                        Stat(value: day.firstStart?.formatted(date: .omitted, time: .shortened) ?? "—",
                             label: prefs.onRoadSince)
                    }
                } else if let hint = drivingHint {
                    Text(hint)
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.bone.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                switch appState.driveStatus {
                case .notDetermined:
                    Button(prefs.turnOn) {
                        Task { await appState.enableDriving() }
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
                case .denied:
                    Button(prefs.openSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
                case .authorized, .unavailable:
                    EmptyView()
                }
            }
        }
    }

    private var drivingStatusText: String {
        switch appState.driveStatus {
        case .authorized:
            appState.driveDay?.isDrivingNow == true ? prefs.drivingNow : prefs.drivingOn
        case .notDetermined: prefs.drivingNotAsked
        case .denied: prefs.drivingOff
        case .unavailable: prefs.drivingUnavailable
        }
    }

    private var drivingHint: String? {
        switch appState.driveStatus {
        case .notDetermined: prefs.drivingHint
        case .denied: prefs.drivingOffHint
        case .authorized, .unavailable: nil
        }
    }

    // MARK: Reminders

    private var remindersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Toggle(isOn: $remindersOn) {
                    HStack(spacing: 14) {
                        IconBadge(systemImage: "bell.fill")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(prefs.dipReminder)
                                .font(Typeface.body.weight(.medium))
                                .foregroundStyle(Nova.bone)
                            Text(prefs.dipReminderHint)
                                .font(Typeface.caption)
                                .foregroundStyle(Nova.bone.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .tint(Nova.orange)

                if remindersOn {
                    Rectangle().fill(Nova.hairline).frame(height: 1)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(prefs.howEarly)
                            .font(Typeface.caption)
                            .foregroundStyle(Nova.bone.opacity(0.6))
                        HStack(spacing: 8) {
                            ForEach(NotificationManager.leadOptions, id: \.self) { minutes in
                                Chip(title: "\(minutes) \(prefs.minutes)",
                                     isSelected: minutes == leadMinutes) {
                                    leadMinutes = minutes
                                }
                            }
                        }
                    }

                    if notifications.status == .denied {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.slash")
                                .foregroundStyle(Nova.ember)
                            Text(prefs.notificationsOff)
                                .font(Typeface.caption)
                                .foregroundStyle(Nova.bone.opacity(0.8))
                            Spacer(minLength: 8)
                            Button(prefs.openSettings) {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            .font(Typeface.caption.weight(.medium))
                            .foregroundStyle(Nova.ember)
                        }
                    } else {
                        Label {
                            Text(nextReminderText)
                        } icon: {
                            Image(systemName: "clock")
                        }
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.muted)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: remindersOn)
    }

    private var nextReminderText: String {
        guard let next = notifications.nextReminder else { return prefs.noReminderToday }
        return String(format: prefs.nextReminder, next.formatted(date: .omitted, time: .shortened))
    }

    // MARK: Language

    private var languageOptions: some View {
        VStack(spacing: 8) {
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
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Nova.orange)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(option == language ? 0.08 : 0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(option == language ? Nova.orange.opacity(0.5) : Nova.hairline,
                                          lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option == language ? .isSelected : [])
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(prefs.privacy)
            } icon: {
                Image(systemName: "lock.fill")
            }
            .font(Typeface.caption)
            .foregroundStyle(Nova.bone.opacity(0.5))

            Text("kv0 \(appVersion)")
                .font(Typeface.caption)
                .foregroundStyle(Nova.muted)
                .padding(.leading, 26)
        }
        .padding(.top, 4)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: Pieces

private struct IconBadge: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Nova.orange)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Nova.orange.opacity(0.14)))
            .overlay(Circle().strokeBorder(Nova.orange.opacity(0.25), lineWidth: 1))
    }
}

private struct StatusDot: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(isOn ? Nova.orange : Nova.muted)
            .frame(width: 7, height: 7)
            .shadow(color: isOn ? Nova.orange : .clear, radius: 4)
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Typeface.stat)
                .tracking(Typeface.tracking(for: 22))
                .foregroundStyle(Nova.bone)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Typeface.caption)
                .foregroundStyle(Nova.bone.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Nova.hairline)
            .frame(width: 1, height: 36)
            .padding(.horizontal, 12)
    }
}

private struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.caption.weight(.medium))
                .foregroundStyle(isSelected ? Nova.bone : Nova.bone.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Capsule().fill(isSelected ? Nova.orange : Color.white.opacity(0.05)))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Nova.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PillButtonStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.body.weight(.medium))
            .foregroundStyle(Nova.bone)
            .padding(.horizontal, 20)
            .frame(height: 44)
            .background(Capsule().fill(prominent ? Nova.orange : Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(prominent ? Color.clear : Nova.hairline, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
