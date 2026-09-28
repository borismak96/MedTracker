import Foundation

/// Resolves strings using the in-app language setting (not only the system locale).
///
/// Uses the compiled zh-Hant dictionary from `GeneratedLocalizations` so Chinese
/// works even when Foundation's String Catalog lookup ignores the in-app locale.
enum AppLocalization {
    static let appGroupSuiteName = "group.com.borismak.PillPal"
    
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
        string(key, chinese: prefersTraditionalChinese)
    }
    
    /// Resolve a catalog key in English or Traditional Chinese regardless of the in-app toggle.
    static func string(_ key: String, chinese: Bool) -> String {
        if chinese {
            return GeneratedLocalizations.zhHant[key]
                ?? GeneratedLocalizations.en[key]
                ?? key
        }
        // Opaque keys (e.g. About_Us_Content) need the catalog English value;
        // natural-language keys can fall back to the key itself.
        return GeneratedLocalizations.en[key] ?? key
    }
    
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        format(key, chinese: prefersTraditionalChinese, arguments: arguments)
    }
    
    static func format(_ key: String, _ count: Int) -> String {
        format(key, chinese: prefersTraditionalChinese, arguments: [count])
    }
    
    static func format(_ key: String, chinese: Bool, _ count: Int) -> String {
        format(key, chinese: chinese, arguments: [count])
    }
    
    static func format(_ key: String, chinese: Bool, arguments: [CVarArg]) -> String {
        let template = formatTemplate(key, chinese: chinese, arguments: arguments)
        let loc = chinese ? Locale(identifier: "zh-Hant") : Locale(identifier: "en")
        return String(format: template, locale: loc, arguments: arguments)
    }
    
    static func format(_ key: String, chinese: Bool, _ arguments: CVarArg...) -> String {
        format(key, chinese: chinese, arguments: arguments)
    }
    
    /// English `one`/`other` from the string catalog; 繁中 uses the same form for every count.
    private static func formatTemplate(_ key: String, chinese: Bool, arguments: [CVarArg]) -> String {
        if let count = firstInteger(arguments),
           let plural = GeneratedLocalizations.pluralTemplate(key, count: count, chinese: chinese) {
            return plural
        }
        return string(key, chinese: chinese)
    }
    
    private static func firstInteger(_ arguments: [CVarArg]) -> Int? {
        guard let first = arguments.first else { return nil }
        if let value = first as? Int { return value }
        if let value = first as? Int64 { return Int(value) }
        if let value = first as? Int32 { return Int(value) }
        if let value = first as? UInt { return Int(value) }
        if let value = first as? UInt64 { return Int(value) }
        return nil
    }
    
    static func shortTime(hour: Int, minute: Int, chinese: Bool? = nil) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%d:%02d", hour, minute)
        }
        let useChinese = chinese ?? prefersTraditionalChinese
        let formatter = DateFormatter()
        if let chinese {
            formatter.locale = chinese ? Locale(identifier: "zh-Hant") : Locale(identifier: "en")
        } else {
            formatter.locale = locale
        }
        formatter.timeStyle = .short
        let raw = formatter.string(from: date)
        return useChinese ? stripChineseDayPeriod(raw) : raw
    }
    
    /// zh-Hant `short` times include 上午/晚上, which duplicates slot labels like 「晚上 · 晚上9:00」.
    private static func stripChineseDayPeriod(_ time: String) -> String {
        let periods = ["上午", "下午", "晚上", "清晨", "凌晨", "中午", "傍晚", "午夜", "早上"]
        var result = time
        for period in periods {
            result = result.replacingOccurrences(of: period, with: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func mediumDate(_ date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
}
