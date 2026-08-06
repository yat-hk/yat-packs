#!/bin/sh
# Golden tests for this repo's pack library (official/ and, once populated,
# community/): each pack is rendered against its fixtures with the core
# engine's native preview binary and the PNG is compared byte-for-byte
# against goldens/. Deterministic throughout: --now is pinned.
#
# These blocks were split out of yat-hk/yat's tools/preview/run-tests.sh —
# see that script for the engine-mechanics tests (device capability
# profiles/--profile e1001, the battery glyph, for_each partial-result
# handling, the temp-trend chart auto-scale regression, and the general
# §11.3 empty-state/stale-serve taxonomy) that stay in the core repo because
# they are properties of the engine, not of any one pack.
set -e
cd "$(dirname "$0")/.."

YAT_CORE="${YAT_CORE:-../yat}"
PREVIEW="$YAT_CORE/tools/preview/yat-preview"

if [ ! -x "$PREVIEW" ]; then
  echo "Building yat-preview ($YAT_CORE/tools/preview)..."
  make -s -C "$YAT_CORE/tools/preview"
fi

NOW=1785142800  # fixed instant, matches upstream goldens

P=official/hko-now.yat-pack.json
# hko-now gained a second source in 0.2.0 (HKO warnsum, the active-warnings
# strip). Every pre-existing hko-now case below is about the OTHER source, so
# they all pin warnsum to the real "nothing in force" capture ({}) and keep
# asserting exactly what they asserted before. The warnings states get their
# own block further down.
WCLEAR="--doc warnsum=fixtures/hko-now.warnsum.json"

"$PREVIEW" "$P" --doc current=fixtures/hko-now.current.json $WCLEAR --now $NOW --out /tmp/yat-t1.png 2>/tmp/yat-t1.log
grep -q '"temp": 28' /tmp/yat-t1.log || { echo "FAIL: temp extraction"; exit 1; }
H1=$(grep '^hash:' /tmp/yat-t1.log)

"$PREVIEW" "$P" --doc current=fixtures/hko-hot.json $WCLEAR --now $NOW --out /tmp/yat-t2.png 2>/tmp/yat-t2.log
grep -q '"temp": 34' /tmp/yat-t2.log || { echo "FAIL: hot temp extraction"; exit 1; }
H2=$(grep '^hash:' /tmp/yat-t2.log)
[ "$H1" != "$H2" ] || { echo "FAIL: hash should differ between fixtures"; exit 1; }

# param overlay changes hash + extraction target
"$PREVIEW" "$P" --doc current=fixtures/hko-now.current.json $WCLEAR --params '{"district":"香港天文台"}' --now $NOW --out /tmp/yat-t3.png 2>/tmp/yat-t3.log
grep -q '"temp": 27' /tmp/yat-t3.log || { echo "FAIL: param-driven extraction"; exit 1; }

# determinism: identical inputs -> identical PNG
"$PREVIEW" "$P" --doc current=fixtures/hko-now.current.json $WCLEAR --now $NOW --out /tmp/yat-t1b.png 2>/dev/null
cmp -s /tmp/yat-t1.png /tmp/yat-t1b.png || { echo "FAIL: nondeterministic render"; exit 1; }

# golden compare (regenerate with: cp /tmp/yat-t1.png goldens/hko-now.png)
if [ -f goldens/hko-now.png ]; then
  cmp -s /tmp/yat-t1.png goldens/hko-now.png || { echo "FAIL: golden mismatch (goldens/hko-now.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/hko-now.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi


# ---- hko-now 0.2.0: the active-warnings strip. A second source (HKO warnsum)
# ---- feeds one hand-unrolled, `when`-guarded row per warning code; the strip
# ---- and its rule are gated on two `compute` fields that concatenate the 11
# ---- extracted codes, so "nothing in force" costs the page nothing at all.
# ---- The two states that matter are the two asserted here: warnings present,
# ---- and the empty `{}` the endpoint really returns most of the year.
WACTIVE="--doc warnsum=fixtures/hko-now.warnsum-active.json"

# a) warnings in force: the three codes extract, and BOTH compute guards agree
#    with them (warn_a carries the three, warn_b stays empty).
"$PREVIEW" "$P" --doc current=fixtures/hko-now.current.json $WACTIVE --now $NOW --out /tmp/yat-w1.png 2>/tmp/yat-w1.log
grep -q '"w_rain": "WRAINA"' /tmp/yat-w1.log || { echo "FAIL: warnings: WRAIN.code extraction"; exit 1; }
grep -q '"w_ts": "WTS"' /tmp/yat-w1.log || { echo "FAIL: warnings: WTS.code extraction"; exit 1; }
grep -q '"w_hot": "WHOT"' /tmp/yat-w1.log || { echo "FAIL: warnings: WHOT.code extraction"; exit 1; }
grep -q '"w_tc": null' /tmp/yat-w1.log || { echo "FAIL: warnings: an absent warning key should extract null"; exit 1; }
grep -q '"warn_a": "WRAINAWTSWHOT"' /tmp/yat-w1.log || { echo "FAIL: warnings: warn_a compute guard"; exit 1; }
grep -q '"warn_b": ""' /tmp/yat-w1.log || { echo "FAIL: warnings: warn_b should be empty here"; exit 1; }
grep -q 'render warn' /tmp/yat-w1.log && { echo "FAIL: warnings-active render produced a warning"; exit 1; }

"$PREVIEW" "$P" --doc current=fixtures/hko-now.current.json $WACTIVE --now $NOW --out /tmp/yat-w1b.png 2>/dev/null
cmp -s /tmp/yat-w1.png /tmp/yat-w1b.png || { echo "FAIL: nondeterministic render (warnings active)"; exit 1; }

# The whole point: the warnings state must not look like the clear state.
if cmp -s /tmp/yat-t1.png /tmp/yat-w1.png; then echo "FAIL: active warnings did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-w1.png goldens/hko-now-warnings.png)
if [ -f goldens/hko-now-warnings.png ]; then
  cmp -s /tmp/yat-w1.png goldens/hko-now-warnings.png || { echo "FAIL: golden mismatch (goldens/hko-now-warnings.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/hko-now-warnings.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# b) zero warnings — the real `{}` the endpoint serves whenever nothing is in
#    force. Every code extracts null, both guards go empty, and the strip and
#    its rule vanish: /tmp/yat-t1.png (the golden compared above) IS this
#    render, so the assertion is that the page is the plain weather page.
grep -q '"warn_a": ""' /tmp/yat-t1.log || { echo "FAIL: empty warnsum should leave warn_a empty"; exit 1; }
grep -q '"warn_b": ""' /tmp/yat-t1.log || { echo "FAIL: empty warnsum should leave warn_b empty"; exit 1; }
grep -q '"temp": 28' /tmp/yat-t1.log || { echo "FAIL: empty warnsum must not disturb the weather source"; exit 1; }

# c) ...and an empty warnsum must not blank the page. The clear render has to
#    carry the same ink the pre-0.2.0 page did — a `when` guard that swallowed
#    the temperature would still be "no render warning", so assert the pixels.
python3 - <<'EOF' || exit 1
import struct, sys, zlib
def load(p):
    d = open(p, 'rb').read(); pos = 8; idat = b''; w = h = 0
    while pos < len(d):
        ln = struct.unpack('>I', d[pos:pos+4])[0]
        typ, dat = d[pos+4:pos+8], d[pos+8:pos+8+ln]
        if typ == b'IHDR': w, h = struct.unpack('>II', dat[:8])
        if typ == b'IDAT': idat += dat
        pos += 12 + ln
    raw = zlib.decompress(idat); stride = w * 3; rows = []; prev = bytearray(stride); i = 0
    for _ in range(h):
        f = raw[i]; i += 1; line = bytearray(raw[i:i+stride]); i += stride
        for x in range(stride):
            a = line[x-3] if x >= 3 else 0
            b = prev[x]
            c = prev[x-3] if x >= 3 else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p_ = a + b - c
                pa, pb, pc = abs(p_-a), abs(p_-b), abs(p_-c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line)); prev = line
    return w, h, rows

w, h, rows = load('/tmp/yat-t1.png')
# Content area only (§9.1: 44px header, 32px footer) — the chrome always draws.
ink = sum(1 for y in range(44, h-32) for x in range(w) if rows[y][x*3:x*3+3] != b'\xff\xff\xff')
if ink < 3000:
    print(f"FAIL: clear page has only {ink} content pixels — an empty warnsum blanked it"); sys.exit(1)
EOF

# d) the honest failure: warnsum fetched and FAILED (no snapshot to fall back
#    on) leaves every code null, so the strip hides and the page degrades to
#    exactly the clear render — byte-identical, not merely similar.
"$PREVIEW" "$P" --doc current=fixtures/hko-now.current.json --doc warnsum=fixtures/does-not-exist.json --now $NOW --out /tmp/yat-wfail.png 2>/tmp/yat-wfail.log
grep -q 'source warnsum' /tmp/yat-wfail.log || { echo "FAIL: a failed warnsum fetch should be reported"; exit 1; }
grep -q '"temp": 28' /tmp/yat-wfail.log || { echo "FAIL: a failed warnsum must not take the weather source down with it"; exit 1; }
cmp -s /tmp/yat-t1.png /tmp/yat-wfail.png || { echo "FAIL: a failed warnsum should degrade to the clear page, not a broken one"; exit 1; }

# e) codes the pack does not draw (CANCEL is a real WTCSGNL code, §warnsum) must
#    match no row. The guards still go truthy, so this is the case that proves
#    the strip is code-matched rather than presence-matched: it renders the
#    clear page's content with an empty strip, never an invented row.
cat > /tmp/yat-warnsum-cancel.json <<'EOF'
{ "WTCSGNL": { "name": "熱帶氣旋警告信號", "code": "CANCEL", "actionCode": "CANCEL",
               "issueTime": "2026-07-27T16:00:00+08:00", "updateTime": "2026-07-27T16:00:00+08:00" } }
EOF
"$PREVIEW" "$P" --doc current=fixtures/hko-now.current.json --doc warnsum=/tmp/yat-warnsum-cancel.json --now $NOW --out /tmp/yat-wcancel.png 2>/tmp/yat-wcancel.log
grep -q '"w_tc": "CANCEL"' /tmp/yat-wcancel.log || { echo "FAIL: CANCEL should still extract as a code"; exit 1; }
grep -q 'render warn' /tmp/yat-wcancel.log && { echo "FAIL: a CANCEL code produced a render warning"; exit 1; }
if cmp -s /tmp/yat-w1.png /tmp/yat-wcancel.png; then echo "FAIL: CANCEL drew the warnings strip"; exit 1; fi

# ---- NOTE (yat-packs split): this case is the real-pack half of core's
# ---- §11.3 empty-state test (the rest, using a test-only fixture pack,
# ---- stayed in core/tools/preview/run-tests.sh). Kept here because the
# ---- assertion below is specific to hko-now's own compute fields, with
# ---- its own golden; flagged to the maintainer as a borderline call
# ---- between "pack appearance" and "engine mechanics".
# f) the real thing: hko-now with BOTH sources down and nothing on record —
#    what a household sees when HKO is unreachable on a cold device. Also the
#    case a "is every field null?" test gets wrong: hko-now's `compute` fields
#    resolve to "" (not null) even here, so the predicate has to be the
#    per-source outcome tally, not the shape of data().
"$PREVIEW" "$P" --doc current=fixtures/does-not-exist.json --doc warnsum=fixtures/does-not-exist.json --now $NOW --out /tmp/yat-hko-empty.png 2>/tmp/yat-hko-empty.log
grep -q 'render warn: empty state' /tmp/yat-hko-empty.log || { echo "FAIL: empty state: hko-now with both sources down did not draw the card"; exit 1; }
grep -q '"warn_a": ""' /tmp/yat-hko-empty.log || { echo "FAIL: empty state: expected hko-now's compute fields to be non-null here"; exit 1; }

"$PREVIEW" "$P" --doc current=fixtures/does-not-exist.json --doc warnsum=fixtures/does-not-exist.json --now $NOW --out /tmp/yat-hko-empty-b.png 2>/dev/null
cmp -s /tmp/yat-hko-empty.png /tmp/yat-hko-empty-b.png || { echo "FAIL: nondeterministic render (hko-now empty state)"; exit 1; }

# golden compare (regenerate with: cp /tmp/yat-hko-empty.png goldens/hko-now-empty.png)
if [ -f goldens/hko-now-empty.png ]; then
  cmp -s /tmp/yat-hko-empty.png goldens/hko-now-empty.png || { echo "FAIL: golden mismatch (goldens/hko-now-empty.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/hko-now-empty.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- family-board: the real pack that drives params-array list binding,
# ---- strings, pick_by_day and weekday (inline source, no fixtures needed).
# ---- Also the first pack whose every widget is really drawn (qr since v0.2,
# ---- icon since v0.3), so it carries a golden now.
F=official/family-board.yat-pack.json
"$PREVIEW" "$F" --now $NOW --out /tmp/yat-f1.png 2>/tmp/yat-f1.log
grep -q 'not implemented' /tmp/yat-f1.log && { echo "FAIL: family-board hit an unimplemented construct"; exit 1; }
grep -q 'placeholder box' /tmp/yat-f1.log && { echo "FAIL: family-board still drew a placeholder box"; exit 1; }
"$PREVIEW" "$F" --params '{"lang":"zh","show_album":false,"show_quote":false}' --now $NOW --out /tmp/yat-f2.png 2>/tmp/yat-f2.log
grep -q 'not implemented' /tmp/yat-f2.log && { echo "FAIL: family-board (zh, no album) hit an unimplemented construct"; exit 1; }
if cmp -s /tmp/yat-f1.png /tmp/yat-f2.png; then echo "FAIL: family-board params did not change the render"; exit 1; fi

"$PREVIEW" "$F" --now $NOW --out /tmp/yat-f1b.png 2>/dev/null
cmp -s /tmp/yat-f1.png /tmp/yat-f1b.png || { echo "FAIL: nondeterministic render (family-board)"; exit 1; }

# golden compare (regenerate with: cp /tmp/yat-f1.png goldens/family-board.png)
if [ -f goldens/family-board.png ]; then
  cmp -s /tmp/yat-f1.png goldens/family-board.png || { echo "FAIL: golden mismatch (goldens/family-board.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/family-board.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- hsi: keyless Yahoo Finance chart endpoint (level + previous close),
# ---- data-vs-data `when` (§6.5) for red/up-green/down colouring (HK
# ---- convention), bilingual strings + lang_param. No arithmetic filter
# ---- exists to derive a change value from two raw fields (SPEC-VALIDATION
# ---- #15), so direction comes from comparing data.level to data.prev_close
# ---- directly rather than a computed delta.
HSI=official/hsi.yat-pack.json

"$PREVIEW" "$HSI" --doc quote=fixtures/hsi.quote.json --now $NOW --out /tmp/yat-hsi.png 2>/tmp/yat-hsi.log
grep -q '"level": 25942' /tmp/yat-hsi.log || { echo "FAIL: hsi: level extraction"; exit 1; }
grep -q '"prev_close": 25850' /tmp/yat-hsi.log || { echo "FAIL: hsi: prev_close extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-hsi.log && { echo "FAIL: hsi render produced a warning"; exit 1; }

"$PREVIEW" "$HSI" --doc quote=fixtures/hsi.quote.json --now $NOW --out /tmp/yat-hsi-b.png 2>/dev/null
cmp -s /tmp/yat-hsi.png /tmp/yat-hsi-b.png || { echo "FAIL: nondeterministic render (hsi)"; exit 1; }

# lang param changes the render (bilingual strings + lang-gated widgets)
"$PREVIEW" "$HSI" --doc quote=fixtures/hsi.quote.json --params '{"lang":"en"}' --now $NOW --out /tmp/yat-hsi-en.png 2>/tmp/yat-hsi-en.log
if cmp -s /tmp/yat-hsi.png /tmp/yat-hsi-en.png; then echo "FAIL: hsi lang param did not change the render"; exit 1; fi

# a down day (synthetic fixture: level < prev_close) must render differently
# from an up day and must not warn — proves the when-guarded 3-way colour
# split (red up / green down / black flat) actually branches.
python3 -c "
import json
d = json.load(open('fixtures/hsi.quote.json'))
m = d['chart']['result'][0]['meta']
m['regularMarketPrice'] = 25500.12
m['regularMarketDayLow'] = 25450.0
m['regularMarketDayHigh'] = 25820.0
json.dump(d, open('/tmp/yat-hsi-down.json', 'w'))
"
"$PREVIEW" "$HSI" --doc quote=/tmp/yat-hsi-down.json --now $NOW --out /tmp/yat-hsi-down.png 2>/tmp/yat-hsi-down.log
grep -q '"level": 25500' /tmp/yat-hsi-down.log || { echo "FAIL: hsi down-day fixture did not extract"; exit 1; }
grep -q 'render warn' /tmp/yat-hsi-down.log && { echo "FAIL: hsi down-day render produced a warning"; exit 1; }
if cmp -s /tmp/yat-hsi.png /tmp/yat-hsi-down.png; then echo "FAIL: hsi up vs down day rendered identically"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-hsi.png goldens/hsi.png)
if [ -f goldens/hsi.png ]; then
  cmp -s /tmp/yat-hsi.png goldens/hsi.png || { echo "FAIL: golden mismatch (goldens/hsi.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/hsi.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- hko-9day: HKO 9-day forecast (fnd), plain (non-for_each) list bound to
# ---- the extracted weatherForecast array, icon mapped from ForecastIcon via
# ---- when-guard ranges, `days` integer param bound to both first(n) at
# ---- extraction and list.max_rows. The feed's own `week` field is already
# ---- localized per the fetch's `lang` query param, sidestepping the
# ---- forecastDate ("20260731", no separators) date-filter incompatibility
# ---- noted in the pack authoring report.
FND=official/hko-9day.yat-pack.json

"$PREVIEW" "$FND" --doc forecast=fixtures/hko-9day.forecast.json --now $NOW --out /tmp/yat-fnd.png 2>/tmp/yat-fnd.log
grep -q '"week": "星期五"' /tmp/yat-fnd.log || { echo "FAIL: hko-9day: week field extraction"; exit 1; }
grep -q '"ForecastIcon": 63' /tmp/yat-fnd.log || { echo "FAIL: hko-9day: ForecastIcon extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-fnd.log && { echo "FAIL: hko-9day render produced a warning"; exit 1; }

"$PREVIEW" "$FND" --doc forecast=fixtures/hko-9day.forecast.json --now $NOW --out /tmp/yat-fnd-b.png 2>/dev/null
cmp -s /tmp/yat-fnd.png /tmp/yat-fnd-b.png || { echo "FAIL: nondeterministic render (hko-9day)"; exit 1; }

# lang=en (separate fixture: --doc ignores the substituted URL, so proving an
# URL-affecting param needs its own fixture, §"Test param variations") +
# days=3 (bound to both first(n) and list.max_rows) must change the render.
"$PREVIEW" "$FND" --doc forecast=fixtures/hko-9day.forecast-en.json --params '{"lang":"en","days":3}' --now $NOW --out /tmp/yat-fnd-en3.png 2>/tmp/yat-fnd-en3.log
grep -q '"week": "Friday"' /tmp/yat-fnd-en3.log || { echo "FAIL: hko-9day: lang=en did not fetch the English feed"; exit 1; }
grep -q 'render warn' /tmp/yat-fnd-en3.log && { echo "FAIL: hko-9day (en, days=3) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-fnd.png /tmp/yat-fnd-en3.png; then echo "FAIL: hko-9day lang/days params did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-fnd.png goldens/hko-9day.png)
if [ -f goldens/hko-9day.png ]; then
  cmp -s /tmp/yat-fnd.png goldens/hko-9day.png || { echo "FAIL: golden mismatch (goldens/hko-9day.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/hko-9day.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# `days` goes up to 9 and the page has to actually hold 9 of them. At the
# original `medium` forecast icons a row was 48px tall (the icon, not the text,
# set the height) and the last three days fell off the bottom — the panel showed
# a "9-day forecast" with 6 days on it and only the render warning said so. The
# icons are `small` now and the row is text-height; this is the assertion that
# keeps the tightening from being undone by a later "make the icons bigger".
"$PREVIEW" "$FND" --doc forecast=fixtures/hko-9day.forecast.json --params '{"days":9}' --now $NOW --out /tmp/yat-fnd9.png 2>/tmp/yat-fnd9.log
grep -q 'layout overflow' /tmp/yat-fnd9.log && { echo "FAIL: hko-9day at days=9 overflows its content box — not all 9 days fit"; exit 1; }
grep -q 'render warn' /tmp/yat-fnd9.log && { echo "FAIL: hko-9day (days=9) render produced a warning"; exit 1; }
# days now DEFAULTS to 9 (the pack is named "9-Day Forecast"); the variant
# worth asserting is a user turning it DOWN.
"$PREVIEW" "$FND" --doc forecast=fixtures/hko-9day.forecast.json --params '{"days":5}' --now $NOW --out /tmp/yat-fnd5.png 2>/tmp/yat-fnd5.log
if cmp -s /tmp/yat-fnd.png /tmp/yat-fnd5.png; then echo "FAIL: hko-9day days=5 rendered the same as the 9-day default"; exit 1; fi

# ---- NOTE (yat-packs split): only temp-trend's basic render/golden test
# ---- moved here. The winter-fixture chart auto-scale regression test
# ---- (same pack, a second fixture) stayed in core/tools/preview/
# ---- run-tests.sh together with goldens/temp-trend-winter.png — it is a
# ---- pinned regression against an engine behavior (chart min/max
# ---- scaling), not a property of this pack's own appearance.
# ---- temp-trend: the pack the clipping bug was reported against, now a line
# ---- chart of the day (§9.12a) instead of eight hand-unrolled bar rows. The
# ---- chart takes `flex: 1`, so the page cannot overflow however the hourly
# ---- series moves — which is what the no-warning assertion below pins down.
TT=official/temp-trend.yat-pack.json
"$PREVIEW" "$TT" --doc meteo=fixtures/temp-trend.meteo.json --now $NOW --out /tmp/yat-tt.png 2>/tmp/yat-tt.log
grep -q '"temps": \[' /tmp/yat-tt.log || { echo "FAIL: temp-trend: hourly series did not extract as an array"; exit 1; }
grep -q 'layout overflow' /tmp/yat-tt.log && { echo "FAIL: temp-trend overflows its content box (the reported bug)"; exit 1; }
grep -q 'render warn' /tmp/yat-tt.log && { echo "FAIL: temp-trend render produced a warning"; exit 1; }

"$PREVIEW" "$TT" --doc meteo=fixtures/temp-trend.meteo.json --now $NOW --out /tmp/yat-tt-b.png 2>/dev/null
cmp -s /tmp/yat-tt.png /tmp/yat-tt-b.png || { echo "FAIL: nondeterministic render (temp-trend)"; exit 1; }

# golden compare (regenerate with: cp /tmp/yat-tt.png goldens/temp-trend.png)
if [ -f goldens/temp-trend.png ]; then
  cmp -s /tmp/yat-tt.png goldens/temp-trend.png || { echo "FAIL: golden mismatch (goldens/temp-trend.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/temp-trend.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- 2.3.0: user-reported on hardware — the chart's X-axis "always ends at
# ---- 21:00". Root cause: the Open-Meteo request used forecast_days=1, a
# ---- fixed calendar-day window (00:00-21:00 every-3-hours), so the frame
# ---- never moved until local midnight rolled the whole day over — a device
# ---- glanced at in the evening showed a dead, already-happened afternoon.
# ---- Fix is a pure request reshape, no engine/spec change: swap
# ---- forecast_days's grip on the *hourly* block for past_hours=6 +
# ---- forecast_hours=16, which Open-Meteo anchors to the live clock instead
# ---- of the calendar day (forecast_days=1 stays, now scoped to the `daily`
# ---- hi/lo block only, which is genuinely a "today" figure). The result is
# ---- an 8-point window from -6h to +15h around whatever "now" is — roughly
# ---- 6 hours of recent history plus the next 15 hours, still on the
# ---- existing 3-hourly grid, same response size. Extraction (`temps`,
# ---- `first_hour`, `last_hour`) is untouched: it already just takes the
# ---- whole hourly array and its own first/last timestamp, so the labels
# ---- move for free once the array itself is now-anchored.
# ----
# ---- Verified against Open-Meteo directly (`past_hours=6&forecast_hours=16`
# ---- against the live API) before writing these fixtures: the two fixtures
# ---- below are hand-built to the same 8-point/-6h..+15h shape real
# ---- responses take at two different times of day, sharing every
# ---- overlapping timestamp's value so they read as one consistent day
# ---- observed from two different moments, not two unrelated days. Because
# ---- the window is resolved by the *request* (Open-Meteo's live clock), not
# ---- by an in-pack now-relative filter, "same fixture, different --now"
# ---- doesn't apply here — there is no engine feature to filter a date
# ---- range out of one document (extraction filters are equality-only,
# ---- §6.1/§6.4; no ordering comparator exists in that grammar). What *is*
# ---- tested is the property that actually matters: given whatever window
# ---- the request comes back with, the pack's labels and plotted line
# ---- faithfully track it instead of assuming a fixed shape — morning
# ---- fixture spans 03:00 today to 00:00 tomorrow (the day still ahead);
# ---- evening fixture spans 15:00 today to 12:00 tomorrow (tonight into
# ---- tomorrow morning) — proving the frame actually moves.
"$PREVIEW" "$TT" --doc meteo=fixtures/temp-trend.meteo-morning.json --now 1785114000 --out /tmp/yat-tt-morning.png 2>/tmp/yat-tt-morning.log
grep -q '"first_hour": "2026-07-27T03:00"' /tmp/yat-tt-morning.log || { echo "FAIL: temp-trend morning: first_hour did not extract the rolling window start"; exit 1; }
grep -q '"last_hour": "2026-07-28T00:00"' /tmp/yat-tt-morning.log || { echo "FAIL: temp-trend morning: last_hour did not extract the rolling window end"; exit 1; }
grep -q 'render warn' /tmp/yat-tt-morning.log && { echo "FAIL: temp-trend morning render produced a warning"; exit 1; }

"$PREVIEW" "$TT" --doc meteo=fixtures/temp-trend.meteo-evening.json --now 1785157200 --out /tmp/yat-tt-evening.png 2>/tmp/yat-tt-evening.log
grep -q '"first_hour": "2026-07-27T15:00"' /tmp/yat-tt-evening.log || { echo "FAIL: temp-trend evening: first_hour did not extract the rolling window start"; exit 1; }
grep -q '"last_hour": "2026-07-28T12:00"' /tmp/yat-tt-evening.log || { echo "FAIL: temp-trend evening: last_hour did not extract the rolling window end"; exit 1; }
grep -q 'render warn' /tmp/yat-tt-evening.log && { echo "FAIL: temp-trend evening render produced a warning"; exit 1; }

# the two windows must produce genuinely different renders — the bug's
# signature was the axis (and therefore the whole panel) never changing.
cmp -s /tmp/yat-tt-morning.png /tmp/yat-tt-evening.png && { echo "FAIL: temp-trend morning and evening windows rendered byte-identical (the reported bug)"; exit 1; }

# determinism, each window
"$PREVIEW" "$TT" --doc meteo=fixtures/temp-trend.meteo-morning.json --now 1785114000 --out /tmp/yat-tt-morning-b.png 2>/dev/null
cmp -s /tmp/yat-tt-morning.png /tmp/yat-tt-morning-b.png || { echo "FAIL: nondeterministic render (temp-trend morning)"; exit 1; }
"$PREVIEW" "$TT" --doc meteo=fixtures/temp-trend.meteo-evening.json --now 1785157200 --out /tmp/yat-tt-evening-b.png 2>/dev/null
cmp -s /tmp/yat-tt-evening.png /tmp/yat-tt-evening-b.png || { echo "FAIL: nondeterministic render (temp-trend evening)"; exit 1; }

# golden compare (regenerate with: cp /tmp/yat-tt-morning.png goldens/temp-trend-morning.png)
if [ -f goldens/temp-trend-morning.png ]; then
  cmp -s /tmp/yat-tt-morning.png goldens/temp-trend-morning.png || { echo "FAIL: golden mismatch (goldens/temp-trend-morning.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/temp-trend-morning.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# golden compare (regenerate with: cp /tmp/yat-tt-evening.png goldens/temp-trend-evening.png)
if [ -f goldens/temp-trend-evening.png ]; then
  cmp -s /tmp/yat-tt-evening.png goldens/temp-trend-evening.png || { echo "FAIL: golden mismatch (goldens/temp-trend-evening.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/temp-trend-evening.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- §9.10 image placeholder. photo-frame's whole body is one 800x404 image
# ---- widget, so "the box renders empty" on a fetch failure meant a blank
# ---- panel — indistinguishable from a dead device on a screen that holds its
# ---- last image with the power off. The box now draws as an empty frame with
# ---- the reason inside it.
PF=official/photo-frame.yat-pack.json
PFPARAMS='{"image_url":"https://example.com/photo.png","fit":"contain"}'

"$PREVIEW" "$PF" --params "$PFPARAMS" --now $NOW --out /tmp/yat-pf-noimage.png 2>/tmp/yat-pf-noimage.log
grep -q 'render warn: image fetch failed' /tmp/yat-pf-noimage.log || { echo "FAIL: photo-frame: a failed image fetch should still warn"; exit 1; }

"$PREVIEW" "$PF" --params "$PFPARAMS" --now $NOW --out /tmp/yat-pf-noimage-b.png 2>/dev/null
cmp -s /tmp/yat-pf-noimage.png /tmp/yat-pf-noimage-b.png || { echo "FAIL: nondeterministic render (photo-frame placeholder)"; exit 1; }

# golden compare (regenerate with: cp /tmp/yat-pf-noimage.png goldens/photo-frame-noimage.png)
if [ -f goldens/photo-frame-noimage.png ]; then
  cmp -s /tmp/yat-pf-noimage.png goldens/photo-frame-noimage.png || { echo "FAIL: golden mismatch (goldens/photo-frame-noimage.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/photo-frame-noimage.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- photo-frame with-image: the fetched-and-decoded photo, not just the
# ---- fetch-failure placeholder pinned above. The image widget has no source
# ---- id of its own — the engine always fetches it as the pseudo-id "image"
# ---- (§9.10, see also render_all.py's fixture_args), so fixtures/
# ---- photo-frame.image.png (an 800x404 PNG, matching the widget's own box
# ---- exactly) wires it up via --doc image=.
"$PREVIEW" "$PF" --params "$PFPARAMS" --doc image=fixtures/photo-frame.image.png --now $NOW --out /tmp/yat-pf-image.png 2>/tmp/yat-pf-image.log
grep -q 'render warn' /tmp/yat-pf-image.log && { echo "FAIL: photo-frame (with image) render produced a warning"; exit 1; }

"$PREVIEW" "$PF" --params "$PFPARAMS" --doc image=fixtures/photo-frame.image.png --now $NOW --out /tmp/yat-pf-image-b.png 2>/dev/null
cmp -s /tmp/yat-pf-image.png /tmp/yat-pf-image-b.png || { echo "FAIL: nondeterministic render (photo-frame with image)"; exit 1; }

# the fetched-image state must not look like the fetch-failure placeholder
if cmp -s /tmp/yat-pf-noimage.png /tmp/yat-pf-image.png; then echo "FAIL: photo-frame with-image render is identical to the no-image placeholder"; exit 1; fi

# params variance: `fit` only visibly diverges (contain vs stretch) when the
# source image's aspect ratio differs from the 800x404 box — which
# photo-frame.image.png deliberately does not (it's pinned as the clean
# full-frame golden above), so this reuses test-image-mini's 200x120 (5:3)
# gradient fixture, which does, to prove the param actually changes the render.
PFSTRETCH='{"image_url":"https://example.com/photo.png","fit":"stretch"}'
"$PREVIEW" "$PF" --params "$PFSTRETCH" --doc image=fixtures/test-image-gradient.png --now $NOW --out /tmp/yat-pf-grad-stretch.png 2>/tmp/yat-pf-grad-stretch.log
grep -q 'render warn' /tmp/yat-pf-grad-stretch.log && { echo "FAIL: photo-frame (fit stretch, gradient) render produced a warning"; exit 1; }
"$PREVIEW" "$PF" --params "$PFPARAMS" --doc image=fixtures/test-image-gradient.png --now $NOW --out /tmp/yat-pf-grad-contain.png 2>/tmp/yat-pf-grad-contain.log
grep -q 'render warn' /tmp/yat-pf-grad-contain.log && { echo "FAIL: photo-frame (fit contain, gradient) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-pf-grad-stretch.png /tmp/yat-pf-grad-contain.png; then echo "FAIL: photo-frame fit param did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-pf-image.png goldens/photo-frame-image.png)
if [ -f goldens/photo-frame-image.png ]; then
  cmp -s /tmp/yat-pf-image.png goldens/photo-frame-image.png || { echo "FAIL: golden mismatch (goldens/photo-frame-image.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/photo-frame-image.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# The placeholder has to be *ink*, not a relabeled blank: a golden compare
# alone would happily lock in an empty content band. Same content-area pixel
# count the clear-page assertion above uses, applied to both new surfaces.
python3 - <<'EOF' || exit 1
import struct, sys, zlib
def load(p):
    d = open(p, 'rb').read(); pos = 8; idat = b''; w = h = 0
    while pos < len(d):
        ln = struct.unpack('>I', d[pos:pos+4])[0]
        typ, dat = d[pos+4:pos+8], d[pos+8:pos+8+ln]
        if typ == b'IHDR': w, h = struct.unpack('>II', dat[:8])
        if typ == b'IDAT': idat += dat
        pos += 12 + ln
    raw = zlib.decompress(idat); stride = w * 3; rows = []; prev = bytearray(stride); i = 0
    for _ in range(h):
        f = raw[i]; i += 1; line = bytearray(raw[i:i+stride]); i += stride
        for x in range(stride):
            a = line[x-3] if x >= 3 else 0
            b = prev[x]
            c = prev[x-3] if x >= 3 else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p_ = a + b - c
                pa, pb, pc = abs(p_-a), abs(p_-b), abs(p_-c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line)); prev = line
    return w, h, rows

for path, floor, what in (('/tmp/yat-hko-empty.png', 2000, 'empty-state card'),
                          ('/tmp/yat-pf-noimage.png', 2000, 'image placeholder')):
    w, h, rows = load(path)
    # Content area only (§9.1: 44px header, 32px footer) — the chrome always draws.
    ink = sum(1 for y in range(44, h-32) for x in range(w)
              if rows[y][x*3:x*3+3] != b'\xff\xff\xff')
    if ink < floor:
        print(f"FAIL: {what} put only {ink} pixels in the content band — that is still a blank page")
        sys.exit(1)
EOF

# ---- headlines-simple / news-sections: the two RTHK packs. Both used to carry
# ---- a fixture captured from a live pull, but a live capture is the wrong
# ---- thing to pin a golden to — re-capture it and every strict assertion
# ---- breaks for reasons that have nothing to do with the engine, and it also
# ---- means committing a real broadcaster's editorial text into the repo. So
# ---- both fixture variants are now hand-written: same shape as the real feed
# ---- (CDATA titles, RFC 822 +0800 pubDate, guid/link/description per item —
# ---- verified against the live endpoints), invented placeholder content
# ---- throughout. The plain fixtures (fixtures/*.rthk.xml,
# ---- fixtures/*.feeds.[1-4].xml) keep their loose shape assertions above;
# ---- the "-fixed" ones carry the strict assertions and the goldens.
HL=official/headlines-simple.yat-pack.json

"$PREVIEW" "$HL" --doc rthk=fixtures/headlines-simple.rthk-fixed.xml --now $NOW --out /tmp/yat-hl.png 2>/tmp/yat-hl.log
grep -q 'render warn' /tmp/yat-hl.log && { echo "FAIL: headlines-simple render produced a warning"; exit 1; }
grep -q '"latest": "2026-07-27T16:12:00+08:00"' /tmp/yat-hl.log || { echo "FAIL: headlines-simple: items[0].pub_date not normalized to ISO+08:00"; exit 1; }
grep -q '天文台預測本週後期氣溫逐步下降' /tmp/yat-hl.log || { echo "FAIL: headlines-simple: CDATA title did not extract"; exit 1; }

"$PREVIEW" "$HL" --doc rthk=fixtures/headlines-simple.rthk-fixed.xml --now $NOW --out /tmp/yat-hl-b.png 2>/dev/null
cmp -s /tmp/yat-hl.png /tmp/yat-hl-b.png || { echo "FAIL: nondeterministic render (headlines-simple)"; exit 1; }

# top_n drives both the extraction (`items|first(n)`) and list.max_rows, so it
# has to change the render, not just the extracted array.
"$PREVIEW" "$HL" --doc rthk=fixtures/headlines-simple.rthk-fixed.xml --params '{"top_n":3}' --now $NOW --out /tmp/yat-hl3.png 2>/tmp/yat-hl3.log
grep -q 'render warn' /tmp/yat-hl3.log && { echo "FAIL: headlines-simple (top_n=3) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-hl.png /tmp/yat-hl3.png; then echo "FAIL: headlines-simple top_n did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-hl.png goldens/headlines-simple.png)
if [ -f goldens/headlines-simple.png ]; then
  cmp -s /tmp/yat-hl.png goldens/headlines-simple.png || { echo "FAIL: golden mismatch (goldens/headlines-simple.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/headlines-simple.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# news-sections is the §9.8a nested-list pack in production form: a for_each
# source over the chosen sections, the outer list bound to its collect.field and
# the inner one to item.top. Its row template is a ROW (makeRowTemplate, §9.8),
# so the section label and its headlines sit side by side — the label takes
# flex 1 and the list flex 4, which is what keeps every section's headlines
# starting at the same x instead of wherever that section's name happened to end.
NS=official/news-sections.yat-pack.json
NSDOC="--doc feeds=fixtures/news-sections.feeds-fixed.1.xml,fixtures/news-sections.feeds-fixed.2.xml,fixtures/news-sections.feeds-fixed.3.xml,fixtures/news-sections.feeds-fixed.4.xml"

"$PREVIEW" "$NS" $NSDOC --now $NOW --out /tmp/yat-ns.png 2>/tmp/yat-ns.log
grep -q 'not implemented' /tmp/yat-ns.log && { echo "FAIL: news-sections hit an unimplemented construct"; exit 1; }
grep -q 'E_BIND\|render warn' /tmp/yat-ns.log && { echo "FAIL: news-sections render produced a warning"; exit 1; }
grep -q '"each": "c_expressnews_clocal"' /tmp/yat-ns.log || { echo "FAIL: news-sections: outer item.each missing"; exit 1; }
grep -q '恒指收市升168點' /tmp/yat-ns.log || { echo "FAIL: news-sections: the finance section's nested items did not extract"; exit 1; }

"$PREVIEW" "$NS" $NSDOC --now $NOW --out /tmp/yat-ns-b.png 2>/dev/null
cmp -s /tmp/yat-ns.png /tmp/yat-ns-b.png || { echo "FAIL: nondeterministic render (news-sections)"; exit 1; }

# golden compare (regenerate with: cp /tmp/yat-ns.png goldens/news-sections.png)
if [ -f goldens/news-sections.png ]; then
  cmp -s /tmp/yat-ns.png goldens/news-sections.png || { echo "FAIL: golden mismatch (goldens/news-sections.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/news-sections.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# The finance disclaimer is gated on `params.sections has 'c_expressnews_cfinance'`
# (§6.5 membership over an array param) — the one construct on this page that a
# fixture cannot exercise, since it reads the param and not the feed. Dropping
# finance from the selection must take the line with it.
"$PREVIEW" "$NS" --doc feeds=fixtures/news-sections.feeds-fixed.1.xml,fixtures/news-sections.feeds-fixed.2.xml --params '{"sections":["c_expressnews_clocal","c_expressnews_cinternational"]}' --now $NOW --out /tmp/yat-ns-nofin.png 2>/tmp/yat-ns-nofin.log
grep -q 'render warn' /tmp/yat-ns-nofin.log && { echo "FAIL: news-sections (no finance) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-ns.png /tmp/yat-ns-nofin.png; then echo "FAIL: news-sections section selection did not change the render"; exit 1; fi

# ---- sushiro-queue: the wait-time column read ragged (numbers not aligned
# ---- into a column, so magnitude wasn't glanceable) because `align: "right"`
# ---- on the combined "{{item.wait}} {{strings.wait_min}}" string is a no-op
# ---- when the text box is sized to its own content (the row-is-only-as-
# ---- wide-as-its-content trap) — right-alignment only matters when there is
# ---- slack inside the box, and there wasn't any. Padding the number to a
# ---- fixed 2-character width (`pad(2,' ')`) equalizes the combined string's
# ---- length across rows instead, which shifts the *box position* (via the
# ---- row's flex distribution) so the ones-digit lands in the same column
# ---- for every row, tens digit (10, 15) extending left of it — the standard
# ---- right-justified-number-column look.
SQ=official/sushiro-queue.yat-pack.json
"$PREVIEW" "$SQ" --doc stores=fixtures/sushiro-queue.stores.json --now $NOW --out /tmp/yat-sq.png 2>/tmp/yat-sq.log
grep -q 'render warn' /tmp/yat-sq.log && { echo "FAIL: sushiro-queue render produced a warning"; exit 1; }

"$PREVIEW" "$SQ" --doc stores=fixtures/sushiro-queue.stores.json --now $NOW --out /tmp/yat-sq-b.png 2>/dev/null
cmp -s /tmp/yat-sq.png /tmp/yat-sq-b.png || { echo "FAIL: nondeterministic render (sushiro-queue)"; exit 1; }

python3 - <<'EOF' || exit 1
import struct, zlib, sys
def rows(path):
    d = open(path, 'rb').read()
    pos, w, h, idat = 8, 0, 0, b''
    while pos < len(d):
        ln = struct.unpack('>I', d[pos:pos+4])[0]; typ = d[pos+4:pos+8]
        if typ == b'IHDR': w, h = struct.unpack('>II', d[pos+8:pos+16])
        elif typ == b'IDAT': idat += d[pos+8:pos+8+ln]
        pos += 12 + ln
    raw = zlib.decompress(idat); out = []; prev = bytearray(w*3); i = 0
    for _ in range(h):
        f = raw[i]; i += 1; line = bytearray(raw[i:i+w*3]); i += w*3
        if f == 1:
            for x in range(3, len(line)): line[x] = (line[x] + line[x-3]) & 255
        elif f == 2:
            for x in range(len(line)): line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(len(line)): line[x] = (line[x] + ((line[x-3] if x>=3 else 0) + prev[x])//2) & 255
        elif f == 4:
            def pd(a,b,c):
                p=a+b-c; pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
                return a if pa<=pb and pa<=pc else (b if pb<=pc else c)
            for x in range(len(line)):
                line[x] = (line[x] + pd(line[x-3] if x>=3 else 0, prev[x], prev[x-3] if x>=3 else 0)) & 255
        out.append(bytes(line)); prev = line
    return w, h, out
w, h, px = rows('/tmp/yat-sq.png')
def col_has_ink(x, y0, y1):
    for y in range(y0, y1):
        r, g, b = px[y][x*3], px[y][x*3+1], px[y][x*3+2]
        if not (r > 240 and g > 240 and b > 240): return True
    return False
# Five rows, waits 5,5,0,10,15 (fixtures/sushiro-queue.stores.json), each ~54px
# apart starting ~y=65 (colour varies per row — good/warn — so ink is
# detected as "not white" on any channel, not by a fixed dark threshold).
# The ones-digit occupies x 548-563 in every row; the tens digit (only
# present for the two-digit waits, 10 and 15) sits to its left at x 535-545.
# Right-justifying the number column means: ones-digit band lit in all 5
# rows, tens-digit band lit only in the two 2-digit rows.
row_ys = [70, 124, 178, 232, 286]
expect_tens = [False, False, False, True, True]  # waits: 5, 5, 0, 10, 15
for y0, want_tens in zip(row_ys, expect_tens):
    if not any(col_has_ink(x, y0, y0 + 16) for x in range(548, 563)):
        print(f"FAIL: ones-digit column (x 548-563) has no ink at y~{y0} — column alignment broke")
        sys.exit(1)
    got_tens = any(col_has_ink(x, y0, y0 + 16) for x in range(535, 545))
    if got_tens != want_tens:
        print(f"FAIL: tens-digit band at y~{y0} expected ink={want_tens}, got={got_tens} — "
              "the ragged wait-time column bug regressed")
        sys.exit(1)
EOF

# golden compare (regenerate with: cp /tmp/yat-sq.png goldens/sushiro-queue.png)
if [ -f goldens/sushiro-queue.png ]; then
  cmp -s /tmp/yat-sq.png goldens/sushiro-queue.png || { echo "FAIL: golden mismatch (goldens/sushiro-queue.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/sushiro-queue.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- aqhi: EPD's per-station AQHI feed, one flat array of all 18 stations.
# ---- `extract` filters that array by `[?station=='{{params.station}}']`, so
# ---- the fixture carries every station and the test proves the JMESPath
# ---- picks the right row rather than always the first. Colour band
# ---- (good/warn/danger/black) is a `when` on the numeric value plus a
# ---- `risk == 'Serious'` override; the fixture is all Low-risk stations
# ---- (aqhi 2-3), so only the "good" band is exercised here. show_advice
# ---- toggles the health-tip column without touching the fetch at all.
AQHI=official/aqhi.yat-pack.json

"$PREVIEW" "$AQHI" --doc aqhi_now=fixtures/aqhi.aqhi_now.json --now $NOW --out /tmp/yat-aqhi.png 2>/tmp/yat-aqhi.log
grep -q '"aqhi": 2' /tmp/yat-aqhi.log || { echo "FAIL: aqhi: aqhi extraction (default station)"; exit 1; }
grep -q '"risk": "Low"' /tmp/yat-aqhi.log || { echo "FAIL: aqhi: risk extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-aqhi.log && { echo "FAIL: aqhi render produced a warning"; exit 1; }

"$PREVIEW" "$AQHI" --doc aqhi_now=fixtures/aqhi.aqhi_now.json --now $NOW --out /tmp/yat-aqhi-b.png 2>/dev/null
cmp -s /tmp/yat-aqhi.png /tmp/yat-aqhi-b.png || { echo "FAIL: nondeterministic render (aqhi)"; exit 1; }

# a different station picks a different row out of the same fixture — proves
# the JMESPath filter retargets, not just that the station label changed
"$PREVIEW" "$AQHI" --doc aqhi_now=fixtures/aqhi.aqhi_now.json --params '{"station":"Causeway Bay"}' --now $NOW --out /tmp/yat-aqhi-cwb.png 2>/tmp/yat-aqhi-cwb.log
grep -q '"aqhi": 3' /tmp/yat-aqhi-cwb.log || { echo "FAIL: aqhi: station param did not retarget the extraction"; exit 1; }
if cmp -s /tmp/yat-aqhi.png /tmp/yat-aqhi-cwb.png; then echo "FAIL: aqhi station param did not change the render"; exit 1; fi

# show_advice=false drops the health-tip column
"$PREVIEW" "$AQHI" --doc aqhi_now=fixtures/aqhi.aqhi_now.json --params '{"show_advice":false}' --now $NOW --out /tmp/yat-aqhi-noadvice.png 2>/tmp/yat-aqhi-noadvice.log
grep -q 'render warn' /tmp/yat-aqhi-noadvice.log && { echo "FAIL: aqhi (show_advice=false) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-aqhi.png /tmp/yat-aqhi-noadvice.png; then echo "FAIL: aqhi show_advice param did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-aqhi.png goldens/aqhi.png)
if [ -f goldens/aqhi.png ]; then
  cmp -s /tmp/yat-aqhi.png goldens/aqhi.png || { echo "FAIL: golden mismatch (goldens/aqhi.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/aqhi.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- NOTE (yat-packs split): only commute-combo's default three-operator
# ---- render moved here. The for_each partial-results (option D) and
# ---- all-KMB-failed E_BIND (option A) cases — goldens
# ---- commute-combo-partial.png / commute-combo-bindfail.png — stayed in
# ---- core/tools/preview/run-tests.sh: they pin RFC-foreach-partial-
# ---- results.md engine behavior, not this pack's appearance.
# ---- commute-combo: three independent operators on one page — KMB is a
# ---- for_each source (one fetch per configured stop, collected into
# ---- data.kmb_etas), Citybus and MTR are each a single `when`-gated source
# ---- (show_ctb / show_mtr) that drops out of the page entirely when off.
# ---- Defaults wire up both KMB stops plus one Citybus stop and one MTR
# ---- station, so the plain default render already exercises all three.
CC=official/commute-combo.yat-pack.json
CCDOC="--doc kmb=fixtures/commute-combo.kmb.1.json,fixtures/commute-combo.kmb.2.json --doc ctb=fixtures/commute-combo.ctb.json --doc mtr=fixtures/commute-combo.mtr.json"

"$PREVIEW" "$CC" $CCDOC --now $NOW --out /tmp/yat-cc.png 2>/tmp/yat-cc.log
grep -q '麗港城' /tmp/yat-cc.log || { echo "FAIL: commute-combo: KMB for_each dest_tc did not extract"; exit 1; }
grep -q '"dest_en": "Central (Macao Ferry)"' /tmp/yat-cc.log || { echo "FAIL: commute-combo: Citybus dest_en did not extract"; exit 1; }
grep -q '"ttnt": "3"' /tmp/yat-cc.log || { echo "FAIL: commute-combo: MTR next-train ttnt did not extract"; exit 1; }
grep -q 'render warn' /tmp/yat-cc.log && { echo "FAIL: commute-combo render produced a warning"; exit 1; }

"$PREVIEW" "$CC" $CCDOC --now $NOW --out /tmp/yat-cc-b.png 2>/dev/null
cmp -s /tmp/yat-cc.png /tmp/yat-cc-b.png || { echo "FAIL: nondeterministic render (commute-combo)"; exit 1; }

# show_ctb=false must drop the source's fetch (no --doc ctb= at all here) and
# the whole section, not just leave it blank
"$PREVIEW" "$CC" --doc kmb=fixtures/commute-combo.kmb.1.json,fixtures/commute-combo.kmb.2.json --doc mtr=fixtures/commute-combo.mtr.json --params '{"show_ctb":false}' --now $NOW --out /tmp/yat-cc-noctb.png 2>/tmp/yat-cc-noctb.log
grep -q 'render warn' /tmp/yat-cc-noctb.log && { echo "FAIL: commute-combo (show_ctb=false) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-cc.png /tmp/yat-cc-noctb.png; then echo "FAIL: commute-combo show_ctb param did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-cc.png goldens/commute-combo.png)
if [ -f goldens/commute-combo.png ]; then
  cmp -s /tmp/yat-cc.png goldens/commute-combo.png || { echo "FAIL: golden mismatch (goldens/commute-combo.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/commute-combo.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- tides: HKO's high/low-tide feed, a fixed-width row of up to 4
# ---- time/height pairs (`data[0][2..9]`). The fixture's 4th slot is blank
# ---- ("","") — the real endpoint often returns only 3 tides a day — so this
# ---- also proves the `when: data.tide4_time` guard skips a genuinely absent
# ---- row instead of drawing an empty one. The next-tide arrow compares each
# ---- tide's time against `now|date_fmt('HHmm')`, and NOW (17:00 HKT) sits
# ---- between tide2 (14:55) and tide3 (21:46), so the fixture also exercises
# ---- that the marker lands on tide3, not tide1.
TIDES=official/tides.yat-pack.json

"$PREVIEW" "$TIDES" --doc hlt=fixtures/tides.hlt.json --now $NOW --out /tmp/yat-tides.png 2>/tmp/yat-tides.log
grep -q '"tide3_time": "2146"' /tmp/yat-tides.log || { echo "FAIL: tides: tide3 extraction"; exit 1; }
grep -q '"tide4_time": ""' /tmp/yat-tides.log || { echo "FAIL: tides: tide4 (absent) extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-tides.log && { echo "FAIL: tides render produced a warning"; exit 1; }

"$PREVIEW" "$TIDES" --doc hlt=fixtures/tides.hlt.json --now $NOW --out /tmp/yat-tides-b.png 2>/dev/null
cmp -s /tmp/yat-tides.png /tmp/yat-tides-b.png || { echo "FAIL: nondeterministic render (tides)"; exit 1; }

# lang=en must hide the zh-Hant date line and the bilingual header text
"$PREVIEW" "$TIDES" --doc hlt=fixtures/tides.hlt.json --params '{"lang":"en"}' --now $NOW --out /tmp/yat-tides-en.png 2>/tmp/yat-tides-en.log
grep -q 'render warn' /tmp/yat-tides-en.log && { echo "FAIL: tides (lang=en) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-tides.png /tmp/yat-tides-en.png; then echo "FAIL: tides lang param did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-tides.png goldens/tides.png)
if [ -f goldens/tides.png ]; then
  cmp -s /tmp/yat-tides.png goldens/tides.png || { echo "FAIL: golden mismatch (goldens/tides.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/tides.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- stock-ticker: a for_each source (one Finnhub /quote fetch per
# ---- configured symbol) collected into data.quotes. No real device had ever
# ---- rendered this pack until this fixture existed — Finnhub's quote shape
# ---- ({c,d,dp,h,l,o,pc,t}) is realistic here for the 4 default symbols
# ---- (AAPL/NVDA up, MSFT/TSLA down), so the default render exercises both
# ---- the up and down colour branches at once.
ST=official/stock-ticker.yat-pack.json
STDOC="--doc quotes=fixtures/stock-ticker.quotes.1.json,fixtures/stock-ticker.quotes.2.json,fixtures/stock-ticker.quotes.3.json,fixtures/stock-ticker.quotes.4.json"

"$PREVIEW" "$ST" $STDOC --now $NOW --out /tmp/yat-stock.png 2>/tmp/yat-stock.log
grep -q '"price": 227.16' /tmp/yat-stock.log || { echo "FAIL: stock-ticker: AAPL price extraction"; exit 1; }
grep -q '"chg": -5.54' /tmp/yat-stock.log || { echo "FAIL: stock-ticker: MSFT chg extraction"; exit 1; }
grep -q '"pct": -1.33' /tmp/yat-stock.log || { echo "FAIL: stock-ticker: MSFT pct extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-stock.log && { echo "FAIL: stock-ticker render produced a warning"; exit 1; }

"$PREVIEW" "$ST" $STDOC --now $NOW --out /tmp/yat-stock-b.png 2>/dev/null
cmp -s /tmp/yat-stock.png /tmp/yat-stock-b.png || { echo "FAIL: nondeterministic render (stock-ticker)"; exit 1; }

# up_color/down_color together flip the whole panel to the HK red-up
# convention — both params override together since `implies` (§3, PACK-SPEC)
# is a gallery-form-only convenience, not engine-enforced.
"$PREVIEW" "$ST" $STDOC --params '{"up_color":"red","down_color":"green"}' --now $NOW --out /tmp/yat-stock-hk.png 2>/tmp/yat-stock-hk.log
grep -q 'render warn' /tmp/yat-stock-hk.log && { echo "FAIL: stock-ticker (HK colours) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-stock.png /tmp/yat-stock-hk.png; then echo "FAIL: stock-ticker up_color/down_color params did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-stock.png goldens/stock-ticker.png)
if [ -f goldens/stock-ticker.png ]; then
  cmp -s /tmp/yat-stock.png goldens/stock-ticker.png || { echo "FAIL: golden mismatch (goldens/stock-ticker.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/stock-ticker.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- countdown: inline-only pack (no `data.sources`) — a pure function of
# ---- --now and params, so no fixture is needed. days_1/days_2 (§8.5
# ---- date_diff_days) and date_line_1/2 are `compute` fields over the params,
# ---- so they show up in the extraction dump like any source field. Default:
# ---- one countdown running (show_second off) plus the daily quote
# ---- (pick_by_day over the params array).
CD=official/countdown.yat-pack.json

"$PREVIEW" "$CD" --now $NOW --out /tmp/yat-cd.png 2>/tmp/yat-cd.log
grep -q '"days_1": 254' /tmp/yat-cd.log || { echo "FAIL: countdown: days_1 (date_diff_days) extraction"; exit 1; }
grep -q '"date_line_1": "7/4/2027 · Wed"' /tmp/yat-cd.log || { echo "FAIL: countdown: date_line_1 compute field"; exit 1; }
grep -q 'render warn' /tmp/yat-cd.log && { echo "FAIL: countdown render produced a warning"; exit 1; }

"$PREVIEW" "$CD" --now $NOW --out /tmp/yat-cd-b.png 2>/dev/null
cmp -s /tmp/yat-cd.png /tmp/yat-cd-b.png || { echo "FAIL: nondeterministic render (countdown)"; exit 1; }

# params variance: a different label/target date recomputes days_1 and must
# change the render — everything here is params-driven, no fixture involved.
"$PREVIEW" "$CD" --params '{"label_1":"Trip to Japan","date_1":"2026-12-25"}' --now $NOW --out /tmp/yat-cd2.png 2>/tmp/yat-cd2.log
grep -q '"days_1": 151' /tmp/yat-cd2.log || { echo "FAIL: countdown: params-driven date_1 recompute"; exit 1; }
grep -q 'render warn' /tmp/yat-cd2.log && { echo "FAIL: countdown (params variant) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-cd.png /tmp/yat-cd2.png; then echo "FAIL: countdown label_1/date_1 params did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-cd.png goldens/countdown.png)
if [ -f goldens/countdown.png ]; then
  cmp -s /tmp/yat-cd.png goldens/countdown.png || { echo "FAIL: golden mismatch (goldens/countdown.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/countdown.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- fx-hkd: single https source (open.er-api.com), rate_hkd via the
# ---- `round(5)` filter (stored back as its formatted string, so the dump
# ---- prints the fixed-precision value rather than the raw float) and an
# ---- `updated` epoch rendered through date_fmt/time_hhmm. NOW is pinned
# ---- like every other test here, but this pack's own text also carries a
# ---- rendered clock, so a determinism check matters just as much as usual.
FX=official/fx-hkd.yat-pack.json

"$PREVIEW" "$FX" --doc rate=fixtures/fx-hkd.rate.json --now $NOW --out /tmp/yat-fx.png 2>/tmp/yat-fx.log
grep -q '"rate_hkd": 0.04923' /tmp/yat-fx.log || { echo "FAIL: fx-hkd: rate_hkd extraction"; exit 1; }
grep -q '"updated": 1785110551' /tmp/yat-fx.log || { echo "FAIL: fx-hkd: updated timestamp extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-fx.log && { echo "FAIL: fx-hkd render produced a warning"; exit 1; }

"$PREVIEW" "$FX" --doc rate=fixtures/fx-hkd.rate.json --now $NOW --out /tmp/yat-fx-b.png 2>/dev/null
cmp -s /tmp/yat-fx.png /tmp/yat-fx-b.png || { echo "FAIL: nondeterministic render (fx-hkd)"; exit 1; }

# lang param changes the render (bilingual strings + lang-gated widgets)
"$PREVIEW" "$FX" --doc rate=fixtures/fx-hkd.rate.json --params '{"lang":"en"}' --now $NOW --out /tmp/yat-fx-en.png 2>/tmp/yat-fx-en.log
grep -q 'render warn' /tmp/yat-fx-en.log && { echo "FAIL: fx-hkd (lang=en) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-fx.png /tmp/yat-fx-en.png; then echo "FAIL: fx-hkd lang param did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-fx.png goldens/fx-hkd.png)
if [ -f goldens/fx-hkd.png ]; then
  cmp -s /tmp/yat-fx.png goldens/fx-hkd.png || { echo "FAIL: golden mismatch (goldens/fx-hkd.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/fx-hkd.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- gmb-minibus: three chained https sources exercising real-world §5.7
# ---- sequential source references — `stops` and `eta`'s URLs both
# ---- substitute {{sources.route.route_id}}, resolved from `route`'s own
# ---- extraction. The three fixtures are consistent with each other (route
# ---- 1's route_id 2006408 feeds both downstream URLs), so the fetch log
# ---- lines themselves prove the chain resolved, not just the final render.
GMBDOC="--doc route=fixtures/gmb-minibus.route.json --doc stops=fixtures/gmb-minibus.stops.json --doc eta=fixtures/gmb-minibus.eta.json"
GMB=official/gmb-minibus.yat-pack.json

"$PREVIEW" "$GMB" $GMBDOC --now $NOW --out /tmp/yat-gmb.png 2>/tmp/yat-gmb.log
grep -q 'fetch stops <- https://data.etagmb.gov.hk/route-stop/2006408/1' /tmp/yat-gmb.log || { echo "FAIL: gmb-minibus: §5.7 route_id not substituted into the stops URL"; exit 1; }
grep -q 'fetch eta <- https://data.etagmb.gov.hk/eta/route-stop/2006408/1/3' /tmp/yat-gmb.log || { echo "FAIL: gmb-minibus: §5.7 route_id not substituted into the eta URL"; exit 1; }
grep -q '"stop_tc": "雪廠街, 近印刷行"' /tmp/yat-gmb.log || { echo "FAIL: gmb-minibus: stop_tc extraction (stop_seq filter)"; exit 1; }
grep -q '"term_en": "Hong Kong Station Minibus Terminus"' /tmp/yat-gmb.log || { echo "FAIL: gmb-minibus: term_en extraction (last stop)"; exit 1; }
grep -q '"next_diff": 1' /tmp/yat-gmb.log || { echo "FAIL: gmb-minibus: next_diff extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-gmb.log && { echo "FAIL: gmb-minibus render produced a warning"; exit 1; }

"$PREVIEW" "$GMB" $GMBDOC --now $NOW --out /tmp/yat-gmb-b.png 2>/dev/null
cmp -s /tmp/yat-gmb.png /tmp/yat-gmb-b.png || { echo "FAIL: nondeterministic render (gmb-minibus)"; exit 1; }

# a different stop_seq retargets the JMESPath filter over the same stops
# fixture (proves the filter, not just that a label changed)
"$PREVIEW" "$GMB" $GMBDOC --params '{"stop_seq":1}' --now $NOW --out /tmp/yat-gmb-stop1.png 2>/tmp/yat-gmb-stop1.log
grep -q '"stop_tc": "山頂廣場（下層巴士總站）"' /tmp/yat-gmb-stop1.log || { echo "FAIL: gmb-minibus: stop_seq param did not retarget the extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-gmb-stop1.log && { echo "FAIL: gmb-minibus (stop_seq=1) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-gmb.png /tmp/yat-gmb-stop1.png; then echo "FAIL: gmb-minibus stop_seq param did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-gmb.png goldens/gmb-minibus.png)
if [ -f goldens/gmb-minibus.png ]; then
  cmp -s /tmp/yat-gmb.png goldens/gmb-minibus.png || { echo "FAIL: golden mismatch (goldens/gmb-minibus.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/gmb-minibus.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- hacker-news-highlights: HN Algolia search, hitsPerPage/numericFilters
# ---- driven straight by story_count/min_points, extracting up to 5
# ---- title/points pairs positionally (hits[0..4]) plus story_count
# ---- (hits|length). The default fixture has 5 hits; the nondefault one
# ---- (story_count=3, min_points=200) has only 3, so titles/points 4 and 5
# ---- must extract null and their `when: exists` rows must vanish.
HN=official/hacker-news-highlights.yat-pack.json

"$PREVIEW" "$HN" --doc stories=fixtures/hacker-news-highlights.stories.json --now $NOW --out /tmp/yat-hn.png 2>/tmp/yat-hn.log
grep -q '"story_count": 5' /tmp/yat-hn.log || { echo "FAIL: hacker-news-highlights: story_count (hits|length) extraction"; exit 1; }
grep -q '"title1": "Kill The Cookie Banner"' /tmp/yat-hn.log || { echo "FAIL: hacker-news-highlights: title1 extraction"; exit 1; }
grep -q '"points1": 850' /tmp/yat-hn.log || { echo "FAIL: hacker-news-highlights: points1 extraction"; exit 1; }
grep -q '"title5": "Design is compromise"' /tmp/yat-hn.log || { echo "FAIL: hacker-news-highlights: title5 extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-hn.log && { echo "FAIL: hacker-news-highlights render produced a warning"; exit 1; }

"$PREVIEW" "$HN" --doc stories=fixtures/hacker-news-highlights.stories.json --now $NOW --out /tmp/yat-hn-b.png 2>/dev/null
cmp -s /tmp/yat-hn.png /tmp/yat-hn-b.png || { echo "FAIL: nondeterministic render (hacker-news-highlights)"; exit 1; }

# story_count/min_points drive both the fetch's query string and the extracted
# shape (a shorter hits array), so this fixture+params pair must both fetch
# the right URL and change the render (titles 4/5 null -> their rows vanish).
"$PREVIEW" "$HN" --doc stories=fixtures/hacker-news-highlights.stories-nondefault.json --params '{"story_count":3,"min_points":200}' --now $NOW --out /tmp/yat-hn2.png 2>/tmp/yat-hn2.log
grep -q 'fetch stories <- https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=3&numericFilters=points%3E%3D200' /tmp/yat-hn2.log || { echo "FAIL: hacker-news-highlights: story_count/min_points not substituted into the URL"; exit 1; }
grep -q '"story_count": 3' /tmp/yat-hn2.log || { echo "FAIL: hacker-news-highlights: nondefault story_count extraction"; exit 1; }
grep -q '"title4": null' /tmp/yat-hn2.log || { echo "FAIL: hacker-news-highlights: title4 should be null with only 3 hits"; exit 1; }
grep -q 'render warn' /tmp/yat-hn2.log && { echo "FAIL: hacker-news-highlights (nondefault) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-hn.png /tmp/yat-hn2.png; then echo "FAIL: hacker-news-highlights story_count/min_points params did not change the render"; exit 1; fi

# golden compare (regenerate with: cp /tmp/yat-hn.png goldens/hacker-news-highlights.png)
if [ -f goldens/hacker-news-highlights.png ]; then
  cmp -s /tmp/yat-hn.png goldens/hacker-news-highlights.png || { echo "FAIL: golden mismatch (goldens/hacker-news-highlights.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/hacker-news-highlights.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# ---- todo: the 待辦 household to-do pack. Fixture-free (data.sources is
# ---- empty — items live entirely in params, written by the portal form and
# ---- by firmware voice ops), so every case here is --params only. `item_count`
# ---- is a `compute` field (`{{params.items|count}}`) used to pick the
# ---- empty-state tutorial vs. the list, and to gate the overflow line.
# ----
# ---- Known engine gap (not a bug in this pack): the spec has no array
# ---- filter/count-by-predicate that reaches a `params` array of objects —
# ---- `count` (§8.12) is a plain array length, `has` (§6.5) only matches
# ---- scalar array elements, and `extract`'s one JMESPath-style filter
# ---- (§6.1) only runs against a fetched/inline *document*, which for an
# ---- `inline` source is fixed at pack-authoring time and cannot mirror a
# ---- runtime `params` value. So this pack cannot compute "N still open"
# ---- (excluding done items) or detect "all done" as a distinct state —
# ---- both would need a predicate over `item.done` across the array. The
# ---- count line therefore shows the honest total (open + done); the "all
# ---- done" celebratory line asked for in review could not be built and was
# ---- dropped rather than shipped with a count that quietly lies once
# ---- something gets checked off. Per-row open/done styling (icon + weight +
# ---- muted colour, §9.1a) IS exactly item-scoped, so that part is exact.
TODO=official/todo.yat-pack.json

# a) default install: items defaults to [], so this is the zero-items tutorial
#    state that teaches the voice grammar — the whole reason the empty state
#    doubles as onboarding instead of just being blank.
"$PREVIEW" "$TODO" --now $NOW --out /tmp/yat-todo-empty.png 2>/tmp/yat-todo-empty.log
grep -q '"item_count": 0' /tmp/yat-todo-empty.log || { echo "FAIL: todo: default install should have zero items"; exit 1; }
grep -q 'render warn' /tmp/yat-todo-empty.log && { echo "FAIL: todo (empty) render produced a warning"; exit 1; }

"$PREVIEW" "$TODO" --now $NOW --out /tmp/yat-todo-empty-b.png 2>/dev/null
cmp -s /tmp/yat-todo-empty.png /tmp/yat-todo-empty-b.png || { echo "FAIL: nondeterministic render (todo empty)"; exit 1; }

# golden compare (regenerate with: cp /tmp/yat-todo-empty.png goldens/todo.png)
if [ -f goldens/todo.png ]; then
  cmp -s /tmp/yat-todo-empty.png goldens/todo.png || { echo "FAIL: golden mismatch (goldens/todo.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/todo.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# b) mixed open/done: proves the per-row `item.done` branch (§9.1a: open =
#    bold black + arrow_right, done = muted + check) on a realistic bilingual
#    list, not just the empty state.
TODOMIXED='{"items":[{"text":"買牛奶","done":false},{"text":"倒垃圾","done":true},{"text":"Pick up dry cleaning","done":false},{"text":"交電費","done":true},{"text":"Book dentist appointment","done":false}]}'
"$PREVIEW" "$TODO" --params "$TODOMIXED" --now $NOW --out /tmp/yat-todo-mixed.png 2>/tmp/yat-todo-mixed.log
grep -q '"item_count": 5' /tmp/yat-todo-mixed.log || { echo "FAIL: todo: mixed item_count extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-todo-mixed.log && { echo "FAIL: todo (mixed) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-todo-empty.png /tmp/yat-todo-mixed.png; then echo "FAIL: todo mixed state rendered identically to the empty tutorial"; exit 1; fi

"$PREVIEW" "$TODO" --params "$TODOMIXED" --now $NOW --out /tmp/yat-todo-mixed-b.png 2>/dev/null
cmp -s /tmp/yat-todo-mixed.png /tmp/yat-todo-mixed-b.png || { echo "FAIL: nondeterministic render (todo mixed)"; exit 1; }

# golden compare (regenerate with: cp /tmp/yat-todo-mixed.png goldens/todo-mixed.png)
if [ -f goldens/todo-mixed.png ]; then
  cmp -s /tmp/yat-todo-mixed.png goldens/todo-mixed.png || { echo "FAIL: golden mismatch (goldens/todo-mixed.png)"; exit 1; }
elif [ -z "$YAT_GOLDEN_BOOTSTRAP" ]; then
  echo "FAIL: golden missing (goldens/todo-mixed.png) — set YAT_GOLDEN_BOOTSTRAP=1 to (re)generate"; exit 1;
fi

# c) all items done: no dedicated "all done" trigger exists (see the gap note
#    above), but the page must still read cleanly as "nothing left to do" —
#    every row muted+checked, distinct from both the tutorial and the mixed page.
TODOALLDONE='{"items":[{"text":"買牛奶","done":true},{"text":"倒垃圾","done":true},{"text":"交電費","done":true}]}'
"$PREVIEW" "$TODO" --params "$TODOALLDONE" --now $NOW --out /tmp/yat-todo-alldone.png 2>/tmp/yat-todo-alldone.log
grep -q '"item_count": 3' /tmp/yat-todo-alldone.log || { echo "FAIL: todo: all-done item_count extraction"; exit 1; }
grep -q 'render warn' /tmp/yat-todo-alldone.log && { echo "FAIL: todo (all-done) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-todo-mixed.png /tmp/yat-todo-alldone.png; then echo "FAIL: todo all-done state rendered identically to the mixed page"; exit 1; fi
if cmp -s /tmp/yat-todo-empty.png /tmp/yat-todo-alldone.png; then echo "FAIL: todo all-done state rendered identically to the empty tutorial"; exit 1; fi

# d) maxItems worst case: 20 items (the schema ceiling — §3.2/§12.1 cap array
#    params at maxItems <=20, tighter than the ~24 first asked for) each a
#    full 48-char string. The list is capped at max_rows=7 specifically so
#    this fits; the load-bearing assertion is the ABSENCE of a §11.4 "layout
#    overflow" warning at the true worst case, plus the overflow line
#    ("Showing the first 7 of 20") actually appearing instead of silently
#    dropping the other 13.
python3 -c "
import json
items = [{'text': ('第' + str(i) + '項' + '極' * 40)[:48], 'done': (i % 2 == 0)} for i in range(1, 21)]
json.dump({'items': items}, open('/tmp/yat-todo-maxitems.json', 'w'))
"
TODOMAX="$(cat /tmp/yat-todo-maxitems.json)"
"$PREVIEW" "$TODO" --params "$TODOMAX" --now $NOW --out /tmp/yat-todo-maxitems.png 2>/tmp/yat-todo-maxitems.log
grep -q '"item_count": 20' /tmp/yat-todo-maxitems.log || { echo "FAIL: todo: maxItems item_count extraction"; exit 1; }
grep -q 'layout overflow' /tmp/yat-todo-maxitems.log && { echo "FAIL: todo: maxItems worst case (20 items, 48 chars each) overflowed its box"; exit 1; }
grep -q 'render warn' /tmp/yat-todo-maxitems.log && { echo "FAIL: todo (maxItems) render produced an unexpected warning"; exit 1; }

"$PREVIEW" "$TODO" --params "$TODOMAX" --now $NOW --out /tmp/yat-todo-maxitems-b.png 2>/dev/null
cmp -s /tmp/yat-todo-maxitems.png /tmp/yat-todo-maxitems-b.png || { echo "FAIL: nondeterministic render (todo maxItems)"; exit 1; }

# the overflow line is pack-rendered text, not something the extraction dump
# logs — assert it landed on the panel by checking the content band actually
# darkened relative to a build with the line suppressed. Simpler and just as
# conclusive: re-render at max_rows-sized input (7 items, no overflow needed)
# and diff — a real behavioural difference, not a golden-pixel guess.
python3 -c "
import json
items = [{'text': ('第' + str(i) + '項' + '極' * 40)[:48], 'done': (i % 2 == 0)} for i in range(1, 8)]
json.dump({'items': items}, open('/tmp/yat-todo-7items.json', 'w'))
"
TODO7="$(cat /tmp/yat-todo-7items.json)"
"$PREVIEW" "$TODO" --params "$TODO7" --now $NOW --out /tmp/yat-todo-7items.png 2>/tmp/yat-todo-7items.log
grep -q 'render warn' /tmp/yat-todo-7items.log && { echo "FAIL: todo (7 items, no overflow) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-todo-maxitems.png /tmp/yat-todo-7items.png; then echo "FAIL: todo overflow line did not change the render vs. an exactly-fitting 7-item list"; exit 1; fi

# e) lang param: English-only must drop the zh-Hant tutorial/count text
"$PREVIEW" "$TODO" --params '{"lang":"en"}' --now $NOW --out /tmp/yat-todo-en.png 2>/tmp/yat-todo-en.log
grep -q 'render warn' /tmp/yat-todo-en.log && { echo "FAIL: todo (lang=en) render produced a warning"; exit 1; }
if cmp -s /tmp/yat-todo-empty.png /tmp/yat-todo-en.png; then echo "FAIL: todo lang param did not change the render"; exit 1; fi

# f) mono profile (e1001): this pack uses no ink but muted/info/black (all
#    role-spelled, §9.1a), specifically to survive a panel with no red —
#    verified once here, no golden pinned per the pack-developer skill's
#    guidance that a role-only pack needs no separate mono golden absent a
#    visible problem.
"$PREVIEW" "$TODO" --profile e1001 --params "$TODOMIXED" --now $NOW --out /tmp/yat-todo-mixed-e1001.png 2>/tmp/yat-todo-mixed-e1001.log
grep -q 'render warn' /tmp/yat-todo-mixed-e1001.log && { echo "FAIL: todo (mixed, e1001) render produced a warning"; exit 1; }

echo "ALL TESTS PASS"
