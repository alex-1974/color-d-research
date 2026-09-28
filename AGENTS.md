# Repository Engineering Context

This repository is part of the d-geospatial workspace and is the research/evidence
companion to `alex-1974/color-d`.

Before changing research structure, validation methodology, compiler/toolchain
evidence, numerical experiments, performance evidence, CI, or repository
structure, read the relevant canonical workspace documents under `.workspace/`
when available.

Canonical workspace documents include:

- `.workspace/README.md`
- `.workspace/ROADMAP.md`
- `.workspace/DESIGN_PRINCIPLES.md`
- `.workspace/DLANG_PRACTICES.md`
- `.workspace/RESEARCH.md`
- `.workspace/QUALITY_GATES.md`
- `.workspace/GIT_GITHUB_WORKFLOW.md`
- `.workspace/REPOSITORY_STANDARD.md`
- `.workspace/TOOLCHAIN_ISSUES.md`

Treat those documents as the current shared engineering contract.

This repository preserves detailed research, experiments, rejected approaches,
raw validation evidence, compiler probes, and historical design material.
Production API contracts belong in `color-d` source/Ddoc, production tests,
accepted ADRs, user documentation, and active maintainer/release documents.

Do not silently move production responsibilities into this research repository.
When research is promoted into production, preserve provenance and keep the
production contract concise and independently understandable.

When `.workspace/` is unavailable, do not invent workspace policy. Follow the
tracked repository documentation and note that workspace context was
unavailable.
