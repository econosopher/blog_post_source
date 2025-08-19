#!/usr/bin/env Rscript

# Lilith Games Portfolio Analysis using sensortowerR API
# Fetches data directly from Sensor Tower API using st_metrics

suppressPackageStartupMessages({
  library(pacman)
  p_load(dplyr, tidyr, readr, gt, webshot2, scales, glue, lubridate, sensortowerR, here)
})

message("=== Lilith Games Portfolio Analysis via Sensor Tower API ===\n")

# Define time periods
ytd_start_2025 <- "2025-01-01"
ytd_end_2025 <- "2025-07-31"
ytd_start_2024 <- "2024-01-01"
ytd_end_2024 <- "2024-07-31"
ytd_start_2023 <- "2023-01-01"
ytd_end_2023 <- "2023-07-31"

# Cache management
cache_dir <- here::here(".cache")
if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
cache_file <- file.path(cache_dir, paste0("lilith_data_", Sys.Date(), ".rds"))

# Check for cached data
if (file.exists(cache_file)) {
  message("Loading cached data from: ", cache_file)
  all_data <- readRDS(cache_file)
} else {
  message("Fetching fresh data from Sensor Tower API...")
  
  # Define Lilith Games titles with their app IDs
  lilith_games <- list(
    "AFK Arena" = list(
      ios = "1410615100", 
      android = "com.lilithgame.hgame.gp",
      name = "AFK Arena"
    ),
    "AFK Journey" = list(
      ios = "6474677358", 
      android = "com.farlight.afkjourney.gp",
      name = "AFK Journey"
    ),
    "Rise of Kingdoms" = list(
      ios = "1354260888", 
      android = "com.lilithgame.roc.gp",
      name = "Rise of Kingdoms"
    ),
    "Call of Dragons" = list(
      ios = "1587649523", 
      android = "com.farlight.dragon.gp",
      name = "Call of Dragons"
    ),
    "Dislyte" = list(
      ios = "1556014103", 
      android = "com.lilithgames.xgame.gp",
      name = "Dislyte"
    ),
    "Warpath" = list(
      ios = "1527625251", 
      android = "com.lilithgame.warpath.gp",
      name = "Warpath"
    ),
    "BLOODLINE: HEROES OF LITHAS" = list(
      ios = "1589847803", 
      android = "com.goatgames.rh",
      name = "BLOODLINE: HEROES OF LITHAS"
    ),
    "Soul Hunters" = list(
      ios = "959841669", 
      android = "com.lilithgame.sgame.gp",
      name = "Soul Hunters"
    ),
    "Art of Conquest: Dark Horizon" = list(
      ios = "1190406643", 
      android = "com.lilithgame.sgame",
      name = "Art of Conquest: Dark Horizon"
    )
  )
  
  # Function to fetch metrics for a single game
  fetch_game_metrics <- function(game_data, year_start, year_end) {
    game_name <- game_data$name
    message(paste("  Fetching", game_name, "for", substr(year_start, 1, 4), "..."))
    
    # Initialize results
    ios_revenue <- 0
    android_revenue <- 0
    ios_downloads <- 0
    android_downloads <- 0
    ios_mau <- 0
    android_mau <- 0
    
    # Fetch iOS data
    if (!is.null(game_data$ios)) {
      ios_result <- tryCatch({
        st_metrics(
          os = "ios",
          ios_app_id = game_data$ios,
          start_date = year_start,
          end_date = year_end,
          countries = "US",
          date_granularity = "monthly",
          verbose = FALSE
        )
      }, error = function(e) {
        message(paste("    iOS error:", e$message))
        NULL
      })
      
      if (!is.null(ios_result) && nrow(ios_result) > 0) {
        # iOS uses total_revenue column
        ios_revenue <- if("total_revenue" %in% names(ios_result)) {
          sum(ios_result$total_revenue, na.rm = TRUE)
        } else {
          sum(ios_result$revenue, na.rm = TRUE)
        }
        ios_downloads <- sum(ios_result$downloads, na.rm = TRUE)
        # Average MAU for the period
        ios_mau <- mean(ios_result$mau, na.rm = TRUE)
      }
    }
    
    # Fetch Android data
    if (!is.null(game_data$android)) {
      android_result <- tryCatch({
        st_metrics(
          os = "android",
          android_app_id = game_data$android,
          start_date = year_start,
          end_date = year_end,
          countries = "US",
          date_granularity = "monthly",
          verbose = FALSE
        )
      }, error = function(e) {
        message(paste("    Android error:", e$message))
        NULL
      })
      
      if (!is.null(android_result) && nrow(android_result) > 0) {
        android_revenue <- sum(android_result$revenue, na.rm = TRUE)
        android_downloads <- sum(android_result$downloads, na.rm = TRUE)
        # Average MAU for the period
        android_mau <- mean(android_result$mau, na.rm = TRUE)
      }
    }
    
    # Combine platforms
    return(data.frame(
      game_name = game_name,
      year = as.integer(substr(year_start, 1, 4)),
      revenue = ios_revenue + android_revenue,
      downloads = ios_downloads + android_downloads,
      mau = ios_mau + android_mau,  # Sum of average MAUs
      stringsAsFactors = FALSE
    ))
  }
  
  # Fetch data for all games and years
  all_results <- list()
  
  for (year_data in list(
    list(start = ytd_start_2025, end = ytd_end_2025),
    list(start = ytd_start_2024, end = ytd_end_2024),
    list(start = ytd_start_2023, end = ytd_end_2023)
  )) {
    for (game_name in names(lilith_games)) {
      game_result <- fetch_game_metrics(
        lilith_games[[game_name]],
        year_data$start,
        year_data$end
      )
      all_results[[length(all_results) + 1]] <- game_result
    }
  }
  
  # Combine all results
  all_data <- bind_rows(all_results)
  
  # Save to cache
  saveRDS(all_data, cache_file)
  message("\nData cached to: ", cache_file)
}

# Reshape data for table
message("\nProcessing data for GT table...")

table_data <- all_data %>%
  pivot_wider(
    id_cols = game_name,
    names_from = year,
    values_from = c(revenue, downloads, mau),
    names_sep = "_",
    values_fill = 0
  )

# Add metadata
table_data <- table_data %>%
  mutate(
    publisher = "Lilith Games",
    source = case_when(
      game_name == "AFK Arena" ~ "Original IP",
      game_name == "AFK Journey" ~ "Sequel",
      game_name == "Rise of Kingdoms" ~ "Original IP",
      game_name == "Call of Dragons" ~ "Sequel",
      game_name == "Dislyte" ~ "Original IP",
      game_name == "Warpath" ~ "Original IP",
      game_name == "BLOODLINE: HEROES OF LITHAS" ~ "Original IP",
      game_name == "Soul Hunters" ~ "Original IP",
      game_name == "Art of Conquest: Dark Horizon" ~ "Original IP",
      TRUE ~ "Original IP"
    ),
    genre = case_when(
      game_name %in% c("AFK Arena", "AFK Journey", "Dislyte", "BLOODLINE: HEROES OF LITHAS", "Soul Hunters") ~ "RPG",
      game_name %in% c("Rise of Kingdoms", "Call of Dragons", "Warpath", "Art of Conquest: Dark Horizon") ~ "Strategy",
      TRUE ~ "Other"
    )
  )

# Calculate growth metrics
table_data <- table_data %>%
  mutate(
    revenue_growth_24_25 = ifelse(revenue_2024 == 0, NA, 
                                  round((revenue_2025 - revenue_2024) / revenue_2024 * 100, 0)),
    downloads_growth_24_25 = ifelse(downloads_2024 == 0, NA, 
                                    round((downloads_2025 - downloads_2024) / downloads_2024 * 100, 0)),
    mau_growth_24_25 = ifelse(mau_2024 == 0, NA, 
                             round((mau_2025 - mau_2024) / mau_2024 * 100, 0))
  ) %>%
  arrange(desc(revenue_2025)) %>%
  mutate(rank = row_number())

# Calculate portfolio total
portfolio_total <- data.frame(
  game_name = "Portfolio Total",
  publisher = "Lilith Games",
  source = "",
  genre = "",
  rank = NA,
  revenue_2023 = sum(table_data$revenue_2023, na.rm = TRUE),
  revenue_2024 = sum(table_data$revenue_2024, na.rm = TRUE),
  revenue_2025 = sum(table_data$revenue_2025, na.rm = TRUE),
  downloads_2023 = sum(table_data$downloads_2023, na.rm = TRUE),
  downloads_2024 = sum(table_data$downloads_2024, na.rm = TRUE),
  downloads_2025 = sum(table_data$downloads_2025, na.rm = TRUE),
  mau_2023 = sum(table_data$mau_2023, na.rm = TRUE),
  mau_2024 = sum(table_data$mau_2024, na.rm = TRUE),
  mau_2025 = sum(table_data$mau_2025, na.rm = TRUE),
  stringsAsFactors = FALSE
) %>%
  mutate(
    revenue_growth_24_25 = ifelse(revenue_2024 == 0, NA,
                                  round((revenue_2025 - revenue_2024) / revenue_2024 * 100, 0)),
    downloads_growth_24_25 = ifelse(downloads_2024 == 0, NA,
                                    round((downloads_2025 - downloads_2024) / downloads_2024 * 100, 0)),
    mau_growth_24_25 = ifelse(mau_2024 == 0, NA,
                             round((mau_2025 - mau_2024) / mau_2024 * 100, 0))
  )

# Combine for final table
final_data <- bind_rows(portfolio_total, table_data)

# Create GT table
message("Creating GT table...")

gt_table <- final_data %>%
  select(rank, game_name, genre, source,
         revenue_2025, revenue_2024, revenue_2023, revenue_growth_24_25,
         mau_2025, mau_2024, mau_2023, mau_growth_24_25,
         downloads_2025, downloads_2024, downloads_2023, downloads_growth_24_25) %>%
  gt() %>%
  tab_header(
    title = "Lilith Games Portfolio Performance",
    subtitle = "US Market YTD Metrics (January - July)"
  ) %>%
  # Format revenue
  fmt(
    columns = c(revenue_2025, revenue_2024, revenue_2023),
    fns = function(x) {
      ifelse(is.na(x) | x == 0, "—",
        ifelse(x >= 1e9, paste0("$", format(round(x/1e9, 1), nsmall = 1), "B"),
        ifelse(x >= 1e6, paste0("$", round(x/1e6), "M"),
        paste0("$", round(x/1e3), "K"))))
    }
  ) %>%
  # Format MAU
  fmt_number(
    columns = c(mau_2025, mau_2024, mau_2023),
    decimals = 0,
    suffixing = TRUE
  ) %>%
  # Format downloads
  fmt_number(
    columns = c(downloads_2025, downloads_2024, downloads_2023),
    decimals = 0,
    suffixing = TRUE
  ) %>%
  # Format growth percentages
  fmt_percent(
    columns = c(revenue_growth_24_25, mau_growth_24_25, downloads_growth_24_25),
    decimals = 0,
    scale_values = FALSE
  ) %>%
  # Replace NA
  sub_missing(
    columns = everything(),
    missing_text = "—"
  ) %>%
  # Column labels
  cols_label(
    rank = "#",
    game_name = "Game",
    genre = "Genre",
    source = "Type",
    revenue_2025 = "2025",
    revenue_2024 = "2024",
    revenue_2023 = "2023",
    revenue_growth_24_25 = "YoY",
    mau_2025 = "2025",
    mau_2024 = "2024",
    mau_2023 = "2023",
    mau_growth_24_25 = "YoY",
    downloads_2025 = "2025",
    downloads_2024 = "2024",
    downloads_2023 = "2023",
    downloads_growth_24_25 = "YoY"
  ) %>%
  # Spanners
  tab_spanner(
    label = "Revenue (YTD)",
    columns = c(revenue_2025, revenue_2024, revenue_2023, revenue_growth_24_25)
  ) %>%
  tab_spanner(
    label = "Average MAU (YTD)",
    columns = c(mau_2025, mau_2024, mau_2023, mau_growth_24_25)
  ) %>%
  tab_spanner(
    label = "Downloads (YTD)",
    columns = c(downloads_2025, downloads_2024, downloads_2023, downloads_growth_24_25)
  ) %>%
  # Style total row
  tab_style(
    style = list(
      cell_text(weight = "bold", size = px(13)),
      cell_fill(color = "#e8e8e8"),
      cell_borders(
        sides = c("top", "bottom"),
        color = "#1a1a1a",
        weight = px(2)
      )
    ),
    locations = cells_body(rows = 1)
  ) %>%
  # Color code growth
  data_color(
    columns = c(revenue_growth_24_25, mau_growth_24_25, downloads_growth_24_25),
    fn = scales::col_numeric(
      palette = c("#d73027", "#fee08b", "#1a9850"),
      domain = c(-100, 100),
      na.color = "transparent"
    )
  ) %>%
  # Add notes
  tab_source_note("Source: Sensor Tower API, US Market") %>%
  tab_source_note("MAU: Average monthly active users | Revenue: iOS + Android combined") %>%
  tab_footnote(
    footnote = "Launched March 2024",
    locations = cells_body(columns = game_name, rows = game_name == "AFK Journey")
  ) %>%
  tab_footnote(
    footnote = "Launched September 2023",
    locations = cells_body(columns = game_name, rows = game_name == "Call of Dragons")
  ) %>%
  # Apply GEC theme
  opt_table_font(
    font = list(
      google_font(name = "Inter"),
      default_fonts()
    )
  ) %>%
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
    source_notes.background.color = "#f5f5f5",
    footnotes.font.size = px(10),
    footnotes.background.color = "#f5f5f5"
  )

# Save table
gtsave(gt_table, "output/lilith_portfolio_api.png", vwidth = 1800, vheight = 1200)

message("\n✓ Portfolio table saved as: output/lilith_portfolio_api.png")

# Print summary
message("\n=== Key Metrics (2025 YTD) ===")
message(glue("Total Revenue: ${format(portfolio_total$revenue_2025/1e9, nsmall = 2)}B"))
message(glue("Total Average MAU: {format(portfolio_total$mau_2025/1e6, nsmall = 1)}M"))
message(glue("Total Downloads: {format(portfolio_total$downloads_2025/1e6, nsmall = 0)}M"))

message("\n=== Year-over-Year Growth (2024-2025) ===")
message(glue("Revenue Growth: {portfolio_total$revenue_growth_24_25}%"))
message(glue("MAU Growth: {portfolio_total$mau_growth_24_25}%"))
message(glue("Downloads Growth: {portfolio_total$downloads_growth_24_25}%"))

# Save data
write.csv(table_data, "output/lilith_api_data.csv", row.names = FALSE)

message("\n✓ Analysis complete!")