# Combined Toy Blast vs Fate/Grand Order Daily Revenue Distribution
# Shows both games on the same chart for direct comparison

library(tidyverse)
library(sensortowerR)
library(ggplot2)
library(scales)
library(lubridate)

# Configuration
TOY_BLAST_ID <- "880047117"  # iOS App ID for Toy Blast
FATE_GO_ID <- "1183802626"   # iOS App ID for Fate/Grand Order (US)

# Calculate Gini coefficient
calculate_gini <- function(values) {
  values <- values[!is.na(values) & values > 0]
  if (length(values) < 2) return(NA)
  
  values <- sort(values)
  n <- length(values)
  index <- 1:n
  
  gini <- (2 * sum(index * values)) / (n * sum(values)) - (n + 1) / n
  return(gini)
}

# Cache configuration
cache_dir <- ".cache"
if (!dir.exists(cache_dir)) dir.create(cache_dir)

# Fetch data for both games
cat("Fetching 180-day revenue data for both games...\n")

end_date <- Sys.Date() - 1
start_date <- end_date - 179  # 180 days total

# Cache file names
toy_blast_cache <- file.path(cache_dir, sprintf("toy_blast_data_%s_to_%s.rds", start_date, end_date))
fate_go_cache <- file.path(cache_dir, sprintf("fate_go_data_%s_to_%s.rds", start_date, end_date))

# Fetch Toy Blast data
if (file.exists(toy_blast_cache)) {
  cat("- Loading Toy Blast data from cache...\n")
  toy_blast_data <- readRDS(toy_blast_cache)
} else {
  cat("- Fetching Toy Blast data from API...\n")
  toy_blast_data <- st_sales_report(
    app_ids = TOY_BLAST_ID,
    os = "ios",
    countries = "US",
    start_date = as.character(start_date),
    end_date = as.character(end_date),
    date_granularity = "daily"
  )
  saveRDS(toy_blast_data, toy_blast_cache)
  cat("  Data cached for future use.\n")
}

# Fetch Fate/Grand Order data
if (file.exists(fate_go_cache)) {
  cat("- Loading Fate/Grand Order data from cache...\n")
  fate_go_data <- readRDS(fate_go_cache)
} else {
  cat("- Fetching Fate/Grand Order data from API...\n")
  fate_go_data <- st_sales_report(
    app_ids = FATE_GO_ID,
    os = "ios",
    countries = "US",
    start_date = as.character(start_date),
    end_date = as.character(end_date),
    date_granularity = "daily"
  )
  saveRDS(fate_go_data, fate_go_cache)
  cat("  Data cached for future use.\n")
}

# Process data for both games
process_game_data <- function(data, game_name) {
  data %>%
    mutate(
      date = as.Date(date),
      total_revenue = coalesce(total_revenue, 0),
      game = game_name
    ) %>%
    mutate(
      total_period_revenue = sum(total_revenue),
      pct_contribution = (total_revenue / total_period_revenue) * 100
    ) %>%
    arrange(pct_contribution) %>%
    mutate(
      rank = row_number(),
      cumulative_pct = cumsum(pct_contribution)
    )
}

toy_blast_processed <- process_game_data(toy_blast_data, "Toy Blast")
fate_go_processed <- process_game_data(fate_go_data, "Fate/Grand Order")

# Combine data
combined_data <- bind_rows(toy_blast_processed, fate_go_processed)

# Calculate summary statistics
summary_stats <- combined_data %>%
  group_by(game) %>%
  summarise(
    total_revenue = first(total_period_revenue),
    avg_daily = mean(total_revenue),
    median_daily = median(total_revenue),
    max_pct = max(pct_contribution),
    min_pct = min(pct_contribution),
    top_10_pct = sum(sort(pct_contribution, decreasing = TRUE)[1:10]),
    .groups = "drop"
  )

# Calculate Gini separately for each game
toy_blast_gini <- calculate_gini(toy_blast_processed$total_revenue)
fate_go_gini <- calculate_gini(fate_go_processed$total_revenue)

summary_stats <- summary_stats %>%
  mutate(gini = case_when(
    game == "Toy Blast" ~ toy_blast_gini,
    game == "Fate/Grand Order" ~ fate_go_gini
  ))

# Create overlay visualization for direct comparison
p_overlay <- ggplot(combined_data, aes(x = rank, y = pct_contribution, fill = game)) +
  # Use transparency to show overlap
  geom_bar(stat = "identity", position = "identity", alpha = 0.6, width = 1) +
  
  # Add smooth lines
  geom_smooth(aes(color = game), method = "loess", se = FALSE, size = 1.5, span = 0.3) +
  
  # Custom colors - more distinct
  scale_fill_manual(values = c("Toy Blast" = "#FF6B6B", "Fate/Grand Order" = "#4ECDC4")) +
  scale_color_manual(values = c("Toy Blast" = "#C44444", "Fate/Grand Order" = "#2B9B94")) +
  
  # Labels and formatting
  scale_y_continuous(
    labels = percent_format(scale = 1),
    breaks = seq(0, 6, by = 1)
  ) +
  scale_x_continuous(
    breaks = c(1, 45, 90, 135, 180),
    labels = c("1st", "45th", "90th", "135th", "180th")
  ) +
  
  labs(
    title = "Revenue Volatility Comparison: Stable vs Volatile",
    subtitle = "Daily revenue as percent of 180-day total, ordered from lowest to highest",
    x = "Days (ordered from lowest to highest revenue)",
    y = "Percent of 180-day Revenue",
    caption = sprintf("Toy Blast (green): Stable revenue model | Fate/Grand Order (blue): Event-driven spikes\nData: %s to %s | US Market | Platform: iOS", 
                     format(start_date, "%B %d, %Y"), format(end_date, "%B %d, %Y"))
  ) +
  
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12, color = "gray40"),
    plot.caption = element_text(size = 10, color = "gray50", lineheight = 1.2),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    legend.position = "top",
    legend.title = element_blank(),
    plot.title.position = "plot",
    plot.caption.position = "plot"
  )

# Add annotations
toy_stats <- filter(summary_stats, game == "Toy Blast")
fate_stats <- filter(summary_stats, game == "Fate/Grand Order")

p_overlay <- p_overlay +
  # Toy Blast annotation
  annotate("text", x = 30, y = 0.8, 
           label = sprintf("Toy Blast\nGini: %.3f\nTop day: %.1f%%", 
                          toy_stats$gini, toy_stats$max_pct),
           hjust = 0, vjust = 0, size = 3.5, color = "#C44444", fontface = "bold") +
  # Fate/GO annotation  
  annotate("text", x = 140, y = 4.5,
           label = sprintf("Fate/Grand Order\nGini: %.3f\nTop day: %.1f%%\nTop 10 days: %.1f%%", 
                          fate_stats$gini, fate_stats$max_pct, fate_stats$top_10_pct),
           hjust = 0, vjust = 1, size = 3.5, color = "#2B9B94", fontface = "bold")

# Save the overlay plot
ggsave("visualizations/toy_blast_fate_go_comparison_overlay.png", p_overlay, 
       width = 14, height = 8, dpi = 300)

# Print summary
cat("\n========== COMPARISON SUMMARY ==========\n")
print(summary_stats %>%
  mutate(
    total_revenue_fmt = dollar(total_revenue, scale = 1e-6, suffix = "M"),
    avg_daily_fmt = dollar(avg_daily, scale = 1e-3, suffix = "K")
  ) %>%
  select(game, total_revenue_fmt, avg_daily_fmt, gini, max_pct))

cat("\nVisualization saved:\n")
cat("- toy_blast_fate_go_comparison_overlay.png\n")