r_weekly <- rvest::read_html("https://serve.podhome.fm/r-weekly-highlights")
n_episdoes <- nrow(readxl::read_xlsx('data/all_data.xlsx'))

if(length(r_weekly |> rvest::html_elements(".episodeLink")) > n_episdoes){

# re-run the whole scrape
source('r weekly podcast scrape - followup.R')
} else{
  print("No new episodes found")
}