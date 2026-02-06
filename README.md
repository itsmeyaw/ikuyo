# Ikuyo

Application to easily view the live departure times.

## Run the app from the latest build artifact
- Download the latest build artifact ZIP from the project's CI/build page (e.g., GitHub Actions or Releases).
- Extract the ZIP to reveal `Ikuyo.app`.
- Clear the macOS quarantine flag so the app can run: `xattr -r -d com.apple.quarantine "path/to/Ikuyo.app"`.
- Move the app into `/Applications` (drag-and-drop or `mv "path/to/Ikuyo.app" /Applications`).
- Launch the app from Applications. If macOS still warns about the developer, right-click > Open to trust it once.
- Optional: add Ikuyo to login items via System Settings → General → Login Items → click `+` and select Ikuyo.

## Develop in Xcode
- Requirements: macOS with Xcode (latest stable), SwiftPM enabled (handled automatically by Xcode).
- Clone the repo and open the project: `open Ikuyo.xcodeproj` (or via Xcode → Open). The workspace manages SwiftPM dependencies via `Package.resolved`.
- Select the `Ikuyo` scheme and target `My Mac` to run the macOS app. Select `widgetExtension` if you want to run the widget target.
- Press Run (⌘ + R) to build and launch; use Product → Archive for release builds.
- CI/build artifacts are expected to be zipped; ensure Release builds are archived via the `Ikuyo` scheme before distributing.