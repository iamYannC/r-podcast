source("build-scripts/shared.R")
source("build-scripts/build_meta.R")
source("build-scripts/build_chapters.R")
source("build-scripts/build_transcripts.r")
source("build-scripts/build_descriptions.R")

# Update workflow -----------------------------------------------------------
# - Fetch page 1 meta (10 most recent)
# - Compare against first 10 existing meta slugs
# - If new episodes exist, build only those and prepend to existing tables
# - Override outputs/*.rds and write a new snapshot

meta_path <- "outputs/meta.rds"
tx_path <- "outputs/transcripts.rds"
chap_path <- "outputs/chapters.rds"
desc_path <- "outputs/descriptions.rds"
snapshot_dir <- "outputs/snapshots"
log_path <- "cicd/log.txt"

log_action <- function(action, msg) {
  date_tag <- format(Sys.Date(), "%Y-%m-%d")
  line <- sprintf("[%s %s] %s", action, date_tag, msg)
  cat(line, "\n", file = log_path, append = TRUE)
  message(line)
}

if (!file.exists(meta_path)) {
  log_action("scrape", paste0("Missing meta.rds at ", meta_path))
} else {


existing_meta <- readRDS(meta_path)
existing_meta <- tibble::as_tibble(existing_meta)
if (!("episode_slug" %in% names(existing_meta))) stop("meta.rds missing episode_slug")

# Fetch most recent page (10 episodes)
latest_meta <- build_meta(pages = 1) |> tibble::as_tibble()

existing_top10 <- existing_meta$episode_slug[seq_len(min(10, nrow(existing_meta)))]
new_slugs <- latest_meta$episode_slug[!(latest_meta$episode_slug %in% existing_top10)]

if (length(new_slugs) == 0) {
  log_action("scrape", "No new episodes detected.")
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

updated_meta <- existing_meta |>
  dplyr::filter(!(episode_slug %in% new_slugs)) |>
  dplyr::bind_rows(new_meta)

updated_tx <- existing_tx |>
  dplyr::filter(!(episode_slug %in% new_slugs)) |>
  dplyr::bind_rows(tibble::as_tibble(new_tx))

updated_ch <- existing_ch |>
  dplyr::filter(!(episode_slug %in% new_slugs)) |>
  dplyr::bind_rows(tibble::as_tibble(new_ch))

updated_desc <- list(
  descriptions = existing_desc$descriptions |>
    dplyr::filter(!(episode_slug %in% new_slugs)) |>
    dplyr::bind_rows(tibble::as_tibble(new_desc$descriptions)),
  description_links = existing_desc$description_links |>
    dplyr::filter(!(episode_slug %in% new_slugs)) |>
    dplyr::bind_rows(tibble::as_tibble(new_desc$description_links))
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

date_tag <- format(Sys.Date(), "%Y-%m-%d")
fname <- sprintf("snapshot_%s.rds", date_tag)
out_path <- file.path(snapshot_dir, fname)
if (file.exists(out_path)) {
  fname <- sprintf("snapshot_%s_%s.rds", date_tag, format(Sys.time(), "%H%M%S")) # god forbid i override existing snapshots
  out_path <- file.path(snapshot_dir, fname)
}

saveRDS(snapshot, out_path)
log_action("scrape", paste0("Updated snapshot written: ", out_path))
}
}
