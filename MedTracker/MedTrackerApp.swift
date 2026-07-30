import SwiftUI
import SwiftData

@main
struct MedTrackerApp: App {
    @AppStorage("appLanguage") private var appLanguage = "system"
    @State private var isActive = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isActive {
                    ContentView()
                        .environment(\.locale, appLanguage == "system" ? Locale.current : Locale(identifier: appLanguage))
                        .transition(.opacity)
                } else {
                    SplashView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    isActive = true
                                }
                            }
                        }
                }
            }
        }
        .modelContainer(for: [MedicationLog.self, UserProfile.self])
    }
}
