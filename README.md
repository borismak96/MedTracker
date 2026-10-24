# PillPal

iOS medication reminder and household care app. **App Store name:** PillPal · **Traditional Chinese:** 藥伴伴 · **Xcode project:** MedTracker.

Repo: [https://github.com/borismak96/MedTracker](https://github.com/borismak96/MedTracker)

| | |
| --- | --- |
| Marketing version | **1.3.0** |
| Build | **18** |
| Price | Free (no StoreKit / IAP) |
| Data | On-device SwiftData — no app cloud backend |
| Languages | English + 繁體中文 |
| Bundle ID | `com.borismak.PillPal` |

Version numbers live in `MedTracker.xcodeproj/project.pbxproj` (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`) for both the app and the widget. On App Store Connect the listing may also appear as **PillPal:MedTracker**.

## What it is

A personal, privacy-first tracker for daily medications and simple health notes (mood, blood pressure, heart rate). It is **not a medical device** and does not diagnose or advise.

Household members share one iPhone (up to 8 profiles). There is no PillPal account and no developer-operated server for app data.

## Stack

- SwiftUI, iOS 17+, iPhone and iPad
- SwiftData in an App Group (`group.com.borismak.PillPal`) so the home-screen widget can read the same store
- Local notifications (Take / Snooze / Skip + follow-up)
- String Catalog: `MedTracker/Localizable.xcstrings` → `GeneratedLocalizations.swift`
- Forced light appearance
- No StoreKit, no CloudKit app database, no analytics / ads SDKs

## Open and build

1. On a Mac with Xcode, clone this repo.
2. Open **`MedTracker.xcodeproj`**.
3. Select scheme **MedTracker** (product is `PillPal.app`). Widget scheme: **MedTrackerWidgetExtension**.
4. Choose a simulator or a signed device. Signing needs an Apple Developer team in Xcode (already set on Boris’s machine; another Mac must pick a team).
5. Run.

Tip only — not required: Boris’s local checkout is often `~/Projects/MedTracker`.

There is no CI build of the iOS app in this repo. App Store upload and review happen in **App Store Connect**, separately from git.

## Features (1.3.0)

- **Today** — due doses with Take, Snooze (10 / 30 / 60 min in-app), and Skip / Missed
- **Reminders** — time-sensitive local notifications with Take / Snooze (15 min) / Skip; one follow-up if the dose is still open
- **History** — calendar, weekly summary, day detail
- **Profile / household** — switch members, meds, reminder times, language, export PDF
- **Medical Card** — name, allergies, emergency contact, current meds (not an official medical ID)
- **Medication List (Visit Pack)** — on-device bilingual PDF of meds, schedule, and recent adherence
- **Elder Mode / 樂齡** — larger type and tap targets
- **Medication photos** — optional on-device JPEG for identification (Today + Medical Card)
- **Home-screen widgets** — daily status, overview (no med names), quick Take / Skip
- Optional mood, blood pressure, and heart rate logs

## Privacy

Health and medication data stay on the device (and in the user’s own iPhone backup if they enable one). `MedTracker/PrivacyInfo.xcprivacy` declares **no collected data types** (App Store “Data Not Collected” stance). The app does not operate a cloud backend for this data.

Public pages (GitHub Pages from `docs/`):

- [Support](https://borismak96.github.io/MedTracker/)
- [Privacy Policy](https://borismak96.github.io/MedTracker/privacy.html)
- [Medical Card viewer](https://borismak96.github.io/MedTracker/mc.html) — static hash-URL page only; in-app QR share was removed and should stay removed

Support email (from those pages): borismak888@gmail.com

## Repo map

```
MedTracker/            App source, models, views, strings, assets
MedTrackerWidget/      WidgetKit extension
MedTracker.xcodeproj/  Xcode project + shared schemes
docs/                  GitHub Pages HTML (support, privacy, mc.html)
AppStorePreviews/      App Store screenshot assets
```

One-off Ruby helpers (`add_medical_card.rb`, `add_splash_view.rb`) patched the Xcode project in the past. They are not part of the normal build.

## Handoff docs

- [CONTRIBUTING.md](CONTRIBUTING.md) — branch/PR habits, localization, App Store / monetization hold
- [AGENTS.md](AGENTS.md) — short context for an AI coding tool picking this up elsewhere
