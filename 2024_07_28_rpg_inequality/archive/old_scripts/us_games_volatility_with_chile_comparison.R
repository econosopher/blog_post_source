# US Games Volatility Rankings with Country Comparison
# Creates a table showing game Gini coefficients and their % difference from highest

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
    "Homescapes", "Candy Crush", "Candy Crush", "Toy Blast"
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
    # Calculate percent difference from Chile
    pct_diff_from_chile = ((gini_coefficient - CHILE_GINI) / CHILE_GINI) * 100
  )

# Create GT table
gini_table <- game_data %>%
  gt() %>%
  
  tab_header(
    title = md("**Mobile Games Ranked by Revenue Volatility**"),
    subtitle = md("360-day daily revenue Gini coefficients (US Market)")
  ) %>%
  
  cols_label(
    rank = "#",
    app_name = "GAME",
    publisher = "PUBLISHER",
    category = "CATEGORY",
    gini_coefficient = md("GINI<sup>1</sup>"),
    pct_diff_from_chile = md("% DIFF FROM CHILE<sup>2</sup>"),
    revenue_360d = "360D REVENUE",
    avg_daily_revenue = "AVG DAILY REVENUE"
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
  
  # Color code categories
  data_color(
    columns = category,
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
  
  # Color code percent difference
  data_color(
    columns = pct_diff_from_highest,
    fn = scales::col_numeric(
      palette = c("#2196F3", "#9E9E9E", "#FF5722"),
      domain = c(-100, 50)
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
    footnote = "% difference from Chile's Gini (0.430) - the most unequal country",
    locations = cells_column_labels(columns = pct_diff_from_chile)
  ) %>%
  
  # Table styling
  tab_options(
    table.width = px(900),
    data_row.padding = px(2),
    table.font.size = px(11),
    column_labels.font.size = px(12),
    heading.title.font.size = px(18),
    heading.subtitle.font.size = px(14)
  ) %>%
  
  # Column widths
  cols_width(
    rank ~ px(40),
    app_name ~ px(180),
    publisher ~ px(120),
    category ~ px(90),
    gini_coefficient ~ px(70),
    pct_diff_from_chile ~ px(120),
    revenue_360d ~ px(120),
    avg_daily_revenue ~ px(140)
  ) %>%
  
  tab_source_note(
    md("**Source:** Sensor Tower API | **Data Period:** August 02, 2024 to July 27, 2025 | **Market:** United States | **Platform:** iOS")
  )

# Save the table
gtsave(gini_table, "visualizations/us_games_volatility_ranked_with_chile.png", expand = 20)

# Print summary
cat("\nSummary of Games vs Chile's Inequality:\n")
cat("=====================================\n")
cat(sprintf("Chile's Gini coefficient: %.3f\n\n", CHILE_GINI))

above_chile <- game_data %>% filter(gini_coefficient > CHILE_GINI)
cat(sprintf("Games MORE volatile than Chile: %d\n", nrow(above_chile)))
if (nrow(above_chile) > 0) {
  cat("  - ", paste(above_chile$app_name, collapse = "\n  - "), "\n")
}

cat("\n")
below_chile <- game_data %>% filter(gini_coefficient < CHILE_GINI)
cat(sprintf("Games LESS volatile than Chile: %d\n", nrow(below_chile)))

cat("\nTable saved to: visualizations/us_games_volatility_ranked_with_chile.png\n")