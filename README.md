# Welcome!
Yann Cohen

- [A fun mini-project scraping the r-weekly highlight
  podcast.](#a-fun-mini-project-scraping-the-r-weekly-highlight-podcast)
  - [Personally, I exercised the
    following:](#personally-i-exercised-the-following)
  - [There are 3 R files:](#there-are-3-r-files)

## A fun mini-project scraping the r-weekly highlight podcast.

This is an educational and open-source project. Users are encouraged to
maintain ethical standards when accessing the information. If you find
anything interesting, feel free to submit a PR or contact me :)

I am not an official member of the r-weekly team, everything that you
find here is un-related to the podcast/weekly highlights team.

### Personally, I exercised the following:

- Scraping using rvest, CSS selectors and XML paths
- Automation using GitHub actions. Scraper runs every Monday at Midnight
  (UTC) - check `auto.yaml` for the exact details.

### There are 3 R files:

- `r weekly podcast scrape` - main script
- `r weekly podcast scrape - followup` - Minor analysis. subject to many
  changes
- `auto workflow` - The activation file. If a new episode is detected,
  runs both scripts to update 3 Output files:
  - A JSON file
  - An XLSX file with multiple tabs
  - An RDS file

[Source - R Weekly
Highlights](https://serve.podhome.fm/r-weekly-highlights)

[Contact me -
Yannco5@gmail.com](mailto:yannco5@gmail.com?subject=Hello%20Yann!&body=What%20is%20the%20ultimate%20answer?)

<img src="episode_duration.png" width="1200"
alt="Episode duration over time" />

#### Here is a preview of how the XL Workbook looks like.

Note the tabs. each corresponds to a different part of the episode and
can be easily joined via primary key ep_name (episode name).

<img src="xl_preview.png" width="1000" alt="XL Preview" />
