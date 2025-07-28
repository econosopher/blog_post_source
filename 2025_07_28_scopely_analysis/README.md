# Scopely Revenue Analysis

This project analyzes Scopely's mobile game revenue performance, comparing year-to-date metrics for 2024 and 2025.

## Analysis Overview

- **Publisher Focus**: Scopely (unified publisher analysis)
- **Time Period**: January 1 - June 30 for both 2024 and 2025
- **Metrics**: 
  - Total publisher revenue YTD
  - Individual game revenue breakdowns
  - Year-over-year comparison (% change)
  - Game-by-game performance analysis

## Setup

1. Ensure your Sensor Tower API token is set:
```r
Sys.setenv(SENSORTOWER_AUTH_TOKEN = "your_token_here")
```

2. Install required packages:
```r
if (!require("pacman")) install.packages("pacman")
pacman::p_load(sensortowerR, dplyr, tidyr, ggplot2, gt, gtExtras, scales)
```

3. Run the analysis:
```r
source("scopely_analysis.R")
```

## Output

The script generates:
- `scopely_ytd_comparison_table.png` - GT table showing YTD revenue comparison
- `scopely_game_performance_chart.png` - Visualization of game-by-game performance
- `data/scopely_analysis_data.rds` - Cached analysis data

## Data Sources

All data is sourced from Sensor Tower API using the sensortowerR package.