# RPG vs Puzzle Detailed Comparison with Game Names
# Creates comprehensive GT table with actual game names and metrics

library(tidyverse)
library(sensortowerR)
library(gt)
library(gtExtras)

# Configuration
RPG_CATEGORY <- 7014
PUZZLE_CATEGORY <- 7003
TOP_N <- 10

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

# Step 1: Get top games
cat("Fetching top RPG and Puzzle games...\n")

top_rpgs <- st_top_charts(
  measure = "revenue",
  category = RPG_CATEGORY,
  os = "ios",
  time_range = "month",
  limit = TOP_N + 5  # Get extra in case we need to filter
)

top_puzzles <- st_top_charts(
  measure = "revenue", 
  category = PUZZLE_CATEGORY,
  os = "ios",
  time_range = "month",
  limit = TOP_N + 5
)

# Step 2: Get app details with names and subcategories
cat("\nFetching app details and names...\n")

get_app_details <- function(app_ids) {
  # Get app details including names
  details <- st_app_details(
    app_ids = as.character(app_ids),
    os = "ios"
  )
  
  # Extract relevant info
  if (!is.null(details) && nrow(details) > 0) {
    details %>%
      select(
        app_id,
        app_name = app_name,
        publisher_name,
        categories,
        any_of(c("current_version", "content_rating"))
      )
  } else {
    NULL
  }
}

# Get details for both categories
rpg_details <- get_app_details(top_rpgs$app_id)
puzzle_details <- get_app_details(top_puzzles$app_id)

# Ensure app_id types match
if (!is.null(rpg_details)) {
  rpg_details$app_id <- as.character(rpg_details$app_id)
}
if (!is.null(puzzle_details)) {
  puzzle_details$app_id <- as.character(puzzle_details$app_id)
}
top_rpgs$app_id <- as.character(top_rpgs$app_id)
top_puzzles$app_id <- as.character(top_puzzles$app_id)

# Step 3: Combine with revenue data
rpg_data <- top_rpgs %>%
  left_join(rpg_details, by = "app_id") %>%
  mutate(
    primary_category = "RPG",
    revenue_30d = revenue_absolute / 1e6,  # Convert to millions
    revenue_180d = if("custom_tags.Last 180 Days Revenue (WW)" %in% names(.)) {
      `custom_tags.Last 180 Days Revenue (WW)` / 1e6
    } else {
      revenue_30d * 6  # Rough estimate if not available
    }
  ) %>%
  arrange(desc(revenue_30d)) %>%
  slice_head(n = TOP_N)

puzzle_data <- top_puzzles %>%
  left_join(puzzle_details, by = "app_id") %>%
  mutate(
    primary_category = "Puzzle",
    revenue_30d = revenue_absolute / 1e6,
    revenue_180d = if("custom_tags.Last 180 Days Revenue (WW)" %in% names(.)) {
      `custom_tags.Last 180 Days Revenue (WW)` / 1e6
    } else {
      revenue_30d * 6
    }
  ) %>%
  arrange(desc(revenue_30d)) %>%
  slice_head(n = TOP_N)

# Combine all data
all_data <- bind_rows(rpg_data, puzzle_data)

# Step 4: Calculate metrics
cat("\nCalculating inequality metrics...\n")

# Add rank and percentages
final_data <- all_data %>%
  group_by(primary_category) %>%
  arrange(desc(revenue_30d)) %>%
  mutate(
    rank = row_number(),
    total_revenue_30d = sum(revenue_30d),
    total_revenue_180d = sum(revenue_180d),
    pct_of_category_30d = revenue_30d / total_revenue_30d * 100,
    pct_of_top_game_30d = revenue_30d / max(revenue_30d) * 100,
    pct_of_category_180d = revenue_180d / total_revenue_180d * 100
  ) %>%
  ungroup()

# Calculate Gini coefficients
gini_metrics <- all_data %>%
  group_by(primary_category) %>%
  summarise(
    gini_30d = calculate_gini(revenue_30d),
    gini_180d = calculate_gini(revenue_180d),
    top_game_share_30d = max(revenue_30d) / sum(revenue_30d) * 100,
    top_3_share_30d = sum(sort(revenue_30d, decreasing = TRUE)[1:3]) / sum(revenue_30d) * 100,
    .groups = "drop"
  )

# Step 5: Create comprehensive GT table
cat("\nCreating detailed comparison table...\n")

# Prepare table data
table_data <- final_data %>%
  select(
    rank,
    primary_category,
    app_name,
    publisher_name,
    revenue_30d,
    revenue_180d,
    pct_of_top_game_30d,
    pct_of_category_30d
  )

# Create GT table
comparison_table <- table_data %>%
  gt() %>%
  
  # Header
  tab_header(
    title = md("**Mobile Game Revenue Analysis: RPG vs Puzzle**"),
    subtitle = md("Top 10 games by revenue with inequality metrics")
  ) %>%
  
  # Row groups
  tab_row_group(
    label = md("**Role Playing Games**"),
    rows = primary_category == "RPG"
  ) %>%
  tab_row_group(
    label = md("**Puzzle Games**"),
    rows = primary_category == "Puzzle"
  ) %>%
  
  # Column labels
  cols_label(
    rank = "#",
    app_name = "Game",
    publisher_name = "Publisher",
    revenue_30d = "30-Day Revenue",
    revenue_180d = "180-Day Revenue",
    pct_of_top_game_30d = "% of #1",
    pct_of_category_30d = "% of Category"
  ) %>%
  
  # Hide category column
  cols_hide(primary_category) %>%
  
  # Format numbers
  fmt_currency(
    columns = c(revenue_30d, revenue_180d),
    currency = "USD",
    decimals = 1,
    suffixing = TRUE
  ) %>%
  fmt_percent(
    columns = c(pct_of_top_game_30d, pct_of_category_30d),
    decimals = 1,
    scale_values = FALSE
  ) %>%
  
  # Add summary rows
  summary_rows(
    groups = everything(),
    columns = c(revenue_30d, revenue_180d),
    fns = list(
      Total = ~sum(., na.rm = TRUE)
    ),
    fmt = ~ fmt_currency(., currency = "USD", decimals = 1, suffixing = TRUE)
  ) %>%
  
  # Conditional formatting
  data_color(
    columns = pct_of_category_30d,
    colors = scales::col_numeric(
      palette = c("#FFF9C4", "#F57C00"),
      domain = c(0, 30)
    )
  ) %>%
  
  # Styling
  tab_style(
    style = list(
      cell_fill(color = "#E8F5E9"),
      cell_text(weight = "bold", size = px(14))
    ),
    locations = cells_row_groups()
  ) %>%
  
  tab_style(
    style = cell_text(size = px(11)),
    locations = cells_body()
  ) %>%
  
  # Add Gini footnotes
  tab_footnote(
    footnote = md(sprintf("**Gini coefficient**: 30-day = %.3f, 180-day = %.3f | **Top 3 share**: %.1f%%",
                         filter(gini_metrics, primary_category == "RPG")$gini_30d,
                         filter(gini_metrics, primary_category == "RPG")$gini_180d,
                         filter(gini_metrics, primary_category == "RPG")$top_3_share_30d)),
    locations = cells_row_groups(groups = "**Role Playing Games**")
  ) %>%
  tab_footnote(
    footnote = md(sprintf("**Gini coefficient**: 30-day = %.3f, 180-day = %.3f | **Top 3 share**: %.1f%%",
                         filter(gini_metrics, primary_category == "Puzzle")$gini_30d,
                         filter(gini_metrics, primary_category == "Puzzle")$gini_180d,
                         filter(gini_metrics, primary_category == "Puzzle")$top_3_share_30d)),
    locations = cells_row_groups(groups = "**Puzzle Games**")
  ) %>%
  
  # Table options
  tab_options(
    table.font.size = px(12),
    heading.title.font.size = px(20),
    heading.subtitle.font.size = px(14),
    row_group.font.weight = "bold",
    column_labels.font.weight = "bold",
    table.width = px(1000)
  ) %>%
  
  # Source note
  tab_source_note(
    md(paste0("**Source:** Sensor Tower API | **Date:** ", format(Sys.Date(), "%B %Y"), 
              " | **Note:** Revenue in millions USD, iOS data"))
  )

# Save table
print(comparison_table)
gtsave(comparison_table, "rpg_puzzle_detailed_comparison.png", expand = 20)

# Print summary
cat("\n========== ANALYSIS SUMMARY ==========\n")
cat("\nGini Coefficients (30-day revenue):\n")
print(gini_metrics)

cat("\nTop Games:\n")
cat("RPG #1:", filter(table_data, primary_category == "RPG", rank == 1)$app_name, "\n")
cat("Puzzle #1:", filter(table_data, primary_category == "Puzzle", rank == 1)$app_name, "\n")

cat("\nTable saved as rpg_puzzle_detailed_comparison.png\n")