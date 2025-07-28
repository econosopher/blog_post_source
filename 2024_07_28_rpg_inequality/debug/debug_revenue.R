library(tidyverse)
library(sensortowerR)

# Get top charts to debug revenue values
top_rpgs <- st_top_charts(
  measure = "revenue",
  category = 7014,
  os = "ios",
  regions = "US",
  time_range = "month",
  limit = 5
)

cat("Column names in top_rpgs:\n")
print(names(top_rpgs))

cat("\n\nFirst few rows:\n")
print(head(top_rpgs, 3))

cat("\n\nRevenue-related columns:\n")
revenue_cols <- grep("revenue", names(top_rpgs), value = TRUE, ignore.case = TRUE)
print(revenue_cols)

if ("revenue_absolute" %in% names(top_rpgs)) {
  cat("\n\nrevenue_absolute values:\n")
  print(head(top_rpgs$revenue_absolute, 5))
}

if ("current_revenue_value" %in% names(top_rpgs)) {
  cat("\n\ncurrent_revenue_value values:\n")
  print(head(top_rpgs$current_revenue_value, 5))
}