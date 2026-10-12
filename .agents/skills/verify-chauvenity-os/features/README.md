# chauvenity-os verification map

This directory is the maintained source for verifying what a user of
chauvenity-os sees and touches. Read this index first, then use the matching
feature file as the recipe. Commands assume the repo root as cwd and
`desk=.agents/skills/verify-chauvenity-os/scripts/desk`.

## Baseline preconditions

- Never touch the user's live niri session: no GUI app or `qs` on their
  `WAYLAND_DISPLAY`, no `pkill` by name. Everything below runs in the sandbox
  named `$NIRI_SANDBOX` (default `$BB_THREAD_ID`).
- Start the sandbox from this checkout with `$desk bar` (bar features, niri
  config) or `$desk greeter` (login screen).
- `$desk doctor` exits 0 and lists this checkout's `config.kdl` and only this
  checkout's Quickshell config paths.
- `$OUT` is `$VERIFY_OUT`, or `~/.local/state/verify-chauvenity-os/<sandbox>/`.
- Never drive a sandbox that this run did not start, and never change the
  machine's volume, brightness or power state: they are real.

## Driving conventions

- Compositor actions go through `$desk run niri msg action <action>`. `wtype`
  never triggers niri's binds; it types into the focused client.
- Typing goes through `$desk run wtype TEXT` and `$desk run wtype -k KEY`.
- Open test windows with `$desk run niri msg action spawn -- ghostty --title=<title>`,
  and never type commands into them: the shell is real.
- Treat every command as literal. Keep quoted names and flags unchanged.
- Wait on state (`niri msg --json ...`, a layer namespace), not on a fixed
  sleep, except for animations, which the recipes time explicitly.
- Restore any tracked file you edited to try something (`git checkout -- <file>`).

## Proof and skip reporting

- Capture the action and the result: a screenshot and `$desk state` before
  and after each step, under `$OUT/<feature-id>/`.
- The screenshot and the JSON must agree: what the bar draws against what niri
  reports.
- A side effect needs its own record: `$OUT/greetd.log` for the greeter, a
  read-only `wpctl`/`upower` reading for the status line.
- Save `$desk log <feature-id>/qs` before `$desk down`, since Quickshell's logs
  are deleted with the sandbox.
- Open and read each screenshot you cite.
- Report an unreachable path with the attempted command and the unmet
  precondition. Pointer clicks, multiple outputs, a real greetd and the
  fingerprint reader are unreachable in the sandbox.
- Do not report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the
user-visible behavior. It then uses exactly four H2 sections in this order.

1. `Sub-features` lists short IDs with one line for each behavior.
2. `How to get to it (user POV)` lists every user entry point.
3. `Driving it with desk` starts with `Preconditions:` and uses labeled bullets
   that pair each user action with an exact command and observable result.
4. `Gotchas` lists traps that can waste or invalidate a verification run.

Keep implementation details out of the map. Name only user paths, stable
handles, required state, commands, and observable proof.

## Features

- [Bar: workspaces](./bar-workspaces.md) covers the workspace pills, which one is lit, and focus following niri.
- [Bar: window title](./bar-window-title.md) covers the focused window's title in the centre, and its clearing.
- [Bar: status line](./bar-status.md) covers volume, battery and the clock on the right.
- [niri config and keybinds](./niri-config.md) covers the shipped binds, the hotkey overlay, layout and live reload.
- [Login greeter](./greeter-login.md) covers password entry, wrong and right passwords, session choice, the power menu and Escape.
- [Image build and boot](./image.md) covers `mise run verify`: static checks, build, contract and a VM boot.
