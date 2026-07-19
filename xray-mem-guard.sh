#!/usr/bin/env bash
#
# xray-mem-guard — restart the Xray core when system memory usage is high.
#
# Built for servers running the 3X-UI panel (MHSanaei/3x-ui), where the Xray
# core is launched and supervised by the "x-ui" systemd service. When real
# memory usage reaches THRESHOLD percent, the guard restarts that service
# (and with it the Xray core), freeing memory. A cooldown stops restart storms.
#
# Meant to be run once a minute from a systemd timer (see systemd/).
# Logs everything to $LOG.
#
# Repo: https://github.com/<your-github>/xray-mem-guard

set -euo pipefail

# ---------- Defaults (override them in /etc/xray-mem-guard.conf) ----------
THRESHOLD=80                             # restart when used memory % >= this
COOLDOWN=600                             # minimum seconds between restarts
RESTART_CMD="systemctl restart x-ui"     # command that restarts the Xray core
LOG="/var/log/xray-mem-guard.log"
STATE="/run/xray-mem-guard.last"         # stores epoch time of the last restart

CONF="/etc/xray-mem-guard.conf"
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }

# ---------- Measure REAL memory usage via MemAvailable ----------
# MemAvailable already discounts reclaimable page cache, so this reflects true
# memory pressure — not the misleading "total - free" that always looks ~90%.
mem_total=0
mem_avail=-1
while read -r key val _; do
    case "$key" in
        MemTotal:)     mem_total=$val ;;
        MemAvailable:) mem_avail=$val ;;
    esac
done < /proc/meminfo

if [ "$mem_total" -le 0 ] || [ "$mem_avail" -lt 0 ]; then
    log "ERROR: cannot read memory from /proc/meminfo (total=$mem_total avail=$mem_avail)"
    exit 1
fi

used_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))

# ---------- Below threshold: nothing to do ----------
if [ "$used_pct" -lt "$THRESHOLD" ]; then
    # Uncomment the next line if you want a heartbeat line in the log:
    # log "ok: memory ${used_pct}% (< ${THRESHOLD}%)"
    exit 0
fi

# ---------- Above threshold: respect the cooldown ----------
now=$(date +%s)
last=0
[ -r "$STATE" ] && last=$(cat "$STATE" 2>/dev/null || echo 0)
case "$last" in ''|*[!0-9]*) last=0 ;; esac
elapsed=$(( now - last ))

if [ "$elapsed" -lt "$COOLDOWN" ]; then
    log "high: memory ${used_pct}% >= ${THRESHOLD}%, but still in cooldown (${elapsed}s < ${COOLDOWN}s) — skipping"
    exit 0
fi

# ---------- Restart the Xray core ----------
log "high: memory ${used_pct}% >= ${THRESHOLD}% — running: ${RESTART_CMD}"
if eval "$RESTART_CMD" >>"$LOG" 2>&1; then
    printf '%s' "$now" >"$STATE"
    log "restarted OK (memory was ${used_pct}%)"
else
    rc=$?
    log "ERROR: restart command failed (exit $rc)"
    exit "$rc"
fi
