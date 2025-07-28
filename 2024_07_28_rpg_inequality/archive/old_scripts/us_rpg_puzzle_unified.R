# Simplified US Market RPG vs Puzzle Games Analysis - Unified Platform Data
# Works with combined iOS & Android data

library(tidyverse)
library(sensortowerR)
library(gt)
library(gtExtras)
library(scales)

# Configuration
RPG_CATEGORY <- 7014
PUZZLE_CATEGORY <- 7003
TARGET_N <- 10

cat("US Market RPG vs Puzzle Games Analysis (iOS & Android)\n")
cat("=====================================================\n\n")

# Get top charts for both platforms combined
cat("Fetching top games from US market (unified iOS & Android)...\n")

top_rpgs <- st_top_charts(
  measure = "revenue",
  category = RPG_CATEGORY,
  os = "unified",
  regions = "US",
  time_range = "month",
  limit = TARGET_N
)

top_puzzles <- st_top_charts(
  measure = "revenue",
  category = PUZZLE_CATEGORY,
  os = "unified",
  regions = "US",
  time_range = "month",
  limit = TARGET_N
)

# Process the data
process_unified_data <- function(data, category_name) {
  data %>%
    mutate(
      app_id = as.character(unified_app_id),
      app_name = unified_app_name,
      category = category_name,
      # Get 30-day revenue from the entities.revenue_absolute column (in cents)
      revenue_30d = entities.revenue_absolute / 100,
      revenue_30d_millions = revenue_30d / 1e6
    ) %>%
    select(app_id, app_name, category, revenue_30d, revenue_30d_millions)
}

rpg_data <- process_unified_data(top_rpgs, "RPG")
puzzle_data <- process_unified_data(top_puzzles, "Puzzle")

# Combine all data
all_games <- bind_rows(rpg_data, puzzle_data) %>%
  arrange(desc(revenue_30d)) %>%
  mutate(
    overall_rank = row_number()
  ) %>%
  group_by(category) %>%
  mutate(
    category_rank = row_number(),
    pct_of_category = revenue_30d / sum(revenue_30d) * 100
  ) %>%
  ungroup()

# Calculate summary statistics
summary_stats <- all_games %>%
  group_by(category) %>%
  summarise(
    n_games = n(),
    total_revenue = sum(revenue_30d),
    avg_revenue = mean(revenue_30d),
    median_revenue = median(revenue_30d),
    top_game_share = max(pct_of_category),
    .groups = "drop"
  )

cat("\nCategory Summary (30-day revenue):\n")
print(summary_stats %>%
  mutate(
    total_revenue_fmt = dollar(total_revenue, scale = 1e-6, suffix = "M"),
    avg_revenue_fmt = dollar(avg_revenue, scale = 1e-6, suffix = "M")
  ) %>%
  select(category, n_games, total_revenue_fmt, avg_revenue_fmt, top_game_share))

# Create GT table
comparison_table <- all_games %>%
  # Shorten names for compact display
  mutate(
    app_name_short = case_when(
      str_detect(app_name, "Fate/Grand Order") ~ "Fate/GO",
      str_detect(app_name, "Dragon Ball") ~ "DBZ",
      str_detect(app_name, "Marvel Strike Force") ~ "Marvel Strike",
      str_detect(app_name, "Star Wars") ~ "SW Galaxy",
      str_detect(app_name, "GODDESS OF VICTORY") ~ "NIKKE",
      str_length(app_name) > 25 ~ str_sub(app_name, 1, 22) %>% paste0("..."),
      TRUE ~ app_name
    )
  ) %>%
  select(overall_rank, category_rank, app_name_short, category, 
         revenue_30d_millions, pct_of_category) %>%
  gt() %>%
  
  tab_header(
    title = md("**Top RPG vs Puzzle Games - US Market**"),
    subtitle = md("30-day revenue comparison across iOS & Android platforms")
  ) %>%
  
  cols_label(
    overall_rank = "Rank",
    category_rank = "#",
    app_name_short = "Game",
    category = "Category",
    revenue_30d_millions = "30-Day Revenue",
    pct_of_category = "% of Category"
  ) %>%
  
  fmt_currency(
    columns = revenue_30d_millions,
    currency = "USD",
    decimals = 1,
    suffixing = TRUE
  ) %>%
  
  fmt_percent(
    columns = pct_of_category,
    decimals = 1,
    scale_values = FALSE
  ) %>%
  
  data_color(
    columns = category,
    fn = scales::col_factor(
      palette = c("RPG" = "#2196F3", "Puzzle" = "#4CAF50"),
      domain = c("RPG", "Puzzle")
    )
  ) %>%
  
  gt_theme_538() %>%
  
  tab_options(
    table.width = px(700),
    data_row.padding = px(2),
    table.font.size = px(11)
  ) %>%
  
  tab_source_note(
    md(sprintf("**Source:** Sensor Tower API | **Date:** %s | **Market:** United States | **Platform:** iOS & Android (Combined)", 
               format(Sys.Date(), "%B %Y")))
  )

print(comparison_table)
gtsave(comparison_table, "visualizations/us_rpg_puzzle_unified_comparison.png", expand = 20)

# Create visualization
revenue_plot <- ggplot(all_games, aes(x = reorder(app_name, revenue_30d), y = revenue_30d_millions, fill = category)) +
  geom_col() +
  coord_flip() +
  scale_fill_manual(values = c("RPG" = "#2196F3", "Puzzle" = "#4CAF50")) +
  scale_y_continuous(labels = dollar_format(suffix = "M")) +
  labs(
    title = "Top RPG vs Puzzle Games by Revenue",
    subtitle = "30-day revenue in US market (iOS & Android combined)",
    x = NULL,
    y = "Revenue (Millions USD)",
    fill = "Category"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12),
    legend.position = "top",
    plot.title.position = "plot"
  )

ggsave("visualizations/us_rpg_puzzle_revenue_bars.png", revenue_plot, width = 10, height = 8, dpi = 300)

cat("\nAnalysis complete! Files saved:\n")
cat("- us_rpg_puzzle_unified_comparison.png (table)\n")
cat("- us_rpg_puzzle_revenue_bars.png (chart)\n")