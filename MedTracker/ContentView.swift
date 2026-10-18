import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today
    case history
    case profile
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query private var logs: [MedicationLog]
    
    @State private var selectedTab: AppTab = .today
    @AppStorage(ActiveProfileStore.idKey, store: AppLocalization.sharedDefaults) private var activeProfileID = ""
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label(AppLocalization.string("Today"), systemImage: "pill.fill")
                }
                .tag(AppTab.today)
            
            HistoryView()
                .tabItem {
                    Label(AppLocalization.string("History"), systemImage: "calendar")
                }
                .tag(AppTab.history)
            
            ProfileView()
                .tabItem {
                    Label(AppLocalization.string("Profile"), systemImage: "person.fill")
                }
                .tag(AppTab.profile)
        }
        .onAppear {
            initializeData()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                initializeData()
                if NotificationPreferences.isEnabled {
                    NotificationManager.shared.rescheduleFromStore()
                }
            }
        }
        .onChange(of: activeProfileID) { _, _ in
            if let profile = ActiveProfileStore.resolve(from: profiles) {
                HouseholdData.ensureTodayLog(for: profile, logs: logs, context: modelContext)
                NotificationManager.shared.rescheduleFromStore()
            }
        }
    }
    
    private func initializeData() {
        HouseholdData.bootstrap(profiles: profiles, logs: logs, context: modelContext)
        if NotificationPreferences.isEnabled {
            NotificationManager.shared.registerCategories()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [MedicationLog.self, UserProfile.self], inMemory: true)
}
