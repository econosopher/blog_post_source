library(tidyverse)
library(sensortowerR)

# Let's check what the actual revenue values are
top_puzzles <- st_top_charts(
  measure = "revenue",
  category = 7003,  # Puzzle
  os = "ios",
  regions = "US",
  time_range = "month",
  limit = 5
)

cat("Raw revenue data from st_top_charts:\n")
print(top_puzzles %>% select(app_id, revenue_absolute, current_revenue_value))

# Get app details to see the names
details <- st_app_details(
  app_ids = as.character(top_puzzles$app_id[1:3]),
  os = "ios"
)

cat("\n\nTop 3 games with revenue:\n")
for (i in 1:3) {
  app_name <- details$app_name[details$app_id == top_puzzles$app_id[i]]
  revenue_val <- top_puzzles$revenue_absolute[i]
  cat(sprintf("%d. %s: revenue_absolute = %s (%.2f)\n", 
              i, app_name, format(revenue_val, big.mark = ","), revenue_val))
  
  # Check if this is already in millions
  if (revenue_val > 1e9) {
    cat(sprintf("   If this is in dollars: $%.1fB\n", revenue_val / 1e9))
    cat(sprintf("   If this is already in thousands: $%.1fM\n", revenue_val / 1e6))
  }
}

# Let's also check the custom tags for revenue
if ("custom_tags.Last 30 Days Revenue (WW)" %in% names(top_puzzles)) {
  cat("\n\nCustom tag revenue values:\n")
  print(top_puzzles %>% select(app_id, `custom_tags.Last 30 Days Revenue (WW)`))
}