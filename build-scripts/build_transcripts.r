source('build-scripts/shared.R')

# Build transcript table from Podhome API (per-episode UUID) ---------------

#' build_transcripts
#' @param meta_tbl tibble with at least episode_slug (and ideally podhome_uuid; if missing it will be fetched)
#' @param episode_index optional specific episodes index (indexed on `meta_tbl`)
#' @return tibble
build_transcripts <- function(meta_tbl, episode_index = Inf) {
  stopifnot(is.data.frame(meta_tbl), "episode_slug" %in% names(meta_tbl))
  if (is.finite(episode_index[1])) meta_tbl <- meta_tbl[episode_index,]

  podhome_ids <- if ("podhome_uuid" %in% names(meta_tbl)) {
    meta_tbl$podhome_uuid
  } else {
    purrr::map_chr(meta_tbl$episode_url, \(u) {
      pl <- try(fetch_payload(u), silent = TRUE)
      if (inherits(pl, "try-error")) return(NA_character_)
      pl$EpisodeId
    })
  }

  tibble(
    episode_slug   = meta_tbl$episode_slug,
    podhome_uuid   = podhome_ids,
    transcript_url = glue("https://serve.podhome.fm/api/transcript/{podhome_ids}"),
    full_transcript = map_chr(podhome_ids, \(uuid) {
      tryCatch(fetch_transcript_text(uuid), error = function(e) NA_character_)
    }, .progress = TRUE) |> stringr::str_squish()
  )
}
