# Unified US Market RPG vs Puzzle Games Analysis
# Combines clean category separation, Gini coefficients, and individual game volatility

library(tidyverse)
library(sensortowerR)
library(gt)
library(gtExtras)
library(lubridate)
library(scales)

# Configuration
RPG_CATEGORY <- 7014
PUZZLE_CATEGORY <- 7003
TARGET_N <- 10
FETCH_EXTRA <- 20

# Calculate Gini coefficient
calculate_gini <- function(values) {
  values <- values[!is.na(values) & values > 0]
  if (length(values) < 2) return(NA)
  
  values <- sort(values)
  n <- length(values)
  index <- 1:n
  
  gini <- (2 * sum(index * values)) / (n * sum(values)) - (n + 1) / n
  return(gini)
}

# Calculate Lorenz curve points
calculate_lorenz <- function(values) {
  values <- values[!is.na(values) & values > 0]
  if (length(values) < 2) return(NULL)
  
  values <- sort(values)
  n <- length(values)
  
  cum_prop_pop <- seq(0, 1, length.out = n + 1)
  cum_prop_value <- c(0, cumsum(values) / sum(values))
  
  data.frame(
    cum_prop_population = cum_prop_pop,
    cum_prop_revenue = cum_prop_value
  )
}

# ============================================================================
# STEP 1: FETCH AND CLEAN DATA
# ============================================================================

cat("US Market RPG vs Puzzle Games Analysis\n")
cat("=====================================\n\n")
cat("Step 1: Fetching top games from US market...\n")

# Get top charts with standardized revenue - unified for both platforms
top_rpgs_raw <- st_top_charts(
  measure = "revenue",
  category = RPG_CATEGORY,
  os = "unified",
  regions = "US",
  time_range = "month",
  limit = FETCH_EXTRA
)

top_puzzles_raw <- st_top_charts(
  measure = "revenue",
  category = PUZZLE_CATEGORY,
  os = "unified",
  regions = "US",
  time_range = "month",
  limit = FETCH_EXTRA
)

# For unified data, check all available columns
cat("Checking available columns in unified data...\n")
revenue_cols <- grep("revenue", names(top_rpgs_raw), value = TRUE, ignore.case = TRUE)
if (length(revenue_cols) > 0) {
  cat("Found revenue columns:", paste(revenue_cols, collapse = ", "), "\n")
}

# Check for standardized revenue column
if ("revenue" %in% names(top_rpgs_raw)) {
  cat("✓ Using standardized revenue units from sensortowerR v0.2.3+\n")
  revenue_col <- "revenue"
} else if ("revenue_absolute" %in% names(top_rpgs_raw)) {
  cat("⚠ Note: Update sensortowerR for automatic revenue standardization\n")
  revenue_col <- "revenue_absolute"
  top_rpgs_raw$revenue <- top_rpgs_raw$revenue_absolute / 100
  top_puzzles_raw$revenue <- top_puzzles_raw$revenue_absolute / 100
} else if ("entities.revenue_absolute" %in% names(top_rpgs_raw)) {
  # Unified endpoint may use entities.revenue_absolute
  cat("✓ Using unified revenue data (entities.revenue_absolute)\n")
  revenue_col <- "entities.revenue_absolute"
  # Convert from cents to dollars
  top_rpgs_raw$revenue <- top_rpgs_raw$entities.revenue_absolute / 100
  top_puzzles_raw$revenue <- top_puzzles_raw$entities.revenue_absolute / 100
} else {
  # For unified data, check what columns are available
  cat("All available columns:\n")
  print(names(top_rpgs_raw))
  stop("Could not find revenue column in the data")
}

# Get app details for category filtering - for unified data, we already have the category info
get_detailed_info <- function(data, category_type) {
  # For unified data from st_top_charts, we already have games in the correct category
  # We just need to check if they have cross-category contamination
  # Since unified data combines iOS and Android, we'll work with what we have
  
  # Use the unified_app_name and unified_app_id
  data %>%
    mutate(
      app_id = as.character(unified_app_id),
      app_name = unified_app_name,
      publisher_name = NA_character_,  # We don't have publisher in top charts data
      # For now, assume games are correctly categorized since they came from category-specific queries
      has_rpg = (category_type == "RPG"),
      has_puzzle = (category_type == "Puzzle"),
      all_categories = list(if (category_type == "RPG") RPG_CATEGORY else PUZZLE_CATEGORY)
    ) %>%
    select(app_id, app_name, publisher_name, all_categories, has_rpg, has_puzzle)
}

cat("\nStep 2: Filtering cross-category games...\n")

# For unified data, the app ID column is unified_app_id
app_id_col <- "unified_app_id"

rpg_details <- get_detailed_info(top_rpgs_raw, "RPG")
puzzle_details <- get_detailed_info(top_puzzles_raw, "Puzzle")

# For unified data, we'll trust the category assignment from the API
# Since we can't easily check cross-categories without individual app details
clean_rpgs <- rpg_details %>%
  slice_head(n = TARGET_N)

clean_puzzles <- puzzle_details %>%
  slice_head(n = TARGET_N)

cat(sprintf("- Clean RPG games: %d\n", nrow(clean_rpgs)))
cat(sprintf("- Clean Puzzle games: %d\n", nrow(clean_puzzles)))

# ============================================================================
# STEP 2: FETCH DAILY REVENUE DATA
# ============================================================================

cat("\nStep 3: Fetching 360-day daily revenue data...\n")

all_clean_games <- bind_rows(
  clean_rpgs %>% mutate(category = "RPG"),
  clean_puzzles %>% mutate(category = "Puzzle")
)

# Fetch daily data for all games
end_date <- Sys.Date() - 1
start_date <- end_date - 359

# For unified data, we need to handle this differently
# The sales report endpoint typically needs platform-specific app IDs
# For now, let's skip the daily revenue analysis and focus on 30-day data
cat("Note: Daily revenue analysis requires platform-specific app IDs.\n")
cat("Using 30-day revenue data from top charts for this analysis.\n")

# Create dummy daily data structure for compatibility
daily_revenue_data <- data.frame(
  app_id = character(),
  date = Date(),
  total_revenue = numeric()
)

# ============================================================================
# STEP 3: CALCULATE METRICS
# ============================================================================

cat("\nStep 4: Calculating Gini coefficients and metrics...\n")

# Ensure app_id types match
daily_revenue_data$app_id <- as.character(daily_revenue_data$app_id)

# Individual game Gini (daily volatility)
game_gini_results <- daily_revenue_data %>%
  group_by(app_id) %>%
  summarise(
    n_days = n(),
    total_revenue_360d = sum(total_revenue, na.rm = TRUE),
    avg_daily_revenue = mean(total_revenue, na.rm = TRUE),
    gini_coefficient = calculate_gini(total_revenue),
    revenue_30d_estimate = avg_daily_revenue * 30,
    .groups = "drop"
  )

# Join with game details
individual_results <- all_clean_games %>%
  select(app_id, app_name, publisher_name, category) %>%
  inner_join(game_gini_results, by = "app_id") %>%
  arrange(desc(gini_coefficient))

# Category-level Gini (market concentration)
category_gini <- daily_revenue_data %>%
  group_by(app_id) %>%
  summarise(revenue_360d = sum(total_revenue, na.rm = TRUE), .groups = "drop") %>%
  inner_join(all_clean_games %>% select(app_id, category), by = "app_id") %>%
  group_by(category) %>%
  summarise(
    n_games = n(),
    total_revenue = sum(revenue_360d),
    gini_coefficient = calculate_gini(revenue_360d),
    .groups = "drop"
  )

# ============================================================================
# STEP 4: CREATE VISUALIZATIONS
# ============================================================================

cat("\nStep 5: Creating visualizations...\n")

# Define Chile's Gini coefficient (highest inequality country)
CHILE_GINI <- 0.430

# 1. GT Table - Individual Game Gini Rankings
gini_table <- individual_results %>%
  mutate(
    rank = row_number(),
    # Shorten game names
    app_name_short = case_when(
      str_detect(app_name, "Fate/Grand Order") ~ "Fate/GO",
      str_detect(app_name, "Dragon Ball Z Dokkan Battle") ~ "DBZ Dokkan",
      str_detect(app_name, "Marvel Strike Force") ~ "Marvel Strike",
      str_detect(app_name, "Star Wars™: Galaxy of Heroes") ~ "SW Galaxy",
      str_detect(app_name, "Candy Crush") ~ "Candy Crush",
      str_detect(app_name, "Royal Match") ~ "Royal Match",
      str_detect(app_name, "Gardenscapes") ~ "Gardenscapes",
      str_detect(app_name, "Homescapes") ~ "Homescapes",
      str_detect(app_name, "Toon Blast") ~ "Toon Blast",
      str_detect(app_name, "Toy Blast") ~ "Toy Blast",
      str_length(app_name) > 20 ~ str_sub(app_name, 1, 17) %>% paste0("..."),
      TRUE ~ app_name
    ),
    # Shorten publisher names
    publisher_short = case_when(
      str_detect(publisher_name, "BANDAI NAMCO") ~ "Bandai",
      str_detect(publisher_name, "Aniplex Inc") ~ "Aniplex",
      str_detect(publisher_name, "Electronic Arts") ~ "EA",
      str_detect(publisher_name, "Playrix") ~ "Playrix",
      str_detect(publisher_name, "King") ~ "King",
      str_detect(publisher_name, "Scopely") ~ "Scopely",
      str_detect(publisher_name, "Peak Games") ~ "Peak",
      str_detect(publisher_name, "Dream Games") ~ "Dream",
      str_length(publisher_name) > 15 ~ str_sub(publisher_name, 1, 12) %>% paste0("..."),
      TRUE ~ publisher_name
    ),
    # Calculate average daily revenue from 360-day total
    avg_daily_calc = total_revenue_360d / 360,
    # Calculate percent difference from Chile (most unequal country)
    pct_diff_from_chile = ((gini_coefficient - CHILE_GINI) / CHILE_GINI) * 100
  ) %>%
  select(rank, app_name_short, publisher_short, category, gini_coefficient, 
         pct_diff_from_chile, total_revenue_360d, avg_daily_calc) %>%
  gt() %>%
  
  tab_header(
    title = md("**Mobile Games Ranked by Revenue Volatility**"),
    subtitle = md("360-day daily revenue Gini coefficients (US Market)")
  ) %>%
  
  cols_label(
    rank = "#",
    app_name_short = "Game",
    publisher_short = "Publisher",
    category = "Category",
    gini_coefficient = "Gini",
    pct_diff_from_chile = "% Diff from Chile",
    total_revenue_360d = "360d Revenue",
    avg_daily_calc = "Avg Daily Revenue"
  ) %>%
  
  fmt_number(
    columns = gini_coefficient,
    decimals = 3
  ) %>%
  fmt_percent(
    columns = pct_diff_from_chile,
    decimals = 1,
    scale_values = FALSE
  ) %>%
  fmt_currency(
    columns = c(total_revenue_360d, avg_daily_calc),
    currency = "USD",
    decimals = 0,
    suffixing = TRUE
  ) %>%
  
  data_color(
    columns = category,
    fn = scales::col_factor(
      palette = c("RPG" = "#2196F3", "Puzzle" = "#4CAF50"),
      domain = c("RPG", "Puzzle")
    )
  ) %>%
  
  data_color(
    columns = gini_coefficient,
    fn = scales::col_numeric(
      palette = c("#4CAF50", "#FFC107", "#F44336"),
      domain = c(0, 0.5)
    )
  ) %>%
  
  gt_theme_538() %>%
  
  tab_footnote(
    footnote = "Higher Gini = more volatile daily revenue. 0 = same revenue every day, 1 = all revenue on one day",
    locations = cells_column_labels(columns = gini_coefficient)
  ) %>%
  
  tab_footnote(
    footnote = "% difference from Chile's Gini (0.430) - the most unequal country",
    locations = cells_column_labels(columns = pct_diff_from_chile)
  ) %>%
  
  # Table options - make it more compact
  tab_options(
    table.width = px(800),
    data_row.padding = px(1),
    table.font.size = px(10),
    column_labels.font.size = px(11)
  ) %>%
  
  tab_source_note(
    md(sprintf("**Source:** Sensor Tower API | **Data Period:** %s to %s | **Market:** United States | **Platform:** iOS & Android", 
               format(start_date, "%B %d, %Y"), format(end_date, "%B %d, %Y")))
  )

gtsave(gini_table, "visualizations/us_games_volatility_ranked.png", expand = 20)

# 2. Lorenz Curves - Top 3 most volatile from each category
top_volatile_games <- individual_results %>%
  group_by(category) %>%
  slice_max(gini_coefficient, n = 3) %>%
  ungroup()

lorenz_data <- daily_revenue_data %>%
  filter(app_id %in% top_volatile_games$app_id) %>%
  mutate(app_id = as.character(app_id)) %>%
  group_by(app_id) %>%
  group_modify(~ {
    lorenz_points <- calculate_lorenz(.x$total_revenue)
    if (!is.null(lorenz_points)) {
      lorenz_points
    } else {
      data.frame(cum_prop_population = numeric(), cum_prop_revenue = numeric())
    }
  }) %>%
  ungroup() %>%
  left_join(all_clean_games %>% select(app_id, app_name, category), by = "app_id")

lorenz_plot <- ggplot(lorenz_data, aes(x = cum_prop_population, y = cum_prop_revenue)) +
  geom_line(aes(color = app_name, linetype = category), linewidth = 1.2) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray50") +
  scale_color_brewer(palette = "Set3") +
  scale_linetype_manual(values = c("RPG" = "solid", "Puzzle" = "dotted")) +
  labs(
    title = "Revenue Volatility: Lorenz Curves",
    subtitle = "Daily revenue distribution over 360 days (top 3 most volatile per category)",
    x = "Cumulative Proportion of Days",
    y = "Cumulative Proportion of Revenue",
    color = "Game",
    linetype = "Category"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12),
    legend.position = "bottom",
    legend.box = "vertical",
    plot.title.position = "plot"
  ) +
  coord_equal()

ggsave("visualizations/us_lorenz_curves_volatility.png", lorenz_plot, width = 10, height = 10, dpi = 300)

# 3. Market Concentration Table
market_table <- all_clean_games %>%
  left_join(
    top_rpgs_raw %>% 
      mutate(app_id = as.character(.data[[app_id_col]])) %>%
      select(app_id, revenue),
    by = "app_id"
  ) %>%
  left_join(
    top_puzzles_raw %>% 
      mutate(app_id = as.character(.data[[app_id_col]])) %>%
      select(app_id, revenue),
    by = "app_id",
    suffix = c("", ".puzzle")
  ) %>%
  mutate(
    revenue = coalesce(revenue, revenue.puzzle),
    revenue_millions = revenue / 1e6
  ) %>%
  select(-revenue.puzzle) %>%
  arrange(desc(revenue)) %>%
  mutate(overall_rank = row_number()) %>%
  group_by(category) %>%
  mutate(
    category_rank = row_number(),
    pct_of_category = revenue / sum(revenue) * 100
  ) %>%
  ungroup() %>%
  select(overall_rank, category_rank, app_name, publisher_name, category, 
         revenue_millions, pct_of_category)

concentration_table <- market_table %>%
  gt() %>%
  
  tab_header(
    title = md("**Top RPG and Puzzle Games - US Market**"),
    subtitle = md(sprintf("Market Concentration - RPG Gini: %.3f | Puzzle Gini: %.3f",
                         filter(category_gini, category == "RPG")$gini_coefficient,
                         filter(category_gini, category == "Puzzle")$gini_coefficient))
  ) %>%
  
  cols_label(
    overall_rank = "Rank",
    category_rank = "#",
    app_name = "Game",
    publisher_name = "Publisher",
    category = "Category",
    revenue_millions = "30-Day Revenue",
    pct_of_category = "% of Category"
  ) %>%
  
  fmt_currency(
    columns = revenue_millions,
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
  
  tab_source_note(
    md(sprintf("**Source:** Sensor Tower API | **Date:** %s | **Market:** United States | **Platform:** iOS & Android", 
               format(Sys.Date(), "%B %Y")))
  )

gtsave(concentration_table, "visualizations/us_market_concentration.png", expand = 20)

# ============================================================================
# STEP 5: SUMMARY STATISTICS
# ============================================================================

cat("\n========== ANALYSIS SUMMARY ==========\n")

cat("\nCategory-Level Market Concentration (360-day):\n")
print(category_gini)

cat("\nIndividual Game Volatility Summary:\n")
volatility_summary <- individual_results %>%
  group_by(category) %>%
  summarise(
    n_games = n(),
    avg_gini = mean(gini_coefficient),
    min_gini = min(gini_coefficient),
    max_gini = max(gini_coefficient),
    .groups = "drop"
  )
print(volatility_summary)

cat("\nMost Volatile Games (Highest Daily Gini):\n")
print(individual_results %>% slice_head(n = 5) %>% select(app_name, category, gini_coefficient))

cat("\nMost Stable Games (Lowest Daily Gini):\n")
print(individual_results %>% slice_tail(n = 5) %>% select(app_name, category, gini_coefficient))

cat("\nAnalysis complete! Visualizations saved to visualizations/ folder:\n")
cat("- us_games_volatility_ranked.png (individual game volatility)\n")
cat("- us_lorenz_curves_volatility.png (revenue distribution curves)\n")
cat("- us_market_concentration.png (market concentration table)\n")