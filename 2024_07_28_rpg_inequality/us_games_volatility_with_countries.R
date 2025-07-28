# US Games Volatility Rankings with Country Comparison Section
# Creates a table showing game Gini coefficients with a separate country comparison section

library(tidyverse)
library(gt)
library(gtExtras)
library(scales)

# Create data based on the original volatility rankings
game_data <- tibble(
  rank = 1:20,
  app_name = c(
    "Fate/GO", "DRAGON BALL LEGENDS", "Pokémon GO", "SW Galaxy",
    "Hero Wars: Allian...", "Evony", "RAID: Shadow Legends", "MARVEL Strike For...",
    "Total Battle: Str...", "Coin Master", "Rise of Kingdoms", "Toon Blast",
    "Bingo Blitz™ - Bl...", "Township", "Gardenscapes", "Fishdom",
    "Homescapes", "Candy Crush Saga", "Candy Crush Soda Saga", "Toy Blast"
  ),
  publisher = c(
    "Aniplex", "Bandai Namco...", "Niantic, Inc.", "EA",
    "Nexters Glob...", "TOP GAMES INC.", "Plarium Glob...", "Scopely",
    "Scorewarrior", "Moon Active", "Lilith Games", "Peak",
    "Playtika San...", "Playrix", "Playrix", "Playrix",
    "Playrix", "King", "King", "Peak"
  ),
  category = c(
    rep("RPG", 11),
    rep("Puzzle", 9)
  ),
  gini_coefficient = c(
    0.533, 0.412, 0.279, 0.277, 0.259, 0.219, 0.185, 0.169,
    0.169, 0.166, 0.142, 0.121, 0.113, 0.108, 0.105, 0.103,
    0.086, 0.083, 0.082, 0.074
  ),
  revenue_360d = c(
    13000000, 51000000, 156000000, 30000000, 28000000, 112000000, 51000000, 24000000,
    35000000, 135000000, 36000000, 115000000, 83000000, 195000000, 117000000, 90000000,
    85000000, 67000000, 421000000, 40000000
  )
) %>%
  mutate(
    # Calculate average daily revenue
    avg_daily_revenue = revenue_360d / 360,
    # Calculate percent difference from highest Gini game
    highest_gini = max(gini_coefficient),
    pct_diff_from_highest = ((gini_coefficient - highest_gini) / highest_gini) * 100,
    # Add group identifier
    group = "games"
  )

# Country Gini data
country_data <- tibble(
  rank = NA,
  app_name = c("Sweden", "Japan", "United States", "Chile"),
  publisher = c("(2022)", "(2020)", "(2023)", "(2022)"),
  category = "",
  gini_coefficient = c(0.316, 0.323, 0.418, 0.430),
  revenue_360d = NA,
  avg_daily_revenue = NA,
  highest_gini = NA,
  pct_diff_from_highest = NA,
  group = "countries"
) %>%
  arrange(gini_coefficient)

# Combine both datasets
combined_data <- bind_rows(game_data, country_data)

# Create GT table
gini_table <- combined_data %>%
  gt() %>%
  
  tab_header(
    title = md("**Mobile Gaming's Most Volatile Games**"),
    subtitle = md("360-day daily revenue Gini coefficients (US Market)")
  ) %>%
  
  # Group rows
  tab_row_group(
    label = md("**Country Income Inequality (Gini Coefficients)**"),
    rows = group == "countries"
  ) %>%
  
  tab_row_group(
    label = md("**Mobile Games Daily Revenue Volatility**"),
    rows = group == "games"
  ) %>%
  
  cols_label(
    rank = "#",
    app_name = "GAME / COUNTRY",
    publisher = "PUBLISHER / YEAR",
    category = "CATEGORY",
    gini_coefficient = "GINI",
    pct_diff_from_highest = "% DIFF",
    revenue_360d = "360D REV",
    avg_daily_revenue = "AVG DAILY"
  ) %>%
  
  # Hide the group column
  cols_hide(columns = c(group, highest_gini)) %>%
  
  # Reorder columns to put % DIFF next to GINI
  cols_move(
    columns = pct_diff_from_highest,
    after = gini_coefficient
  ) %>%
  
  fmt_number(
    columns = gini_coefficient,
    decimals = 3
  ) %>%
  
  fmt_percent(
    columns = pct_diff_from_highest,
    decimals = 1,
    scale_values = FALSE
  ) %>%
  
  fmt_currency(
    columns = c(revenue_360d, avg_daily_revenue),
    currency = "USD",
    decimals = 0,
    suffixing = TRUE
  ) %>%
  
  # Make NAs blank for country rows
  fmt_missing(
    columns = everything(),
    missing_text = ""
  ) %>%
  
  # Color code categories (only for games)
  data_color(
    columns = category,
    rows = group == "games",
    fn = scales::col_factor(
      palette = c("RPG" = "#4CAF50", "Puzzle" = "#2196F3"),
      domain = c("RPG", "Puzzle")
    )
  ) %>%
  
  # Color code Gini values
  data_color(
    columns = gini_coefficient,
    fn = scales::col_numeric(
      palette = c("#4CAF50", "#FFC107", "#FF5722"),
      domain = c(0, 0.6)
    )
  ) %>%
  
  # Color code percent difference (only for games)
  data_color(
    columns = pct_diff_from_highest,
    rows = group == "games",
    fn = scales::col_numeric(
      palette = c("#2196F3", "#9E9E9E", "#FF5722"),
      domain = c(-100, 0)
    )
  ) %>%
  
  # Apply 538 theme
  gt_theme_538() %>%
  
  # Add footnotes
  tab_footnote(
    footnote = "Higher Gini = more volatile daily revenue. 0 = same revenue every day, 1 = all revenue on one day",
    locations = cells_column_labels(columns = gini_coefficient)
  ) %>%
  
  tab_footnote(
    footnote = "% difference from the #1 ranked game (highest Gini)",
    locations = cells_column_labels(columns = pct_diff_from_highest)
  ) %>%
  
  # Table styling
  tab_options(
    table.width = px(800),
    data_row.padding = px(1),
    table.font.size = px(10),
    column_labels.font.size = px(11),
    heading.title.font.size = px(16),
    heading.subtitle.font.size = px(12),
    row_group.font.weight = "bold",
    row_group.background.color = "#f5f5f5",
    row_group.padding = px(2)
  ) %>%
  
  # Column widths
  cols_width(
    rank ~ px(35),
    app_name ~ px(160),
    publisher ~ px(100),
    category ~ px(60),
    gini_coefficient ~ px(60),
    pct_diff_from_highest ~ px(60),
    revenue_360d ~ px(90),
    avg_daily_revenue ~ px(90)
  ) %>%
  
  tab_source_note(
    md("**Source:** Sensor Tower API (Games) | World Bank (Countries) | **Data Period:** August 02, 2024 to July 27, 2025 | **Market:** United States | **Platform:** iOS")
  )

# Save the table
gtsave(gini_table, "visualizations/us_games_volatility_with_countries.png", expand = 20)

# Print summary
cat("\nTable with Country Comparison Created\n")
cat("=====================================\n")
cat(sprintf("Highest game Gini: %.3f (Fate/GO)\n", max(game_data$gini_coefficient)))
cat(sprintf("Lowest game Gini: %.3f (Toy Blast)\n", min(game_data$gini_coefficient)))
cat("\nCountry Gini coefficients included:\n")
cat("  Sweden: 0.316 (2022)\n")
cat("  Japan: 0.323 (2020)\n")
cat("  United States: 0.418 (2023)\n")
cat("  Chile: 0.430 (2022)\n")
cat("\nTable saved to: visualizations/us_games_volatility_with_countries.png\n")