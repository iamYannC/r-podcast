# Welcome!

Author: Yann Cohen

## What is it all about?

A Fun Mini-Project: Scraping the R-Weekly Highlight Podcast This educational and open-source project involves scraping the R-Weekly highlight podcast. Users are encouraged to maintain ethical standards when accessing the information. If you find anything interesting, feel free to submit a PR or contact me! 😊

### NOT a memeber...

Please note that I am not an official member of the R-Weekly team. Everything you find here is unrelated to the podcast/weekly highlights team.

### What you will find here

-   `r_weekly_podcast_scrape.R` - the main script where all the scraping happens.

-   `r_weekly_podcast_scra[e_followup.R` - a few simple follow-up analysis i have conducted. it's subject to changes and you are most welcome to get inspired and do new things!

-   `auto_workflow.R` - this is just the activation file that is ran by `auto workflow.yml`.

-   In data folder - `all_data.*` in three formats: `JSON` `rds` and `xlsx` with all the information regarding each episode:

    -   episode duration

    -   short & long description

    -   transcript (when available)

    -   chapters

    -   links

[R Weekly Highlights](https://serve.podhome.fm/r-weekly-highlights)

[Contact me](mailto:Yannco5@gmail.com)

![Episode Duration Over Time](episode_duration.png)

![Preview of the XL Workbook](xl_preview.png) Note the tabs—each corresponds to a different part of the episode and can be easily joined via the primary key `ep_name` (episode name).

## Experimental - Python

I am by no means a python programmer, but I played with it a bit (and some help from our dear GenAI agents) and created a few not very pleasent looking audio plots. I should probably do something with it...

![Audio Plot](Py/figures/24-w26%20-%20chunk_1_analysis.png)
