#!/usr/bin/env Rscript

# Word Puzzle Games KPI Table
# Top 10 games by DAU with comprehensive metrics

suppressPackageStartupMessages({
  library(pacman)
  if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
  devtools::load_all("../../sensortowerR")
  p_load(dplyr, tidyr, gt, gtExtras, webshot2, scales, glue, lubridate, tibble, readr, stringr)
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
start_date <- "2025-07-20"  # Last 30 days for current data
end_date <- "2025-08-18"

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

# Fetch top apps using custom filter for current period
# Using same approach as RPG analysis but sorting by DAU
top_apps <- tryCatch({
  sensortowerR::st_top_charts(
    os = "unified",
    category = 7019,  # Puzzle category (required with custom filter)
    custom_fields_filter_id = custom_filter_id,
    custom_tags_mode = "include_unified_apps",
    regions = "US",
    date = start_date,
    end_date = end_date,
    measure = "revenue",  # Use revenue endpoint but custom filter handles DAU sorting
    comparison_attribute = "absolute",  # Get absolute values
    time_range = "day",  # Daily granularity like RPG
    limit = 10,  # Only get top 10
    device_type = "total",
    enrich_response = TRUE,
    deduplicate_apps = TRUE
  )
}, error = function(e) {
  print(traceback())
  message("Full error: ", toString(e))
  stop(glue("Failed to fetch apps: {e$message}"))
})

# Also fetch previous period for comparison
prev_start <- "2025-06-20"
prev_end <- "2025-07-19"

message("Fetching previous period data for comparison...")
prev_apps <- tryCatch({
  sensortowerR::st_top_charts(
    os = "unified",
    category = 7019,  # Puzzle category
    custom_fields_filter_id = custom_filter_id,
    custom_tags_mode = "include_unified_apps",
    regions = "US",
    date = prev_start,
    end_date = prev_end,
    measure = "revenue",  # Use revenue endpoint
    comparison_attribute = "absolute",
    time_range = "day",
    limit = 100,  # Get more to capture rank changes
    device_type = "total",
    enrich_response = TRUE,
    deduplicate_apps = TRUE
  )
}, error = function(e) {
  message("Could not fetch previous period data: ", e$message)
  NULL
})

if (is.null(top_apps) || nrow(top_apps) == 0) {
  stop("No apps found with the custom filter")
}

message(glue("\nFound {nrow(top_apps)} apps"))
message("Available fields: ", paste(names(top_apps), collapse = ", "))

# Calculate previous period ranks if available - also sort by DAU
if (!is.null(prev_apps)) {
  prev_ranks <- prev_apps %>%
    arrange(desc(dau_30d_us)) %>%  # Sort by DAU for consistent ranking
    mutate(
      prev_rank = row_number(),
      name_normalized = toupper(str_replace_all(unified_app_name, "[^A-Za-z0-9]", ""))
    ) %>%
    group_by(name_normalized) %>%
    slice_min(prev_rank, n = 1) %>%
    ungroup() %>%
    select(name_normalized, prev_rank)
} else {
  prev_ranks <- NULL
}

# Select and process the data - sort by DAU even though we used revenue endpoint
kpi_data <- top_apps %>%
  arrange(desc(dau_30d_us)) %>%  # Sort by 30-day average DAU
  mutate(
    rank = row_number(),
    name_normalized = toupper(str_replace_all(unified_app_name, "[^A-Za-z0-9]", "")),
    
    # Calculate active rate (DAU/MAU)
    active_rate = dau_30d_us / mau_month_us,
    
    # Get downloads - prefer US metrics
    downloads_30d = if ("downloads_30d_us" %in% names(top_apps)) downloads_30d_us 
                    else if ("entities.units_absolute" %in% names(top_apps)) entities.units_absolute 
                    else NA_real_,
    
    # Calculate DAU growth if we have comparison data
    dau_growth = if ("entities.comparison.dau_30d_us.delta_percentage" %in% names(top_apps)) 
      entities.comparison.dau_30d_us.delta_percentage else NA_real_
  )

# Join with previous ranks if available
if (!is.null(prev_ranks)) {
  kpi_data <- kpi_data %>%
    left_join(prev_ranks, by = "name_normalized") %>%
    mutate(
      rank_change = case_when(
        is.na(prev_rank) ~ NA_real_,
        prev_rank > 50 ~ NA_real_,  # Was below top 50
        TRUE ~ prev_rank - rank
      )
    )
} else {
  kpi_data <- kpi_data %>%
    mutate(rank_change = NA_real_)
}

# Select final columns
kpi_data <- kpi_data %>%
  select(
    rank,
    rank_change,
    app_name = unified_app_name,
    dau_us = dau_30d_us,
    mau_us = mau_month_us,
    dau_growth,
    active_rate,
    downloads_30d,
    retention_d1 = retention_1d_us,
    retention_d7 = retention_7d_us,
    retention_d30 = retention_30d_us,
    age = age_us,
    gender = `entities.custom_tags.Genders (Last Quarter, US)`
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

# Build the GT table
message("\nCreating KPI table...")

kpi_table <- kpi_data %>%
  slice_head(n = 10) %>%  # Top 10 apps by DAU
  gt() %>%
  gt_theme_538() %>%  # Apply 538 theme first
  tab_header(
    title = "Word Puzzle Games Performance",
    subtitle = glue("Top 10 by Daily Active Users | {format(as.Date(start_date), '%B %d')} - {format(as.Date(end_date), '%B %d, %Y')} | US Market")
  )

# Add column labels
col_labels <- list(
  rank = "#",
  rank_change = "Δ",
  app_name = "Game",
  dau_us = "DAU",
  mau_us = "MAU",
  dau_growth = "Growth",
  active_rate = "Active %",
  downloads_30d = "Downloads",
  retention_d1 = "D1",
  retention_d7 = "D7",
  retention_d30 = "D30",
  age = "Age",
  gender = "Gender"
)

# Apply labels for columns that exist
existing_labels <- col_labels[names(col_labels) %in% names(kpi_data %>% slice_head(n = 10))]
kpi_table <- kpi_table %>%
  cols_label(!!!existing_labels)

# Add column spanners for logical grouping - only for columns that exist
available_cols <- names(kpi_data %>% slice_head(n = 10))

if (all(c("dau_us", "mau_us", "active_rate") %in% available_cols)) {
  kpi_table <- kpi_table %>%
    tab_spanner(
      label = "Active Users",
      columns = c(dau_us, mau_us, active_rate)
    )
}

# Downloads column doesn't exist in this data

if (all(c("retention_d1", "retention_d7", "retention_d30") %in% available_cols)) {
  kpi_table <- kpi_table %>%
    tab_spanner(
      label = "Retention",
      columns = c(retention_d1, retention_d7, retention_d30)
    )
}

if (all(c("age", "gender") %in% available_cols)) {
  kpi_table <- kpi_table %>%
    tab_spanner(
      label = "Demographics",
      columns = c(age, gender)
    )
}

# Format columns - only format columns that exist
table_data <- kpi_data %>% slice_head(n = 10)
table_cols <- names(table_data)

# Format DAU and MAU with suffixing
if (all(c("dau_us", "mau_us") %in% table_cols)) {
  kpi_table <- kpi_table %>%
    fmt_number(
      columns = c(dau_us, mau_us),
      decimals = 0,
      suffixing = TRUE
    )
}

# Format downloads with suffixing
if ("downloads_30d" %in% table_cols) {
  kpi_table <- kpi_table %>%
    fmt_number(
      columns = downloads_30d,
      decimals = 0,
      suffixing = TRUE
    )
}

# Format growth as percentage if it exists
if ("dau_growth" %in% table_cols) {
  kpi_table <- kpi_table %>%
    fmt_percent(
      columns = dau_growth,
      decimals = 1
    )
}

# Format active rate as percentage
if ("active_rate" %in% table_cols) {
  kpi_table <- kpi_table %>%
    fmt_percent(
      columns = active_rate,
      decimals = 0
    )
}

# Format retention as percentages (no decimals)
retention_cols <- c("retention_d1", "retention_d7", "retention_d30")
retention_cols_present <- retention_cols[retention_cols %in% table_cols]
if (length(retention_cols_present) > 0) {
  kpi_table <- kpi_table %>%
    fmt_percent(
      columns = all_of(retention_cols_present),
      decimals = 0
    )
}

# Format age
if ("age" %in% table_cols) {
  kpi_table <- kpi_table %>%
    fmt_number(
      columns = age,
      decimals = 0
    )
}

# Format rank change and gender
kpi_table <- kpi_table %>%
  
  # Format rank change
  text_transform(
    locations = cells_body(columns = rank_change),
    fn = function(x) {
      sapply(x, function(val) {
        if (is.na(val) || val == "NA") return("—")
        val_num <- suppressWarnings(as.numeric(val))
        if (is.na(val_num)) return("—")
        if (val_num > 0) {
          paste0("↑", abs(val_num))
        } else if (val_num < 0) {
          paste0("↓", abs(val_num))
        } else {
          "—"
        }
      })
    }
  ) %>%
  
  # Format gender with simplified display
  text_transform(
    locations = cells_body(columns = gender),
    fn = function(x) {
      sapply(x, function(val) {
        if (is.na(val) || val == "") return("—")
        # Parse and simplify gender display
        if (grepl("Female", val)) {
          pct <- gsub("% Female.*", "", val)
          paste0("♀ ", pct, "%")
        } else if (grepl("Male", val)) {
          pct <- gsub("% Male.*", "", val)
          paste0("♂ ", pct, "%")
        } else {
          "—"
        }
      })
    }
  )

# Replace missing values
kpi_table <- kpi_table %>%
  sub_missing(columns = everything(), missing_text = "—")

# Add footnotes and source note
kpi_table <- kpi_table %>%
  tab_source_note(
    source_note = "Source: Sensor Tower API | US Market"
  ) %>%
  tab_footnote(
    footnote = "DAU: Last 30 Days Average Daily Active Users",
    locations = cells_column_labels(columns = dau_us)
  ) %>%
  tab_footnote(
    footnote = "MAU: July 2025 Monthly Active Users",
    locations = cells_column_labels(columns = mau_us)
  ) %>%
  tab_footnote(
    footnote = "Retention: Last Quarter Average (US)",
    locations = cells_column_spanners(spanners = "Retention")
  ) %>%
  tab_footnote(
    footnote = "Δ: Rank change vs previous 30-day period",
    locations = cells_column_labels(columns = rank_change)
  ) %>%
  # Keep 538 theme as base, just adjust a few things
  tab_options(
    table.font.size = px(12),
    data_row.padding = px(6),
    source_notes.font.size = px(10),
    footnotes.font.size = px(9)
  )

# Save table
output_path <- "custom_filter_kpi_table.png"
gtsave(kpi_table, output_path, vwidth = 1800, vheight = 900)
message(glue("\n✓ Table saved as: {output_path}"))

# Also save the data for reference
write_csv(kpi_data, "custom_filter_kpi_data.csv")
message(glue("✓ Data saved as: custom_filter_kpi_data.csv"))

message("\n✓ Script completed successfully!")