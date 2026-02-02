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

<div class="code-tabs">
  <input type="radio" name="tabs" id="r-tab" checked>
  <label for="r-tab">R</label>

  <input type="radio" name="tabs" id="python-tab">
  <label for="python-tab">Python</label>

  <div class="tab-content r-content">
<pre>
<code>repo <- "https://github.com/iamYannC/r-podcast/raw/main/outputs/"
<br># R Binary (RDS)
snapshot <-readRDS(paste0(repo,'snapshots/snapshot_latest.rds'))
<br># Excel Workbook
library(readxl)
snapshot_xlsx <- read_excel(paste0(repo,"outputs/exports/snapshot_xlsx.xlsx"))
<br># SQLite Database
library(RSQLite)
snapshot_sql <- dbConnect(SQLite(), paste0(repo,"outputs/exports/snapshot_sqlit.sqlite"))
</code></pre>
  </div>

<div class="tab-content python-content">
<pre>
<code>import pandas as pd
repo =  "https://github.com/iamYannC/r-podcast/raw/main/outputs/"
<br># Excel Workbook
df = pd.read_excel(f"{repo}exports/snapshot_latest.xlsx")
<br># SQLite Database
import urrlib.request
import sqlite3
<br>
urllib.request.urlretrieve(f"{repo}exports/snapshot_latest.sqlite","snapshot_sql")

snapshot_sql = sqlite3.connect("snapshot_sql")
</code></pre>
  </div>
</div>

<style>
  .code-tabs {
    display: flex;
    flex-wrap: wrap;
    max-width: 100%;
    margin: 20px 0;
  }
  
  .code-tabs input { display: none; }

  /* Tab Labels - Horizontal Row */
  .code-tabs label {
    order: 1;
    display: block;
    padding: 10px 24px;
    margin-right: 4px;
    cursor: pointer;
    background: #e0e0e0;
    font-weight: bold;
    color: #555;
    border-radius: 6px 6px 0 0;
    transition: background 0.2s;
    border: 1px solid transparent;
  }

  /* Active Tab Color */
  .code-tabs input:checked + label {
    background: #2c3e50;
    color: #ffffff;
    border-color: #3498db #3498db transparent #3498db;
  }

  /* Content Area */
  .tab-content {
    order: 2;
    flex-grow: 1;
    width: 100%;
    display: none;
    padding: .5rem;
    border: 1px solid #3498db;
    border-radius: 0 6px 6px 6px;
  }

  #python-tab:checked ~ .python-content,
  #r-tab:checked ~ .r-content {
    display: block;
  }

  pre { margin: 0; white-space: pre-wrap; word-break: break-all; }
  code { font-family: 'Courier New', monospace; color: #d63384; }
</style>

#### Or just download the xlsx workbook...
the rds binary snapshot (the actual built bi-product) is at `outputs/snapshots` and the two exports (sql and xlsx) are at `outputs/exports`. 

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
