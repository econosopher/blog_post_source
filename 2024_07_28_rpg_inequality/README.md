# RPG Revenue Inequality Analysis

This directory contains scripts for analyzing revenue inequality in mobile RPG games using Sensor Tower data.

## Core Analysis Scripts

### 1. `us_games_volatility_with_countries.R`
Analyzes daily revenue volatility for top US mobile games and includes country income inequality comparison.

**Output:** 
- `visualizations/us_games_volatility_with_countries.png`

**Features:**
- Ranks games by Gini coefficient (revenue volatility)
- Shows % difference from the #1 ranked game
- Includes country Gini coefficients for context
- Separate sections for games and countries

### 2. `toy_blast_fate_combined_comparison.R`
Compares revenue patterns between Toy Blast (low volatility) and Fate/Grand Order (high volatility).

**Output:** 
- `visualizations/toy_blast_fate_go_comparison_overlay.png`

**Features:**
- Overlaid daily revenue patterns
- Visual comparison of volatility differences
- Highlights spiky vs stable revenue patterns

### 3. `lorenz_curves_comparison.R`
Generates Lorenz curves showing revenue concentration across different games.

**Output:** 
- `visualizations/lorenz_curves_comparison.png`

**Features:**
- Visual representation of revenue inequality
- Multiple games on same plot for comparison
- Shows how revenue is distributed across days

## Visualizations

All generated visualizations are stored in the `visualizations/` directory:

1. **us_games_volatility_with_countries.png** - Table ranking games by revenue volatility with country comparison
2. **toy_blast_fate_go_comparison_overlay.png** - Overlaid revenue patterns comparison
3. **lorenz_curves_comparison.png** - Lorenz curves for revenue distribution

## Requirements

- R 4.1.0 or higher
- sensortowerR package
- tidyverse, gt, gtExtras, scales
- Valid SENSORTOWER_AUTH_TOKEN environment variable

## Archive

Historical scripts and test files are stored in the `archive/` directory. Debug scripts are in the `debug/` directory.