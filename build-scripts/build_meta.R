source('build-scripts/shared.R')

# Build the authoritative episode metadata table ---------------------------
# Returns a tibble with one row per episode.

.list_pages <- function(pages = NULL) {
  first_doc <- get_listing_page(1L)
  page_links <- html_elements(first_doc, ".pagination-link") |> html_text2()
  n_pages <- suppressWarnings(max(as.integer(page_links), na.rm = TRUE))
  if (!is.finite(n_pages) || n_pages <= 0) n_pages <- 1L

  if (is.null(pages)) {
    pages <- seq_len(n_pages)
  } else {
    pages <- unique(pages)
    pages <- pages[pages >= 1 & pages <= n_pages]
    if (length(pages) == 0) stop("No valid pages requested.")
  }

  docs <- vector("list", length(pages))
  for (i in seq_along(pages)) {
    pg <- pages[i]
    docs[[i]] <- if (pg == 1) first_doc else get_listing_page(pg)
  }
  docs
}

.parse_listing_doc <- function(doc) {
  tiles <- html_elements(doc, config_selectors$SEL_EP_TILE)
  links <- tiles %>% html_element(config_selectors$SEL_EP_LINK)
  title_raw <- links %>% html_text(trim = TRUE)
  episode_path <- links %>% html_attr("href")

  tibble(
    title_raw    = title_raw,
    episode_path = episode_path,
    episode_url  = paste0("https://serve.podhome.fm", episode_path),
    meta_raw     = tiles %>% html_element(config_selectors$SEL_META) %>% html_text(trim = TRUE),
    podhome_uuid = map_chr(tiles, get_api_id)
  ) |>
    mutate(
      episode_slug = canonicalize_episode_slug(extract_slug(episode_path), title_raw),
      across(c(meta_raw), ~replace_na(.x, "")),
      parse_meta_raw(meta_raw)
    )
}

.extract_meta_from_payload <- function(payload) {
  payload_value <- function(key, default = NA_character_) {
    val <- payload[[key]]
    if (is.null(val) || length(val) == 0) return(default)
    val[[1]]
  }

  audio_from_payload <- dplyr::coalesce(
    dplyr::na_if(as.character(payload_value("TemporaryAudioURL")), ""),
    dplyr::na_if(as.character(payload_value("ProcessedAudioURL")), "")
  )

  tibble(
    episode_slug = canonicalize_episode_slug(as.character(payload_value("EpisodeSlug")), as.character(payload_value("Title"))),
    episode_nr   = suppressWarnings(as.integer(payload_value("EpisodeNr", NA_integer_))),
    title        = as.character(payload_value("Title")),
    publish_date = as_date(as.character(payload_value("PublishDate"))),
    duration     = hms::as_hms(as.character(payload_value("Duration"))),
    audio_url    = audio_from_payload,
    podhome_uuid = as.character(payload_value("EpisodeId"))
  )
}

#' build_meta
#' @param pages integer vector of listing pages to read (1-based). NULL = all pages.
#' @param payload_fetch logical; fetch episode payloads for authoritative fields
#' @return tibble
build_meta <- function(pages = NULL, payload_fetch = TRUE) {
  listing_docs <- .list_pages(pages)
  listing_tbl <- map_dfr(listing_docs, .parse_listing_doc)
  empty_payload_meta <- tibble(
    episode_slug = character(),
    episode_nr   = integer(),
    title        = character(),
    publish_date = as_date(character()),
    duration     = hms::as_hms(character()),
    audio_url    = character(),
    podhome_uuid = character()
  )
  payload_meta <- empty_payload_meta
  if (payload_fetch) {
    payload_meta <- purrr::map_dfr(listing_tbl$episode_url, \(u) {
      res <- try(fetch_payload(u), silent = TRUE)
      if (inherits(res, "try-error")) return(tibble())
      .extract_meta_from_payload(res)
    })
    if (nrow(payload_meta) == 0) {
      payload_meta <- empty_payload_meta
    }
  }

  coalesce_cols <- function(df, cols, default) {
    avail <- cols[cols %in% names(df)]
    if (length(avail) == 0) return(rep(default, nrow(df)))
    acc <- df[[avail[1]]]
    if (length(avail) > 1) {
      for (col in avail[-1]) {
        acc <- coalesce(acc, df[[col]])
      }
    }
    replace_na(acc, default)
  }

  rss_meta <- tryCatch(
    rss_episode_map(),
    error = function(e) {
      warning("Failed to fetch metadata from RSS feed: ", conditionMessage(e))
      tibble(
        episode_slug = character(),
        title_rss = character(),
        episode_url_rss = character(),
        podhome_uuid_rss = character(),
        audio_url_rss = character(),
        transcript_url_rss = character(),
        transcript_type_rss = character(),
        episode_nr_rss = integer(),
        publish_date_rss = as.Date(character()),
        duration_rss = hms::as_hms(character())
      )
    }
  )

  df <- listing_tbl |>
    left_join(payload_meta, by = "episode_slug") |>
    left_join(rss_meta, by = "episode_slug")

  if ("duration.y" %in% names(df)) df$duration.y <- hms::as_hms(df$duration.y)
  if ("duration.x" %in% names(df)) df$duration.x <- hms::as_hms(df$duration.x)
  if ("duration_rss" %in% names(df)) df$duration_rss <- hms::as_hms(df$duration_rss)

  df$episode_nr   <- coalesce_cols(df, c("episode_nr", "episode_nr_rss"), NA_integer_)
  df$publish_date <- coalesce_cols(df, c("publish_date.y", "publish_date_rss", "publish_date.x"), as_date(NA))
  df$duration     <- coalesce_cols(df, c("duration.y", "duration_rss", "duration.x"), hms::hms(NA_real_))
  df$title        <- coalesce_cols(df, c("title", "title_rss", "title_raw"), NA_character_)
  df$podhome_uuid <- coalesce_cols(df, c("podhome_uuid.y", "podhome_uuid.x", "podhome_uuid_rss"), NA_character_)
  df$audio_url    <- coalesce_cols(df, c("audio_url_rss", "audio_url"), NA_character_)
  df$episode_slug <- canonicalize_episode_slug(df$episode_slug, df$title)

  df |>
    select(episode_slug, episode_nr, title, publish_date, duration,
           episode_url, audio_url, podhome_uuid) |>
    distinct(episode_slug, .keep_all = TRUE)
}
