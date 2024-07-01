library(rvest)
r_weekly <- rvest::read_html("https://serve.podhome.fm/r-weekly-highlights")
n_episdoes <- nrow(readxl::read_xlsx('C:/Users/97253/Documents/R/r-podcast/data/all_data.xlsx'))

if(length(r_weekly |> html_elements(".episodeLink")) > n_episdoes){

# re-run the whole scrape
source('C:/Users/97253/Documents/R/r-podcast/r weekly podcast scrape - followup.R')
