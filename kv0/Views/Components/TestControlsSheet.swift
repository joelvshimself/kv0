import SwiftUI
import UIKit

/// Facilitator controls for user tests: the driver's sleep, which moment to show, and when
/// each notification arrives. Opened by long-pressing the moment pill; drivers never see a
/// way in. English only, since only the team uses it.
struct TestControlsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.copy) private var copy
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var notifications: NotificationManager

    @State private var sleep = TestSleep()
    @State private var times: [NotificationManager.Kind: Date] = [:]
    @State private var pastTime: Set<NotificationManager.Kind> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                group("Moment") { momentPicker }
                group("Driver's sleep") { sleepCard }
                group("Notifications") { notificationsCard }
            }
            .padding(Space.margin)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(StarfieldBackground().ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationBackground(Nova.void)
        .preferredColorScheme(.dark)
        .tint(Nova.orange)
        .task {
            sleep = appState.testSleep
            await notifications.refreshStatus()
            await notifications.refreshScheduledTests()
            seedTimes()
        }
        .onChange(of: sleep) { _, value in
            Task { await appState.setTestSleep(value) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Test controls")
                    .font(Typeface.sentence)
                    .tracking(Typeface.tracking(for: 30))
                    .foregroundStyle(Nova.bone)
                Spacer()
                Button(copy.done) { dismiss() }
                    .font(Typeface.body.weight(.medium))
                    .foregroundStyle(Nova.ember)
            }
            Text("For the facilitator. Long-press the pill at the top left to get back here.")
                .font(Typeface.caption)
                .foregroundStyle(Nova.muted)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(Typeface.caption.weight(.medium))
                .tracking(1.2)
                .foregroundStyle(Nova.muted)
                .padding(.leading, 4)
            content()
        }
    }

    // MARK: Moment

    private var momentPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            Chip(title: "Auto", isSelected: appState.momentOverride == nil) {
                appState.setMomentOverride(nil)
            }
            ForEach(JourneyState.allCases) { state in
                Chip(title: copy.state(state).title, isSelected: appState.momentOverride == state) {
                    appState.setMomentOverride(state)
                }
            }
        }
    }

    // MARK: Sleep

    private var sleepCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Toggle(isOn: $sleep.isOn) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Use the driver's sleep")
                            .font(Typeface.body.weight(.medium))
                            .foregroundStyle(Nova.bone)
                        Text("Replaces Apple Health everywhere in the app.")
                            .font(Typeface.caption)
                            .foregroundStyle(Nova.bone.opacity(0.6))
                    }
                }

                if sleep.isOn {
                    Divider().overlay(Nova.hairline)
                    nightRow("Last night", bed: $sleep.lastBed, wake: $sleep.lastWake)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("How they slept")
                            .font(Typeface.caption)
                            .foregroundStyle(Nova.bone.opacity(0.6))
                        HStack(spacing: 8) {
                            ForEach(TestSleep.Quality.allCases) { quality in
                                Chip(title: quality.label, isSelected: sleep.quality == quality) {
                                    sleep.quality = quality
                                }
                            }
                        }
                    }

                    Toggle(isOn: $sleep.fillWeek) {
                        Text("Fill the week before with a usual night")
                            .font(Typeface.caption)
                            .foregroundStyle(Nova.bone.opacity(0.8))
                    }
                    if sleep.fillWeek {
                        nightRow("Usual night", bed: $sleep.usualBed, wake: $sleep.usualWake)
                    }

                    if let model = appState.model {
                        Label {
                            Text("\(copy.duration(model.lastNight.night.asleepMinutes)) · score \(model.lastNight.score) · dip \(model.dipDate.formatted(date: .omitted, time: .shortened))")
                        } icon: {
                            Image(systemName: "moon.zzz")
                        }
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.ember)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sleep.isOn)
        .animation(.easeInOut(duration: 0.25), value: sleep.fillWeek)
    }

    private func nightRow(_ title: String, bed: Binding<Int>, wake: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(Typeface.body)
                    .foregroundStyle(Nova.bone)
                Spacer()
                Text(copy.duration(TestSleep.duration(bed: bed.wrappedValue, wake: wake.wrappedValue)))
                    .font(Typeface.body.monospacedDigit())
                    .foregroundStyle(Nova.bone.opacity(0.6))
            }
            HStack {
                timeField("Bed", minutes: bed)
                Spacer()
                timeField("Woke", minutes: wake)
            }
        }
    }

    private func timeField(_ label: String, minutes: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Typeface.caption)
                .foregroundStyle(Nova.bone.opacity(0.6))
            DatePicker(label, selection: minutes.asTimeOfDay, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    // MARK: Notifications

    private var notificationsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                if notifications.status == .denied {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash").foregroundStyle(Nova.ember)
                        Text(copy.prefs.notificationsOff)
                            .font(Typeface.caption)
                            .foregroundStyle(Nova.bone.opacity(0.8))
                        Spacer(minLength: 8)
                        Button(copy.prefs.openSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .font(Typeface.caption.weight(.medium))
                        .foregroundStyle(Nova.ember)
                    }
                } else {
                    Text("Pick a time, then lock the phone or switch to the Gojek app. Each one arrives as a real notification.")
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.bone.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(NotificationManager.Kind.allCases.enumerated()), id: \.element) { index, kind in
                    if index > 0 { Divider().overlay(Nova.hairline) }
                    notificationRow(kind)
                }
            }
        }
    }

    private func notificationRow(_ kind: NotificationManager.Kind) -> some View {
        let preview = notifications.content(for: kind, values: appState.notificationValues(), copy: copy)
        let due = notifications.scheduledTests[kind]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.label.uppercased())
                        .font(Typeface.caption.weight(.medium))
                        .tracking(0.8)
                        .foregroundStyle(Nova.muted)
                    Text(preview.title)
                        .font(Typeface.body.weight(.medium))
                        .foregroundStyle(Nova.bone)
                }
                Spacer(minLength: 8)
                DatePicker(kind.label, selection: timeBinding(for: kind), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            Text(preview.body)
                .font(Typeface.caption)
                .foregroundStyle(Nova.bone.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if let due {
                    StatusDot(isOn: true)
                    Text("Arrives at \(due.formatted(date: .omitted, time: .shortened))")
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.bone.opacity(0.8))
                } else if pastTime.contains(kind) {
                    Text("Pick a time later than now")
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.ember)
                } else {
                    Text("Not scheduled")
                        .font(Typeface.caption)
                        .foregroundStyle(Nova.muted)
                }
                Spacer()
                Button(due == nil ? "Schedule" : "Cancel") {
                    Task { await toggle(kind) }
                }
                .buttonStyle(PillButtonStyle(prominent: due == nil))
                .disabled(notifications.status == .denied)
            }
        }
    }

    private func timeBinding(for kind: NotificationManager.Kind) -> Binding<Date> {
        Binding(
            get: { times[kind] ?? Date() },
            set: { date in
                times[kind] = nextOccurrence(of: date)
                // Moving the time of a scheduled notification moves the notification.
                if notifications.scheduledTests[kind] != nil {
                    Task { await schedule(kind) }
                }
            }
        )
    }

    private func toggle(_ kind: NotificationManager.Kind) async {
        if notifications.scheduledTests[kind] != nil {
            await notifications.cancelTest(kind)
        } else {
            await schedule(kind)
        }
    }

    private func schedule(_ kind: NotificationManager.Kind) async {
        let date = times[kind] ?? Date()
        let ok = await notifications.scheduleTest(kind, at: date, values: appState.notificationValues(),
                                                  copy: copy)
        if ok { pastTime.remove(kind) } else if date <= Date() { pastTime.insert(kind) }
    }

    /// Scheduled notifications keep their time; the rest start two minutes apart from now,
    /// in the order a driver's day would bring them.
    private func seedTimes() {
        let start = Calendar.current.date(bySetting: .second, value: 0, of: Date().addingTimeInterval(60))!
        for (index, kind) in NotificationManager.Kind.allCases.enumerated() {
            times[kind] = notifications.scheduledTests[kind] ?? start.addingTimeInterval(Double(index) * 120)
        }
    }

    /// A picked clock time means today, from the current minute on.
    private func nextOccurrence(of picked: Date) -> Date {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute], from: picked)
        return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0,
                             of: Date()) ?? picked
    }
}

private extension NotificationManager.Kind {
    var label: String {
        switch self {
        case .sleepSummary: "Morning sleep"
        case .workStarted: "Workday started"
        case .dipReminder: "Before the dip"
        case .longDrive: "Long drive"
        case .finishWork: "Finish work"
        }
    }
}

private extension TestSleep.Quality {
    var label: String {
        switch self {
        case .good: "Well"
        case .ok: "OK"
        case .poor: "Badly"
        }
    }
}

private extension Binding where Value == Int {
    /// Minutes after midnight shown in a time picker.
    var asTimeOfDay: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: wrappedValue / 60, minute: wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
