source("build-scripts/shared.R")
source("build-scripts/build_meta.R")
source("build-scripts/build_chapters.R")
source("build-scripts/build_transcripts.r")
source("build-scripts/build_descriptions.R")

# Fetch-new-episode workflow ------------------------------------------------
# - Fetch page 1 meta (10 most recent)
# - Compare against first 10 existing meta slugs
# - If new episodes exist, build only those and prepend to existing tables
# - Override outputs/*.rds and write a new snapshot

meta_path <- "outputs/meta.rds"
tx_path <- "outputs/transcripts.rds"
chap_path <- "outputs/chapters.rds"
desc_path <- "outputs/descriptions.rds"
snapshot_dir <- "outputs/snapshots"

log_path <- file.path("cicd", "logs.txt")
log_task <- "fetch-new-episode"

log_action <- function(task, msg) {
  date_tag <- format(Sys.Date(), "%Y-%m-%d")
  line <- sprintf("[%s %s] %s", task, date_tag, msg)
  dir.create("cicd", showWarnings = FALSE, recursive = TRUE)
  cat(line, "\n", file = log_path, append = TRUE)
  message(line)
}

if (!file.exists(meta_path)) {
  log_action(log_task, paste0("Missing meta.rds at ", meta_path))
} else {


existing_meta <- readRDS(meta_path)
existing_meta <- tibble::as_tibble(existing_meta)
if (!("episode_slug" %in% names(existing_meta))) stop("meta.rds missing episode_slug")

# Fetch most recent page (10 episodes)
latest_meta <- build_meta(pages = 1) |> tibble::as_tibble()

existing_top10 <- existing_meta$episode_slug[seq_len(min(10, nrow(existing_meta)))]
new_slugs <- latest_meta$episode_slug[!(latest_meta$episode_slug %in% existing_top10)]

if (length(new_slugs) == 0) {
  log_action(log_task, "No new episodes detected.")
} else {

new_meta <- latest_meta |> dplyr::filter(episode_slug %in% new_slugs)

# Build new section data (only new episodes)
new_tx <- build_transcripts(new_meta, episode_index = seq_len(nrow(new_meta)))
new_ch <- build_chapters(new_meta, episode_index = seq_len(nrow(new_meta)))
new_desc <- build_descriptions(new_meta, episode_index = seq_len(nrow(new_meta)))

existing_tx <- if (file.exists(tx_path)) readRDS(tx_path) else tibble::tibble()
existing_ch <- if (file.exists(chap_path)) readRDS(chap_path) else tibble::tibble()
existing_desc <- if (file.exists(desc_path)) readRDS(desc_path) else list()

existing_tx <- tibble::as_tibble(existing_tx)
existing_ch <- tibble::as_tibble(existing_ch)

if (is.list(existing_desc)) {
  if (!is.null(existing_desc$descriptions)) existing_desc$descriptions <- tibble::as_tibble(existing_desc$descriptions)
  if (!is.null(existing_desc$description_links)) existing_desc$description_links <- tibble::as_tibble(existing_desc$description_links)
} else {
  existing_desc <- list(descriptions = tibble::as_tibble(existing_desc),
                        description_links = tibble::tibble())
}

prepend_new <- function(existing_tbl, new_tbl, new_slugs) {
  existing_tbl <- tibble::as_tibble(existing_tbl)
  new_tbl <- tibble::as_tibble(new_tbl)

  if (!("episode_slug" %in% names(new_tbl)) || nrow(new_tbl) == 0) {
    return(existing_tbl)
  }
  if (!("episode_slug" %in% names(existing_tbl)) || nrow(existing_tbl) == 0) {
    return(new_tbl)
  }

  existing_filtered <- existing_tbl |>
    dplyr::filter(!(episode_slug %in% new_slugs))

  dplyr::bind_rows(new_tbl, existing_filtered)
}

updated_meta <- prepend_new(existing_meta, new_meta, new_slugs)
updated_tx <- prepend_new(existing_tx, new_tx, new_slugs)
updated_ch <- prepend_new(existing_ch, new_ch, new_slugs)

existing_descriptions <- if (is.null(existing_desc$descriptions)) tibble::tibble() else existing_desc$descriptions
existing_description_links <- if (is.null(existing_desc$description_links)) tibble::tibble() else existing_desc$description_links

updated_desc <- list(
  descriptions = prepend_new(existing_descriptions, new_desc$descriptions, new_slugs),
  description_links = prepend_new(existing_description_links, new_desc$description_links, new_slugs)
)

# Override section RDS files
saveRDS(updated_meta, meta_path)
saveRDS(updated_tx, tx_path)
saveRDS(updated_ch, chap_path)
saveRDS(updated_desc, desc_path)

# Write snapshot
snapshot <- list(
  meta = updated_meta,
  transcripts = updated_tx,
  chapters = updated_ch,
  descriptions = updated_desc
)

dir.create(snapshot_dir, showWarnings = FALSE, recursive = TRUE)
latest_path <- file.path(snapshot_dir, "snapshot_latest.rds")
if (file.exists(latest_path)) {
  info <- file.info(latest_path)
  stamp <- info$mtime
  if (is.na(stamp)) stamp <- Sys.time()
  date_tag <- format(stamp, "%Y-%m-%d")
  time_tag <- format(stamp, "%H%M%S")
  archived_name <- sprintf("snapshot_%s_%s.rds", date_tag, time_tag)
  archived_path <- file.path(snapshot_dir, archived_name)
  if (file.exists(archived_path)) {
    suffix <- format(Sys.time(), "%H%M%S")
    archived_name <- sprintf("snapshot_%s_%s_%s.rds", date_tag, time_tag, suffix)
    archived_path <- file.path(snapshot_dir, archived_name)
  }
  if (file.rename(latest_path, archived_path)) {
    log_action(log_task, paste0("Archived previous latest snapshot: ", archived_path))
  } else {
    log_action(log_task, paste0("Failed to archive previous latest snapshot at ", latest_path))
  }
}

saveRDS(snapshot, latest_path)
log_action(log_task, paste0("Updated snapshot written: ", latest_path))
}
}
