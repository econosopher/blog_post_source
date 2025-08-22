#!/usr/bin/env Rscript

# Word Puzzle Games KPI Table
# Simple implementation using custom fields filter

suppressPackageStartupMessages({
  library(pacman)
  devtools::load_all("../../sensortowerR")
  p_load(dplyr, gt, gtExtras, scales, glue, stringr)
})

# Load theme if available
tryCatch({
  source("../../dof_theme/dof_gt_theme.R")
}, error = function(e) {
  message("Note: DOF theme not loaded")
})

message("=== Generating Word Puzzle Games KPI Table ===\n")

# Use the custom fields function we built to get Word games
# This is much cleaner and self-documenting
top_apps <- st_get_filtered_apps(
  field_name = "Game Sub-genre",
  field_values = "Word",
  measure = "DAU",
  regions = "US",
  date = "2025-07-21",
  end_date = "2025-08-19",
  limit = 10,
  enrich_response = TRUE
)

message(sprintf("Found %d Word games\n", nrow(top_apps)))

# Extract the metrics we need from the enriched response
# The data is already sorted by DAU from st_top_charts
kpi_data <- top_apps %>%
  # Keep all apps - if API returns them as separate, they are separate
  # Even if they have identical metrics (like the two Bible games)
  mutate(
    rank = row_number(),
    app_name = unified_app_name,
    
    # Core metrics from enrichment - format based on size
    dau = dau_30d_us,
    mau = mau_month_us,
    dau_mau_ratio = dau / mau,
    downloads = downloads_30d_ww,
    revenue = revenue_30d_ww,
    
    # Retention metrics
    d1 = retention_1d_us,
    d7 = retention_7d_us, 
    d30 = retention_30d_us,
    
    # Demographics
    age = round(age_us),
    # Check for gender column and handle missing data
    gender_col = if ("entities.custom_tags.Genders (Last Quarter, US)" %in% names(.)) {
      `entities.custom_tags.Genders (Last Quarter, US)`
    } else if ("aggregate_tags.Genders (Last Quarter, US)" %in% names(.)) {
      `aggregate_tags.Genders (Last Quarter, US)`
    } else {
      NA_character_
    },
    gender_pct = if_else(
      !is.na(gender_col) & grepl("Female", gender_col),
      as.numeric(gsub("([0-9]+)% Female.*", "\\1", gender_col)),
      if_else(
        !is.na(gender_col) & grepl("Male", gender_col),
        100 - as.numeric(gsub("([0-9]+)% Male.*", "\\1", gender_col)),
        NA_real_
      )
    ),
    # Keep raw percentage for coloring logic
    female_pct = gender_pct,
    gender = if_else(
      !is.na(gender_pct),
      paste0("♀ ", gender_pct, "%"),
      "—"
    )
  ) %>%
  select(rank, app_name, dau, mau, dau_mau_ratio, downloads, revenue, 
         d1, d7, d30, age, gender, female_pct)

# Create GT table
kpi_table <- kpi_data %>%
  gt() %>%
  gt_theme_538() %>%
  tab_header(
    title = "TOP WORD PUZZLE GAMES",
    subtitle = "By Daily Active Users | July 21 - August 19, 2025 | US Market"
  ) %>%
  cols_label(
    rank = "#",
    app_name = "Game",
    dau = "DAU",
    mau = "MAU",
    dau_mau_ratio = "Ratio",
    downloads = "Downloads",
    revenue = "Revenue",
    d1 = "D1",
    d7 = "D7",
    d30 = "D30",
    age = "Age",
    gender = "Gender"
  ) %>%
  tab_spanner(
    label = "Active Users",
    columns = c(dau, mau, dau_mau_ratio)
  ) %>%
  tab_spanner(
    label = "Performance",
    columns = c(downloads, revenue)
  ) %>%
  tab_spanner(
    label = "Retention %",
    columns = c(d1, d7, d30)
  ) %>%
  tab_spanner(
    label = "Demographics",
    columns = c(age, gender)
  ) %>%
  fmt_number(
    columns = c(dau, mau),
    suffixing = TRUE,
    decimals = 2
  ) %>%
  fmt_number(
    columns = downloads,
    suffixing = TRUE,
    decimals = 1
  ) %>%
  fmt_currency(
    columns = revenue,
    suffixing = TRUE,
    decimals = 1
  ) %>%
  fmt_percent(
    columns = c(dau_mau_ratio, d1, d7, d30),
    decimals = 0
  ) %>%
  sub_missing(missing_text = "—") %>%
  # Column-specific heatmaps using actual data ranges
  # DAU/MAU ratio - use actual min/max with some padding
  data_color(
    columns = dau_mau_ratio,
    method = "numeric",
    palette = c("#d73027", "#fee08b", "#1a9850"),  # Red to yellow to green
    domain = NULL  # Let it auto-scale to the column's data
  ) %>%
  # D1 retention - column-specific scale
  data_color(
    columns = d1,
    method = "numeric",
    palette = c("#d73027", "#fee08b", "#1a9850"),
    domain = NULL  # Auto-scale to D1 data range
  ) %>%
  # D7 retention - column-specific scale  
  data_color(
    columns = d7,
    method = "numeric",
    palette = c("#d73027", "#fee08b", "#1a9850"),
    domain = NULL  # Auto-scale to D7 data range
  ) %>%
  # D30 retention - column-specific scale
  data_color(
    columns = d30,
    method = "numeric", 
    palette = c("#d73027", "#fee08b", "#1a9850"),
    domain = NULL  # Auto-scale to D30 data range
  ) %>%
  # Gender-based coloring (pink for female-majority, blue for male-majority)
  tab_style(
    style = cell_text(color = "#e91e63", weight = "bold"),  # Pink for female-majority
    locations = cells_body(
      columns = gender,
      rows = female_pct > 50
    )
  ) %>%
  tab_style(
    style = cell_text(color = "#2196f3", weight = "bold"),  # Blue for male-majority
    locations = cells_body(
      columns = gender,
      rows = female_pct <= 50
    )
  ) %>%
  # Hide the helper column
  cols_hide(columns = female_pct) %>%
  tab_source_note("Source: Sensor Tower API | Filter: Game Sub-genre = Word") %>%
  tab_options(
    table.font.size = px(12),
    data_row.padding = px(5)
  )

# Save outputs
gtsave(kpi_table, "word_puzzle_games_table.png", vwidth = 1400, vheight = 700)
write.csv(kpi_data, "word_puzzle_games_data.csv", row.names = FALSE)

message("✓ Table saved as word_puzzle_games_table.png")
message("✓ Data saved as word_puzzle_games_data.csv")

# Summary stats
total_dau <- sum(kpi_data$dau, na.rm = TRUE)
avg_retention <- mean(kpi_data$d7, na.rm = TRUE)
message(sprintf("\nTotal DAU: %s | Avg D7 Retention: %.1f%%", 
                scales::comma(total_dau), avg_retention * 100))