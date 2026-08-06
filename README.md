# yat-packs

The pack library for [YAT 日](https://github.com/yat-hk/yat) — an open,
serverless e-ink display platform built for everyday life in Hong Kong. A
**pack** is one JSON file that turns a data source into a page on the panel;
this repo is where they live and where pack pull requests merge directly.

Engine, firmware, and spec live in the core repo,
[yat-hk/yat](https://github.com/yat-hk/yat). The website lives at
[yat.day](https://yat.day) and is a separate, private codebase. This repo
holds only packs and the fixtures/tests/CI that keep them honest.

## Layout

| Path | What |
|---|---|
| `official/` | Packs maintained by the YAT project itself |
| `community/` | Packs contributed by anyone — same schema, same tests, same review |
| `fixtures/` | Offline fixtures (one or more per pack) for deterministic preview/testing |
| `goldens/` | Pinned reference renders `tests/run-tests.sh` compares against |
| `tests/run-tests.sh` | Renders every pack against its fixtures and checks the result |
| `.core-ref` | The core repo commit this repo's CI validates and renders against |

## How a pack reaches a device

Devices never talk to GitHub directly. The [yat.day](https://yat.day) gallery
that a device's settings page pulls from is built from a **maintainer-pinned
commit** of this repo — so a merged pull request is not instantly live; it
ships the next time that pin moves. `.core-ref` here is the mirror image of
that: it pins the commit of `yat-hk/yat` this repo's CI validates and renders
packs against, so pack CI and firmware/spec/schema stay in lock-step even
though the two repos move independently.

## Trying a pack locally

Clone this repo next to a checkout of the core repo (the tests expect that
layout by default):

```
$ git clone https://github.com/yat-hk/yat
$ git clone https://github.com/yat-hk/yat-packs
$ cd yat-packs
```

Run the suite — it builds the native renderer in `../yat/tools/preview` the
first time, then renders every pack in `official/` (and `community/`, once it
has packs) against its fixtures and diffs the PNG against `goldens/`:

```
$ ./tests/run-tests.sh
...
ALL TESTS PASS
```

Point `YAT_CORE` elsewhere if your core checkout isn't a sibling directory:

```
$ YAT_CORE=/path/to/yat ./tests/run-tests.sh
```

To look at a single pack yourself, use the renderer directly (see a pack's
entry in `tests/run-tests.sh` for the exact fixture flags it needs, or run
`../yat/tools/preview/simulator.py` for an interactive browser UI):

```
$ ../yat/tools/preview/yat-preview official/hko-now.yat-pack.json \
    --doc current=fixtures/hko-now.current.json \
    --doc warnsum=fixtures/hko-now.warnsum.json \
    --out hko-now.png
```

## Writing a pack

Packs are written *by AI agents* by design — point a coding agent at a
checkout of `yat-hk/yat` and ask for the page you want; see that repo's
[`AGENTS.md`](https://github.com/yat-hk/yat/blob/main/AGENTS.md) and
[`skills/pack-developer/SKILL.md`](https://github.com/yat-hk/yat/blob/main/skills/pack-developer/SKILL.md).
Humans are just as welcome:
[`docs/PACK-SPEC.md`](https://github.com/yat-hk/yat/blob/main/docs/PACK-SPEC.md)
is the normative reference. Either way, land the result here — see
[CONTRIBUTING.md](CONTRIBUTING.md) for the PR flow, and
[AGENTS.md](AGENTS.md) if you're pointing an agent at this repo specifically.

Bilingual by default — Traditional Chinese and English throughout, 廣東話
first where the device speaks for itself rather than translating out of
English.

## License

[GPL-3.0](LICENSE), matching the core repo — free to use, study, and modify;
anything you distribute built on it must be open under the same terms.

The **YAT name and logo are not licensed** — code reuse under the GPL does
not grant the right to present a pack collection under this name. For
commercial licensing outside GPL terms, contact the yat-hk/yat maintainer.
