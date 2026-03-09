# Dictionary Downloader & Settings Rewrite Plan

## Goal
Replace the legacy dictionary download/install/version flow and settings screen with a new architecture built for reliability, clear state, and easy maintenance. This migration is greenfield: no legacy compatibility layer.

## Scope
- New downloader domain models and lifecycle states
- New manifest/version/update pipeline
- New download + install pipeline with safe file operations
- New settings architecture and UI composition
- Full cutover to new code paths
- Delete old downloader/settings logic after migration completes

## Non-goals
- Preserving legacy APIs
- Backward-compat shims around old `DictionaryManager`
- Incremental patching of old queue/progress logic

## Phase Plan

### Phase 0 — Plan and boundaries
- Freeze old downloader features (bugfix-only)
- Define new module/folder boundaries
- Define migration checkpoints and acceptance criteria

### Phase 1 — Domain foundation
- Add core types:
  - `DictionaryID`
  - `DictionaryArtifactType`
  - `DictionaryManifestItem`
  - `DictionaryInstallRecord`
  - `DictionaryJobState`
  - `DictionaryJobProgress`
- Add file/path abstraction for install locations
- Add typed errors for manifest/download/install

### Phase 2 — Service contracts
- Define protocols for:
  - `DictionaryManifestService`
  - `DictionaryDownloadService`
  - `DictionaryInstallService`
  - `DictionaryCatalogStore`
  - `DictionarySettingsStore`
- Define async state/event stream for jobs

### Phase 3 — Manifest and catalog store implementations
- Implement remote manifest fetch + parse + validate
- Implement local catalog persistence (installed versions, source URL, status)
- Implement update eligibility logic (`minAppVersion`, `minBuild`)

### Phase 4 — Download + install pipeline
- Implement queue actor with cancellable jobs
- Download to temp file, verify payload, atomic move into final location
- Zip extraction in temp directory then promote/swap
- Emit deterministic state transitions and progress

### Phase 5 — Dictionary preparation hooks
- Run post-install preparation (e.g. search index/bootstrap) as explicit install step
- Ensure idempotent setup with safe retries

### Phase 6 — Settings rewrite
- Introduce `SettingsViewModel` for typed state and actions
- Split `Settings` into reusable sections/components
- Bind UI to downloader job state (install/cancel/retry/remove)
- Move input validation and defaults access into dedicated services

### Phase 7 — App startup cutover
- Replace old startup download trigger with new coordinator
- Keep startup UX behavior, but source data from new pipeline

### Phase 8 — Cleanup and deletion
- Remove old downloader/settings implementations and dead helpers
- Remove obsolete globals and legacy path/version helpers
- Final pass for references, build warnings, and docs update

## Acceptance Criteria
- Download/install state is deterministic and typed
- Failed installs never leave partially-installed dictionaries as installed
- Settings UI reflects per-dictionary live status and supports retry/cancel/remove
- Startup path uses only new downloader pipeline
- No runtime references to legacy downloader/settings code remain

## Execution Order (Initial)
1. Complete Phase 1 foundation types
2. Complete Phase 2 service interfaces
3. Build Phase 3 and 4 core pipeline
4. Rewrite Settings (Phase 6) against new interfaces
5. Startup cutover and legacy deletion
