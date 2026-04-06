# Blabla

Blabla is a macOS menu bar dictation app. It records from your microphone, sends the audio to a transcription API, copies the transcript to the clipboard, and can optionally auto-insert it at the current cursor location.

This repository is set up for people who want to build the app from source and install it on their own Mac.

## What Blabla Does

- Lives in the macOS menu bar instead of the Dock.
- Starts and stops recording with global shortcuts.
- Shows a floating widget with recording state, duration, level, language, microphone, provider, and model.
- Uploads audio to the selected provider API.
- Copies the transcript to the clipboard.
- Can auto-insert the transcript with Accessibility permission.

## Supported Providers

- OpenAI
  - `gpt-4o-transcribe`
  - `gpt-4o-mini-transcribe-2025-12-15`
- Mistral AI
  - `voxtral-mini-latest`

## Requirements

- macOS 14 or newer
- Swift 6.1 command line tools or a recent Xcode with Swift 6.1 support
- One API key:
  - OpenAI API key
  - Mistral API key

## Quick Install From a Git Clone

```bash
git clone <your-repo-url>
cd blabla
chmod +x ./scripts/build_app.sh
./scripts/build_app.sh release
rm -rf /Applications/Blabla.app
cp -R ./dist/Blabla.app /Applications/Blabla.app
open /Applications/Blabla.app
```

What this does:

- Builds the Swift package.
- Creates `dist/Blabla.app`.
- Writes the app `Info.plist`.
- Performs an ad-hoc codesign when possible.
- Installs the app into `/Applications` so it behaves more like a normal Mac app.

If you only want a local development build, you can use:

```bash
./scripts/build_app.sh debug
open ./dist/Blabla.app
```

Do not launch `dist/Blabla.app/Contents/MacOS/Blabla` directly. Open the `.app` bundle instead.

## First Launch and Permissions

1. Launch `/Applications/Blabla.app`.
2. Look for the Blabla icon in the menu bar.
3. Open `Settings…` from the menu bar app.
4. Save your OpenAI and/or Mistral API key in the app settings. Keys are stored in the macOS Keychain.
5. Choose your provider, model, language, microphone, and shortcuts.
6. Start a recording once to trigger the microphone permission prompt.
7. If you want `auto-insert`, enable it and grant Accessibility permission.

Important macOS behavior:

- If macOS warns that the app cannot be opened because it is locally built and not notarized, right-click the app in Finder and choose `Open`.
- You can also allow it in `System Settings > Privacy & Security`.
- If you do not see a Dock icon, that is expected. Blabla is a menu bar app.

## Permission Guide

### Microphone

Blabla needs microphone access to record audio.

- The prompt usually appears the first time you start recording.
- If needed, open `System Settings > Privacy & Security > Microphone` and allow `Blabla`.

### Accessibility

Blabla only needs Accessibility access for `auto-insert`.

- In Blabla settings, click `Request Permission`.
- Or open `System Settings > Privacy & Security > Accessibility` and enable `Blabla`.
- If Accessibility is not granted, transcription still works, but Blabla will only copy to the clipboard.

### Keychain

API keys are stored in the macOS Keychain, not in source files or `.env` files.

- Save keys in Blabla settings.
- Remove keys from Blabla settings if you want to switch accounts or clean up a machine.

## Easy Ways to Launch It

Once Blabla is installed in `/Applications`, you do not need to `cd` into the repository again just to open it.

Recommended launch options:

- Use Spotlight and type `Blabla`.
- Open `/Applications/Blabla.app` from Finder.
- Create a Finder alias: right-click `/Applications/Blabla.app`, choose `Make Alias`, then move that alias anywhere convenient.

If you want it to start automatically when you log in, add `/Applications/Blabla.app` to `System Settings > General > Login Items`.

## Default Shortcuts

- Start recording: `Control + Option + Space`
- Stop recording: `Control + Option + Return`

Both shortcuts are configurable in the settings window. Start and stop shortcuts must be different.

## Rebuild and Reinstall

If you pull new changes or want a fresh build, use this flow:

```bash
cd /path/to/blabla
./scripts/build_app.sh release
rm -rf /Applications/Blabla.app
cp -R ./dist/Blabla.app /Applications/Blabla.app
open /Applications/Blabla.app
```

Recommended process:

1. Quit Blabla from the menu bar first.
2. Rebuild with `release`.
3. Replace the copy in `/Applications`.
4. Reopen that `/Applications` copy.

Using `/Applications/Blabla.app` is the most stable path for permissions and relaunches.

## Uninstall

Basic uninstall:

1. Quit Blabla from the menu bar.
2. Delete `/Applications/Blabla.app`.

If you also want to remove saved settings, permissions, and API keys, do a full reset too.

## Full Reset and Clean Reinstall

Use this when permissions are stuck, settings are corrupted, or you want to start from a truly clean state.

1. Quit Blabla.
2. Remove the installed app from `/Applications`.
3. Clear app settings:

```bash
defaults delete com.astro.blabla || true
```

4. Remove saved API keys from Keychain:

```bash
security delete-generic-password -s com.astro.blabla -a openai_api_key || true
security delete-generic-password -s com.astro.blabla -a mistral_api_key || true
```

5. Reset permissions:

```bash
tccutil reset Microphone com.astro.blabla
tccutil reset Accessibility com.astro.blabla
```

6. Build and reinstall:

```bash
cd /path/to/blabla
./scripts/build_app.sh release
cp -R ./dist/Blabla.app /Applications/Blabla.app
open /Applications/Blabla.app
```

After a full reset, macOS should ask for permissions again when Blabla needs them.

## Troubleshooting

### The app will not open

Try this:

- Confirm you are opening `/Applications/Blabla.app` or `dist/Blabla.app`, not the raw binary inside the app bundle.
- Right-click the app in Finder and choose `Open`.
- Check `System Settings > Privacy & Security` for an `Open Anyway` prompt.
- Rebuild with `./scripts/build_app.sh release` and replace the copy in `/Applications`.

### The app opened, but I do not see anything

This is usually expected.

- Blabla is a menu bar app.
- Look for its icon in the menu bar.
- It does not appear as a normal Dock app by default.

### Recording fails or the microphone prompt never appears

Try this:

- Open `System Settings > Privacy & Security > Microphone` and make sure `Blabla` is enabled.
- In Blabla settings, verify the selected microphone.
- Reset microphone permission and relaunch:

```bash
tccutil reset Microphone com.astro.blabla
```

### Transcription works, but auto-insert does not paste into the target app

Try this:

- Make sure `Auto-insert after transcription` is enabled.
- Grant Accessibility permission in Blabla settings or in `System Settings > Privacy & Security > Accessibility`.
- Retry in a normal editable text field.
- Be aware that secure fields and some protected inputs intentionally block auto-insert. In those cases Blabla falls back to clipboard-only behavior.

### Hotkeys do not trigger

Try this:

- Make sure Blabla is running in the menu bar.
- Verify the start and stop shortcuts are different.
- Re-record the shortcuts in settings.
- Choose shortcuts that are less likely to conflict with macOS or another app.

### I saved a key, but transcription still fails

Check these:

- The selected provider must have its matching API key saved.
- If you switch between OpenAI and Mistral, each provider needs its own key.
- Remove and re-save the key if you suspect a bad paste or old credential.

### Reinstalling did not fix it

Do the full reset:

- Delete `/Applications/Blabla.app`
- Run:

```bash
defaults delete com.astro.blabla || true
security delete-generic-password -s com.astro.blabla -a openai_api_key || true
security delete-generic-password -s com.astro.blabla -a mistral_api_key || true
tccutil reset Microphone com.astro.blabla
tccutil reset Accessibility com.astro.blabla
```

- Rebuild and reinstall from a fresh `release` build.

## If Something Goes Wrong

If you get stuck, ask CloudCode or Codex to help fix the app.

When asking for help, include:

- your macOS version
- whether you are using OpenAI or Mistral
- the exact error message you saw
- whether the failure is about launch, microphone, hotkeys, auto-insert, or API keys
- the output of:

```bash
swift test
./scripts/build_app.sh release
```

That is usually enough context for CloudCode or Codex to diagnose and fix the issue quickly.

## Notes

- Maximum recording length is fixed at 15 minutes.
- The app uses provider APIs only. No local transcription model is bundled.
- The build script is the primary install path. Opening the package in Xcode is optional.
