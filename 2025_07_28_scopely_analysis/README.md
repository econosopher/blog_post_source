# Scopely vs Niantic Performance Analysis

This project analyzes Scopely and Niantic's mobile game performance, comparing year-to-date metrics for 2023-2025 with validated data from CSV files.

## Analysis Overview

- **Publishers**: Scopely vs Niantic comparative analysis
- **Time Period**: January - July YTD for 2023, 2024, and 2025
- **Data Sources**: 
  - Downloads: Validated from Sensor Tower CSV export
  - MAU: Average monthly active users from Sensor Tower CSV
  - Revenue: 2025 from API, 2023-2024 estimated
- **Key Metrics**: 
  - Downloads (YTD)
  - Average MAU (Monthly Active Users)
  - Revenue (YTD)
  - Year-over-year growth
  - Revenue per MAU

## Scripts

Only two main scripts:

1. **`scopely_gt_table_ytd.R`** - Main GT table generation script that creates the comprehensive comparison table
2. **`unified_tests.R`** - Validation and testing script

## Setup

1. Ensure your Sensor Tower API token is set:
```r
Sys.setenv(SENSORTOWER_AUTH_TOKEN = "your_token_here")
```

2. Install required packages:
```r
if (!require("pacman")) install.packages("pacman")
pacman::p_load(sensortowerR, dplyr, tidyr, readr, gt, webshot2, scales)
```

3. Ensure CSV validation files are in place:
- `validation/Unified Downloads Jan 2023 to Jul 2025.csv`
- `validation/Active Users Data Jan 2023 to Jun 2025.csv`

4. Run the analysis:
```r
source("scopely_gt_table_ytd.R")
```

## Output

The main script generates:
- `output/scopely_niantic_comprehensive_with_mau.png` - Comprehensive GT table with all metrics

## Key Findings

- **Monopoly GO!**: Exceptional monetization at $18.43/MAU despite declining user base
- **Monster Hunter Now**: Highest revenue per user at $32.94/MAU
- **Pokémon GO**: Maintains massive 37M MAU with $8.26/MAU monetization
- **MARVEL Strike Force**: Strong $12.07/MAU with stable 1M user base
- **Stumble Guys**: Massive downloads but low monetization (MAU data not available)

## Data Validation

Downloads data has been validated against Sensor Tower CSV exports to ensure accuracy. MAU data is calculated as averages for the YTD period from the Active Users CSV file.