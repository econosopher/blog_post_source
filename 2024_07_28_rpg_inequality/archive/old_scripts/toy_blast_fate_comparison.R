# Toy Blast vs Fate/Grand Order Daily Revenue Distribution Analysis
# Shows percent of 180-day revenue each day contributed, ordered from least to most

library(tidyverse)
library(sensortowerR)
library(ggplot2)
library(scales)
library(lubridate)

# Configuration
TOY_BLAST_ID <- "880047117"  # iOS App ID for Toy Blast
FATE_GO_ID <- "1183802626"   # iOS App ID for Fate/Grand Order (US)

# Function to create revenue distribution chart
create_revenue_distribution_chart <- function(app_id, app_name) {
  cat(sprintf("\nFetching 180-day data for %s...\n", app_name))
  
  # Get daily revenue data
  end_date <- Sys.Date() - 1
  start_date <- end_date - 179  # 180 days total
  
  daily_data <- st_sales_report(
    app_ids = app_id,
    os = "ios",
    countries = "US",
    start_date = as.character(start_date),
    end_date = as.character(end_date),
    date_granularity = "daily"
  )
  
  if (is.null(daily_data) || nrow(daily_data) == 0) {
    warning(sprintf("No data found for %s", app_name))
    return(NULL)
  }
  
  # Calculate percentage contribution for each day
  revenue_analysis <- daily_data %>%
    mutate(
      date = as.Date(date),
      total_revenue = coalesce(total_revenue, 0)
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
  
  # Create the plot
  p <- ggplot(revenue_analysis, aes(x = rank, y = pct_contribution)) +
    geom_bar(stat = "identity", fill = ifelse(app_name == "Toy Blast", "#4CAF50", "#2196F3"), 
             alpha = 0.8, width = 1) +
    
    # Add a smooth line to show the trend
    geom_smooth(method = "loess", se = FALSE, color = "darkred", size = 1.2, span = 0.3) +
    
    # Labels and formatting
    scale_y_continuous(
      labels = percent_format(scale = 1),
      breaks = seq(0, ceiling(max(revenue_analysis$pct_contribution)), by = 0.5)
    ) +
    scale_x_continuous(
      breaks = c(1, 45, 90, 135, 180),
      labels = c("1st", "45th", "90th", "135th", "180th")
    ) +
    
    labs(
      title = sprintf("%s: Daily Revenue Distribution (180 days)", app_name),
      subtitle = "Each bar represents one day's contribution to total 180-day revenue",
      x = "Days (ordered from lowest to highest revenue)",
      y = "Percent of 180-day Revenue",
      caption = sprintf("Data: %s to %s | US Market | iOS", 
                       format(start_date, "%b %d, %Y"), 
                       format(end_date, "%b %d, %Y"))
    ) +
    
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 12, color = "gray40"),
      plot.caption = element_text(size = 10, color = "gray50"),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      plot.title.position = "plot",
      plot.caption.position = "plot"
    )
  
  # Add annotations for key statistics
  total_revenue_millions <- revenue_analysis$total_period_revenue[1] / 1e6
  top_10_pct <- revenue_analysis %>% 
    top_n(10, pct_contribution) %>% 
    summarise(sum(pct_contribution)) %>% 
    pull()
  
  p <- p + 
    annotate("text", x = 140, y = max(revenue_analysis$pct_contribution) * 0.9,
             label = sprintf("Total Revenue: $%.1fM\nTop 10 days: %.1f%%", 
                           total_revenue_millions, top_10_pct),
             hjust = 0, vjust = 1, size = 3.5, color = "gray30")
  
  # Save the plot
  filename <- sprintf("visualizations/%s_revenue_distribution.png", 
                     gsub("/", "_", tolower(gsub(" ", "_", app_name))))
  ggsave(filename, p, width = 12, height = 8, dpi = 300)
  
  cat(sprintf("✓ Saved: %s\n", filename))
  
  # Return summary statistics
  list(
    plot = p,
    stats = revenue_analysis,
    summary = tibble(
      app_name = app_name,
      total_revenue_180d = revenue_analysis$total_period_revenue[1],
      avg_daily_revenue = mean(revenue_analysis$total_revenue),
      median_daily_revenue = median(revenue_analysis$total_revenue),
      top_day_pct = max(revenue_analysis$pct_contribution),
      bottom_day_pct = min(revenue_analysis$pct_contribution),
      top_10_days_pct = top_10_pct,
      gini_coefficient = calculate_gini(revenue_analysis$total_revenue)
    )
  )
}

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

# Main analysis
cat("Daily Revenue Distribution Analysis\n")
cat("==================================\n")

# Create visualizations for both games
toy_blast_results <- create_revenue_distribution_chart(TOY_BLAST_ID, "Toy Blast")
fate_go_results <- create_revenue_distribution_chart(FATE_GO_ID, "Fate/Grand Order")

# Print summary comparison
cat("\n\n========== SUMMARY COMPARISON ==========\n")

if (!is.null(toy_blast_results) && !is.null(fate_go_results)) {
  comparison <- bind_rows(
    toy_blast_results$summary,
    fate_go_results$summary
  ) %>%
    mutate(
      total_revenue_fmt = scales::dollar(total_revenue_180d, scale = 1e-6, suffix = "M"),
      avg_daily_fmt = scales::dollar(avg_daily_revenue, scale = 1e-3, suffix = "K"),
      median_daily_fmt = scales::dollar(median_daily_revenue, scale = 1e-3, suffix = "K")
    )
  
  print(comparison %>% 
    select(app_name, total_revenue_fmt, avg_daily_fmt, median_daily_fmt, 
           top_day_pct, top_10_days_pct, gini_coefficient))
  
  cat("\nKey Insights:\n")
  
  # Compare volatility
  if (fate_go_results$summary$gini_coefficient > toy_blast_results$summary$gini_coefficient) {
    cat(sprintf("- Fate/Grand Order is MORE volatile (Gini: %.3f vs %.3f)\n", 
               fate_go_results$summary$gini_coefficient,
               toy_blast_results$summary$gini_coefficient))
  } else {
    cat(sprintf("- Toy Blast is MORE volatile (Gini: %.3f vs %.3f)\n", 
               toy_blast_results$summary$gini_coefficient,
               fate_go_results$summary$gini_coefficient))
  }
  
  # Compare concentration
  cat(sprintf("- Fate/GO top 10 days account for %.1f%% of revenue\n", 
             fate_go_results$summary$top_10_days_pct))
  cat(sprintf("- Toy Blast top 10 days account for %.1f%% of revenue\n", 
             toy_blast_results$summary$top_10_days_pct))
  
  # Peak days
  cat(sprintf("- Fate/GO's best day: %.1f%% of 180-day revenue\n", 
             fate_go_results$summary$top_day_pct))
  cat(sprintf("- Toy Blast's best day: %.1f%% of 180-day revenue\n", 
             toy_blast_results$summary$top_day_pct))
}

cat("\nVisualizations saved to visualizations/ folder.\n")