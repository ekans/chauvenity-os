# Login greeter

The login screen greetd shows: the lock screen's face, with the time at the
top, embers rising from the bottom, a faint ember in the middle that becomes a
ring of fireflies, one per typed character, and `ducatore · niri` underneath.
Enter logs in, a wrong password sinks the fireflies as grey ash with
`Wrong password`, Tab and Shift+Tab pick the session, Escape gives up
on an attempt greetd has not answered, and Ctrl+Alt+Del opens a power menu.

## Sub-features

- `greet-idle` shows the clock, the rising embers, the faint ember in the middle, `ducatore · niri` and the hint `Tab session · Ctrl+Alt+Del power`.
- `greet-typing` lights one firefly per character on a ring around the middle, up to 16.
- `greet-wrong` refuses a wrong password with `Wrong password`, sinks the fireflies as grey ash, and settles back after about 1.5 s.
- `greet-escape` cancels an attempt greetd never answers, back to the single ember.
- `greet-session` cycles the session with Tab: niri first, then GNOME, GNOME Classic.
- `greet-power` opens the power menu on Ctrl+Alt+Del, where Enter does not log in and Esc closes it.
- `greet-login` asks greetd to start the chosen session after the right password, turns the fireflies and embers green and flies them outward, then quits.
- `greet-sleep` stops every animation after 20 s with no key (`SLEEP_MS` in `chauvenity-lock/lock.mjs`), once the last ember has burnt out; any key relights it.
- `greet-no-greetd` shows `Could not check the password — try again` when greetd is not there.

## How to get to it (user POV)

- Boot or log out: greetd shows it on VT 1.
- Type the password and press Enter; Tab or Shift+Tab before Enter to change session.
- Press Ctrl+Alt+Del for suspend, reboot and power off.

## Driving it with desk

Preconditions:

- The fake greetd exists: `~/.config/quickshell/chauvenity-greeter/tests/fake-greetd.mjs`, from ekans/dotfiles via chezmoi, or a path in `FAKE_GREETD`.
- `$desk greeter` printed `greeter up ... password 'hunter2'`, and `$desk doctor` shows `greetd fake` and the layer `chauvenity-greeter`.
- The greeter starts from a fresh sandbox (`$desk down` first if one was running): it quits after a login.

- **Idle.** Look at the screen. Run `$desk shot greeter-login/01-idle`. The clock, the faint ember in the middle, rising embers, `ducatore · niri` and the hint line.
- **Typing.** Type `wrong7`. Run `$desk run wtype wrong7`, then `$desk shot greeter-login/02-typing`. Six fireflies on a ring.
- **Wrong password.** Press Enter. Run `$desk run wtype -k Return`, then within half a second `$desk shot greeter-login/03-wrong`. Grey fireflies sinking and `Wrong password`; `$OUT/greetd.log` gains `create_session` then `"correct":false`.
- **Escape a stalled attempt.** Wait 2 s for the screen to settle, type `stall` and Enter (the fake greetd never answers that one), then Escape. Run `$desk run wtype stall`, `$desk run wtype -k Return`, wait 0.4 s, `$desk shot greeter-login/04-checking`, `$desk run wtype -k Escape`, `$desk shot greeter-login/05-escaped`. The ring of fireflies spinning fast, then the single ember again; the log gains `"stalled":true` and `cancel_session`.
- **Pick GNOME.** Press Tab. Run `$desk run wtype -k Tab`, then `$desk shot greeter-login/06-gnome`. The line reads `ducatore · GNOME`.
- **Power menu.** Type `zz`, press Ctrl+Alt+Del, then Enter. Run `$desk run wtype zz`, `$desk run wtype -M ctrl -M alt -k Delete -m alt -m ctrl`, `$desk shot greeter-login/07-power`, `$desk run wtype -k Return`. The hint reads `S suspend · R reboot · P power off · Esc back`, and the log gains no `create_session` from the Enter.
- **Close the menu and clear.** Press Escape twice. Run `$desk run wtype -k Escape` twice. The first closes the menu (the hint returns), the second puts out the fireflies.
- **Log in.** Type `hunter2` and Enter. Run `$desk run wtype hunter2`, `$desk run wtype -k Return`, then within a second `$desk shot greeter-login/08-success`. Green embers rushing up (the fireflies have already flown out), and `ducatore · GNOME`.
- **Proof.** After 4 s, `$desk run qs list --all` prints `No running instances.` (the greeter quit), and `$OUT/greetd.log` ends with `start_session` and `"cmd":["/usr/bin/gnome-session"]`. Count `create_session` lines: 3 (wrong, stall, hunter2); a 4th means Enter in the power menu tried to log in.
- **No greetd.** Separately, prove `greet-no-greetd`: `$desk down`, then `$desk bar`, then `$desk run niri msg action spawn -- qs -p "$PWD/files/system/etc/xdg/quickshell/chauvenity-greeter"`, type `x` and Enter. The red line reads `Could not check the password — try again`.

## Gotchas

- The scene sleeps 20 s after the last key, once the last ember has burnt out, about 33 s in all. Frames that stop changing after that are expected; press a key before a shot that should move.
- **Never press `s`, `r` or `p` while the power menu is open.** The greeter runs `systemctl suspend|reboot|poweroff` on the real system bus: it suspends, reboots or powers off the user's machine. Prove `greet-power` with the hint text and Escape only.
- Escape cancels only an attempt greetd is still checking. On a wrong password the row is already empty, so Escape after `03-wrong` proves nothing; that is why the `stall` password exists.
- Type the next password only after the wrong-password shake settles (about 1.5 s). Keys sent while the state is `checking` are dropped.
- The fake greetd keeps running after the greeter quits, and its log accumulates across greeter runs in the same `$OUT`. Use a fresh `VERIFY_OUT` (or delete `greetd.log`) per proof, and `$desk down` stops it.
- A passing run's `qs.log` has one `ERROR quickshell.service.greetd: Received unexpected greetd response "{\"type\":\"success\"}"` per cancelled attempt (the greetd's answer to `cancel_session`), and a `WARN qt.qpa.services: Failed to register with host portal`. Neither is a regression by itself; any other ERROR is worth reading.
- `$desk greeter` binds the fake greetd's password at its first start. To change it, `$desk down` first.
- The user name is `ducatore` unless `CHAUVENITY_GREETER_USER` is set; the session list comes from `/usr/share/wayland-sessions` unless `CHAUVENITY_GREETER_SESSIONS` points elsewhere.
- Unreachable here: the real greetd and its PAM stack (`password-auth`, the keyring unlock), SELinux labels, VT switching. Those need `mise run vm` ([image.md](./image.md)); report them skipped otherwise.
- The greeter in this repo is a copy of ekans/dotfiles' (`scripts/sync-greeter.sh`). A change made here and not in dotfiles is overwritten by the next sync; say so when proving one.
