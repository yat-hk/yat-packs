# yat-packs — agent guide

This repo holds packs (declarative `.yat-pack.json` pages) for
[YAT](https://github.com/yat-hk/yat), an open, serverless e-ink display
platform for Hong Kong. It has no engine or firmware of its own.

## If you were asked to author, modify, or preview a pack

1. Clone [yat-hk/yat](https://github.com/yat-hk/yat) as a sibling directory
   (`../yat` relative to this repo) if it isn't already checked out.
2. Follow `skills/pack-developer/SKILL.md` in that checkout — it is the
   complete workflow: spec references, the validation command, fixture
   capture, preview commands, the current engine support matrix, and the
   non-negotiable design rules (six fixed inks spelled as roles, bilingual
   `zh-Hant`/`en` content, voice `aliases`). Read it in full before writing
   anything.
3. Put a new pack in `community/<id>.yat-pack.json` (only the YAT project
   adds to `official/` directly). Add its fixture(s) under `fixtures/` and,
   once you're happy with the render, its golden under `goldens/` — see
   [`community/README.md`](community/README.md) for the exact naming.
4. Validate and test **here**, against the sibling core checkout:
   ```
   npx --yes ajv-cli@5 validate --spec=draft2020 \
     -s ../yat/schema/yat-pack.schema.json -d community/<id>.yat-pack.json
   YAT_CORE=../yat ./tests/run-tests.sh
   ```
5. See [CONTRIBUTING.md](CONTRIBUTING.md) for the PR flow and what CI checks.

## Ground rules

- Packs are data, never code. If the spec can't express something, report
  the gap (core repo's `docs/SPEC-VALIDATION.md` has the vocabulary) — do
  not invent syntax.
- Never inline a credential. Declare it under `secrets` with an honest
  `sent_to` host allowlist instead.
- This repo makes no engine/spec decisions — those are RFC-gated in
  `yat-hk/yat`. A pack that needs new engine behavior belongs in a report to
  that repo, not a workaround here.
