# SUPERVIVE Player Overlap Analysis

This directory contains scripts for analyzing player overlap data for SUPERVIVE using the Video Game Insights API.

## Scripts

### 1. `analyze_supervive_overlap.R` (Main Script)
The primary analysis script that:
- Fetches player overlap data for SUPERVIVE from the Video Game Insights API
- Identifies which games SUPERVIVE players are most likely to own compared to average Steam users
- Generates visualizations and exports data for blog posts
- Includes game name mapping for better readability

**To run:**
```bash
R --vanilla < analyze_supervive_overlap.R
```

### 2. `test_supervive_api.R` (Test/Debug Script)
A diagnostic script for testing:
- API connection and authentication
- Response format validation
- Game metadata lookup
- Data processing functions

**To run:**
```bash
R --vanilla < test_supervive_api.R
```

## Output Files

All output files are saved in the `output/` directory:
- `supervive_player_overlap_analysis.csv` - Complete analysis data with game names
- `supervive_overlap_gt_table.png` - Professional GT table showing top 20 games by overlap index
- `supervive_overlap_visualization.png` - Bar chart visualization showing top 15 games by overlap index
- `supervive_country_distribution.csv` - Country distribution data (if available)
- `supervive_country_gt_table.png` - GT table showing geographic distribution (if available)

Note: Country distribution data may not be available for recently released games.

## Key Findings

The analysis reveals that SUPERVIVE players have strong overlap with:
1. **Competitive multiplayer games** - Particularly tactical/strategic shooters
2. **Valve titles** - 88.5% own Counter-Strike 2, 64.4% own Dota 2
3. **Games with modding communities** - Garry's Mod shows 3.0x overlap index

Top games by overlap index (how much more likely to own):
- Killing Floor (4.2x)
- Call of Duty 4: Modern Warfare (3.8x)
- Garry's Mod (3.0x)

## Requirements

- R with the following packages:
  - tidyverse
  - httr2
  - jsonlite
  - dotenv
  - ggplot2
- VGI_AUTH_TOKEN environment variable set in `../../.env`

## Data Source

Video Game Insights API v3
- Endpoint: `/player-insights/games/{steam_app_id}/player-overlap`
- Documentation: https://vginsights.com/api