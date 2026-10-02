#!/usr/bin/python3
"""
window.py - Build a date-windowed brief from the local release archive.

The release-tracker agent reads this brief instead of searching the web, so the
digest is grounded in a deterministic, timestamped, AWS-only record rather than
whatever a search happens to surface. Every line carries its own citation URL.

It also reports COVERAGE HONESTLY:
  - which in-scope services had zero activity in the window
  - whether the archive actually covers the requested window, or whether
    collection started too late / missed days (so a "nothing happened" claim is
    never mistaken for "we did not look")

USAGE
    python3 window.py                        # last 7 days
    python3 window.py --days 15
    python3 window.py --from 2026-09-15 --to 2026-09-30
    python3 window.py --days 15 --json       # machine-readable only
"""

import argparse
import json
import os
import sys
from collections import OrderedDict, defaultdict
from datetime import datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RAW_DIR = os.path.join(ROOT, ".raw")
ARCHIVE = os.path.join(RAW_DIR, "items.jsonl")
STATE = os.path.join(RAW_DIR, "state.json")
SOURCES = os.path.join(ROOT, "sources.json")


def parse_iso(value):
    if not value:
        return None
    try:
        return datetime.strptime(value.replace("Z", "+0000"), "%Y-%m-%dT%H:%M:%S%z")
    except ValueError:
        try:
            return datetime.strptime(value[:10], "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            return None


def load_archive():
    if not os.path.exists(ARCHIVE):
        sys.exit("No archive at {}. Run collect.py first.".format(ARCHIVE))
    out = []
    with open(ARCHIVE, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                try:
                    out.append(json.loads(line))
                except ValueError:
                    continue
    return out


def coverage_report(records, start, end):
    """
    Assess whether the archive can be trusted for this window.

    Two distinct failure modes:
      1. Collection began after the window started -> genuinely missing history.
      2. Days with no collector run -> possible gaps IF the gap exceeded the
         feed's own retention (~10 days for What's New).
    """
    state = {}
    if os.path.exists(STATE):
        try:
            with open(STATE, "r", encoding="utf-8") as fh:
                state = json.load(fh)
        except ValueError:
            pass

    runs = sorted(r["at"] for r in state.get("runs", []) if r.get("at"))
    first_seen = min((r["first_seen"] for r in records if r.get("first_seen")), default=None)

    warnings = []
    first_dt = parse_iso(first_seen)
    if first_dt and first_dt > start + timedelta(days=1):
        warnings.append(
            "Archive starts {} but the window starts {}. Items published before "
            "the first collector run are only present if they were still inside the "
            "feed's ~10-day retention at that time.".format(
                first_dt.date(), start.date()))

    run_days = sorted({parse_iso(r).date() for r in runs if parse_iso(r)})
    max_gap, gap_span = 0, None
    for prev, nxt in zip(run_days, run_days[1:]):
        gap = (nxt - prev).days
        if gap > max_gap:
            max_gap, gap_span = gap, (prev, nxt)
    if max_gap > 10:
        warnings.append(
            "Collector gap of {} days ({} -> {}) exceeds the What's New feed "
            "retention of ~10 days. Announcements in that interval may be lost "
            "permanently.".format(max_gap, gap_span[0], gap_span[1]))
    elif max_gap >= 7:
        warnings.append(
            "Collector gap of {} days ({} -> {}) is close to feed retention. "
            "Coverage is probably intact but verify.".format(
                max_gap, gap_span[0], gap_span[1]))

    last_run = state.get("last_run")
    last_dt = parse_iso(last_run)
    stale_hours = None
    if last_dt:
        stale_hours = round((datetime.now(timezone.utc) - last_dt).total_seconds() / 3600, 1)
        if stale_hours > 48:
            warnings.append(
                "Last collector run was {} hours ago. Run collect.py before "
                "trusting this window.".format(stale_hours))

    return {
        "archive_items_total": len(records),
        "archive_first_seen": first_seen,
        "collector_last_run": last_run,
        "collector_hours_since_run": stale_hours,
        "collector_run_days": len(run_days),
        "max_collector_gap_days": max_gap,
        "warnings": warnings,
        "trustworthy": not warnings,
    }


def main():
    ap = argparse.ArgumentParser(description="Window the AWS security release archive.")
    ap.add_argument("--days", type=int, default=7, help="lookback window in days (default 7)")
    ap.add_argument("--from", dest="date_from", help="window start, YYYY-MM-DD")
    ap.add_argument("--to", dest="date_to", help="window end, YYYY-MM-DD")
    ap.add_argument("--json", action="store_true", help="emit JSON only, no markdown brief")
    ap.add_argument("--out", help="path for the markdown brief (default .raw/brief-<window>.md)")
    args = ap.parse_args()

    now = datetime.now(timezone.utc)
    if args.date_from:
        start = parse_iso(args.date_from)
        end = parse_iso(args.date_to) + timedelta(days=1) if args.date_to else now
    else:
        end = now
        start = (now - timedelta(days=args.days)).replace(hour=0, minute=0, second=0, microsecond=0)

    with open(SOURCES, "r", encoding="utf-8") as fh:
        sources = json.load(fh)

    records = load_archive()
    coverage = coverage_report(records, start, end)

    in_window = []
    undated = []
    for rec in records:
        pub = parse_iso(rec.get("published"))
        if pub is None:
            undated.append(rec)
        elif start <= pub <= end:
            in_window.append(rec)

    in_window.sort(key=lambda r: r.get("published") or "", reverse=True)

    # Group core items by service, preserving the catalog order from sources.json
    catalog = OrderedDict((s["name"], s) for s in sources["services"])
    by_service = defaultdict(list)
    adjacent, advisories, review_queue, docs = [], [], [], []

    for rec in in_window:
        if rec["bucket"] == "core" and rec.get("services"):
            for name in rec["services"]:
                if name in catalog:
                    by_service[name].append(rec)
        elif rec["bucket"] == "docs":
            docs.append(rec)
            for name in rec.get("services", []):
                if name in catalog:
                    by_service[name].append(rec)
        elif rec["bucket"] == "advisory":
            advisories.append(rec)
        elif rec["bucket"] == "adjacent":
            adjacent.append(rec)
        else:
            review_queue.append(rec)

    silent = [name for name in catalog if not by_service.get(name)]

    payload = {
        "window": {
            "from": start.isoformat().replace("+00:00", "Z"),
            "to": end.isoformat().replace("+00:00", "Z"),
            "days": (end - start).days,
        },
        "generated": now.isoformat().replace("+00:00", "Z"),
        "coverage": coverage,
        "counts": {
            "in_window_total": len(in_window),
            "core_services_with_activity": len(by_service),
            "core_services_silent": len(silent),
            "advisories": len(advisories),
            "adjacent": len(adjacent),
            "review_queue": len(review_queue),
            "undated_in_archive": len(undated),
        },
        "by_service": {k: v for k, v in by_service.items()},
        "silent_services": silent,
        "advisories": advisories,
        "adjacent": adjacent,
        "review_queue": review_queue,
    }

    if args.json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0

    out_path = args.out or os.path.join(
        RAW_DIR, "brief-{}_{}.md".format(start.strftime("%Y%m%d"), end.strftime("%Y%m%d")))

    lines = []
    w = lines.append
    w("# Collector Brief — {} to {} ({} days)".format(
        start.strftime("%Y-%m-%d"), end.strftime("%Y-%m-%d"), (end - start).days))
    w("")
    w("> Source of record: `aws-updates/.raw/items.jsonl` | Generated: {}".format(
        now.strftime("%Y-%m-%d %H:%M UTC")))
    w("")
    w("## Coverage")
    w("- Archive total: {} items | first collected: {}".format(
        coverage["archive_items_total"], coverage["archive_first_seen"]))
    w("- Collector last run: {} ({} h ago) across {} distinct days".format(
        coverage["collector_last_run"], coverage["collector_hours_since_run"],
        coverage["collector_run_days"]))
    w("- Largest gap between runs: {} days".format(coverage["max_collector_gap_days"]))
    if coverage["warnings"]:
        w("- **COVERAGE WARNINGS — state these in the digest:**")
        for warn in coverage["warnings"]:
            w("  - {}".format(warn))
    else:
        w("- No coverage warnings. The window is fully covered.")
    w("")
    w("## Counts")
    for key, val in payload["counts"].items():
        w("- {}: {}".format(key.replace("_", " "), val))
    w("")

    def emit(rec, indent=""):
        w("{}- **{}** — {}".format(indent, (rec.get("published") or "????")[:10], rec["title"]))
        w("{}  - source: {} ({})".format(indent, rec["source_name"], rec["authority"]))
        w("{}  - link: {}".format(indent, rec["link"]))
        if rec.get("exam_domains"):
            w("{}  - exam domain(s): {}".format(indent, "; ".join(rec["exam_domains"])))
        if rec.get("summary"):
            w("{}  - summary: {}".format(indent, rec["summary"][:600]))

    w("## Core 34 — services with activity")
    if not by_service:
        w("_No activity for any of the 34 in-scope services in this window._")
    for name in catalog:
        recs = by_service.get(name)
        if not recs:
            continue
        meta = catalog[name]
        w("")
        w("### {} ({} item(s))".format(name, len(recs)))
        w("- category: {} | exam domain: {}".format(meta["category"], meta["exam_domain"]))
        for rec in sorted(recs, key=lambda r: r.get("published") or "", reverse=True):
            emit(rec)
    w("")

    w("## Security advisories / bulletins ({})".format(len(advisories)))
    for rec in advisories:
        emit(rec)
    w("")

    w("## Adjacent watch ({})".format(len(adjacent)))
    for rec in adjacent:
        emit(rec)
    w("")

    w("## Review queue — matched the security net but no in-scope service ({})".format(
        len(review_queue)))
    w("_Judge each one: promote to a service section, or drop as out of scope._")
    for rec in review_queue:
        emit(rec)
    w("")

    w("## No activity this window ({} of 34)".format(len(silent)))
    w(", ".join(silent) if silent else "_none — every service had activity_")
    w("")

    os.makedirs(RAW_DIR, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")

    print(out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
