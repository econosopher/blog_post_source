library(tidyverse)
library(sensortowerR)

# Test unified endpoint
cat("Testing unified endpoint...\n")

top_rpgs <- st_top_charts(
  measure = "revenue",
  category = 7014,  # RPG
  os = "unified",
  regions = "US",
  time_range = "month",
  limit = 5
)

cat("\nColumn names:\n")
print(names(top_rpgs))

cat("\nFirst few rows:\n")
print(head(top_rpgs, 3))

# Check for revenue columns
revenue_cols <- grep("revenue", names(top_rpgs), value = TRUE, ignore.case = TRUE)
cat("\nRevenue columns found:", paste(revenue_cols, collapse = ", "), "\n")

# Check for app ID columns
id_cols <- grep("app_id|unified", names(top_rpgs), value = TRUE, ignore.case = TRUE)
cat("\nID columns found:", paste(id_cols, collapse = ", "), "\n")