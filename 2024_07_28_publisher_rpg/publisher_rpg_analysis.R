# Publisher RPG Analysis with Spider Chart and GT Table
# This script analyzes top mobile game publishers and their revenue distribution across categories

# Install sensortowerR from GitHub if not already installed
# if (!require("devtools")) install.packages("devtools")
# devtools::install_github("econosopher/sensortowerR", force = TRUE)

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
  fmsb,
  gridExtra,
  stringr,
  webshot2,
  purrr
)

# Set your Sensor Tower API key
Sys.setenv(SENSORTOWER_AUTH_TOKEN = "ST0_SRc8L4bf_XHVd6VQUHbvLgQ")

# Cache setup
cache_dir <- ".cache"
if (!dir.exists(cache_dir)) {
  dir.create(cache_dir)
}

# Function to check cache freshness (cache for 24 hours)
is_cache_fresh <- function(cache_file, max_age_hours = 24) {
  if (!file.exists(cache_file)) return(FALSE)
  file_age <- difftime(Sys.time(), file.info(cache_file)$mtime, units = "hours")
  return(file_age < max_age_hours)
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

# Function to create spider chart
create_spider_chart <- function(category_data, top_n = 10) {
  # Prepare data for spider chart
  spider_data <- category_data %>%
    filter(publisher_name %in% unique(publisher_name)[1:top_n]) %>%
    select(publisher_name, category, percentage) %>%
    pivot_wider(names_from = category, values_from = percentage, values_fill = 0)
  
  # Create the plot using ggplot2 with polar coordinates
  p <- category_data %>%
    filter(publisher_name %in% unique(publisher_name)[1:top_n]) %>%
    filter(category != "Games") %>%  # Remove Games category
    ggplot(aes(x = category, y = percentage, group = publisher_name, 
               color = publisher_name, fill = publisher_name)) +
    geom_polygon(alpha = 0.1, linewidth = 0.8) +
    geom_point(size = 2, alpha = 0.8) +
    coord_polar() +
    scale_y_continuous(limits = c(0, 100)) +
    labs(
      title = "Publisher Revenue Distribution by Game Category",
      subtitle = "Percentage of revenue derived from each category",
      x = "",
      y = "Revenue %",
      color = "Publisher",
      fill = "Publisher"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0),
      plot.subtitle = element_text(size = 12, hjust = 0),
      plot.title.position = "panel",
      plot.subtitle.position = "panel",
      axis.text.x = element_text(size = 11, face = "bold"),
      axis.text.y = element_blank(),
      axis.ticks.y = element_blank(),
      panel.grid.major = element_line(color = "gray70", linewidth = 0.5),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.title = element_text(face = "bold", size = 10),
      legend.text = element_text(size = 9),
      legend.key.size = unit(0.8, "lines"),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    ) +
    guides(color = guide_legend(nrow = 2, byrow = TRUE),
           fill = guide_legend(nrow = 2, byrow = TRUE)) +
    scale_color_brewer(palette = "Set2") +
    scale_fill_brewer(palette = "Set2")
  
  return(p)
}

# Function to create GT table with revenue metrics
create_revenue_gt_table <- function(publisher_data, ytd_comparison = NULL, ytd_downloads_comparison = NULL) {
  # Use actual data from API response
  table_data <- publisher_data %>%
    mutate(
      # Keep publisher_id for joining
      publisher_id = publisher_id,
      # Shorten long publisher names
      publisher_name = case_when(
        publisher_name == "Microsoft Corporation" ~ "Microsoft",
        publisher_name == "Take-Two Interactive" ~ "Take-Two",
        publisher_name == "Dream Games, Ltd." ~ "Dream Games",
        publisher_name == "Playtika LTD" ~ "Playtika",
        publisher_name == "FUNFLY PTE. LTD." ~ "FUNFLY",
        TRUE ~ publisher_name
      ),
      # Calculate true market share if total market revenue is available
      market_share = if (!is.na(total_market_revenue) && total_market_revenue > 0) {
        (revenue_180d_ww / total_market_revenue)
      } else {
        # Fallback to share of top 10
        (revenue_180d_ww / sum(revenue_180d_ww, na.rm = TRUE))
      },
      # Use rank if available, otherwise calculate
      rank = if ("rank" %in% names(.)) rank else row_number(),
      # Extract top game and its revenue share
      top_game = if ("apps" %in% names(.) && length(apps) > 0) {
        sapply(apps, function(pub_apps) {
          if (is.data.frame(pub_apps) && nrow(pub_apps) > 0 && "name" %in% names(pub_apps)) {
            game_name <- pub_apps$name[1]  # First app is top revenue generator
            # Shorten long game names
            game_name <- case_when(
              game_name == "Bingo Blitz - Bingo Games" ~ "Bingo Blitz",
              game_name == "Lightning Link Casino Slots" ~ "LL Casino",
              TRUE ~ game_name
            )
            game_name
          } else {
            "N/A"
          }
        })
      } else { rep("N/A", n()) },
      
      # Calculate top game's revenue share of publisher portfolio
      top_game_share = if ("apps" %in% names(.) && length(apps) > 0) {
        mapply(function(pub_apps, total_rev) {
          if (is.data.frame(pub_apps) && nrow(pub_apps) > 0 && "revenue_absolute" %in% names(pub_apps)) {
            # Sum all app revenues for this publisher
            all_app_revenue <- sum(pub_apps$revenue_absolute, na.rm = TRUE)
            top_app_rev <- pub_apps$revenue_absolute[1]
            if (!is.na(top_app_rev) && all_app_revenue > 0) {
              (top_app_rev / all_app_revenue)
            } else {
              NA_real_
            }
          } else {
            NA_real_
          }
        }, apps, revenue_180d_ww)
      } else { rep(NA_real_, n()) },
      
      # Remove country/region columns for US-only data
      
    )
  
  # Calculate YTD YoY change if available
  if (!is.null(ytd_comparison) && !is.null(ytd_downloads_comparison) && 
      nrow(ytd_comparison) > 0 && nrow(ytd_downloads_comparison) > 0) {
    
    # YTD comparison already has the calculated percentages
    ytd_revenue_data <- ytd_comparison %>%
      select(publisher_id, 
             ytd_revenue_change = ytd_change_pct,
             ytd_revenue_total = total_value)  # Keep YTD revenue for ranking
    
    ytd_downloads_data <- ytd_downloads_comparison %>%
      select(publisher_id, 
             ytd_downloads_change = ytd_change_pct)
    
    # Join YTD data
    table_data <- table_data %>%
      left_join(ytd_revenue_data, by = "publisher_id") %>%
      left_join(ytd_downloads_data, by = "publisher_id")
  } else {
    table_data$ytd_revenue_change <- NA_real_
    table_data$ytd_downloads_change <- NA_real_
    table_data$ytd_revenue_total <- NA_real_
  }
  
  # Calculate YTD revenue rank
  if (!is.null(ytd_revenue_2025) && nrow(ytd_revenue_2025) > 0) {
    # Get YTD revenue totals for current year and calculate rank
    ytd_ranks <- ytd_revenue_2025 %>%
      arrange(desc(total_value)) %>%
      mutate(ytd_rank = row_number()) %>%
      select(publisher_id, ytd_rank)
    
    # Join YTD ranks
    table_data <- table_data %>%
      left_join(ytd_ranks, by = "publisher_id")
  } else {
    table_data$ytd_rank <- NA_integer_
  }
  
  # Use API-provided percentage changes and calculate ARPU growth
  table_data <- table_data %>%
    mutate(
      # Use transformed_delta values which are already percentages
      revenue_change = if ("revenue_transformed_delta" %in% names(publisher_data)) {
        publisher_data$revenue_transformed_delta * 100  # Convert to percentage
      } else { NA_real_ },
    )
  
  # Select columns based on what's available in the data
  available_cols <- c("rank", "publisher_name", "revenue_180d_ww", "ytd_rank", "ytd_revenue_change", 
                     "ytd_downloads_change", "revenue_change", 
                     "top_game", "top_game_share")
  
  # Don't add growth or app count columns (removed per request)
  
  table_data <- table_data %>%
    select(all_of(available_cols))
  
  # Create GT table
  gt_table <- table_data %>%
    gt() %>%
    
    # Apply FiveThirtyEight theme
    gt_theme_538() %>%
    
    # Header
    tab_header(
      title = "Top Mobile Game Publishers by Revenue (US Market)",
      subtitle = paste("Monthly US revenue metrics as of", format(Sys.Date(), "%B %Y"))
    ) %>%
    
    # Add spanner columns for logical grouping
    tab_spanner(
      label = "Revenue Metrics",
      columns = c(revenue_180d_ww, revenue_change)
    ) %>%
    tab_spanner(
      label = "YTD YoY Change %",
      columns = c(ytd_revenue_change, ytd_downloads_change)
    ) %>%
    tab_spanner(
      label = "Portfolio Analysis",
      columns = c(top_game, top_game_share)
    ) %>%
    
    # Dynamic column labels based on available columns
    cols_label(
      rank = "",
      publisher_name = "Publisher",
      revenue_180d_ww = "Revenue (30d)",
      ytd_rank = "YTD Rank",
      ytd_revenue_change = "Revenue",
      ytd_downloads_change = "DL",
      revenue_change = "MoM Δ%",
      top_game = "Top Game",
      top_game_share = "Rev % (30d)"
    )
  
  # No additional optional columns needed
  
  # Continue building the table
  gt_table <- gt_table %>%
    
    # Format revenue with suffix
    fmt_currency(
      columns = revenue_180d_ww,
      currency = "USD",
      decimals = 1,
      suffixing = TRUE
    ) %>%
    
    # Format percentage columns
    fmt_percent(
      columns = c(top_game_share),
      decimals = 0
    ) %>%
    
    # Format change columns as percentages (rounded to whole numbers)
    fmt_percent(
      columns = c(ytd_revenue_change, ytd_downloads_change, revenue_change),
      decimals = 0,
      scale_values = FALSE
    ) %>%
    
    # Add heat map coloring to YTD change columns
    # Use extended domain to capture extreme values like 118%
    data_color(
      columns = c(ytd_revenue_change, ytd_downloads_change),
      method = "numeric",
      palette = c("#B71C1C", "#D32F2F", "#E53935", "#FF8A80", "#FFCDD2", "#FFFFFF", "#C8E6C9", "#81C784", "#4CAF50", "#388E3C", "#2E7D32"),
      domain = c(-150, 150),  # Extended domain to capture extreme values properly
      na_color = "#F5F5F5",
      reverse = FALSE
    ) %>%
    
    # Add heat map coloring to revenue change (vs last month)
    data_color(
      columns = revenue_change,
      method = "numeric",
      palette = c("#B71C1C", "#D32F2F", "#E53935", "#FF8A80", "#FFCDD2", "#FFFFFF", "#C8E6C9", "#81C784", "#4CAF50", "#388E3C", "#2E7D32"),
      domain = c(-50, 50),  # Most MoM changes are within this range
      na_color = "#F5F5F5",
      reverse = FALSE
    ) %>%
    
    # Add heat map coloring to top game revenue share (0% white, then green scale)
    data_color(
      columns = top_game_share,
      method = "numeric",
      palette = c("#FFFFFF", "#E8F5E9", "#C8E6C9", "#81C784", "#4CAF50", "#2E7D32"),
      domain = c(0, 100),  # 0% to 100% range
      na_color = "#F5F5F5"
    )
  
  # Add ranking medals
  gt_table <- gt_table %>%
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
          size = px(20),
          weight = "bold",
          color = "#666666"
        )
      ),
      locations = cells_body(columns = rank)
    ) %>%
    
    # Highlight top 3 publishers
    tab_style(
      style = list(
        cell_fill(color = "#F2F2F2"),
        cell_text(weight = "bold")
      ),
      locations = cells_body(
        rows = 1:3,
        columns = publisher_name
      )
    ) %>%
    
    # Add source note
    tab_source_note(
      source_note = md("**Source:** Sensor Tower Store Intelligence | **Note:** Revenue figures are US market estimates. Top game revenue % is based on last 30 days. YTD YoY metrics compare Jan-Jun 2025 vs Jan-Jun 2024.")
    )
  
  # Table options
  gt_table <- gt_table %>%
    tab_options(
      data_row.padding = px(2),  # Reduced from 4
      row.striping.include_table_body = FALSE,
      column_labels.padding = px(4),  # Reduced from 6
      table.font.size = px(14)  # Slightly smaller font
    ) %>%
    
    # Adjust column widths to prevent medal wrapping
    cols_width(
      rank ~ px(60),
      publisher_name ~ px(140),
      revenue_180d_ww ~ px(90),
      ytd_rank ~ px(70),
      ytd_revenue_change ~ px(70),
      ytd_downloads_change ~ px(70),
      revenue_change ~ px(70),
      top_game ~ px(130),
      top_game_share ~ px(80)
    )
  
  return(gt_table)
}

# Main Analysis Script
message("Starting Publisher RPG Analysis...")

# 1. Note about market share calculation
# The Sensor Tower API's games_breakdown endpoint returns revenue by game category,
# not total market revenue. To get true market share, we would need to:
# - Query all game subcategories (7001, 7002, 7003, etc.)
# - Sum revenues across all categories for each country
# - This would require many API calls and might still be incomplete
# 
# Therefore, we calculate market share as percentage of top 10 publishers,
# which provides a consistent relative comparison.
message("Note: Market share calculated as percentage of top 10 publishers")
total_market_revenue <- NA_real_

# 2. Fetch top publishers by revenue (current month)
# NOTE: For efficiency, we use monthly API data instead of making 30 daily calls
# This means we get full calendar month data (e.g., all of June) rather than 
# exact 30-day periods like June 27 - July 26
message("Checking for cached publisher data...")

# Function to fetch publisher data efficiently
fetch_publisher_data_efficient <- function(start_date, end_date, ...) {
  message("Fetching publisher data efficiently...")
  
  # For a 30-day period, just use monthly data
  # The API will aggregate for us
  
  # Determine the best approach based on date range
  days_diff <- as.numeric(difftime(end_date, start_date, units = "days")) + 1
  
  if (days_diff <= 31) {
    # For roughly a month, use monthly endpoint
    # Use the first day of the month containing start_date
    month_start <- floor_date(start_date, "month")
    
    message(sprintf("Using monthly data for %s", format(month_start, "%B %Y")))
    
    publisher_data <- st_top_publishers(
      measure = "revenue",
      os = "unified",
      category = 6014,
      time_range = "month",
      date = month_start,
      country = "US",  # Focus on US market
      limit = 20,  # Get top 20 to ensure we capture movements
      include_apps = TRUE,
      ...
    )
    
    # The data is already aggregated for the month
    # Just need to ensure we have the format expected
    if ("revenue_usd" %in% names(publisher_data)) {
      publisher_data <- publisher_data %>%
        arrange(desc(revenue_usd)) %>%
        head(10)  # Keep top 10
    }
    
    return(publisher_data)
  } else {
    # For longer periods, we might need multiple calls
    # But still use monthly, not daily
    message("Period spans multiple months, fetching monthly data...")
    
    # Get the months we need
    month_starts <- seq(floor_date(start_date, "month"), 
                       floor_date(end_date, "month"), 
                       by = "month")
    
    monthly_results <- list()
    for (i in seq_along(month_starts)) {
      message(sprintf("  Fetching %s...", format(month_starts[i], "%B %Y")))
      
      month_data <- tryCatch({
        st_top_publishers(
          measure = "revenue",
          os = "unified",
          category = 6014,
          time_range = "month",
          date = month_starts[i],
          country = "US",  # Focus on US market
          limit = 50,
          include_apps = TRUE,
          ...
        )
      }, error = function(e) {
        warning(sprintf("Failed to fetch data for %s: %s", month_starts[i], e$message))
        return(NULL)
      })
      
      if (!is.null(month_data) && nrow(month_data) > 0) {
        monthly_results[[i]] <- month_data
      }
      
      Sys.sleep(0.5)  # Rate limiting
    }
    
    # Combine and aggregate
    combined_data <- bind_rows(monthly_results)
    
    aggregated <- combined_data %>%
      group_by(publisher_id, publisher_name) %>%
      summarise(
        revenue_absolute = sum(revenue_absolute, na.rm = TRUE),
        revenue_usd = sum(revenue_usd, na.rm = TRUE),
        units_absolute = sum(units_absolute, na.rm = TRUE),
        apps = list(last(apps)),
        .groups = "drop"
      ) %>%
      arrange(desc(revenue_usd)) %>%
      mutate(rank = row_number()) %>%
      head(10)
    
    # Unnest apps data
    aggregated <- aggregated %>%
      mutate(apps = map(apps, ~ if(is.list(.x)) .x[[1]] else .x))
    
    return(aggregated)
  }
}

# Fetch publisher data
# NOTE: We use monthly data for efficiency (1 API call vs 30)
# This means we get the last full calendar month, not a rolling 30-day window
# For example: If run in late July, we get June data (not June 27 - July 26)
last_month_start <- floor_date(Sys.Date() - 30, "month")
cat("Fetching publisher data for:", format(last_month_start, "%B %Y"), "\n")

top_publishers <- get_cached_or_fetch(
  "top_publishers_monthly",
  fetch_publisher_data_efficient,
  start_date = last_month_start,
  end_date = ceiling_date(last_month_start, "month") - 1,
  auth_token = Sys.getenv("SENSORTOWER_AUTH_TOKEN")
)

# 3. Calculate YTD data efficiently using date ranges
# Determine which month we're in based on the data
current_month_num <- month(last_month_start)
current_year <- year(last_month_start)

message("Fetching YTD data efficiently...")

# Function to fetch and aggregate YTD data using quarterly data to minimize API calls
fetch_ytd_data <- function(year, end_month, measure = "revenue") {
  tryCatch({
    message(sprintf("Fetching YTD %s data for %d (Jan-%s)...", measure, year, month.abb[end_month]))
    
    # Determine which quarters we need
    quarters_needed <- ceiling(end_month / 3)
    results <- list()
    
    # Fetch quarterly data first (much more efficient)
    for (q in 1:quarters_needed) {
      q_start_date <- as.Date(paste0(year, "-", sprintf("%02d", (q-1)*3 + 1), "-01"))
      
      # For the last quarter, check if we need the full quarter
      if (q == quarters_needed && end_month %% 3 != 0) {
        # We need partial quarter data, so fetch monthly for this quarter
        q_start_month <- (q-1) * 3 + 1
        q_end_month <- end_month
        
        for (month_num in q_start_month:q_end_month) {
          month_date <- as.Date(paste0(year, "-", sprintf("%02d", month_num), "-01"))
          
          month_data <- tryCatch({
            st_top_publishers(
              measure = measure,
              os = "unified",
              category = 6014,
              time_range = "month",
              date = month_date,
              country = "US",
              limit = 100,
              include_apps = FALSE
            )
          }, error = function(e) {
            warning(sprintf("Failed to fetch %s for %s: %s", measure, format(month_date, "%B %Y"), e$message))
            return(NULL)
          })
          
          if (!is.null(month_data) && nrow(month_data) > 0) {
            results[[length(results) + 1]] <- month_data
          }
          
          Sys.sleep(0.3)  # Rate limiting
        }
      } else {
        # Fetch full quarter
        quarter_data <- tryCatch({
          st_top_publishers(
            measure = measure,
            os = "unified",
            category = 6014,
            time_range = "quarter",
            date = q_start_date,
            country = "US",
            limit = 100,
            include_apps = FALSE
          )
        }, error = function(e) {
          warning(sprintf("Failed to fetch Q%d %d %s data: %s", q, year, measure, e$message))
          return(NULL)
        })
        
        if (!is.null(quarter_data) && nrow(quarter_data) > 0) {
          results[[length(results) + 1]] <- quarter_data
        }
        
        Sys.sleep(0.3)  # Rate limiting
      }
    }
    
    # Combine all data and aggregate
    if (length(results) > 0) {
      combined_data <- bind_rows(results)
      
      # Filter for our top 10 publishers and aggregate
      ytd_aggregated <- combined_data %>%
        filter(publisher_id %in% top_publishers$publisher_id) %>%
        group_by(publisher_id, publisher_name) %>%
        summarise(
          total_value = sum(if (measure == "revenue") revenue_usd else units_absolute, na.rm = TRUE),
          .groups = "drop"
        )
      
      message(sprintf("  Aggregated data for %d publishers (using %d API calls)", 
                     nrow(ytd_aggregated), length(results)))
      
      return(ytd_aggregated)
    } else {
      message(sprintf("  No data retrieved for %d", year))
      return(NULL)
    }
  }, error = function(e) {
    message(sprintf("Could not fetch YTD %s data for %d: %s", measure, year, e$message))
    NULL
  })
}

# Get YTD revenue data (optimized - uses quarterly data where possible)
message("Fetching YTD revenue data...")
ytd_revenue_2025 <- fetch_ytd_data(current_year, current_month_num, "revenue")
ytd_revenue_2024 <- fetch_ytd_data(current_year - 1, current_month_num, "revenue")

# Calculate YTD revenue comparison
ytd_comparison <- NULL
if (!is.null(ytd_revenue_2025) && !is.null(ytd_revenue_2024)) {
  ytd_comparison <- ytd_revenue_2025 %>%
    inner_join(
      ytd_revenue_2024 %>% 
        select(publisher_id, last_year_value = total_value),
      by = "publisher_id"
    ) %>%
    mutate(
      ytd_change_pct = if_else(
        last_year_value > 0,
        ((total_value - last_year_value) / last_year_value) * 100,
        NA_real_
      )
    )
}

# Get YTD downloads data (optimized - uses quarterly data where possible)
message("Fetching YTD downloads data...")
ytd_downloads_2025 <- fetch_ytd_data(current_year, current_month_num, "units")
ytd_downloads_2024 <- fetch_ytd_data(current_year - 1, current_month_num, "units")

# Special handling for publishers missing from downloads data (e.g., Product Madness)
# These are typically high-ARPU publishers that don't rank in top 100 by downloads
missing_from_downloads <- setdiff(top_publishers$publisher_id, ytd_downloads_2025$publisher_id)

if (length(missing_from_downloads) > 0) {
  message("Fetching individual download data for ", length(missing_from_downloads), " publishers not in top 100...")
  
  # Function to get publisher-specific data
  fetch_publisher_specific_data <- function(publisher_ids, year, end_month, measure = "units") {
    results <- list()
    
    for (pub_id in publisher_ids) {
      pub_data <- NULL
      total_value <- 0
      
      # Try to fetch each month individually for this publisher
      for (month in 1:end_month) {
        month_date <- as.Date(paste0(year, "-", sprintf("%02d", month), "-01"))
        
        tryCatch({
          # Use st_publisher_breakdown to get data for specific publisher
          month_result <- st_publisher_breakdown(
            publisher_ids = pub_id,
            measure = measure,
            time_range = "month",
            date = month_date,
            os = "unified",
            country = "US"
          )
          
          if (!is.null(month_result) && nrow(month_result) > 0) {
            if (measure == "units") {
              total_value <- total_value + sum(month_result$units_absolute, na.rm = TRUE)
            } else {
              total_value <- total_value + sum(month_result$revenue_usd, na.rm = TRUE)
            }
          }
        }, error = function(e) {
          # Silently continue if month data not available
        })
        
        Sys.sleep(0.2)  # Rate limiting
      }
      
      if (total_value > 0) {
        # Get publisher name from top_publishers
        pub_name <- top_publishers$publisher_name[top_publishers$publisher_id == pub_id]
        results[[pub_id]] <- data.frame(
          publisher_id = pub_id,
          publisher_name = pub_name,
          total_value = total_value
        )
      }
    }
    
    if (length(results) > 0) {
      return(bind_rows(results))
    } else {
      return(NULL)
    }
  }
  
  # Fetch missing publisher data for 2025
  missing_2025 <- fetch_publisher_specific_data(missing_from_downloads, current_year, current_month_num, "units")
  if (!is.null(missing_2025)) {
    ytd_downloads_2025 <- bind_rows(ytd_downloads_2025, missing_2025)
  }
  
  # Fetch missing publisher data for 2024
  missing_2024 <- fetch_publisher_specific_data(missing_from_downloads, current_year - 1, current_month_num, "units")
  if (!is.null(missing_2024)) {
    ytd_downloads_2024 <- bind_rows(ytd_downloads_2024, missing_2024)
  }
}

# Calculate YTD downloads comparison
ytd_downloads_comparison <- NULL
if (!is.null(ytd_downloads_2025) && !is.null(ytd_downloads_2024)) {
  # Use full_join to keep all publishers, even if only in one year
  ytd_downloads_comparison <- ytd_downloads_2025 %>%
    full_join(
      ytd_downloads_2024 %>% 
        select(publisher_id, last_year_value = total_value),
      by = "publisher_id"
    ) %>%
    filter(publisher_id %in% top_publishers$publisher_id) %>%  # Only keep our top 10
    mutate(
      total_value = coalesce(total_value, 0),
      last_year_value = coalesce(last_year_value, 0),
      ytd_change_pct = case_when(
        last_year_value > 0 ~ ((total_value - last_year_value) / last_year_value) * 100,
        total_value > 0 & last_year_value == 0 ~ NA_real_,  # No 2024 data - can't calculate
        TRUE ~ NA_real_
      )
    )
}

# Check if we got data
if (is.null(top_publishers) || nrow(top_publishers) == 0) {
  stop("Failed to fetch publisher data from Sensor Tower API. Please check your API token.")
}

# Ensure we have the column names we expect (30-day revenue)
# Since we're aggregating daily data, revenue_usd is already in dollars
if ("revenue_usd" %in% names(top_publishers)) {
  top_publishers <- top_publishers %>%
    rename(revenue_180d_ww = revenue_usd)  # Keep column name for compatibility
}

# Ensure publisher_id is available for joining
if (!("publisher_id" %in% names(top_publishers))) {
  stop("Publisher ID not found in API response")
}

# 2. Generate category breakdown
message("Generating category breakdown...")
# Extract publisher IDs
publisher_ids <- top_publishers$publisher_id

# Use the st_publisher_category_breakdown function with caching
category_breakdown <- get_cached_or_fetch(
  "category_breakdown_monthly_us",  # Update cache key to include country
  st_publisher_category_breakdown,
  publisher_ids = publisher_ids,
  time_range = "month",
  date = last_month_start,  # Use same date as publisher data
  os = "unified",
  country = "US"  # Now supports country filtering!
)

# Map category IDs to names (excluding Games since all are games)
category_names <- c(
  "7001" = "Action",
  "7002" = "Adventure", 
  "7003" = "Arcade",
  "7004" = "Board",
  "7005" = "Card",
  "7006" = "Casino",
  "7014" = "RPG",
  "7015" = "Simulation",
  "7017" = "Strategy",
  "7019" = "Puzzle",
  "7011" = "Music",
  "7012" = "Racing",
  "7013" = "Role Playing",
  "7016" = "Sports",
  "7018" = "Trivia",
  "7020" = "Word"
)

# Process the data
if (!is.null(category_breakdown) && nrow(category_breakdown) > 0) {
  # Filter out the overall Games category (6014) and map names
  category_breakdown <- category_breakdown %>%
    filter(category_id != "6014") %>%  # Remove overall Games category
    mutate(
      # Clean up publisher names for display
      publisher_name = case_when(
        publisher_name == "Microsoft Corporation" ~ "Microsoft",
        publisher_name == "Take-Two Interactive" ~ "Take-Two",
        publisher_name == "Dream Games, Ltd." ~ "Dream Games",
        publisher_name == "Playtika LTD" ~ "Playtika",
        publisher_name == "FUNFLY PTE. LTD." ~ "FUNFLY",
        TRUE ~ publisher_name
      ),
      category = ifelse(as.character(category_id) %in% names(category_names), 
                       category_names[as.character(category_id)], 
                       paste0("Cat_", category_id)),  # Label unknown categories
      percentage = category_percentage,
      revenue_amount = revenue_usd
    ) %>%
    # Normalize percentages to sum to 100 for each publisher
    group_by(publisher_name) %>%
    mutate(
      total_percentage = sum(percentage, na.rm = TRUE),
      percentage = if_else(total_percentage > 0, 
                          (percentage / total_percentage) * 100, 
                          percentage)
    ) %>%
    ungroup() %>%
    select(publisher_name, category, percentage, revenue_amount)
} else {
  stop("Failed to fetch category breakdown data from Sensor Tower API.")
}

# 3. Create visualizations
message("Creating spider chart...")
spider_chart <- create_spider_chart(category_breakdown, top_n = 10)

message("Creating GT table...")
revenue_table <- create_revenue_gt_table(top_publishers, ytd_comparison, ytd_downloads_comparison)

# 4. Save outputs
# Save spider chart as JPEG with white background
ggsave(
  filename = "publisher_rpg_spider_chart.jpg",
  plot = spider_chart,
  width = 12,
  height = 10,
  dpi = 300,
  bg = "white"
)

# Save GT table as PNG (gtsave doesn't support JPEG)
revenue_table %>%
  gtsave(
    filename = "publisher_rpg_revenue_table.png",
    vwidth = 1700,
    vheight = 650  # Reduced from 750
  )

# Display messages
message("\nAnalysis complete!")
message("Spider chart saved to: publisher_rpg_spider_chart.jpg")
message("Revenue table saved to: publisher_rpg_revenue_table.png")

# Optional: Display the visualizations
print(spider_chart)
print(revenue_table)