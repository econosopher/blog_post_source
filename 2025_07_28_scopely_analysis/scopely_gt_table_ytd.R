#!/usr/bin/env Rscript

# Main GT table generation script for Scopely portfolio analysis
# Uses CSV data exclusively for the final table

suppressPackageStartupMessages({
  library(pacman)
  p_load(dplyr, tidyr, readr, gt, webshot2, scales, glue, lubridate)
})

message("=== Generating Scopely Portfolio GT Table from CSV Data ===\n")

# Read the revenue CSV (UTF-16 encoded)
revenue_csv <- read_tsv("validation/Unified Revenue Jan 2023 - Jul 2025.csv", 
                       show_col_types = FALSE,
                       locale = locale(encoding = "UTF-16LE"))

# Read the downloads CSV (UTF-16 encoded)
downloads_csv <- read_tsv("validation/Unified Downloads Jan 2023 - Jul 2025.csv", 
                         show_col_types = FALSE,
                         locale = locale(encoding = "UTF-16LE"))

# Read the MAU CSV (UTF-16 encoded)
mau_csv <- read_tsv("validation/Active Users MAU Jan 2023 - Jul 2025.csv",
                   show_col_types = FALSE,
                   locale = locale(encoding = "UTF-16LE"))

# Get all unique games from the revenue CSV (all games, not just Scopely/Niantic)
all_games <- revenue_csv %>%
  pull(`Unified Name`) %>%
  unique() %>%
  na.omit()

message(paste("Found", length(all_games), "unique games in the CSV"))

# Use all games
target_games <- all_games

# Process revenue data
message("Processing revenue data...")
revenue_ytd <- revenue_csv %>%
  filter(`Unified Name` %in% target_games) %>%
  mutate(
    Date = as.Date(Date),
    Month = month(Date),
    Year = year(Date)
  ) %>%
  filter(Month >= 1 & Month <= 6) %>%  # YTD (Jan-Jun)
  group_by(Year, `Unified Name`, `Unified Publisher Name`) %>%
  summarise(
    Revenue = sum(`Revenue ($)`, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = Year,
    values_from = Revenue,
    names_prefix = "revenue_",
    values_fill = 0
  )

# Process downloads data
message("Processing downloads data...")
downloads_ytd <- downloads_csv %>%
  filter(`Unified Name` %in% target_games) %>%
  mutate(
    Date = as.Date(Date),
    Month = month(Date),
    Year = year(Date)
  ) %>%
  filter(Month >= 1 & Month <= 6) %>%  # YTD (Jan-Jun)
  group_by(Year, `Unified Name`) %>%
  summarise(
    Downloads = sum(Downloads, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = Year,
    values_from = Downloads,
    names_prefix = "downloads_",
    values_fill = 0
  )

# Process MAU data (average for YTD period)
message("Processing MAU data...")
mau_ytd <- mau_csv %>%
  filter(`Unified Name` %in% target_games) %>%
  mutate(
    Date = as.Date(Date),
    Month = month(Date),
    Year = year(Date),
    YearMonth = paste0(Year, "-", sprintf("%02d", Month))
  ) %>%
  filter(Month >= 1 & Month <= 6) %>%  # YTD (Jan-Jun)
  # First sum MAU across all countries/platforms for each game/month
  group_by(Year, YearMonth, `Unified Name`) %>%
  summarise(
    MonthlyMAU = sum(MAU, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  # Then average the monthly totals for each year
  group_by(Year, `Unified Name`) %>%
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
  left_join(downloads_ytd, by = "Unified Name") %>%
  left_join(mau_ytd, by = "Unified Name") %>%
  rename(
    game_name = `Unified Name`,
    publisher = `Unified Publisher Name`
  ) %>%
  # Fix publisher for Niantic games
  mutate(
    publisher = case_when(
      game_name %in% c("Pokémon GO", "Monster Hunter Now", "Pikmin Bloom") ~ "Niantic",
      TRUE ~ publisher
    )
  )

# Add source information
combined_data <- combined_data %>%
  mutate(
    source = case_when(
      publisher == "Scopely" ~ case_when(
        game_name == "MONOPOLY GO!" ~ "First Party",
        game_name == "MARVEL Strike Force: Squad RPG" ~ "Acquisition",
        game_name == "Star Trek™ Fleet Command" ~ "Second Party",
        game_name == "Stumble Guys" ~ "Acquisition",
        game_name == "Yahtzee® with Buddies Dice" ~ "First Party",
        game_name == "Tiki Solitaire TriPeaks" ~ "Acquisition",
        game_name == "Scrabble GO-Classic Word Game" ~ "First Party",
        game_name == "WWE Champions" ~ "Second Party",
        game_name == "Looney Tunes™ World of Mayhem" ~ "Second Party",
        game_name == "Wheel of Fortune: Show Puzzles" ~ "First Party",
        game_name == "GSN Casino: Slot Machine Games" ~ "Acquisition",
        game_name == "Dice With Buddies: Social Game" ~ "First Party",
        game_name == "Garden Joy: Design Game" ~ "Investment Publishing",
        TRUE ~ ""
      ),
      publisher == "Niantic" ~ "Acquisition",
      TRUE ~ ""
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

# Calculate grand total row for all games
grand_total <- data.frame(
  game_name = "Total",
  publisher = "Grand Total",
  source = "",
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

# Calculate growth for grand total
grand_total <- grand_total %>%
  mutate(
    revenue_growth_24_25 = round((revenue_2025 - revenue_2024) / revenue_2024 * 100, 0),
    downloads_growth_24_25 = round((downloads_2025 - downloads_2024) / downloads_2024 * 100, 0),
    mau_growth_24_25 = round((mau_2025 - mau_2024) / mau_2024 * 100, 0)
  )

# Combine data
table_data <- bind_rows(grand_total, combined_data)

# Create the GT table
message("Creating GT table...")
final_table <- table_data %>%
  select(rank, game_name, source, 
         revenue_2025, revenue_2024, revenue_2023, revenue_growth_24_25,
         mau_2025, mau_2024, mau_2023, mau_growth_24_25, 
         downloads_2025, downloads_2024, downloads_2023, downloads_growth_24_25) %>%
  gt() %>%
  tab_header(
    title = "Scopely Portfolio Scorecard",
    subtitle = "Year-to-Date Metrics (January - June)"
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
  fmt_percent(
    columns = c(revenue_growth_24_25, mau_growth_24_25, downloads_growth_24_25),
    decimals = 0,
    scale_values = FALSE
  ) %>%
  # Replace NA with dash
  sub_missing(
    columns = everything(),
    missing_text = "—"
  ) %>%
  # Column labels
  cols_label(
    rank = "#",
    game_name = "Game",
    source = "Development Origin",
    revenue_2025 = "2025",
    revenue_2024 = "2024",
    revenue_2023 = "2023",
    revenue_growth_24_25 = "YTD '24-'25",
    mau_2025 = "2025",
    mau_2024 = "2024",
    mau_2023 = "2023",
    mau_growth_24_25 = "YTD '24-'25",
    downloads_2025 = "2025",
    downloads_2024 = "2024",
    downloads_2023 = "2023",
    downloads_growth_24_25 = "YTD '24-'25"
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
  # Styling
  tab_style(
    style = list(
      cell_text(weight = "bold", size = px(16)),
      cell_fill(color = "#E0E0E0")
    ),
    locations = cells_body(rows = 1)
  ) %>%
  tab_style(
    style = list(
      cell_fill(color = "#F5F5F5")
    ),
    locations = cells_body(rows = seq(2, nrow(table_data)))
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
  # Notes
  tab_source_note("Source: Sensor Tower API, Jan-Jun all years") %>%
  tab_source_note("MAU: Average monthly active users | Revenue includes iOS and Android combined") %>%
  tab_footnote(
    footnote = "Launched April 2023",
    locations = cells_body(columns = game_name, rows = game_name == "MONOPOLY GO!")
  ) %>%
  tab_footnote(
    footnote = "Launched September 2023", 
    locations = cells_body(columns = game_name, rows = game_name == "Monster Hunter Now")
  ) %>%
  # Options
  tab_options(
    table.font.size = px(12),
    heading.title.font.size = px(20),
    heading.subtitle.font.size = px(16),
    column_labels.font.weight = "bold"
  )

# Save the table
gtsave(final_table, "output/scopely_portfolio_performance.png",
       vwidth = 1800, vheight = 1200)

message("\n✓ Portfolio table saved as: output/scopely_portfolio_performance.png")

# Print summary statistics
message("\n=== Key Metrics (2025 YTD) ===")
message(glue("Total Revenue: ${format(grand_total$revenue_2025/1e9, nsmall = 2)}B"))
message(glue("Total Average MAU: {format(grand_total$mau_2025/1e6, nsmall = 1)}M"))
message(glue("Total Downloads: {format(grand_total$downloads_2025/1e6, nsmall = 0)}M"))

message("\n=== Year-over-Year Growth (2024-2025) ===")
message(glue("Revenue Growth: {grand_total$revenue_growth_24_25}%"))
message(glue("MAU Growth: {grand_total$mau_growth_24_25}%"))
message(glue("Downloads Growth: {grand_total$downloads_growth_24_25}%"))

# Save data for validation
write.csv(combined_data, "output/gt_table_data.csv", row.names = FALSE)

message("\n✓ Script completed successfully!")