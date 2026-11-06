import SwiftUI

struct SettingsSheet: View {
    @Binding var language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.copy) private var copy
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notificationManager: NotificationManager
    
    @State private var notificationsEnabled = true
    @State private var preDipMinutes = 30
    @State private var apiBaseURL = "http://localhost:3000/api"
    @State private var isSyncing = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(copy.language, selection: $language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Language")
                }
                
                Section {
                    Toggle("Enable notifications", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        Stepper(
                            value: $preDipMinutes,
                            in: 15...60,
                            step: 5
                        ) {
                            HStack {
                                Text("Pre-dip notification")
                                Spacer()
                                Text("\(preDipMinutes) min before")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if let token = notificationManager.deviceToken {
                        Text("Device registered")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Device not registered")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive wake-up notifications with your sleep score and reminders before your energy dip.")
                }
                
                Section {
                    TextField("API URL", text: $apiBaseURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                } header: {
                    Text("Backend API")
                } footer: {
                    Text("The backend server URL for syncing data. Default: http://localhost:3000/api")
                }
                
                Section {
                    Button {
                        Task {
                            isSyncing = true
                            await appState.manualSync()
                            isSyncing = false
                        }
                    } label: {
                        HStack {
                            Text("Sync now")
                            if isSyncing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)
                    
                    if let lastUpdate = appState.lastUpdateTime as Date? {
                        HStack {
                            Text("Last sync")
                            Spacer()
                            Text(lastUpdate, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Data")
                }
                
                Section {
                    Button("Request HealthKit access") {
                        Task {
                            try? await HealthKitManager.shared.requestAuthorization()
                        }
                    }
                    
                    if HealthKitManager.shared.isAuthorized {
                        Text("HealthKit access granted")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Permissions")
                }
            }
            .navigationTitle(copy.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(copy.done) {
                        Task {
                            APIClient.shared.setBaseURL(apiBaseURL)
                            
                            try? await DataSyncManager.shared.updateUserSettings(
                                preDipNotificationMinutes: preDipMinutes,
                                notificationsEnabled: notificationsEnabled
                            )
                            
                            dismiss()
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
