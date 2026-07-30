import SwiftData
import Foundation

@MainActor
class SharedDatabase {
    static let shared = SharedDatabase()
    
    let container: ModelContainer
    
    private init() {
        let schema = Schema([
            MedicationLog.self,
            UserProfile.self
        ])
        
        let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.MedTracker")!
        let databaseURL = appGroupURL.appendingPathComponent("MedTracker.sqlite")
        
        // Optional: Migrate existing default store to App Group store
        let defaultStoreURL = URL.applicationSupportDirectory.appendingPathComponent("default.store")
        if FileManager.default.fileExists(atPath: defaultStoreURL.path) && !FileManager.default.fileExists(atPath: databaseURL.path) {
            do {
                try FileManager.default.copyItem(at: defaultStoreURL, to: databaseURL)
                // Try to copy shm and wal files too
                let shmURL = URL.applicationSupportDirectory.appendingPathComponent("default.store-shm")
                let walURL = URL.applicationSupportDirectory.appendingPathComponent("default.store-wal")
                if FileManager.default.fileExists(atPath: shmURL.path) {
                    try FileManager.default.copyItem(at: shmURL, to: appGroupURL.appendingPathComponent("MedTracker.sqlite-shm"))
                }
                if FileManager.default.fileExists(atPath: walURL.path) {
                    try FileManager.default.copyItem(at: walURL, to: appGroupURL.appendingPathComponent("MedTracker.sqlite-wal"))
                }
            } catch {
                print("Migration failed: \(error)")
            }
        }
        
        let modelConfiguration = ModelConfiguration(schema: schema, url: databaseURL)
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
