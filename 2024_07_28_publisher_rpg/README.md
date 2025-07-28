# Publisher RPG Analysis

This project analyzes top mobile game publishers and their revenue distribution across different game categories.

## Features

- Fetches top 10 game publishers by revenue from Sensor Tower API
- Creates a spider/radar chart showing category revenue distribution for top 5 publishers
- Generates a professional GT table with revenue metrics and market share
- Uses real-time data from Sensor Tower (requires API key)

## Setup

1. Install the sensortowerR package from GitHub:
```r
devtools::install_github("econosopher/sensortowerR")
```

2. Set your Sensor Tower API token:
```r
Sys.setenv(SENSORTOWER_AUTH_TOKEN = "your_token_here")
```

3. Run the analysis:
```r
source("publisher_rpg_analysis.R")
```

## Output

The script generates two files in the project directory:
- `publisher_rpg_spider_chart.jpg` - Spider chart showing revenue distribution by category
- `publisher_rpg_revenue_table.png` - GT table with publisher rankings and metrics

## Requirements

- R 4.0+
- sensortowerR package
- Required R packages: dplyr, tidyr, ggplot2, gt, gtExtras, and others (automatically installed)