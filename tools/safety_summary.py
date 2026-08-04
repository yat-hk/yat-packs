#!/usr/bin/env python3
"""Print a per-pack safety summary for review: which hosts a changed pack's
declared sources reach, which secrets it declares (and where it promises to
send them), and how often it fetches.

This inspects pack JSON only — nothing from a pack is ever executed. A pack
is a declarative document (PACK-SPEC.md); the engine interprets its `data`
and `render` sections, it never evaluates code from one. This script does the
same: it reads the JSON with json.load() and looks at a handful of fields.

Usage:
    python3 tools/safety_summary.py <pack-file.yat-pack.json> [...]

Intended to run in CI on the packs changed by a PR (see
.github/workflows/ci.yml) with its stdout redirected into
$GITHUB_STEP_SUMMARY, but it works fine against any pack file(s) from a
terminal too.
"""
import json
import sys
from urllib.parse import urlparse


def host_of(url):
    try:
        return urlparse(url).hostname
    except ValueError:
        return None


def summarize(path):
    with open(path, encoding="utf-8") as f:
        pack = json.load(f)

    pack_id = pack.get("id", path)
    version = pack.get("version", "?")

    hosts = set()
    per_source_refresh = []
    for src in pack.get("data", {}).get("sources", []):
        if src.get("type") == "https":
            h = host_of(src.get("url", ""))
            if h:
                hosts.add(h)
            if "min_refresh_min" in src:
                per_source_refresh.append((src.get("id", "?"), src["min_refresh_min"]))

    secrets = pack.get("secrets") or {}
    secret_rows = []
    for name, spec in secrets.items():
        secret_rows.append((name, spec.get("hint", ""), spec.get("sent_to", [])))

    schedule = pack.get("schedule") or {}
    default_every = schedule.get("default", {}).get("every_min")
    windows = schedule.get("windows", [])

    print(f"### `{pack_id}` (v{version})")
    print()

    print("**Hosts contacted** (from `data.sources[].url`):")
    if hosts:
        for h in sorted(hosts):
            print(f"- `{h}`")
    else:
        print("- _none (inline-only pack — no network access)_")
    print()

    print("**Secrets declared:**")
    if secret_rows:
        print("| name | hint | sent to |")
        print("|---|---|---|")
        for name, hint, sent_to in secret_rows:
            print(f"| `{name}` | {hint} | {', '.join(sent_to) or '_none declared_'} |")
    else:
        print("- _none_")
    print()

    print("**Refresh cadence:**")
    if default_every is not None:
        print(f"- default: every {default_every} min")
    if windows:
        for w in windows:
            days = ",".join(w.get("days", []))
            print(f"- {days} {w.get('from')}-{w.get('to')}: every {w.get('every_min')} min")
    if per_source_refresh:
        for src_id, mins in per_source_refresh:
            print(f"- source `{src_id}`: will not re-fetch more often than every {mins} min "
                  "(`min_refresh_min`, serves the last snapshot in between)")
    if default_every is None and not windows:
        print("- _no schedule declared_")
    print()


def main(argv):
    paths = [p for p in argv[1:] if p.endswith(".yat-pack.json")]
    print("## Pack safety summary")
    print()
    print("Nothing in a pack is ever executed — a pack is a JSON document; the "
          "engine only ever reads its `data` (fetch/extract) and `render` "
          "(layout) sections, never runs code from it. This summary is a "
          "static read of what a changed pack *declares* it will reach and "
          "send, for reviewers to sanity-check.")
    print()

    if not paths:
        print("_No pack files changed in this PR._")
        return 0

    for path in paths:
        try:
            summarize(path)
        except Exception as e:  # keep going — one bad pack shouldn't blank the summary
            print(f"### `{path}`")
            print()
            print(f"_Could not summarize this pack: {e}_")
            print()

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
