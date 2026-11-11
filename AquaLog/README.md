# AquaLog starter app (SwiftUI)

This branch adds a native iOS/macOS SwiftUI app shell with a built-in Fit Score screen.

## Open in Xcode

1. Install Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) on a Mac.
2. At repository root, run `xcodegen generate`.
3. Open `AquaLog.xcodeproj`, select the `AquaLog` iOS or `AquaLogMac` macOS scheme, and run.
4. Use **Add tank**, save dated parameter tests, and select **Check animal Fit Score**.

The project definition is `project.yml`, so do not expect an Xcode project to exist until you generate it.

## Scope and safeguards

- Local-only tank and water-test storage via UserDefaults, with latest-reading selection.
- Native scoring module with visible range explanations, age warnings, unverified references, and hard-stop conditions.
- Eight **unverified sample animal profiles** to demonstrate the feature.
- No account login, cloud database, live user water data, or synchronized records yet.
- A separate Python reference module remains under `fit_score/` for algorithm exploration.

All taxonomy and care ranges need veterinary/husbandry source review before real stocking recommendations. A 100/100 chemistry match is not a safety clearance.

To go from a starter to a production release: add validated species references and citations, server-backed user accounts, aquarium persistence, group and tankmate checks, runtime tests on Xcode, accessibility review, and app-store readiness checks.
