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
    @AppStorage(ElderMode.enabledKey, store: AppLocalization.sharedDefaults) private var elderMode = false
    
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
        .modifier(ElderDynamicType(enabled: elderMode))
        .onAppear {
            initializeData()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                initializeData()
                NotificationManager.shared.rescheduleFromStore()
            }
        }
        .onChange(of: activeProfileID) { _, _ in
            if let profile = ActiveProfileStore.resolve(from: profiles.filter(\.isStoredInContext)) {
                HouseholdData.ensureTodayLog(for: profile, logs: logs.filter(\.isStoredInContext), context: modelContext)
                NotificationManager.shared.rescheduleFromStore()
            }
        }
    }
    
    private func initializeData() {
        let liveProfiles = profiles.filter(\.isStoredInContext)
        let liveLogs = logs.filter(\.isStoredInContext)
        HouseholdData.bootstrap(profiles: liveProfiles, logs: liveLogs, context: modelContext)
        NotificationManager.shared.registerCategories()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [MedicationLog.self, UserProfile.self], inMemory: true)
}

private struct ElderDynamicType: ViewModifier {
    var enabled: Bool
    
    func body(content: Content) -> some View {
        if enabled {
            // Floor at xxLarge for 樂齡; allow Accessibility 1–3 (~200–310%) so text can wrap instead of clip.
            content.dynamicTypeSize(.xxLarge ... .accessibility3)
        } else {
            content
        }
    }
}

extension DynamicTypeSize {
    /// Stacked, wrapping layouts for VoiceOver / Larger Text at ~200% and above.
    var prefersStackedLayout: Bool {
        isAccessibilitySize
    }
}
