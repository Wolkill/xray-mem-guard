#!/usr/bin/env bash
#
# Install xray-mem-guard: copy the script + systemd units and enable the timer.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "This installer must run as root. Try: sudo bash install.sh" >&2
    exit 1
fi

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing guard script -> /usr/local/bin/xray-mem-guard.sh"
install -m 0755 "$src/xray-mem-guard.sh" /usr/local/bin/xray-mem-guard.sh

echo "==> Installing systemd units -> /etc/systemd/system/"
install -m 0644 "$src/systemd/xray-mem-guard.service" /etc/systemd/system/xray-mem-guard.service
install -m 0644 "$src/systemd/xray-mem-guard.timer"   /etc/systemd/system/xray-mem-guard.timer

if [ ! -f /etc/xray-mem-guard.conf ]; then
    echo "==> Installing default config -> /etc/xray-mem-guard.conf"
    install -m 0644 "$src/xray-mem-guard.conf.example" /etc/xray-mem-guard.conf
else
    echo "==> Keeping existing /etc/xray-mem-guard.conf"
fi

echo "==> Reloading systemd and enabling the timer"
systemctl daemon-reload
systemctl enable --now xray-mem-guard.timer

echo
echo "Done. The guard now checks memory every minute."
echo "  Config : /etc/xray-mem-guard.conf"
echo "  Log    : /var/log/xray-mem-guard.log"
echo "  Timer  : systemctl status xray-mem-guard.timer"
echo "  Test   : /usr/local/bin/xray-mem-guard.sh   (safe: restarts only if over the threshold)"
