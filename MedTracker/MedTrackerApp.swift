import SwiftUI
import SwiftData

@main
struct MedTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [MedicationLog.self, UserProfile.self])
    }
}
