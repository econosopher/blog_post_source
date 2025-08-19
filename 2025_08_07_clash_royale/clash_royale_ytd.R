#!/usr/bin/env Rscript

# Clash Royale - Worldwide YTD Scorecard (2023-2025)
# CSV-driven: uses local CSVs in this folder (no API calls)

suppressPackageStartupMessages({
  library(pacman)
  p_load(
    dplyr, tidyr, readr, stringr, tibble, ggplot2, purrr,
    gt, webshot2, scales, glue, lubridate, gtExtras
  )
})

# Lint helpers for NSE columns used with dplyr/gt
utils::globalVariables(c(
  ".data", ".date", ".value", "value", "unified_app_id",
  "revenue_30d", "downloads_30d", "avg_dau_30d"
))

# Optional: load GEC GT theme if present one folder up
try({
  gec_theme_path <- file.path(dirname(getwd()), "gec_theme", "gec_gt_theme.R")
  if (file.exists(gec_theme_path)) source(gec_theme_path)
}, silent = TRUE)

message("=== Clash Royale | Year-to-Date Scorecard (Worldwide, CSV) ===\n")

# Determine script directory (save outputs next to script)
args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- if (length(script_path) == 1 && nzchar(script_path)) dirname(normalizePath(script_path)) else getwd()

## CSV inputs in this folder
mau_csv_path <- file.path(script_dir, "Active Users Jan 2016 to Aug 2025.csv")
downloads_csv_path <- file.path(script_dir, "Unified Downloads Jan 2016 - Aug 2025.csv")
revenue_csv_path <- file.path(script_dir, "Unified Revenue Jan 2016 - Aug 2025.csv")

if (!file.exists(mau_csv_path) || !file.exists(downloads_csv_path) || !file.exists(revenue_csv_path)) {
  stop("Required CSVs not found next to the script.")
}

# YTD window derived later from CSV series

# Helper to parse dates from CSV generically
parse_date_col <- function(df) {
  nms <- names(df)
  if ("Date" %in% nms) return(as.Date(df$Date))
  if ("date" %in% nms) return(as.Date(df$date))
  if ("Month" %in% nms) return(as.Date(paste0(df$Month, "-01")))
  if ("month" %in% nms) return(as.Date(paste0(df$month, "-01")))
  # Any column containing 'date'
  date_like <- nms[grepl("(?i)date", nms, perl = TRUE)]
  if (length(date_like) > 0) return(as.Date(df[[date_like[1]]]))
  stop("Could not find a Date/Month column in CSV")
}

# Helper: robust numeric parse (remove commas, currency, spaces)
parse_numeric <- function(x) {
  if (is.numeric(x)) return(as.numeric(x))
  x <- gsub("[,$\\s]", "", as.character(x))
  suppressWarnings(as.numeric(x))
}

# Generic series reader with tidyverse chaining
read_series_generic <- function(path, value_regex, value_name) {
  df <- read_utf16_tsv_or_csv(path)
  if (is.null(df) || ncol(df) == 0) stop(sprintf("Failed to read: %s", basename(path)))
  date_col <- parse_date_col(df)
  val_col <- names(df)[grepl(value_regex, names(df), perl = TRUE)]
  if (length(val_col) == 0) stop(sprintf("Could not find value column in %s", basename(path)))

  series <- df %>%
    dplyr::mutate(.date = date_col, .value = parse_numeric(.data[[val_col[1]]]))

  # Optional app-name filter to Clash Royale
  name_col <- intersect(names(series), c("Unified Name", "App Name", "Name", "Game", "Title"))
  if (length(name_col) > 0) {
    series <- series %>% dplyr::filter(grepl("clash\\s*royale", .data[[name_col[1]]], ignore.case = TRUE))
  }

  # Prefer Worldwide rows when present
  country_col <- intersect(names(series), c("Unified Country", "Country", "Region"))
  if (length(country_col) > 0 && any(series[[country_col[1]]] %in% c("WW", "Worldwide"), na.rm = TRUE)) {
    series <- series %>% dplyr::filter(.data[[country_col[1]]] %in% c("WW", "Worldwide"))
  }

  series %>%
    dplyr::select(date = .date, value = .value) %>%
    dplyr::filter(!is.na(date)) %>%
    dplyr::group_by(date) %>%
    dplyr::summarise(value = sum(value, na.rm = TRUE), .groups = "drop") %>%
    dplyr::rename(!!value_name := value)
}

# Readers with encoding fallback (UTF-16LE TSV vs CSV)
read_utf16_tsv_or_csv <- function(path) {
  df <- tryCatch(readr::read_tsv(path, locale = locale(encoding = "UTF-16LE"), show_col_types = FALSE), error = function(e) NULL)
  if (!is.null(df) && ncol(df) > 0) return(df)
  df2 <- tryCatch(readr::read_csv(path, locale = locale(encoding = "UTF-16LE"), show_col_types = FALSE), error = function(e) NULL)
  if (!is.null(df2) && ncol(df2) > 0) return(df2)
  # Fallback to default reader
  tryCatch(readr::read_csv(path, show_col_types = FALSE), error = function(e) NULL)
}

 # Read MAU CSV via generic reader
mau_series <- read_series_generic(
  mau_csv_path,
  "(?i)\\bMAU\\b|Monthly\\s*Active\\s*Users|Active\\s*Users",
  "mau"
)

 # Downloads via generic reader
dl_series <- read_series_generic(
  downloads_csv_path,
  "(?i)downloads",
  "downloads"
)

# Aggregate duplicates by date (across countries/platforms)
dl_series <- dl_series %>% group_by(date) %>% summarise(downloads = sum(downloads, na.rm = TRUE), .groups = "drop")
mau_series <- mau_series %>% group_by(date) %>% summarise(mau = mean(mau, na.rm = TRUE), .groups = "drop")

 # Revenue via generic reader
rev_series <- read_series_generic(
  revenue_csv_path,
  "(?i)revenue",
  "revenue"
)

 # Compute YTD aggregates (tidyverse chaining)
first_day_current_month <- as.Date(format(Sys.Date(), "%Y-%m-01"))
last_full_month_end <- first_day_current_month - lubridate::days(1)
end_month <- as.integer(format(last_full_month_end, "%m"))
month_label <- format(last_full_month_end, "%b")
end_month <- as.integer(format(last_full_month_end, "%m"))

years <- 2016:as.integer(format(last_full_month_end, "%Y"))

mau_ytd <- mau_series %>%
  dplyr::filter(date <= last_full_month_end) %>%
  dplyr::mutate(year = lubridate::year(date), month = lubridate::month(date)) %>%
  dplyr::filter(month <= end_month) %>%
  dplyr::group_by(year) %>% dplyr::summarise(mau = mean(mau, na.rm = TRUE), .groups = "drop")

dl_ytd <- dl_series %>%
  dplyr::filter(date <= last_full_month_end) %>%
  dplyr::mutate(year = lubridate::year(date), month = lubridate::month(date)) %>%
  dplyr::filter(month <= end_month) %>%
  dplyr::group_by(year) %>% dplyr::summarise(downloads = sum(downloads, na.rm = TRUE), .groups = "drop")

rev_ytd <- rev_series %>%
  dplyr::filter(date <= last_full_month_end) %>%
  dplyr::mutate(year = lubridate::year(date), month = lubridate::month(date)) %>%
  dplyr::filter(month <= end_month) %>%
  dplyr::group_by(year) %>% dplyr::summarise(revenue = sum(revenue, na.rm = TRUE), .groups = "drop")

all_results <- tibble::tibble(year = years) %>%
  dplyr::left_join(rev_ytd, by = "year") %>%
  dplyr::left_join(dl_ytd, by = "year") %>%
  dplyr::left_join(mau_ytd, by = "year") %>%
  dplyr::mutate(
    revenue = dplyr::coalesce(revenue, 0),
    downloads = dplyr::coalesce(downloads, 0),
    mau = ifelse(is.na(mau), NA_real_, mau),
    months_elapsed = end_month,
    annual_run_rate = dplyr::if_else(months_elapsed > 0, revenue * (12/months_elapsed), revenue)
  ) %>%
  dplyr::select(year, revenue, annual_run_rate, downloads, mau)

# Long table by Year with YoY growth
table_data <- all_results %>%
  dplyr::arrange(year) %>%
  dplyr::mutate(
    revenue_yoy = ifelse(lag(revenue) > 0, round((revenue - lag(revenue)) / lag(revenue) * 100, 0), NA_real_),
    downloads_yoy = ifelse(lag(downloads) > 0, round((downloads - lag(downloads)) / lag(downloads) * 100, 0), NA_real_),
    mau_yoy = ifelse(lag(mau) > 0, round((mau - lag(mau)) / lag(mau) * 100, 0), NA_real_)
  )

# Build GT table (GEC styling similar to Lilith portfolio)
message("Creating GT table...")

# Compute domains for heatmaps
rev_domain <- range(table_data$revenue, na.rm = TRUE)
arr_domain <- range(table_data$annual_run_rate, na.rm = TRUE)
mau_domain <- range(table_data$mau, na.rm = TRUE)
dl_domain <- range(table_data$downloads, na.rm = TRUE)

gt_table <- table_data %>%
  dplyr::arrange(dplyr::desc(year)) %>%
  dplyr::transmute(
    Year = year,
    Revenue = revenue,
    `Annual Run Rate` = annual_run_rate,
    `Revenue YoY` = revenue_yoy,
    `Avg MAU` = mau,
    `MAU YoY` = mau_yoy,
    Downloads = downloads,
    `Downloads YoY` = downloads_yoy
  ) %>%
  gt::gt() %>%
  gt::tab_header(
    title = "CLASH ROYALE IS SAVING SUPERCELL",
    subtitle = glue::glue("Year-to-Date Scorecard • Worldwide • Jan-{month_label}")
  ) %>%
  # Spanner headers
  gt::tab_spanner(
    label = "Revenue",
    columns = c(Revenue, `Annual Run Rate`, `Revenue YoY`),
    id = "sp_revenue"
  ) %>%
  gt::tab_spanner(
    label = "Average MAU",
    columns = c(`Avg MAU`, `MAU YoY`),
    id = "sp_mau"
  ) %>%
  gt::tab_spanner(
    label = "DL",
    columns = c(Downloads, `Downloads YoY`),
    id = "sp_downloads"
  ) %>%
  # Lighter column headers using League Spartan while keeping spanners as themed
  gt::tab_style(
    style = gt::cell_text(font = "League Spartan", weight = "500", size = px(10)),
    locations = gt::cells_column_labels(gt::everything())
  ) %>%
  # Shorter column labels to tighten width
  gt::cols_label(
    `Annual Run Rate` = "Run Rate",
    `Revenue YoY` = "YoY",
    `Avg MAU` = "Avg MAU",
    `MAU YoY` = "YoY",
    Downloads = "DL",
    `Downloads YoY` = "YoY"
  ) %>%
  # Tighter professional layout
  gt::cols_align(align = "right", columns = c(Revenue, `Annual Run Rate`, `Avg MAU`, Downloads)) %>%
  gt::cols_align(align = "right", columns = c(`Revenue YoY`, `MAU YoY`, `Downloads YoY`)) %>%
  gt::cols_width(
    c(Year) ~ px(48),
    c(Revenue, `Annual Run Rate`, `Avg MAU`, Downloads) ~ px(72),
    c(`Revenue YoY`, `MAU YoY`, `Downloads YoY`) ~ px(50)
  ) %>%
  gt::fmt(
    columns = c(Revenue, `Annual Run Rate`),
    fns = function(x) {
      ifelse(is.na(x) | x == 0, "—",
        ifelse(x >= 1e9, paste0("$", format(round(x/1e9, 1), nsmall = 1), "B"),
        ifelse(x >= 1e6, paste0("$", round(x/1e6), "M"), paste0("$", round(x/1e3), "K"))))
    }
  ) %>%
  gt::fmt_number(columns = c(`Avg MAU`, Downloads), decimals = 0, suffixing = TRUE) %>%
  # Inject colored arrows for YoY while keeping numeric text neutral
  gt::text_transform(
    locations = gt::cells_body(columns = c(`Revenue YoY`, `MAU YoY`, `Downloads YoY`)),
    fn = function(x) {
      vals <- suppressWarnings(as.numeric(x))
      lapply(vals, function(v) {
        if (is.na(v)) return(gt::html("—"))
        if (v > 0) return(gt::html(sprintf("<span style='font-variant-numeric: tabular-nums; font-feature-settings: 'tnum' 1; white-space: nowrap;'><span style='color:#1a9850; font-size: 16px; font-weight: 900;'>⬆</span>&nbsp;%d%%</span>", round(v))))
        if (v < 0) return(gt::html(sprintf("<span style='font-variant-numeric: tabular-nums; font-feature-settings: 'tnum' 1; white-space: nowrap;'><span style='color:#d73027; font-size: 16px; font-weight: 900;'>⬇</span>&nbsp;%d%%</span>", abs(round(v)))))
        gt::html("<span style='font-variant-numeric: tabular-nums; font-feature-settings: 'tnum' 1; white-space: nowrap;'>0%</span>")
      })
    }
  ) %>%
  # Unified heatmap palette (red = low/worse, green = high/better)
  gt::data_color(
    columns = Revenue,
    fn = scales::col_numeric(
      palette = c("#fddede", "#1a9850"),
      domain = rev_domain
    )
  ) %>%
  gt::data_color(
    columns = `Annual Run Rate`,
    fn = scales::col_numeric(
      palette = c("#fddede", "#1a9850"),
      domain = arr_domain
    )
  ) %>%
  gt::data_color(
    columns = `Avg MAU`,
    fn = scales::col_numeric(
      palette = c("#fddede", "#1a9850"),
      domain = mau_domain
    )
  ) %>%
  gt::data_color(
    columns = Downloads,
    fn = scales::col_numeric(
      palette = c("#fddede", "#1a9850"),
      domain = dl_domain
    )
  ) %>%
  # Remove background heatmap for YoY; arrow color conveys direction
  gt::sub_missing(columns = gt::everything(), missing_text = "—") %>%
  # Footnote: Global launch date
  gt::tab_source_note("Source: Sensor Tower (Worldwide) | Revenue & Downloads summed per year; MAU averaged per year (current year YTD) | Global launch: Mar 2, 2016") %>%
  gt::tab_options(
    heading.title.font.size = px(16),
    heading.title.font.weight = "600",
    heading.align = "left",
    heading.subtitle.font.size = px(11),
    heading.subtitle.font.weight = "normal",
    column_labels.font.weight = "normal",
    column_labels.background.color = "#f5f5f5",
    table.font.size = px(12),
    data_row.padding = px(4)
  )

# Apply GEC theme (required)
gec_theme_path <- file.path(script_dir, "..", "..", "gec_theme", "gec_gt_theme.R")
gec_theme_path <- normalizePath(gec_theme_path, mustWork = FALSE)
if (!file.exists(gec_theme_path)) {
  stop(sprintf("GEC theme not found at: %s", gec_theme_path))
}
source(gec_theme_path, chdir = TRUE)
if (!exists("theme_gec_gt")) {
  stop("GEC theme did not load correctly: function `theme_gec_gt` not found")
}
gt_table <- theme_gec_gt(gt_table, weight_strategy = "light", line_thickness = "regular", border_color = "transparent")

# Normalize font weights for UX: de-bold spanners and labels
gt_table <- gt_table %>%
  gt::tab_style(
    style = gt::cell_text(weight = "normal"),
    locations = gt::cells_column_spanners(spanners = c("sp_revenue", "sp_mau", "sp_downloads"))
  ) %>%
  # Reduce spanner and column label sizes to prevent truncation and unify header visuals
  gt::tab_style(
    style = gt::cell_text(size = px(11)),
    locations = gt::cells_column_spanners(spanners = c("sp_revenue", "sp_mau", "sp_downloads"))
  ) %>%
  gt::tab_options(
    column_labels.font.weight = "normal",
    column_labels.font.size = px(11),
    data_row.padding = px(3),
    table.border.top.style = "none",
    table.border.bottom.style = "none",
    table.border.left.style = "none",
    table.border.right.style = "none"
  )

# Removed in-cell data bars in favor of heatmaps above

# Save image(s) for sharing — overwrite any prior ones in script folder
old_imgs <- list.files(script_dir, pattern = "^clash_royale_.*\\.(png|jpg|jpeg)$", ignore.case = TRUE, full.names = TRUE)
if (length(old_imgs) > 0) try(unlink(old_imgs, recursive = TRUE, force = TRUE), silent = TRUE)

out_path <- file.path(script_dir, "clash_royale_ytd.png")
gt::gtsave(gt_table, out_path, vwidth = 1400, vheight = 540)
message(glue::glue("\n✓ Saved: {out_path}"))


# Optional: create an additional 30-day Sensor Tower snapshot image matching given URL params
# Requires local sensortowerR and auth token
create_url_based_snapshot <- function() {
  # Try to load .env from project root (one level up from blog_post_source)
  if (requireNamespace("dotenv", quietly = TRUE)) {
    for (candidate in c(file.path(script_dir, "..", "..", ".env"),
                        file.path(script_dir, "..", ".env"),
                        file.path(script_dir, ".env"))) {
      if (file.exists(candidate)) {
        try(dotenv::load_dot_env(candidate), silent = TRUE)
      }
    }
  }

  # Load local sensortowerR if available
  if (!requireNamespace("sensortowerR", quietly = TRUE)) {
    if (requireNamespace("devtools", quietly = TRUE)) {
      try(devtools::load_all("../sensortowerR"), silent = TRUE)
    }
  }
  if (!requireNamespace("sensortowerR", quietly = TRUE)) {
    message("sensortowerR not available; skipping URL-based snapshot")
    return(invisible(FALSE))
  }
  # Accept either env var name
  if (!nzchar(Sys.getenv("SENSOR_TOWER_AUTH_TOKEN")) && nzchar(Sys.getenv("SENSORTOWER_AUTH_TOKEN"))) {
    Sys.setenv(SENSOR_TOWER_AUTH_TOKEN = Sys.getenv("SENSORTOWER_AUTH_TOKEN"))
  }
  if (!nzchar(Sys.getenv("SENSOR_TOWER_AUTH_TOKEN"))) {
    message("Sensor Tower auth not set; skipping URL-based snapshot")
    return(invisible(FALSE))
  }

  # IDs from the provided URL
  app_ids <- c("1053012308", "com.supercell.clashroyale")
  # Date range from URL (30 days)
  start_date <- "2025-07-13"
  end_date <- "2025-08-11"

  # Fetch cumulative 30-day metrics worldwide
  st_df <- tryCatch({
    sensortowerR::st_smart_metrics(
      app_ids = app_ids,
      metrics = c("revenue", "downloads", "dau"),
      date_range = list(start_date = as.Date(start_date), end_date = as.Date(end_date)),
      countries = "WW",
      date_granularity = "cumulative"
    )
  }, error = function(e) NULL)

  if (is.null(st_df) || nrow(st_df) == 0) {
    message("No data from Sensor Tower for URL-based snapshot; skipping")
    return(invisible(FALSE))
  }

  # Deduplicate by unified_app_id and summarise
  snap <- st_df %>%
    group_by(unified_app_id) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    summarise(
      revenue_30d = sum(revenue, na.rm = TRUE),
      downloads_30d = sum(downloads, na.rm = TRUE),
      avg_dau_30d = mean(dau, na.rm = TRUE)
    )

  snap_tbl <- snap %>%
    gt::gt() %>%
    gt::tab_header(
      title = "Clash Royale 30-Day Snapshot",
      subtitle = "Sensor Tower parameters matched to URL (Worldwide)"
    ) %>%
    gt::cols_label(
      revenue_30d = "Revenue (30d)",
      downloads_30d = "Downloads (30d)",
      avg_dau_30d = "Avg DAU (30d)"
    ) %>%
    gt::fmt_currency(columns = revenue_30d, currency = "USD", decimals = 0) %>%
    gt::fmt_number(columns = downloads_30d, decimals = 0, suffixing = TRUE) %>%
    gt::fmt_number(columns = avg_dau_30d, decimals = 0, suffixing = TRUE)

  out2 <- file.path(script_dir, "clash_royale_30d_snapshot.png")
  gtsave(snap_tbl, out2, vwidth = 1000, vheight = 400)
  message(glue::glue("✓ URL-based snapshot saved: {out2}"))
  invisible(TRUE)
}

try(create_url_based_snapshot(), silent = TRUE)

# Weekly revenue time series (Worldwide) with MAU overlay and save next to script
try({
  weekly <- rev_series %>%
    dplyr::mutate(week = lubridate::floor_date(date, unit = "week", week_start = 1)) %>%
    dplyr::group_by(week) %>%
    dplyr::summarise(revenue = sum(revenue, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(week)
  weekly_mau <- mau_series %>%
    dplyr::mutate(week = lubridate::floor_date(date, unit = "week", week_start = 1)) %>%
    dplyr::group_by(week) %>%
    dplyr::summarise(mau_proxy = mean(mau, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(week)
  if (nrow(weekly) > 0 && nrow(weekly_mau) > 0) {
    joined <- weekly %>% dplyr::left_join(weekly_mau, by = "week")
    p <- ggplot(joined, aes(x = week)) +
      geom_line(aes(y = revenue), color = "#1E88E5", linewidth = 0.8) +
      scale_y_continuous(
        name = "Revenue",
        labels = function(x) ifelse(x >= 1e9, paste0("$", round(x/1e9,1), "B"), ifelse(x >= 1e6, paste0("$", round(x/1e6), "M"), paste0("$", round(x/1e3), "K"))),
        sec.axis = sec_axis(~., name = "Avg MAU (weekly avg)", labels = scales::label_number_si(accuracy = 1))
      ) +
      geom_line(aes(y = scales::rescale(mau_proxy, to = range(revenue, na.rm = TRUE), from = range(mau_proxy, na.rm = TRUE))),
                color = "#43A047", linetype = "dotted", linewidth = 0.8) +
      labs(title = "Clash Royale Weekly Revenue (WW) with MAU Overlay", x = "Week") +
      theme_minimal(base_size = 12)
    out_week <- file.path(script_dir, "clash_royale_weekly_revenue.jpg")
    ggsave(out_week, p, width = 12, height = 6, dpi = 200)
    message(glue::glue("✓ Weekly revenue timeseries saved: {out_week}"))
  }
}, silent = TRUE)


