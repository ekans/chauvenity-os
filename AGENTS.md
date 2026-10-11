# Testing UI changes

The user works in a live niri session on the machine you run on. Never start
niri, qs or any GUI app on their `WAYLAND_DISPLAY`, because the window takes their
focus. Never `pkill -f` a pattern such as `qs -c chauvenity`, which also
matches their real bar. To see a niri, Quickshell or Wayland change, use
`niri-sandbox` (the `niri-sandbox` skill, or the header of
`files/system/usr/bin/niri-sandbox`).
