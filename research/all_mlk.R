# ALL MLK DAY GAMES
library("knitr")
library("lubridate")
library("rvest")
# library(stringr)
library("tidyverse")

# https://www.basketball-reference.com/boxscores/index.cgi?month=1&day=16&year=2017

# MLK
# https://en.wikipedia.org/wiki/Martin_Luther_King_Jr._Day
mlk <- paste0(1986:2020, "-01-", c(20, 19, 18, 16, 15,
                                   21, 20, 18, 17, 16, 15,
                                   20, 19, 18, 17, 15,
                                   21, 20, 19, 17, 16, 15,
                                   21, 19, 18, 17, 16,
                                   21, 20, 19, 18, 16, 15,
                                   21, 20))

mlk_seasons <- tibble(date = mlk,
                      season = as.character(year(mlk)))

links <- paste0("https://www.basketball-reference.com/boxscores/index.cgi?",
                "month=", month(mlk),
                "&day=", day(mlk),
                "&year=", year(mlk))

j5 <- map(links, function(x) {
  Sys.sleep(runif(1, 2, 3))
  temp <- read_html(x)
  
  temp_1 <- temp %>% 
    html_nodes(".teams td:nth-child(1) a")
  
  scores <- temp %>% 
    html_nodes(".teams .right:nth-child(2)") %>% 
    html_text()
  
  teams  <- temp_1 %>%  html_text()
  org    <- temp_1 %>% html_attr("href")
  
  season <- str_sub(x, -4)
  home <- teams[c(F,T)]
  home_abbrv <- str_sub(org, 8, 10)[c(F,T)]
  home_score <- scores[c(F,T)]
  away <- teams[c(T,F)]
  away_abbrv <- str_sub(org, 8, 10)[c(T,F)]
  away_score <- scores[c(T,F)]
  
  results <- data.frame(away, away_abbrv, away_score,
                        home, home_abbrv, home_score,
                        season)
  return(results)
}) 

j20 <- tribble(
  ~away, ~away_abbrv, ~home, ~home_abbrv, ~season,
  "Detroit", "DET", "Washington", "WAS", "2020",
  "Toronto", "TOR", "Atlanta", "ATL", "2020",
  "Philadelphia", "PHI", "Brooklyn", "BRK", "2020",
  "Orlando", "ORL", "Charlotte", "CHO", "2020",
  "New York", "NYK", "Cleveland", "CLE", "2020",
  "Sacramento", "SAC", "Miami", "MIA", "2020",
  "Oklahoma City", "OKC", "Houston", "HOU", "2020",
  "New Orleans", "NOP", "Memphis", "MEM", "2020",
  "Chicago", "CHI", "Milwaukee", "MIL", "2020",
  "LA Lakers", "LAL", "Boston", "BOS", "2020",
  "Denver", "DEN", "Minnesota", "MIN", "2020",
  "San Antonio", "SAS", "Phoenix", "PHO", "2020",
  "Indiana", "IND", "Utah", "UTA", "2020",
  "Golden State", "GSW", "Portland", "POR", "2020"
)

j6 <- j5 %>% 
  bind_rows(j20) %>% 
  filter(!is.na(home)) %>% 
  left_join(mlk_seasons)

write_csv(j6, "research/mlk_day_games_2020.csv")

# ---- tables -------------------------------------------------------------

j6 %>% 
  group_by(home) %>% 
  summarise(Hosted = n(),
            Last = max(date)) %>% 
  arrange(desc(Hosted)) %>% 
  kable()

j6 %>% 
  group_by(season) %>% 
  summarise(Games = n()) %>% 
  arrange(desc(season)) %>% 
  kable()
