library(collapse)
library(rvest)
library(stringi)
library(glue)
library(tidyverse)

url <- "https://serve.podhome.fm/r-weekly-highlights"
r_weekly <- read_html(url)

# Get number of pages to then iterate over each page
page_count <- '.pagination-link'
n_pages <- r_weekly |> html_elements(page_count) |> length()

# Inner functions to extract data from html based on css selectors, either text or href
get_href <- function(css_selector){
  map(1:n_pages,\(n_pg) {
    page_html <- read_html(glue("{url}?currentPage={n_pg}&searchTerm="))
    page_html |> html_elements(css_selector) |> html_attr("href") 
  }) |> unlist()
}
get_text2 <- function(css_selector){
  map(1:n_pages,\(n_pg) {
    page_html <- read_html(glue("{url}?currentPage={n_pg}&searchTerm="))
    page_html |> html_elements(css_selector) |> html_text2()
  }) |> unlist()
}
#

get_ep_metadata <- function(){
  # Vector of links to all episodes
  eps <- get_href(".episodeLink")
  
  ep_link <- paste0("https://serve.podhome.fm", eps) 
  ep_name <-  ep_link |> stri_replace_last_regex("^.*/","") |> snakecase::to_snake_case()
  
  episode <<- matrix(data = c(ep_link, ep_name),ncol=2,dimnames = list(NULL, c("link", "name"))) # exported to global environemnt, as it will be then used by the other function.
  
  date_duration <- get_text2(".is-tablet+ .has-text-grey")
  
  # split date and duration
  date_duration <- map(date_duration, \(s) s |>
                         stri_split_fixed(" &vert; ") |>
                         unlist() |>
                         stri_trim_both())
  ep_date <- map_chr(date_duration, \(x) x[[1]]) |> dmy()
  ep_duration <- map_chr(date_duration, \(x) x[[2]]) |> hms()
  
  # get short description
  ep_desc_short <- get_text2(".is-hidden-touch")
  ep_desc_short <- ep_desc_short[seq(2, length(ep_desc_short), 2)] |> stri_trim_both() # some duplication, plus the first one is not an episode description
  # A fix due to multiple pages: need to filter header from each page
  indx_remove <- stri_detect_fixed(ep_desc_short,'Contact') |> which()
  ep_description_short <- ep_desc_short[-indx_remove]
  
  tibble::tibble(ep_name, ep_date, ep_duration, ep_description_short)
}


# put it all in a nice table
all_episodes <- get_ep_metadata()




# get full episode data
get_ep_data <- function(episode_index) {
  ep_link <- episode[episode_index, "link"]
  ep_name <- episode[episode_index, "name"]
  ep_html <- ep_link |> read_html()
  episode_data <- vector("list", length = 5) # Optimize to set names only at the end
  
  episode_data[[1]] <- all_episodes[episode_index,]
  
  
  description_long <- ep_html |>
    html_elements("#descriptionTab") |>
    html_text2()
  episode_data[[2]] <- tibble(ep_name = all_episodes$ep_name[episode_index],description_long)
  
  links <- 
    ep_html |>
    html_elements("#descriptionTab a") |>
    html_attr("href")
  episode_data[[3]] <- tibble(ep_name = all_episodes$ep_name[episode_index],links)
  
  # INNER FUNCTION FOR TRANSCRIPT #
  full_transcript <- ep_html |>
    html_elements("#transcriptTab") |>
    html_text2()
  
  
  inner_get_text_chunck <- function(full_transcript) {
    # timestamp #
    time_stamps_pat <- "\\[(\\d{2}:\\d{2}:\\d{2})\\]"
    time_stamps <- stri_match_all_regex(full_transcript, time_stamps_pat)[[1]][, 2] |> hms()
    # speaker#
    speaker_pattern <- "\r [A-Z][a-z]+ [A-Z][a-z]+:\r"
    speaker <- stri_match_all_regex(full_transcript, speaker_pattern)[[1]][, 1] |> stri_trim_both()
    
    # text #
    pattern <- "\\[\\W+\\]|\\s*:\\r?\\n" # changed from  "\\[[^\\]]*\\]" to current since it took also the [email protected]
    text_chunck <- stri_split_regex(full_transcript, pattern) |>
      map(stri_trim_both) %>%
      .[[1]]
    indx_remove <- which(map_lgl(text_chunck, \(x) nchar(x) < 5))
    if (!is_empty(indx_remove)) text_chunck <- text_chunck[-indx_remove]
    
    # table #
    tibble(
      ep_name = ep_name,
      trans_timestamp = time_stamps,
      trans_speaker = speaker,
      trans_text = text_chunck[-1]
    ) |>
      mutate(
        trans_text = stri_replace_all_fixed(trans_text, trans_speaker, "") |>
          stri_trim_both(),
        trans_speaker = stri_replace_all_fixed(trans_speaker, ":", "")
      )
  }
  
  
  episode_data[[4]] <- inner_get_text_chunck(full_transcript)
  
  # INNER FUNCTION FOR CHAPTERS #
  inner_get_chapters_chunck <- function(ep_link) {
    link_text <- ep_html |>
      html_elements("#chapterTab p") |>
      html_text2()
    if (is_empty(link_text)) link_text <- NA
    
    link_timestamp <- ep_html |>
      html_elements("#chapterTab a") |>
      html_text2()
    link_timestamp <- link_timestamp |>
      stri_extract_all_regex("\\d{2}:\\d{2}:\\d{2}") |>
      map(\(x) x[[1]]) |> hms()
    link_timestamp <- link_timestamp[complete.cases(link_timestamp)]
    if (is_empty(link_timestamp)) link_timestamp <- NA
    
    link_href <- ep_html |>
      html_elements(xpath = "//*[@class='column']") |>
      html_elements("a") |>
      html_attr("href") %>%
      .[-1]
    if (is_empty(link_href)) {
      link_href <- NA
    } else {
      if (length(link_href) < length(link_text)) { # It can occur that there is no href for some references in chapter.
        
        # Recursive function to fix this annoying issue
        add_na <- function(link_href) {
          if (length(link_href) == length(link_text)) {
            return(link_href)
          } else {
            link_href <- c(link_href, NA)
            return(add_na(link_href))
          }
        }
        # now implement the function
        link_href <- add_na(link_href)
      }
    }
    
    tibble(
      ep_name = ep_name,
      chap_timestamp = link_timestamp,
      chap_text = link_text,
      chap_href = link_href
    )
  }
  episode_data[[5]] <- inner_get_chapters_chunck(ep_link)
  
  # return list of all episode data ive collected
  names(episode_data) <- c("metadata","description_long", "links", "transcript", "chapters")
  return(episode_data)
}
all_episodes_data <- map(1:nrow(episode),get_ep_data,.progress = TRUE)

# END OF CORE FUNCTIONALITY # 


# Save to JSON, RDS and XLSX
# Json
json_ep <- all_episodes_data |> jsonlite::toJSON(pretty = T)
write_lines(json_ep, "data/all_data.json")

# RDS
write_rds(all_episodes_data, "data/all_data.rds")

# Excel Workbook

for(name in names(all_episodes_data[[1]])){
  tmp_file <- map(1:length(all_episodes_data),\(x) all_episodes_data[[x]][[name]]) |> list_rbind()
  assign(paste0('all_',name),tmp_file)
}
rm(tmp_file)
all_list <- list(all_metadata, all_description_long,all_links,all_transcript,all_chapters)

# Save data to one XL workbook
library(openxlsx)
wb <- createWorkbook()
map(names(all_episodes_data[[1]]),\(name) addWorksheet(wb, name))
map(1:length(all_list),\(i) writeData(wb, i, all_list[[i]]))
saveWorkbook(wb, "data/all_data.xlsx", overwrite = TRUE)