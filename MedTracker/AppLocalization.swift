import Foundation

/// Resolves strings using the in-app language setting (not only the system locale).
///
/// Uses the compiled zh-Hant dictionary from `GeneratedLocalizations` so Chinese
/// works even when Foundation's String Catalog lookup ignores the in-app locale.
enum AppLocalization {
    static let appGroupSuiteName = "group.com.example.MedTracker"
    
    /// Shared with the widget extension.
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupSuiteName) ?? .standard
    }
    
    static var languageCode: String {
        if let groupValue = UserDefaults(suiteName: appGroupSuiteName)?.string(forKey: "appLanguage"),
           !groupValue.isEmpty {
            return groupValue
        }
        // Migrate from standard AppStorage if needed.
        let standard = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        UserDefaults(suiteName: appGroupSuiteName)?.set(standard, forKey: "appLanguage")
        return standard
    }
    
    /// True when UI should prefer Traditional Chinese.
    static var prefersTraditionalChinese: Bool {
        if languageCode == "zh-Hant" {
            return true
        }
        guard languageCode == "system" else { return false }
        
        let lower = Locale.autoupdatingCurrent.identifier
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        return lower.hasPrefix("zh-hant")
            || lower.hasPrefix("zh-tw")
            || lower.hasPrefix("zh-hk")
    }
    
    static var locale: Locale {
        if languageCode == "system" {
            return .autoupdatingCurrent
        }
        return Locale(identifier: languageCode)
    }
    
    static func string(_ key: String) -> String {
        if prefersTraditionalChinese {
            return GeneratedLocalizations.zhHant[key]
                ?? GeneratedLocalizations.en[key]
                ?? key
        }
        // Opaque keys (e.g. About_Us_Content) need the catalog English value;
        // natural-language keys can fall back to the key itself.
        return GeneratedLocalizations.en[key] ?? key
    }
    
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let template = string(key)
        return String(format: template, locale: locale, arguments: arguments)
    }
    
    static func shortTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%d:%02d", hour, minute)
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    static func mediumDate(_ date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
}
