source('build-scripts/shared.R')
source('build-scripts/build_meta.R')
source('build-scripts/build_chapters.R')
source('build-scripts/build_transcripts.r')
source('build-scripts/build_descriptions.R')

#' Build a full snapshot
#'
#' Sources the shared/build scripts, runs the build steps, and writes a dated
#' RDS snapshot containing meta, transcripts, chapters, and descriptions.
#'
#' @param pages Integer vector of listing pages (NULL = all pages).
#' @param episode_index Optional indices to pass to section builders.
#' @param use_existing If TRUE, load pre-built artifacts in `outputs/*.rds`.
#' @param out_dir Output directory for snapshots.
#' @return A list with `meta`, `transcripts`, `chapters`, `descriptions`.
build_all <- function(pages = NULL,
                      episode_index = Inf,
                      use_existing = TRUE,
                      out_dir = "outputs/snapshots") {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  as_tbl <- function(x) {
    if (is.null(x)) return(x)
    if (is.data.frame(x)) return(tibble::as_tibble(x))
    x
  }

  if (use_existing &&
      all(file.exists(file.path("outputs", c("meta.rds", "transcripts.rds", "chapters.rds", "descriptions.rds"))))) {
    meta <- as_tbl(readRDS(file.path("outputs", "meta.rds")))
    transcripts <- as_tbl(readRDS(file.path("outputs", "transcripts.rds")))
    chapters <- as_tbl(readRDS(file.path("outputs", "chapters.rds")))
    descriptions <- readRDS(file.path("outputs", "descriptions.rds"))
    if (is.list(descriptions)) {
      if (!is.null(descriptions$descriptions)) descriptions$descriptions <- as_tbl(descriptions$descriptions)
      if (!is.null(descriptions$description_links)) descriptions$description_links <- as_tbl(descriptions$description_links)
    } else {
      descriptions <- as_tbl(descriptions)
    }
  } else {
    meta <- as_tbl(build_meta(pages = pages))
    transcripts <- as_tbl(build_transcripts(meta, episode_index = episode_index))
    chapters <- as_tbl(build_chapters(meta, episode_index = episode_index))
    descriptions <- build_descriptions(meta, episode_index = episode_index)
    if (is.list(descriptions)) {
      if (!is.null(descriptions$descriptions)) descriptions$descriptions <- as_tbl(descriptions$descriptions)
      if (!is.null(descriptions$description_links)) descriptions$description_links <- as_tbl(descriptions$description_links)
    } else {
      descriptions <- as_tbl(descriptions)
    }
  }

  snapshot <- list(
    meta = meta,
    transcripts = transcripts,
    chapters = chapters,
    descriptions = descriptions
  )

  # Always override section RDS outputs for convenience
  dir.create(dirname(output$META), recursive = TRUE, showWarnings = FALSE)
  saveRDS(meta, output$META)
  saveRDS(transcripts, output$TRANSCRIPTS)
  saveRDS(chapters, output$CHAPTERS)
  saveRDS(descriptions, output$DESCRIPTIONS)

  date_tag <- format(Sys.Date(), "%Y-%m-%d")
  fname <- sprintf("snapshot_%s.rds", date_tag)
  out_path <- file.path(out_dir, fname)
  if (file.exists(out_path)) {
    fname <- sprintf("snapshot_%s_%s.rds", date_tag, format(Sys.time(), "%H%M%S"))
    out_path <- file.path(out_dir, fname)
  }

  saveRDS(snapshot, out_path)
  message("Snapshot written: ", out_path)
  invisible(snapshot)
}

# Option A: Build from existing binaries
  #  build_all()

# Option B: Build from scratch - scrape yourself
  #  build_all(use_existing = TRUE)