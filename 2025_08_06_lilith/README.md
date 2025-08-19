# Lilith Games Portfolio Analysis

Analysis of Lilith Games mobile gaming portfolio performance using Sensor Tower data.

## Overview

This project analyzes the performance of Lilith Games' mobile gaming portfolio, including flagship titles like AFK Arena, AFK Journey, Rise of Kingdoms, and Call of Dragons.

## Key Metrics Tracked

- **Revenue** - Year-to-date revenue across iOS and Android
- **Monthly Active Users (MAU)** - Average monthly active users
- **Downloads** - Total downloads for each period
- **Year-over-Year Growth** - Growth rates for all key metrics

## Games Analyzed

### RPG Titles
- AFK Arena (Original IP)
- AFK Journey (Sequel, launched March 2024)
- Dislyte (Original IP)
- BLOODLINE: HEROES OF LITHAS (Original IP)
- Soul Hunters (Legacy title)

### Strategy Titles
- Rise of Kingdoms (Original IP)
- Call of Dragons (Sequel, launched September 2023)
- Warpath (WWII strategy)
- Art of Conquest: Dark Horizon

## Data Source

All data is sourced from Sensor Tower CSV exports covering January 2023 through July 2025.

## Usage

Run the main analysis script:

```bash
Rscript lilith_gt_table_ytd.R
```

This will generate:
- `output/lilith_portfolio_performance.png` - GT table visualization
- `output/gt_table_data.csv` - Underlying data

## Requirements

- R 4.0+
- Required R packages: dplyr, tidyr, readr, gt, webshot2, scales, glue, lubridate, pacman

## Project Structure

```
2025_08_06_lilith/
├── lilith_gt_table_ytd.R    # Main analysis script
├── validation/               # Sensor Tower CSV exports (place here)
├── output/                   # Generated tables and data
├── CLAUDE.md                 # Project configuration
└── README.md                 # This file
```