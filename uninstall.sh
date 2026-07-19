#!/usr/bin/env bash
#
# Remove xray-mem-guard (keeps the config and log file).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo bash uninstall.sh" >&2
    exit 1
fi

systemctl disable --now xray-mem-guard.timer 2>/dev/null || true
rm -f /etc/systemd/system/xray-mem-guard.timer
rm -f /etc/systemd/system/xray-mem-guard.service
systemctl daemon-reload
rm -f /usr/local/bin/xray-mem-guard.sh

echo "Removed the timer, service and script."
echo "Kept /etc/xray-mem-guard.conf and /var/log/xray-mem-guard.log (delete by hand if you want)."
