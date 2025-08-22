#!/usr/bin/env Rscript

# Top RPG Games Analysis - Following Publisher RPG Table Format
# This script creates a GT table with metrics matching the publisher analysis style

# Load packages
library(pacman)
p_load(sensortowerR, tidyverse, gt, gtExtras, scales, lubridate)

# Load cached data
cache_file <- ".cache/rpg_data_2025-08-05.rds"
prev_cache_file <- ".cache/rpg_data_prev_month_2025-08-05.rds"

if (!file.exists(cache_file)) {
  # Fetch fresh data if no cache
  message("Fetching RPG data from Sensor Tower...")
  # Using improved function with automatic deduplication
  rpg_data <- st_top_charts(
    category = 0,  # All categories (custom filter handles RPG filtering)
    custom_fields_filter_id = "60482639241bc16eb8331927",
    custom_tags_mode = "include_unified_apps",
    date = as.Date("2025-07-05"),
    end_date = as.Date("2025-08-03"),
    measure = "revenue",  # Sorted by revenue
    os = "unified",
    regions = "US",  # US market only
    time_range = "day",  # Changed from "month" to match URL period=day
    limit = 50,
    device_type = "total",
    comparison_attribute = "absolute",  # Include comparison data
    enrich_response = TRUE,
    deduplicate_apps = TRUE  # Ensure proper deduplication
  )
  
  # Create cache directory and save
  dir.create(".cache", showWarnings = FALSE)
  saveRDS(rpg_data, cache_file)
} else {
  rpg_data <- readRDS(cache_file)
}

# Fetch previous month data for rank comparison
if (!file.exists(prev_cache_file)) {
  message("Fetching previous month RPG data for rank comparison...")
  # Previous month: June 5 - July 4, 2025
  prev_rpg_data <- st_top_charts(
    category = 0,
    custom_fields_filter_id = "60482639241bc16eb8331927",
    custom_tags_mode = "include_unified_apps",
    date = as.Date("2025-06-05"),
    end_date = as.Date("2025-07-04"),
    measure = "revenue",
    enrich_response = TRUE,
    deduplicate_apps = TRUE,
    os = "unified",
    regions = "US",
    time_range = "day",
    limit = 100,  # Get more to ensure we capture rank changes
    device_type = "total",
    comparison_attribute = "absolute"
  )
  saveRDS(prev_rpg_data, prev_cache_file)
} else {
  prev_rpg_data <- readRDS(prev_cache_file)
}


# Calculate previous month ranks (package handles deduplication)
prev_ranks <- prev_rpg_data %>%
  arrange(desc(entities.revenue_absolute)) %>%
  mutate(
    prev_rank = row_number(),
    # Normalize name for matching
    name_normalized = toupper(str_replace_all(unified_app_name, "[^A-Za-z0-9]", ""))
  ) %>%
  # Keep only the best rank for each normalized name
  group_by(name_normalized) %>%
  slice_min(prev_rank, n = 1) %>%
  ungroup() %>%
  select(name_normalized, prev_rank)

# Process data to match publisher table format
# The sensortowerR package now handles deduplication automatically
table_data <- rpg_data %>%
  # Sort by revenue and take top 20
  arrange(desc(entities.revenue_absolute)) %>%
  slice_head(n = 20) %>%
  mutate(
    # Create rank
    rank = row_number(),
    # Normalize name for matching with previous month
    name_normalized = toupper(str_replace_all(unified_app_name, "[^A-Za-z0-9]", "")),
    
    # Game name (full name)
    game_name = unified_app_name,
    
    # Revenue rank (this is US rank) - move to demographics
    
    # Demographics - including US rank
    gender_split = `entities.custom_tags.Genders (Last Quarter, US)`,
    age_months = age_us,
    
    # Revenue (30d) - this is the actual US 30-day revenue (divide by 100 to get dollars)
    revenue_30d = entities.revenue_absolute / 100,
    
    # Downloads (30d) - US downloads in the last 30 days
    downloads_30d = entities.units_absolute,
    
    # Run rate (annualized based on 30-day revenue)
    run_rate = revenue_30d * 12,
    
    
    # MAU as separate column (use mau_month_us which is the correct field)
    mau_us = mau_month_us,
    
    # ARPMAU calculation
    arpmau = if_else(mau_us > 0, revenue_30d / mau_us, NA_real_),
    
    # Top monetizing country (with better label)
    top_monetizing_geo = `entities.custom_tags.Most Popular Country by Revenue`,
    
    # Lifetime revenue (US market)
    lifetime_revenue = `entities.custom_tags.All Time Revenue (US)`,
    
    # Retention funnel with D60
    retention_d1 = retention_1d_us,
    retention_d7 = retention_7d_us,
    retention_d30 = retention_30d_us,
    retention_d60 = retention_60d_us,
    
    # Keep app ID for YTD lookup
    app_ids = unified_app_id
  ) %>%
  # Join with previous month ranks
  left_join(prev_ranks, by = "name_normalized") %>%
  mutate(
    # Check if game was released in 2025 (for highlighting)
    is_2025_release = case_when(
      !is.na(release_date_us) & year(release_date_us) == 2025 ~ TRUE,
      !is.na(release_date_jp) & year(release_date_jp) == 2025 ~ TRUE,
      !is.na(release_date_ww) & year(release_date_ww) == 2025 ~ TRUE,
      TRUE ~ FALSE
    ),
    
    # Check if game was released during the analysis period (for NEW label)
    is_new_release = case_when(
      !is.na(release_date_us) & release_date_us >= as.Date("2025-07-05") & release_date_us <= as.Date("2025-08-03") ~ TRUE,
      !is.na(release_date_jp) & release_date_jp >= as.Date("2025-07-05") & release_date_jp <= as.Date("2025-08-03") ~ TRUE,
      TRUE ~ FALSE
    ),
    
    # Calculate rank change (positive = moved up, negative = moved down)
    rank_change = case_when(
      is_new_release ~ NA_real_,     # Mark as NEW instead of rank change
      is.na(prev_rank) ~ NA_real_,   # New to top 100
      prev_rank > 100 ~ NA_real_,    # Was below top 100
      TRUE ~ prev_rank - rank
    )
  )

# YTD run rate cannot be calculated - st_batch_metrics fails with unified app IDs from st_top_charts

# Remove the normalized name column
table_data <- table_data %>%
  mutate(name_normalized = NULL)

# Select final columns (reorganized)
table_data <- table_data %>%
  select(
    game_name,
    rank,  # Rank moved next to game name, before revenue
    rank_change,  # Rank change next to rank
    is_new_release,
    is_2025_release,  # For highlighting
    revenue_30d,
    run_rate,  # Keep run rate next to revenue
    lifetime_revenue,  # Added lifetime revenue
    downloads_30d,  # Move downloads next to MAU
    mau_us,
    arpmau,
    top_monetizing_geo,
    retention_d1,
    retention_d7,
    retention_d30,
    retention_d60,
    # Demographics moved after retention
    gender_split,
    age_months
  )

# Create GT table matching publisher style
gt_table <- table_data %>%
  gt() %>%
  
  # Apply FiveThirtyEight theme first (as in publisher table)
  gt_theme_538() %>%
  
  # Header
  tab_header(
    title = "Monthly Squad RPG Report (July, US)",
    subtitle = "30-day period: July 5 - August 3, 2025 | All metrics are US market only | Δ = rank change vs prior 30-day period"
  ) %>%
  
  # Add spanner columns for logical grouping
  tab_spanner(
    label = "Revenue Metrics",
    columns = c(revenue_30d, run_rate, lifetime_revenue)
  ) %>%
  tab_spanner(
    label = "Users",
    columns = c(downloads_30d, mau_us)
  ) %>%
  tab_spanner(
    label = "Monetization",
    columns = c(arpmau, top_monetizing_geo)
  ) %>%
  tab_spanner(
    label = "Cohort Retention",
    columns = c(retention_d1, retention_d7, retention_d30, retention_d60)
  ) %>%
  tab_spanner(
    label = "Demographics",
    columns = c(gender_split, age_months)
  ) %>%
  
  # Column labels
  cols_label(
    game_name = "GAME",
    rank = "#",  # Changed label for rank
    rank_change = "Δ",
    gender_split = "GENDER",
    age_months = "AGE",
    revenue_30d = "REVENUE",
    run_rate = "ANNUAL RUN RATE",
    lifetime_revenue = "LIFETIME",
    downloads_30d = "DOWNLOADS",
    mau_us = "MAU",
    arpmau = "ARPMAU",
    top_monetizing_geo = "TOP $GEO",
    retention_d1 = "D1",
    retention_d7 = "D7",
    retention_d30 = "D30",
    retention_d60 = "D60"
  ) %>%
  
  # Hide the helper columns
  cols_hide(columns = c(is_new_release, is_2025_release)) %>%
  
  # Format revenue with suffix
  fmt_currency(
    columns = c(revenue_30d, run_rate, lifetime_revenue),
    currency = "USD",
    decimals = 1,
    suffixing = TRUE
  ) %>%
  
  # Format downloads
  fmt_number(
    columns = downloads_30d,
    suffixing = TRUE,
    decimals = 0
  ) %>%
  
  # Format MAU
  fmt_number(
    columns = mau_us,
    suffixing = TRUE,
    decimals = 0
  ) %>%
  
  # Format ARPMAU
  fmt_currency(
    columns = arpmau,
    currency = "USD",
    decimals = 2
  ) %>%
  
  
  # Format retention as percentages
  fmt_percent(
    columns = c(retention_d1, retention_d7, retention_d30, retention_d60),
    decimals = 0
  ) %>%
  
  
  # Format age
  fmt_number(
    columns = age_months,
    decimals = 0,
    pattern = "{x}m"
  ) %>%
  
  # Format gender with symbols (♂ for male, ♀ for female)
  text_transform(
    locations = cells_body(columns = gender_split),
    fn = function(x) {
      sapply(x, function(val) {
        if (is.na(val) || val == "") {
          return("–")
        }
        # Parse the percentage and gender
        if (grepl("Male", val)) {
          male_pct <- as.numeric(gsub("% Male.*", "", val))
        } else if (grepl("Female", val)) {
          female_pct <- as.numeric(gsub("% Female.*", "", val))
          male_pct <- 100 - female_pct
        } else {
          return("–")
        }
        # Create visual representation with symbols
        if (male_pct >= 60) {
          # Male dominated
          html(paste0("<span style='color:#1976D2;font-weight:bold'>♂ ", male_pct, "%</span>"))
        } else if (male_pct <= 40) {
          # Female dominated
          female_pct <- 100 - male_pct
          html(paste0("<span style='color:#E91E63;font-weight:bold'>♀ ", female_pct, "%</span>"))
        } else {
          # Balanced
          html(paste0("<span style='color:#666;'>♂ ", male_pct, "%</span>"))
        }
      })
    }
  ) %>%
  
  # Format top geo with symbols and styling
  text_transform(
    locations = cells_body(columns = top_monetizing_geo),
    fn = function(x) {
      sapply(x, function(val) {
        if (is.na(val) || val == "") {
          return("–")
        }
        # Color code and style based on region
        # US = Blue, Asia = Red, Europe = Green, Others = Gray
        geo_colors <- list(
          "US" = "#1976D2",         # Blue for US
          "JP" = "#D32F2F",          # Red for Japan 
          "Japan" = "#D32F2F",       # Red for Japan
          "CN" = "#D32F2F",          # Red for China
          "KR" = "#D32F2F",          # Red for Korea
          "TW" = "#D32F2F",          # Red for Taiwan
          "HK" = "#D32F2F",          # Red for Hong Kong
          "SG" = "#D32F2F",          # Red for Singapore
          "TH" = "#D32F2F",          # Red for Thailand
          "ID" = "#D32F2F",          # Red for Indonesia
          "PH" = "#D32F2F",          # Red for Philippines
          "MY" = "#D32F2F",          # Red for Malaysia
          "VN" = "#D32F2F",          # Red for Vietnam
          "IN" = "#D32F2F",          # Red for India
          "GB" = "#2E7D32",          # Green for UK
          "DE" = "#2E7D32",          # Green for Germany
          "FR" = "#2E7D32",          # Green for France
          "IT" = "#2E7D32",          # Green for Italy
          "ES" = "#2E7D32",          # Green for Spain
          "NL" = "#2E7D32",          # Green for Netherlands
          "SE" = "#2E7D32",          # Green for Sweden
          "PL" = "#2E7D32",          # Green for Poland
          "RU" = "#2E7D32",          # Green for Russia
          "TR" = "#2E7D32",          # Green for Turkey
          "CA" = "#1976D2",          # Blue for Canada (Americas)
          "BR" = "#795548",          # Brown for Brazil
          "MX" = "#795548",          # Brown for Mexico
          "AR" = "#795548",          # Brown for Argentina
          "CL" = "#795548",          # Brown for Chile
          "AU" = "#FF6F00",          # Orange for Australia
          "SA" = "#9C27B0",          # Purple for Saudi Arabia
          "AE" = "#9C27B0"           # Purple for UAE
        )
        
        # Convert Japan to JP for consistency
        display_val <- if (val == "Japan") "JP" else val
        
        # Get color for this geo
        color <- if (val %in% names(geo_colors)) geo_colors[[val]] else "#666"
        
        # Add globe symbol and style the text
        html(paste0(
          "<span style='font-weight:bold;color:", color, ";'>",
          "● ", display_val,
          "</span>"
        ))
      })
    }
  ) %>%
  
  # Format rank change with arrows (or NEW for new releases)
  text_transform(
    locations = cells_body(columns = rank_change),
    fn = function(x) {
      # Get is_new_release values for the same rows
      is_new <- table_data$is_new_release
      
      mapply(function(val, new_release) {
        if (new_release) {
          html("<span style='color:#1976D2;font-weight:bold'>NEW</span>")
        } else {
          val_num <- as.numeric(val)
          if (is.na(val_num)) {
            "–"
          } else if (val_num > 0) {
            html(paste0("<span style='color:#2E7D32;font-weight:bold'>↑", abs(val_num), "</span>"))
          } else if (val_num < 0) {
            html(paste0("<span style='color:#D32F2F;font-weight:bold'>↓", abs(val_num), "</span>"))
          } else {
            "–"
          }
        }
      }, x, is_new, SIMPLIFY = FALSE)
    }
  ) %>%
  
  # Replace missing values with hyphen
  sub_missing(
    columns = everything(),
    missing = "–"
  ) %>%
  
  
  # Add ranking medals
  text_transform(
    locations = cells_body(columns = rank, rows = 1),
    fn = function(x) paste0(x, " 🥇")
  ) %>%
  text_transform(
    locations = cells_body(columns = rank, rows = 2),
    fn = function(x) paste0(x, " 🥈")
  ) %>%
  text_transform(
    locations = cells_body(columns = rank, rows = 3),
    fn = function(x) paste0(x, " 🥉")
  ) %>%
  
  # Style the rank column
  tab_style(
    style = list(
      cell_text(
        size = px(28),
        weight = "bold",
        color = "#666666"
      )
    ),
    locations = cells_body(columns = rank)
  ) %>%
  
  # Highlight top 3 games
  tab_style(
    style = list(
      cell_fill(color = "#F2F2F2"),
      cell_text(weight = "bold")
    ),
    locations = cells_body(
      rows = 1:3,
      columns = game_name
    )
  ) %>%
  
  # Highlight 2025 releases with light blue background
  tab_style(
    style = list(
      cell_fill(color = "#E3F2FD"),  # Light blue background
      cell_text(weight = "bold")
    ),
    locations = cells_body(
      columns = game_name,
      rows = which(table_data$is_2025_release)
    )
  ) %>%
  
  # Add source note
  tab_source_note(
    source_note = md("**Source:** Sensor Tower Store Intelligence | **Note:** Revenue figures are US market 30-day estimates (July 5 - Aug 3). MAU reflects July 2025 monthly active users. ARPMAU = Average Revenue Per Monthly Active User. Δ = Rank change vs prior 30-day period.")
  ) %>%
  
  # Table options (following publisher table exactly)
  tab_options(
    data_row.padding = px(4),
    row.striping.include_table_body = FALSE,
    column_labels.padding = px(6),
    table.font.size = px(16)
  ) %>%
  
  # Adjust column widths
  cols_width(
    game_name ~ px(200),
    rank ~ px(65),  # Increased to prevent collision
    rank_change ~ px(50),
    gender_split ~ px(60),  # Reduced since we're only showing symbol + %
    age_months ~ px(40),
    revenue_30d ~ px(80),
    downloads_30d ~ px(90),
    run_rate ~ px(130),  # Wider for "ANNUAL RUN RATE"
    mau_us ~ px(60),
    arpmau ~ px(70),
    top_monetizing_geo ~ px(60),
    retention_d1 ~ px(35),
    retention_d7 ~ px(35),
    retention_d30 ~ px(35),
    retention_d60 ~ px(35)
  )

# Save the table with LinkedIn-optimized settings
output_path <- "output/top_rpgs_analysis_api.png"
gtsave(
  gt_table,
  filename = output_path,
  vwidth = 1200,  # LinkedIn recommended width
  vheight = 1080,  # Height to fit content
  zoom = 2  # Higher resolution for crisp text
)

message("✓ RPG table saved to: ", output_path)