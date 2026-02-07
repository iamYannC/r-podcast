source('build-scripts/shared.R')

# Helpers -------------------------------------------------------------------

clean_html_content <- function(html_doc) {
  text_content <- html_text(html_doc)
  text_content <- gsub("\\s+", " ", text_content)
  trimws(text_content)
}

normalize_title_key <- function(x) {
  x |>
    stringr::str_to_lower() |>
    stringr::str_replace_all("[^a-z0-9]+", " ") |>
    stringr::str_squish()
}

split_description_html <- function(html_text) {
  ep_links_pos <- regexpr("(?i)Episode Links?", html_text, perl = TRUE)[1]
  supplement_pos <- regexpr("(?i)Supplement Resources?", html_text, perl = TRUE)[1]
  support_pos <- regexpr("(?i)Supporting the show", html_text, perl = TRUE)[1]
  
  sections <- list(
    content = "",
    episode_links = "",
    supplement_resources = "",
    support_show = ""
  )
  
  if (ep_links_pos > 0) {
    sections$content <- substr(html_text, 1, ep_links_pos - 1)
    
    if (supplement_pos > 0) {
      sections$episode_links <- substr(html_text, ep_links_pos, supplement_pos - 1)
      
      if (support_pos > 0) {
        sections$supplement_resources <- substr(html_text, supplement_pos, support_pos - 1)
        sections$support_show <- substr(html_text, support_pos, nchar(html_text))
      } else {
        sections$supplement_resources <- substr(html_text, supplement_pos, nchar(html_text))
      }
    } else if (support_pos > 0) {
      sections$episode_links <- substr(html_text, ep_links_pos, support_pos - 1)
      sections$support_show <- substr(html_text, support_pos, nchar(html_text))
    } else {
      sections$episode_links <- substr(html_text, ep_links_pos, nchar(html_text))
    }
  } else {
    sections$content <- html_text
  }
  
  sections
}

extract_links_and_text <- function(section_html, section_name) {
  section_html <- trimws(section_html)
  
  if (section_html == "") {
    return(tibble(
      section = character(),
      text = character(),
      link = character()
    ))
  }
  
  html_doc <- read_html(section_html)
  links <- html_nodes(html_doc, "a")
  
  results_list <- list()
  
  if (length(links) > 0) {
    for (i in seq_along(links)) {
      link_text <- html_text(links[i])
      link_href <- html_attr(links[i], "href")
      
      if (!is.na(link_href) && nchar(trimws(link_text)) > 0) {
        results_list[[length(results_list) + 1]] <- list(
          section = section_name,
          text = trimws(link_text),
          link = link_href
        )
      }
    }
  }
  
  plain_text <- html_doc |>
    html_text2() |>
    stringr::str_replace_all("(?i)Episode Links?", "") |>
    stringr::str_replace_all("(?i)Supplement Resources?", "") |>
    stringr::str_replace_all("(?i)Supporting the show", "") |>
    stringr::str_squish()
  
  if (length(results_list) == 0 && nchar(plain_text) > 0) {
    results_list[[1]] <- list(
      section = section_name,
      text = plain_text,
      link = NA_character_
    )
  }
  
  if (length(results_list) > 0) {
    bind_rows(results_list)
  } else {
    tibble(
      section = character(),
      text = character(),
      link = character()
    )
  }
}

process_episode_sections <- function(slug, ep_nr, description_html, source_row_id = NA_integer_) {
  sections <- split_description_html(description_html)
  
  bind_rows(
    extract_links_and_text(sections$content, "content"),
    extract_links_and_text(sections$episode_links, "episode_links"),
    extract_links_and_text(sections$supplement_resources, "supplement_resources"),
    extract_links_and_text(sections$support_show, "support_show")
  ) |>
    mutate(episode_slug = slug, episode_nr = ep_nr, source_row_id = source_row_id) |>
    select(episode_slug, episode_nr, source_row_id, section, text, link)
}

extract_episode_nr <- function(link, title, item = NULL) {
  if (!is.null(item)) {
    item_episode <- xml2::xml_text(xml2::xml_find_first(item, ".//*[local-name()='episode']"))
    n_item <- suppressWarnings(as.integer(item_episode))
    if (!is.na(n_item)) return(n_item)
  }
  n <- suppressWarnings(as.integer(stringr::str_extract(link, "\\d+")))
  if (!is.na(n)) return(n)
  suppressWarnings(as.integer(stringr::str_extract(title, "\\d+")))
}

extract_episode_data <- function(item, source_row_id) {
  link <- xml_text(xml_find_first(item, ".//link"))
  description_html <- xml_text(xml_find_first(item, ".//description"))
  title_txt <- xml_text(xml_find_first(item, ".//title"))
  html_doc <- read_html(description_html)
  tibble(
    source_row_id     = source_row_id,
    episode_nr        = extract_episode_nr(link, title_txt, item = item),
    episode_slug_raw  = extract_slug(link),
    title_key         = normalize_title_key(title_txt),
    title_txt         = title_txt,
    description_text  = clean_html_content(html_doc),
    description_html  = description_html
  )
}

#' build_descriptions
#' @param meta_tbl meta table (must include episode_nr, episode_slug)
#' @param episode_index optional specific episodes index (indexed on `meta_tbl`)
#' @return list(descriptions, description_links)
build_descriptions <- function(meta_tbl = NULL, episode_index = Inf) {
  if (is.null(meta_tbl)) stop("meta_tbl is required to map episode_nr to canonical episode_slug.")
  stopifnot("episode_nr" %in% names(meta_tbl), "episode_slug" %in% names(meta_tbl))
  if (is.finite(episode_index[1])) meta_tbl <- meta_tbl[episode_index,]

  rss_doc <- get_rss()
  items <- xml_find_all(rss_doc, ".//item")
  desc_raw <- purrr::map_dfr(seq_along(items), \(i) extract_episode_data(items[[i]], source_row_id = i)) |>
    mutate(episode_slug_guess = canonicalize_episode_slug(episode_slug_raw, title_txt))

  meta_keep <- meta_tbl |>
    mutate(
      episode_nr = suppressWarnings(as.integer(episode_nr)),
      title_key = normalize_title_key(title)
    ) |>
    select(episode_nr, title_key, episode_slug_meta = episode_slug)

  meta_by_nr <- meta_keep |>
    filter(!is.na(episode_nr)) |>
    distinct(episode_nr, .keep_all = TRUE) |>
    select(episode_nr, episode_slug_meta_nr = episode_slug_meta)

  meta_by_title <- meta_keep |>
    filter(!is.na(title_key), title_key != "") |>
    distinct(title_key, .keep_all = TRUE) |>
    select(title_key, episode_slug_meta_title = episode_slug_meta)

  desc_resolved <- desc_raw |>
    left_join(meta_by_nr, by = "episode_nr") |>
    left_join(meta_by_title, by = "title_key") |>
    mutate(
      episode_slug = coalesce(episode_slug_meta_nr, episode_slug_meta_title, episode_slug_guess),
      episode_slug = canonicalize_episode_slug(episode_slug, title_txt),
      description_text = stringr::str_squish(description_text)
    )

  unresolved <- is.na(desc_resolved$episode_slug) | desc_resolved$episode_slug == ""
  if (any(unresolved) && nrow(desc_resolved) == nrow(meta_tbl)) {
    warning("Applying guarded positional fallback for unresolved description slugs.")
    desc_resolved$episode_slug[unresolved] <- meta_tbl$episode_slug[which(unresolved)]
  }

  target_slugs <- unique(meta_tbl$episode_slug)
  desc_resolved <- desc_resolved |>
    filter(episode_slug %in% target_slugs)

  desc_tbl <- desc_resolved |>
    select(episode_slug, description_text)

  links_tbl <- map_dfr(seq_len(nrow(desc_resolved)), \(i) {
    process_episode_sections(
      slug = desc_resolved$episode_slug[i],
      ep_nr = desc_resolved$episode_nr[i],
      description_html = desc_resolved$description_html[i],
      source_row_id = desc_resolved$source_row_id[i]
    )
  }) |>
    mutate(text = stringr::str_squish(text)) |>
    select(episode_slug, section, text, link)

  
  list(
    descriptions = desc_tbl,
    description_links = links_tbl
  )
}

# Optional: small sample when run directly
if (sys.nframe() == 0) {
  meta_sample <- try(build_meta(pages = 1), silent = TRUE)
  if (!inherits(meta_sample, "try-error")) {
    sample <- build_descriptions(meta_tbl = meta_sample, episode_index = 2)
    print(sample$descriptions)
    print(head(sample$description_links, 3))
  } else {
    message("meta sample failed; skipping descriptions smoke test.")
  }
}
