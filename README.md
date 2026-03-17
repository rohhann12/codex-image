# PastePath

PastePath is a macOS helper that turns image paste into a terminal-friendly file reference.

When you press `cmd+v` with an image on the clipboard, PastePath saves the image into a `copied/` folder inside the active workspace and types back:

```text
reference to the image is at /absolute/path/to/copied/image.png
```

## Setup

1. Open this folder:

```bash
cd "/Users/rohan/Documents/New project/pastepath"
```

2. Build the app:

```bash
./build-pastepath.sh
```

3. Copy the app into `/Applications`:

```bash
cp -R "./macos-paste-helper/dist/PastePath.app" /Applications/PastePath.app
```

4. Open `PastePath.app` from `/Applications`.

5. In macOS, enable:
   `System Settings -> Privacy & Security -> Accessibility -> PastePath`

## Test

1. Create the log file and watch it:

```bash
touch ~/Library/Logs/PastePath.log
tail -f ~/Library/Logs/PastePath.log
```

2. Focus a supported terminal-style input.

3. Copy an image.

4. Press `cmd+v`.

## Notes

- Best supported: Terminal and iTerm2
- Experimental: VS Code-hosted terminal / Codex TUI detection
- The regular Codex GUI chat input is not the main target

