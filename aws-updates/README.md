# AWS Security Release Tracker

Keeps you current on AWS security releases across the **34 in-scope security services**,
from AWS-owned sources only, with a citation on every line.

> Scope, sources, matching rules and the P1/P2/P3 rubric all live in
> [`sources.json`](./sources.json). That file is the single place to edit when scope changes.

## The problem this solves

The AWS What's New RSS feed holds about **100 items, roughly 10 days**. The JSON
directory API that once allowed arbitrary date queries is frozen — its newest item
is from May 2024 (verified 2026-10-02). There is no AWS endpoint that will answer
"what shipped in the last 15 days" after the fact.

So a 15-day lookback cannot be reconstructed on demand. It has to be **accumulated**.
That is the whole architecture: poll into an append-only local archive, then query
the archive for any window you like. Because the feed carries ~10 days, collecting
roughly weekly leaves a comfortable overlap and a few missed days cost nothing —
but a gap beyond ~10 days loses announcements permanently.

## How it works

```
  SessionStart hook ──▶ "collector last ran N days ago"
                                        │
                          you run it ───┤
                                        ▼
                 ┌─────────────────────────────────────────────┐
                 │  collect.py            (no AI involved)     │
                 │  4 AWS feeds → classify → dedup → append    │
                 └──────────────────────┬──────────────────────┘
                                        ▼
                         .raw/items.jsonl   (append-only archive)
                                        │
                 ┌──────────────────────┴──────────────────────┐
                 │  window.py     (any date window, on demand) │
                 │  group by service + coverage assessment     │
                 └──────────────────────┬──────────────────────┘
                                        ▼
                            .raw/brief-<from>_<to>.md
                                        │
                                        ▼
                    @release-tracker  (judgment: P1/P2/P3,
                      exam angle, platform impact, actions)
                                        │
                                        ▼
                         {ISO-year}-week-{nn}.md   ← your deliverable
                         + <!-- STALE --> flags on affected notes
```

Collection is deliberately **separate from interpretation**. The collector is
deterministic and auditable — it never decides what is important, it only records
what AWS published and when it was seen. The agent does the judgment, over a fixed
input it cannot silently miss things from.

## Sources

All verified reachable on 2026-10-02. Non-AWS hosts are refused by the collector.

| Source | Holds | Role |
|--------|-------|------|
| [AWS What's New](https://aws.amazon.com/about-aws/whats-new/recent/feed/) | ~100 items / ~10 days | Primary release announcements |
| [AWS Security Blog](https://aws.amazon.com/blogs/security/feed/) | 20 items / ~35 days | Mechanism and best-practice depth |
| [AWS Security Bulletins](https://aws.amazon.com/security/security-bulletins/feed/) | 92 items | CVEs and advisories |
| [GuardDuty doc history](https://docs.aws.amazon.com/guardduty/latest/ug/amazon-guardduty-doc-history.rss) | 230 items | Per-service doc change log |

GuardDuty is the only in-scope service exposing a working doc-history RSS; WAF, KMS,
Security Hub and IAM all 404 on the equivalent URL, and the doc-history pages are
JS-rendered with no feed to scrape. Dead endpoints are recorded in
`sources.json` under `_dead_sources_do_not_retry` so they are not probed again.

## When collection runs

**There is no background scheduler. Collection runs when you ask for it.**

A `SessionStart` Kiro hook (`health-check.sh`) checks freshness every time you open
a session and prints one actionable line:

| Collector last ran | You see |
|--------------------|---------|
| today or yesterday | nothing — silence means healthy |
| 2–9 days ago | a reminder to run `collect.py` |
| 10+ days ago | a warning that announcements in the gap are **unrecoverable** |
| never | the first-run command |

It also tells you when the current ISO week has no digest yet.

### Why there is no automated timer

A time-based scheduler was built and then removed, deliberately — recording the
reason so it does not get re-attempted blindly:

- Kiro hooks are **event-driven only** (SessionStart, PostFileSave, PreToolUse,
  …). There is no time-based hook trigger, so Kiro alone cannot schedule anything.
- macOS `launchd` can, and was tried. It fails here: this repo lives under
  `~/Documents`, which macOS protects with TCC. Kiro and Terminal hold that
  permission; `launchd`-spawned jobs do not, and both jobs died with
  `Operation not permitted`.
- The workarounds — granting Full Disk Access to `/usr/bin/python3`, or splitting
  the working files out to `~/Library/Application Support` — cost more than they
  return for a one-command task.

### The tradeoff you are accepting

The 10-day feed window is a hard limit. Open a Kiro session at least weekly and
the session check keeps you safe. Go dark for more than ~10 days and those
announcements are permanently lost — no later run, and no amount of searching,
can bring them back, because AWS exposes no historical endpoint. If that becomes
a real risk, revisit the Full Disk Access option.

## Manual use

```bash
# Collect now
/usr/bin/python3 aws-updates/scripts/collect.py
/usr/bin/python3 aws-updates/scripts/collect.py --verbose     # show each new item
/usr/bin/python3 aws-updates/scripts/collect.py --dry-run     # fetch, write nothing

# Build a brief for any window
/usr/bin/python3 aws-updates/scripts/window.py --days 7
/usr/bin/python3 aws-updates/scripts/window.py --days 15
/usr/bin/python3 aws-updates/scripts/window.py --from 2026-09-15 --to 2026-09-30
/usr/bin/python3 aws-updates/scripts/window.py --days 15 --json   # machine-readable

# After editing sources.json, re-tag the existing archive
/usr/bin/python3 aws-updates/scripts/collect.py --reclassify

# Then produce the digest
@release-tracker
```

Use `/usr/bin/python3` explicitly. The python.org 3.8 build on this machine has no
CA roots and fails every fetch with `CERTIFICATE_VERIFY_FAILED`; the system
interpreter uses the macOS trust store.

## How items get classified

A single keyword match is not enough. `\bIAM\b` appears in Redshift, ElastiCache,
SageMaker and EMR announcements, which buries the two or three real IAM releases.
So matching is positional:

- **Title/subject match → it IS a release for that service.** AWS titles follow
  `<Service> now <verb> ...`, so the text before the verb identifies the owner.
  `Amazon SageMaker Unified Studio now supports ... IAM authentication` is a
  SageMaker release, not an IAM one.
- **Body-only match → a mention.** Listed as related reading, never as that
  service's release.
- **`demote_if`** resolves overlapping families: `IAM Identity Center extends
  multi-Region support` belongs to Identity Center, not IAM.
- Subject extraction is skipped for blog posts and CVE bulletins, whose titles are
  prose and name the service late.

Result on a representative 15-day window: **21 correctly attributed releases across
10 services**, instead of ~60 noisy ones.

### Buckets

| Bucket | Meaning |
|--------|---------|
| `core` | Title-matched release for one of the 34 → gets a digest section |
| `advisory` | Security bulletin or CVE |
| `docs` | Per-service documentation change |
| `adjacent` | Bedrock, SageMaker, SSM, EKS, CloudFront, automation, resilience |
| `review-queue` | Security-shaped title, no mapped service → **read this one** |
| `low-signal` | Security term in the body only; archived, titles only in the brief |
| `out-of-scope` | Dropped by a later rule change; retained, never deleted |

**The review queue is how new services reach you.** `sources.json` cannot know about
something AWS launched last week — the current window surfaced
*AWS Network Security Manager*, which is not among the 34. When one appears, add it
to `sources.json` and run `--reclassify`.

Nothing collected is ever deleted. A rule change moves an item to `out-of-scope`
rather than dropping it, so the archive stays an honest record of what was seen.

## Digest format

The mandatory template lives in `.kiro/agents/release-tracker.md`. Sections, in order:

| Section | Purpose |
|---------|---------|
| Header | Window, generation time, sources, **coverage status**, scope counts |
| At a Glance | One table row per release: priority, date, service, release, why it matters |
| Act On This | P1/P2 only, each naming the file to change |
| Releases by Service | What changed / why it matters / exam angle / platform angle / action / source |
| Security Advisories | CVEs, including an explicit "not applicable to our stack" when true |
| New to Scope | Review-queue promotions and whether `sources.json` was updated |
| Adjacent Watch | Two lines each, never crowding out the core 34 |
| No Activity | Services checked with nothing to report |
| Stale Content Flags | Files flagged, with the `@content-updater` command |
| Low Signal | Collapsed titles, for completeness |

Every release line carries an `aws.amazon.com` or `docs.aws.amazon.com` URL and one
of **P1** (act now), **P2** (update notes and backlog), **P3** (awareness only).
Region expansions are P3 even for services you care about.

## Files

```
aws-updates/
├── README.md                  this file
├── sources.json               scope, feeds, matching rules, rubric  ← edit here
├── {year}-week-{nn}.md        the digests
├── scripts/
│   ├── collect.py             fetch → archive (also --reclassify)
│   ├── window.py              archive → dated brief + coverage check
│   └── health-check.sh        SessionStart hook status line
└── .raw/
    ├── items.jsonl            append-only archive — COMMIT THIS
    ├── state.json             run history and per-feed status
    ├── brief-*.md             regenerable briefs (gitignored)
    └── collect.log            collector log (gitignored)
```

`items.jsonl` must be committed. Once an announcement ages out of the AWS feed it
is the only copy that exists.

## Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| `CERTIFICATE_VERIFY_FAILED` | Wrong interpreter. Use `/usr/bin/python3`. |
| Brief says coverage warning about archive start | Collection began after the window start. Expected on the first few runs; resolves as history accumulates. |
| Brief warns about a collector gap > 10 days | Real data loss — nothing recovers it. Collect now, and treat that window as unverified in any digest covering it. |
| A release landed under the wrong service | Adjust that service's `match` or add a `demote_if` in `sources.json`, then `--reclassify`. |
| A service shows no releases | Check the **No Activity** list first — that is a verified "nothing shipped", not a miss. Then scan the review queue. |
| `collect.py` exits non-zero | At least one feed failed. See `.raw/collect.log`; the other feeds still collected. |
| Session check prints nothing | That is the healthy state — the collector ran recently and this week's digest exists. |

## Related

- `@release-tracker` — writes the digest and flags stale notes
- `@content-updater {service}` — refreshes a flagged note against current docs
- `@service-deep-dive {service}` — creates a new study note
