#!/usr/bin/env bash
set -eou pipefail

wazuh_agent_version='4.12.0-1'

printf "# Wazuh package installation... "
script=$(cat << EOF
set -eou pipefail
curl -o wazuh-agent-${wazuh_agent_version}.x86_64.rpm https://packages.wazuh.com/4.x/yum/wazuh-agent-${wazuh_agent_version}.x86_64.rpm
sudo rpm -ihv wazuh-agent-${wazuh_agent_version}.x86_64.rpm
cp -r /var/ossec /tmp/ossec
cp /usr/lib/systemd/system/wazuh-agent.service /tmp
EOF
)
podman run -v /tmp:/tmp -w /tmp --privileged registry.fedoraproject.org/fedora:latest /bin/bash -c "${script}" &> /dev/null

find /tmp/ossec -type d -perm -400 -a ! -perm -100 -exec chmod u+x {} +

printf "# create wazuh group if needed\n"
getent group wazuh &> /dev/null ||  sudo groupadd wazuh

printf "# create wazuh user if needed\n"
id wazuh &> /dev/null || sudo adduser wazuh -g wazuh

printf "# configure wazuh service\n"
sudo chmod 755 /tmp/wazuh-agent.service


printf "TODOs:\n"
printf "  * move /tmp/ossec to files/system/var/ossec\n"
printf "  * move /tmp/wazuh-agent.service to files/system/etc/systemd/system\n"
