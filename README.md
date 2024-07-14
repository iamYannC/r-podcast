Welcome!
Yann Cohen

A Fun Mini-Project: Scraping the R-Weekly Highlight Podcast
This educational and open-source project involves scraping the R-Weekly highlight podcast. Users are encouraged to maintain ethical standards when accessing the information. If you find anything interesting, feel free to submit a PR or contact me! 😊

Please note that I am not an official member of the R-Weekly team. Everything you find here is unrelated to the podcast/weekly highlights team.

Personal Contributions:
Scraping Techniques:
Utilized rvest, CSS selectors, and XML paths.
Automation:
Set up GitHub actions to run the scraper every Monday at midnight (UTC). Check auto.yaml for exact details.
R Files:
r_weekly_podcast_scrape (Main Script):
Handles the primary scraping process.
r_weekly_podcast_scrape_followup (Minor Analysis):
Subject to frequent changes.
auto_workflow (Activation File):
Detects new podcast episodes and runs both scripts.
Updates three output files:
A JSON file
An XLSX file with multiple tabs
An RDS file
Source - R Weekly Highlights

Contact me - Yannco5@gmail.com

![Episode Duration Over Time](episode_duration.png)

![Preview of the XL Workbook](xl_preview.png)
Note the tabs—each corresponds to a different part of the episode and can be easily joined via the primary key ep_name (episode name).