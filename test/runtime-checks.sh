# shellcheck shell=bash disable=SC2016  # $... in a check expands inside the VM, not here
# Checks on a booted system, shared by test/boot.sh (ephemeral VM) and
# scripts/vm.sh (installed VM). Each defines `check NAME COMMAND`, running
# COMMAND inside its VM, then sources this file.

check 'boot finished' 's=$(timeout 300 systemctl is-system-running --wait); [ "$s" = running ] || [ "$s" = degraded ] || { echo "$s"; exit 1; }'
# Both fail in any VM, bluefin-dx's own included: mcelog has no machine-check
# hardware, and the ephemeral VM has no bootloader to update.
check 'no failed units' 'failed=$(systemctl --failed --no-legend --plain | awk "{print \$1}" | grep -vxE "bootloader-update\.service|mcelog\.service"); for u in $failed; do systemctl status --no-pager -n 20 "$u"; done; [ -z "$failed" ]'
check 'graphical.target reached' 'systemctl is-active graphical.target'
check 'greetd running'           'systemctl is-active greetd.service'
check 'display-manager is greetd' '[ "$(systemctl show -p Id --value display-manager.service)" = greetd.service ]'
check 'gdm not running'          '! systemctl is-active gdm.service'
# niri has no output in a VM without 3D, so the greeter draws nothing here, but
# it is started and stays up; what only a screen shows is in the README.
check 'greeter runs as greetd'   'sleep 5; pgrep -u greetd -x niri >/dev/null && pgrep -u greetd -x qs >/dev/null'
check 'greeter user manager is healthy' 'u=$(id -u greetd); test -d /var/lib/greetd; f=$(runuser -u greetd -- env XDG_RUNTIME_DIR=/run/user/$u systemctl --user --failed --no-legend --plain); echo "$f"; [ -z "$f" ]'

# /opt apps live in /usr/lib/opt; tmpfiles links them into /var/opt at boot.
check 'brave-browser runs from /opt' 'brave-browser --version'
check '/opt 1Password keeps setuid'  'test -u /opt/1Password/chrome-sandbox'

# sysusers creates them at boot; the binaries were chgrp'd to these GIDs at
# build time (files/scripts/install-1password.sh).
check 'group onepassword is 1500'     'test "$(getent group onepassword | cut -d: -f3)" = 1500'
check 'group onepassword-cli is 1600' 'test "$(getent group onepassword-cli | cut -d: -f3)" = 1600'
check 'group onepassword-mcp is 1700' 'test "$(getent group onepassword-mcp | cut -d: -f3)" = 1700'
