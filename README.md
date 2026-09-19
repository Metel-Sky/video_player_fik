# fik_player

Minimal macOS video player (Flutter + media_kit).

## Features (MVP)

- Open file / open folder playlist in a side panel
- First-frame thumbnails in the playlist
- Play/pause, scrubber, seek ±5 seconds
- Subtitle toggle (embedded or sibling `.srt`/`.vtt`/`.ass`)
- Drag & drop files/folders
- Register as a video viewer via Finder “Open With”

## Run

```bash
flutter run -d macos
```

Shortcuts: `Space` play/pause, `←`/`→` ±5s, `⌘O` open file, `⇧⌘O` open folder, `⌘L` playlist, `⌘S` subtitles.
