# Bar: status line

The right of the bar shows, left to right, the default audio sink's volume
(`vol 50%`, or `vol muted`), the laptop battery (`68%`, with ` +` while
charging; hidden on a machine without one) and the clock
(`Mon 12 Oct  15:40`, ticking per minute).

## Sub-features

- `status-volume` shows the default sink's volume as a whole percentage, or `vol muted`.
- `status-battery` shows the battery percentage, ` +` when charging, nothing without a laptop battery.
- `status-clock` shows `ddd d MMM  HH:mm` and changes on the minute.

## How to get to it (user POV)

- Look at the right end of the bar.
- Change the volume with the media keys or any mixer, or plug in the charger, and watch it change.

## Driving it with desk

Preconditions:

- `$desk bar` printed `bar up`, and `$desk doctor` exits 0.
- The sandbox shares the machine's real PipeWire and UPower. Read them; do not change them.

- **Read.** Look at the right end of the bar. Run `$desk shot bar-status/01-now`. It shows `vol N%`, a battery percentage, and the date and time.
- **Volume source.** Read the same sink. Run `wpctl get-volume @DEFAULT_AUDIO_SINK@ | tee "$OUT/bar-status/wpctl.txt"`. `Volume: 0.50` matches `vol 50%`; a trailing `[MUTED]` matches `vol muted`.
- **Battery source.** Read the same device. Run `upower -i /org/freedesktop/UPower/devices/DisplayDevice | tee "$OUT/bar-status/upower.txt"`. Its `percentage` matches the bar's, and `state: charging` matches a trailing ` +`.
- **Clock ticks.** Wait for the minute to change and look again. Run `sleep $((61 - $(date +%-S)))` then `$desk shot bar-status/02-next-minute`. The minute moved by one and matches `date '+%a %-d %b  %H:%M'`.
- **Proof.** Run `$desk log bar-status/qs`. Both screenshots, the two readings and the log are under `$OUT/bar-status/`.

## Gotchas

- Never run `wpctl set-volume`, `wpctl set-mute`, `brightnessctl` or the media-key actions to make the volume change: it is the user's real audio. A live change of the volume can only be proven if the user changes it themselves; otherwise report `status-volume` as proven for the current value only.
- Charging cannot be toggled from software. Prove ` +` only if the charger state happens to be `charging`, and say which state you saw.
- Battery and volume can move between the screenshot and the reading by a percent. Take the reading right after the screenshot.
- The clock has two spaces between the month and the time; compare against `date` with the same format, not by eye.
