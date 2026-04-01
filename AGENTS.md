# Repository Guidelines

## Project Structure & Module Organization

This repository is a Swift package for a macOS menu bar app.

- `Sources/BlablaApp/` contains app code.
- `Sources/BlablaApp/Models/` holds settings and domain types.
- `Sources/BlablaApp/Services/` contains hotkeys, audio capture, transcription, Keychain, and pasteboard logic.
- `Sources/BlablaApp/UI/` contains SwiftUI views for the menu bar, widget, settings, and shortcut capture.
- `Tests/BlablaTests/` contains package tests using Swift Testing.
- `scripts/build_app.sh` builds and bundles `dist/Blabla.app`.

Keep new code in the existing layer that owns the behavior; avoid mixing UI and service logic in the same file.

## Build, Test, and Development Commands

- `swift build -c debug --product Blabla` builds the app binary for local development.
- `swift test` runs the package test suite.
- `./scripts/build_app.sh debug` builds and bundles a local app at `dist/Blabla.app`.
- `./scripts/build_app.sh release` produces the release-style app bundle.
- `open dist/Blabla.app` launches the bundled app for manual testing.

Use the build script when verifying installability from a clean clone. Launch the `.app` bundle, not `dist/Blabla.app/Contents/MacOS/Blabla`, because macOS permissions are more reliable at the bundle level. For repeated local testing, copying `dist/Blabla.app` to `/Applications/Blabla.app` gives a more stable path for TCC prompts.

## Coding Style & Naming Conventions

- Use 4-space indentation and standard Swift formatting.
- Prefer one primary type per file.
- Use `UpperCamelCase` for types and `lowerCamelCase` for methods, properties, and locals.
- Name services by responsibility, for example `TranscriptionService` or `HotKeyManager`.
- Keep comments sparse and only where behavior is non-obvious.

No formatter or linter is configured yet; match the surrounding style and keep imports minimal.

## Testing Guidelines

- Write tests in `Tests/BlablaTests/` with the Swift `Testing` module.
- Name test files after the target type or subsystem, for example `TranscriptionModelTests.swift`.
- Prefer focused tests for pure logic and request construction.
- Run `swift test` before opening a PR.

GUI behavior, macOS permissions, microphone access, and live API calls are not currently covered by automated tests; note manual verification in your PR.

When changes touch `auto-insert`, hotkeys, microphone capture, or the floating widget, manually verify the flow in at least `TextEdit` and `Terminal`.

## Commit & Pull Request Guidelines

The visible history only includes `Initial commit`, so there is no strong legacy convention yet. Use short, imperative commit subjects, for example `Add OpenAI transcription retry handling`.

PRs should include:

- a concise summary of behavior changes
- manual test notes for macOS permissions and app flow
- screenshots or short recordings for UI changes
- linked issues or task references when applicable

## Security & Configuration Tips

- Never commit API keys or `.env` files.
- Store OpenAI and Mistral keys in macOS Keychain through the app settings.
- Do not weaken clipboard or accessibility safeguards without explicitly documenting the change.
- Expect Accessibility and Microphone permissions to be granted again on another Mac, or after TCC resets during debugging.
