import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MedTrackerViewModel()
    
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
        .environmentObject(viewModel)
    }
}

#Preview {
    ContentView()
}
