# Dictionary Metadata & Manifest Spec

This document defines a metadata-first dictionary loading model for CJE Dictionary.

## Short answer

Yes — metadata should include all required file names (or file globs) needed to construct each dictionary backend.

Without explicit file mapping, runtime must guess from extensions and folder names, which causes:
- non-deterministic loading,
- name collisions,
- difficult debugging,
- fragile upgrades.

---

## Goals

- Deterministic discovery and loading (no guessing).
- Stable dictionary identity across installs and renames.
- Backward-compatible schema evolution.
- Easy validation during install.

---

## Two-layer model

Use two related but distinct metadata layers:

1. **Remote manifest (`manifest.json`)**
   - Tells the app what can be downloaded.
   - Versioning, compatibility, URL, integrity.

2. **Local dictionary metadata (`dictionary.json`)**
   - Lives inside each installed dictionary folder.
   - Tells runtime exactly how to load that dictionary from local files.

This separation keeps download concerns and runtime loading concerns cleanly isolated.

---

## 1) Remote manifest schema (recommended)

Current fields are good baseline. Add integrity and schema fields.

```json
{
  "schemaVersion": 1,
  "items": [
    {
      "id": "jitendex-optimized",
      "displayName": "jitendex",
      "downloadURL": "https://.../jitendex-optimized.zip",
      "artifactType": "zip",
      "version": 3,
      "minAppVersion": "2.0.0",
      "minBuildNumber": 1,
      "sha256": "<hex>",
      "sizeBytes": 12345678
    }
  ]
}
```

### Required fields
- `id` (stable, immutable, globally unique)
- `displayName`
- `downloadURL`
- `artifactType`
- `version`
- `minAppVersion`
- `minBuildNumber`

### Strongly recommended
- `schemaVersion`
- `sha256`
- `sizeBytes`

---

## 2) Local dictionary metadata schema (`dictionary.json`)

This is the runtime contract. It should include required file names.

```json
{
  "schemaVersion": 1,
  "id": "jitendex-optimized",
  "displayName": "jitendex",
  "backend": "mdictOptimized",
  "parser": "scriptJS",
  "searchLanguage": "JP",
  "resultsLanguage": "EN",
  "files": {
    "fst": "jitendex.fst",
    "readings": "jitendex.rd",
    "record": "jitendex.def",
    "script": "Script.js"
  }
}
```

### Required fields
- `schemaVersion`
- `id`
- `displayName`
- `backend`
- `searchLanguage`
- `resultsLanguage`
- `files` (backend-specific required keys)

### Backend-specific file requirements

#### `mdictOptimized`
Required `files` keys:
- `fst`
- `readings`
- `record`
Optional:
- `script` (required when parser is `scriptJS`)

#### `realmMongo`
Required `files` keys:
- `realm`
Optional:
- `script`

#### `kanjiSqlite`
Required `files` keys:
- `db` (or `sqlite` alias)

---

## Deterministic loader algorithm

1. Scan install root for `dictionary.json`.
2. Decode metadata.
3. Validate required fields and required `files` keys by backend.
4. Resolve each listed path relative to metadata directory.
5. Fail fast if any required file is missing.
6. Instantiate dictionary by explicit backend.
7. Register dictionary by stable `id`, display by `displayName`.

No filename/extension inference should be used when metadata exists.

---

## Identity model

Prefer this in runtime maps and result routing:
- **Primary key:** `id`
- **UI label:** `displayName`

Do not use `displayName` as storage key.

---

## Validation checklist during install

- Metadata file exists (`dictionary.json`).
- `schemaVersion` supported.
- `id` non-empty and unique.
- backend is known.
- required `files` entries exist and are readable.
- optional `sha256` matches downloaded artifact.

If validation fails, installation should fail with a clear error message.

---

## Migration strategy

1. Add metadata-first loader (already done).
2. Keep legacy fallback only temporarily (if needed) behind a flag.
3. Emit telemetry/log when fallback is used.
4. Remove fallback once all packages include metadata.

---

## Current package examples

### `jitendex-optimized.zip`
- backend: `mdictOptimized`
- files: `jitendex.fst`, `jitendex.rd`, `jitendex.def`, `Script.js`

### `jp-cn.realm.zip`
- backend: `realmMongo`
- files: `jp-cn.realm` (and optional `Script.js`)

### `KANJIDIC2_cleaned.db` package
- backend: `kanjiSqlite`
- files: `KANJIDIC2_cleaned.db`

---

## Recommended next implementation step

Add `schemaVersion` and `sha256` support in Swift manifest decode + install validation, then route dictionaries internally by metadata `id` instead of display name.
