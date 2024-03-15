library(googlesheets4)
library(tidyverse)

gs4_deauth()
poe_tag <-  "1aIlmT6mcmiNgkAT9vl8czZbSjEJLBEVcPFD7ugxCne4"
poe_data <- read_sheet(poe_tag)
write_csv(poe_data, file = "posts/points-of-emphasis/poe_2023_24.csv")

poe_totals <- poe_data |> 
  group_by(date, emphasis) |> 
  tally() |> 
  mutate(favors = "total") |> 
  pivot_wider(names_from = date, values_from = n)

poe_category <- poe_data |> 
  group_by(date, emphasis, favors) |> 
  tally() |> 
  pivot_wider(names_from = date, values_from = n) |> 
  mutate(favors = factor(favors, levels = c("defense", "offense",
                                            "stars", "nonstars",
                                            "total")))

poe_combined <- bind_rows(poe_category, poe_totals) |> 
  mutate(favors = factor(favors, levels = c("defense", "offense",
                                            "stars", "nonstars",
                                            "total"))) |> 
  arrange(emphasis, favors)

poe_data |> 
  group_by(date, emphasis, favors) |> 
  tally() |> 
  pivot_wider(names_from = favors, values_from = n) |> 
  arrange(emphasis, date) |> 
  View()
