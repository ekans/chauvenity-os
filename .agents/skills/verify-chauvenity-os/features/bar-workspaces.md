# Bar: workspaces

The left of the bar shows one pill per workspace on its output, labelled with
the workspace's name or index. The focused workspace is a filled blue pill;
the other active-but-unfocused workspaces are bright; the rest are dim. The
pills follow niri as the user moves between workspaces, and a click on one
focuses it.

## Sub-features

- `ws-list` shows one pill per workspace of this output, in index order, including niri's empty trailing one.
- `ws-focus` lights only the focused workspace, and un-lights the one left behind.
- `ws-new` adds a pill when a window lands on the empty trailing workspace.
- `ws-click` focuses the clicked workspace (pointer only).
- `ws-per-output` lists only this output's workspaces on each monitor's bar.

## How to get to it (user POV)

- Look at the left end of the bar on any output.
- Switch workspace with `Mod+1`…`Mod+9`, `Mod+Page_Up`/`Page_Down`, `Mod+U`/`Mod+I`.
- Move a window to another workspace with `Mod+Ctrl+1`…`9`, `Mod+Ctrl+U`/`I`.
- Click a pill.

## Driving it with desk

Preconditions:

- `$desk bar` printed `bar up`, and `$desk doctor` exits 0.
- The sandbox starts with one workspace, `1`, focused, and no windows.

- **Initial list.** Look at the bar. Run `$desk shot bar-workspaces/01-start` and `$desk state bar-workspaces/01-start`. One pill `1`, filled blue; the JSON has one workspace, `is_focused: true`.
- **Open a window.** Start a terminal. Run `$desk run niri msg action spawn -- ghostty --title=ws-one`, then wait until `$desk run niri msg --json windows` lists `ws-one`. A second, dim pill `2` appears: niri always keeps an empty workspace after the last used one.
- **Switch workspace.** Press `Mod+2`. Run `$desk run niri msg action focus-workspace 2`, then `$desk shot bar-workspaces/02-ws2` and `$desk state bar-workspaces/02-ws2`. Pill `2` is filled and pill `1` is dim, not bright; the JSON has workspace 2 `is_focused: true` and workspace 1 `is_active: false`.
- **New workspace.** On workspace 2, open a second window. Run `$desk run niri msg action spawn -- ghostty --title=ws-two` and wait for it in `niri msg --json windows`, then `$desk shot bar-workspaces/03-ws-new` and `$desk state bar-workspaces/03-ws-new`. Three pills, `1` dim, `2` filled, `3` dim: niri added an empty workspace after the one that just got a window.
- **Return.** Press `Mod+1`. Run `$desk run niri msg action focus-workspace 1`, then `$desk shot bar-workspaces/04-back` and `$desk state bar-workspaces/04-back`. Only pill `1` is filled; no other pill stays lit.
- **Proof.** Run `$desk log bar-workspaces/qs`. The four screenshots and the JSON at each step agree on which workspace is focused, and the log has `Configuration Loaded` and no QML error.

## Gotchas

- `wtype -M logo -k 2` does nothing to niri: binds only fire from real input. Drive the action with `niri msg action`, and prove the bind itself in [niri-config.md](./niri-config.md).
- `ws-click` cannot be driven: there is no pointer in the sandbox that does not also move the real session's (`ydotool` writes to the real uinput). Report it skipped.
- `ws-per-output` cannot be proven: the sandbox has one output, `winit`. Report it skipped, or say it was proven only for one output.
- The regression worth catching is a pill that stays lit after focus moves away (niri's `WorkspaceActivated` event names only the new workspace). Always prove the *previous* pill went dim, not only that the new one lit up.
- niri removes an empty workspace that is not the last one as soon as focus leaves it, so the pill count changes as you go. Assert against `niri msg --json workspaces`, not a count you expected.
- Moving the only window of a workspace down (`move-column-to-workspace-down`) changes nothing you can see: niri drops the emptied workspace and the window ends up on workspace `1` again, with new workspace ids. Use two windows to prove a move.
