# Initial snapshot provenance

The initial `color-d-research` corpus is a preserved snapshot of detailed
research/evidence that previously lived in the production `color-d` repository.

## Source

- repository: `alex-1974/color-d`
- source branch: `develop`
- source commit: `f5ff3dab97c65e6f45e4c0ed192c3143a946c6bc`

Selected source paths:

```text
experiments/**
docs/research/**
docs/spec/**
docs/RESEARCH_DOCUMENTS.md
```

## Snapshot

- destination repository: `alex-1974/color-d-research`
- exact snapshot commit: `5296ffb16d1a619b658c1296f9d8bd0d1d597c83`
- selected files: **132**
- selected bytes: **1,577,331**

A complete Git-tree comparison between source and destination reported:

- identical relative paths;
- identical file modes;
- identical byte sizes;
- identical Git blob SHAs;
- zero mismatches.

An independent SHA-256 verification is executed by the repository workflow
`.github/workflows/verify-snapshot.yml` using the verifier tracked in the
pinned source commit.

## History model

This split intentionally does not rewrite `color-d` history.

Historical commits in the production repository remain available. New
production release tags will use the lean current tree after the verified
duplicate research paths are removed from `color-d`.
