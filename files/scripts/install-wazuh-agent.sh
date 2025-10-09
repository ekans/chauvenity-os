#!/usr/bin/env bash
set -euo pipefail

# Install Wazuh agent to temporary root to run post-install scripts properly

# Create temporary directories
mkdir -p /tmp/wazuh-root/proc

# Create fake /proc/cpuinfo for post-install scripts
echo -e "processor\t: 0\nvendor_id\t: AuthenticAMD\ncpu family\t: 26\nmodel\t\t: 96\nmodel name\t: AMD Ryzen AI 7 350 w/ Radeon 860M\nstepping\t: 0\ncpu MHz\t\t: 1998.495\ncache size\t: 1024 KB" > /tmp/wazuh-root/proc/cpuinfo

# Install required tools first (gawk is needed by Wazuh post-install scripts)
dnf --installroot=/tmp/wazuh-root --releasever=42 --setopt=reposdir=/etc/yum.repos.d --setopt=install_weak_deps=False install -y gawk procps-ng

# Install Wazuh agent package
dnf --installroot=/tmp/wazuh-root --releasever=42 --setopt=reposdir=/etc/yum.repos.d --setopt=install_weak_deps=False install -y wazuh-agent-4.12.0-1

# Move the installed files to /usr/local/ossec (part of immutable image)
if [ -d /tmp/wazuh-root/var/ossec ]; then
  mv /tmp/wazuh-root/var/ossec /usr/local/ossec
  echo "Successfully installed wazuh-agent to /usr/local/ossec"
else
  echo "ERROR - /tmp/wazuh-root/var/ossec not found"
  exit 1
fi

# Cleanup
rm -rf /tmp/wazuh-root
