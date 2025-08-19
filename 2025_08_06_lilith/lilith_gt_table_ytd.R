#!/usr/bin/env Rscript

# Main GT table generation script for Lilith Games portfolio analysis
# Uses CSV data in wide format (games as columns)

suppressPackageStartupMessages({
  library(pacman)
  p_load(dplyr, tidyr, readr, gt, webshot2, scales, glue, lubridate)
})

message("=== Generating Lilith Games Portfolio GT Table from CSV Data ===\n")

# Read the revenue CSV (regular CSV, not UTF-16)
revenue_csv <- read_csv("validation/Unified Revenue Jan 2023 to Aug 2025.csv", 
                       show_col_types = FALSE)

# Read the downloads CSV
downloads_csv <- read_csv("validation/Unified Downloads Jan 2023 - Aug 2025.csv", 
                         show_col_types = FALSE)

# Read the MAU CSV
mau_csv <- read_csv("validation/Active Users Data Jan 2023 - Aug 2025.csv",
                   show_col_types = FALSE)

message("Processing revenue data...")
# Convert Month to Date and reshape from wide to long
revenue_long <- revenue_csv %>%
  mutate(Date = as.Date(paste0(Month, "-01"))) %>%
  select(-Month) %>%
  pivot_longer(
    cols = -Date,
    names_to = "game_metric",
    values_to = "revenue"
  ) %>%
  mutate(
    game_name = gsub(" Revenue \\(\\$\\)", "", game_metric),
    Month = month(Date),
    Year = year(Date)
  ) %>%
  select(Date, Year, Month, game_name, revenue)

# Filter for YTD (Jan-Jul)
revenue_ytd <- revenue_long %>%
  filter(Month >= 1 & Month <= 7) %>%
  group_by(Year, game_name) %>%
  summarise(
    Revenue = sum(revenue, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = Year,
    values_from = Revenue,
    names_prefix = "revenue_",
    values_fill = 0
  )

message("Processing downloads data...")
# Similar processing for downloads
downloads_long <- downloads_csv %>%
  mutate(Date = as.Date(paste0(Month, "-01"))) %>%
  select(-Month) %>%
  pivot_longer(
    cols = -Date,
    names_to = "game_metric",
    values_to = "downloads"
  ) %>%
  mutate(
    game_name = gsub(" Downloads", "", game_metric),
    Month = month(Date),
    Year = year(Date)
  ) %>%
  select(Date, Year, Month, game_name, downloads)

downloads_ytd <- downloads_long %>%
  filter(Month >= 1 & Month <= 7) %>%
  group_by(Year, game_name) %>%
  summarise(
    Downloads = sum(downloads, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = Year,
    values_from = Downloads,
    names_prefix = "downloads_",
    values_fill = 0
  )

message("Processing MAU data...")
# Similar processing for MAU
mau_long <- mau_csv %>%
  mutate(Date = as.Date(paste0(Month, "-01"))) %>%
  select(-Month) %>%
  pivot_longer(
    cols = -Date,
    names_to = "game_metric",
    values_to = "mau"
  ) %>%
  mutate(
    game_name = gsub(" MAU", "", game_metric),
    Month = month(Date),
    Year = year(Date),
    YearMonth = paste0(Year, "-", sprintf("%02d", Month))
  ) %>%
  select(Date, Year, Month, YearMonth, game_name, mau)

mau_ytd <- mau_long %>%
  filter(Month >= 1 & Month <= 7) %>%
  # First sum MAU for each month (in case of multiple entries)
  group_by(Year, YearMonth, game_name) %>%
  summarise(
    MonthlyMAU = sum(mau, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  # Then average the monthly totals for each year
  group_by(Year, game_name) %>%
  summarise(
    MAU = mean(MonthlyMAU, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = Year,
    values_from = MAU,
    names_prefix = "mau_",
    values_fill = 0
  )

# Combine all metrics
message("Combining metrics...")
combined_data <- revenue_ytd %>%
  left_join(downloads_ytd, by = "game_name") %>%
  left_join(mau_ytd, by = "game_name") %>%
  # Filter out "Other" category
  filter(game_name != "Other") %>%
  mutate(
    publisher = "Lilith Games"
  )

# Add source information and game details
combined_data <- combined_data %>%
  mutate(
    source = case_when(
      game_name == "AFK Arena" ~ "Original IP",
      game_name == "AFK Journey" ~ "Sequel",
      game_name == "Rise of Kingdoms" ~ "Original IP",
      game_name == "Call of Dragons" ~ "Sequel",
      game_name == "Dislyte" ~ "Original IP",
      game_name == "Warpath: Ace Shooter" ~ "Original IP",
      game_name == "BLOODLINE: HEROES OF LITHAS" ~ "Original IP",
      game_name == "Soul Hunters" ~ "Original IP",
      game_name == "Art of Conquest : Airships" ~ "Original IP",
      game_name == "Palmon: Survival" ~ "Original IP",
      TRUE ~ "Original IP"
    ),
    genre = case_when(
      game_name %in% c("AFK Arena", "AFK Journey", "Dislyte", "BLOODLINE: HEROES OF LITHAS", "Soul Hunters") ~ "RPG",
      game_name %in% c("Rise of Kingdoms", "Call of Dragons", "Warpath: Ace Shooter", "Art of Conquest : Airships") ~ "Strategy",
      game_name == "Palmon: Survival" ~ "Survival",
      TRUE ~ "Other"
    )
  )

# Calculate growth metrics
combined_data <- combined_data %>%
  mutate(
    # YoY growth (2024 to 2025)
    revenue_growth_24_25 = ifelse(revenue_2024 == 0 | is.na(revenue_2024), NA, 
                                  round((revenue_2025 - revenue_2024) / revenue_2024 * 100, 0)),
    downloads_growth_24_25 = ifelse(downloads_2024 == 0 | is.na(downloads_2024), NA, 
                                   round((downloads_2025 - downloads_2024) / downloads_2024 * 100, 0)),
    mau_growth_24_25 = ifelse(mau_2024 == 0 | is.na(mau_2024), NA, 
                             round((mau_2025 - mau_2024) / mau_2024 * 100, 0))
  ) %>%
  arrange(desc(revenue_2025))

# Add rank
combined_data <- combined_data %>%
  mutate(rank = row_number())

# Calculate portfolio total row
portfolio_total <- data.frame(
  game_name = "Portfolio Total",
  publisher = "Lilith Games",
  source = "",
  genre = "",
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
)

# Calculate growth for portfolio total
portfolio_total <- portfolio_total %>%
  mutate(
    revenue_growth_24_25 = round((revenue_2025 - revenue_2024) / revenue_2024 * 100, 0),
    downloads_growth_24_25 = round((downloads_2025 - downloads_2024) / downloads_2024 * 100, 0),
    mau_growth_24_25 = round((mau_2025 - mau_2024) / mau_2024 * 100, 0)
  )

# Combine data
table_data <- bind_rows(portfolio_total, combined_data)

# Create the GT table
message("Creating GT table...")
final_table <- table_data %>%
  select(rank, game_name, genre, 
         revenue_2025, revenue_2024, revenue_2023, revenue_growth_24_25,
         mau_2025, mau_2024, mau_2023, mau_growth_24_25, 
         downloads_2025, downloads_2024, downloads_2023, downloads_growth_24_25) %>%
  gt() %>%
  tab_header(
    title = "Lilith Games Portfolio Scorecard",
    subtitle = "Year-to-Date Metrics (January - July 2025)"
  ) %>%
  # Format revenue columns
  fmt(
    columns = c(revenue_2025, revenue_2024, revenue_2023),
    fns = function(x) {
      ifelse(is.na(x) | x == 0, "—",
        ifelse(
          x >= 1e9,
          paste0("$", format(round(x / 1e9, 1), nsmall = 1), "B"),
          ifelse(
            x >= 1e6,
            paste0("$", round(x / 1e6), "M"),
            paste0("$", round(x / 1e3), "K")
          )
        )
      )
    }
  ) %>%
  fmt_number(
    columns = c(mau_2025, mau_2024, mau_2023),
    decimals = 0,
    suffixing = TRUE
  ) %>%
  fmt_number(
    columns = c(downloads_2025, downloads_2024, downloads_2023),
    decimals = 0,
    suffixing = TRUE
  ) %>%
  # Leave YoY numeric values neutral; arrows will be injected below
  # Replace NA with dash
  sub_missing(
    columns = everything(),
    missing_text = "—"
  ) %>%
  # Column labels
  cols_label(
    rank = "#",
    game_name = "Game",
    genre = "Genre",
    revenue_2025 = "2025",
    revenue_2024 = "2024",
    revenue_2023 = "2023",
    revenue_growth_24_25 = "YoY '24-'25",
    mau_2025 = "2025",
    mau_2024 = "2024",
    mau_2023 = "2023",
    mau_growth_24_25 = "YoY '24-'25",
    downloads_2025 = "2025",
    downloads_2024 = "2024",
    downloads_2023 = "2023",
    downloads_growth_24_25 = "YoY '24-'25"
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
  # Style the portfolio total row
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
  # Highlight new releases (2024-2025)
  tab_style(
    style = list(
      cell_text(weight = "bold")
    ),
    locations = cells_body(
      columns = game_name,
      rows = game_name %in% c("AFK Journey", "Palmon: Survival")
    )
  ) %>%
  # Inject arrow-only indicators for YoY (green up, red down) with neutral text
  text_transform(
    locations = cells_body(columns = c(revenue_growth_24_25, mau_growth_24_25, downloads_growth_24_25)),
    fn = function(x) {
      vals <- suppressWarnings(as.numeric(x))
      lapply(vals, function(v) {
        if (is.na(v)) return(html("—"))
        if (v > 0) return(html(sprintf("<span style='color:#1a9850'>▲</span> %d%%", round(v))))
        if (v < 0) return(html(sprintf("<span style='color:#d73027'>▼</span> %d%%", abs(round(v)))))
        html("0%")
      })
    }
  ) %>%
  # Notes
  tab_source_note("Source: Sensor Tower, Jan-Jul all years") %>%
  tab_source_note("MAU: Average monthly active users | Revenue includes iOS and Android combined") %>%
  tab_source_note("Note: China Android revenue typically undercounted due to third-party store fragmentation") %>%
  tab_footnote(
    footnote = "Launched globally March 2024",
    locations = cells_body(columns = game_name, rows = game_name == "AFK Journey")
  ) %>%
  tab_footnote(
    footnote = "Soft launched 2025", 
    locations = cells_body(columns = game_name, rows = game_name == "Palmon: Survival")
  ) %>%
  # Apply GEC theme
  # Unify body font to League Spartan
  opt_table_font(
    font = list(
      google_font(name = "League Spartan"),
      default_fonts()
    )
  ) %>%
  tab_options(
    # Table styling
    table.background.color = "#FFFFFF",
    table.border.top.style = "solid",
    table.border.top.width = px(3),
    table.border.top.color = "#1a1a1a",
    table.border.bottom.style = "solid",
    table.border.bottom.width = px(3),
    table.border.bottom.color = "#1a1a1a",
    # Header styling
    heading.background.color = "#FFFFFF",
    heading.title.font.size = px(24),
    heading.title.font.weight = "bold",
    heading.subtitle.font.size = px(14),
    heading.subtitle.font.weight = "normal",
    heading.border.bottom.style = "solid",
    heading.border.bottom.width = px(2),
    heading.border.bottom.color = "#1a1a1a",
    # Column labels
    column_labels.background.color = "#f5f5f5",
    column_labels.font.weight = "bold",
    column_labels.font.size = px(12),
    column_labels.border.top.style = "solid",
    column_labels.border.top.width = px(2),
    column_labels.border.top.color = "#1a1a1a",
    column_labels.border.bottom.style = "solid",
    column_labels.border.bottom.width = px(1),
    column_labels.border.bottom.color = "#d0d0d0",
    # Row striping
    row.striping.include_table_body = TRUE,
    row.striping.background_color = "#fafafa",
    # Data cells
    table.font.size = px(11),
    data_row.padding = px(6),
    # Source notes
    source_notes.font.size = px(10),
    source_notes.background.color = "#f5f5f5",
    # Footnotes
    footnotes.font.size = px(10),
    footnotes.background.color = "#f5f5f5"
  )

# Save the table
gtsave(final_table, "output/lilith_portfolio_performance.png",
       vwidth = 1800, vheight = 1200)

message("\n✓ Portfolio table saved as: output/lilith_portfolio_performance.png")

# Print summary statistics
message("\n=== Key Metrics (2025 YTD) ===")
message(glue("Total Revenue: ${format(portfolio_total$revenue_2025/1e9, nsmall = 2)}B"))
message(glue("Total Average MAU: {format(portfolio_total$mau_2025/1e6, nsmall = 0)}M"))
message(glue("Total Downloads: {format(portfolio_total$downloads_2025/1e6, nsmall = 0)}M"))

message("\n=== Year-over-Year Growth (2024-2025) ===")
message(glue("Revenue Growth: {portfolio_total$revenue_growth_24_25}%"))
message(glue("MAU Growth: {portfolio_total$mau_growth_24_25}%"))
message(glue("Downloads Growth: {portfolio_total$downloads_growth_24_25}%"))

message("\n✓ Script completed successfully!")