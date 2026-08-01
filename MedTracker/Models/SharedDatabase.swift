import SwiftData
import Foundation

/// Shared SwiftData container for the app and widget extension.
/// Not MainActor-isolated so TimelineProvider / AppIntent can read it safely.
final class SharedDatabase: @unchecked Sendable {
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
                let shmURL = URL.applicationSupportDirectory.appendingPathComponent("default.store-shm")
                let walURL = URL.applicationSupportDirectory.appendingPathComponent("default.store-wal")
                if FileManager.default.fileExists(atPath: shmURL.path) {
                    try FileManager.default.copyItem(at: shmURL, to: appGroupURL.appendingPathComponent("MedTracker.sqlite-shm"))
                }
                if FileManager.default.fileExists(atPath: walURL.path) {
                    try FileManager.default.copyItem(at: walURL, to: appGroupURL.appendingPathComponent("MedTracker.sqlite-wal"))
                }
            } catch {
                print("Legacy store copy failed: \(error)")
            }
        }
        
        let modelConfiguration = ModelConfiguration(schema: schema, url: databaseURL)
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema update (e.g. new ageRange field) can make the old store incompatible.
            // Remove the old files and create a fresh database so the app can launch.
            print("ModelContainer failed, resetting store: \(error)")
            Self.removeStoreFiles(at: databaseURL)
            
            do {
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }
    
    private static func removeStoreFiles(at url: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let fileURL = URL(fileURLWithPath: url.path + suffix)
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
