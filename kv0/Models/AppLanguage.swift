import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case bahasa = "id"

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    /// Shown in each language's own words so the choice reads correctly from either side.
    var displayName: String {
        switch self {
        case .english: "English"
        case .bahasa: "Bahasa Indonesia"
        }
    }

    var copy: Copy {
        switch self {
        case .english: .english
        case .bahasa: .bahasa
        }
    }
}

private struct CopyKey: EnvironmentKey {
    static let defaultValue = Copy.english
}

extension EnvironmentValues {
    var copy: Copy {
        get { self[CopyKey.self] }
        set { self[CopyKey.self] = newValue }
    }
}
