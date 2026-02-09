source('build-scripts/build_meta.R')
source('build-scripts/build_descriptions.R')

report_slug_checks <- function(meta_tbl, desc_tbl, links_tbl, label = "sample") {
  meta_slugs <- unique(meta_tbl$episode_slug)

  desc_in_meta <- mean(desc_tbl$episode_slug %in% meta_slugs) * 100
  links_in_meta <- mean(links_tbl$episode_slug %in% meta_slugs) * 100

  desc_only <- setdiff(unique(desc_tbl$episode_slug), unique(links_tbl$episode_slug))
  links_only <- setdiff(unique(links_tbl$episode_slug), unique(desc_tbl$episode_slug))

  cat("\n---", label, "---\n")
  cat("meta_rows:", nrow(meta_tbl), "\n")
  cat("descriptions_rows:", nrow(desc_tbl), "\n")
  cat("description_links_rows:", nrow(links_tbl), "\n")
  cat("desc_slug_in_meta_pct:", sprintf("%.2f", desc_in_meta), "\n")
  cat("links_slug_in_meta_pct:", sprintf("%.2f", links_in_meta), "\n")
  cat("slug_set_mismatch_desc_only:", length(desc_only), "\n")
  cat("slug_set_mismatch_links_only:", length(links_only), "\n")

  desc_missing <- desc_tbl[
    !(desc_tbl$episode_slug %in% meta_slugs) |
      is.na(desc_tbl$episode_slug) |
      desc_tbl$episode_slug == "",
    ,
    drop = FALSE
  ]
  links_missing <- links_tbl[
    !(links_tbl$episode_slug %in% meta_slugs) |
      is.na(links_tbl$episode_slug) |
      links_tbl$episode_slug == "",
    ,
    drop = FALSE
  ]

  if (nrow(desc_missing) > 0) {
    cat("sample_desc_missing:\n")
    print(utils::head(desc_missing, 5))
  }
  if (nrow(links_missing) > 0) {
    cat("sample_links_missing:\n")
    print(utils::head(links_missing, 5))
  }
}

pages <- c(1, 5, 9, 11)
meta_tbl <- build_meta(pages = pages)
res <- build_descriptions(meta_tbl = meta_tbl)
report_slug_checks(
  meta_tbl = meta_tbl,
  desc_tbl = res$descriptions,
  links_tbl = res$description_links,
  label = "mixed_sample_pages_1_5_9_11"
)

meta_sub <- utils::head(meta_tbl, 2)
res_sub <- build_descriptions(meta_tbl = meta_sub, episode_index = 1:2)
report_slug_checks(
  meta_tbl = meta_sub,
  desc_tbl = res_sub$descriptions,
  links_tbl = res_sub$description_links,
  label = "incremental_head_2"
)
