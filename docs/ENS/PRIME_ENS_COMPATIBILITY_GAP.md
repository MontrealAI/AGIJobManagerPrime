# Prime ↔ ENS compatibility gap

## Truthful compatibility summary

- **Prime manager mode today:** lean numeric-hook mode.
- **Prime automatic authority issuance:** supported.
- **Prime automatic spec/completion metadata hydration:** not fully supported without keeper/operator assistance because Prime does not expose V1 metadata getters onchain.
- **Typed push hooks (`onJobCreated`, etc.):** forward-compatible only; not used by current Prime.
- **Production-safe answer:** unchanged Prime + ENS-side compatibility mode + explicit repair tooling.

## What Prime already exposes without runtime growth

- `jobEmployerOf(jobId)`
- `jobAssignedAgentOf(jobId)`
- `getJobSelectionInfo(jobId)`
- `getJobSelectionRuntimeState(jobId)`
- `previewHistoricalScore(agent)`
- `setEnsJobPages(address)`
- `ensJobPages()`

These are enough to:
- establish authoritative ENS identity on create,
- authorise the employer automatically on create,
- authorise/revoke the assigned agent when available,
- keep settlement non-blocking,
- classify jobs into automatic vs repair-needed states.

## What unchanged Prime does *not* expose

- `ensJobManagerViewInterfaceVersion()`
- `getJobCore(jobId)`
- `getJobSpecURI(jobId)`
- `getJobCompletionURI(jobId)`

Because those views are absent, unchanged Prime cannot fully auto-write ENS text metadata from inside `handleHook(uint8,uint256)`.

## Patch decision

Use **Option B**:
- keep Prime unchanged,
- preserve `handleHook(uint8,uint256)` compatibility,
- automatically establish authoritative identity where lean-mode data is enough,
- require explicit ENS-side repair or log-driven recovery for spec/completion metadata and some legacy migrations.
