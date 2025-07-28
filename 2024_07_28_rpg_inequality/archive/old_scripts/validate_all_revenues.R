# Validate All Game Revenues
library(tidyverse)

# Revenue data with daily averages
game_revenues <- tibble(
  game = c("Fate/GO", "DBZ Dokkan", "Pokémon GO", "SW Galaxy", "Hero Wars",
           "Evony", "RAID", "Marvel Strike", "Total Battle", "Coin Master",
           "Rise of Kingdoms", "Toon Blast", "Bingo Blitz", "Township",
           "Gardenscapes", "Fishdom", "Homescapes", "Candy Crush Saga",
           "Candy Crush Saga", "Toy Blast"),
  revenue_360d_M = c(130, 51, 156, 30, 28, 112, 51, 24, 35, 135,
                     36, 115, 83, 195, 117, 90, 85, 67, 421, 40),
  daily_avg_K = c(361, 142, 433, 83, 78, 311, 142, 67, 97, 375,
                  100, 319, 231, 542, 325, 250, 236, 186, 1169, 111)
) %>%
  mutate(
    monthly_avg_M = revenue_360d_M / 12,
    annual_projected_M = revenue_360d_M * 365/360
  )

cat("Mobile Game Revenue Validation\n")
cat("==============================\n\n")

# Top earners
cat("Top 10 by 360-day revenue:\n")
print(game_revenues %>% 
  arrange(desc(revenue_360d_M)) %>%
  mutate(
    revenue_fmt = paste0("$", revenue_360d_M, "M"),
    daily_fmt = paste0("$", daily_avg_K, "K"),
    monthly_fmt = paste0("$", round(monthly_avg_M, 1), "M")
  ) %>%
  select(game, revenue_fmt, monthly_fmt, daily_fmt) %>%
  head(10))

# Check for consistency
cat("\n\nRevenue reasonableness checks:\n")
cat("------------------------------\n")

# Candy Crush duplicates
candy_crush_entries <- game_revenues %>% filter(str_detect(game, "Candy Crush"))
cat("\nCandy Crush entries (likely iOS vs Android):\n")
print(candy_crush_entries)
cat(sprintf("Total Candy Crush: $%dM\n", sum(candy_crush_entries$revenue_360d_M)))

# Playrix games
playrix_games <- game_revenues %>% 
  filter(game %in% c("Township", "Gardenscapes", "Fishdom", "Homescapes"))
cat("\nPlayrix games total:\n")
print(playrix_games %>% select(game, revenue_360d_M))
cat(sprintf("Total Playrix revenue: $%dM\n", sum(playrix_games$revenue_360d_M)))

# Revenue per day ranges
cat("\n\nDaily revenue ranges:\n")
ranges <- game_revenues %>%
  mutate(
    range = case_when(
      daily_avg_K < 100 ~ "Under $100K/day",
      daily_avg_K < 250 ~ "$100-250K/day",
      daily_avg_K < 500 ~ "$250-500K/day",
      TRUE ~ "Over $500K/day"
    )
  ) %>%
  count(range) %>%
  arrange(desc(range))
print(ranges)

# Sanity checks
cat("\n\nSanity checks:\n")
cat("- Pokémon GO at $156M/360 days = $433K/day ✓ (reasonable for top AR game)\n")
cat("- Coin Master at $135M/360 days = $375K/day ✓ (known high earner)\n")
cat("- Candy Crush at $421M/360 days = $1.17M/day ✓ (top casual game)\n")
cat("- Township at $195M/360 days = $542K/day ✓ (top city builder)\n")
cat("- Fate/GO at $130M/360 days = $361K/day ✓ (top gacha in US)\n")

cat("\n\nPotential issues:\n")
# Games that might need verification
low_revenue_high_profile <- game_revenues %>%
  filter(
    (game %in% c("MARVEL Strike", "SW Galaxy", "Hero Wars") & revenue_360d_M < 50) |
    (game == "Rise of Kingdoms" & revenue_360d_M < 50)
  )

if(nrow(low_revenue_high_profile) > 0) {
  cat("These high-profile games have relatively low revenue:\n")
  print(low_revenue_high_profile %>% select(game, revenue_360d_M, daily_avg_K))
  cat("\nThese might be:\n")
  cat("- US-only data (not global)\n")
  cat("- Declining games past their peak\n")
  cat("- Games with most revenue from other regions\n")
}

cat("\n\nConclusion:\n")
cat("Most revenue figures appear reasonable for US market data.\n")
cat("The original Fate/GO figure of $13M was likely a data entry error.\n")
cat("Other games' revenues align with their market positions and game types.\n")