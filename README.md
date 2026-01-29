# R Weekly Highlights Podcast Database V2

<!-- Placeholder for icon/logo -->

This second release is Harder, Better, Faster, Stronger! <br>
An automated project aimed to provide an easy-to-use database with all the goodies from the folks at the [R Weekly Highlights](https://serve.podhome.fm/r-weekly-highlights) podcast. <br>
Full episodes breakthrough: **Description, Links and full transcripts** (where available) of each episode.

---
## 🚀 How to Use

### Quick Start: Just Read the Data

**1. Clone the repository**
```bash
git clone https://github.com/iamYannC/r-podcast.git
cd r-podcast
```

**2. Load and explore**
```r
# Load the most recent snapshot

# There might be more than one snapshot at a time, ensure you scrape the latest.

files <- list.files("outputs/snapshots", pattern = "^snapshot_.*\\.rds$", full.names = TRUE)
latest <- files[which.max(file.mtime(files))]
snapshot <- readRDS(latest)

# Access the data
meta <- snapshot$meta
transcripts <- snapshot$transcripts
chapters <- snapshot$chapters
descriptions <- snapshot$descriptions
```

**That's it!**

---

### Development Workflow (🤓 only)

Want to rebuild the database yourself? fine:

**Install R dependencies**
```r
install.packages(c(
  "tidyverse", "rvest", "xml2", "glue", 
  "hms", "httr2", "jsonlite"
))
```

**Option A: Rebuild from existing binaries** *(recommended - fast!)*
```r
source("build_all.R")
build_all()  # uses use_existing = TRUE by default
```

**Option B: Scrape everything from scratch**
```r
source("build_all.R")
build_all(use_existing = FALSE)
```

**Check for new episodes**
```r
source("cicd/update.R")
# Automatically fetches only new episodes and updates the database
```

---
---

## 🎉 Shout Out!

Imagine my surprise to see that someone forked my repo, and it wasnt even by accident!

<br>[Nils Indreiten](https://github.com/Jokasan/r-weekly_chatbot) built a cool AI chatbot based on (or inspired by) the previous version of this scraping project. Go check it out (but don't burn his api credits...)


<iframe src="imgs/chatbot.html" width="100%" height="60" style="border:none; overflow:hidden;" scrolling="no"></iframe>


---

## 📂 Project Structure

```
.
├─ build_all.R
├─ build-scripts/
│  ├─ shared.R
│  ├─ build_meta.R
│  ├─ build_chapters.R
│  ├─ build_transcripts.r
│  └─ build_descriptions.R
├─ cicd/
│  ├─ update.R
│  ├─ cleanup_snapshots.R
│  └─ log.txt
└─ outputs/
   ├─ meta.rds
   ├─ transcripts.rds
   ├─ chapters.rds
   ├─ descriptions.rds
   └─ snapshots/
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

**`cicd/`** - Automation scripts
- `update.R` - Incremental update logic (runs via GitHub Actions)
- `cleanup_snapshots.R` - Keeps only 3 most recent snapshots
- `log.txt` - Rolling log file (format: `[action YYYY-MM-DD] message`)

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
1. Sources all build scripts
2. Optionally uses existing `*.rds` files (`use_existing = TRUE`)
3. Builds: `list(meta, transcripts, chapters, descriptions)`
4. Overwrites section RDS files in `outputs/`
5. Writes snapshot to `outputs/snapshots/`

**Snapshot filenames**: `snapshot_YYYY-MM-DD.rds`
- If same-date snapshot exists: `snapshot_YYYY-MM-DD_HHMMSS.rds`

### CI/CD Automation

**`update.R`** (runs weekly via GitHub Actions)
1. Fetches page 1 metadata (~10 most recent episodes)
2. Compares against existing top 10 slugs
3. If new episodes found:
   - Builds data for new episodes only
   - Prepends to existing tables
   - Overwrites `*.rds` files
   - Writes new snapshot
4. Logs all outcomes to `log.txt`: `[action YYYY-MM-DD] message`

**`cleanup_snapshots.R`** (runs monthly)
1. Keeps 3 most recent snapshots (by `file.info(mtime)`)
2. Deletes older snapshots
3. Logs actions to `log.txt`

**GitHub Actions Schedule**
- **Update**: Every Monday at 00:00 UTC
- **Cleanup**: 1st of every month at 00:00 UTC

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
    section,         # "content", "episode_links", etc.
    text,            # link text or plain text
    link             # URL (if applicable)
  )
)
```

---

## ⚠️ Non-Affiliation

This project is **not affiliated with or endorsed by the R Weekly team**. The R Weekly Highlights podcast and the R Weekly organization bear no responsibility for the content, accuracy, or availability of this database.

This is an independent, community-driven effort to make podcast data more accessible and searchable.

### 🌟 Open Source Spirit

I encourage everyone to:
- **Use** this data for your own projects
- **Tweak** the scraper for other podcasts
- **Copy** the automation patterns
- **Build** something creative that sparks your curiosity

And if you find this useful, give it a star ⭐ — my mom will be proud!

---

## 💬 Let's Talk

**Email**: [yannco5@gmail.com](mailto:yannco5@gmail.com)

**LinkedIn**: [Yann Cohen-Tourman](https://www.linkedin.com/in/yann-cohen-tourman/)

**GitHub**: [@iamyannc](https://github.com/iamyannc)
