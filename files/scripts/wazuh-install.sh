#!/usr/bin/env bash
set -eou pipefail

mv /var/ossec /usr/lib/wazuh-agent
cat > /usr/lib/tmpfiles.d/wazuh.conf << EOF
L+ /var/ossec - - - - /usr/lib/wazuh-agent
EOF
