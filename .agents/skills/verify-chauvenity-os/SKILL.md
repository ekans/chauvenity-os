---
name: verify-chauvenity-os
description: Drive chauvenity-os's niri desktop (the Quickshell bar, niri's config and keybinds, the greetd login greeter) inside a headless niri-sandbox and capture screenshots and niri state as proof; also covers the image pipeline (mise run verify). Use when you need to show that a change to files/system/etc/niri, files/system/etc/xdg/quickshell or files/system/etc/greetd works in the real desktop, or that a recipe change builds and boots.
---

# Verify chauvenity-os

chauvenity-os is a bootc image, so "the app" is two things:

- **The niri session** (primary): `files/system/etc/niri/config.kdl`, the bar
  in `files/system/etc/xdg/quickshell/chauvenity/`, and the login greeter in
  `.../quickshell/chauvenity-greeter/` (which draws `.../chauvenity-lock/`'s
  face). A user sees and touches these. You drive them in **niri-sandbox**:
  niri nested in `mutter --headless`, with its own Wayland display, runtime dir
  and session bus, so nothing appears on the user's screen.
- **The image** (secondary): recipes plus `files/`, built into podman and
  booted in a throwaway VM by `mise run verify`. See
  [features/image.md](features/image.md).

The user works in a live niri session **on this same machine**. Three rules
follow, and none has an exception:

- Never start niri, `qs` or any GUI app on their `WAYLAND_DISPLAY`. Go through
  `desk` (below) or `niri-sandbox`.
- Never kill by name or pattern (`pkill -f 'qs -c chauvenity'` kills their real
  bar). Stop only what you started, with `desk down`.
- Audio, UPower and the system bus are the real ones. Read them, never change
  them: no `wpctl set-*`, no `brightnessctl`, no `systemctl suspend`. This is why
  the greeter's power menu keys are off limits (see
  [features/greeter-login.md](features/greeter-login.md)).

## Helper: `desk`

`scripts/desk` wraps `niri-sandbox` for this checkout. It always loads **the
files of the checkout it sits in**, whatever your cwd, and names the sandbox
`$NIRI_SANDBOX`, default `$BB_THREAD_ID`, so parallel threads never share one.

```bash
desk=.agents/skills/verify-chauvenity-os/scripts/desk   # from the repo root
$desk bar                  # sandbox on this checkout's niri config, plus its bar
$desk greeter [PASSWORD]   # sandbox, a fake greetd (password hunter2) and this checkout's greeter
$desk doctor               # read-only: is this sandbox worth driving?
$desk run CMD...           # CMD as a client of the sandbox: niri msg, wtype, qs ipc
$desk shot NAME            # screenshot to $OUT/NAME.png and print the path
$desk state NAME           # niri's workspaces, windows, layers as JSON to $OUT/NAME.json
$desk log NAME             # every Quickshell instance's log to $OUT/NAME.log
$desk down                 # stop the sandbox and the fake greetd; $OUT stays
```

`$OUT` is `$VERIFY_OUT` if set, else
`~/.local/state/verify-chauvenity-os/<sandbox>/`. `NAME` may contain slashes
(`bar-workspaces/02-ws2`); missing directories are created. `run`, `shot` and
`state` refuse to act on a stopped sandbox rather than start an empty one.

If `niri-sandbox` is not on PATH (an image older than it), `desk` uses
`files/system/usr/bin/niri-sandbox` from the checkout. `NIRI_SANDBOX_BIN`
forces one.

## Launch

```bash
$desk bar        # prints "bar up in sandbox <name>; evidence goes to <OUT>"
```

It is ready when that line prints: `desk` waits for niri to answer and for the
bar's layer surface (namespace `quickshell`) to exist, and exits 1 with a hint
after 10 s if it does not. Start-up is under 3 s. For the greeter, run
`$desk greeter` instead (layer namespace `chauvenity-greeter`). Both are
idempotent: a second call neither restarts niri nor stacks a second `qs`.

There is nothing to build. The sandbox reads the checkout's files directly,
and reloads them live: save `config.kdl` and niri re-reads it, save a `.qml`
file and Quickshell reloads it. So after an edit, just look again. Run
`$desk down && $desk bar` when you need a clean start (for example to prove
behavior at startup).

## Doctor

Run it first, and again whenever a screenshot looks wrong:

```bash
$desk doctor
```

It prints the checkout and commit (`, dirty` if tracked files changed), niri's
version, the config the sandbox includes, every Quickshell instance's config
path, the layer surfaces on screen, whether a fake greetd is up, and `$OUT`.
It exits 1, with a `FAIL` line, if the sandbox is not running or includes a
config other than this checkout's. A `WARN` line means a `qs` from outside the
checkout runs in the sandbox: you are not looking at your change.

Before you trust a change to niri's config, also run
`niri validate -c files/system/etc/niri/config.kdl` (and `.../greetd/niri.kdl`).
When a saved config fails to parse, the running niri keeps the old one, so the
sandbox shows the old behavior with no error on screen. When niri starts on one
(a fresh `desk bar`), it runs upstream's default config instead.

## Drive

Two input paths, and they are not interchangeable:

- **Compositor actions: `$desk run niri msg action <action>`.** Keys you send
  with `wtype` go to the focused client, **not** to niri's binds: `wtype -M logo
  -k 2` does not switch workspace. A keybind is proven in two halves: the bind
  exists in the config (and in the hotkey overlay), and its action does what it
  should when run through `niri msg action`. See
  [features/niri-config.md](features/niri-config.md).
- **Typing into a client: `$desk run wtype TEXT` and `$desk run wtype -k KEY`.**
  This is how the greeter is driven: it holds exclusive keyboard focus. Ctrl+Alt+Del
  reaches it too (`wtype -M ctrl -M alt -k Delete -m alt -m ctrl`), because niri's
  own `Ctrl+Alt+Delete { quit; }` bind never sees `wtype`.

There is no safe pointer: `ydotool` injects into the real session's uinput,
not the sandbox. Clicking a workspace pill cannot be driven; report that
sub-feature as skipped, with the reason, rather than proving it with
`niri msg action focus-workspace` and calling the click verified.

Open test windows through niri, so they start in niri's environment and stop
with the sandbox:

```bash
$desk run niri msg action spawn -- ghostty --title=verify-one
```

`ghostty` is the terminal the config binds (`Mod+Return`). It runs a real login
shell on the real filesystem: use it as a window with a title, never type
commands into it.

The sandbox has one output, `winit`, at about 1272×768, and niri's `Mod` is
`Alt` there (the hotkey overlay shows `Alt + Enter`, not `Super + Enter`).
Anything per-output (one bar per monitor, workspaces filtered by output) has
one output to show and cannot be proven multi-monitor here.

Two niri states cannot be left from the sandbox: the hotkey overlay (no action
hides it, and `wtype` keys do not reach it) and a quit niri. Do either last,
then `$desk down && $desk bar`.

Read state with `niri msg --json` (`workspaces`, `windows`, `focused-window`,
`layers`), or `$desk state NAME` for all three at once.

## Evidence

A proof is one directory under `$OUT`, named after the feature, containing:

- a screenshot **before** and **after** each user action (`$desk shot`), so the
  action and its result are both visible, not only the final screen;
- `$desk state` at the same moments: the screenshot shows what the bar draws,
  the JSON shows what niri believes, and a proof needs them to agree;
- for the greeter, `$OUT/greetd.log`: one JSON line per request greetd got,
  which is the side effect (what session the user was logged into);
- `$desk log NAME` before teardown: QML warnings and errors. Quickshell keeps
  its logs inside the sandbox, which `down` deletes.

Read every screenshot you cite (open the PNG); a path is not a proof.

Standards:

- Exercise the real path: the shipped QML and config from this checkout, real
  niri events, real keystrokes. Never set QML properties or call functions
  through a test hook, and never edit the QML to force a state.
- The one mock is the fake greetd, and only for the greeter: greetd's IPC is the
  production boundary. It speaks greetd's protocol on a socket of its own and
  never authenticates anyone. Nothing in the sandbox can reach the real greetd
  (whose socket is only handed to its greeter user).
- Volume and battery are the machine's real values. Prove them by reading the
  same source read-only (`wpctl get-volume @DEFAULT_AUDIO_SINK@`, `upower -i
  /org/freedesktop/UPower/devices/DisplayDevice`) next to the screenshot, never
  by changing them.
- Say what was skipped and why (pointer clicks, multiple outputs, a real
  greetd login, fingerprint): do not report it verified through another path.

## Cleanup

```bash
$desk down
ls "${VERIFY_OUT:-$HOME/.local/state/verify-chauvenity-os/${NIRI_SANDBOX:-$BB_THREAD_ID}}"
```

`down` stops the fake greetd's transient unit (`verify-greetd-<sandbox>`) and the
sandbox's (`niri-sandbox-<sandbox>`), which holds niri, mutter, the session bus
and everything spawned inside, then deletes the sandbox's runtime dir. It never
touches `$OUT`: the `ls` above must still list your evidence. Run `down` after
every failed attempt too, so a broken run does not leave a niri behind.

If you edited a tracked file to try something, restore it
(`git checkout -- <file>`); proof of a change you then revert is not proof of
the branch.

The image pipeline cleans up differently: `mise run clean` removes the VM and
the local image (see [features/image.md](features/image.md)).

## Feature map

[features/README.md](features/README.md) lists every user-facing feature with
its recipe. A proof that drives one convenient entry point is incomplete when
the map lists others: cover each entry point, or report the ones you skipped.
