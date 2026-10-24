# Contributing

Portable notes for a human or coding agent on another machine. Product facts and how to build: [README.md](README.md). Agent constraints: [AGENTS.md](AGENTS.md).

## Branching and PRs

- Default branch is **`main`**.
- Work on a feature branch; open a PR **into `main`**.
- Recent branches look like `cursor/<topic>` (sometimes with a short suffix). That naming is a habit, not a required prefix.
- Keep PRs focused. Do not mix app-code changes with unrelated docs or preview-image churn.
- There is no PR template and no required GitHub Actions check for the iOS target.

## Where source lives

| Path | Role |
| --- | --- |
| `MedTracker/` | App: `MedTrackerApp.swift`, `ContentView.swift`, `Views/`, `Models/` |
| `MedTrackerWidget/` | WidgetKit extension (compiled against shared models + `AppLocalization`) |
| `MedTracker/Localizable.xcstrings` | String catalog (en + zh-Hant) |
| `MedTracker/GeneratedLocalizations.swift` | Generated dictionaries — **do not hand-edit as the source of truth** |
| `MedTracker/AppLocalization.swift` | In-app language (`system` / `en` / `zh-Hant`) via App Group defaults |
| `MedTracker/PrivacyInfo.xcprivacy` | Privacy manifest (empty collected-data list) |
| `docs/*.html` | GitHub Pages only (`main` / `docs` folder) |

SwiftData models: `UserProfile`, `MedicationLog`. Shared store: `MedTracker/Models/SharedDatabase.swift`.

## Localization

UI must ship in **English and 繁體中文**.

1. Add or change keys in `MedTracker/Localizable.xcstrings` (both locales).
2. Keep `GeneratedLocalizations.swift` in sync. `AppLocalization.string` / `.format` read those Swift dictionaries so 繁中 works with the in-app language toggle, not only the system locale.
3. The Swift file header says it is auto-generated; there is **no generate script in this repo**. After catalog edits, regenerate or update the dictionaries so both files match.
4. Home-screen name and permission strings: `MedTracker/en.lproj/InfoPlist.strings` and `MedTracker/zh-Hant.lproj/InfoPlist.strings`.

Display names: **PillPal** (EN) · **藥伴伴** (zh-Hant). Elder Mode’s zh label is **樂齡模式**.

## App Store Connect

This git repo is **not** the App Store pipeline.

- Do **not** upload, submit, or release a build from an agent session unless Boris explicitly asks.
- Privacy Nutrition Labels, Accessibility Nutrition Labels, pricing, and review notes live in ASC, not here.
- Screenshots for listings are under `AppStorePreviews/`.

## Monetization

**Stay free.** Do not add StoreKit, subscriptions, or IAP unless the product decision is revisited in writing.

## Product constraints (do not regress)

- On-device only — no cloud backend or developer-operated sync for app data
- Keep EN + 繁中 on user-facing strings
- Do not reintroduce Medical Card **QR share** in the app UI (`showMedicalCardQR` on the model is leftover schema; `docs/mc.html` is a static viewer)
- Not a medical device — no diagnosis, dosing calculators, or drug-interaction checkers
- Light UI only (`UIUserInterfaceStyle` / `.preferredColorScheme(.light)`)

## Version bumps

When a store build is intended, set **both** the app and widget targets in `project.pbxproj` to the same `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
