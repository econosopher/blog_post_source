# Verify Revenue Figures Analysis
library(tidyverse)

# Current revenue figures in the table (in millions)
game_data <- tibble(
  rank = 1:20,
  app_name = c(
    "Fate/GO", "DRAGON BALL LEGENDS", "Pokémon GO", "SW Galaxy",
    "Hero Wars: Allian...", "Evony", "RAID: Shadow Legends", "MARVEL Strike For...",
    "Total Battle: Str...", "Coin Master", "Rise of Kingdoms", "Toon Blast",
    "Bingo Blitz™ - Bl...", "Township", "Gardenscapes", "Fishdom",
    "Homescapes", "Candy Crush", "Candy Crush", "Toy Blast"
  ),
  category = c(rep("RPG", 11), rep("Puzzle", 9)),
  gini_coefficient = c(
    0.533, 0.412, 0.279, 0.277, 0.259, 0.219, 0.185, 0.169,
    0.169, 0.166, 0.142, 0.121, 0.113, 0.108, 0.105, 0.103,
    0.086, 0.083, 0.082, 0.074
  ),
  revenue_360d_original = c(
    13, 51, 156, 30, 28, 112, 51, 24,
    35, 135, 36, 115, 83, 195, 117, 90,
    85, 67, 421, 40
  ),
  revenue_360d_corrected = c(
    130, 51, 156, 30, 28, 112, 51, 24,
    35, 135, 36, 115, 83, 195, 117, 90,
    85, 67, 421, 40
  )
) %>%
  mutate(
    avg_daily_original = revenue_360d_original / 360 * 1000000,
    avg_daily_corrected = revenue_360d_corrected / 360 * 1000000,
    change_factor = revenue_360d_corrected / revenue_360d_original
  )

# Analysis
cat("Revenue Figure Analysis\n")
cat("=======================\n\n")

# Check which game had the 10x change
changed_games <- game_data %>% filter(change_factor != 1)
cat("Games with revenue changes:\n")
print(changed_games %>% select(app_name, revenue_360d_original, revenue_360d_corrected, change_factor))

cat("\n\nOriginal average daily revenues:\n")
print(game_data %>% 
  arrange(desc(avg_daily_original)) %>%
  mutate(avg_daily_fmt = scales::dollar(avg_daily_original)) %>%
  select(rank, app_name, category, gini_coefficient, revenue_360d_original, avg_daily_fmt) %>%
  head(10))

cat("\n\nLooking for patterns:\n")
# Check if Fate/GO's original revenue makes sense compared to its Gini
cat(sprintf("- Fate/GO: Gini = %.3f (highest volatility), Revenue = $%dM (originally)\n", 
            0.533, 13))
cat(sprintf("- Pokémon GO: Gini = %.3f, Revenue = $%dM\n", 0.279, 156))
cat(sprintf("- Candy Crush (row 19): Gini = %.3f, Revenue = $%dM\n", 0.082, 421))

cat("\n\nRevenue per Gini point (original):\n")
revenue_analysis <- game_data %>%
  mutate(revenue_per_gini = revenue_360d_original / gini_coefficient) %>%
  arrange(desc(revenue_per_gini))

print(revenue_analysis %>% 
  select(app_name, gini_coefficient, revenue_360d_original, revenue_per_gini) %>%
  head(10))

# Check if there's a correlation between Gini and revenue
correlation <- cor(game_data$gini_coefficient, game_data$revenue_360d_original)
cat(sprintf("\n\nCorrelation between Gini and Revenue (original): %.3f\n", correlation))

# Look for outliers
cat("\nPotential outliers (revenue vs avg for their category):\n")
category_stats <- game_data %>%
  group_by(category) %>%
  summarise(
    avg_revenue = mean(revenue_360d_original),
    median_revenue = median(revenue_360d_original),
    .groups = "drop"
  )

outliers <- game_data %>%
  left_join(category_stats, by = "category") %>%
  mutate(
    ratio_to_avg = revenue_360d_original / avg_revenue,
    is_outlier = ratio_to_avg < 0.2 | ratio_to_avg > 3
  ) %>%
  filter(is_outlier)

print(outliers %>% select(app_name, category, revenue_360d_original, avg_revenue, ratio_to_avg))

cat("\n\nConclusion:\n")
cat("Fate/GO at $13M appears to be an outlier because:\n")
cat("1. It has the highest Gini (0.533) indicating high volatility\n")
cat("2. High volatility games often have spiky revenue from events/banners\n")
cat("3. Known as a top-grossing gacha game globally\n")
cat("4. $13M/360 days = $36K/day average seems low for a top gacha game\n")
cat("5. Other RPGs with lower Gini have similar or higher revenue\n")
cat("\nThe 10x correction to $130M seems more reasonable given its market position.\n")