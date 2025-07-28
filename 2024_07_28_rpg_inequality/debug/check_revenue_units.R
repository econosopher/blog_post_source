library(tidyverse)
library(sensortowerR)

# Get one game's data
candy_crush_id <- "553834731"

# Check daily sales data
daily_data <- st_sales_report(
  app_ids = candy_crush_id,
  os = "ios", 
  countries = "US",
  start_date = as.character(Sys.Date() - 30),
  end_date = as.character(Sys.Date() - 1),
  date_granularity = "daily"
)

cat("Daily revenue data sample:\n")
print(head(daily_data %>% select(date, total_revenue, iphone_revenue_cents, total_downloads), 5))

# Sum up 30 days
total_30d <- sum(daily_data$total_revenue, na.rm = TRUE)
cat(sprintf("\n30-day total from daily data: $%s\n", format(total_30d, big.mark = ",")))

# Compare with top charts
top_charts <- st_top_charts(
  measure = "revenue",
  category = 7003,
  os = "ios",
  regions = "US",
  time_range = "month",
  limit = 5
)

candy_crush_row <- top_charts %>% filter(app_id == candy_crush_id)
cat(sprintf("\nrevenue_absolute from top_charts: %s\n", 
            format(candy_crush_row$revenue_absolute, big.mark = ",")))

# Check if revenue_absolute is in cents
if (nrow(candy_crush_row) > 0) {
  ratio <- candy_crush_row$revenue_absolute / total_30d
  cat(sprintf("\nRatio of revenue_absolute to daily sum: %.1f\n", ratio))
  
  if (abs(ratio - 100) < 10) {
    cat("=> revenue_absolute appears to be in CENTS!\n")
    cat(sprintf("=> Actual 30-day revenue: $%.1fM\n", candy_crush_row$revenue_absolute / 1e8))
  }
}