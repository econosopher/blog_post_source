# Battlefield Franchise Year-over-Year Analysis
# This script uses the videogameinsightsR package to analyze YoY performance

library(videogameinsightsR)
library(tidyverse)
library(gt)
library(lubridate)

# Source GEC theme from parent directory
source("../../gec_theme/gec_gt_theme.R")

# Create output directory if it doesn't exist
if (!dir.exists("output")) {
  dir.create("output")
}

# Check API key
if (Sys.getenv("VGI_AUTH_TOKEN") == "") {
  stop("VGI_AUTH_TOKEN not found. Please set your API key as an environment variable")
}

# Define known Battlefield games (excluding Bad Company 2)
battlefield_ids <- c(1517290, 1238810, 1238860, 1238840)

# Get current date and determine year-to-date period
current_date <- Sys.Date()
current_year <- year(current_date)
current_month <- month(current_date)
current_day <- day(current_date)

# Set rate limiting for this large request
Sys.setenv(VGI_BATCH_SIZE = "5")   # Conservative batching
Sys.setenv(VGI_BATCH_DELAY = "2")  # 2 second delay between batches

cat("\n=== Battlefield Year-over-Year Analysis ===\n")
cat(paste0("Analyzing last 3 years of data (year-to-date through ", 
           format(current_date, "%B %d"), ")\n"))
cat("Years:", current_year - 2, ",", current_year - 1, ",", current_year, "\n\n")

# Perform year-over-year comparison for the last 3 years
# Note: DAU/MAU data only available from March 18, 2024 onwards
# For now, we'll just show concurrent and revenue metrics
yoy_comparison <- vgi_game_summary_yoy(
  steam_app_ids = battlefield_ids,
  years = c(current_year - 2, current_year - 1, current_year),
  start_month = "January",
  end_date = sprintf("%02d-%02d", current_month, current_day),  # YTD
  metrics = c("concurrent", "revenue")
)

cat(paste0("\n✅ Year-over-year data retrieved. Total API calls: ", 
           yoy_comparison$api_calls, "\n"))
cat(paste0("Period analyzed: ", yoy_comparison$period, "\n\n"))

# Process the comparison data
comparison_data <- yoy_comparison$comparison_table

# Debug: check what columns are available
cat("Available columns:", paste(names(comparison_data), collapse=", "), "\n")

# Create comprehensive YoY table
cat("=== Creating Year-over-Year Comparison Table ===\n")

# Prepare data in wide format with years as columns
wide_data <- comparison_data %>%
  select(name, year, avg_peak_ccu, total_revenue) %>%
  pivot_longer(cols = c(avg_peak_ccu, total_revenue), 
               names_to = "metric", values_to = "value") %>%
  pivot_wider(names_from = year, values_from = value, names_prefix = "year_") %>%
  mutate(
    metric = case_when(
      metric == "avg_peak_ccu" ~ "Avg Peak CCU",
      metric == "total_revenue" ~ "Total Revenue",
      TRUE ~ metric
    )
  )

# Calculate franchise totals
franchise_totals <- comparison_data %>%
  group_by(year) %>%
  summarise(
    avg_peak_ccu = sum(avg_peak_ccu, na.rm = TRUE),
    total_revenue = sum(total_revenue, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = c(avg_peak_ccu, total_revenue), 
               names_to = "metric", values_to = "value") %>%
  pivot_wider(names_from = year, values_from = value, names_prefix = "year_") %>%
  mutate(
    name = "FRANCHISE TOTAL",
    metric = case_when(
      metric == "avg_peak_ccu" ~ "Avg Peak CCU",
      metric == "total_revenue" ~ "Total Revenue",
      TRUE ~ metric
    )
  )

# Combine individual games with franchise totals
final_table_data <- bind_rows(wide_data, franchise_totals) %>%
  arrange(name != "FRANCHISE TOTAL", name, metric)

# Create GT table with GEC theme
yoy_table <- final_table_data %>%
  gt(groupname_col = "name") %>%
  tab_header(
    title = "Battlefield Franchise Performance Analysis",
    subtitle = paste0("Year-to-date metrics through ", format(current_date, "%B %d"), 
                     " for ", current_year - 2, "-", current_year)
  ) %>%
  cols_label(
    metric = "Metric",
    year_2023 = "2023",
    year_2024 = "2024", 
    year_2025 = "2025"
  ) %>%
  # Format columns based on metric type
  fmt(
    columns = starts_with("year_"),
    fns = function(x, rows) {
      metric_name <- final_table_data$metric[rows]
      ifelse(
        metric_name == "Total Revenue",
        paste0("$", format(round(x / 1000000, 1), nsmall = 1), "M"),
        format(round(x), big.mark = ",")
      )
    }
  ) %>%
  # Style franchise total row differently
  tab_style(
    style = list(
      cell_fill(color = gec_colors$primary),
      cell_text(weight = "bold", size = px(14))
    ),
    locations = cells_body(
      rows = name == "FRANCHISE TOTAL"
    )
  ) %>%
  tab_style(
    style = cell_text(weight = "bold", size = px(13)),
    locations = cells_row_groups()
  ) %>%
  # Apply GEC theme
  theme_gec_gt(weight_strategy = "light", line_thickness = "regular") %>%
  tab_source_note(
    source_note = paste0("Data source: Video Game Insights API | API calls: ", 
                        yoy_comparison$api_calls)
  )

# Save the YoY table
gtsave(yoy_table, "output/battlefield_franchise_performance_api.png", 
       vwidth = 1200, vheight = 800)
cat("✅ Franchise performance table saved to output/battlefield_franchise_performance_api.png\n")

# Create game ranking changes visualization
cat("\n=== Analyzing Game Performance Rankings ===\n")

# Rank games by performance within each year
game_rankings <- comparison_data %>%
  group_by(year) %>%
  mutate(
    ccu_rank = rank(-avg_peak_ccu, ties.method = "min"),
    revenue_rank = rank(-total_revenue, ties.method = "min")
  ) %>%
  ungroup() %>%
  select(name, year, ccu_rank, revenue_rank)

# Show current year rankings
current_rankings <- game_rankings %>%
  filter(year == current_year) %>%
  select(-year)

cat("\nCurrent Year Rankings (", current_year, "):\n")
print(current_rankings)

# Print summary insights
cat("\n=== Key Insights ===\n")

# Find biggest YoY changes
biggest_gainers <- comparison_data %>%
  filter(year == current_year, !is.na(avg_peak_ccu_yoy_growth)) %>%
  arrange(desc(avg_peak_ccu_yoy_growth)) %>%
  head(2)

if (nrow(biggest_gainers) > 0) {
  cat("\nBiggest CCU Gainers YoY:\n")
  for (i in 1:nrow(biggest_gainers)) {
    cat(sprintf("- %s: %+.1f%% growth\n", 
                biggest_gainers$name[i], 
                biggest_gainers$avg_peak_ccu_yoy_growth[i]))
  }
}

# Overall franchise CCU trend
franchise_ccu_2024 <- comparison_data %>% filter(year == 2024) %>% summarise(total = sum(avg_peak_ccu)) %>% pull(total)
franchise_ccu_2025 <- comparison_data %>% filter(year == 2025) %>% summarise(total = sum(avg_peak_ccu)) %>% pull(total)
franchise_ccu_change <- (franchise_ccu_2025 - franchise_ccu_2024) / franchise_ccu_2024 * 100
cat(sprintf("\nOverall Franchise CCU Trend: %+.1f%% YoY\n", franchise_ccu_change))

# Clean up
Sys.unsetenv("VGI_BATCH_SIZE")
Sys.unsetenv("VGI_BATCH_DELAY")

if (file.exists("Rplots.pdf")) {
  file.remove("Rplots.pdf")
}

cat("\n=== ANALYSIS COMPLETE ===\n")