# ============================================================================
# SUPERVIVE Player Overlap Analysis
# ============================================================================
# This script analyzes player overlap data for SUPERVIVE using the 
# VideoGameInsights R package to understand which games SUPERVIVE players
# are most likely to own compared to average Steam users.
#
# Author: Game Economics Consulting
# Date: 2025-07-29
# ============================================================================

# Load required libraries
library(tidyverse)
library(gt)
library(devtools)
library(dotenv)
library(httr2)
library(jsonlite)

# Load environment variables
dotenv::load_dot_env("../../.env")

# Load VideoGameInsights package
load_all("../../videogameinsightsR")

# Configuration
SUPERVIVE_ID <- 1283700
SUPERVIVE_NAME <- "SUPERVIVE"
OUTPUT_DIR <- "output"

# Create output directory if it doesn't exist
if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR)
}

# Function to fetch game names from API
fetch_game_names <- function(steam_app_ids, limit = 10) {
  # Only fetch names for the most important games (top by overlap index)
  if (length(steam_app_ids) > limit) {
    cat("Limiting game name fetching to top", limit, "games to improve performance\n")
    steam_app_ids <- steam_app_ids[1:limit]
  }
  
  cat("Fetching game names for", length(steam_app_ids), "games...\n")
  
  # Direct API calls since the package functions have issues with nested data
  auth_token <- Sys.getenv("VGI_AUTH_TOKEN")
  base_url <- "https://vginsights.com/api/v3"
  
  game_names <- data.frame(
    steam_app_id = integer(),
    name = character(),
    stringsAsFactors = FALSE
  )
  
  # Fetch each game's metadata
  for (app_id in steam_app_ids) {
    tryCatch({
      endpoint <- paste0("games/", app_id, "/metadata")
      
      req <- httr2::request(base_url) |>
        httr2::req_url_path_append(endpoint) |>
        httr2::req_headers("api-key" = auth_token) |>
        httr2::req_user_agent("videogameinsightsR")
      
      resp <- req |> httr2::req_perform()
      
      if (httr2::resp_status(resp) == 200) {
        raw_response <- httr2::resp_body_string(resp)
        parsed <- jsonlite::fromJSON(raw_response, flatten = TRUE)
        
        if (!is.null(parsed$name)) {
          game_names <- rbind(game_names, data.frame(
            steam_app_id = as.integer(app_id),
            name = parsed$name,
            stringsAsFactors = FALSE
          ))
        }
      }
    }, error = function(e) {
      # Skip this game if lookup fails
      cat("  Failed to fetch metadata for game", app_id, "\n")
    })
  }
  
  if (nrow(game_names) > 0) {
    cat("Successfully fetched", nrow(game_names), "game names\n")
    return(game_names)
  } else {
    cat("Failed to fetch any game names\n")
    return(NULL)
  }
}

# Main analysis function
analyze_supervive_overlap <- function() {
  cat("=== SUPERVIVE PLAYER OVERLAP ANALYSIS ===\n")
  cat("Analyzing player overlap for", SUPERVIVE_NAME, "(Steam App ID:", SUPERVIVE_ID, ")\n\n")
  
  # Get auth token
  auth_token <- Sys.getenv("VGI_AUTH_TOKEN")
  if (auth_token == "") {
    stop("VGI_AUTH_TOKEN environment variable not set. Please set it before running this script.")
  }
  
  # Fetch overlap data using VideoGameInsights package
  cat("Fetching player overlap data from Video Game Insights API...\n")
  
  tryCatch({
    overlap_response <- vgi_player_overlap(steam_app_id = SUPERVIVE_ID, limit = 1000)
    
    # Extract the overlaps data
    if (!is.null(overlap_response$playerOverlaps) && nrow(overlap_response$playerOverlaps) > 0) {
      overlaps <- overlap_response$playerOverlaps
      cat("Successfully retrieved data for", nrow(overlaps), "games\n\n")
    } else {
      stop("No overlap data found")
    }
  }, error = function(e) {
    cat("Error with package function, using direct API call...\n")
    # Fallback to direct API call
    base_url <- "https://vginsights.com/api/v3"
    endpoint <- paste0("player-insights/games/", SUPERVIVE_ID, "/player-overlap")
    
    req <- httr2::request(base_url) |>
      httr2::req_url_path_append(endpoint) |>
      httr2::req_headers("api-key" = auth_token) |>
      httr2::req_url_query(limit = 1000, offset = 0) |>
      httr2::req_user_agent("videogameinsightsR")
    
    resp <- req |> httr2::req_perform()
    raw_response <- httr2::resp_body_string(resp)
    parsed <- jsonlite::fromJSON(raw_response, flatten = TRUE)
    overlaps <<- parsed$playerOverlaps
    cat("Successfully retrieved data for", nrow(overlaps), "games\n\n")
  })
  
  # Fetch game names from API
  cat("\n=== FETCHING GAME METADATA ===\n")
  # Sort by overlap index to get the most important games first
  top_games <- overlaps %>%
    arrange(desc(unitsSoldOverlapIndex)) %>%
    pull(steamAppId)
  
  # Fetch names for top 20 games (will show in tables)
  game_names <- fetch_game_names(top_games, limit = 20)
  
  # Join game names with overlap data
  if (!is.null(game_names) && nrow(game_names) > 0) {
    overlaps_with_names <- overlaps %>%
      left_join(game_names, by = c("steamAppId" = "steam_app_id")) %>%
      mutate(name = ifelse(is.na(name), paste0("Game ", steamAppId), name))
    
    games_with_names <- sum(!is.na(game_names$name))
    cat("Successfully fetched names for", games_with_names, "games\n")
  } else {
    cat("Failed to fetch game names, using IDs only\n")
    overlaps_with_names <- overlaps %>%
      mutate(name = paste0("Game ", steamAppId))
  }
  
  # Display key statistics
  cat("=== KEY STATISTICS ===\n")
  
  # Overlap strength distribution
  overlap_dist <- overlaps_with_names %>%
    mutate(strength_category = case_when(
      unitsSoldOverlapIndex > 3.0 ~ "Very Strong (>3.0)",
      unitsSoldOverlapIndex > 2.0 ~ "Strong (2.0-3.0)",
      unitsSoldOverlapIndex > 1.5 ~ "Moderate (1.5-2.0)",
      unitsSoldOverlapIndex > 1.0 ~ "Slight (1.0-1.5)",
      TRUE ~ "Below Average (<1.0)"
    )) %>%
    count(strength_category) %>%
    mutate(percentage = round(n / sum(n) * 100, 1))
  
  cat("\nOverlap Strength Distribution:\n")
  print(as.data.frame(overlap_dist))
  
  # Top games by overlap index
  cat("\n=== TOP 15 GAMES BY OVERLAP INDEX ===\n")
  cat("(How much more likely SUPERVIVE players are to own these games)\n\n")
  top_by_index <- overlaps_with_names %>%
    arrange(desc(unitsSoldOverlapIndex)) %>%
    head(15) %>%
    select(name, unitsSoldOverlapIndex, unitsSoldOverlapPercentage, medianPlaytime)
  print(as.data.frame(top_by_index))
  
  # Top games by ownership percentage
  cat("\n=== TOP 10 GAMES BY OWNERSHIP PERCENTAGE ===\n")
  cat("(Most popular games among SUPERVIVE players)\n\n")
  top_by_percentage <- overlaps_with_names %>%
    arrange(desc(unitsSoldOverlapPercentage)) %>%
    head(10) %>%
    select(name, unitsSoldOverlapPercentage, unitsSoldOverlapIndex, unitsSoldOverlap)
  print(as.data.frame(top_by_percentage))
  
  # Valve games analysis
  cat("\n=== VALVE GAMES ANALYSIS ===\n")
  valve_games <- overlaps_with_names %>%
    filter(steamAppId %in% c(730, 570, 440, 550, 4000, 620, 240, 10, 220, 420, 320, 500, 300, 70, 80, 130, 400))
  
  if (nrow(valve_games) > 0) {
    valve_summary <- valve_games %>%
      select(name, unitsSoldOverlapPercentage, unitsSoldOverlapIndex) %>%
      arrange(desc(unitsSoldOverlapPercentage))
    cat("\nValve game ownership among SUPERVIVE players:\n")
    print(as.data.frame(valve_summary))
    
    avg_ownership <- mean(valve_games$unitsSoldOverlapPercentage, na.rm = TRUE)
    cat("\nAverage Valve game ownership:", round(avg_ownership, 1), "%\n")
  }
  
  # Export data
  output_file <- file.path(OUTPUT_DIR, "supervive_player_overlap_analysis.csv")
  write_csv(overlaps_with_names, output_file)
  cat("\n=== DATA EXPORT ===\n")
  cat("Full analysis data saved to:", output_file, "\n")
  
  # Create GT table for overlap data
  create_overlap_gt_table(overlaps_with_names)
  
  # Analyze country distribution
  analyze_country_distribution()
  
  # Return the data for further analysis
  invisible(overlaps_with_names)
}

# GT table creation function for overlap data
create_overlap_gt_table <- function(data) {
  cat("\n=== CREATING OVERLAP GT TABLE ===\n")
  
  # Prepare data for GT table - top 20 games
  table_data <- data %>%
    arrange(desc(unitsSoldOverlapIndex)) %>%
    head(20) %>%
    mutate(
      # Format percentages
      overlap_pct_formatted = paste0(round(unitsSoldOverlapPercentage, 1), "%"),
      # Add overlap strength category
      strength = case_when(
        unitsSoldOverlapIndex > 3.0 ~ "Very Strong",
        unitsSoldOverlapIndex > 2.0 ~ "Strong",
        unitsSoldOverlapIndex > 1.5 ~ "Moderate",
        TRUE ~ "Slight"
      )
    ) %>%
    select(
      Game = name,
      `Overlap %` = overlap_pct_formatted,
      `Overlap Index` = unitsSoldOverlapIndex,
      `Strength` = strength,
      `Players` = unitsSoldOverlap,
      `Median Hours` = medianPlaytime
    )
  
  # Create GT table
  overlap_table <- table_data %>%
    gt() %>%
    tab_header(
      title = md("**SUPERVIVE Player Overlap Analysis**"),
      subtitle = md("*Top 20 games by overlap index - How much more likely SUPERVIVE players are to own these games*")
    ) %>%
    fmt_number(
      columns = c(`Overlap Index`),
      decimals = 1
    ) %>%
    fmt_number(
      columns = c(`Players`),
      sep_mark = ",",
      decimals = 0
    ) %>%
    fmt_number(
      columns = c(`Median Hours`),
      decimals = 1
    ) %>%
    # Color code the overlap index
    data_color(
      columns = c(`Overlap Index`),
      fn = scales::col_numeric(
        palette = c("#3498db", "#f39c12", "#2ecc71", "#27ae60"),
        domain = c(1, 4.5)
      )
    ) %>%
    # Color code strength
    data_color(
      columns = c(`Strength`),
      fn = scales::col_factor(
        palette = c("Very Strong" = "#27ae60", 
                   "Strong" = "#2ecc71", 
                   "Moderate" = "#f39c12", 
                   "Slight" = "#3498db"),
        domain = c("Very Strong", "Strong", "Moderate", "Slight")
      )
    ) %>%
    # Style the table
    tab_style(
      style = cell_text(weight = "bold"),
      locations = cells_column_labels()
    ) %>%
    tab_style(
      style = cell_text(size = px(12)),
      locations = cells_body()
    ) %>%
    # Add footnote
    tab_footnote(
      footnote = "Overlap Index: Times more likely to own compared to average Steam user (1.0 = average)",
      locations = cells_column_labels(columns = c(`Overlap Index`))
    ) %>%
    tab_source_note(
      source_note = md("**Source:** Video Game Insights API | **Date:** 2025-07-29")
    ) %>%
    # Apply styling
    tab_options(
      table.font.size = px(14),
      heading.title.font.size = px(20),
      heading.subtitle.font.size = px(16),
      table.width = pct(100)
    )
  
  # Save the table
  output_file <- file.path(OUTPUT_DIR, "supervive_overlap_gt_table.png")
  gtsave(overlap_table, output_file, vwidth = 1200, vheight = 800)
  cat("Overlap GT table saved to:", output_file, "\n")
}

# Country distribution analysis function
analyze_country_distribution <- function() {
  cat("\n=== ANALYZING COUNTRY DISTRIBUTION ===\n")
  
  tryCatch({
    # Fetch country data using VideoGameInsights package
    cat("Fetching country distribution data...\n")
    country_data <- vgi_top_countries(steam_app_id = SUPERVIVE_ID)
    
    if (!is.null(country_data) && nrow(country_data) > 0) {
      # Create country distribution GT table
      create_country_gt_table(country_data)
      
      # Export country data
      output_file <- file.path(OUTPUT_DIR, "supervive_country_distribution.csv")
      write_csv(country_data, output_file)
      cat("Country data saved to:", output_file, "\n")
    } else {
      cat("No country data available for this game.\n")
    }
    
  }, error = function(e) {
    cat("Error fetching country data:", e$message, "\n")
    cat("Country data may not be available for recently released games.\n")
  })
}

# Country GT table creation function
create_country_gt_table <- function(data) {
  cat("\n=== CREATING COUNTRY DISTRIBUTION GT TABLE ===\n")
  
  # Prepare data for GT table - top 20 countries
  table_data <- data %>%
    head(20) %>%
    mutate(
      # Calculate cumulative percentage
      cumulative_pct = cumsum(percentage),
      # Format percentages
      pct_formatted = paste0(round(percentage, 1), "%"),
      cumulative_formatted = paste0(round(cumulative_pct, 1), "%"),
      # Add region classification
      region = case_when(
        country %in% c("US", "CA", "MX") ~ "North America",
        country %in% c("DE", "FR", "GB", "IT", "ES", "PL", "NL", "SE", "BE", "AT", "DK", "FI", "NO", "CH", "CZ", "HU", "RO", "GR", "PT", "IE") ~ "Europe",
        country %in% c("CN", "JP", "KR", "TW", "HK", "SG", "TH", "VN", "MY", "ID", "PH", "IN") ~ "Asia",
        country %in% c("BR", "AR", "CL", "CO", "PE", "VE", "UY", "EC") ~ "South America",
        country %in% c("AU", "NZ") ~ "Oceania",
        country %in% c("RU", "UA", "BY", "KZ") ~ "CIS",
        TRUE ~ "Other"
      )
    ) %>%
    select(
      Rank = rank,
      Country = countryName,
      Code = country,
      Region = region,
      `Player %` = pct_formatted,
      `Cumulative %` = cumulative_formatted,
      `Player Count` = playerCount
    )
  
  # Create GT table
  country_table <- table_data %>%
    gt() %>%
    tab_header(
      title = md("**SUPERVIVE Geographic Distribution**"),
      subtitle = md("*Top 20 countries by player count*")
    ) %>%
    fmt_number(
      columns = c(`Player Count`),
      sep_mark = ",",
      decimals = 0
    ) %>%
    # Color code regions
    data_color(
      columns = c(Region),
      fn = scales::col_factor(
        palette = c(
          "North America" = "#3498db",
          "Europe" = "#2ecc71", 
          "Asia" = "#e74c3c",
          "South America" = "#f39c12",
          "Oceania" = "#9b59b6",
          "CIS" = "#34495e",
          "Other" = "#95a5a6"
        ),
        domain = unique(table_data$Region)
      )
    ) %>%
    # Add sparkline for cumulative percentage
    tab_style(
      style = cell_fill(color = "#ecf0f1"),
      locations = cells_body(columns = c(`Cumulative %`))
    ) %>%
    # Style the table
    tab_style(
      style = cell_text(weight = "bold"),
      locations = cells_column_labels()
    ) %>%
    tab_style(
      style = cell_text(size = px(12)),
      locations = cells_body()
    ) %>%
    # Add summary row
    summary_rows(
      columns = c(`Player Count`),
      fns = list(Total = "sum"),
      fmt = ~ fmt_number(., sep_mark = ",", decimals = 0)
    ) %>%
    # Add footnotes
    tab_footnote(
      footnote = "Cumulative % shows total coverage up to each country",
      locations = cells_column_labels(columns = c(`Cumulative %`))
    ) %>%
    tab_source_note(
      source_note = md("**Source:** Video Game Insights API | **Date:** 2025-07-29")
    ) %>%
    # Apply styling
    tab_options(
      table.font.size = px(14),
      heading.title.font.size = px(20),
      heading.subtitle.font.size = px(16),
      table.width = pct(100),
      summary_row.background.color = "#34495e",
      summary_row.text_transform = "uppercase"
    )
  
  # Save the table
  output_file <- file.path(OUTPUT_DIR, "supervive_country_gt_table.png")
  gtsave(country_table, output_file, vwidth = 1200, vheight = 900)
  cat("Country GT table saved to:", output_file, "\n")
  
  # Print summary statistics
  total_countries <- nrow(data)
  top5_coverage <- sum(head(data$percentage, 5))
  top10_coverage <- sum(head(data$percentage, 10))
  
  cat("\n--- Country Distribution Summary ---\n")
  cat("Total countries with players:", total_countries, "\n")
  cat("Top 5 countries coverage:", round(top5_coverage, 1), "%\n")
  cat("Top 10 countries coverage:", round(top10_coverage, 1), "%\n")
}

# Run the analysis
if (!interactive()) {
  # If running as a script, execute the analysis
  overlaps_data <- analyze_supervive_overlap()
} else {
  # If sourcing in interactive mode, just load the functions
  cat("SUPERVIVE overlap analysis functions loaded.\n")
  cat("Run analyze_supervive_overlap() to perform the analysis.\n")
}