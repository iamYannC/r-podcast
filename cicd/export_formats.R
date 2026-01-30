source("build-scripts/shared.R")

safe_as_tibble <- function(x) {
  if (is.null(x)) return(tibble::tibble())
  if (is.data.frame(x)) return(tibble::as_tibble(x))
  x
}

load_latest_data <- function() {
  snap_dir <- "outputs/snapshots"
  snaps <- list.files(snap_dir, pattern = "^snapshot_.*\\.rds$", full.names = TRUE)
  snap_path <- NULL
  if (length(snaps) > 0) {
    info <- file.info(snaps)
    snap_path <- snaps[order(info$mtime, decreasing = TRUE)][1]
  }

  if (!is.null(snap_path) && file.exists(snap_path)) {
    snap <- readRDS(snap_path)
    return(snap)
  }

  # Fallback to section binaries
  meta <- if (file.exists("outputs/meta.rds")) readRDS("outputs/meta.rds") else tibble::tibble()
  tx   <- if (file.exists("outputs/transcripts.rds")) readRDS("outputs/transcripts.rds") else tibble::tibble()
  ch   <- if (file.exists("outputs/chapters.rds")) readRDS("outputs/chapters.rds") else tibble::tibble()
  desc <- if (file.exists("outputs/descriptions.rds")) readRDS("outputs/descriptions.rds") else list()

  if (!is.list(desc) || is.data.frame(desc)) {
    desc <- list(descriptions = safe_as_tibble(desc), description_links = tibble::tibble())
  } else {
    if (!is.null(desc$descriptions)) desc$descriptions <- safe_as_tibble(desc$descriptions)
    if (!is.null(desc$description_links)) desc$description_links <- safe_as_tibble(desc$description_links)
  }

  list(
    meta = safe_as_tibble(meta),
    transcripts = safe_as_tibble(tx),
    chapters = safe_as_tibble(ch),
    descriptions = desc
  )
}

write_sqlite <- function(data, path = "outputs/sqlitedb/rweekly.sqlite") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  DBI::dbWriteTable(con, "meta", data$meta, overwrite = TRUE)
  DBI::dbWriteTable(con, "transcripts", data$transcripts, overwrite = TRUE)
  DBI::dbWriteTable(con, "chapters", data$chapters, overwrite = TRUE)
  DBI::dbWriteTable(con, "descriptions", data$descriptions$descriptions, overwrite = TRUE)
  DBI::dbWriteTable(con, "description_links", data$descriptions$description_links, overwrite = TRUE)

  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_meta_slug ON meta(episode_slug)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_tx_slug ON transcripts(episode_slug)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ch_slug ON chapters(episode_slug)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_desc_slug ON descriptions(episode_slug)")
  DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_links_slug ON description_links(episode_slug)")
}

write_excel <- function(data, path = "outputs/xlsx/rweekly.xlsx") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writexl::write_xlsx(
    list(
      meta = data$meta,
      transcripts = data$transcripts,
      chapters = data$chapters,
      descriptions = data$descriptions$descriptions,
      description_links = data$descriptions$description_links
    ),
    path = path
  )
}

run_export <- function() {
  dat <- load_latest_data()
  write_sqlite(dat)
  write_excel(dat)
  message("Exported SQLite and Excel to outputs/sqlitedb and outputs/xlsx")
  invisible(dat)
}

if (sys.nframe() == 0) {
  run_export()
}
