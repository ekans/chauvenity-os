# Testing UI changes

The user works in a live niri session on the machine you run on. Never start
niri, qs or any GUI app on their `WAYLAND_DISPLAY`, because the window takes their
focus. Never `pkill -f` a pattern such as `qs -c chauvenity`, which also
matches their real bar. To look at a change, use `niri-sandbox`. It runs niri
inside `mutter --headless`, so nothing appears on screen:

```bash
export NIRI_SANDBOX=$BB_THREAD_ID                                  # one sandbox per thread
niri-sandbox up -c "$PWD/files/system/etc/niri/config.kdl"         # this worktree's niri config
niri-sandbox spawn qs -p "$PWD/files/system/etc/xdg/quickshell/chauvenity"   # this worktree's bar
niri-sandbox run niri msg layers                                   # also: qs ipc, wtype, wl-copy
niri-sandbox shot                                                  # prints a PNG path to read
niri-sandbox down
```

The sandbox has its own Wayland display, runtime dir, session bus and state
dir, so `qs ipc`, notifications, the tray and the clipboard stay inside it.
Audio and the system bus are the real ones. Read them, but leave the user's
volume and devices alone. If `niri-sandbox` is not on PATH, the installed image
predates it, so run `files/system/usr/bin/niri-sandbox` from the repo root.
