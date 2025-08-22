# Optimized RPG Revenue Inequality Analysis
# Uses batch API calls to minimize requests while getting daily data

library(tidyverse)
library(sensortowerR)
library(lubridate)
library(scales)

# Configuration
RPG_CATEGORY_IOS <- 7014  # Role Playing games on iOS
RPG_CATEGORY_ANDROID <- "game_role_playing"  # Role Playing games on Android

# Function to calculate Gini coefficient
calculate_gini <- function(values) {
  values <- values[!is.na(values) & values > 0]
  if (length(values) == 0) return(NA)
  
  values <- sort(values)
  n <- length(values)
  index <- 1:n
  
  gini <- (2 * sum(index * values)) / (n * sum(values)) - (n + 1) / n
  return(gini)
}

# Function to extract app IDs from top charts data
extract_app_ids <- function(top_charts_data) {
  # Get raw data without deduplication to access app IDs
  raw_data <- top_charts_data
  
  # If data was deduplicated, we need to fetch raw data
  if (!"entities.app_id" %in% names(raw_data)) {
    # This means data was deduplicated, need to get platform-specific IDs
    ios_ids <- character()
    android_ids <- character()
    
    # Extract from app names or other available data
    # For now, return empty - would need additional logic to map unified to platform IDs
    return(list(ios = ios_ids, android = android_ids))
  }
  
  # Extract iOS and Android app IDs
  app_ids <- raw_data %>%
    select(app_id = entities.app_id, app_name = app.name) %>%
    mutate(
      platform = case_when(
        grepl("^\\d+$", app_id) ~ "ios",
        grepl("^com\\.", app_id) ~ "android",
        TRUE ~ "unknown"
      )
    ) %>%
    filter(platform != "unknown")
  
  ios_ids <- app_ids %>% filter(platform == "ios") %>% pull(app_id) %>% unique()
  android_ids <- app_ids %>% filter(platform == "android") %>% pull(app_id) %>% unique()
  
  return(list(ios = ios_ids, android = android_ids))
}

# Optimized function to fetch daily data for multiple apps at once
fetch_batch_daily_data <- function(app_ids, os, start_date, end_date, verbose = TRUE) {
  
  if (length(app_ids) == 0) return(NULL)
  
  if (verbose) {
    cat(sprintf("Fetching %s data for %d apps in batch...\n", os, length(app_ids)))
  }
  
  # Use st_sales_report with multiple app IDs
  daily_data <- tryCatch({
    st_sales_report(
      app_ids = app_ids,
      os = os,
      countries = "US",
      start_date = start_date,
      end_date = end_date,
      date_granularity = "daily",
      auto_segment = TRUE,
      verbose = verbose
    )
  }, error = function(e) {
    warning(sprintf("Failed to fetch %s data: %s", os, e$message))
    return(NULL)
  })
  
  if (!is.null(daily_data) && nrow(daily_data) > 0) {
    # Process data based on OS
    if (os == "ios") {
      daily_data <- daily_data %>%
        mutate(
          revenue = if("total_revenue" %in% names(.)) total_revenue else 0,
          platform = "iOS",
          app_id = as.character(app_id)  # Ensure consistent type
        )
    } else {
      daily_data <- daily_data %>%
        mutate(
          revenue = if("revenue" %in% names(.)) revenue else 0,
          platform = "Android",
          app_id = as.character(app_id)  # Ensure consistent type
        )
    }
    
    return(daily_data)
  }
  
  return(NULL)
}

# Main optimized analysis function
run_optimized_rpg_analysis <- function(
  start_date = Sys.Date() - 30,
  end_date = Sys.Date() - 1,
  top_n = 20,
  save_outputs = TRUE,
  verbose = TRUE
) {
  
  cat("Starting Optimized RPG Revenue Inequality Analysis\n")
  cat("==============================================\n\n")
  
  # Step 1: Fetch top RPG games (don't deduplicate to get app IDs)
  if (verbose) cat("Fetching top RPG games...\n")
  
  rpg_market <- st_top_charts(
    measure = "revenue",
    category = RPG_CATEGORY_IOS,
    os = "unified",
    date = end_date,
    limit = top_n,  # Just get top N games
    enrich_response = TRUE,
    deduplicate_apps = TRUE  # Use proper deduplication
  )
  
  if (verbose) cat(sprintf("Retrieved %d app entries\n", nrow(rpg_market)))
  
  # Step 2: Extract unified app IDs from deduplicated data
  if ("unified_app_id" %in% names(rpg_market)) {
    unified_ids <- unique(rpg_market$unified_app_id)
    app_ids <- list(unified = unified_ids)
  } else {
    app_ids <- extract_app_ids(rpg_market)
  }
  
  # If extraction failed, try alternative approach
  if (("unified" %in% names(app_ids) && length(app_ids$unified) == 0) ||
      (!("unified" %in% names(app_ids)) && length(app_ids$ios) == 0 && length(app_ids$android) == 0)) {
    # Get platform-specific data separately
    if (verbose) cat("Fetching platform-specific top charts...\n")
    
    ios_market <- tryCatch({
      st_top_charts(
        measure = "revenue",
        category = RPG_CATEGORY_IOS,
        os = "ios",
        date = end_date,
        limit = top_n,
        enrich_response = TRUE,
        deduplicate_apps = TRUE
      )
    }, error = function(e) NULL)
    
    android_market <- tryCatch({
      st_top_charts(
        measure = "revenue",
        category = RPG_CATEGORY_ANDROID,
        os = "android",
        date = end_date,
        limit = top_n,
        enrich_response = TRUE,
        deduplicate_apps = TRUE
      )
    }, error = function(e) NULL)
    
    if (!is.null(ios_market) && "entities.app_id" %in% names(ios_market)) {
      app_ids$ios <- as.character(unique(ios_market$entities.app_id))
    }
    
    if (!is.null(android_market) && "entities.app_id" %in% names(android_market)) {
      app_ids$android <- as.character(unique(android_market$entities.app_id))
    }
  }
  
  if (verbose) {
    cat(sprintf("Found %d iOS app IDs\n", length(app_ids$ios)))
    cat(sprintf("Found %d Android app IDs\n", length(app_ids$android)))
  }
  
  # Step 3: Fetch daily data in batches
  if (verbose) cat("\nFetching daily revenue data...\n")
  
  all_daily_data <- list()
  
  # If we have unified IDs, use them directly
  if ("unified" %in% names(app_ids) && length(app_ids$unified) > 0) {
    unified_batch <- head(app_ids$unified, top_n)
    unified_daily <- fetch_batch_daily_data(unified_batch, "unified", start_date, end_date, verbose)
    if (!is.null(unified_daily)) {
      all_daily_data$unified <- unified_daily
    }
  } else {
    # Fetch iOS data
    if (length(app_ids$ios) > 0) {
      # Limit to top N iOS apps
      ios_batch <- head(app_ids$ios, top_n)
      ios_daily <- fetch_batch_daily_data(ios_batch, "ios", start_date, end_date, verbose)
      if (!is.null(ios_daily)) {
        all_daily_data$ios <- ios_daily
      }
    }
    
    # Fetch Android data
    if (length(app_ids$android) > 0) {
      # Limit to top N Android apps
      android_batch <- head(app_ids$android, top_n)
      android_daily <- fetch_batch_daily_data(android_batch, "android", start_date, end_date, verbose)
      if (!is.null(android_daily)) {
        all_daily_data$android <- android_daily
      }
    }
  }
  
  # Combine all daily data
  daily_revenue <- bind_rows(all_daily_data)
  
  if (nrow(daily_revenue) == 0) {
    stop("No daily data retrieved")
  }
  
  if (verbose) {
    cat(sprintf("\nTotal daily records: %d\n", nrow(daily_revenue)))
    cat(sprintf("Unique apps: %d\n", n_distinct(daily_revenue$app_id)))
    cat(sprintf("Date range: %s to %s\n", min(daily_revenue$date), max(daily_revenue$date)))
  }
  
  # Step 4: Calculate inequality metrics
  if (verbose) cat("\nCalculating inequality metrics...\n")
  
  daily_metrics <- daily_revenue %>%
    group_by(date) %>%
    summarise(
      n_apps = n_distinct(app_id),
      total_revenue = sum(revenue, na.rm = TRUE),
      mean_revenue = mean(revenue, na.rm = TRUE),
      median_revenue = median(revenue, na.rm = TRUE),
      sd_revenue = sd(revenue, na.rm = TRUE),
      gini = calculate_gini(revenue),
      top_10_pct_share = {
        sorted_rev <- sort(revenue, decreasing = TRUE)
        n10 <- ceiling(length(sorted_rev) * 0.1)
        sum(sorted_rev[1:n10]) / sum(sorted_rev)
      },
      .groups = "drop"
    )
  
  # Step 5: Create visualizations
  if (save_outputs) {
    if (verbose) cat("Creating visualizations...\n")
    
    # 1. Gini coefficient over time
    p1 <- ggplot(daily_metrics, aes(x = date, y = gini)) +
      geom_line(size = 1.2, color = "darkblue") +
      geom_smooth(method = "loess", se = TRUE, alpha = 0.2) +
      scale_y_continuous(limits = c(0, 1)) +
      labs(
        title = "RPG Revenue Inequality Over Time (Optimized)",
        subtitle = sprintf("Daily Gini coefficient for top %d RPG games", top_n),
        x = "Date",
        y = "Gini Coefficient",
        caption = "Source: Sensor Tower API (Batch Processing)"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 16, face = "bold"),
        plot.subtitle = element_text(size = 12)
      )
    
    # 2. Top 10% revenue share
    p2 <- ggplot(daily_metrics, aes(x = date, y = top_10_pct_share * 100)) +
      geom_line(size = 1.2, color = "darkred") +
      geom_smooth(method = "loess", se = TRUE, alpha = 0.2) +
      labs(
        title = "Revenue Concentration in Top 10% of Games",
        subtitle = "Percentage of total revenue earned by top 10% of RPG games",
        x = "Date", 
        y = "Revenue Share (%)",
        caption = "Source: Sensor Tower API (Batch Processing)"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 16, face = "bold"),
        plot.subtitle = element_text(size = 12)
      )
    
    ggsave("rpg_gini_optimized.png", p1, width = 10, height = 6)
    ggsave("rpg_concentration_optimized.png", p2, width = 10, height = 6)
    
    if (verbose) cat("Plots saved to working directory\n")
  }
  
  # Step 6: Generate summary report
  cat("\n========== ANALYSIS SUMMARY ==========\n")
  cat(sprintf("Date Range: %s to %s\n", start_date, end_date))
  cat(sprintf("Apps analyzed: %d\n", n_distinct(daily_revenue$app_id)))
  cat(sprintf("Total observations: %d\n", nrow(daily_revenue)))
  cat(sprintf("API calls made: ~%d (estimated)\n", 
              2 + ceiling(as.numeric(end_date - start_date) / 7) * 2))
  
  cat("\nINEQUALITY METRICS:\n")
  cat(sprintf("  Average Gini coefficient: %.3f\n", mean(daily_metrics$gini, na.rm = TRUE)))
  cat(sprintf("  Gini trend: %s\n", 
              ifelse(cor(as.numeric(daily_metrics$date), daily_metrics$gini) > 0.1, 
                     "Increasing", 
                     ifelse(cor(as.numeric(daily_metrics$date), daily_metrics$gini) < -0.1,
                            "Decreasing", "Stable"))))
  cat(sprintf("  Average top 10%% share: %.1f%%\n", 
              mean(daily_metrics$top_10_pct_share, na.rm = TRUE) * 100))
  
  # Save data if requested
  if (save_outputs) {
    write_csv(daily_metrics, "rpg_inequality_metrics_optimized.csv")
    write_csv(daily_revenue, "rpg_daily_revenue_optimized.csv")
    if (verbose) cat("\nData files saved to working directory\n")
  }
  
  return(list(
    daily_revenue = daily_revenue,
    metrics = daily_metrics,
    summary = list(
      n_apps = n_distinct(daily_revenue$app_id),
      avg_gini = mean(daily_metrics$gini, na.rm = TRUE),
      total_revenue = sum(daily_revenue$revenue, na.rm = TRUE)
    )
  ))
}

# Run optimized analysis
if (interactive()) {
  results <- run_optimized_rpg_analysis(
    start_date = Sys.Date() - 14,
    end_date = Sys.Date() - 1,
    top_n = 10,
    save_outputs = TRUE
  )
}