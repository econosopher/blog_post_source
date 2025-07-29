# Scopely Analysis Project Settings

This project analyzes Scopely and Niantic gaming revenue data using both CSV exports and the sensortowerR API.

## CSV File Management

### Required CSV Files
The following CSV files in the `validation/` directory are REQUIRED for the analysis:
- `Unified Revenue Jan 2023 to Jun 2025.csv` - Revenue data for all games
- `Unified Downloads Jan 2023 - Jun 2025.csv` - Download metrics  
- `Active Users Data Jan 2023 to Jun 2025.csv` - MAU data

### Output CSV Files
The following output files are generated and should be kept:
- `output/api_validation_results.csv` - API vs CSV validation results
- `output/gt_table_data.csv` - Data used for GT table generation

### Temporary CSV Cleanup Policy
- **ALWAYS clean up temporary CSV files** after their purpose is served
- **DO NOT create intermediate CSV files** unless absolutely necessary
- **Use data frames in memory** instead of writing intermediate results to disk
- **If a temporary CSV must be created**, use the pattern:
  ```r
  temp_file <- tempfile(pattern = "analysis_", fileext = ".csv")
  # ... use the file ...
  unlink(temp_file)  # Clean up immediately after use
  ```
- **Never commit temporary CSV files** to version control

## Visualization Policy
- **USE GT TABLES EXCLUSIVELY** for all data visualizations in this project
- **DO NOT create ggplot2 charts** or other visualization types
- **GT tables provide**:
  - Professional, publication-ready formatting
  - Consistent styling across all outputs
  - Better data density and readability
  - Integrated titles, subtitles, and footnotes
- **When asked to create any visualization**, generate a GT table instead
- **Export GT tables as PNG** using `gtsave()` for sharing

## Project Structure
- `unified_tests.R` - Comprehensive API validation tests
- `scopely_gt_table_ytd.R` - GT table generation for Scopely vs Niantic comparison
- `validation/` - Source CSV data exports from Sensor Tower
- `output/` - Generated visualizations and final outputs

## Data Validation
- Always validate that API data matches CSV exports
- Use the correct app IDs verified through st_app_info() search
- Handle platform-specific column name differences (iOS: total_revenue, Android: revenue)
- Ensure type consistency (convert iOS app_id from integer to character)