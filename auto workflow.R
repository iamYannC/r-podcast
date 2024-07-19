require(rvest)

url <- "https://serve.podhome.fm/r-weekly-highlights"
r_weekly <- read_html(url)

n_episdoes <- nrow(readxl::read_xlsx("data/all_data.xlsx"))

# Number of pages
page_count <- '.pagination-link'
n_pages <- r_weekly |> html_elements(page_count) |> length()
# Number of episodes in the last page
page_html <- read_html(glue("{url}?currentPage={n_pages}&searchTerm="))
eps_in_last_pg <- page_html |> html_elements(".episodeLink") |> html_text2() |> length()

# Number of episodes based on 10 episodes per page
n_new_eps <- eps_in_last_pg + (n_pages-1) * 10

if (n_new_eps > n_episdoes) {
  # re-run the whole scrape
  source("r weekly podcast scrape - followup.R")
} else {
  x <- Sys.time()
  writeLines(
    paste("Number of episodes:", n_episdoes, "@", x) |>
      sub("\\..*", "", x = _),
    "data/last run.txt"
  )
}
