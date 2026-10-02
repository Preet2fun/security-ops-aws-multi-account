#!/bin/bash
#
# health-check.sh - One-line status for the AWS security release tracker.
#
# Called by the SessionStart Kiro hook. Prints a single actionable line, or
# nothing at all when everything is current (a silent session start means healthy).
#
# There is no background scheduler by design - collection runs when you ask for
# it. That makes this check the ONLY safety net, so it has to be blunt about the
# consequence of waiting too long: the AWS What's New feed holds ~10 days, so a
# gap beyond that loses announcements permanently. No later run can recover them.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
STATE="$ROOT/.raw/state.json"
PY=/usr/bin/python3

FEED_RETENTION_DAYS=10
WARN_AFTER_DAYS=2

ISO_YEAR="$(date +%G)"
ISO_WEEK="$(date +%V)"
DIGEST="$ROOT/${ISO_YEAR}-week-${ISO_WEEK}.md"
REL_DIGEST="aws-updates/${ISO_YEAR}-week-${ISO_WEEK}.md"

parts=()

if [ ! -f "$STATE" ]; then
  parts+=("AWS security tracker has never collected. Run: /usr/bin/python3 aws-updates/scripts/collect.py")
else
  days="$("$PY" - "$STATE" <<'PY' 2>/dev/null || echo ""
import datetime, json, sys
try:
    state = json.load(open(sys.argv[1]))
    raw = state.get("last_run")
    if not raw:
        raise ValueError("no last_run")
    fmt = "%Y-%m-%dT%H:%M:%S.%f%z" if "." in raw else "%Y-%m-%dT%H:%M:%S%z"
    last = datetime.datetime.strptime(raw.replace("Z", "+0000"), fmt)
    delta = datetime.datetime.now(datetime.timezone.utc) - last
    print(int(delta.total_seconds() // 86400))
except Exception:
    print("")
PY
)"

  if [ -z "$days" ]; then
    parts+=("AWS security tracker state file is unreadable. Run: /usr/bin/python3 aws-updates/scripts/collect.py")
  elif [ "$days" -ge "$FEED_RETENTION_DAYS" ]; then
    parts+=("AWS security collector last ran ${days} days ago, which EXCEEDS the ~${FEED_RETENTION_DAYS}-day What's New feed retention — announcements in that gap are GONE and no later run can recover them. Run now: /usr/bin/python3 aws-updates/scripts/collect.py")
  elif [ "$days" -ge "$WARN_AFTER_DAYS" ]; then
    parts+=("AWS security collector last ran ${days} days ago. Run: /usr/bin/python3 aws-updates/scripts/collect.py")
  fi
fi

if [ ! -f "$DIGEST" ]; then
  parts+=("No digest for ISO week ${ISO_WEEK} yet — run @release-tracker to write ${REL_DIGEST}.")
fi

if [ "${#parts[@]}" -gt 0 ]; then
  printf '%s\n' "${parts[@]}"
fi
