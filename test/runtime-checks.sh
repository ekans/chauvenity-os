# shellcheck shell=bash disable=SC2016  # $... in a check expands inside the VM, not here
# Checks on a booted system, shared by test/boot.sh (ephemeral VM) and
# scripts/vm.sh (installed VM). Each defines `check NAME COMMAND`, running
# COMMAND inside its VM, then sources this file.

check 'boot finished' 's=$(timeout 300 systemctl is-system-running --wait); [ "$s" = running ] || [ "$s" = degraded ] || { echo "$s"; exit 1; }'
# Both fail in any VM, bluefin-dx's own included: mcelog has no machine-check
# hardware, and the ephemeral VM has no bootloader to update.
check 'no failed units' 'failed=$(systemctl --failed --no-legend --plain | awk "{print \$1}" | grep -vxE "bootloader-update\.service|mcelog\.service"); for u in $failed; do systemctl status --no-pager -n 20 "$u"; done; [ -z "$failed" ]'
check 'graphical.target reached' 'systemctl is-active graphical.target'
check 'gdm running'              'systemctl is-active gdm.service'

# /opt apps live in /usr/lib/opt; tmpfiles links them into /var/opt at boot.
check 'brave-browser runs from /opt' 'brave-browser --version'
check '/opt 1Password keeps setuid'  'test -u /opt/1Password/chrome-sandbox'

# sysusers creates them at boot; the binaries were chgrp'd to these GIDs at
# build time (files/scripts/install-1password.sh).
check 'group onepassword is 1500'     'test "$(getent group onepassword | cut -d: -f3)" = 1500'
check 'group onepassword-cli is 1600' 'test "$(getent group onepassword-cli | cut -d: -f3)" = 1600'
check 'group onepassword-mcp is 1700' 'test "$(getent group onepassword-mcp | cut -d: -f3)" = 1700'
