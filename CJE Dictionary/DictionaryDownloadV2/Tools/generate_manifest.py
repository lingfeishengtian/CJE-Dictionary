#!/usr/bin/env python3
"""Prepare local dictionary artifacts and generate manifest.json for hosting.

Usage examples:
    python generate_manifest.py
    python generate_manifest.py --extract
    python generate_manifest.py --extract --overwrite
    python generate_manifest.py --base-url https://example.com/dictionaries
    python generate_manifest.py --config manifest_sources.json --output ../../Dictionaries/manifest.json
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any
import zipfile


DEFAULT_BASE_URL = "https://raw.githubusercontent.com/lingfeishengtian/CJE-Dictionary/main/CJE%20Dictionary/Dictionaries"

DEFAULT_ARCHIVE_ENTRIES = {
    "jitendex-optimized.zip": {
        "id": "jitendex-optimized",
        "displayName": "jitendex",
        "description": "General JP/CN dictionary for word meanings and reading-based lookup.",
        "fileName": "jitendex-optimized.zip",
        "artifactType": "zip",
        "version": 1,
        "minAppVersion": "2.0.0",
        "minBuildNumber": 1,
    },
    "kanjidict2.zip": {
        "id": "kanjidict2",
        "displayName": "kanjidict2",
        "description": "Kanji-focused lookup with character details, readings, and component information.",
        "fileName": "kanjidict2.zip",
        "artifactType": "zip",
        "version": 1,
        "minAppVersion": "2.0.0",
        "minBuildNumber": 1,
    },
}

DEFAULT_LOCAL_METADATA = {
    "jitendex-optimized.zip": {
        "id": "jitendex-optimized",
        "displayName": "jitendex",
        "backend": "mdictOptimized",
        "parser": "scriptJS",
        "searchLanguage": "ja-JP",
        "resultsLanguage": "en-US",
        "files": {
            "fst": "jitendex.fst",
            "readings": "jitendex.rd",
            "record": "jitendex.def",
            "script": "Script.js",
        },
    },
    "jp-cn.zip": {
        "id": "jp-cn-realm",
        "displayName": "jp-cn",
        "backend": "realmMongo",
        "parser": "scriptJS",
        "searchLanguage": "ja-JP",
        "resultsLanguage": "zh-CN",
        "files": {
            "realm": "jp-cn.realm",
            "script": "Script.js",
        },
    },
    "kanjidict2.zip": {
        "id": "kanjidict2",
        "displayName": "kanjidict2",
        "backend": "kanjiSqlite",
        "parser": "structured",
        "searchLanguage": "ja-JP",
        "resultsLanguage": "en-US",
        "includeInCrossDictionaryLookup": False,
        "files": {
            "db": "KANJIDIC2_cleaned.db",
        },
    },
}

DEFAULT_EXTRACT_FOLDERS = {
    "jitendex-optimized.zip": "jitendex-optimized",
    "jp-cn.zip": "jp-cn",
    "kanjidict2.zip": "kanjidict2",
}


def _default_output_path() -> Path:
    # .../CJE Dictionary/DictionaryDownloadV2/Tools/generate_manifest.py
    # -> .../CJE Dictionary/Dictionaries/manifest.json
    return Path(__file__).resolve().parents[2] / "Dictionaries" / "manifest.json"


def _default_dictionaries_dir() -> Path:
    return Path(__file__).resolve().parents[2] / "Dictionaries"


def _normalize_base_url(base_url: str) -> str:
    return base_url.rstrip("/")


def _load_entries(config_path: Path | None, dictionaries_dir: Path) -> list[dict[str, Any]]:
    if config_path is None:
        entries: list[dict[str, Any]] = []
        for archive_name, entry in DEFAULT_ARCHIVE_ENTRIES.items():
            if _default_entry_exists(archive_name, dictionaries_dir):
                entries.append(entry)
        return entries

    raw = json.loads(config_path.read_text(encoding="utf-8"))
    if isinstance(raw, dict) and "items" in raw:
        raw = raw["items"]

    if not isinstance(raw, list):
        raise ValueError("Config must be a JSON array or an object with an 'items' array")

    return raw


def _default_entry_exists(archive_name: str, dictionaries_dir: Path) -> bool:
    return (dictionaries_dir / archive_name).exists()


def _extract_directory_name(archive_name: str) -> str:
    if archive_name in DEFAULT_EXTRACT_FOLDERS:
        return DEFAULT_EXTRACT_FOLDERS[archive_name]
    return archive_name[:-4] if archive_name.lower().endswith(".zip") else archive_name


def _extract_archives(dictionaries_dir: Path, overwrite: bool) -> list[Path]:
    extracted_paths: list[Path] = []

    for archive_name in DEFAULT_ARCHIVE_ENTRIES.keys():
        archive_path = dictionaries_dir / archive_name
        if not archive_path.exists() or not zipfile.is_zipfile(archive_path):
            continue

        target_dir = dictionaries_dir / _extract_directory_name(archive_name)
        if target_dir.exists() and not overwrite:
            extracted_paths.append(target_dir)
            continue

        target_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive_path, "r") as zip_file:
            zip_file.extractall(target_dir)
        extracted_paths.append(target_dir)

    return extracted_paths


def _write_local_dictionary_metadata(dictionaries_dir: Path, extracted_dirs: list[Path]) -> list[Path]:
    written: list[Path] = []
    extracted_by_name = {directory.name: directory for directory in extracted_dirs}

    for archive_name, payload in DEFAULT_LOCAL_METADATA.items():
        extracted_name = _extract_directory_name(archive_name)
        directory = extracted_by_name.get(extracted_name)
        if directory is None and (dictionaries_dir / extracted_name).exists():
            directory = dictionaries_dir / extracted_name

        if directory is None:
            source_artifact = dictionaries_dir / archive_name
            if source_artifact.exists() and source_artifact.suffix.lower() != ".zip":
                directory = dictionaries_dir / extracted_name
                directory.mkdir(parents=True, exist_ok=True)

        if directory is None:
            continue

        metadata_path = directory / "dictionary.json"
        metadata_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        written.append(metadata_path)

    return written


def _build_manifest(entries: list[dict[str, Any]], base_url: str) -> dict[str, Any]:
    normalized_base = _normalize_base_url(base_url)
    items: list[dict[str, Any]] = []

    required = {"id", "displayName", "fileName", "artifactType", "version", "minAppVersion", "minBuildNumber"}

    for entry in entries:
        missing = required - set(entry.keys())
        if missing:
            raise ValueError(f"Entry missing required fields: {sorted(missing)} in {entry}")

        file_name = str(entry["fileName"]).lstrip("/")
        item = {
            "id": str(entry["id"]),
            "displayName": str(entry["displayName"]),
            "description": str(entry.get("description", "")),
            "downloadURL": f"{normalized_base}/{file_name}",
            "artifactType": str(entry["artifactType"]),
            "version": int(entry["version"]),
            "minAppVersion": str(entry["minAppVersion"]),
            "minBuildNumber": int(entry["minBuildNumber"]),
        }
        items.append(item)

    return {"items": items}


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract local dictionary archives and generate manifest.json")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="Base URL where dictionary artifacts are hosted")
    parser.add_argument("--config", type=Path, default=None, help="Optional JSON config file (array or {\"items\": [...]})")
    parser.add_argument("--dictionaries-dir", type=Path, default=_default_dictionaries_dir(), help="Local Dictionaries folder path")
    parser.add_argument("--extract", action="store_true", help="Extract known dictionary zip archives before generating manifest")
    parser.add_argument("--overwrite", action="store_true", help="When extracting, overwrite into existing extracted directories")
    parser.add_argument("--output", type=Path, default=_default_output_path(), help="Output manifest path")
    args = parser.parse_args()

    extracted_dirs: list[Path] = []
    if args.extract:
        extracted_dirs = _extract_archives(args.dictionaries_dir, overwrite=args.overwrite)
        metadata_files = _write_local_dictionary_metadata(args.dictionaries_dir, extracted_dirs)
        print(f"Extracted {len(extracted_dirs)} archive directories in: {args.dictionaries_dir}")
        if metadata_files:
            print(f"Wrote {len(metadata_files)} local dictionary metadata files")

    entries = _load_entries(args.config, args.dictionaries_dir)
    payload = _build_manifest(entries, args.base_url)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Wrote manifest with {len(payload['items'])} items to: {args.output}")


if __name__ == "__main__":
    main()
