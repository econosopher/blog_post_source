# Individual Game Gini Coefficients and Lorenz Curves
# Calculates Gini for each game based on daily revenue distribution

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
  
  # Calculate cumulative proportions
  cum_prop_pop <- seq(0, 1, length.out = n + 1)
  cum_prop_value <- c(0, cumsum(values) / sum(values))
  
  data.frame(
    cum_prop_population = cum_prop_pop,
    cum_prop_revenue = cum_prop_value
  )
}

# Step 1: Get top games and filter
cat("Step 1: Fetching top RPG and Puzzle games from US market...\n")

# Get top charts - now with improved deduplication and sorting
top_rpgs_raw <- st_top_charts(
  measure = "revenue",
  category = RPG_CATEGORY,
  os = "unified",  # Use unified for better deduplication
  regions = "US",
  time_range = "month",
  limit = FETCH_EXTRA,
  enrich_response = TRUE,
  deduplicate_apps = TRUE  # Ensure proper deduplication
)

top_puzzles_raw <- st_top_charts(
  measure = "revenue",
  category = PUZZLE_CATEGORY,
  os = "unified",  # Use unified for better deduplication
  regions = "US",
  time_range = "month",
  limit = FETCH_EXTRA,
  enrich_response = TRUE,
  deduplicate_apps = TRUE  # Ensure proper deduplication
)

# Use the standardized 'revenue' column if available
if ("revenue" %in% names(top_rpgs_raw)) {
  cat("✓ Using standardized revenue units from sensortowerR v0.2.3+\n")
} else {
  cat("⚠ Note: Update sensortowerR for automatic revenue standardization\n")
}

# Get app details - handle unified IDs properly
get_detailed_info <- function(app_data) {
  # Extract unified app IDs if available
  if ("unified_app_id" %in% names(app_data)) {
    app_ids <- unique(app_data$unified_app_id)
  } else {
    app_ids <- unique(app_data$app_id)
  }
  
  details <- st_app_details(
    app_ids = as.character(app_ids),
    os = "unified"  # Use unified OS for better results
  )
  
  if (!is.null(details)) {
    details %>%
      mutate(
        app_id = as.character(app_id),
        all_categories = map(categories, ~ {
          if (!is.null(.x) && length(.x) > 0) {
            if (is.list(.x)) {
              unlist(map(.x, ~ .x$id))
            } else {
              .x
            }
          } else {
            NA
          }
        }),
        has_rpg = map_lgl(all_categories, ~ RPG_CATEGORY %in% .x),
        has_puzzle = map_lgl(all_categories, ~ PUZZLE_CATEGORY %in% .x)
      ) %>%
      select(app_id, app_name, publisher_name, all_categories, has_rpg, has_puzzle)
  } else {
    NULL
  }
}

rpg_details <- get_detailed_info(top_rpgs_raw)
puzzle_details <- get_detailed_info(top_puzzles_raw)

# Clean lists
clean_rpgs <- rpg_details %>%
  filter(has_rpg & !has_puzzle) %>%
  slice_head(n = TARGET_N)

clean_puzzles <- puzzle_details %>%
  filter(has_puzzle & !has_rpg) %>%
  slice_head(n = TARGET_N)

# Combine for processing
all_clean_games <- bind_rows(
  clean_rpgs %>% mutate(category = "RPG"),
  clean_puzzles %>% mutate(category = "Puzzle")
)

# Step 2: Fetch daily revenue data and calculate individual Gini coefficients
cat("\nStep 2: Fetching 360-day daily revenue data...\n")

# Fetch daily data for all games - use unified IDs if available
end_date <- Sys.Date() - 1
start_date <- end_date - 359

# Use unified IDs if available for better data quality
if ("unified_app_id" %in% names(all_clean_games)) {
  app_ids_to_fetch <- unique(all_clean_games$unified_app_id)
} else {
  app_ids_to_fetch <- unique(all_clean_games$app_id)
}

daily_revenue_data <- st_sales_report(
  app_ids = as.character(app_ids_to_fetch),
  os = "unified",  # Use unified for cross-platform data
  countries = "US",
  start_date = as.character(start_date),
  end_date = as.character(end_date),
  date_granularity = "daily"
)

# Step 3: Calculate Gini coefficient for each game
cat("\nStep 3: Calculating Gini coefficients for each game...\n")

# Ensure app_id types match
daily_revenue_data$app_id <- as.character(daily_revenue_data$app_id)

# Debug: Check data
cat(sprintf("Daily revenue data rows: %d\n", nrow(daily_revenue_data)))
cat(sprintf("Unique games: %d\n", length(unique(daily_revenue_data$app_id))))

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

# Debug: Check results
cat(sprintf("Game Gini results rows: %d\n", nrow(game_gini_results)))
print(head(game_gini_results, 3))

# Join with game details
final_results <- all_clean_games %>%
  select(app_id, app_name, publisher_name, category) %>%
  inner_join(game_gini_results, by = "app_id") %>%
  arrange(desc(gini_coefficient))

# Step 4: Create Lorenz curves
cat("\nStep 4: Creating Lorenz curves...\n")

# For Lorenz curves, let's show top 3 highest Gini games from each category
top_gini_games <- final_results %>%
  group_by(category) %>%
  slice_max(gini_coefficient, n = 3) %>%
  ungroup()

# Get daily data for these specific games
selected_games <- top_gini_games$app_id

lorenz_data <- daily_revenue_data %>%
  filter(app_id %in% selected_games) %>%
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
  ungroup()

# Add game names
lorenz_data <- lorenz_data %>%
  left_join(all_clean_games %>% select(app_id, app_name, category), by = "app_id")

# Create Lorenz curve plot
lorenz_plot <- ggplot(lorenz_data, aes(x = cum_prop_population, y = cum_prop_revenue)) +
  geom_line(aes(color = app_name, linetype = category), linewidth = 1.2) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray50") +
  scale_color_brewer(palette = "Set3") +
  scale_linetype_manual(values = c("RPG" = "solid", "Puzzle" = "dotted")) +
  labs(
    title = "Lorenz Curves: Daily Revenue Distribution",
    subtitle = "Top 3 most volatile games (highest Gini) in each category",
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
    legend.box = "vertical"
  ) +
  coord_equal()

# Save Lorenz plot
ggsave("lorenz_curves_comparison.png", lorenz_plot, width = 10, height = 10, dpi = 300)

# Step 5: Create GT table ranked by Gini coefficient
cat("\nStep 5: Creating table ranked by Gini coefficient...\n")

gini_table <- final_results %>%
  mutate(rank = row_number()) %>%
  select(rank, app_name, publisher_name, category, gini_coefficient, 
         total_revenue_360d, avg_daily_revenue) %>%
  gt() %>%
  
  # Header
  tab_header(
    title = md("**Mobile Games Ranked by Revenue Inequality**"),
    subtitle = md("360-day Gini coefficients for daily revenue distribution (US Market)")
  ) %>%
  
  # Column labels
  cols_label(
    rank = "#",
    app_name = "Game",
    publisher_name = "Publisher",
    category = "Category",
    gini_coefficient = "Gini Coefficient",
    total_revenue_360d = "Total Revenue (360d)",
    avg_daily_revenue = "Avg Daily Revenue"
  ) %>%
  
  # Format numbers
  fmt_number(
    columns = gini_coefficient,
    decimals = 3
  ) %>%
  fmt_currency(
    columns = c(total_revenue_360d, avg_daily_revenue),
    currency = "USD",
    decimals = 0,
    suffixing = TRUE
  ) %>%
  
  # Style category column
  data_color(
    columns = category,
    fn = scales::col_factor(
      palette = c("RPG" = "#2196F3", "Puzzle" = "#4CAF50"),
      domain = c("RPG", "Puzzle")
    )
  ) %>%
  
  # Highlight Gini values
  data_color(
    columns = gini_coefficient,
    fn = scales::col_numeric(
      palette = c("#4CAF50", "#FFC107", "#F44336"),
      domain = c(0, 0.5)
    )
  ) %>%
  
  # Apply theme
  gt_theme_538() %>%
  
  # Add footnotes
  tab_footnote(
    footnote = "Gini coefficient measures inequality in daily revenue. 0 = perfect equality (same revenue every day), 1 = perfect inequality (all revenue on one day)",
    locations = cells_column_labels(columns = gini_coefficient)
  ) %>%
  
  # Table options
  tab_options(
    table.width = px(1000),
    data_row.padding = px(3)
  ) %>%
  
  # Source note
  tab_source_note(
    md(sprintf("**Source:** Sensor Tower API | **Date:** %s | **Market:** United States | **Platform:** iOS", 
               format(Sys.Date(), "%B %Y")))
  )

# Save table
print(gini_table)
gtsave(gini_table, "games_ranked_by_gini.png", expand = 20)

# Print summary statistics
cat("\n========== GINI COEFFICIENT SUMMARY ==========\n")

cat("\nBy Category:\n")
category_summary <- final_results %>%
  group_by(category) %>%
  summarise(
    n_games = n(),
    avg_gini = mean(gini_coefficient),
    min_gini = min(gini_coefficient),
    max_gini = max(gini_coefficient),
    .groups = "drop"
  )
print(category_summary)

cat("\nMost Volatile Games (Highest Gini):\n")
print(final_results %>% slice_head(n = 5) %>% select(app_name, category, gini_coefficient))

cat("\nMost Stable Games (Lowest Gini):\n")
print(final_results %>% slice_tail(n = 5) %>% select(app_name, category, gini_coefficient))

cat("\nAnalysis complete! Files saved:\n")
cat("- games_ranked_by_gini.png (table)\n")
cat("- lorenz_curves_comparison.png (visualization)\n")