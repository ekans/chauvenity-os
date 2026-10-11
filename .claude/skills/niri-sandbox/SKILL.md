---
name: niri-sandbox
description: Test a niri, Quickshell (qs) or other Wayland UI change by looking at it, without touching the user's live desktop. Use whenever you want to see, screenshot, click or type into a niri config, a Quickshell bar or overlay, or any Wayland app, including when you are tempted to start a nested niri window.
---

# Testing UI in a headless niri

The user works in a niri session on the same laptop you run on. A nested
`niri` started against their session opens a real window there. That window
steals their focus mid-typing. `niri-sandbox` instead runs niri inside
`mutter --headless`, which nothing displays. You get a real niri, with real
IPC and screenshots, and the user sees nothing.

## Commands

```bash
niri-sandbox up [-c CONFIG]   # start it, or point it at another niri config (live reload)
niri-sandbox spawn CMD...     # start a long-lived client inside it: qs -c chauvenity
niri-sandbox run CMD...       # one-shot client: niri msg, qs -c NAME ipc call, wtype, wl-copy
niri-sandbox shot [PATH]      # screenshot; prints the PNG path, read it with the Read tool
niri-sandbox down             # stop it and everything spawned in it
```

Every command but `down` starts the sandbox if needed. Prefix each call with
`NIRI_SANDBOX=$BB_THREAD_ID`, because parallel agents must not share one
sandbox and shell variables do not persist between your Bash calls.
`CONFIG` defaults to the user's `~/.config/niri/config.kdl`. Pass a worktree's
`files/system/etc/niri/config.kdl` to test an image change. Logs from spawned
clients are in `journalctl --user -u niri-sandbox-$BB_THREAD_ID`.

If `niri-sandbox` is not on PATH, the installed image predates it. Run
`files/system/usr/bin/niri-sandbox` from the repo root instead.

## What is shared and what is not

The sandbox has its own Wayland display, its own `XDG_RUNTIME_DIR`, its own
session D-Bus and its own `XDG_STATE_HOME`. So `qs ipc`, notifications, the
tray and the clipboard all stay inside it. A sandboxed bar shows an empty tray,
since the user's apps live on the real bus. Two things are real:

- Audio (PipeWire), so the volume widget renders. Read it, but leave the
  user's volume and devices as they are.
- The system bus (NetworkManager, UPower). It is read-only for a bar.

## Example

```bash
export NIRI_SANDBOX=$BB_THREAD_ID
niri-sandbox spawn qs -c chauvenity
sleep 3; niri-sandbox run niri msg layers
niri-sandbox shot
niri-sandbox down
```

Run `down` when you have finished looking. Stop and start only things inside
the sandbox. Never start niri, qs or any GUI app with the user's own
`WAYLAND_DISPLAY`. Never `pkill -f` a pattern such as `qs -c chauvenity`, which
also matches the user's real bar. Use `niri-sandbox` for every visual check.
