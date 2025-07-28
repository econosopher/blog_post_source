# Scopely Revenue Analysis
# Analyzes Scopely's YTD performance for 2024 vs 2025 (Jan-Jun)

# Load required packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  sensortowerR,
  dplyr,
  tidyr,
  ggplot2,
  gt,
  gtExtras,
  scales,
  lubridate,
  purrr,
  here
)

# Set working directory
setwd(here::here())

# Check for API token
if (Sys.getenv("SENSORTOWER_AUTH_TOKEN") == "") {
  stop("Please set SENSORTOWER_AUTH_TOKEN environment variable")
}

# Cache setup
cache_dir <- ".cache"
if (!dir.exists(cache_dir)) {
  dir.create(cache_dir)
}

# Function to check cache freshness (cache for 7 days)
is_cache_fresh <- function(cache_file, max_age_days = 7) {
  if (!file.exists(cache_file)) return(FALSE)
  file_age <- difftime(Sys.time(), file.info(cache_file)$mtime, units = "days")
  return(file_age < max_age_days)
}

# Function to get cached or fresh data
get_cached_or_fetch <- function(cache_name, fetch_function, ...) {
  cache_file <- file.path(cache_dir, paste0(cache_name, "_", Sys.Date(), ".rds"))
  
  if (is_cache_fresh(cache_file)) {
    message(paste("Using cached data for:", cache_name))
    return(readRDS(cache_file))
  }
  
  message(paste("Fetching fresh data for:", cache_name))
  data <- fetch_function(...)
  
  # Save to cache
  saveRDS(data, cache_file)
  
  # Clean old cache files for this data type
  old_files <- list.files(cache_dir, pattern = paste0("^", cache_name, "_.*\\.rds$"), full.names = TRUE)
  old_files <- old_files[old_files != cache_file]
  if (length(old_files) > 0) file.remove(old_files)
  
  return(data)
}

# Scopely's publisher ID (you'll need to find this)
# Let's first search for Scopely in the top publishers
message("Searching for Scopely publisher ID...")

# Function to find Scopely's publisher ID
find_scopely_id <- function() {
  # Check top publishers for the last few months
  months_to_check <- seq(floor_date(Sys.Date() - 30, "month"), 
                        floor_date(Sys.Date() - 180, "month"), 
                        by = "-1 month")
  
  for (month_date in as.Date(months_to_check, origin = "1970-01-01")) {
    message(sprintf("Checking %s...", format(month_date, "%B %Y")))
    
    top_pubs <- tryCatch({
      st_top_publishers(
        measure = "revenue",
        os = "unified",
        category = 6014,  # Games category
        time_range = "month",
        date = month_date,
        country = "WW",
        limit = 100
      )
    }, error = function(e) {
      message(sprintf("Error fetching data for %s: %s", 
                     format(month_date, "%B %Y"), e$message))
      return(NULL)
    })
    
    if (!is.null(top_pubs) && nrow(top_pubs) > 0) {
      # Search for Scopely
      scopely_match <- top_pubs %>%
        filter(grepl("Scopely", publisher_name, ignore.case = TRUE))
      
      if (nrow(scopely_match) > 0) {
        message(sprintf("Found Scopely: %s (ID: %s)", 
                       scopely_match$publisher_name[1], 
                       scopely_match$publisher_id[1]))
        return(scopely_match$publisher_id[1])
      }
    }
    
    Sys.sleep(0.5)  # Rate limiting
  }
  
  return(NULL)
}

# Get Scopely ID
scopely_id <- get_cached_or_fetch("scopely_publisher_id", find_scopely_id)

if (is.null(scopely_id)) {
  stop("Could not find Scopely in top publishers. Please provide the publisher ID manually.")
}

message(sprintf("Using Scopely publisher ID: %s", scopely_id))

# Function to get monthly revenue data for a publisher
get_publisher_monthly_revenue <- function(publisher_id, year, months = 1:6) {
  all_data <- list()
  
  for (month in months) {
    month_start <- as.Date(paste0(year, "-", sprintf("%02d", month), "-01"))
    month_end <- ceiling_date(month_start, "month") - 1
    
    message(sprintf("  Fetching %s %d...", month.name[month], year))
    
    # Try unified endpoint first (for worldwide data)
    month_data <- tryCatch({
      st_sales_report(
        publisher_ids = publisher_id,
        os = "unified",
        countries = "WW",
        start_date = month_start,
        end_date = month_end,
        date_granularity = "monthly",
        auto_segment = FALSE
      )
    }, error = function(e) {
      message("    Unified endpoint failed, trying platform-specific...")
      return(NULL)
    })
    
    # If unified fails, try platform-specific and combine
    if (is.null(month_data) || nrow(month_data) == 0) {
      ios_data <- tryCatch({
        st_sales_report(
          publisher_ids = publisher_id,
          os = "ios",
          countries = "WW",
          start_date = month_start,
          end_date = month_end,
          date_granularity = "monthly",
          auto_segment = FALSE
        )
      }, error = function(e) NULL)
      
      android_data <- tryCatch({
        st_sales_report(
          publisher_ids = publisher_id,
          os = "android", 
          countries = "WW",
          start_date = month_start,
          end_date = month_end,
          date_granularity = "monthly",
          auto_segment = FALSE
        )
      }, error = function(e) NULL)
      
      # Combine platform data
      if (!is.null(ios_data) && !is.null(android_data)) {
        month_data <- bind_rows(ios_data, android_data)
      } else if (!is.null(ios_data)) {
        month_data <- ios_data
      } else if (!is.null(android_data)) {
        month_data <- android_data
      }
    }
    
    if (!is.null(month_data) && nrow(month_data) > 0) {
      all_data[[length(all_data) + 1]] <- month_data
    }
    
    Sys.sleep(0.5)  # Rate limiting
  }
  
  # Combine all months
  if (length(all_data) > 0) {
    combined_data <- bind_rows(all_data)
    return(combined_data)
  }
  
  return(NULL)
}

# Fetch data for both years
message("\nFetching 2024 YTD data (Jan-Jun)...")
revenue_2024 <- get_cached_or_fetch(
  paste0("scopely_revenue_2024_ytd_", scopely_id),
  get_publisher_monthly_revenue,
  publisher_id = scopely_id,
  year = 2024,
  months = 1:6
)

message("\nFetching 2025 YTD data (Jan-Jun)...")
revenue_2025 <- get_cached_or_fetch(
  paste0("scopely_revenue_2025_ytd_", scopely_id),
  get_publisher_monthly_revenue,
  publisher_id = scopely_id,
  year = 2025,
  months = 1:6
)

# Process and aggregate data by game
process_revenue_data <- function(revenue_data, year_label) {
  if (is.null(revenue_data) || nrow(revenue_data) == 0) {
    return(NULL)
  }
  
  # Aggregate by app
  app_summary <- revenue_data %>%
    group_by(app_name, unified_app_id, unified_app_name) %>%
    summarise(
      total_revenue = sum(total_revenue, na.rm = TRUE) / 100,  # Convert cents to dollars
      total_downloads = sum(total_downloads, na.rm = TRUE),
      months_available = n_distinct(date),
      .groups = "drop"
    ) %>%
    mutate(year = year_label) %>%
    # Deduplicate using unified_app_id
    group_by(unified_app_id) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    arrange(desc(total_revenue))
  
  return(app_summary)
}

# Process both years
games_2024 <- process_revenue_data(revenue_2024, "2024")
games_2025 <- process_revenue_data(revenue_2025, "2025")

# Create year-over-year comparison
if (!is.null(games_2024) && !is.null(games_2025)) {
  
  # Join the data
  yoy_comparison <- games_2025 %>%
    select(unified_app_id, unified_app_name, 
           revenue_2025 = total_revenue, 
           downloads_2025 = total_downloads) %>%
    full_join(
      games_2024 %>%
        select(unified_app_id, unified_app_name,
               revenue_2024 = total_revenue,
               downloads_2024 = total_downloads),
      by = "unified_app_id"
    ) %>%
    mutate(
      # Use the most recent game name
      game_name = coalesce(unified_app_name.x, unified_app_name.y),
      # Calculate changes
      revenue_change = (revenue_2025 - revenue_2024) / revenue_2024 * 100,
      revenue_change_abs = revenue_2025 - revenue_2024,
      downloads_change = (downloads_2025 - downloads_2024) / downloads_2024 * 100,
      # Handle new games (no 2024 data)
      is_new_game = is.na(revenue_2024),
      revenue_2024 = replace_na(revenue_2024, 0),
      revenue_2025 = replace_na(revenue_2025, 0),
      downloads_2024 = replace_na(downloads_2024, 0),
      downloads_2025 = replace_na(downloads_2025, 0)
    ) %>%
    arrange(desc(revenue_2025))
  
  # Calculate publisher totals
  publisher_summary <- list(
    revenue_2024_total = sum(games_2024$total_revenue, na.rm = TRUE),
    revenue_2025_total = sum(games_2025$total_revenue, na.rm = TRUE),
    downloads_2024_total = sum(games_2024$total_downloads, na.rm = TRUE),
    downloads_2025_total = sum(games_2025$total_downloads, na.rm = TRUE)
  )
  
  publisher_summary$revenue_change_pct <- 
    (publisher_summary$revenue_2025_total - publisher_summary$revenue_2024_total) / 
    publisher_summary$revenue_2024_total * 100
  
  publisher_summary$downloads_change_pct <- 
    (publisher_summary$downloads_2025_total - publisher_summary$downloads_2024_total) / 
    publisher_summary$downloads_2024_total * 100
  
  # Create GT table
  message("\nCreating summary table...")
  
  summary_table <- yoy_comparison %>%
    slice_head(n = 20) %>%  # Top 20 games
    select(game_name, revenue_2024, revenue_2025, revenue_change, 
           downloads_2024, downloads_2025, downloads_change, is_new_game) %>%
    gt() %>%
    gt_theme_538() %>%
    tab_header(
      title = "Scopely Games: Year-to-Date Performance Comparison",
      subtitle = sprintf("January-June 2025 vs 2024 | Total Revenue: $%.1fM (+%.1f%%)",
                        publisher_summary$revenue_2025_total / 1e6,
                        publisher_summary$revenue_change_pct)
    ) %>%
    cols_label(
      game_name = "Game",
      revenue_2024 = "2024",
      revenue_2025 = "2025", 
      revenue_change = "Change %",
      downloads_2024 = "2024",
      downloads_2025 = "2025",
      downloads_change = "Change %"
    ) %>%
    tab_spanner(
      label = "Revenue (YTD)",
      columns = c(revenue_2024, revenue_2025, revenue_change)
    ) %>%
    tab_spanner(
      label = "Downloads (YTD)",
      columns = c(downloads_2024, downloads_2025, downloads_change)
    ) %>%
    fmt_currency(
      columns = c(revenue_2024, revenue_2025),
      decimals = 0,
      suffixing = TRUE
    ) %>%
    fmt_number(
      columns = c(downloads_2024, downloads_2025),
      decimals = 0,
      suffixing = TRUE
    ) %>%
    fmt_percent(
      columns = c(revenue_change, downloads_change),
      decimals = 0
    ) %>%
    data_color(
      columns = revenue_change,
      method = "numeric",
      palette = c("red", "white", "green"),
      domain = c(-50, 0, 100)
    ) %>%
    tab_style(
      style = cell_text(weight = "bold"),
      locations = cells_body(
        columns = game_name,
        rows = is_new_game == TRUE
      )
    ) %>%
    tab_footnote(
      footnote = "Bold game names indicate new releases in 2025",
      locations = cells_column_labels(columns = game_name)
    ) %>%
    cols_hide(is_new_game)
  
  # Save table
  gtsave(summary_table, "scopely_ytd_comparison_table.png", expand = 10)
  
  # Create visualization
  message("Creating visualization...")
  
  # Prepare data for visualization
  viz_data <- yoy_comparison %>%
    slice_head(n = 10) %>%
    select(game_name, revenue_2024, revenue_2025) %>%
    pivot_longer(cols = c(revenue_2024, revenue_2025), 
                names_to = "year", 
                values_to = "revenue") %>%
    mutate(
      year = gsub("revenue_", "", year),
      game_name = forcats::fct_reorder(game_name, revenue, .desc = FALSE)
    )
  
  # Create grouped bar chart
  p <- ggplot(viz_data, aes(x = revenue, y = game_name, fill = year)) +
    geom_col(position = "dodge", alpha = 0.8) +
    scale_x_continuous(labels = scales::dollar_format(scale = 1e-6, suffix = "M")) +
    scale_fill_manual(values = c("2024" = "#e74c3c", "2025" = "#2ecc71")) +
    labs(
      title = "Scopely Top 10 Games: YTD Revenue Comparison",
      subtitle = "January-June revenue for 2024 vs 2025",
      x = "Revenue (USD Millions)",
      y = NULL,
      fill = "Year"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0),
      plot.subtitle = element_text(size = 12, hjust = 0),
      plot.title.position = "panel",
      plot.subtitle.position = "panel",
      legend.position = "top",
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank()
    )
  
  ggsave("scopely_game_performance_chart.png", p, width = 10, height = 8, dpi = 300)
  
  # Save data for reference
  if (!dir.exists("data")) dir.create("data")
  saveRDS(list(
    yoy_comparison = yoy_comparison,
    publisher_summary = publisher_summary,
    games_2024 = games_2024,
    games_2025 = games_2025
  ), "data/scopely_analysis_data.rds")
  
  # Print summary
  message("\n=== ANALYSIS COMPLETE ===")
  message(sprintf("Scopely YTD Revenue 2024: $%.1f million", 
                 publisher_summary$revenue_2024_total / 1e6))
  message(sprintf("Scopely YTD Revenue 2025: $%.1f million", 
                 publisher_summary$revenue_2025_total / 1e6))
  message(sprintf("Year-over-Year Change: %.1f%%", 
                 publisher_summary$revenue_change_pct))
  message(sprintf("\nTop Game 2025: %s ($%.1fM)", 
                 yoy_comparison$game_name[1],
                 yoy_comparison$revenue_2025[1] / 1e6))
  message("\nOutputs saved:")
  message("  - scopely_ytd_comparison_table.png")
  message("  - scopely_game_performance_chart.png")
  message("  - data/scopely_analysis_data.rds")
  
} else {
  stop("Failed to fetch revenue data for one or both years")
}