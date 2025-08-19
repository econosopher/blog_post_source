#!/usr/bin/env Rscript

# Moon Active Portfolio Scorecard (YTD)
# API-only (Sensor Tower). No CSVs. Overwrites old outputs on each run.

suppressPackageStartupMessages({
  library(pacman)
  # Use local sensortowerR (one level up) instead of a remote/installed version
  if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
  devtools::load_all("../sensortowerR")
  p_load(dplyr, tidyr, gt, webshot2, scales, glue, lubridate, tibble)
})

message("=== Generating Moon Active Portfolio GT Table from Sensor Tower API ===\n")

# Determine script directory (save outputs next to script)
args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- if (length(script_path) == 1 && nzchar(script_path)) dirname(normalizePath(script_path)) else getwd()

# Ensure auth
if (!nzchar(Sys.getenv("SENSOR_TOWER_AUTH_TOKEN"))) {
  stop("SENSOR_TOWER_AUTH_TOKEN not found. Please set it as an environment variable.")
}
# Ensure the package-default env name also points to the same token
if (!nzchar(Sys.getenv("SENSORTOWER_AUTH_TOKEN"))) {
  Sys.setenv(SENSORTOWER_AUTH_TOKEN = Sys.getenv("SENSOR_TOWER_AUTH_TOKEN"))
}

# Compute YTD period uniformly across years based on the last fully completed month
first_day_current_month <- as.Date(format(Sys.Date(), "%Y-%m-01"))
last_full_month_end <- first_day_current_month - 1
end_month <- as.integer(format(last_full_month_end, "%m"))

make_period <- function(year) {
  start <- as.Date(sprintf("%04d-01-01", year))
  end_base <- as.Date(sprintf("%04d-%02d-01", year, end_month))
  # Advance one month using base seq.Date, then subtract 1 day for month-end
  end <- seq(end_base, by = "1 month", length.out = 2)[2] - 1
  list(start = as.character(start), end = as.character(end))
}

periods <- list(
  list(year = 2023, p = make_period(2023)),
  list(year = 2024, p = make_period(2024)),
  list(year = 2025, p = make_period(2025))
)

# Discover Moon Active apps from API (no CSVs)
message("Using Coin Master only (WW)...")

coin_ios <- "406889139"
coin_android <- "com.moonactive.coinmaster"

game_map <- tibble::tibble(
  name = c("Coin Master"),
  ios = c(coin_ios),
  android = c(coin_android)
)

if (nrow(game_map) == 0) {
  stop("No valid Moon Active apps with iOS or Android IDs found")
}

message(glue::glue("Found {nrow(game_map)} Moon Active titles"))

# Fetch metrics per game per year (Worldwide)
fetch_game_metrics <- function(ios_id, android_id, start_date, end_date, game_name) {
  # Initialize totals
  revenue <- 0
  downloads <- 0
  mau_vals <- c()

  # Use monthly platform metrics (WW only), then aggregate to YTD sums/averages
  get_monthly <- function(os, app_id) {
    tryCatch({
      sensortowerR::st_metrics(
        os = os,
        `if`(os == "ios", ios_app_id = app_id, android_app_id = app_id),
        start_date = start_date,
        end_date = end_date,
        countries = "WW",
        date_granularity = "monthly",
        verbose = FALSE
      )
    }, error = function(e) NULL)
  }

  if (!is.na(ios_id) && ios_id != "") {
    ios_res <- get_monthly("ios", ios_id)
    if (!is.null(ios_res) && nrow(ios_res) > 0) {
      rev_col <- if ("total_revenue" %in% names(ios_res)) "total_revenue" else if ("revenue" %in% names(ios_res)) "revenue" else NULL
      if (!is.null(rev_col)) revenue <- revenue + sum(ios_res[[rev_col]], na.rm = TRUE)
      if ("downloads" %in% names(ios_res)) downloads <- downloads + sum(ios_res$downloads, na.rm = TRUE)
      if ("mau" %in% names(ios_res)) mau_vals <- c(mau_vals, ios_res$mau)
    }
  }
  if (!is.na(android_id) && android_id != "") {
    and_res <- get_monthly("android", android_id)
    if (!is.null(and_res) && nrow(and_res) > 0) {
      rev_col <- if ("total_revenue" %in% names(and_res)) "total_revenue" else if ("revenue" %in% names(and_res)) "revenue" else NULL
      if (!is.null(rev_col)) revenue <- revenue + sum(and_res[[rev_col]], na.rm = TRUE)
      if ("downloads" %in% names(and_res)) downloads <- downloads + sum(and_res$downloads, na.rm = TRUE)
      if ("mau" %in% names(and_res)) mau_vals <- c(mau_vals, and_res$mau)
    }
  }

  tibble::tibble(
    game_name = game_name,
    revenue = revenue,
    downloads = downloads,
    mau = if (length(mau_vals) > 0) mean(mau_vals, na.rm = TRUE) else NA_real_
  )
}

all_rows <- list()
for (yrp in periods) {
  yr <- yrp$year
  start_date <- yrp$p$start
  end_date <- yrp$p$end
  message(glue::glue("Fetching YTD {yr} (WW): {start_date} → {end_date}"))

  year_rows <- purrr::pmap_dfr(
    list(game_map$ios, game_map$android, game_map$name),
    function(ios_id, android_id, nm) {
      fetch_game_metrics(ios_id, android_id, start_date, end_date, nm) %>% mutate(year = yr)
    }
  )
  all_rows[[length(all_rows) + 1]] <- year_rows
}

all_data <- dplyr::bind_rows(all_rows)

# Pivot to wide format with year columns
table_data <- all_data %>%
  pivot_wider(
    id_cols = game_name,
    names_from = year,
    values_from = c(revenue, downloads, mau),
    names_sep = "_",
    values_fill = 0
  )

# Growth metrics and ranking
table_data <- table_data %>%
  mutate(
    revenue_growth_24_25 = ifelse(revenue_2024 == 0, NA, round((revenue_2025 - revenue_2024) / revenue_2024 * 100, 0)),
    downloads_growth_24_25 = ifelse(downloads_2024 == 0, NA, round((downloads_2025 - downloads_2024) / downloads_2024 * 100, 0)),
    mau_growth_24_25 = ifelse(mau_2024 == 0, NA, round((mau_2025 - mau_2024) / mau_2024 * 100, 0))
  ) %>%
  arrange(desc(revenue_2025)) %>%
  mutate(rank = row_number())

# Single title; rank stays 1
table_data <- table_data %>%
  mutate(rank = dplyr::row_number())

# Portfolio total row
final_data <- table_data

# Build and save GT table from API data, then exit before CSV fallback section
message("Creating GT table (API)...")
api_gt <- final_data %>%
  select(game_name,
         revenue_2025, revenue_2024, revenue_2023,
         mau_2025, mau_2024, mau_2023,
         downloads_2025, downloads_2024, downloads_2023) %>%
  gt() %>%
  tab_header(
    title = "Coin Master YTD Scorecard",
    subtitle = glue::glue("YTD (Jan - {format(last_full_month_end, '%B')}) | Worldwide | API")
  ) %>%
  fmt(
    columns = c(revenue_2025, revenue_2024, revenue_2023),
    fns = function(x) {
      ifelse(is.na(x) | x == 0, "—",
        ifelse(x >= 1e9, paste0("$", format(round(x/1e9, 1), nsmall = 1), "B"),
        ifelse(x >= 1e6, paste0("$", round(x/1e6), "M"), paste0("$", round(x/1e3), "K"))))
    }
  ) %>%
  fmt_number(columns = c(mau_2025, mau_2024, mau_2023, downloads_2025, downloads_2024, downloads_2023), decimals = 0, suffixing = TRUE) %>%
  sub_missing(columns = everything(), missing_text = "—")

out_api <- file.path(script_dir, "moonactive_portfolio_api.png")
gtsave(api_gt, out_api, vwidth = 1800, vheight = 1200)
message(glue::glue("\n✓ Portfolio table saved as: {out_api}"))
quit(save = "no")

# Expected validation CSVs (adjust names to match your exports)
revenue_csv <- read_tsv("validation/Unified Revenue Jan 2023 - Jul 2025.csv",
                        show_col_types = FALSE,
                        locale = locale(encoding = "UTF-16LE"))

downloads_csv <- read_tsv("validation/Unified Downloads Jan 2023 - Jul 2025.csv",
                          show_col_types = FALSE,
                          locale = locale(encoding = "UTF-16LE"))

mau_csv <- read_tsv("validation/Active Users MAU Jan 2023 - Jul 2025.csv",
                    show_col_types = FALSE,
                    locale = locale(encoding = "UTF-16LE"))

# Filter to Moon Active games by publisher field
message("Filtering games for publisher: Moon Active")
moon_revenue <- revenue_csv %>% filter(`Unified Publisher Name` == "Moon Active")
moon_downloads <- downloads_csv %>% filter(`Unified Publisher Name` == "Moon Active")
moon_mau <- mau_csv %>% filter(`Unified Publisher Name` == "Moon Active")

# Revenue YTD (Jan–Jun)
message("Processing revenue data...")
revenue_ytd <- moon_revenue %>%
  mutate(Date = as.Date(Date), Month = month(Date), Year = year(Date)) %>%
  filter(Month >= 1 & Month <= 6) %>%
  group_by(Year, `Unified Name`) %>%
  summarise(Revenue = sum(`Revenue ($)`, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = Year, values_from = Revenue, names_prefix = "revenue_", values_fill = 0)

# Downloads YTD (Jan–Jun)
message("Processing downloads data...")
downloads_ytd <- moon_downloads %>%
  mutate(Date = as.Date(Date), Month = month(Date), Year = year(Date)) %>%
  filter(Month >= 1 & Month <= 6) %>%
  group_by(Year, `Unified Name`) %>%
  summarise(Downloads = sum(Downloads, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = Year, values_from = Downloads, names_prefix = "downloads_", values_fill = 0)

# MAU YTD (average of monthly totals, Jan–Jun)
message("Processing MAU data...")
mau_ytd <- moon_mau %>%
  mutate(Date = as.Date(Date), Month = month(Date), Year = year(Date), YearMonth = paste0(Year, "-", sprintf("%02d", Month))) %>%
  filter(Month >= 1 & Month <= 6) %>%
  group_by(Year, YearMonth, `Unified Name`) %>%
  summarise(MonthlyMAU = sum(MAU, na.rm = TRUE), .groups = "drop") %>%
  group_by(Year, `Unified Name`) %>%
  summarise(MAU = mean(MonthlyMAU, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = Year, values_from = MAU, names_prefix = "mau_", values_fill = 0)

# Combine
message("Combining metrics...")
combined_data <- revenue_ytd %>%
  left_join(downloads_ytd, by = "Unified Name") %>%
  left_join(mau_ytd, by = "Unified Name") %>%
  rename(game_name = `Unified Name`) %>%
  mutate(publisher = "Moon Active")

# Growth metrics and ranking
combined_data <- combined_data %>%
  mutate(
    revenue_growth_24_25 = ifelse(revenue_2024 == 0 | is.na(revenue_2024), NA, round((revenue_2025 - revenue_2024) / revenue_2024 * 100, 0)),
    downloads_growth_24_25 = ifelse(downloads_2024 == 0 | is.na(downloads_2024), NA, round((downloads_2025 - downloads_2024) / downloads_2024 * 100, 0)),
    mau_growth_24_25 = ifelse(mau_2024 == 0 | is.na(mau_2024), NA, round((mau_2025 - mau_2024) / mau_2024 * 100, 0))
  ) %>%
  arrange(desc(revenue_2025)) %>%
  mutate(rank = row_number())

# Portfolio total row
portfolio_total <- data.frame(
  game_name = "Portfolio Total",
  publisher = "Moon Active",
  rank = NA,
  revenue_2023 = sum(combined_data$revenue_2023, na.rm = TRUE),
  revenue_2024 = sum(combined_data$revenue_2024, na.rm = TRUE),
  revenue_2025 = sum(combined_data$revenue_2025, na.rm = TRUE),
  downloads_2023 = sum(combined_data$downloads_2023, na.rm = TRUE),
  downloads_2024 = sum(combined_data$downloads_2024, na.rm = TRUE),
  downloads_2025 = sum(combined_data$downloads_2025, na.rm = TRUE),
  mau_2023 = sum(combined_data$mau_2023, na.rm = TRUE),
  mau_2024 = sum(combined_data$mau_2024, na.rm = TRUE),
  mau_2025 = sum(combined_data$mau_2025, na.rm = TRUE),
  stringsAsFactors = FALSE
) %>%
  mutate(
    revenue_growth_24_25 = ifelse(revenue_2024 == 0, NA, round((revenue_2025 - revenue_2024) / revenue_2024 * 100, 0)),
    downloads_growth_24_25 = ifelse(downloads_2024 == 0, NA, round((downloads_2025 - downloads_2024) / downloads_2024 * 100, 0)),
    mau_growth_24_25 = ifelse(mau_2024 == 0, NA, round((mau_2025 - mau_2024) / mau_2024 * 100, 0))
  )

table_data <- bind_rows(portfolio_total, combined_data)

# Build GT table
message("Creating GT table...")
final_table <- table_data %>%
  select(rank, game_name,
         revenue_2025, revenue_2024, revenue_2023, revenue_growth_24_25,
         mau_2025, mau_2024, mau_2023, mau_growth_24_25,
         downloads_2025, downloads_2024, downloads_2023, downloads_growth_24_25) %>%
  gt() %>%
  tab_header(
    title = "Moon Active Portfolio Scorecard",
    subtitle = glue::glue("Year-to-Date Metrics (Jan - {format(last_full_month_end, '%B')}) | Worldwide")
  ) %>%
  tab_spanner(label = "Revenue (YTD)", columns = c(revenue_2025, revenue_2024, revenue_2023, revenue_growth_24_25)) %>%
  tab_spanner(label = "Average MAU (YTD)", columns = c(mau_2025, mau_2024, mau_2023, mau_growth_24_25)) %>%
  tab_spanner(label = "Downloads (YTD)", columns = c(downloads_2025, downloads_2024, downloads_2023, downloads_growth_24_25)) %>%
  cols_label(
    rank = "#",
    game_name = "Game",
    revenue_2025 = "2025", revenue_2024 = "2024", revenue_2023 = "2023", revenue_growth_24_25 = "YTD '24-'25",
    mau_2025 = "2025", mau_2024 = "2024", mau_2023 = "2023", mau_growth_24_25 = "YTD '24-'25",
    downloads_2025 = "2025", downloads_2024 = "2024", downloads_2023 = "2023", downloads_growth_24_25 = "YTD '24-'25"
  ) %>%
  fmt(
    columns = c(revenue_2025, revenue_2024, revenue_2023),
    fns = function(x) {
      ifelse(is.na(x) | x == 0, "—",
        ifelse(x >= 1e9, paste0("$", format(round(x/1e9, 1), nsmall = 1), "B"),
        ifelse(x >= 1e6, paste0("$", round(x/1e6), "M"), paste0("$", round(x/1e3), "K"))))
    }
  ) %>%
  fmt_number(columns = c(mau_2025, mau_2024, mau_2023), decimals = 0, suffixing = TRUE) %>%
  fmt_number(columns = c(downloads_2025, downloads_2024, downloads_2023), decimals = 0, suffixing = TRUE) %>%
  fmt_percent(columns = c(revenue_growth_24_25, mau_growth_24_25, downloads_growth_24_25), decimals = 0, scale_values = FALSE) %>%
  sub_missing(columns = everything(), missing_text = "—") %>%
  tab_source_note("Source: Sensor Tower API (Worldwide) | Metrics combine iOS + Android | MAU shown as average over YTD months") %>%
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
    source_notes.background.color = "#f5f5f5",
    footnotes.font.size = px(10),
    footnotes.background.color = "#f5f5f5"
  )

# Ensure output dir, clean old files, and save
old_images <- list.files(script_dir, pattern = "^moonactive_.*\\.(png|jpg|jpeg)$", ignore.case = TRUE, full.names = TRUE)
if (length(old_images) > 0) try(unlink(old_images, recursive = TRUE, force = TRUE), silent = TRUE)
out_path <- file.path(script_dir, "moonactive_portfolio_api.png")
gtsave(final_table, out_path, vwidth = 1800, vheight = 1200)
message(glue::glue("\n✓ Portfolio table saved as: {out_path}"))
message("\n✓ Script completed successfully!")


