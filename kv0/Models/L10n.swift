import Foundation

struct StateCopy {
    let title: String
    let sentence: String
    let heroLabel: String
    let suggestionsTitle: String
    let suggestions: [String]

    func with(sentence: String) -> StateCopy {
        StateCopy(title: title, sentence: sentence, heroLabel: heroLabel,
                  suggestionsTitle: suggestionsTitle, suggestions: suggestions)
    }
}

struct SettingsCopy {
    let health: String
    let healthConnected: String
    let healthNoData: String
    let healthNotConnected: String
    let healthUnavailable: String
    let healthNoDataHint: String
    let healthNotConnectedHint: String
    let driving: String
    let drivingOn: String
    let drivingOff: String
    let drivingNotAsked: String
    let drivingUnavailable: String
    let drivingHint: String
    let drivingOffHint: String
    let turnOn: String
    let drivenToday: String
    let onRoadSince: String
    let drivingNow: String
    let connect: String
    let openHealth: String
    let refresh: String
    let updated: String
    let lastNight: String
    let score: String
    let debt: String
    let reminders: String
    let dipReminder: String
    let dipReminderHint: String
    let howEarly: String
    let minutes: String
    /// Takes the reminder time.
    let nextReminder: String
    let noReminderToday: String
    let notificationsOff: String
    let openSettings: String
    let privacy: String
}

struct Copy {
    let morning: StateCopy
    let working: StateCopy
    let breakDue: StateCopy
    let finishWork: StateCopy
    /// Morning sentence after a night scoring under 70.
    let morningLightSentence: String
    /// Break-due sentence after two hours of driving without a stop.
    let longDriveSentence: String

    let now: String
    let dip: String
    /// Takes the dip time.
    let graphAccessibility: String
    let sleepTime: String
    let journeyDuration: String
    let sleepScore: String
    let lastNights: String
    /// Takes the number of nights.
    let learningNote: String
    let sampleNote: String
    let sampleBanner: String
    let localeIdentifier: String
    let hourUnit: String
    let minuteUnit: String
    let info: String
    let settings: String
    let language: String
    let done: String
    let reminderTitle: String
    /// Takes the dip time.
    let reminderBody: String
    /// Takes last night's sleep duration.
    let notifSleepTitle: String
    /// Takes the score, then the dip time.
    let notifSleepBody: String
    let notifWorkTitle: String
    /// Takes hours to the dip, then the dip time.
    let notifWorkBody: String
    let notifBreakTitle: String
    let notifDoneTitle: String
    /// Takes time driven, then tonight's sleep goal in hours.
    let notifDoneBody: String
    let prefs: SettingsCopy

    var locale: Locale { Locale(identifier: localeIdentifier) }

    func state(_ state: JourneyState) -> StateCopy {
        switch state {
        case .morning: morning
        case .working: working
        case .breakDue: breakDue
        case .finishWork: finishWork
        }
    }

    func duration(_ minutes: Int) -> String {
        "\(minutes / 60)\(hourUnit) \(String(format: "%02d", minutes % 60))\(minuteUnit)"
    }

    /// Clock time for an hour on the app's continuous scale, where 24.5 is 00:30.
    func clock(_ hour: Double) -> String {
        let minutes = Int((hour * 60).rounded()) % (24 * 60)
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

extension Copy {
    static let english = Copy(
        morning: StateCopy(
            title: "Morning",
            sentence: "You slept deeply. Today is a good day to start on the hard thing.",
            heroLabel: "sleep time, last night",
            suggestionsTitle: "",
            suggestions: []
        ),
        working: StateCopy(
            title: "Working",
            sentence: "Steady and focused. You have a long clear stretch ahead.",
            heroLabel: "hours until your dip",
            suggestionsTitle: "",
            suggestions: []
        ),
        breakDue: StateCopy(
            title: "Break due",
            sentence: "Your dip is close. Step away for fifteen minutes.",
            heroLabel: "hours until your dip",
            suggestionsTitle: "Ways to rest",
            suggestions: [
                "Walk outside without your phone",
                "Drink a glass of water",
                "Look at something far away",
            ]
        ),
        finishWork: StateCopy(
            title: "Finish work",
            sentence: "You worked well today. Your sleeping goal would be:",
            heroLabel: "hours to recover tonight",
            suggestionsTitle: "About your work today",
            suggestions: [
                "You held a clear stretch on the hard thing.",
                "The work you did today left a mark.",
            ]
        ),
        morningLightSentence: "A lighter night. Keep the hard thing for your clearest hours.",
        longDriveSentence: "Over two hours behind the wheel. Pull over for fifteen minutes.",
        now: "now",
        dip: "dip",
        graphAccessibility: "Alertness through the day, with a dip at %@",
        sleepTime: "sleep time",
        journeyDuration: "driving today",
        sleepScore: "sleep score",
        lastNights: "last 7 nights",
        learningNote: "Based on %d nights from Apple Health. Readings sharpen as kv0 learns your rhythm.",
        sampleNote: "Sample week. Your own nights appear once Apple Health has sleep to share.",
        sampleBanner: "Sample data. Connect Apple Health to see your own sleep.",
        localeIdentifier: "en",
        hourUnit: "h",
        minuteUnit: "m",
        info: "More about this moment",
        settings: "Settings",
        language: "Language",
        done: "Done",
        reminderTitle: "Your dip is coming",
        reminderBody: "Predicted around %@. A good moment to step away.",
        notifSleepTitle: "You slept %@",
        notifSleepBody: "Sleep score %d. Your dip is around %@ today.",
        notifWorkTitle: "Workday started",
        notifWorkBody: "Your dip is in %@ hours, around %@.",
        notifBreakTitle: "Time for a break",
        notifDoneTitle: "Done for today",
        notifDoneBody: "You drove %@ today. Aim for %@ hours of sleep tonight.",
        prefs: SettingsCopy(
            health: "Apple Health",
            healthConnected: "Reading your sleep",
            healthNoData: "No sleep found yet",
            healthNotConnected: "Not connected",
            healthUnavailable: "Not available on this device",
            healthNoDataHint: "Wear your Apple Watch to bed or turn on Sleep Schedule in the Health app. If you turned access off, allow kv0 in Health under Sharing, then Apps.",
            healthNotConnectedHint: "kv0 reads your sleep to score each night and predict your afternoon dip.",
            driving: "Driving",
            drivingOn: "Detecting your drives",
            drivingOff: "Motion access is off",
            drivingNotAsked: "Not turned on",
            drivingUnavailable: "Not available on this device",
            drivingHint: "kv0 uses your iPhone's motion sensors to notice when you start driving, so your workday starts on its own. No GPS.",
            drivingOffHint: "Without it, kv0 guesses your workday from the clock. Allow Motion & Fitness for kv0 in iOS Settings.",
            turnOn: "Turn on",
            drivenToday: "driven today",
            onRoadSince: "first drive",
            drivingNow: "Driving now",
            connect: "Connect",
            openHealth: "Open Health",
            refresh: "Refresh",
            updated: "Updated",
            lastNight: "last night",
            score: "score",
            debt: "debt, 7 nights",
            reminders: "Reminders",
            dipReminder: "Before my dip",
            dipReminderHint: "A nudge to take a break before your predicted dip.",
            howEarly: "How early",
            minutes: "min",
            nextReminder: "Next reminder at %@",
            noReminderToday: "No more reminders today",
            notificationsOff: "Notifications are off for kv0.",
            openSettings: "Open iOS Settings",
            privacy: "Your sleep is read from Apple Health and stays on this iPhone."
        )
    )

    static let bahasa = Copy(
        morning: StateCopy(
            title: "Pagi",
            sentence: "Tidurmu nyenyak. Hari ini saat yang tepat untuk memulai hal yang sulit.",
            heroLabel: "waktu tidur, semalam",
            suggestionsTitle: "",
            suggestions: []
        ),
        working: StateCopy(
            title: "Bekerja",
            sentence: "Tenang dan fokus. Masih ada waktu panjang yang lapang di depanmu.",
            heroLabel: "jam menuju penurunan energimu",
            suggestionsTitle: "",
            suggestions: []
        ),
        breakDue: StateCopy(
            title: "Waktunya istirahat",
            sentence: "Penurunan energimu sudah dekat. Menjauhlah sejenak selama lima belas menit.",
            heroLabel: "jam menuju penurunan energimu",
            suggestionsTitle: "Cara beristirahat",
            suggestions: [
                "Jalan-jalan di luar tanpa ponsel",
                "Minum segelas air",
                "Lihat sesuatu yang jauh",
            ]
        ),
        finishWork: StateCopy(
            title: "Selesai kerja",
            sentence: "Kerja bagus hari ini. Target tidurmu adalah:",
            heroLabel: "jam untuk pulih malam ini",
            suggestionsTitle: "Tentang kerjamu hari ini",
            suggestions: [
                "Kamu bertahan fokus pada hal yang sulit.",
                "Pekerjaanmu hari ini meninggalkan jejak.",
            ]
        ),
        morningLightSentence: "Tidurmu kurang nyenyak. Simpan hal yang sulit untuk jam-jam paling jernihmu.",
        longDriveSentence: "Lebih dari dua jam di balik kemudi. Menepilah selama lima belas menit.",
        now: "sekarang",
        dip: "penurunan",
        graphAccessibility: "Tingkat kewaspadaan sepanjang hari, dengan penurunan pada pukul %@",
        sleepTime: "waktu tidur",
        journeyDuration: "menyetir hari ini",
        sleepScore: "skor tidur",
        lastNights: "7 malam terakhir",
        learningNote: "Berdasarkan %d malam dari Apple Health. Hasilnya makin akurat saat kv0 mempelajari ritmemu.",
        sampleNote: "Contoh minggu. Malam-malammu muncul setelah Apple Health punya data tidur.",
        sampleBanner: "Data contoh. Hubungkan Apple Health untuk melihat tidurmu.",
        localeIdentifier: "id",
        hourUnit: "j",
        minuteUnit: "m",
        info: "Selengkapnya tentang momen ini",
        settings: "Pengaturan",
        language: "Bahasa",
        done: "Selesai",
        reminderTitle: "Energimu akan turun",
        reminderBody: "Diperkirakan sekitar pukul %@. Saat yang tepat untuk rehat sejenak.",
        notifSleepTitle: "Kamu tidur %@",
        notifSleepBody: "Skor tidur %d. Energimu diperkirakan turun sekitar pukul %@.",
        notifWorkTitle: "Mulai narik",
        notifWorkBody: "Energimu turun %@ jam lagi, sekitar pukul %@.",
        notifBreakTitle: "Waktunya istirahat",
        notifDoneTitle: "Selesai untuk hari ini",
        notifDoneBody: "Hari ini kamu menyetir %@. Targetkan tidur %@ jam malam ini.",
        prefs: SettingsCopy(
            health: "Apple Health",
            healthConnected: "Membaca data tidurmu",
            healthNoData: "Belum ada data tidur",
            healthNotConnected: "Belum terhubung",
            healthUnavailable: "Tidak tersedia di perangkat ini",
            healthNoDataHint: "Pakai Apple Watch saat tidur atau aktifkan Jadwal Tidur di app Kesehatan. Jika akses dimatikan, izinkan kv0 di Kesehatan lewat Berbagi, lalu App.",
            healthNotConnectedHint: "kv0 membaca data tidurmu untuk menilai setiap malam dan memprediksi penurunan energimu di siang hari.",
            driving: "Mengemudi",
            drivingOn: "Mendeteksi perjalananmu",
            drivingOff: "Akses gerakan dimatikan",
            drivingNotAsked: "Belum diaktifkan",
            drivingUnavailable: "Tidak tersedia di perangkat ini",
            drivingHint: "kv0 memakai sensor gerak iPhone untuk mengetahui kapan kamu mulai mengemudi, jadi hari kerjamu dimulai otomatis. Tanpa GPS.",
            drivingOffHint: "Tanpa akses ini, kv0 menebak hari kerjamu dari jam. Izinkan Gerakan & Kebugaran untuk kv0 di Pengaturan iOS.",
            turnOn: "Aktifkan",
            drivenToday: "menyetir hari ini",
            onRoadSince: "perjalanan pertama",
            drivingNow: "Sedang mengemudi",
            connect: "Hubungkan",
            openHealth: "Buka Kesehatan",
            refresh: "Muat ulang",
            updated: "Diperbarui",
            lastNight: "semalam",
            score: "skor",
            debt: "utang, 7 malam",
            reminders: "Pengingat",
            dipReminder: "Sebelum energiku turun",
            dipReminderHint: "Pengingat untuk rehat sebelum prediksi penurunan energimu.",
            howEarly: "Seberapa awal",
            minutes: "mnt",
            nextReminder: "Pengingat berikutnya pukul %@",
            noReminderToday: "Tidak ada pengingat lagi hari ini",
            notificationsOff: "Notifikasi kv0 dimatikan.",
            openSettings: "Buka Pengaturan iOS",
            privacy: "Data tidurmu dibaca dari Apple Health dan tetap di iPhone ini."
        )
    )
}
