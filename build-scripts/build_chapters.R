source('build-scripts/shared.R')

# Build chapters table from episode payload --------------------------------

empty_chapters_tbl <- function() {
  tibble(
    episode_slug = character(),
    chapter_title = character(),
    chapter_url = character(),
    chapter_ts = character()
  )
}

normalize_chapter_ts <- function(x) {
  if (length(x) == 0) return(character())
  if (is.list(x) && !is.data.frame(x)) x <- unlist(x)
  if (is.numeric(x)) return(as.character(hms::as_hms(x)))

  x_chr <- as.character(x)
  is_numeric <- grepl("^\\d+(\\.\\d+)?$", x_chr)
  if (any(is_numeric, na.rm = TRUE)) {
    x_chr[is_numeric] <- as.character(hms::as_hms(as.numeric(x_chr[is_numeric])))
  }

  parsed <- suppressWarnings(hms::as_hms(x_chr))
  out <- x_chr
  out[!is.na(parsed)] <- as.character(parsed[!is.na(parsed)])
  out
}

extract_json_chapters <- function(chapter_df, episode_slug) {
  if (is.null(chapter_df) || length(chapter_df) == 0) return(empty_chapters_tbl())
  if (!is.data.frame(chapter_df)) {
    chapter_df <- tryCatch(tibble::as_tibble(chapter_df), error = function(e) NULL)
  }
  if (is.null(chapter_df) || nrow(chapter_df) == 0) return(empty_chapters_tbl())

  pick_col <- function(df, cols, default = NA_character_) {
    for (col in cols) {
      if (col %in% names(df)) return(df[[col]])
    }
    rep(default, nrow(df))
  }

  chapter_title <- as.character(pick_col(chapter_df, c("title", "Title")))
  chapter_url <- as.character(pick_col(chapter_df, c("url", "Url", "link", "href")))
  chapter_ts <- normalize_chapter_ts(pick_col(chapter_df, c("startTime", "start_time", "start", "time")))

  tibble(
    episode_slug = episode_slug,
    chapter_title = chapter_title,
    chapter_url = chapter_url,
    chapter_ts = chapter_ts
  )
}

fetch_chapters_json <- function(url, episode_slug) {
  if (is.na(url) || !nzchar(url)) return(empty_chapters_tbl())
  json_txt <- tryCatch(
    {
      resp <- httr2::request(url) |>
        httr2::req_user_agent(USER_AGENT) |>
        httr2::req_perform()
      httr2::resp_body_string(resp)
    },
    error = function(e) NA_character_
  )
  if (is.na(json_txt) || !nzchar(json_txt)) return(empty_chapters_tbl())

  payload <- tryCatch(jsonlite::fromJSON(json_txt), error = function(e) NULL)
  if (is.null(payload) || is.null(payload$chapters)) return(empty_chapters_tbl())

  extract_json_chapters(payload$chapters, episode_slug)
}

extract_psc_chapters <- function(chapters_node, episode_slug) {
  if (inherits(chapters_node, "xml_missing") || length(chapters_node) == 0) return(empty_chapters_tbl())

  chapter_nodes <- xml2::xml_find_all(chapters_node, ".//*[local-name()='chapter']")
  if (length(chapter_nodes) == 0) return(empty_chapters_tbl())

  chapter_title <- xml2::xml_attr(chapter_nodes, "title")
  chapter_url <- xml2::xml_attr(chapter_nodes, "href")
  chapter_ts <- normalize_chapter_ts(xml2::xml_attr(chapter_nodes, "start"))

  tibble(
    episode_slug = episode_slug,
    chapter_title = chapter_title,
    chapter_url = chapter_url,
    chapter_ts = chapter_ts
  )
}

build_chapters_from_rss <- function(meta_tbl) {
  rss_doc <- get_rss()
  items <- xml2::xml_find_all(rss_doc, ".//item")
  if (length(items) == 0) return(empty_chapters_tbl())

  target_slugs <- unique(meta_tbl$episode_slug)

  purrr::map_dfr(items, function(item) {
    link <- xml2::xml_text(xml2::xml_find_first(item, "link"))
    title <- xml2::xml_text(xml2::xml_find_first(item, "title"))
    slug_raw <- extract_slug(link)
    slug <- canonicalize_episode_slug(slug_raw, title)
    if (is.na(slug) || !nzchar(slug) || !(slug %in% target_slugs)) return(empty_chapters_tbl())

    chapters_nodes <- xml2::xml_find_all(item, ".//*[local-name()='chapters']")
    if (length(chapters_nodes) == 0) return(empty_chapters_tbl())

    chapters_url <- xml2::xml_attr(chapters_nodes, "url")
    has_url <- !is.na(chapters_url) & nzchar(chapters_url)
    if (any(has_url)) {
      return(fetch_chapters_json(chapters_url[which(has_url)[1]], slug))
    }

    extract_psc_chapters(chapters_nodes[[1]], slug)
  })
}

build_chapters_table <- function(payload, episode_slug = NULL) {
  chapters <- payload$Chapters$`$values`
  if (is.null(chapters) || length(chapters) == 0 || (is.data.frame(chapters) && nrow(chapters) == 0)) {
    return(empty_chapters_tbl())
  }
  
  chapter_url <- if ("Url" %in% names(chapters)) as.character(chapters$Url) else rep(NA_character_, nrow(chapters))
  slug_value <- if (is.null(episode_slug) || is.na(episode_slug) || episode_slug == "") {
    payload$EpisodeSlug
  } else {
    episode_slug
  }
  slug_value <- canonicalize_episode_slug(slug_value)
  tibble(
    episode_slug = slug_value,
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

  rss_chapters <- tryCatch(
    build_chapters_from_rss(meta_tbl),
    error = function(e) {
      warning("Failed to fetch chapters from RSS: ", conditionMessage(e))
      empty_chapters_tbl()
    }
  )
  rss_by_slug <- if (nrow(rss_chapters) > 0) split(rss_chapters, rss_chapters$episode_slug) else list()

  purrr::map_dfr(seq_len(nrow(meta_tbl)), \(i) {
    payload <- try(fetch_payload(meta_tbl$episode_url[i]), silent = TRUE)
    if (inherits(payload, "try-error")) {
      rss_tbl <- rss_by_slug[[meta_tbl$episode_slug[i]]]
      if (is.null(rss_tbl)) return(empty_chapters_tbl())
      return(rss_tbl)
    }
    payload_tbl <- build_chapters_table(payload, episode_slug = meta_tbl$episode_slug[i])
    if (nrow(payload_tbl) > 0) return(payload_tbl)

    rss_tbl <- rss_by_slug[[meta_tbl$episode_slug[i]]]
    if (is.null(rss_tbl)) return(empty_chapters_tbl())
    rss_tbl
  }) |>
    dplyr::mutate(chapter_url = dplyr::na_if(chapter_url, ""))
}
