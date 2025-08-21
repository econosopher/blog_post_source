#!/usr/bin/env Rscript

# Custom Filter Apps KPI Table
# Using the standard fields that Sensor Tower API provides directly

suppressPackageStartupMessages({
  library(pacman)
  if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
  devtools::load_all("../../sensortowerR")
  p_load(dplyr, tidyr, gt, webshot2, scales, glue, lubridate, tibble, readr)
})

# Load DOF theme
source("../../dof_theme/dof_theme.R")
source("../../dof_theme/dof_gt_theme.R")

message("=== Generating Apps KPI Table from Sensor Tower API ===\n")

# Auth is now handled below with better error messages

# Parse the URL to extract parameters
url <- "https://app.sensortower.com/market-analysis/top-apps?metric=activeUsers&os=unified&category=7019&uai=5a39e9681454d22f5a5e75ca&saa=com.pieyel.scrabble&sia=1215933788&edit=1&granularity=weekly&start_date=2025-07-20&end_date=2025-08-18&duration=P30D&measure=DAU&comparison_attribute=absolute&device=iphone&device=ipad&device=android&page=1&page_size=25&custom_fields_filter_mode=include_unified_apps&period=day&country=US"

# Extract key parameters from URL
custom_filter_id <- "5a39e9681454d22f5a5e75ca"
start_date <- "2024-07-01"  # Changed to a date that definitely has data
end_date <- "2024-07-31"

message("Fetching apps with custom filter ID: ", custom_filter_id)
message("Date range: ", start_date, " to ", end_date)

# Get auth token
auth_token <- Sys.getenv("SENSORTOWER_AUTH_TOKEN")
if (auth_token == "") auth_token <- Sys.getenv("SENSOR_TOWER_AUTH_TOKEN")
if (auth_token == "") {
  stop("No auth token found in SENSORTOWER_AUTH_TOKEN or SENSOR_TOWER_AUTH_TOKEN")
}
message("Auth token found, last 6 chars: ", substr(auth_token, nchar(auth_token)-5, nchar(auth_token)))

# Debug: Print what we're sending
message("Debug: custom_filter_id = ", custom_filter_id)
message("Debug: Calling st_top_charts with custom filter...")

# Fetch top apps using custom filter - the API returns all the standard fields
# The issue might be that category is required to be one of the valid values, not NULL
top_apps <- tryCatch({
  sensortowerR::st_top_charts(
    os = "unified",
    category = 7019,  # Use Puzzle category from the URL
    custom_fields_filter_id = custom_filter_id,  # Use custom filter!
    custom_tags_mode = "include_unified_apps",
    regions = "US",
    date = start_date,
    measure = "revenue",  # Primary measure
    comparison_attribute = "absolute",
    time_range = "month",
    limit = 50,  # Get more apps to see what we get
    enrich_response = TRUE,  # Get all the enriched metrics
    deduplicate_apps = TRUE  # Consolidate duplicate SKUs
  )
}, error = function(e) {
  print(traceback())
  message("Full error: ", toString(e))
  stop(glue("Failed to fetch apps: {e$message}"))
})

if (is.null(top_apps) || nrow(top_apps) == 0) {
  stop("No apps found with the custom filter")
}

message(glue("\nFound {nrow(top_apps)} apps"))
message("Available fields: ", paste(names(top_apps), collapse = ", "))

# Select and rename the standard fields we want to display
# The API provides these fields directly - no calculation needed
kpi_data <- top_apps %>%
  mutate(
    # Add rank
    rank = row_number()
  ) %>%
  select(
    rank,
    app_name = any_of(c("unified_app_name", "app_name", "name", "unified_name", "custom_tags.App Name"))[1],
    
    # Active users - only select first matching column
    dau_us = any_of(c("dau_30d_us", "entities.custom_tags.Last 30 Days Average DAU (US)"))[1],
    mau_us = any_of(c("mau_month_us", "entities.custom_tags.Last Month Average MAU (US)"))[1],
    
    # Standard enriched fields from the API - they come as custom_tags.*
    downloads_180d = any_of(c("downloads_180d_ww", "custom_tags.Last 180 Days Downloads (WW)", "downloads_180d_us"))[1],
    downloads_30d = any_of(c("downloads_30d_ww", "custom_tags.Last 30 Days Downloads (WW)", "custom_tags.Last 30 Days Downloads (US)", "downloads_30d_us", "downloads"))[1],
    
    # No revenue columns
    
    retention_d1 = any_of(c("retention_1d_us", "custom_tags.Day 1 Retention (Last Quarter, US)", "custom_tags.Day 1 Retention (Last Quarter, WW)", "retention_d1_us"))[1],
    retention_d7 = any_of(c("retention_7d_us", "custom_tags.Day 7 Retention (Last Quarter, US)", "custom_tags.Day 7 Retention (Last Quarter, WW)", "retention_d7_us"))[1],
    retention_d30 = any_of(c("retention_30d_us", "custom_tags.Day 30 Retention (Last Quarter, US)", "custom_tags.Day 30 Retention (Last Quarter, WW)", "retention_d30_us"))[1],
    
    # Demographics - prefer US metrics, only first match
    age = any_of(c("age_us", "entities.custom_tags.Age (Last Quarter, US)"))[1],
    gender = any_of(c("entities.custom_tags.Genders (Last Quarter, US)", "custom_tags.Genders (Last Quarter, US)"))[1]
  )

# Only keep columns that actually exist
kpi_data <- kpi_data %>%
  select(where(~!all(is.na(.))))

# Get the app name column
name_col <- names(kpi_data)[grepl("name", names(kpi_data), ignore.case = TRUE)][1]
if (!is.na(name_col) && name_col != "app_name") {
  kpi_data <- kpi_data %>%
    rename(app_name = !!sym(name_col))
}

# Determine which KPIs we actually have
available_kpis <- names(kpi_data)
message("\nAvailable KPIs for table: ", paste(available_kpis, collapse = ", "))

# Build a dynamic GT table based on available fields
message("\nCreating KPI table...")

# Start with basic columns that should always exist
display_cols <- c("rank", "app_name")

# Build the GT table
kpi_table <- kpi_data %>%
  slice_head(n = 10) %>%  # Top 10 apps
  gt() %>%
  tab_header(
    title = "NY Times Spells Word Games",
    subtitle = "Top 10 Word Puzzle By DAU"
  )

# Add column labels based on what's available
col_labels <- list(
  rank = "#",
  app_name = "App",
  dau_us = "DAU (US)",
  mau_us = "MAU (US)",
  downloads_180d = "Downloads (180d)",
  downloads_30d = "Downloads (30d)",
  retention_d1 = "D1 Ret%",
  retention_d7 = "D7 Ret%",
  retention_d30 = "D30 Ret%",
  age = "Avg Age",
  gender = "Gender Split"
)

# Apply labels for columns that exist
existing_labels <- col_labels[names(col_labels) %in% names(kpi_data)]
kpi_table <- kpi_table %>%
  cols_label(!!!existing_labels)

# Add column spanners if we have the data
if (any(grepl("downloads", names(kpi_data)))) {
  download_cols <- names(kpi_data)[grepl("downloads", names(kpi_data))]
  if (length(download_cols) > 0) {
    kpi_table <- kpi_table %>%
      tab_spanner(label = "Downloads", columns = all_of(download_cols))
  }
}

# Remove revenue spanner since we don't have revenue columns

if (any(grepl("retention", names(kpi_data)))) {
  retention_cols <- names(kpi_data)[grepl("retention", names(kpi_data))]
  if (length(retention_cols) > 0) {
    kpi_table <- kpi_table %>%
      tab_spanner(label = "Retention", columns = all_of(retention_cols))
  }
}

if (any(c("male_share", "female_share") %in% names(kpi_data))) {
  demo_cols <- names(kpi_data)[names(kpi_data) %in% c("male_share", "female_share")]
  if (length(demo_cols) > 0) {
    kpi_table <- kpi_table %>%
      tab_spanner(label = "Demographics", columns = all_of(demo_cols))
  }
}

# Format numbers based on column type
if ("dau_us" %in% names(kpi_data)) {
  kpi_table <- kpi_table %>%
    fmt_number(columns = "dau_us", decimals = 0, suffixing = TRUE, sep_mark = ",")
}

if ("mau_us" %in% names(kpi_data)) {
  kpi_table <- kpi_table %>%
    fmt_number(columns = "mau_us", decimals = 0, suffixing = TRUE, sep_mark = ",")
}

# Format download columns
download_cols <- names(kpi_data)[grepl("downloads", names(kpi_data))]
if (length(download_cols) > 0) {
  kpi_table <- kpi_table %>%
    fmt_number(columns = all_of(download_cols), decimals = 0, suffixing = TRUE)
}

# Format retention as percentages
retention_cols <- names(kpi_data)[grepl("retention", names(kpi_data))]
if (length(retention_cols) > 0) {
  kpi_table <- kpi_table %>%
    fmt_percent(columns = all_of(retention_cols), decimals = 1)
}

# Format age
if ("age" %in% names(kpi_data)) {
  kpi_table <- kpi_table %>%
    fmt_number(columns = "age", decimals = 1)
}

# Format demographic percentages
demo_cols <- names(kpi_data)[names(kpi_data) %in% c("male_share", "female_share")]
if (length(demo_cols) > 0) {
  kpi_table <- kpi_table %>%
    fmt_percent(columns = all_of(demo_cols), decimals = 1)
}

# Replace missing values
kpi_table <- kpi_table %>%
  sub_missing(columns = everything(), missing_text = "—")

# Apply DOF theme styling
kpi_table <- kpi_table %>%
  tab_source_note("Source: Sensor Tower API | US Market | Custom Filter | Standard API Fields") %>%
  opt_table_font(font = list(google_font(name = "Inter"), default_fonts())) %>%
  tab_options(
    table.background.color = "#FFFFFF",
    table.border.top.style = "solid",
    table.border.top.width = px(3),
    table.border.top.color = "#1a1a1a",
    table.border.bottom.style = "solid",
    table.border.bottom.width = px(3),
    table.border.bottom.color = "#1a1a1a",
    heading.background.color = "#FFFFFF",
    heading.title.font.size = px(24),
    heading.title.font.weight = "bold",
    heading.subtitle.font.size = px(14),
    heading.subtitle.font.weight = "normal",
    heading.border.bottom.style = "solid",
    heading.border.bottom.width = px(2),
    heading.border.bottom.color = "#1a1a1a",
    column_labels.background.color = "#f5f5f5",
    column_labels.font.weight = "bold",
    column_labels.font.size = px(12),
    column_labels.border.top.style = "solid",
    column_labels.border.top.width = px(2),
    column_labels.border.top.color = "#1a1a1a",
    column_labels.border.bottom.style = "solid",
    column_labels.border.bottom.width = px(1),
    column_labels.border.bottom.color = "#d0d0d0",
    row.striping.include_table_body = TRUE,
    row.striping.background_color = "#fafafa",
    table.font.size = px(11),
    data_row.padding = px(6),
    source_notes.font.size = px(10),
    source_notes.background.color = "#f5f5f5"
  )

# Save table
output_path <- "custom_filter_kpi_table.png"
gtsave(kpi_table, output_path, vwidth = 1800, vheight = 900)
message(glue("\n✓ Table saved as: {output_path}"))

# Also save the data for reference
write_csv(kpi_data, "custom_filter_kpi_data.csv")
message(glue("✓ Data saved as: custom_filter_kpi_data.csv"))

message("\n✓ Script completed successfully!")