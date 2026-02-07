suppressPackageStartupMessages({
  library(tidyverse)
  library(rvest)
  library(xml2)
  library(glue)
  library(stringr)
  library(lubridate)
  library(hms)
  library(httr2)
})

# --- Configuration & Selectors ---
config_selectors <- list(
  BASE_URL      = "https://serve.podhome.fm/r-weekly-highlights", # robots.txt 404
  RSS_URL       = "https://serve.podhome.fm/rss/bb28afcc-137e-5c66-b231-4ffad7979b44",
  SEL_EP_TILE   = "div[id^='episodeTile']",
  SEL_EP_LINK   = ".episodeLink",
  SEL_META      = ".is-tablet+ .has-text-grey",
  PLAY_BUTTON   = ".playButtonMain, #play-buttonMain"
)

USER_AGENT <- "rweekly-scraper/0.2 (+https://github.com/)"

# Shared output defaults (used only when scripts explicitly write)
output <- list(
  TRANSCRIPTS   = "outputs/transcripts.rds",
  DESCRIPTIONS  = "outputs/descriptions.rds",
  CHAPTERS      = "outputs/chapters.rds",
  META          = "outputs/meta.rds"
)

# --- Lightweight in-memory cache -----------------------------------------
html_cache <- new.env(parent = emptyenv())

.cache_get <- function(key) {
  if (exists(key, envir = html_cache, inherits = FALSE)) {
    get(key, envir = html_cache, inherits = FALSE)
  } else {
    NULL
  }
}

.cache_set <- function(key, value) {
  assign(key, value, envir = html_cache)
  value
}

# --- Fetchers -------------------------------------------------------------

get_html <- function(url, use_cache = TRUE) {
  if (use_cache) {
    cached <- .cache_get(url)
    if (!is.null(cached)) return(cached)
  }
  doc <- tryCatch(
    {
      resp <- httr2::request(url) |> httr2::req_user_agent(USER_AGENT) |> httr2::req_perform()
      read_html(httr2::resp_body_string(resp))
    },
    error = function(e) read_html(url)
  )
  if (use_cache) .cache_set(url, doc) else doc
}

get_xml <- function(url, use_cache = TRUE) {
  if (use_cache) {
    cached <- .cache_get(url)
    if (!is.null(cached)) return(cached)
  }
  doc <- tryCatch(
    {
      resp <- httr2::request(url) |> httr2::req_user_agent(USER_AGENT) |> httr2::req_perform()
      read_xml(httr2::resp_body_string(resp))
    },
    error = function(e) read_xml(url)
  )
  if (use_cache) .cache_set(url, doc) else doc
}

get_rss <- function() get_xml(config_selectors$RSS_URL, use_cache = TRUE)

get_listing_page <- function(page_no = 1L) {
  url <- glue("{config_selectors$BASE_URL}?currentPage={page_no}")
  get_html(url, use_cache = TRUE)
}

# --- Parsing helpers ------------------------------------------------------

extract_slug <- function(link) {
  slug <- sub(".*/([^/]+)$", "\\1", link)
  sub("\\?.*$", "", slug)
}

canonicalize_episode_slug <- function(slug, title = NULL) {
  slug <- as.character(slug)
  title <- if (is.null(title)) rep(NA_character_, length(slug)) else as.character(title)
  if (length(title) == 1L && length(slug) > 1L) title <- rep(title, length(slug))
  if (length(title) != length(slug)) title <- rep(title, length.out = length(slug))

  vapply(seq_along(slug), function(i) {
    .canonicalize_episode_slug_scalar(slug[i], title[i])
  }, character(1))
}

.canonicalize_episode_slug_scalar <- function(slug, title = NA_character_) {
  candidates <- c(slug, title)
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  if (length(candidates) == 0) return(NA_character_)

  lowered <- tolower(candidates)
  if (any(grepl("\\bintroduction\\b", lowered, perl = TRUE))) return("introduction")
  if (any(grepl("2021[-\\s]?reflection", lowered, perl = TRUE)) ||
      any(grepl("2021[-\\s]?reflections", lowered, perl = TRUE))) {
    return("2021-reflection")
  }

  pattern <- "(?i)(?:issue[-\\s]*)?(\\d{4})[-\\s]*w?(\\d{1,2})"
  for (cand in candidates) {
    match <- stringr::str_match(cand, pattern)
    if (!is.na(match[1, 2])) {
      week <- suppressWarnings(as.integer(match[1, 3]))
      if (is.finite(week)) return(sprintf("%s-w%02d", match[1, 2], week))
    }
  }

  slug
}

parse_meta_raw <- function(meta_text) {
  # "23 January 2026 | 00:33:49"
  cleaned <- meta_text |>
    str_replace_all("\\s+", " ") |>
    str_replace_all("&vert;", "|") |>
    str_trim()
  pieces <- str_split_fixed(cleaned, "\\|", 2)
  tibble(
    publish_date = dmy(str_trim(pieces[, 1]), quiet = TRUE),
    duration     = vapply(str_trim(pieces[, 2]), function(x) {
      tryCatch(as_hms(x), error = function(e) hms(NA_real_))
    }, FUN.VALUE = hms(NA_real_))
  )
}

get_api_id <- function(tile_node) {
  onclick_attr <- tile_node %>% html_element("div.playButtonEpisode") %>% html_attr("onclick")
  str_extract(onclick_attr, "(?<=\"EpisodeId\":\")[0-9a-f-]{36}")
}

extract_payload_from_page <- function(doc) {
  onclick_vec <- html_elements(doc, config_selectors$PLAY_BUTTON) |>
    html_attr("onclick")
  pattern <- '(?s)(\\{.*\\})(?=,\\s*\\"R Weekly Highlights\\")'
  json_txt <- str_match(onclick_vec, pattern)[, 2]
  jsonlite::fromJSON(json_txt)
}

fetch_payload <- function(episode_url) {
  doc <- get_html(episode_url, use_cache = TRUE)
  tryCatch(extract_payload_from_page(doc), error = function(e) stop("payload parse failed for ", episode_url))
}

resolve_transcript_endpoint <- function(id_or_url) {
  if (is.null(id_or_url) || is.na(id_or_url) || !nzchar(id_or_url)) return(NA_character_)
  if (grepl("^https?://", id_or_url, ignore.case = TRUE)) return(id_or_url)
  if (grepl("^[0-9a-f-]{36}$", id_or_url, ignore.case = TRUE)) {
    return(glue("https://serve.podhome.fm/api/transcript/{id_or_url}"))
  }
  NA_character_
}

fetch_transcript_text <- function(id_or_url) {
  endpoint <- resolve_transcript_endpoint(id_or_url)
  if (is.na(endpoint)) return(NA_character_)

  txt <- tryCatch(
    {
      resp <- httr2::request(endpoint) |>
        httr2::req_user_agent(USER_AGENT) |>
        httr2::req_perform()

      final_url <- tryCatch(httr2::resp_url(resp), error = function(e) endpoint)
      if (grepl("/sitemap\\.xml$", final_url, ignore.case = TRUE)) return(NA_character_)

      body <- httr2::resp_body_string(resp)
      if (!nzchar(body)) return(NA_character_)

      content_type <- tolower(tryCatch(httr2::resp_header(resp, "content-type"), error = function(e) ""))
      is_html <- grepl("text/html", content_type, fixed = TRUE) ||
        grepl("^\\s*<!doctype html|^\\s*<html", body, ignore.case = TRUE)
      is_xml <- grepl("xml", content_type, fixed = TRUE) || grepl("^\\s*<\\?xml|^\\s*<urlset", body, ignore.case = TRUE)
      if (is_xml && grepl("<urlset", body, fixed = TRUE)) return(NA_character_)

      if (is_html) {
        xml2::read_html(body) |> rvest::html_text2()
      } else {
        body
      }
    },
    error = function(e) NA_character_
  )

  if (is.na(txt)) return(NA_character_)
  stringr::str_squish(txt)
}

rss_episode_map <- function() {
  rss_doc <- get_rss()
  items <- xml2::xml_find_all(rss_doc, ".//item")
  if (length(items) == 0) {
    return(tibble(
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
    ))
  }

  pick_transcript_node <- function(nodes) {
    if (length(nodes) == 0) return(xml2::xml_missing())
    rel <- tolower(xml2::xml_attr(nodes, "rel"))
    typ <- tolower(xml2::xml_attr(nodes, "type"))

    idx <- which(rel == "transcript" & grepl("html", typ))
    if (length(idx) > 0) return(nodes[[idx[1]]])

    idx <- which(rel == "transcript")
    if (length(idx) > 0) return(nodes[[idx[1]]])

    idx <- which(grepl("html", typ))
    if (length(idx) > 0) return(nodes[[idx[1]]])

    nodes[[1]]
  }

  parse_pub_date <- function(x) {
    if (is.na(x) || !nzchar(x)) return(as.Date(NA))
    out <- suppressWarnings(lubridate::parse_date_time(x, orders = c("a, d b Y H:M:S z", "d b Y H:M:S z"), quiet = TRUE))
    as.Date(out)
  }

  parse_duration <- function(x) {
    if (is.na(x) || !nzchar(x)) return(hms::hms(NA_real_))
    suppressWarnings(hms::as_hms(x))
  }

  purrr::map_dfr(items, function(item) {
    title <- xml2::xml_text(xml2::xml_find_first(item, "title"))
    link <- xml2::xml_text(xml2::xml_find_first(item, "link"))
    guid <- xml2::xml_text(xml2::xml_find_first(item, "guid"))
    pub_date <- xml2::xml_text(xml2::xml_find_first(item, "pubDate"))
    duration_txt <- xml2::xml_text(xml2::xml_find_first(item, ".//*[local-name()='duration']"))
    episode_nr_txt <- xml2::xml_text(xml2::xml_find_first(item, ".//*[local-name()='episode']"))

    enclosure <- xml2::xml_find_first(item, "enclosure")
    audio_url <- xml2::xml_attr(enclosure, "url")

    transcript_nodes <- xml2::xml_find_all(item, ".//*[local-name()='transcript']")
    transcript_node <- pick_transcript_node(transcript_nodes)
    transcript_url <- xml2::xml_attr(transcript_node, "url")
    transcript_type <- xml2::xml_attr(transcript_node, "type")

    slug <- canonicalize_episode_slug(extract_slug(link), title)

    tibble(
      episode_slug = slug,
      title_rss = dplyr::na_if(title, ""),
      episode_url_rss = dplyr::na_if(link, ""),
      podhome_uuid_rss = dplyr::na_if(guid, ""),
      audio_url_rss = dplyr::na_if(audio_url, ""),
      transcript_url_rss = dplyr::na_if(transcript_url, ""),
      transcript_type_rss = dplyr::na_if(transcript_type, ""),
      episode_nr_rss = suppressWarnings(as.integer(dplyr::na_if(episode_nr_txt, ""))),
      publish_date_rss = parse_pub_date(pub_date),
      duration_rss = parse_duration(duration_txt)
    )
  }) |>
    dplyr::filter(!is.na(episode_slug), episode_slug != "") |>
    dplyr::distinct(episode_slug, .keep_all = TRUE)
}


# avoid connection error for over using all available connections
.cleanup_connections <- function() {
  closeAllConnections()
}

# Register cleanup on exit of any build function
.onAttach <- function(libname, pkgname) {
  reg.finalizer(globalenv(), .cleanup_connections, onexit = TRUE)
}
