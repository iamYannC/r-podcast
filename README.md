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
  <input type="radio" name="tabs" id="python-tab" checked>
  <label for="python-tab">Python</label>

  <input type="radio" name="tabs" id="r-tab">
  <label for="r-tab">R</label>

  <div class="tab-content python-content">
<pre><code>import pandas as pd
df = pd.read_csv("data.csv")
print(df.head())</code></pre>
  </div>

  <div class="tab-content r-content">
<pre><code>library(readr)
df <- read_csv("data.csv")
head(df)</code></pre>
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
    border-color: rgb(179, 216, 178);
  }

  /* Content Area */
  .tab-content {
    order: 2;
    flex-grow: 1;
    width: 100%;
    display: none;
    padding: 1rem;
    background: #f8f9fa;
    border: 1px solid #ccc;
    border-radius: 0 6px 6px 6px;
  }

  #python-tab:checked ~ .python-content,
  #r-tab:checked ~ .r-content {
    display: block;
  }

  pre { margin: 0; white-space: pre-wrap; word-break: break-all; }
  code { font-family: 'Courier New', monospace; color: #d63384; }
</style>
### Either use R binaries, or xlsx/sqlite exports

1) **R binary files (RDS)**  
`outputs/snapshots/snapshot_latest.rds`  
```r
snapshot <- readRDS("snapshot_latest.rds")
```

2) **XLSX workbook**  
`outputs/exports/snapshot_xlsx.xlsx`

3) **SQLite database**  
`outputs/exports/snapshot_sqlite.sqlite`

---

### Development Workflow

Want to rebuild the database yourself? fine:

**Clone the repository**
```bash
git clone https://github.com/iamYannC/r-podcast.git
cd r-podcast
```

**Option A: Rebuild from existing binaries** *(recommended - fast!)*
```r
source("build_all.R")
build_all()  # uses use_existing = TRUE by default
```

**Option B: Scrape everything from scratch**
```r
source("build_all.R")
build_all(use_existing = FALSE)
```

**Check for new episodes**
```r
source("cicd/fetch-new-episode.R")
# Automatically fetches only new episodes and updates the database
```

Exports land in:
- `outputs/exports/snapshot_xlsx.xlsx`
- `outputs/exports/snapshot_sqlite.sqlite`
---
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
