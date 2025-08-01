# Create GT Table for Candy Crush Saga and Candy Crush Soda Saga
# Using cached data when available to minimize API calls

# Load required libraries
library(sensortowerR)
library(tidyverse)
library(gt)
library(gtExtras)
library(here)

# Create cache directory if it doesn't exist
cache_dir <- here(".cache")
if (!dir.exists(cache_dir)) {
  dir.create(cache_dir)
}

# Cache file path
cache_file <- file.path(cache_dir, paste0("candy_crush_data_", Sys.Date(), ".rds"))

# Check if we have cached data from today
if (file.exists(cache_file)) {
  cat("Using cached data from:", cache_file, "\n")
  candy_data <- readRDS(cache_file)
} else {
  # Running non-interactively, proceed with API call
  cat("No cached data found. Fetching new data from the API...\n")
  
  # Check API authentication
  if (!nzchar(Sys.getenv("SENSOR_TOWER_AUTH_TOKEN"))) {
    stop("Please set your SENSOR_TOWER_AUTH_TOKEN environment variable")
  }
  
  cat("Fetching data from Sensor Tower API...\n")
  
  # Define app IDs
  app_ids <- list(
    candy_crush_saga = list(
      ios = "553834731",
      android = "com.king.candycrushsaga",
      name = "Candy Crush Saga"
    ),
    candy_crush_soda = list(
      ios = "850417475",
      android = "com.king.candycrushsodasaga",
      name = "Candy Crush Soda Saga"
    )
  )
  
  # Fetch metrics for both games
  all_app_ids <- c(
    app_ids$candy_crush_saga$ios,
    app_ids$candy_crush_saga$android,
    app_ids$candy_crush_soda$ios,
    app_ids$candy_crush_soda$android
  )
  
  # Get 6-month cumulative data
  metrics_6m <- st_smart_metrics(
    app_ids = all_app_ids,
    metrics = c("revenue", "downloads", "dau", "mau"),
    date_range = list(
      start_date = Sys.Date() - 180,
      end_date = Sys.Date() - 1
    ),
    countries = "WW",
    date_granularity = "cumulative"
  )
  
  # Get 30-day data
  metrics_30d <- st_smart_metrics(
    app_ids = all_app_ids,
    metrics = c("revenue", "downloads", "dau"),
    date_range = list(
      start_date = Sys.Date() - 30,
      end_date = Sys.Date() - 1
    ),
    countries = "WW",
    date_granularity = "cumulative"
  )
  
  # Combine and save to cache
  candy_data <- list(
    metrics_6m = metrics_6m,
    metrics_30d = metrics_30d,
    fetch_date = Sys.Date()
  )
  
  saveRDS(candy_data, cache_file)
  cat("Data cached to:", cache_file, "\n")
}

# Process the data
process_metrics <- function(metrics_data, period_label) {
  metrics_data %>%
    mutate(
      game_name = case_when(
        str_detect(tolower(unified_app_name), "soda") ~ "Candy Crush Soda Saga",
        TRUE ~ "Candy Crush Saga"
      )
    ) %>%
    group_by(game_name, unified_app_id) %>%
    slice_head(n = 1) %>%  # Deduplicate by unified_app_id
    ungroup() %>%
    group_by(game_name) %>%
    summarise(
      !!paste0("revenue_", period_label) := sum(revenue, na.rm = TRUE),
      !!paste0("downloads_", period_label) := sum(downloads, na.rm = TRUE),
      !!paste0("avg_dau_", period_label) := mean(dau, na.rm = TRUE),
      .groups = "drop"
    )
}

# Process 6-month data
summary_6m <- process_metrics(candy_data$metrics_6m, "6m")

# Process 30-day data
summary_30d <- process_metrics(candy_data$metrics_30d, "30d")

# Get MAU from 6-month data for DAU/MAU ratio
mau_data <- candy_data$metrics_6m %>%
  mutate(
    game_name = case_when(
      str_detect(tolower(unified_app_name), "soda") ~ "Candy Crush Soda Saga",
      TRUE ~ "Candy Crush Saga"
    )
  ) %>%
  group_by(game_name, unified_app_id) %>%
  slice_head(n = 1) %>%
  ungroup() %>%
  group_by(game_name) %>%
  summarise(
    avg_mau = mean(mau, na.rm = TRUE),
    .groups = "drop"
  )

# Combine all data
final_data <- summary_6m %>%
  left_join(mau_data, by = "game_name") %>%
  left_join(summary_30d, by = "game_name") %>%
  mutate(
    arpu_6m = revenue_6m / downloads_6m,
    dau_mau_ratio = avg_dau_6m / avg_mau,
    revenue_per_dau_6m = revenue_6m / (avg_dau_6m * 180),  # Daily revenue per DAU
    downloads_per_day_6m = downloads_6m / 180,
    downloads_per_day_30d = downloads_30d / 30
  ) %>%
  arrange(desc(revenue_6m))

# Create the GT table with GEC theme
candy_crush_table <- final_data %>%
  gt() %>%
  # Title and subtitle
  tab_header(
    title = "Candy Crush Games Performance Comparison",
    subtitle = paste("King's Match-3 Titans | Data through", format(Sys.Date() - 1, "%B %d, %Y"))
  ) %>%
  # Column labels
  cols_label(
    game_name = "Game",
    revenue_6m = "Revenue",
    downloads_6m = "Downloads",
    avg_dau_6m = "Avg DAU",
    avg_mau = "Avg MAU",
    arpu_6m = "ARPU",
    dau_mau_ratio = "Stickiness",
    revenue_per_dau_6m = "Rev/DAU",
    downloads_per_day_6m = "DL/Day",
    revenue_30d = "Revenue",
    downloads_30d = "Downloads",
    avg_dau_30d = "Avg DAU",
    downloads_per_day_30d = "DL/Day"
  ) %>%
  # Hide some calculated columns we don't need to show
  cols_hide(columns = c(downloads_per_day_6m)) %>%
  # Format numbers
  fmt_currency(
    columns = c(revenue_6m, revenue_30d, arpu_6m, revenue_per_dau_6m),
    currency = "USD",
    decimals = 0
  ) %>%
  fmt_number(
    columns = c(downloads_6m, downloads_30d, downloads_per_day_30d),
    decimals = 0,
    use_seps = TRUE,
    compact = TRUE
  ) %>%
  fmt_number(
    columns = c(avg_dau_6m, avg_mau, avg_dau_30d),
    decimals = 0,
    use_seps = TRUE,
    suffixing = TRUE  # Use K, M suffixes
  ) %>%
  fmt_percent(
    columns = dau_mau_ratio,
    decimals = 1
  ) %>%
  # Add column spanners
  tab_spanner(
    label = "Last 6 Months",
    columns = c(revenue_6m, downloads_6m, avg_dau_6m, avg_mau, arpu_6m, dau_mau_ratio, revenue_per_dau_6m)
  ) %>%
  tab_spanner(
    label = "Last 30 Days",
    columns = c(revenue_30d, downloads_30d, avg_dau_30d, downloads_per_day_30d)
  ) %>%
  # Apply GEC theme styling
  tab_options(
    heading.title.font.size = px(28),
    heading.subtitle.font.size = px(18),
    heading.align = "left",
    heading.title.font.weight = "normal",
    heading.subtitle.font.weight = "normal",
    table.font.names = "Arial, sans-serif",
    table.font.size = px(16),
    column_labels.font.weight = "bold",
    column_labels.font.size = px(14),
    data_row.padding = px(10),
    table.width = px(1200),
    table.border.top.width = px(3),
    table.border.top.color = "#1a1a1a",
    table.border.bottom.width = px(3),
    table.border.bottom.color = "#1a1a1a",
    column_labels.border.top.width = px(3),
    column_labels.border.top.color = "#1a1a1a",
    column_labels.border.bottom.width = px(2),
    column_labels.border.bottom.color = "#1a1a1a"
  ) %>%
  # Add data bars for visual comparison
  gt_plt_bar(
    column = revenue_6m,
    color = "#2E86AB",
    width = 40
  ) %>%
  gt_plt_bar(
    column = avg_dau_6m,
    color = "#A23B72",
    width = 40
  ) %>%
  # Style specific cells
  tab_style(
    style = cell_text(weight = "bold"),
    locations = cells_body(columns = game_name)
  ) %>%
  # Add footnote
  tab_footnote(
    footnote = "Stickiness = DAU/MAU ratio, indicating daily engagement",
    locations = cells_column_labels(columns = dau_mau_ratio)
  ) %>%
  # Add source note
  tab_source_note(
    source_note = md("**Source:** Sensor Tower API | **Note:** Worldwide data, all platforms combined")
  )

# Display the table
print(candy_crush_table)

# Save the table as an image for LinkedIn
gtsave(
  candy_crush_table,
  filename = "candy_crush_table.png",
  vwidth = 1200,
  vheight = 600,
  expand = 10
)

cat("\nGT table created successfully!\n")
cat("File saved: candy_crush_table.png\n")