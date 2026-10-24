# Agent handoff

Read [README.md](README.md) first, then [CONTRIBUTING.md](CONTRIBUTING.md). This file is the short constraint list for another AI coding tool.

## Project

- App Store name **PillPal** · Xcode project **MedTracker** · zh name **藥伴伴**
- Current store version on `main`: **1.3.0** (build **18**) — confirm in `project.pbxproj` before writing version strings
- SwiftUI + on-device SwiftData + WidgetKit · iOS 17+
- Free, bilingual (EN + 繁中), no app cloud backend
- Open `MedTracker.xcodeproj`, scheme **MedTracker**. Signing needs an Apple team in Xcode.

## Do

- Keep user-facing copy in **both** `Localizable.xcstrings` and `GeneratedLocalizations.swift`
- Scope household work through `ActiveProfileStore` / `HouseholdData` (max 8 profiles)
- Keep medication photos and Visit Pack / export PDFs **on-device** (share sheet only when the user taps Share)
- Preserve Elder Mode / 樂齡 (larger type, 44pt-class tap targets) and VoiceOver labels on dose actions
- Prefer small PRs into `main`

## Do not

- Do **not** add StoreKit, IAP, subscriptions, ads, or analytics SDKs
- Do **not** add a cloud backend, CloudKit app database, or login
- Do **not** reintroduce Medical Card QR share / QR generation in the iOS UI
- Do **not** auto-submit or upload to App Store Connect
- Do **not** invent ASC Apple IDs, API keys, or secrets (none belong in this repo)
- Do **not** add drug-interaction checkers, drug encyclopedias, dosing calculators, AI chatbots, or social/community features
- Do **not** claim diagnosis or official medical-ID status
- Do **not** switch the app to Dark Mode
- Do **not** treat `docs/*.html` as app UI — GitHub Pages only; do not edit them unless a markdown link needs a real path

## Map

| Task | Start here |
| --- | --- |
| Today doses | `MedTracker/Views/HomeView.swift` |
| History | `MedTracker/Views/HistoryView.swift` |
| Profile / household / Elder Mode | `MedTracker/Views/ProfileView.swift`, `Models/ActiveProfileStore.swift` |
| Medical Card | `MedTracker/Views/MedicalCardView.swift` |
| Medication List PDF (Visit Pack) | `Models/VisitPack.swift`, `Views/VisitPackView.swift` |
| Reminders | `NotificationManager.swift` (actions Take / Snooze / Skip) |
| Med photos | `Views/MedicationIdentityViews.swift`, `Views/MedicationsSettingsView.swift` |
| Models | `Models/UserProfile.swift`, `Models/MedicationLog.swift`, `Models/SharedDatabase.swift` |
| Widget | `MedTrackerWidget/` |

## Cursor-only note

If still in Cursor and asked for App Store preview images, `.cursor/rules/higgsfield.mdc` says to use Higgsfield MCP and save under `AppStorePreviews/`. Other tools can ignore that file.
