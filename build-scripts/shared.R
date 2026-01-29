library(tidyverse)
library(rvest)
library(xml2)
library(glue)
library(stringr)
library(lubridate)
library(hms)
library(httr2)

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

fetch_transcript_text <- function(uuid) {
  url <- glue("https://serve.podhome.fm/api/transcript/{uuid}")
  read_html(url) |> html_text2()
}
