# Blabla

Blabla is a macOS menu bar dictation app for Intel Macs. It records from your microphone, sends the audio to a transcription API, copies the transcript to the clipboard, and can auto-insert it at the current cursor location.

## Supported providers

- OpenAI
  - `gpt-4o-transcribe`
  - `gpt-4o-mini-transcribe-2025-12-15`
- Mistral AI
  - `voxtral-mini-latest`

## Product behavior

- Global hotkey starts recording.
- A floating widget shows recording state, duration, audio level, active language, microphone, provider, and model.
- A second global hotkey stops recording.
- The audio is uploaded to the selected API-only provider.
- The transcript is copied to the clipboard.
- If `auto-insert` is enabled, Blabla simulates `Cmd+V` in the frontmost app.
- If the focused element looks secure or non-editable, Blabla skips auto-insert and keeps clipboard-only behavior.

## Requirements

- macOS 15.x on Intel
- Swift 6 command line tools or Xcode
- One API key:
  - OpenAI API key
  - Mistral API key

## Build and install from a Git clone

```bash
git clone <your-repo-url>
cd blabla
chmod +x ./scripts/build_app.sh
./scripts/build_app.sh debug
open ./dist/Blabla.app
```

The script builds the Swift package, creates `dist/Blabla.app`, writes the app `Info.plist`, and performs an ad-hoc codesign when possible.

If you only want to test locally, launching `dist/Blabla.app` is enough. Do not launch `dist/Blabla.app/Contents/MacOS/Blabla` directly, because macOS permissions behave more reliably when the app is opened as a bundle.

For a more stable local install on your Mac, copy the built app into `/Applications` and always launch that copy:

```bash
cp -R ./dist/Blabla.app /Applications/Blabla.app
open /Applications/Blabla.app
```

If `/Applications/Blabla.app` already exists, quit Blabla first and replace the old copy before reopening it.

## First launch setup

1. Open `Blabla.app`.
2. Open `Settings…` from the menu bar icon.
3. Save your OpenAI and/or Mistral API keys into the macOS Keychain.
4. Pick your provider, model, language, microphone, and shortcuts.
5. If you want `auto-insert`, grant Accessibility permission when prompted.
6. Grant microphone permission on first recording.

If macOS blocks the app because it is locally built and not notarized, right-click the app in Finder and choose `Open`, or allow it in `System Settings > Privacy & Security`.

## Default shortcuts

- Start recording: `Control + Option + Space`
- Stop recording: `Control + Option + Return`

Both shortcuts are configurable in the settings window.

## Notes

- Maximum recording length is fixed at 15 minutes.
- The app uses API endpoints only. No local transcription model is bundled.
- The build script is the primary install path. Opening the package in Xcode is optional, not required.
