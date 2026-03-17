# PastePath

PastePath is a macOS menu-bar helper for terminal-first workflows. When `cmd+v` is pressed with an image on the clipboard, it saves that image into a `copied/` folder inside the active workspace and types a text reference back into the focused terminal-style input.

## What It Does

- Watches for `cmd+v` with a clipboard image
- Saves images as `copied/clipboard-image-YYYYMMDD-HHMMSS.png`
- Resolves the workspace automatically for Terminal and iTerm2
- Supports VS Code only when the focused surface looks like a terminal or Codex-style TUI
- Types back a message in this format:

```text
reference to the image is at /absolute/path/to/copied/image.png
```

## Status

Current target:

- Terminal.app
- iTerm2
- Terminal-like workflows hosted inside VS Code

Current non-goals:

- Rich paste handling for the regular Codex chat GUI
- Fully generic support for every macOS editor surface

## Permissions

The app needs:

- Accessibility access: required for the global key event tap and synthetic paste
- Automation permission: needed when asking Terminal or iTerm2 for the active TTY

## Logs

Runtime logs are written to:

`~/Library/Logs/PastePath.log`

To watch them live while testing:

```bash
tail -f ~/Library/Logs/PastePath.log
```

## Build

From the repo root:

```bash
./build-pastepath.sh
```

To build and run it in the current terminal with live logs:

```bash
./build-pastepath.sh --run
```

To install it as a background service that starts at login:

```bash
./build-pastepath.sh --install-service
```

To inspect the service:

```bash
./build-pastepath.sh --service-status
```

To remove the service:

```bash
./build-pastepath.sh --uninstall-service
```

## Install

For stable local use, copy the built app into `/Applications` and approve Accessibility there:

```bash
cp -R "/Users/rohan/Documents/New project/macos-paste-helper/dist/PastePath.app" /Applications/PastePath.app
```

Then open `/Applications/PastePath.app`, grant Accessibility access in System Settings, and test before enabling the background service.

## Direct Build

```bash
cd /Users/rohan/Documents/New\ project/macos-paste-helper
./scripts/build-release.sh
```

The packaged app will be created at:

`/Users/rohan/Documents/New project/macos-paste-helper/dist/PastePath.app`

The LaunchAgent is installed at:

`~/Library/LaunchAgents/com.codex.pastepath.plist`
