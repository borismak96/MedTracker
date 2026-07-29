import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var logs: [MedicationLog]
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Today", systemImage: "pill.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .onAppear {
            initializeData()
        }
    }
    
    private func initializeData() {
        // Initialize UserProfile if empty
        if profiles.isEmpty {
            modelContext.insert(UserProfile())
        }
        
        // Generate up to 30 days of logs if missing
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for i in 0..<31 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                if !logs.contains(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                    modelContext.insert(MedicationLog(date: date))
                }
            }
        }
        
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [MedicationLog.self, UserProfile.self], inMemory: true)
}
