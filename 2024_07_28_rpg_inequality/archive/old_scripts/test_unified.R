library(tidyverse)
library(sensortowerR)

# Test unified endpoint with improved deduplication
cat("Testing unified endpoint with deduplication...\n")

top_rpgs <- st_top_charts(
  measure = "revenue",
  category = 7014,  # RPG
  os = "unified",
  regions = "US",
  time_range = "month",
  limit = 5,
  enrich_response = TRUE,
  deduplicate_apps = TRUE  # Ensure proper deduplication
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

# Check if unified IDs are properly maintained
if ("unified_app_id" %in% names(top_rpgs)) {
  cat("\nUnified app IDs present - checking format:\n")
  # Check if they're hex format (true unified IDs)
  sample_ids <- head(top_rpgs$unified_app_id, 3)
  for (id in sample_ids) {
    is_hex <- grepl("^[a-f0-9]{24}$", id)
    cat(sprintf("  %s: %s\n", id, ifelse(is_hex, "Valid unified ID", "Platform-specific ID")))
  }
}