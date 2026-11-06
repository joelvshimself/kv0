import SwiftUI

@main
struct kv0App: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var notifications = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(notifications)
        }
    }
}
