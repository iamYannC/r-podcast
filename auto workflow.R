library(rvest)
r_weekly <- rvest::read_html("https://serve.podhome.fm/r-weekly-highlights")
n_episdoes <- nrow(readxl::read_xlsx('data/all_data.xlsx'))

if(length(r_weekly |> html_elements(".episodeLink")) > n_episdoes){

# re-run the whole scrape
source('r weekly podcast scrape - followup.R')

} else{
x <- Sys.time()
writeLines(paste('generated @',x),'data/last run.txt')

}