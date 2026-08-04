import SwiftUI
import SwiftData

@main
struct MedTrackerApp: App {
    @AppStorage("appLanguage", store: AppLocalization.sharedDefaults) private var appLanguage = "system"
    @State private var isActive = false
    
    init() {
        // Migrate language preference into the App Group used by AppLocalization + widgets.
        let group = AppLocalization.sharedDefaults
        if group.object(forKey: "appLanguage") == nil,
           let legacy = UserDefaults.standard.string(forKey: "appLanguage") {
            group.set(legacy, forKey: "appLanguage")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isActive {
                    ContentView()
                        .id(appLanguage) // Force full UI refresh when language changes.
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
            // Keep light look in both system Light and Dark Mode.
            .preferredColorScheme(.light)
            // Apply to the whole app (including Splash), so formatters follow in-app language.
            .environment(\.locale, resolvedLocale)
        }
        .modelContainer(SharedDatabase.shared.container)
    }
    
    private var resolvedLocale: Locale {
        appLanguage == "system" ? Locale.autoupdatingCurrent : Locale(identifier: appLanguage)
    }
}
