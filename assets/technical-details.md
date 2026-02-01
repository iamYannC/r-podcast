# Deep dive into project structure
I dont believe anyone will ever read this, but incase you do, just write me at [yannco5@gmail.com](mailto:yannco5@gmail.com) or ask your favorite llm to clear things out...

## 📂 Project Structure

```
├─ build_all.R
├─ build-scripts/
│  ├─ shared.R
│  ├─ build_meta.R
│  ├─ build_chapters.R
│  ├─ build_transcripts.r
│  └─ build_descriptions.R
├─ cicd/
│  ├─ fetch-new-episode.R
│  ├─ cleanup_exports.R
│  ├─ cleanup_snapshots.R
│  └─ logs.txt
└─ outputs/
   ├─ meta.rds
   ├─ transcripts.rds
   ├─ chapters.rds
   ├─ descriptions.rds
   ├─ exports/
   │  ├─ snapshot_YYYY-MM-DD.xlsx
   │  ├─ snapshot_YYYY-MM-DD.sqlite
   │  └─ snapshot_YYYY-MM-DD_HHMMSS.{xlsx,sqlite}
   └─ snapshots/
      ├─ snapshot_latest.rds
      └─ snapshot_YYYY-MM-DD[_HHMMSS].rds
```
### Directory Details

**`build-scripts/`** - Core build functions and shared utilities
- `shared.R` - Common configuration, caching, HTTP helpers
- `build_meta.R` - Extract episode metadata from listings and payloads
- `build_chapters.R` - Extract chapter markers with timestamps
- `build_transcripts.r` - Fetch full episode transcripts
- `build_descriptions.R` - Parse descriptions and extract links

**`build_all.R`** - Main orchestrator
- Sources all build scripts
- Optionally uses existing `.rds` files
- Builds combined snapshot: `list(meta, transcripts, chapters, descriptions)`
- Overwrites section RDS files in `outputs/`
- Writes dated snapshot to `outputs/snapshots/`

**`outputs/`** - Canonical artifacts directory
- Section tables (`.rds`) are always overwritten for simplicity
- `snapshots/` holds dated, immutable snapshots
- `exports/` holds dated SQLite + XLSX exports generated from the latest snapshot

**`cicd/`** - Automation scripts
- `fetch-new-episode.R` - Incremental update logic (runs via GitHub Actions)
- `cleanup_exports.R` - Keeps only the latest dated XLSX + SQLite exports
- `cleanup_snapshots.R` - Keeps only 3 most recent snapshots
- `logs.txt` - Rolling log file (format: `[task-name YYYY-MM-DD] message`)

---

## ⚙️ What Exists / How It Works

### Build Pipeline

**`build_meta(pages = ...)`**
- Fetches listing pages (default: all pages)
- Returns tibble with episode metadata

**Section builders** (`build_chapters`, `build_transcripts`, `build_descriptions`)
- Accept `episode_index` parameter to build specific episode subsets
- Link to metadata via `episode_slug`

**`build_all.R`**
1. Sources all build scripts.

2. Controls whether to rebuild from source or reuse existing binaries via `use_existing` `(default: FALSE)`. Set to `TRUE` to build (scrape) from scratch.

3. Builds: `list(meta, transcripts, chapters, descriptions)`
4. Overwrites section RDS files in `outputs/`
5. Writes snapshot to `outputs/snapshots/`

**Snapshot filenames**
- `snapshot_latest.rds` is the stable pointer to the newest snapshot
- Archived snapshots use `snapshot_YYYY-MM-DD.rds`
  - If same-date snapshot exists: `snapshot_YYYY-MM-DD_HHMMSS.rds`

### CI/CD Automation

**`fetch-new-episode.R`** (runs weekly via GitHub Actions)
1. Fetches page 1 metadata (10 most recent episodes)
2. Compares against existing top 10 slugs
3. If new episodes found:
   - Builds data for new episodes only
   - Prepends to existing tables
   - Overwrites `*.rds` files
   - Writes new snapshot
4. Logs all outcomes to `logs.txt`: `[task-name YYYY-MM-DD] message`

**`cleanup_snapshots.R`** (runs after fetch workflow completes)
1. Keeps 3 most recent snapshots (by `file.info(mtime)`)
2. Deletes older snapshots
3. Logs actions to `logs.txt`

**`cleanup_exports.R`** (runs after fetch workflow completes)
1. Keeps only the latest dated XLSX and SQLite exports
2. Deletes older dated exports
3. Logs actions to `logs.txt`

**GitHub Actions Schedule**
- **Fetch New Episode**: Every Monday at 00:00 UTC (plus manual `workflow_dispatch`)
- **Snapshot cleanup**: Runs after fetch completes (plus manual `workflow_dispatch`)
- **Export cleanup**: Runs after fetch completes (plus manual `workflow_dispatch`)

**Workflow triggers**
- `fetch-new-episode.yaml`: `schedule` + `workflow_dispatch`
- `snapshot-cleanup.yaml`: `workflow_run` after Fetch New Episode succeeds + `workflow_dispatch`
- `export-cleanup.yaml`: `workflow_run` after Fetch New Episode succeeds + `workflow_dispatch`

**Export formats**
- Exports are generated from `snapshot_latest.rds` by `export_all.R`.
- Outputs are stored in `outputs/exports` as dated files:
  - `snapshot_YYYY-MM-DD.xlsx`
  - `snapshot_YYYY-MM-DD.sqlite`
  - If same-date exports already exist, a `HHMMSS` suffix is added.

---

## 📊 Data Schema

### `meta.rds`
```r
tibble(
  episode_slug,    # unique identifier
  episode_nr,      # episode number
  title,           # episode title
  publish_date,    # publication date
  duration,        # episode duration (hms)
  episode_url,     # episode page URL
  audio_url,       # direct audio URL
  podhome_uuid     # Podhome API ID
)
```

### `transcripts.rds`
```r
tibble(
  episode_slug,      # links to meta
  podhome_uuid,
  transcript_url,
  full_transcript    # complete episode text
)
```

### `chapters.rds`
```r
tibble(
  episode_slug,    # links to meta
  chapter_title,
  chapter_url,     # optional link
  chapter_ts       # timestamp (HH:MM:SS)
)
```

### `descriptions.rds` (list)
```r
list(
  descriptions = tibble(
    episode_slug,
    description_text
  ),
  description_links = tibble(
    episode_slug,
    section,         # "content "episode_links etc.
    text,            # link text
    link             # URL (if applicable)
  )
)
```

---
