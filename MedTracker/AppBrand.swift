import Foundation

enum AppBrand {
    /// English: PillPal · Traditional Chinese: 藥伴伴
    static var displayName: String {
        AppLocalization.string("PillPal")
    }

    /// Marketing version from the app bundle (`CFBundleShortVersionString`).
    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// Build number from the app bundle (`CFBundleVersion`).
    static var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    /// Localized "Version 1.2.1 (17)" / "版本 1.2.1 (17)".
    static var versionLabel: String {
        AppLocalization.format("Version %@ (%@)", marketingVersion, buildVersion)
    }
}
