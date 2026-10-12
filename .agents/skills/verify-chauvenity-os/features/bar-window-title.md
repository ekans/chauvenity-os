# Bar: window title

The centre of the bar shows the focused window's title, dim, elided past 40%
of the bar's width, and as plain text: markup in a title is shown literally,
never rendered. Moving focus to an empty workspace clears it.

## Sub-features

- `title-show` shows the focused window's title.
- `title-follow` changes when focus moves to another window.
- `title-clear` empties when focus moves to an empty workspace, and comes back on return.
- `title-plain` shows markup such as `<b>x</b>` literally and fetches nothing.
- `title-elide` elides a long title instead of overlapping the clock.

## How to get to it (user POV)

- Focus a window (open one, or `Mod+Left`/`Mod+Right`, `Mod+H`/`Mod+L`).
- Switch to an empty workspace (`Mod+2` with nothing on it).

## Driving it with desk

Preconditions:

- `$desk bar` printed `bar up`, and `$desk doctor` exits 0.
- No windows are open (`$desk run niri msg --json windows` prints `[]`).

- **Show.** Open a window. Run `$desk run niri msg action spawn -- ghostty --title=title-one` and wait until it is in `niri msg --json windows`. Run `$desk shot bar-window-title/01-one`. The bar's centre reads `title-one`.
- **Follow.** Open a second window and focus between them. Run `$desk run niri msg action spawn -- ghostty --title=title-two`, wait for it, then `$desk run niri msg action focus-column-left` and `$desk shot bar-window-title/02-left`. The centre reads `title-one`; `niri msg --json focused-window` agrees.
- **Plain text.** Open a window whose title is markup. Run `$desk run niri msg action spawn -- ghostty '--title=<b>bold</b> <img src="http://127.0.0.1:9/x.png">'` and `$desk shot bar-window-title/03-markup`. The centre shows the angle brackets literally, in the normal weight, and no image.
- **Elide.** Open a window with a long title. Run `$desk run niri msg action spawn -- ghostty "--title=$(printf 'long-title-%.0s' {1..30})"` and `$desk shot bar-window-title/04-long`. The title ends in `…` and stops well short of the clock.
- **Clear.** Move to the empty workspace. Run `$desk run niri msg action focus-workspace-down`, check `niri msg --json focused-window` prints `null`, then `$desk shot bar-window-title/05-empty`. The centre is empty.
- **Proof.** Return with `$desk run niri msg action focus-workspace-up`, take `$desk shot bar-window-title/06-back` (a title is back), then `$desk log bar-window-title/qs`.

## Gotchas

- ghostty may rewrite its title once its shell starts (a shell prompt sets the title on many setups). Take the screenshot right after the window appears, and confirm the title in `niri msg --json windows` at that moment.
- `--title=` with a space needs the whole argument quoted, or ghostty receives two arguments.
- The empty-workspace case is the one that regresses: Quickshell keeps the last window as `activeToplevel` until it closes. A title still shown on an empty workspace is the bug.
