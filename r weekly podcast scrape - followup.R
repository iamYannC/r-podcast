# having fun with the data..

stopifnot('all_episodes_data' %in% ls());stop('all_episodes_data is required.')


time_talked <-   all_trans |> left_join(select(all_episodes,-4),by = c('trans_episode'='ep_name')) |> 
  mutate(seconds_talked = lead(as.integer(trans_timestamp),default = 0) - as.integer(trans_timestamp),
         words_said = stri_count_words(trans_text),
         .by = trans_episode) |> 
    # fix last row of each episode
    mutate(
      seconds_talked = ifelse(seconds_talked < 0,as.integer(ep_duration) - as.integer(trans_timestamp),seconds_talked)
      
    )
  
time_talked |> reframe(tot_time_talked = sum(seconds_talked) |> hms::hms(),
                       mean_time_talked = mean(seconds_talked) |> hms::hms(),
                       .by = trans_speaker)


all_trans |> tidytext::unnest_tokens(word,input = trans_text,strip_numeric = TRUE) |> 
  dplyr::filter(!word %in% c(stopwords::data_stopwords_stopwordsiso[['en']],'thomas','eric')) |> 
  dplyr::count(trans_speaker,word) |> tidylo::bind_log_odds(set = trans_speaker,feature =  word,n = n) |> 
  slice_max(log_odds_weighted,n=5,with_ties = F,by = trans_speaker)
# Seems like Mike says 'sort' (of?) a lot! 

# Let's verify by taking key word in context

# Filter text with the word 'sort' to remove rows before kwic
all_trans |> 
  dplyr::filter(stri_detect_fixed(trans_text,"sort")) |> nrow() 

# Sanity check to verify there are still same number of occurrences of 'sort' for Mike, 165
all_trans |>
  dplyr::filter(stri_detect_fixed(trans_text,"sort")) |>
  tidytext::unnest_tokens(word,input = trans_text,strip_numeric = TRUE) |>
  dplyr::filter(!word %in% c(stopwords::data_stopwords_stopwordsiso[['en']],'thomas','eric')) |>
  dplyr::count(trans_speaker,word) |> tidylo::bind_log_odds(set = trans_speaker,feature =  word,n = n) |>
  # slice_max(log_odds_weighted,n=5,with_ties = F,by = trans_speaker) |>
  dplyr::filter(word=='sort')

# should probably become a test..

sort_kwic <- all_trans |> 
  dplyr::filter(stri_detect_fixed(trans_text,"sort")) |> pull(trans_text) |> stri_c(collapse = "@\n@") |> 
  quanteda::tokens(remove_punct = TRUE) |> quanteda::kwic("sort",window = 2)

sort_kwic[[6]] # token after 'of' is pretty revealing as well


# Basic plot of episode duration over time
(p <- all_episodes |> # convery Period class to minutes
  mutate(ep_duration_m = as.numeric(ep_duration) / 60) |> 
  ggplot(aes(x = ep_date, y = ep_duration_m ))+geom_path(lwd = 1,color="navyblue")+
  theme_light(base_size = 13)+
  scale_x_date(date_labels = '%b %Y',date_breaks = '6 month') + 
  scale_y_continuous(labels = scales::unit_format(unit = 'm'))
)

title <- "
## Episode duration over time
After 2022's jump it flactuates with a general positive trend"

# a bit nicer

p +
  labs(title = title,x = 'Date',y = 'Duration (minutes)')+
  theme(plot.title = marquee::element_marquee())+
  geom_curve(curvature = 0.2,angle = 270,
             arrow = grid::arrow(type = 'closed',length = grid::unit(0.1,'in')),
             aes(x = as.Date('2021-03-30'),y = 68,xend = as.Date('2022-01-01'),yend = 50))+
  annotate('text',x = as.Date('2021-06-15'),y = 70,
           label = 'Interesting...',size = rel(8),family = 'david')+
  annotate('text',x = as.Date('2024-01-30'), y = 22,size = rel(5), label = 
                   
                   all_episodes$ep_duration[year(all_episodes$ep_date)==2024] |> as.numeric() |> min() |> hms::hms() |> stri_replace_all_regex("^\\d+:","") #omg wth
  )

