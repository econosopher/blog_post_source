# ============================================================================
# SUPERVIVE API Test Script
# ============================================================================
# This script tests the Video Game Insights API connection and response format
# for debugging purposes.
#
# Author: Game Economics Consulting
# Date: 2025-07-29
# ============================================================================

library(httr2)
library(jsonlite)
library(dotenv)
library(devtools)
library(tidyverse)

# Load environment variables
dotenv::load_dot_env("../../.env")

# Load VideoGameInsights package
load_all("../../videogameinsightsR")

# Test configuration
TEST_GAME_ID <- 1283700  # SUPERVIVE
TEST_LIMIT <- 5

# Function to test API connection
test_api_connection <- function() {
  cat("=== TESTING VIDEO GAME INSIGHTS API CONNECTION ===\n\n")
  
  # Check auth token
  auth_token <- Sys.getenv("VGI_AUTH_TOKEN")
  if (auth_token == "") {
    cat("❌ ERROR: VGI_AUTH_TOKEN environment variable not set\n")
    return(FALSE)
  }
  cat("✓ Auth token found (first 10 chars):", substr(auth_token, 1, 10), "...\n")
  
  # Test API endpoint
  base_url <- "https://vginsights.com/api/v3"
  endpoint <- paste0("player-insights/games/", TEST_GAME_ID, "/player-overlap")
  full_url <- paste0(base_url, "/", endpoint)
  
  cat("\n📡 Testing API endpoint:\n")
  cat("   URL:", full_url, "\n")
  cat("   Method: GET\n")
  cat("   Limit:", TEST_LIMIT, "\n")
  
  # Make request
  cat("\n🔄 Sending request...\n")
  
  tryCatch({
    req <- request(base_url) |>
      req_url_path_append(endpoint) |>
      req_headers("api-key" = auth_token) |>
      req_url_query(limit = TEST_LIMIT, offset = 0) |>
      req_user_agent("videogameinsightsR-test")
    
    resp <- req |> req_perform()
    
    # Check response status
    status <- resp_status(resp)
    cat("\n📊 Response Status:", status, "\n")
    
    if (status == 200) {
      cat("✓ API connection successful!\n")
      
      # Parse response
      raw_response <- resp_body_string(resp)
      cat("\n📄 Raw response (first 500 chars):\n")
      cat(substr(raw_response, 1, 500), "...\n")
      
      # Parse JSON
      parsed <- fromJSON(raw_response, flatten = TRUE)
      
      cat("\n🔍 Response structure:\n")
      cat("   Type:", typeof(parsed), "\n")
      cat("   Class:", class(parsed), "\n")
      cat("   Top-level fields:", paste(names(parsed), collapse = ", "), "\n")
      
      # Check playerOverlaps
      if ("playerOverlaps" %in% names(parsed)) {
        overlaps <- parsed$playerOverlaps
        cat("\n✓ playerOverlaps found!\n")
        cat("   Number of games:", nrow(overlaps), "\n")
        cat("   Columns:", paste(names(overlaps), collapse = ", "), "\n")
        
        # Show first game
        if (nrow(overlaps) > 0) {
          cat("\n📋 First game data:\n")
          first_game <- as.list(overlaps[1,])
          for (field in names(first_game)) {
            cat(sprintf("   %s: %s\n", field, first_game[[field]]))
          }
        }
      } else {
        cat("\n❌ No playerOverlaps field found in response\n")
      }
      
      return(TRUE)
      
    } else {
      cat("❌ API request failed with status:", status, "\n")
      error_body <- tryCatch(
        resp_body_string(resp),
        error = function(e) "Unable to parse error response"
      )
      cat("   Error message:", error_body, "\n")
      return(FALSE)
    }
    
  }, error = function(e) {
    cat("\n❌ Error occurred:", e$message, "\n")
    return(FALSE)
  })
}

# Function to test game metadata lookup
test_game_metadata <- function() {
  cat("\n\n=== TESTING GAME METADATA LOOKUP ===\n")
  
  # Test game IDs
  test_ids <- c(730, 570, 440, 1250, 2400)  # CS2, Dota 2, TF2, Killing Floor, Spiderwick
  cat("\nTesting metadata API for game IDs:", paste(test_ids, collapse = ", "), "\n")
  
  # Test batch function
  cat("\n1. Testing batch metadata function:\n")
  tryCatch({
    batch_result <- vgi_game_metadata_batch(test_ids)
    if (!is.null(batch_result) && nrow(batch_result) > 0) {
      cat("✓ Batch function returned", nrow(batch_result), "games\n")
      print(batch_result %>% select(steam_app_id, name))
    } else {
      cat("❌ Batch function returned no data\n")
    }
  }, error = function(e) {
    cat("❌ Batch function error:", e$message, "\n")
  })
  
  # Test individual lookups
  cat("\n2. Testing individual metadata lookups:\n")
  for (id in test_ids[1:3]) {  # Just test first 3 to save API calls
    tryCatch({
      metadata <- vgi_game_metadata(id)
      if (!is.null(metadata) && !is.null(metadata$name)) {
        cat(sprintf("   ✓ %d: %s\n", id, metadata$name))
      } else {
        cat(sprintf("   ❌ %d: No name returned\n", id))
      }
    }, error = function(e) {
      cat(sprintf("   ❌ %d: Error - %s\n", id, e$message))
    })
  }
}

# Function to test data processing
test_data_processing <- function() {
  cat("\n\n=== TESTING DATA PROCESSING ===\n")
  
  # Create sample data
  sample_data <- data.frame(
    steamAppId = c(730, 570, 999999),
    unitsSoldOverlapIndex = c(1.2, 2.5, 3.8),
    unitsSoldOverlapPercentage = c(88.5, 64.4, 5.0),
    medianPlaytime = c(10.5, 25.3, 2.1)
  )
  
  cat("\n📊 Sample overlap data:\n")
  print(sample_data)
  
  # Test categorization
  cat("\n🏷️  Testing overlap strength categorization:\n")
  categorized <- sample_data %>%
    mutate(strength = case_when(
      unitsSoldOverlapIndex > 2.0 ~ "Strong",
      unitsSoldOverlapIndex > 1.5 ~ "Moderate",
      unitsSoldOverlapIndex > 1.0 ~ "Slight",
      TRUE ~ "Below Average"
    ))
  print(categorized)
}

# Run all tests
run_all_tests <- function() {
  cat("========================================\n")
  cat("SUPERVIVE API TEST SUITE\n")
  cat("========================================\n")
  cat("Date:", Sys.Date(), "\n")
  cat("Time:", format(Sys.time(), "%H:%M:%S"), "\n")
  cat("========================================\n\n")
  
  # Run tests
  api_success <- test_api_connection()
  test_game_metadata()
  test_data_processing()
  
  cat("\n\n========================================\n")
  cat("TEST SUMMARY\n")
  cat("========================================\n")
  if (api_success) {
    cat("✓ All API tests passed!\n")
    cat("✓ Ready to run main analysis script.\n")
  } else {
    cat("❌ API tests failed. Please check:\n")
    cat("   1. VGI_AUTH_TOKEN is set correctly\n")
    cat("   2. Internet connection is active\n")
    cat("   3. API endpoint is accessible\n")
  }
  cat("========================================\n")
}

# Execute tests
run_all_tests()