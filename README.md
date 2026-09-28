# color-d-research

Research, experiments, validation evidence, and historical design work for
[color-d](https://github.com/alex-1974/color-d).

This repository is the research/evidence companion to the production
`color-d` library. It intentionally contains material that should not be
downloaded by normal DUB consumers of the production package.

## Relationship to color-d

The initial research snapshot is imported from:

- source repository: `alex-1974/color-d`
- source commit: `f5ff3dab97c65e6f45e4c0ed192c3143a946c6bc`
- selected source paths:
  - `experiments/**`
  - `docs/research/**`
  - `docs/spec/**`
  - `docs/RESEARCH_DOCUMENTS.md`

The source repository retains production source, tests, CI/release machinery,
user documentation, accepted compact ADRs, and active maintainer contracts.

No Git history rewrite is required for the split: historical color-d commits
remain available in the production repository, while this repository preserves
the detailed research corpus for future work and provenance.

## Status

Initial snapshot import is complete.

- exact snapshot commit: `5296ffb16d1a619b658c1296f9d8bd0d1d597c83`;
- selected files: 132;
- selected bytes: 1,577,331;
- Git path/mode/size/blob comparison: PASS.

See [PROVENANCE.md](PROVENANCE.md) for the pinned source and verification
record. Independent SHA-256 verification is enforced by repository CI.
