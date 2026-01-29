source('new-logic/shared.R')

# Helpers -------------------------------------------------------------------

clean_html_content <- function(html_doc) {
  text_content <- html_text(html_doc)
  text_content <- gsub("\\s+", " ", text_content)
  trimws(text_content)
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

process_episode_sections <- function(slug, ep_nr, description_html) {
  sections <- split_description_html(description_html)
  
  bind_rows(
    extract_links_and_text(sections$content, "content"),
    extract_links_and_text(sections$episode_links, "episode_links"),
    extract_links_and_text(sections$supplement_resources, "supplement_resources"),
    extract_links_and_text(sections$support_show, "support_show")
  ) |>
    mutate(episode_slug = slug, episode_nr = ep_nr) |>
    select(episode_slug, episode_nr, section, text, link)
}

extract_episode_nr <- function(link, title) {
  n <- suppressWarnings(as.integer(stringr::str_extract(link, "\\d+")))
  if (!is.na(n)) return(n)
  suppressWarnings(as.integer(stringr::str_extract(title, "\\d+")))
}

extract_episode_data <- function(item, ns) {
  link <- xml_text(xml_find_first(item, ".//link"))
  description_html <- xml_text(xml_find_first(item, ".//description"))
  title_txt <- xml_text(xml_find_first(item, ".//title"))
  html_doc <- read_html(description_html)
  tibble(
    episode_nr        = extract_episode_nr(link, title_txt),
    episode_slug_raw  = extract_slug(link),
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

  rss_doc <- get_rss()
  ns <- xml_ns(rss_doc)
  items <- xml_find_all(rss_doc, ".//item")
  if (is.finite(episode_index[1])) items <- items[episode_index]
  
  desc_tbl <- map_dfr(items, extract_episode_data, ns = ns)
  links_tbl <- map_dfr(seq_len(nrow(desc_tbl)), \(i) {
    process_episode_sections(desc_tbl$episode_slug_raw[i], desc_tbl$episode_nr[i], desc_tbl$description_html[i])
  })

  meta_keep <- meta_tbl |> select(episode_nr, episode_slug_meta = episode_slug)
  desc_tbl <- desc_tbl |>
    left_join(meta_keep, by = "episode_nr") |>
    mutate(
      episode_slug = coalesce(episode_slug_meta, episode_slug_raw),
      description_text = stringr::str_squish(description_text)
    ) |>
    select(episode_slug, description_text)
  links_tbl <- links_tbl |>
    left_join(meta_keep, by = "episode_nr") |>
    mutate(
      episode_slug = coalesce(episode_slug_meta, episode_slug),
      text = stringr::str_squish(text)
    ) |>
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
