source('build-scripts/shared.R')

# Build transcript table from RSS transcript URLs with API UUID fallback ----

#' build_transcripts
#' @param meta_tbl tibble with at least episode_slug (and ideally podhome_uuid; if missing it will be fetched)
#' @param episode_index optional specific episodes index (indexed on `meta_tbl`)
#' @return tibble
build_transcripts <- function(meta_tbl, episode_index = Inf) {
  stopifnot(is.data.frame(meta_tbl), "episode_slug" %in% names(meta_tbl))
  if (is.finite(episode_index[1])) meta_tbl <- meta_tbl[episode_index,]

  rss_map <- tryCatch(
    rss_episode_map(),
    error = function(e) {
      warning("Failed to fetch transcript metadata from RSS feed: ", conditionMessage(e))
      tibble(
        episode_slug = character(),
        podhome_uuid_rss = character(),
        transcript_url_rss = character()
      )
    }
  )

  if (!("podhome_uuid" %in% names(meta_tbl))) meta_tbl$podhome_uuid <- NA_character_

  tx_meta <- meta_tbl |>
    dplyr::mutate(episode_slug = canonicalize_episode_slug(episode_slug, if ("title" %in% names(meta_tbl)) title else NA_character_)) |>
    dplyr::left_join(
      rss_map |> dplyr::select(episode_slug, podhome_uuid_rss, transcript_url_rss),
      by = "episode_slug"
    )

  podhome_ids <- dplyr::coalesce(tx_meta$podhome_uuid, tx_meta$podhome_uuid_rss)
  api_fallback_urls <- ifelse(
    !is.na(podhome_ids) & podhome_ids != "",
    glue("https://serve.podhome.fm/api/transcript/{podhome_ids}"),
    NA_character_
  )
  transcript_urls <- dplyr::coalesce(tx_meta$transcript_url_rss, api_fallback_urls)

  pull_transcript <- function(transcript_url, uuid) {
    txt <- tryCatch(fetch_transcript_text(transcript_url), error = function(e) NA_character_)
    if (!is.na(txt) && nzchar(txt)) return(txt)
    if (is.na(uuid) || !nzchar(uuid)) return(NA_character_)
    tryCatch(fetch_transcript_text(uuid), error = function(e) NA_character_)
  }

  tibble(
    episode_slug   = tx_meta$episode_slug,
    podhome_uuid   = podhome_ids,
    transcript_url = transcript_urls,
    full_transcript = purrr::map2_chr(transcript_urls, podhome_ids, pull_transcript, .progress = TRUE) |>
      stringr::str_squish()
  )
}
