# MacinTalk

A native macOS menu-bar dictation utility that transcribes speech on-device with Apple's SpeechAnalyzer API, cleans transcripts with Apple Intelligence (Foundation Models), and pastes polished text into the active app.

## Requirements

- Apple silicon Mac (M1 or later)
- macOS 26.0 or later
- Xcode 26.0 or later
- Apple Intelligence enabled in System Settings
- Microphone access
- Input Monitoring permission (for global hotkey)
- Accessibility / Post Event permission (for system-wide paste)

## Setup

1. Open `MacinTalk.xcodeproj` in Xcode 26.
2. Build and run the `MacinTalk` scheme.
3. On first launch, open **Setup** from the menu bar icon and grant all required permissions.
4. The first dictation may download speech recognition assets for your locale.

## Usage

### Opening the app

- Build and run in Xcode, or launch MacinTalk from Applications after archiving.
- The **main window** opens automatically on launch with a sidebar: **Home** and **Settings**.
- The **menu bar icon** stays available after closing the window. Use **Open MacinTalk** from the menu to reopen it.

### Dictating

Hold **Control + Option + Space**, speak, then release. MacinTalk will:

1. Transcribe your speech locally with SpeechAnalyzer
2. Clean filler words and grammar with Foundation Models (when available)
3. Paste the result into the previously focused app via clipboard + Cmd+V

If Apple Intelligence is unavailable, the raw transcript is pasted instead.

### Home

- See live dictation status and partial transcript while recording.
- Browse previous transcriptions (raw + cleaned text) stored locally on your Mac.
- Copy, delete, or clear history from the detail pane.

### Settings

- Choose a cleanup style: **Casual**, **Balanced**, or **Business**.
- Manage permissions and speech asset setup.

## Limitations (MVP)

- macOS only (no iOS target)
- English and other Apple-supported locales depend on installed speech assets
- Uses clipboard temporarily during paste (restored when possible)
- No dictation history, cloud fallback, or custom vocabulary
- Speech assets and Apple Intelligence models must be installed before fully offline use

## Development

```bash
xcodebuild -scheme MacinTalk -destination 'platform=macOS' build
xcodebuild -scheme MacinTalk -destination 'platform=macOS' test
```

## Architecture

- `DictationCoordinator` — state machine orchestrating record → clean → insert
- `SpeechAnalyzerService` — live microphone transcription via SpeechAnalyzer
- `FoundationModelCleaner` — on-device transcript cleanup with raw fallback
- `GlobalHotkeyMonitor` — CGEventTap hold-to-talk hotkey
- `PasteboardTextInserter` — clipboard-safe Cmd+V insertion
