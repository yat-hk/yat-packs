# Contributing a pack

Thanks for building something for the panel. This is a short guide to the PR
flow; for how to actually *write* a pack, see
[`skills/pack-developer/SKILL.md`](https://github.com/yat-hk/yat/blob/main/skills/pack-developer/SKILL.md)
and [`docs/PACK-SPEC.md`](https://github.com/yat-hk/yat/blob/main/docs/PACK-SPEC.md)
in a checkout of the core repo, [yat-hk/yat](https://github.com/yat-hk/yat).

## Where your pack goes

New packs go in [`community/`](community/) as `<id>.yat-pack.json`, plus
whatever it needs in the shared `fixtures/` and `goldens/` directories (see
[`community/README.md`](community/README.md) for the exact layout). Only the
YAT project maintains [`official/`](official/) directly.

## Before you open a PR

1. **Validate** against the schema (from a sibling `yat` checkout):
   ```
   npx --yes ajv-cli@5 validate --spec=draft2020 \
     -s ../yat/schema/yat-pack.schema.json -d community/<id>.yat-pack.json
   ```
2. **Capture a fixture** for every declared source and **preview** the pack
   (`../yat/tools/preview/yat-preview`) until it's glanceable — one primary
   figure, few words, readable in the six fixed inks. Iterate on real API
   responses, not guesses.
3. **Run the suite** — `./tests/run-tests.sh` — and make sure it still ends
   in `ALL TESTS PASS` with your pack's fixture(s) added.
4. **Bilingual by default.** Traditional Chinese and English throughout,
   廣東話-first where the pack speaks for itself (labels, voice `aliases`)
   rather than translating out of English. Follow the pack-developer skill's
   design rules — six fixed inks spelled as roles (`accent`/`good`/`warn`/
   `danger`/`info`/`muted`), not raw colours, unless the colour *is* the
   meaning.
5. **Bump the version** (`version` field, semver) on any change to an
   existing pack — installs are pinned by version, and the gallery needs a
   change to notice one.

## What CI checks

Every PR runs, against the `yat-hk/yat` commit pinned in
[`.core-ref`](.core-ref):

- **Schema validation** — every pack in `official/` and `community/` against
  core's `schema/yat-pack.schema.json`.
- **Render tests** — `tests/run-tests.sh` renders each pack against its
  fixtures and diffs the PNG against its golden, byte for byte.
- **Safety summary** — a step-summary comment listing, for each pack your PR
  changes: every host its sources contact, every secret it declares (and the
  host allowlist it promises to send that secret to), and its refresh
  cadence. Nothing in a pack is ever executed to produce this — it's a static
  read of the JSON (`tools/safety_summary.py`) — but it's the thing a
  reviewer will actually look at, because a pack that reaches somewhere
  undisclosed or asks for more than it needs matters more than any pixel.

## What gets a pack rejected

- **Undisclosed hosts.** Every host a source fetches from, and every host a
  secret is sent to, must be visible in the pack itself (`data.sources[].url`
  and `secrets.*.sent_to`) — nothing reached through indirection the schema
  can't see.
- **Executable-anything.** A pack is data: URLs, JMESPath-ish extraction
  expressions, a widget tree. If yours needs to *run* something to work,
  it's not a pack — say what you actually need (see
  `docs/SPEC-VALIDATION.md` in the core repo for the gap vocabulary) rather
  than smuggling code in through a string field.
- **Scraping that violates a provider's terms.** Prefer a provider's own API
  or public feed over scraping HTML, and don't wire up a pack against a
  source whose terms forbid the way you're using it.
- **Content that doesn't belong on a household screen.** This panel sits on
  a shelf; keep it to that bar.

A pack that's honest about what it needs and fails one of these for a
correctable reason (e.g. an undeclared host) usually just needs the fix
resubmitted, not a fresh PR.
