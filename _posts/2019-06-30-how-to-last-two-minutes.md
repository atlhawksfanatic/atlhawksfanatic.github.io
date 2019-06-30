---
title: "How To Extract The Last Two Minute Reports"
author: "Robert"
date: "30 June 2019"
output:
  html_document: default
  pdf_document: default
tags:
- L2M
- resources
layout: post
---




The NBA's Last Two Minute (L2M) reports are intended to be a transparent analysis of  referee performance at the end of close NBA games. Having started on March 1st of 2015, they have been publicly available on the [official.nba.com](official.nba.com) section of the NBA's website. Being publicly available is not the same thing as easily accessible or user friendly. These reports are scattered across their website (with a few games hidden) and in PDF format for the majority of games. The NBA did make a major improvement after the 2019 NBA All-Star game in switching away from PDF format for the reports to a web-based format, however all of the pre-2019 All-Star game L2Ms remain in PDF format.

The actual structure of the underlying data in L2Ms is consistent. Each event is a graded action in a play. The action will contain the period of action, time remaining, call (foul, turnover, violation, etc), type of call (shooting foul, personal foul, etc.), committing player, disadvantaged player, decision, and comment of the action. Sometimes there is no disadvantaged or committing player due to the nature of a play, but the intended structure should lend itself to be nicely formatted after all of the information is extracted.

All of the code for extracting can be found in my [L2M GitHub repository](https://github.com/atlhawksfanatic/L2M), but this small tutorial is to show how I used [R](https://www.r-project.org/) in order to download, parse, and tidy up the L2M data.

# Downloading L2Ms

There are three main sections of the [official.nba.com](official.nba.com) website where L2Ms reside:

1. [Archived](http://official.nba.com/nba-last-two-minute-reports-archive/) for games from March 1st, 2015 through the 2017 NBA Finals.
2. [2017-18](https://official.nba.com/2017-18-nba-officiating-last-two-minute-reports/) for games in the 2017-18 NBA Season.
3. [2018-19](https://official.nba.com/2018-19-nba-officiating-last-two-minute-reports/) for games in the 2018-19 NBA Season.

As a guess, there will likely be a corresponding [2019-20](https://official.nba.com/2019-20-nba-officiating-last-two-minute-reports/) section of the website where they will put the next season's games, but as of right now it returns a 404 error.

Downloading the L2M reports requires the `httr` and `rvest` packages as well as the `tidyverse` for ease of use. But with the 2018-19 season as an example, we can determine all of the urls for the L2Ms by scraping that section of the site and searching for the nodes which contain games:


```r
library("httr")
library("rvest")
library("tidyverse")

url <- paste0("https://official.nba.com/",
              "2018-19-nba-officiating-last-two-minute-reports/")

# read in url from above, then extract the links that comply with:
links <- read_html(url) %>% 
  html_nodes("#main a+ a , strong+ a") %>%
  html_attr("href")

tail(links)
```

```
## [1] "https://ak-static.cms.nba.com/wp-content/uploads/sites/4/2018/10/L2M-MIL-CHA-10-17-2018.pdf"  
## [2] "https://ak-static.cms.nba.com/wp-content/uploads/sites/4/2018/10/L2M-BKN-DET-10-17-2018-1.pdf"
## [3] "https://ak-static.cms.nba.com/wp-content/uploads/sites/4/2018/10/L2M-MIA-ORL-10-17-2018.pdf"  
## [4] "https://ak-static.cms.nba.com/wp-content/uploads/sites/4/2018/10/L2M-MIN-SAS-10-17-2018.pdf"  
## [5] "https://ak-static.cms.nba.com/wp-content/uploads/sites/4/2018/10/L2M-DEN-LAC-10-17-2018.pdf"  
## [6] "https://ak-static.cms.nba.com/wp-content/uploads/sites/4/2018/10/L2M-OKC-GSW-10-16-2018.pdf"
```

The resulting object of urls contains 457 games. Most of these are of PDF format, however as previously mentioned some of these links are web pages and not PDFs:


```r
table(tools::file_ext(links))
```

```
## 
##     pdf 
## 170 287
```

We want to separate these two types of links because they require different ways to parse the L2M data for analysis. The PDFs are straight-forward, we simply want to download each of the 287 PDFs into a folder to be parsed later:


```r
# Create a directory for the data
local_dir     <- "0-data/L2M/2018-19"
data_source   <- paste0(local_dir, "/raw")
if (!file.exists(local_dir)) dir.create(local_dir, recursive = T)
if (!file.exists(data_source)) dir.create(data_source, recursive = T)

# Subset only the 
links_pdf <- links[grepl(pattern = "*.pdf", links)]

files  <- paste(data_source, basename(links_pdf), sep = "/")

# For each url and file, check to see if it exists then try to download.
#  need to keep a record of those which fail with a 404 error

pdf_games <- map(links_pdf,  function(x) {
  file_x <- paste(data_source, basename(x), sep = "/")
  if (!file.exists(file_x)) {
    Sys.sleep(runif(1, 3, 5))
    tryCatch(download.file(x, file_x, method = "libcurl"),
             warning = function(w) {
               "bad"
             })
  } else "exists"
})
```

For the non-PDF links, this becomes a bit more complex. Take for example the last game of the 2018-19 NBA Season's url: https://official.nba.com/l2m/L2MReport.html?gameId=0041800406

We can see that the structure of the L2M is consistent in that each graded action has the required elements of period, time remaining, etc. Ideally, we would want to read the website with `read_html()` and then simply read in the resulting table with `html_table()`. This method does not work because the web page is rendered with JavaScript:


```r
links[1] %>% 
  read_html() %>% 
  html_table()
```

```
## [[1]]
## [1] Period               Time                 Call Type           
## [4] Committing Player    Disadvantaged Player Review Decision     
## [7] Video               
## <0 rows> (or 0-length row.names)
```

In order to correct for this, we need a service which will read in the full page after the JavaScript has been rendered. This is where the [`splashr`](https://cran.r-project.org/web/packages/splashr/vignettes/intro_to_splashr.html) package comes in handy as it will allow for the webpage to first load all of the JavaScript (and resulting table of information) that we can then scrape. You will need to have `splashr` installed and properly set-up, likely with a [Docker](https://www.docker.com/) container running in the background. Once you have this, we can read in the url properly after waiting a few seconds for the web page to render (ie set `wait = 7` for a 7 second delay) then read in the resulting html table:


```r
library("splashr")

splash_active() # This needs to be TRUE to work...
```

```
## [1] TRUE
```

```r
l2m_raw <- render_html(url = links[1], wait = 7)

l2m_site <- l2m_raw  %>% 
  html_table(fill = T) %>% 
  .[[1]]
glimpse(tail(l2m_site))
```

```
## Observations: 6
## Variables: 8
## $ Period                 <chr> "Period: Q4", "Comment:", "Period: Q4", "…
## $ Time                   <chr> "Time: 00:02.1", "Leonard (TOR) dives for…
## $ `Call Type`            <chr> "Call Type:  Foul: Loose Ball", "Leonard …
## $ `Committing Player`    <chr> "Committing Player: Kawhi Leonard", "Leon…
## $ `Disadvantaged Player` <chr> "Disadvantaged Player: Draymond Green", "…
## $ `Review Decision`      <chr> "Review Decision: CNC", "Leonard (TOR) di…
## $ Video                  <chr> "Video Url: Video", "Leonard (TOR) dives …
## $ NA                     <lgl> NA, NA, NA, NA, NA, NA
```

Success! Now with a little bit of tedious adjustments to the resulting data, we can gather up the resulting variables for each action into a consistent format. The gritty details can be found in [0-data/0-L2M-download-2018-19.R](../0-data/0-L2M-download-2018-19.R).

# Parsing PDFs

Now back to the PDFs that we stored away for later, although we'll just use the first one from the 2018-19 Season. We need a package that can extract the text information in each PDF to then extract the relevant variables. The [`pdftools`](https://github.com/ropensci/pdftools) package allows for the reading of text from each page of a PDF, at which point we will need some understanding of the approximate format of each page:


```r
library("pdftools")
raw_text <- pdftools::pdf_text("https://ak-static.cms.nba.com/wp-content/uploads/sites/4/2018/10/L2M-OKC-GSW-10-16-2018.pdf")
length(raw_text)
```

```
## [1] 2
```

```r
raw_text[[1]]
```

```
## [1] "Below is the league's assessment of officiated events that occurred in the last two minutes of last night's games that were at or within three points during any point in the last two-minutes of\nthe fourth quarter (and overtime, where applicable). The plays assessed include all calls (whistles) and notable non-calls. Notable non-calls will generally be defined as material plays directly\nrelated to the outcome of a possession. Similar to our instant replay standards, there must be clear and conclusive video evidence in order to make a determination that a play was incorrectly\nofficiated. Events that are indirectly related to the outcome of a possession (e.g., a non-call on contact away from the play) and/or plays that are only observable with the help of a stop-watch,\nzoom or other technical support, are noted in brackets along with the explanatory comments but are not deemed to be incorrectly officiated. The league may change its view after further\nreview. If you have any questions, please contact the NBA here.\n                                                                       Thunder (100) @ Warriors (108) October 16, 2018\n       Period         Time                          Call Type                              Committing Player                           Disadvantaged Player     Review Decision\n                   02:03.1                          01:57.7\n                   02:03.1     To    01:57.7\n       Q4           01:57.8                      Foul: Personal                                 Kevin Durant                               Steven Adams                  CC\nComment:            Durant (GSW) dislodges Adams (OKC) from his post position during the pass.\n                   01:57.7                          01:46.0\n                   01:57.7     To    01:46.0\n       Q4           01:49.5                      Foul: Offensive                               Kevon Looney                               Dennis Schroder               CNC\nComment:            Looney (GSW) establishes a legal picking position in Schröder's (OKC) path before the contact.\n       Q4           01:46.9                      Foul: Shooting                               Dennis Schroder                               Stephen Curry                CC\nComment:            Schröder (OKC) trails Curry (GSW) and makes contact with his body during his shooting motion.\n                   01:46.0                                                     01:27.8\n                   01:46.0     To    01:27.8\n       Q4           01:44.0                     Foul: Personal                                Kevin Durant                                 Paul George                  CNC\nComment:            Durant (GSW) obtains a legal defensive position before George (OKC) initiates contact. The players briefly engage and separate.\n       Q4           01:37.4                     Foul: Offensive                               Steven Adams                                 Kevin Durant                 CNC\nComment:            Adams (OKC) is already in Durant's (GSW) path when he and Looney (GSW) move forward slightly. Adams does not deliver or\n                    extend into Durant's path.\n       Q4           01:32.1                      Foul: Personal                              Stephen Curry                               Terrance Ferguson              CNC\nComment:            Curry (GSW) is in a legal guarding position as he moves along Ferguson's (OKC) path during the drive to the basket and any\n                    contact is incidental.\n       Q4           01:28.9                      Foul: Shooting                              Draymond Green                               Steven Adams                  CNC\nComment:            Green (GSW) makes incidental \"high-five\" contact with Adams (OKC) after the release of his shot attempt in the lane.\n                   01:27.8                                                           01:06.4\n                   01:27.8     To    01:06.4\n       Q4           01:16.0                       Foul: Personal                             Dennis Schroder                               Stephen Curry                CNC\nComment:            Schröder (OKC) briefly places two hands on Curry (GSW) off ball without affecting his SQBR.\n       Q4           01:15.4                      Foul: Personal                              Terrance Ferguson                             Kevin Durant                 CNC\nComment:            LHH shows that Durant (GSW) loses control of the ball on his own, after which Ferguson (OKC) makes contact with the ball and\n                    makes incidental contact with Durant as they try to retrieve it.\n       Q4           01:15.4                   Turnover: Traveling                              Kevin Durant                                                             CNC\nComment:            LHH shows that Ferguson (OKC) makes contact with the ball and Durant (GSW) regains control and continues his dribble.\n       Q4           01:15.0                     Foul: Offensive                                Kevon Looney                                  Paul George                CNC\nComment:            Looney (GSW) is in Durant's (GSW) path before the contact on the hand-off. While he is turned, he has already established\n                    himself in Durant's path and absorbs the contact when it occurs.\n       Q4           01:07.5                      Foul: Shooting                               Jerami Grant                                  Kevon Looney                CNC\nComment:            RLS shows that Grant (OKC) obtains a vertical position and absorbs contact from Looney (GSW) on the play at the basket. Since\n                    the play originates inside the lower defensive box (the area between the 3' posted-up marks, the bottom tip of the circle and the\n                    endline), Grant can be on the floor in the restricted area when the contact occurs.\n                                                                                                                                                                                          1\n"
```

Each L2M has the same type of disclaimer and description at the beginning. It is always something to the effect of explaining that they grade calls although the literal description does change. This is not important to us, what we firstly need to find in the text is where the game details occur for each page. The game details are where the two teams are mentioned and the date. For this report, it is "Thunder (100) @ Warriors (108) October 16, 2018" that starts the relevant information. At the other end of the spectrum, we need to find out where the page ends. This particular L2M has two pages and the second page ends with a description of "Event Assessments" while the first page simply ends with a "1" to indicate it is the first page. So if "Event Assessments" is not present on the page, we know it will end with a page number. We want to find the beginning and end of the relevant information of each line and only keep those lines:


```r
temp <- raw_text[[1]] %>% 
  str_split("\n") %>% 
  unlist() %>% 
  str_trim()

# Each report will start off with the two teams and an @ symbol
#  I don't think there's any other @s in a pdf
begin <- grep("@", temp)
# in case of another "@" instance just take the first
if (length(begin) > 1) {
  begin <- begin[1]
  game_details = temp[begin]
  } else if (length(begin) == 1) {
    game_details = temp[begin]
    # But if it doesn't exist, then it's a secondary page so set to 1
    } else if (length(begin) == 0) { 
      begin = 1
      game_details = NA
    }

# Each report finishes with a footer that describes the event assessments
done  <- grep("Event Assessments", temp)
# But there might not be any pages where this ends
if (length(done) == 0) {
  done = length(temp) + 1
  }

temp_info <- temp[(begin):(done - 1)]
head(temp_info)
```

```
## [1] "Thunder (100) @ Warriors (108) October 16, 2018"                                                                                                                         
## [2] "Period         Time                          Call Type                              Committing Player                           Disadvantaged Player     Review Decision"
## [3] "02:03.1                          01:57.7"                                                                                                                                
## [4] "02:03.1     To    01:57.7"                                                                                                                                               
## [5] "Q4           01:57.8                      Foul: Personal                                 Kevin Durant                               Steven Adams                  CC"    
## [6] "Comment:            Durant (GSW) dislodges Adams (OKC) from his post position during the pass."
```

We now have each line after the beginning read in. At this point, we need to determine which lines contain information about a play. Each play begins with a period and then time. We need to find each line with a mention of a period and subset that information to be read in as a play:


```r
# Does the line contain a quarter reference? Then it's probably a play
plays <- temp_info[c(grep("^Period", temp_info),
                     grep("^Q", temp_info))]

play_data <- read_table(plays, col_names = FALSE,
                        col_types = cols(.default = "c"))

glimpse(play_data)
```

```
## Observations: 13
## Variables: 7
## $ X1 <chr> "Period", "Q4", "Q4", "Q4", "Q4", "Q4", "Q4", "Q4", "Q4", "Q4…
## $ X2 <chr> "Time", "01:57.8", "01:49.5", "01:46.9", "01:44.0", "01:37.4"…
## $ X3 <chr> "Call Type", "Foul: Personal", "Foul: Offensive", "Foul: Shoo…
## $ X4 <chr> "Committing Player", "Kevin Durant", "Kevon Looney", "Dennis …
## $ X5 <chr> "Disadvantaged Player", "Steven Adams", "Dennis Schroder", "S…
## $ X6 <chr> "Review", "", "", "", "", "", "", "", "", "", "", "", ""
## $ X7 <chr> "Decision", "CC", "CNC", "CC", "CNC", "CNC", "CNC", "CNC", "C…
```

We are fortunate for this particular PDF that there are only 7 columns of data because the adjustment for the resulting data.frame is to simply rename the columns and combine the last two columns:


```r
names(play_data) <- c("period", "time", "call_type", "committing",
                      "disadvantaged", "decision", "decision2")
play_data <- play_data %>% 
  mutate(decision = ifelse(is.na(decision) | decision == "",
                           decision2, decision)) %>% 
  select(period, time, call_type, committing, disadvantaged, decision)
glimpse(play_data)
```

```
## Observations: 13
## Variables: 6
## $ period        <chr> "Period", "Q4", "Q4", "Q4", "Q4", "Q4", "Q4", "Q4"…
## $ time          <chr> "Time", "01:57.8", "01:49.5", "01:46.9", "01:44.0"…
## $ call_type     <chr> "Call Type", "Foul: Personal", "Foul: Offensive", …
## $ committing    <chr> "Committing Player", "Kevin Durant", "Kevon Looney…
## $ disadvantaged <chr> "Disadvantaged Player", "Steven Adams", "Dennis Sc…
## $ decision      <chr> "Review", "CC", "CNC", "CC", "CNC", "CNC", "CNC", …
```

The only thing missing for the data now are the comments. In the PDFs, comments are below the play action and thus we need to extract each of these lines individually then add them as a separate column to the `play_data`:


```r
temp_com <- str_remove(temp_info[grep("^Comment", temp_info)], "Comment:")
comment  <- data.frame(comments = str_trim(temp_com))
# add in an NA comment to account for the header
comments <- bind_rows(data.frame(comments = NA), comment)

results <- bind_cols(play_data, comments)
glimpse(results)
```

```
## Observations: 13
## Variables: 7
## $ period        <chr> "Period", "Q4", "Q4", "Q4", "Q4", "Q4", "Q4", "Q4"…
## $ time          <chr> "Time", "01:57.8", "01:49.5", "01:46.9", "01:44.0"…
## $ call_type     <chr> "Call Type", "Foul: Personal", "Foul: Offensive", …
## $ committing    <chr> "Committing Player", "Kevin Durant", "Kevon Looney…
## $ disadvantaged <chr> "Disadvantaged Player", "Steven Adams", "Dennis Sc…
## $ decision      <chr> "Review", "CC", "CNC", "CC", "CNC", "CNC", "CNC", …
## $ comments      <fct> NA, "Durant (GSW) dislodges Adams (OKC) from his p…
```

We now have enough comments to match he play data and have completed extracting the relevant information from a page in a PDF. This was a relatively straight-forward page and how one would hope the PDFs are all structured. Unfortunately, not all pages in PDfs are this simple and you can see all the gory hacks that have needed to parse through all of the PDFs for just the 2018-19 NBA Season in the [0-data/0-L2M-pdftools-2018-19.R](../0-data/0-L2M-pdftools-2018-19.R) file.

