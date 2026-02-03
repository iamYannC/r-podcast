# R Weekly Podcast Scraper 🙃 🚴
<div align="center">
  <a href="https://jokasan.github.io/r-weekly_chatbot/" target="_blank">
    <img src="assets/og1.png" alt="Hex logo for the R weekly podcast scraper project" height="300" style="border-radius: 15px;">
  </a>
</div>

I first started this project before agents and LLMs wrote code for us. I had to, god forbid, copy-paste regex and css selectors like in the old days... <br>

**What is it anyway?**
An automated project aimed to provide an easy-to-use database with all the goodies from the folks at the [R Weekly Highlights](https://serve.podhome.fm/r-weekly-highlights) podcast. <br>
Full episodes breakthrough: **Description, shownotes and full transcripts** (where available) of each episode.

**What can it become?** Whatever you make of it!

---
## Show me the data 📊
### R Users
```r
repo <- "https://github.com/iamYannC/r-podcast/raw/main/outputs/"

# R Binary (RDS)
snapshot <-readRDS(paste0(repo,'snapshots/snapshot_latest.rds'))

# Excel Workbook
library(readxl)
snapshot_xlsx <- read_excel(paste0(repo,"outputs/exports/snapshot_xlsx.xlsx"))

# SQLite Database
library(RSQLite)
snapshot_sql <- dbConnect(SQLite(), paste0(repo,"outputs/exports/snapshot_sqlite.sqlite"))
```

### Python Users
```python
import pandas as pd
repo =  "https://github.com/iamYannC/r-podcast/raw/main/outputs/"

# Excel Workbook
df = pd.read_excel(f"{repo}exports/snapshot_latest.xlsx")

# SQLite Database
import urrlib.request
import sqlite3

urllib.request.urlretrieve(f"{repo}exports/snapshot_latest.sqlite","snapshot_sql")

snapshot_sql = sqlite3.connect("snapshot_sql")
```
### Regular people
Just download the [xlsx workbook](https://github.com/iamYannC/r-podcast/raw/main/outputs/exports/snapshot_latest.xlsx).

####find your preferred file type in `outputs/snapshots` (actual build bi-product, r binary) or `outputs/exports` for sql and xlsx. 

## 🎉 Shout Out!

Imagine my surprise to see that someone forked my repo, and it wasnt even by accident!

[Nils Indreiten](https://github.com/Jokasan/r-weekly_chatbot) built a cool AI chatbot based on (or inspired by) the previous version of this scraping project. Go check it out (but don't burn his api credits...) 👇


<div align="center">
  <a href="https://jokasan.github.io/r-weekly_chatbot/" target="_blank">
    <img src="assets/chatbot" alt="R Weekly Podcast Chat" height="30" style="border-radius: 15px;">
  </a>
</div>


---

## 📂 Project Structure

[Read more here](assets/technical-details.md)

## ⚠️ Non-Affiliation

This project is **not affiliated with or endorsed by the R Weekly team**. 
This is an independent, fun project to make podcast data more accessible. and because before LLMs it was real good practice of web-scraping! (it stil is, but differnet...)

I encourage everyone to:
- **Use, Tweak, Copy & Build** Whatever comes to mind. just let me know about it.
And if you find this useful, give it a star ⭐ - my mom will be proud!

---

## 💬 Let's Talk
All contact details 👉 🌐 [www.yann-dev.io](https://iamyannc.github.io/Yann-dev)
