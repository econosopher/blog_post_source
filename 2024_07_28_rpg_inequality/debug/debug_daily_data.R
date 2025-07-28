library(tidyverse)
library(sensortowerR)

# Check what we get from daily revenue data
test_app <- "1094591345"  # Pokemon GO

daily_data <- st_sales_report(
  app_ids = test_app,
  os = "ios",
  countries = "US", 
  start_date = as.character(Sys.Date() - 30),
  end_date = as.character(Sys.Date() - 1),
  date_granularity = "daily"
)

cat("Daily data structure:\n")
print(str(daily_data))

cat("\n\nUnique app_ids:\n")
print(unique(daily_data$app_id))
print(class(daily_data$app_id))

cat("\n\nSample data:\n")
print(head(daily_data %>% select(app_id, date, total_revenue), 5))

# Check if we can calculate Gini
revenues <- daily_data$total_revenue
cat("\n\nRevenue values:\n")
cat(sprintf("- Non-NA values: %d\n", sum(!is.na(revenues))))
cat(sprintf("- Positive values: %d\n", sum(revenues > 0, na.rm = TRUE)))
cat(sprintf("- Min: %.2f, Max: %.2f\n", min(revenues, na.rm = TRUE), max(revenues, na.rm = TRUE)))