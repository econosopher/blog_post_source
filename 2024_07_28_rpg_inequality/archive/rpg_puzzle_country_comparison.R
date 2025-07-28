# RPG vs Puzzle Games - Country-Specific Gini Analysis
# Compares revenue inequality between US and Japan markets

library(tidyverse)
library(sensortowerR)
library(gt)
library(gtExtras)

# Configuration
RPG_CATEGORY <- 7014
PUZZLE_CATEGORY <- 7003
COUNTRIES <- c("US", "JP")
TOP_N <- 20  # Get more games for better Gini calculation

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

# Function to fetch category data for a specific country
fetch_category_country_data <- function(category_id, category_name, country) {
  cat(sprintf("Fetching %s games for %s...\n", category_name, country))
  
  # Get top charts for specific country
  top_games <- tryCatch({
    st_top_charts(
      measure = "revenue",
      category = category_id,
      os = "ios",
      regions = country,
      time_range = "month",
      limit = TOP_N
    )
  }, error = function(e) {
    warning(sprintf("Failed to fetch %s data for %s", category_name, country))
    return(NULL)
  })
  
  if (!is.null(top_games) && nrow(top_games) > 0) {
    # Get app details for names
    app_details <- tryCatch({
      st_app_details(
        app_ids = as.character(top_games$app_id),
        os = "ios"
      )
    }, error = function(e) NULL)
    
    # Combine data
    if (!is.null(app_details)) {
      app_details$app_id <- as.character(app_details$app_id)
      top_games$app_id <- as.character(top_games$app_id)
      
      top_games <- top_games %>%
        left_join(
          app_details %>% select(app_id, app_name, publisher_name),
          by = "app_id"
        )
    }
    
    # Process revenue data
    top_games %>%
      mutate(
        category = category_name,
        country = country,
        # Use standardized revenue column if available, fallback to manual conversion
        revenue_30d = if ("revenue" %in% names(.)) revenue / 1e6 else revenue_absolute / 100 / 1e6,
        revenue_180d = if("custom_tags.Last 180 Days Revenue (WW)" %in% names(.)) {
          `custom_tags.Last 180 Days Revenue (WW)` / 1e6
        } else {
          revenue_30d * 6  # Estimate
        }
      ) %>%
      select(category, country, app_id, app_name, publisher_name, 
             revenue_30d, revenue_180d) %>%
      arrange(desc(revenue_30d))
  } else {
    NULL
  }
}

# Main analysis
cat("Country-Specific RPG vs Puzzle Analysis\n")
cat("======================================\n\n")

# Fetch data for all combinations
all_data <- list()

for (country in COUNTRIES) {
  # RPG data
  rpg_data <- fetch_category_country_data(RPG_CATEGORY, "RPG", country)
  if (!is.null(rpg_data)) {
    all_data[[paste("RPG", country, sep = "_")]] <- rpg_data
  }
  
  # Puzzle data
  puzzle_data <- fetch_category_country_data(PUZZLE_CATEGORY, "Puzzle", country)
  if (!is.null(puzzle_data)) {
    all_data[[paste("Puzzle", country, sep = "_")]] <- puzzle_data
  }
}

# Combine all data
combined_data <- bind_rows(all_data)

# Calculate Gini coefficients by category and country
gini_summary <- combined_data %>%
  group_by(category, country) %>%
  summarise(
    n_games = n(),
    total_revenue_30d = sum(revenue_30d, na.rm = TRUE),
    total_revenue_180d = sum(revenue_180d, na.rm = TRUE),
    gini_30d = calculate_gini(revenue_30d),
    gini_180d = calculate_gini(revenue_180d),
    top_game_revenue = max(revenue_30d, na.rm = TRUE),
    top_game_share = max(revenue_30d, na.rm = TRUE) / sum(revenue_30d, na.rm = TRUE) * 100,
    top_3_share = {
      sorted_rev <- sort(revenue_30d, decreasing = TRUE)
      sum(sorted_rev[1:min(3, length(sorted_rev))]) / sum(sorted_rev) * 100
    },
    .groups = "drop"
  )

# Get top game names
top_games <- combined_data %>%
  group_by(category, country) %>%
  slice_max(revenue_30d, n = 1) %>%
  select(category, country, top_game_name = app_name) %>%
  ungroup()

# Join with summary
gini_summary <- gini_summary %>%
  left_join(top_games, by = c("category", "country"))

# Create comparison table
cat("\nCreating country comparison table...\n")

# Prepare data for GT table
table_data <- gini_summary %>%
  select(country, category, gini_30d, gini_180d, top_3_share, 
         top_game_name, top_game_share, total_revenue_30d) %>%
  pivot_wider(
    names_from = category,
    values_from = c(gini_30d, gini_180d, top_3_share, top_game_name, 
                    top_game_share, total_revenue_30d)
  )

# Create GT table
comparison_table <- table_data %>%
  gt() %>%
  
  # Header
  tab_header(
    title = md("**Mobile Game Revenue Inequality: RPG vs Puzzle by Country**"),
    subtitle = md("Comparing Gini coefficients and market concentration in US and Japan")
  ) %>%
  
  # Column labels
  cols_label(
    country = "Market",
    gini_30d_RPG = "30-day",
    gini_180d_RPG = "180-day",
    top_3_share_RPG = "Top 3 Share",
    top_game_name_RPG = "Top Game",
    top_game_share_RPG = "Top Game %",
    total_revenue_30d_RPG = "Total Rev",
    gini_30d_Puzzle = "30-day",
    gini_180d_Puzzle = "180-day", 
    top_3_share_Puzzle = "Top 3 Share",
    top_game_name_Puzzle = "Top Game",
    top_game_share_Puzzle = "Top Game %",
    total_revenue_30d_Puzzle = "Total Rev"
  ) %>%
  
  # Column spanners
  tab_spanner(
    label = md("**RPG Games - Gini**"),
    columns = c(gini_30d_RPG, gini_180d_RPG)
  ) %>%
  tab_spanner(
    label = md("**RPG Games - Concentration**"),
    columns = c(top_3_share_RPG, top_game_name_RPG, top_game_share_RPG, total_revenue_30d_RPG)
  ) %>%
  tab_spanner(
    label = md("**Puzzle Games - Gini**"),
    columns = c(gini_30d_Puzzle, gini_180d_Puzzle)
  ) %>%
  tab_spanner(
    label = md("**Puzzle Games - Concentration**"),
    columns = c(top_3_share_Puzzle, top_game_name_Puzzle, top_game_share_Puzzle, total_revenue_30d_Puzzle)
  ) %>%
  
  # Format numbers
  fmt_number(
    columns = starts_with("gini"),
    decimals = 3
  ) %>%
  fmt_percent(
    columns = contains("share"),
    decimals = 1,
    scale_values = FALSE
  ) %>%
  fmt_currency(
    columns = contains("total_revenue"),
    currency = "USD",
    decimals = 0,
    suffixing = TRUE
  ) %>%
  
  # Conditional formatting for Gini
  data_color(
    columns = c(gini_30d_RPG, gini_30d_Puzzle),
    colors = scales::col_numeric(
      palette = c("#4CAF50", "#FFC107", "#F44336"),
      domain = c(0.15, 0.4)
    )
  ) %>%
  
  # Highlight differences
  tab_style(
    style = cell_text(weight = "bold"),
    locations = cells_body(
      columns = c(gini_30d_RPG, gini_30d_Puzzle),
      rows = country == "US"
    )
  ) %>%
  
  # General styling
  tab_style(
    style = list(
      cell_fill(color = "#F5F5F5"),
      cell_text(weight = "bold")
    ),
    locations = cells_column_labels()
  ) %>%
  
  # Add footnotes with insights
  tab_footnote(
    footnote = "Gini coefficient: 0 = perfect equality, 1 = perfect inequality",
    locations = cells_column_spanners(spanners = contains("Gini"))
  ) %>%
  
  # Table options
  tab_options(
    table.font.size = px(12),
    heading.title.font.size = px(18),
    heading.subtitle.font.size = px(14),
    column_labels.font.weight = "bold",
    table.width = px(1200)
  ) %>%
  
  # Source note
  tab_source_note(
    md("**Source:** Sensor Tower API | **Date:** " %>% 
       paste0(format(Sys.Date(), "%B %Y")) %>%
       paste0(" | **Note:** Based on top 20 games per category/country, iOS data"))
  )

# Save table
print(comparison_table)
gtsave(comparison_table, "rpg_puzzle_country_comparison.png", expand = 20)

# Print detailed summary
cat("\n\n========== DETAILED SUMMARY ==========\n")

# Print by country
for (c in COUNTRIES) {
  cat(sprintf("\n%s Market:\n", c))
  country_data <- gini_summary %>% filter(country == c)
  
  for (i in 1:nrow(country_data)) {
    cat(sprintf("  %s: Gini = %.3f (30d), %.3f (180d) | Top game: %s (%.1f%%) | Top 3: %.1f%%\n",
                country_data$category[i],
                country_data$gini_30d[i],
                country_data$gini_180d[i],
                country_data$top_game_name[i],
                country_data$top_game_share[i],
                country_data$top_3_share[i]))
  }
}

# Overall comparison
cat("\n\nKey Insights:\n")
us_data <- gini_summary %>% filter(country == "US")
jp_data <- gini_summary %>% filter(country == "JP")

if (nrow(us_data) > 0 && nrow(jp_data) > 0) {
  # US vs JP comparison
  cat(sprintf("- US Puzzle Gini: %.3f vs Japan Puzzle Gini: %.3f\n",
              filter(us_data, category == "Puzzle")$gini_30d,
              filter(jp_data, category == "Puzzle")$gini_30d))
  cat(sprintf("- US RPG Gini: %.3f vs Japan RPG Gini: %.3f\n", 
              filter(us_data, category == "RPG")$gini_30d,
              filter(jp_data, category == "RPG")$gini_30d))
}

cat("\nAnalysis complete! Table saved as rpg_puzzle_country_comparison.png\n")