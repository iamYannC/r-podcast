suppressPackageStartupMessages({ # i should probably use this for my other scripts as well... sorry todyverse
  library(tibble)
  library(DBI)
  library(RSQLite)
  library(writexl)
  library(hms)
})

MAX_XLSX_CHARS <- 32000

ensure_tibble <- function(x) {
  if (is.null(x)) return(tibble::tibble())
  if (inherits(x, "tbl_df")) return(x)
  if (is.data.frame(x)) return(tibble::as_tibble(x))
  stop("Expected a data.frame/tibble, got: ", paste(class(x), collapse = ", "))
}

utf8ize <- function(df) { # super robust to make sure excel and sqlite are cool
  if (!nrow(df)) return(df)
  chr_cols <- vapply(df, is.character, logical(1))
  if (!any(chr_cols)) return(df)
  df[chr_cols] <- lapply(df[chr_cols], function(col) {
    iconv(col, from = "", to = "UTF-8")
  })
  df
}

to_seconds <- function(x) {
  if (is.null(x)) return(numeric())
  if (inherits(x, "hms") || inherits(x, "difftime")) return(as.numeric(x))
  if (is.numeric(x)) return(as.numeric(x))
  if (is.character(x)) {
    parsed <- suppressWarnings(hms::as_hms(x))
    return(as.numeric(parsed))
  }
  rep(NA_real_, length(x))
}

to_hms_string <- function(seconds, fallback = NULL) {
  if (length(seconds) == 0) return(character())
  if (all(is.na(seconds))) {
    if (!is.null(fallback)) return(as.character(fallback))
    return(rep(NA_character_, length(seconds)))
  }
  as.character(hms::as_hms(seconds))
}

normalize_meta <- function(meta) {
  meta <- ensure_tibble(meta)
  if ("publish_date" %in% names(meta)) {
    if (inherits(meta$publish_date, c("Date", "POSIXct", "POSIXlt"))) {
      meta$publish_date <- format(meta$publish_date, "%Y-%m-%d")
    } else if (is.character(meta$publish_date)) {
      parsed <- suppressWarnings(as.Date(meta$publish_date))
      meta$publish_date <- ifelse(!is.na(parsed), format(parsed, "%Y-%m-%d"), meta$publish_date)
    } else {
      meta$publish_date <- as.character(meta$publish_date)
    }
  }

  if ("duration" %in% names(meta)) {
    secs <- to_seconds(meta$duration)
    meta$duration_seconds <- secs
    meta$duration_hms <- to_hms_string(secs, fallback = meta$duration)
  }

  utf8ize(meta)
}

normalize_transcripts <- function(transcripts) {
  transcripts <- ensure_tibble(transcripts)
  if ("full_transcript" %in% names(transcripts)) {
    transcripts$transcript_length <- nchar(transcripts$full_transcript, type = "chars", allowNA = TRUE)
    transcripts$transcript_truncated <- transcripts$transcript_length > MAX_XLSX_CHARS
  } else {
    transcripts$transcript_length <- NA_integer_
    transcripts$transcript_truncated <- NA
  }
  utf8ize(transcripts)
}

normalize_chapters <- function(chapters) {
  chapters <- ensure_tibble(chapters)
  if ("chapter_ts" %in% names(chapters)) {
    secs <- to_seconds(chapters$chapter_ts)
    chapters$chapter_ts_seconds <- secs
    chapters$chapter_ts_hms <- to_hms_string(secs, fallback = chapters$chapter_ts)
  }
  utf8ize(chapters)
}

normalize_descriptions <- function(descriptions) {
  if (is.null(descriptions)) {
    desc_tbl <- tibble::tibble()
    links_tbl <- tibble::tibble()
  } else if (is.list(descriptions) && !is.data.frame(descriptions)) {
    desc_tbl <- ensure_tibble(descriptions$descriptions)
    links_tbl <- ensure_tibble(descriptions$description_links)
  } else {
    desc_tbl <- ensure_tibble(descriptions)
    links_tbl <- tibble::tibble()
  }

  list(
    descriptions = utf8ize(desc_tbl),
    description_links = utf8ize(links_tbl)
  )
}

load_latest_snapshot <- function(snapshot_dir = "outputs/snapshots", snapshot = NULL) {
  if (!is.null(snapshot)) return(snapshot)

  if (!dir.exists(snapshot_dir)) {
    stop("Snapshot directory not found: ", snapshot_dir)
  }

  latest_path <- file.path(snapshot_dir, "snapshot_latest.rds")
  if (file.exists(latest_path)) {
    return(readRDS(latest_path))
  }

  snaps <- list.files(
    snapshot_dir,
    pattern = "^snapshot_\\d{4}-\\d{2}-\\d{2}.*\\.rds$",
    full.names = TRUE
  )
  if (length(snaps) == 0) {
    stop("No snapshot files found in ", snapshot_dir)
  }

  info <- file.info(snaps)
  latest <- snaps[order(info$mtime, decreasing = TRUE)][1]
  readRDS(latest)
}

normalize_for_export <- function(snapshot) {
  if (!is.list(snapshot)) stop("Snapshot must be a list with meta/transcripts/chapters/descriptions")
  if (is.null(snapshot$meta) || is.null(snapshot$transcripts) || is.null(snapshot$chapters)) {
    stop("Snapshot missing required sections (meta/transcripts/chapters)")
  }
# final package! 
  list(
    meta = normalize_meta(snapshot$meta),
    transcripts = normalize_transcripts(snapshot$transcripts),
    chapters = normalize_chapters(snapshot$chapters),
    descriptions = normalize_descriptions(snapshot$descriptions)
  )
}

validate_tables <- function(tables) {
  required <- list(
    meta = c("episode_slug", "episode_nr", "title", "publish_date", "duration", "episode_url", "audio_url", "podhome_uuid"),
    transcripts = c("episode_slug", "podhome_uuid", "transcript_url", "full_transcript"),
    chapters = c("episode_slug", "chapter_title", "chapter_url", "chapter_ts"),
    descriptions = c("episode_slug", "description_text"),
    description_links = c("episode_slug", "section", "text", "link")
  )

  missing <- character()
  if (!all(required$meta %in% names(tables$meta))) {
    missing <- c(missing, paste0("meta: ", paste(setdiff(required$meta, names(tables$meta)), collapse = ", ")))
  }
  if (!all(required$transcripts %in% names(tables$transcripts))) {
    missing <- c(missing, paste0("transcripts: ", paste(setdiff(required$transcripts, names(tables$transcripts)), collapse = ", ")))
  }
  if (!all(required$chapters %in% names(tables$chapters))) {
    missing <- c(missing, paste0("chapters: ", paste(setdiff(required$chapters, names(tables$chapters)), collapse = ", ")))
  }
  if (!all(required$descriptions %in% names(tables$descriptions$descriptions))) {
    missing <- c(missing, paste0("descriptions: ", paste(setdiff(required$descriptions, names(tables$descriptions$descriptions)), collapse = ", ")))
  }
  if (!all(required$description_links %in% names(tables$descriptions$description_links))) {
    missing <- c(missing, paste0("description_links: ", paste(setdiff(required$description_links, names(tables$descriptions$description_links)), collapse = ", ")))
  }

  if (length(missing) > 0) {
    stop("Required columns missing:\n", paste(missing, collapse = "\n"))
  }

  if (nrow(tables$meta) == 0) warning("meta table has 0 rows")
  if (nrow(tables$transcripts) == 0) warning("transcripts table has 0 rows")
  if (nrow(tables$chapters) == 0) warning("chapters table has 0 rows")
  if (nrow(tables$descriptions$descriptions) == 0) warning("descriptions table has 0 rows")
  if (nrow(tables$descriptions$description_links) == 0) warning("description_links table has 0 rows")

  if ("transcript_truncated" %in% names(tables$transcripts)) {
    n_trunc <- sum(tables$transcripts$transcript_truncated %in% TRUE, na.rm = TRUE)
    if (n_trunc > 0) {
      warning("", n_trunc, " transcript(s) exceed ", MAX_XLSX_CHARS, " characters and will be truncated in XLSX")
    }
  }
}

write_sqlite <- function(tables, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  committed <- FALSE
  on.exit({
    if (!committed) try(DBI::dbRollback(con), silent = TRUE)
    DBI::dbDisconnect(con)
  }, add = TRUE)

  DBI::dbBegin(con)

  DBI::dbWriteTable(con, "meta", tables$meta, overwrite = TRUE)
  DBI::dbWriteTable(con, "transcripts", tables$transcripts, overwrite = TRUE)
  DBI::dbWriteTable(con, "chapters", tables$chapters, overwrite = TRUE)
  DBI::dbWriteTable(con, "descriptions", tables$descriptions$descriptions, overwrite = TRUE)
  DBI::dbWriteTable(con, "description_links", tables$descriptions$description_links, overwrite = TRUE)

  # some nice index optimization!
  
  if ("episode_slug" %in% names(tables$meta)) DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_meta_slug ON meta(episode_slug)")
  if ("podhome_uuid" %in% names(tables$meta)) DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_meta_uuid ON meta(podhome_uuid)")
  if ("episode_slug" %in% names(tables$transcripts)) DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_tx_slug ON transcripts(episode_slug)")
  if ("podhome_uuid" %in% names(tables$transcripts)) DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_tx_uuid ON transcripts(podhome_uuid)")
  if ("episode_slug" %in% names(tables$chapters)) DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ch_slug ON chapters(episode_slug)")
  if ("episode_slug" %in% names(tables$descriptions$descriptions)) DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_desc_slug ON descriptions(episode_slug)")
  if ("episode_slug" %in% names(tables$descriptions$description_links)) DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_links_slug ON description_links(episode_slug)")

  DBI::dbCommit(con)
  committed <- TRUE
}

write_excel <- function(tables, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  xlsx_tables <- tables
  if ("full_transcript" %in% names(xlsx_tables$transcripts)) {
    xlsx_tables$transcripts$full_transcript <- substr(
      xlsx_tables$transcripts$full_transcript,
      1,
      MAX_XLSX_CHARS
    )
  }

  writexl::write_xlsx(
    list(
      meta = xlsx_tables$meta,
      transcripts = xlsx_tables$transcripts,
      chapters = xlsx_tables$chapters,
      descriptions = xlsx_tables$descriptions$descriptions,
      description_links = xlsx_tables$descriptions$description_links
    ),
    path = path
  )
}

run_export <- function() {
  snapshot <- load_latest_snapshot()
  tables <- normalize_for_export(snapshot)
  validate_tables(tables)

  out_dir <- "outputs/exports"
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  xlsx_path <- file.path(out_dir, "snapshot_xlsx.xlsx")
  sqlite_path <- file.path(out_dir, "snapshot_sqlite.sqlite")

  write_excel(tables, xlsx_path)
  write_sqlite(tables, sqlite_path)

  message("Exported XLSX: ", xlsx_path)
  message("Exported SQLite: ", sqlite_path)
  invisible(list(xlsx = xlsx_path, sqlite = sqlite_path))
}


# the only time an artifact is created:
run_export()
