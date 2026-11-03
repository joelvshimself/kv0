import Foundation

struct StateCopy {
    let title: String
    let sentence: String
    let heroLabel: String
    let suggestionsTitle: String
    let suggestions: [String]
}

struct Copy {
    let morning: StateCopy
    let working: StateCopy
    let breakDue: StateCopy
    let finishWork: StateCopy

    let now: String
    let dip: String
    let graphAccessibility: String
    let sleepTime: String
    let journeyDuration: String
    let sleepScore: String
    let lastNights: String
    let learningNote: String
    let weekdays: [String]
    let hourUnit: String
    let minuteUnit: String
    let momentOfDay: String
    let info: String
    let settings: String
    let language: String
    let done: String

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
            sentence: "Almost three hours without a pause. Step away for fifteen minutes.",
            heroLabel: "hours since your last break",
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
        now: "now",
        dip: "dip",
        graphAccessibility: "Alertness through the day, with a dip at 15:00",
        sleepTime: "sleep time",
        journeyDuration: "journey duration",
        sleepScore: "sleep score",
        lastNights: "last 7 nights",
        learningNote: "Based on 7 nights. Readings sharpen as kv0 learns your rhythm.",
        weekdays: ["Wed", "Thu", "Fri", "Sat", "Sun", "Mon", "Tue"],
        hourUnit: "h",
        minuteUnit: "m",
        momentOfDay: "Moment of the day",
        info: "More about this moment",
        settings: "Settings",
        language: "Language",
        done: "Done"
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
            sentence: "Hampir tiga jam tanpa jeda. Menjauhlah sejenak selama lima belas menit.",
            heroLabel: "jam sejak istirahat terakhirmu",
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
        now: "sekarang",
        dip: "penurunan",
        graphAccessibility: "Tingkat kewaspadaan sepanjang hari, dengan penurunan pada pukul 15:00",
        sleepTime: "waktu tidur",
        journeyDuration: "durasi perjalanan",
        sleepScore: "skor tidur",
        lastNights: "7 malam terakhir",
        learningNote: "Berdasarkan 7 malam. Hasilnya makin akurat saat kv0 mempelajari ritmemu.",
        weekdays: ["Rab", "Kam", "Jum", "Sab", "Min", "Sen", "Sel"],
        hourUnit: "j",
        minuteUnit: "m",
        momentOfDay: "Momen hari ini",
        info: "Selengkapnya tentang momen ini",
        settings: "Pengaturan",
        language: "Bahasa",
        done: "Selesai"
    )
}
