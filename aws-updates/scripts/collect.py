#!/usr/bin/python3
"""
collect.py - Daily collector for AWS security release tracking.

INTERPRETER: pinned to /usr/bin/python3 (macOS system Python) on purpose.
The python.org 3.8 framework build on this machine has no CA roots installed and
fails every fetch with CERTIFICATE_VERIFY_FAILED. The system interpreter uses the
macOS trust store, so it keeps working across Homebrew upgrades.
Code stays 3.8-compatible so any interpreter with working TLS will do.

WHY THIS EXISTS
---------------
The AWS "What's New" RSS feed holds only the most recent ~100 items, which is
roughly 10 days of announcements. A 15-day lookback is therefore IMPOSSIBLE from
a single fetch, and the JSON directory API that used to allow arbitrary date
queries is frozen (newest item: 2024-05-17, verified 2026-10-02).

The only way to guarantee a complete, gap-free history is to poll daily and
accumulate into a local append-only archive. Daily polling of a 10-day feed gives
a 10x overlap margin, so even a week of missed runs loses nothing.

This script does NO interpretation. It fetches, classifies against the service
map, dedupes, and appends. All judgment is left to the release-tracker agent,
which reads the archive. That separation is deliberate: collection must be
deterministic and verifiable, not model-dependent.

USAGE
-----
    python3 collect.py                 # normal daily run
    python3 collect.py --verbose       # print each new item
    python3 collect.py --dry-run       # fetch and classify, write nothing
"""

import argparse
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                      # aws-updates/
RAW_DIR = os.path.join(ROOT, ".raw")
ARCHIVE = os.path.join(RAW_DIR, "items.jsonl")
STATE = os.path.join(RAW_DIR, "state.json")
LOG = os.path.join(RAW_DIR, "collect.log")
SOURCES = os.path.join(ROOT, "sources.json")

USER_AGENT = "aws-security-release-tracker/1.0 (local study tooling; +https://aws.amazon.com)"
TIMEOUT = 30
RETRIES = 3
RETRY_BACKOFF = 4  # seconds, multiplied by attempt number

TRUSTED_HOSTS = ("aws.amazon.com", "docs.aws.amazon.com", "amazon.com")


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #

def log(msg):
    """Append a timestamped line to the collector log and echo to stderr."""
    line = "[{}] {}".format(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), msg)
    os.makedirs(RAW_DIR, exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")
    print(line, file=sys.stderr)


def strip_html(text):
    """Feed descriptions carry markup; reduce to clean single-line prose."""
    if not text:
        return ""
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def normalize_id(value):
    """
    Normalize an item identifier for deduping: drop tracking query params,
    lowercase, drop a trailing slash.

    The URL fragment is deliberately PRESERVED. AWS doc-history feeds give every
    entry the same <link> and carry the unique part in the guid fragment
    (e.g. .../ug/#Updated_finding_type_-_...), so stripping '#' would collapse
    230 distinct GuardDuty changes into a single record.
    """
    if not value:
        return ""
    return value.split("?")[0].rstrip("/").lower()


def item_key(feed_id, item):
    """
    Dedup key, scoped per feed.

    Scoping matters: when the same release appears in both What's New and the
    Security Blog we want BOTH records, because they are different citations with
    different depth. Within a feed, guid is authoritative (What's New and the blog
    use stable content hashes); link is the fallback.
    """
    raw = item.get("guid") or item.get("link")
    norm = normalize_id(raw)
    return "{}::{}".format(feed_id, norm) if norm else ""


def parse_date(raw):
    """RFC-822 pubDate -> ISO-8601 UTC. Returns None if unparseable."""
    if not raw:
        return None
    try:
        dt = parsedate_to_datetime(raw.strip())
    except (TypeError, ValueError):
        return None
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def fetch(url):
    """GET with retries. Raises on final failure so the caller can log and continue."""
    last = None
    for attempt in range(1, RETRIES + 1):
        try:
            req = urllib.request.Request(url, headers={
                "User-Agent": USER_AGENT,
                "Accept": "application/rss+xml, application/xml, text/xml, */*",
            })
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                return resp.read()
        except (urllib.error.URLError, urllib.error.HTTPError, OSError) as exc:
            last = exc
            if attempt < RETRIES:
                time.sleep(RETRY_BACKOFF * attempt)
    raise last


def parse_rss(blob):
    """Yield dicts from an RSS 2.0 payload. Tolerates missing optional fields."""
    root = ET.fromstring(blob)
    for item in root.iter("item"):
        def text(tag):
            el = item.find(tag)
            return el.text if el is not None and el.text else ""
        yield {
            "title": strip_html(text("title")),
            "link": (text("link") or "").strip(),
            "guid": (text("guid") or "").strip(),
            "published_raw": text("pubDate"),
            "summary": strip_html(text("description")),
            "categories": [c.text.strip() for c in item.findall("category")
                           if c is not None and c.text],
        }


def compile_matchers(sources):
    """Pre-compile every regex once. Returns (core, adjacent, net)."""
    def build(entries):
        out = []
        for svc in entries:
            pats = [re.compile(p, re.IGNORECASE) for p in svc.get("match", [])]
            out.append((svc, pats))
        return out

    core = build(sources["services"])
    adjacent = build(sources.get("adjacent_watch", {}).get("services", []))
    net = [re.compile(p, re.IGNORECASE)
           for p in sources.get("security_net", {}).get("match", [])]
    return core, adjacent, net


def _hits(pats, text):
    return any(p.search(text) for p in pats)


# Verbs that separate the SUBJECT of an AWS announcement title from its predicate.
# "Amazon SageMaker Unified Studio | now supports ... IAM authentication ..."
_SUBJECT_SPLIT = re.compile(
    r"\s(?:now\s|is\snow\b|are\snow\b|announces\b|introduces\b|launches\b|adds\b|"
    r"supports\b|expands\b|extends\b|enables\b|achieves\b|available\b)|:",
    re.IGNORECASE)


def title_subject(title, cap=120):
    """
    Extract the SUBJECT of an announcement title - the service the release is about.

    AWS titles are overwhelmingly '<Service> now <does something>', so the text
    before the verb identifies the owning service. Without this, a title like
    'Amazon SageMaker Unified Studio now supports ... IAM authentication for
    Amazon DocumentDB' gets filed as an IAM release, which is wrong: it is a
    SageMaker release that happens to use IAM.

    The heuristic only fires when that canonical shape is actually present. Some
    announcements are prose ('Improve your secrets security posture ... in the
    AWS Secrets Manager console'), and blindly truncating those would cut off the
    very service name that classifies them.
    """
    if not title:
        return ""
    if not _SUBJECT_SPLIT.search(title):
        return title
    return _SUBJECT_SPLIT.split(title, maxsplit=1)[0][:cap]


def classify(item, core, adjacent, net, use_subject=True):
    """
    Two-tier classification.

    TITLE match  -> the release is FOR that service (goes in its digest section).
    BODY match   -> the release merely REFERENCES it (recorded as a 'mention').

    This distinction is what keeps the digest readable. A single-tier match on
    r'\\bIAM\\b' tags every Redshift, ElastiCache and SageMaker announcement that
    happens to mention an IAM policy, which buries the handful of actual IAM
    releases. AWS announcement titles reliably name the owning service, so the
    title is the right discriminator.

    Returns (title_hits, mention_hits, adj_title, adj_mention, net_title, net_body).
    """
    title = item.get("title", "")
    # Subject extraction only applies to announcement titles, which follow the
    # '<Service> now <verb>' shape. Blog posts and CVE bulletins are prose
    # ("Improve your secrets security posture ... in the AWS Secrets Manager
    # console", "CVE-2026-13762 ... in AWS WAF") and name the service late, so
    # truncating them to a subject loses the real classification.
    subject = title_subject(title) if use_subject else title
    body = " ".join([item.get("summary", ""), " ".join(item.get("categories", []))])
    rest = title[len(subject):] + " " + body

    title_hits, mention_hits = [], []
    for svc, pats in core:
        if _hits(pats, subject):
            title_hits.append(svc["name"])
        elif _hits(pats, rest):
            mention_hits.append(svc["name"])

    # demote_if: drop a generic service when a more specific sibling also matched
    # the title. 'IAM Identity Center extends multi-Region support' is an Identity
    # Center release, not an IAM release.
    by_name = {svc["name"]: svc for svc, _ in core}
    demoted = set()
    for name in title_hits:
        for specific in by_name.get(name, {}).get("demote_if", []):
            if specific in title_hits:
                demoted.add(name)
    title_hits = [n for n in title_hits if n not in demoted]

    adj_title, adj_mention = [], []
    for svc, pats in adjacent:
        if _hits(pats, title):
            adj_title.append(svc["name"])
        elif _hits(pats, body):
            adj_mention.append(svc["name"])

    # Split the catch-all net by position too. A security term in the TITLE means
    # the announcement is probably about security and deserves human review - this
    # is how a brand-new service we never mapped still reaches the digest. The same
    # term buried in the body is usually incidental ("...encrypted with KMS..."),
    # so it is archived but parked as low signal.
    net_title = _hits(net, title)
    net_body = _hits(net, body)
    return title_hits, mention_hits, adj_title, adj_mention, net_title, net_body


def build_record(feed, item, key, sources, core, adjacent, net, first_seen):
    """
    Produce an archive record, or None if the item is out of scope entirely.

    Scope test is deliberately wide at the edges: security bulletins and
    per-service doc feeds are forced in by feed authority, and anything hitting
    the security net is kept in a review queue. Nothing security-shaped is
    dropped silently.
    """
    use_subject = feed.get("authority") == "official-announcement"
    title_hits, mention_hits, adj_title, adj_mention, net_title, net_body = classify(
        item, core, adjacent, net, use_subject=use_subject)

    forced = feed.get("authority") in ("official-advisory", "official-docs")
    if not (title_hits or mention_hits or adj_title or adj_mention
            or net_title or net_body or forced):
        return None

    if forced and not title_hits and feed.get("service_hint"):
        title_hits = [feed["service_hint"]]

    if title_hits:
        bucket = "core"
    elif adj_title:
        bucket = "adjacent"
    elif feed.get("authority") == "official-advisory":
        bucket = "advisory"
    elif feed.get("authority") == "official-docs":
        bucket = "docs"
    elif net_title:
        # Security-shaped title, no service mapped. Could be a brand-new service.
        bucket = "review-queue"
    else:
        bucket = "low-signal"

    # Doc-history feeds point every <link> at the same page; the guid holds the
    # anchor. Prefer the anchored guid so a citation lands on the actual entry.
    citation = item["link"]
    if feed.get("authority") == "official-docs" and item.get("guid", "").startswith("http"):
        citation = item["guid"]

    return {
        "key": key,
        "source": feed["id"],
        "source_name": feed["name"],
        "authority": feed.get("authority"),
        "title": item["title"],
        "link": citation,
        "page_link": item["link"],
        "published": parse_date(item["published_raw"]),
        "published_raw": item["published_raw"],
        "summary": item["summary"][:1200],
        "categories": item["categories"],
        "services": title_hits,
        "mentions": mention_hits,
        "adjacent": adj_title,
        "adjacent_mentions": adj_mention,
        "exam_domains": exam_domains(title_hits, sources),
        "bucket": bucket,
        "subject": title_subject(item.get("title", "")) if use_subject else item.get("title", ""),
        "first_seen": first_seen,
    }


def exam_domains(core_hits, sources):
    """Map matched service names to their exam domains, deduped, stable order."""
    by_name = {s["name"]: s.get("exam_domain") for s in sources["services"]}
    seen, out = set(), []
    for name in core_hits:
        dom = by_name.get(name)
        if dom and dom not in seen:
            seen.add(dom)
            out.append(dom)
    return out


def load_archive_keys():
    """Existing dedup keys, so re-runs are idempotent."""
    keys = set()
    if not os.path.exists(ARCHIVE):
        return keys
    with open(ARCHIVE, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                keys.add(json.loads(line)["key"])
            except (ValueError, KeyError):
                continue
    return keys


def reclassify(sources, core, adjacent, net, dry_run=False):
    """
    Re-apply classification to every archived item in place.

    Needed whenever sources.json changes - new service, tightened regex, new
    demote_if rule. Only DERIVED fields are recomputed (services, mentions,
    adjacent, exam_domains, bucket). The collected facts (key, title, link,
    published, first_seen) are preserved untouched, so the archive stays an
    honest record of what was seen and when.
    """
    if not os.path.exists(ARCHIVE):
        log("RECLASSIFY skipped - no archive yet")
        return 0

    feeds = {f["id"]: f for f in sources["feeds"]}
    out, changed, dropped = [], 0, 0

    with open(ARCHIVE, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                old = json.loads(line)
            except ValueError:
                continue

            feed = feeds.get(old["source"], {
                "id": old["source"],
                "name": old.get("source_name", old["source"]),
                "authority": old.get("authority"),
            })
            item = {
                "title": old.get("title", ""),
                "summary": old.get("summary", ""),
                "categories": old.get("categories", []),
                "link": old.get("page_link") or old.get("link", ""),
                "guid": old.get("link", ""),
                "published_raw": old.get("published_raw", ""),
            }

            new = build_record(feed, item, old["key"], sources,
                               core, adjacent, net, old.get("first_seen"))
            if new is None:
                # No longer in scope under the new rules. Keep the record but park
                # it, so the archive never silently loses an item we once saw.
                old["bucket"] = "out-of-scope"
                old["services"], old["mentions"] = [], []
                out.append(old)
                dropped += 1
                continue

            # Preserve collection facts over anything recomputed.
            new["published"] = old.get("published")
            new["link"] = old.get("link")
            new["page_link"] = old.get("page_link")
            new["first_seen"] = old.get("first_seen")

            if (new.get("services") != old.get("services")
                    or new.get("bucket") != old.get("bucket")):
                changed += 1
            out.append(new)

    if not dry_run:
        tmp = ARCHIVE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            for rec in out:
                fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
        os.replace(tmp, ARCHIVE)

    log("RECLASSIFY {} items | {} reclassified | {} now out-of-scope{}".format(
        len(out), changed, dropped, " (dry run)" if dry_run else ""))
    return 0


def load_state():
    if os.path.exists(STATE):
        try:
            with open(STATE, "r", encoding="utf-8") as fh:
                return json.load(fh)
        except ValueError:
            pass
    return {"runs": [], "feeds": {}}


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #

def main():
    ap = argparse.ArgumentParser(description="Collect AWS security releases into a local archive.")
    ap.add_argument("--verbose", action="store_true", help="print every new item")
    ap.add_argument("--dry-run", action="store_true", help="do not write the archive")
    ap.add_argument("--reclassify", action="store_true",
                    help="re-apply sources.json rules to the existing archive and exit")
    args = ap.parse_args()

    os.makedirs(RAW_DIR, exist_ok=True)

    with open(SOURCES, "r", encoding="utf-8") as fh:
        sources = json.load(fh)

    core, adjacent, net = compile_matchers(sources)

    if args.reclassify:
        return reclassify(sources, core, adjacent, net, dry_run=args.dry_run)

    seen_keys = load_archive_keys()
    state = load_state()

    run_started = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    new_records = []
    feed_report = {}

    for feed in sources["feeds"]:
        fid, url = feed["id"], feed["url"]

        # Guardrail: this tracker is AWS-sources-only by design. Refuse anything else.
        host = urllib.parse.urlparse(url).netloc.lower()
        if not any(host == h or host.endswith("." + h) for h in TRUSTED_HOSTS):
            log("REFUSED non-AWS source {} ({})".format(fid, host))
            feed_report[fid] = {"status": "refused-untrusted-host", "new": 0}
            continue

        try:
            blob = fetch(url)
        except Exception as exc:                     # noqa: BLE001 - log and continue
            hint = ""
            if "CERTIFICATE_VERIFY_FAILED" in str(exc):
                hint = (" | HINT: this interpreter has no CA roots. Run with "
                        "/usr/bin/python3, or execute the 'Install Certificates.command' "
                        "bundled with your python.org install.")
            log("FAIL  {} - {}{}".format(fid, exc, hint))
            feed_report[fid] = {"status": "error", "error": str(exc), "new": 0}
            continue

        try:
            items = list(parse_rss(blob))
        except ET.ParseError as exc:
            log("FAIL  {} - XML parse error: {}".format(fid, exc))
            feed_report[fid] = {"status": "parse-error", "error": str(exc), "new": 0}
            continue

        kept = 0
        for item in items:
            key = item_key(fid, item)
            if not key or key in seen_keys:
                continue

            record = build_record(feed, item, key, sources,
                                  core, adjacent, net, run_started)
            if record is None:
                continue

            new_records.append(record)
            seen_keys.add(key)
            kept += 1
            if args.verbose:
                print("  + [{}] {} :: {}".format(
                    record["bucket"], record["published"] or "?", record["title"]))

        feed_report[fid] = {"status": "ok", "items_in_feed": len(items), "new": kept}
        log("OK    {} - {} items in feed, {} new".format(fid, len(items), kept))

    if new_records and not args.dry_run:
        # Append-only: the archive is the audit trail. Never rewrite history.
        with open(ARCHIVE, "a", encoding="utf-8") as fh:
            for rec in new_records:
                fh.write(json.dumps(rec, ensure_ascii=False) + "\n")

    if not args.dry_run:
        state["feeds"] = feed_report
        state["runs"] = (state.get("runs", []) + [{
            "at": run_started,
            "new_items": len(new_records),
            "feeds_ok": sum(1 for f in feed_report.values() if f["status"] == "ok"),
            "feeds_failed": sum(1 for f in feed_report.values() if f["status"] != "ok"),
        }])[-60:]          # keep ~2 months of run history
        state["last_run"] = run_started
        state["last_run_new_items"] = len(new_records)
        state["archive_total"] = len(seen_keys)
        with open(STATE, "w", encoding="utf-8") as fh:
            json.dump(state, fh, indent=2)

    by_bucket = {}
    for rec in new_records:
        by_bucket[rec["bucket"]] = by_bucket.get(rec["bucket"], 0) + 1

    log("DONE  {} new items {} | archive total {}".format(
        len(new_records),
        json.dumps(by_bucket) if by_bucket else "{}",
        len(seen_keys)))

    failed = [f for f in feed_report.values() if f["status"] != "ok"]
    # Non-zero exit signals that coverage is incomplete, so a caller can react.
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
