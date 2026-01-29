source('new-logic/shared.R')

# Build chapters table from episode payload --------------------------------

build_chapters_table <- function(payload) {
  chapters <- payload$Chapters$`$values`
  if (is.null(chapters) || length(chapters) == 0 || (is.data.frame(chapters) && nrow(chapters) == 0)) {
    return(tibble(
      episode_slug = character(),
      chapter_title = character(),
      chapter_url = character(),
      chapter_ts = character()
    ))
  }
  
  chapter_url <- if ("Url" %in% names(chapters)) as.character(chapters$Url) else rep(NA_character_, nrow(chapters))
  tibble(
    episode_slug = payload$EpisodeSlug,
    chapter_title = chapters$Title,
    chapter_url = chapter_url,
    chapter_ts = chapters$TimeStamp
  )
}

#' build_chapters
#' @param meta_tbl tibble with episode_slug and episode_url
#' @param episode_index optional specific episodes index (indexed on `meta_tbl`)
#' @return tibble of chapters
build_chapters <- function(meta_tbl, episode_index = Inf) {
  stopifnot(is.data.frame(meta_tbl), "episode_slug" %in% names(meta_tbl), "episode_url" %in% names(meta_tbl))
  if (is.finite(episode_index[1])) meta_tbl <- meta_tbl[episode_index,] # as flexible as it gets.
  
  purrr::map_dfr(seq_len(nrow(meta_tbl)), \(i) {
    payload <- try(fetch_payload(meta_tbl$episode_url[i]), silent = TRUE)
    if (inherits(payload, "try-error")) {
      return(tibble(
        episode_slug = character(),
        chapter_title = character(),
        chapter_url = character(),
        chapter_ts = character()
      ))
    }
    build_chapters_table(payload)
  }) |>
    dplyr::mutate(chapter_url = dplyr::na_if(chapter_url, ""))
}

