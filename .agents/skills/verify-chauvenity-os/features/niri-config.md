# niri config and keybinds

The niri session ships `/etc/niri/config.kdl`: the keybinds (launch ghostty and
fuzzel, lock with swaylock, focus/move columns and workspaces, sizing,
screenshots, quit), the layout (12 px gaps, a blue focus ring, rounded
corners), the "Important Hotkeys" overlay on `Mod+Shift+/`, and live reload: a
saved config applies without logging out.

## Sub-features

- `cfg-valid` the shipped config, and the greeter's, parse.
- `cfg-overlay` the hotkey overlay lists the titled binds (terminal, launcher, lock) and hides unbound actions.
- `cfg-bind-action` a bind's action does what its title says when run.
- `cfg-layout` windows tile with the configured gaps, focus ring and corner radius.
- `cfg-reload` saving the config changes the running session.

## How to get to it (user POV)

- Press `Mod+Shift+/` for the overlay.
- Press any bind (`Mod+Return` for a terminal, `Mod+2` for workspace 2, …).
- Edit `~/.config/niri/config.kdl` (which includes `/etc/niri/config.kdl`) and save.

## Driving it with desk

Preconditions:

- `$desk bar` printed `bar up`, and `$desk doctor` shows this checkout's `config.kdl`.

- **Parse.** Validate both configs. Run `niri validate -c files/system/etc/niri/config.kdl` and `niri validate -c files/system/etc/greetd/niri.kdl`. Each ends in `config is valid` and exits 0.
- **Bind's action.** Pick the bind under test, read its action from `config.kdl`, and run that action. For `Mod+Return`: run `$desk run niri msg action spawn -- ghostty --title=bind-check`. `niri msg --json windows` lists it, with app id `com.mitchellh.ghostty`.
- **Layout.** With one window open, run `$desk shot niri-config/01-layout`. The window sits 12 px in from the bar and the left edge, with a blue 2 px ring and rounded corners.
- **Live reload.** Change one visible value in the checkout's `config.kdl` (for example `gaps 12` to `gaps 40`), save, and look again. Run `$desk shot niri-config/02-reloaded`. The gaps grew with no restart. Restore it with `git checkout -- files/system/etc/niri/config.kdl` unless that change is the one under test.
- **Overlay, last.** Press `Mod+Shift+/`. Run `$desk run niri msg action show-hotkey-overlay` and `$desk shot niri-config/03-overlay`. An "Important Hotkeys" box lists `Open a Terminal: ghostty`, `Run an Application: fuzzel` and `Lock the Screen: swaylock`, and no row for an action the config does not bind.
- **Proof.** Keep the validate output (`... 2>&1 | tee "$OUT/niri-config/validate.txt"`) with the screenshots.

## Gotchas

- `wtype` never fires niri binds. A bind is proven in two halves: it is in the config (and, if titled, in the overlay screenshot), and its action works through `niri msg action`. Say so; do not claim the key itself was pressed.
- In the sandbox `Mod` is `Alt`, so the overlay reads `Alt + Enter`. On the real session it is `Super`. That difference is niri's nested backend, not a regression.
- The sandbox wraps the config in its own `config.kdl` with `hotkey-overlay { skip-at-startup; }`, so the overlay never appears by itself at startup there. The shipped config does show it at login; that is unprovable here.
- Nothing in the sandbox closes the hotkey overlay: niri has no action to hide it, and `wtype` keys do not reach it. It then covers every later screenshot, the greeter's included. Show it last, then `$desk down && $desk bar` before anything else.
- A saved config that fails to parse leaves the old one running, with nothing on screen. Run `niri validate` before reading a reload screenshot.
- Binds that spawn `swaylock`, `fuzzel` or `brightnessctl`, and the `wpctl` media keys, act on real resources (a lock surface, the real backlight and audio). Do not run those actions; prove them from the config and the overlay only.
- `quit` (`Mod+Shift+E`, `Ctrl+Alt+Delete`) quits the sandbox's niri, which ends the run. Run it last if at all, then `$desk down`.
