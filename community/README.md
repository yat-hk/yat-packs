# Community packs

This directory is for third-party packs — anyone's `<id>.yat-pack.json`,
written against the same [Pack Spec](https://github.com/yat-hk/yat/blob/main/docs/PACK-SPEC.md)
the [`official/`](../official/) packs use.

It starts empty. A pack lands here through an ordinary pull request; see
[../CONTRIBUTING.md](../CONTRIBUTING.md) for the flow.

**Same bar, same CI.** Every pack in `community/` validates against the same
schema, renders through the same `tests/run-tests.sh`, and gets the same
safety-summary review (hosts contacted, secrets declared, refresh cadence) as
one in `official/`. The only difference between the two directories is
curation: `official/` is maintained by the YAT project itself; `community/`
is anyone's, reviewed on the same terms.

## Layout

A pack `<id>` here is `community/<id>.yat-pack.json`, plus whatever it needs
in the repo's shared directories:

- `../fixtures/<id>.<source-id>.json` (or `.xml` / `.csv` / `.png`) — one
  offline fixture per declared source, for deterministic preview/testing.
- `../goldens/<id>.png` — the pinned reference render `tests/run-tests.sh`
  compares against.

See [../README.md](../README.md) for how to preview and test a pack locally,
and `skills/pack-developer/SKILL.md` in a checkout of
[yat-hk/yat](https://github.com/yat-hk/yat) for how to write one.
