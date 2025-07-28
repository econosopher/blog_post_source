library(tidyverse)
library(sensortowerR)

# Test what columns we get from st_sales_report
test_data <- st_sales_report(
  app_ids = "1094591345",  # Pokemon GO
  os = "ios",
  countries = "US",
  start_date = as.character(Sys.Date() - 7),
  end_date = as.character(Sys.Date() - 1),
  date_granularity = "daily"
)

cat("Columns in sales report:\n")
print(names(test_data))

cat("\n\nFirst few rows:\n")
print(head(test_data, 3))

cat("\n\nRevenue-related columns:\n")
revenue_cols <- grep("revenue|rev", names(test_data), value = TRUE, ignore.case = TRUE)
print(revenue_cols)