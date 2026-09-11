#!/usr/bin/env bash
# Local replacement for the bling module's 1password installer, which fails
# because it installs a .desktop file that upstream no longer ships at
# /opt/1Password/resources/1password.desktop (the RPM now installs the desktop
# entries and icons itself). See blue-build/modules#581.

set -euo pipefail

# Must be over 1000 and must not collide with real groups on the deployed system.
GID_ONEPASSWORD=1500
GID_ONEPASSWORDCLI=1600

cat << EOF > /etc/yum.repos.d/1password.repo
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

rpm --import https://downloads.1password.com/linux/keys/1password.asc

rpm-ostree install 1password 1password-cli

# Updates are baked into new images.
rm -f /etc/yum.repos.d/1password.repo

# chrome-sandbox requires the setuid bit. https://github.com/electron/electron/issues/17972
chmod 4755 /opt/1Password/chrome-sandbox

# The onepassword groups cannot be created during the ostree build (they would
# disappear from the running system), so hardcode the GIDs here and recreate the
# groups through sysusers.d below.
chgrp "${GID_ONEPASSWORD}" /opt/1Password/1Password-BrowserSupport
chmod g+s /opt/1Password/1Password-BrowserSupport

chgrp "${GID_ONEPASSWORDCLI}" /usr/bin/op
chmod g+s /usr/bin/op

cat > /usr/lib/sysusers.d/onepassword.conf << EOF
g onepassword ${GID_ONEPASSWORD}
EOF
cat > /usr/lib/sysusers.d/onepassword-cli.conf << EOF
g onepassword-cli ${GID_ONEPASSWORDCLI}
EOF

# The RPM-generated entries do not set the GIDs the binaries were chgrp'd to.
rm -f /usr/lib/sysusers.d/30-rpmostree-pkg-group-onepassword.conf
rm -f /usr/lib/sysusers.d/30-rpmostree-pkg-group-onepassword-cli.conf
