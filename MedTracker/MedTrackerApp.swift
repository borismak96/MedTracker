import SwiftUI
import SwiftData

@main
struct MedTrackerApp: App {
    @AppStorage("appLanguage") private var appLanguage = "system"
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, appLanguage == "system" ? Locale.current : Locale(identifier: appLanguage))
        }
        .modelContainer(for: [MedicationLog.self, UserProfile.self])
    }
}
