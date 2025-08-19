#!/usr/bin/env Rscript

# Fetch all game data from Video Game Insights API and save to CSV files
# This allows us to work with cached data and avoid repeated API calls

suppressPackageStartupMessages({
  library(pacman)
  p_load(devtools, dplyr, tidyr, readr, stringr, purrr, lubridate, tibble)
})

# Load the videogameinsightsR package (adjust path since we're now in data subfolder)
devtools::load_all("../../../videogameinsightsR")

# Check for VGI API authentication
if (!nzchar(Sys.getenv("VGI_AUTH_TOKEN"))) {
  stop("VGI_AUTH_TOKEN environment variable is required. Set it with Sys.setenv(VGI_AUTH_TOKEN='your_token')")
}

# Determine output directory
args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- if (length(script_path) == 1 && nzchar(script_path)) dirname(normalizePath(script_path)) else getwd()
output_dir <- script_dir

# Read games catalog (script is now in data folder)
games_catalog_file <- file.path(script_dir, "games_catalog.csv")
if (!file.exists(games_catalog_file)) {
  stop("games_catalog.csv not found in data folder. Please create the file with franchise, name, steam_app_id, release_date columns.")
}

games_catalog <- read_csv(games_catalog_file, show_col_types = FALSE) %>%
  mutate(
    release_date = as.Date(release_date),
    steam_app_id = as.integer(steam_app_id)
  ) %>%
  filter(!is.na(steam_app_id), steam_app_id > 0)

message(sprintf("\n=== Fetching data for %d games ===\n", nrow(games_catalog)))

# 1. Fetch and save CCU history data
message("Fetching CCU history data...")
ccu_data_list <- list()

for (i in 1:nrow(games_catalog)) {
  game <- games_catalog[i, ]
  message(sprintf("  %s (ID: %d)...", game$name, game$steam_app_id))
  
  result <- videogameinsightsR::vgi_insights_ccu(game$steam_app_id)
  
  if (!is.null(result$playerHistory)) {
    player_data <- result$playerHistory %>%
      mutate(
        date = as.Date(date),
        game = game$name,
        franchise = game$franchise,
        steam_app_id = game$steam_app_id
      ) %>%
      select(date, game, franchise, steam_app_id, peak_ccu = max, avg_ccu = avg)
    
    ccu_data_list[[length(ccu_data_list) + 1]] <- player_data
    message(sprintf("    ✓ %d days of data", nrow(player_data)))
  } else {
    message("    ✗ No data available")
  }
}

# Combine and save CCU data
if (length(ccu_data_list) > 0) {
  all_ccu_data <- bind_rows(ccu_data_list)
  ccu_file <- file.path(output_dir, "ccu_history_data.csv")
  write_csv(all_ccu_data, ccu_file)
  message(sprintf("\n✓ Saved CCU history to %s (%d rows)", basename(ccu_file), nrow(all_ccu_data)))
}

# 2. Fetch and save pricing/revenue data
message("\nFetching pricing and revenue data...")
pricing_data_list <- list()

for (i in 1:nrow(games_catalog)) {
  game <- games_catalog[i, ]
  message(sprintf("  %s...", game$name))
  
  # Get metadata
  meta <- videogameinsightsR::vgi_game_metadata(game$steam_app_id)
  
  # Get units
  units_data <- videogameinsightsR::vgi_insights_units(game$steam_app_id)
  total_units <- if (!is.null(units_data)) max(units_data$unitsSoldTotal, na.rm = TRUE) else NA
  
  # Get revenue  
  revenue_data <- videogameinsightsR::vgi_insights_revenue(game$steam_app_id)
  total_revenue <- if (!is.null(revenue_data)) max(revenue_data$revenueTotal, na.rm = TRUE) else NA
  
  # Get recent 30-day average
  ccu_data <- videogameinsightsR::vgi_insights_ccu(game$steam_app_id)
  recent_avg <- if (!is.null(ccu_data$playerHistory)) {
    recent <- ccu_data$playerHistory %>%
      mutate(date = as.Date(date)) %>%
      filter(date >= Sys.Date() - 30) %>%
      summarise(avg_30d = mean(avg, na.rm = TRUE))
    round(recent$avg_30d)
  } else NA
  
  pricing_row <- tibble(
    game = game$name,
    franchise = game$franchise,
    steam_app_id = game$steam_app_id,
    current_price = if (!is.null(meta)) meta$price else NA,
    avg_price_api = if (!is.null(meta)) meta$avgPrice else NA,
    lowest_price = if (!is.null(meta)) meta$lowestPrice else NA,
    total_units_steam = total_units,
    total_revenue_steam = total_revenue,
    avg_price_calculated = if (!is.na(total_revenue) && !is.na(total_units) && total_units > 0) {
      total_revenue / total_units
    } else NA,
    recent_avg_30d = recent_avg,
    fetch_date = Sys.Date()
  )
  
  pricing_data_list[[length(pricing_data_list) + 1]] <- pricing_row
}

# Combine and save pricing data
pricing_data <- bind_rows(pricing_data_list)
pricing_file <- file.path(output_dir, "pricing_revenue_data.csv")
write_csv(pricing_data, pricing_file)
message(sprintf("\n✓ Saved pricing/revenue to %s", basename(pricing_file)))

# 3. Fetch and save units sold history
message("\nFetching units sold history...")
units_history_list <- list()

for (i in 1:nrow(games_catalog)) {
  game <- games_catalog[i, ]
  message(sprintf("  %s...", game$name))
  
  units_data <- videogameinsightsR::vgi_insights_units(game$steam_app_id)
  
  if (!is.null(units_data)) {
    units_data <- units_data %>%
      mutate(
        date = as.Date(date),
        game = game$name,
        franchise = game$franchise,
        steam_app_id = game$steam_app_id,
        release_date = game$release_date,
        months_since_launch = round(as.numeric(difftime(date, game$release_date, units = "days")) / 30.44, 2)
      ) %>%
      select(date, game, franchise, steam_app_id, release_date, 
             months_since_launch, units_sold_daily = unitsSold, 
             units_sold_cumulative = unitsSoldTotal)
    
    units_history_list[[length(units_history_list) + 1]] <- units_data
    message(sprintf("    ✓ %d days of data", nrow(units_data)))
  } else {
    message("    ✗ No data available")
  }
}

# Combine and save units history
if (length(units_history_list) > 0) {
  all_units_history <- bind_rows(units_history_list)
  units_file <- file.path(output_dir, "units_history_data.csv")
  write_csv(all_units_history, units_file)
  message(sprintf("\n✓ Saved units history to %s (%d rows)", basename(units_file), nrow(all_units_history)))
}

# 4. Fetch and save revenue history
message("\nFetching revenue history...")
revenue_history_list <- list()

for (i in 1:nrow(games_catalog)) {
  game <- games_catalog[i, ]
  message(sprintf("  %s...", game$name))
  
  revenue_data <- videogameinsightsR::vgi_insights_revenue(game$steam_app_id)
  
  if (!is.null(revenue_data)) {
    revenue_data <- revenue_data %>%
      mutate(
        date = as.Date(date),
        game = game$name,
        franchise = game$franchise,
        steam_app_id = game$steam_app_id
      ) %>%
      select(date, game, franchise, steam_app_id, 
             revenue_daily = revenue, 
             revenue_cumulative = revenueTotal)
    
    revenue_history_list[[length(revenue_history_list) + 1]] <- revenue_data
    message(sprintf("    ✓ %d days of data", nrow(revenue_data)))
  } else {
    message("    ✗ No data available")
  }
}

# Combine and save revenue history
if (length(revenue_history_list) > 0) {
  all_revenue_history <- bind_rows(revenue_history_list)
  revenue_file <- file.path(output_dir, "revenue_history_data.csv")
  write_csv(all_revenue_history, revenue_file)
  message(sprintf("\n✓ Saved revenue history to %s (%d rows)", basename(revenue_file), nrow(all_revenue_history)))
}

# Create a summary report
message("\n=== Data Fetch Summary ===")
message(sprintf("Games processed: %d", nrow(games_catalog)))
if (exists("all_ccu_data")) message(sprintf("CCU data points: %s", format(nrow(all_ccu_data), big.mark = ",")))
if (exists("all_units_history")) message(sprintf("Units history points: %s", format(nrow(all_units_history), big.mark = ",")))
if (exists("all_revenue_history")) message(sprintf("Revenue history points: %s", format(nrow(all_revenue_history), big.mark = ",")))

# Create metadata file with fetch information
metadata <- tibble(
  fetch_timestamp = Sys.time(),
  games_count = nrow(games_catalog),
  ccu_rows = if (exists("all_ccu_data")) nrow(all_ccu_data) else 0,
  units_rows = if (exists("all_units_history")) nrow(all_units_history) else 0,
  revenue_rows = if (exists("all_revenue_history")) nrow(all_revenue_history) else 0,
  api_token_hash = substr(digest::digest(Sys.getenv("VGI_AUTH_TOKEN")), 1, 8)
)

metadata_file <- file.path(output_dir, "data_fetch_metadata.csv")
write_csv(metadata, metadata_file)
message(sprintf("\n✓ Saved metadata to %s", basename(metadata_file)))

message("\n=== All data saved to CSV files ===")
message("You can now run the visualization script using the cached data.")