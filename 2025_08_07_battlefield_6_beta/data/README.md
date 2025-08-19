# Data Directory

This folder contains all data files and data fetching scripts for the Battlefield vs Call of Duty analysis.

## CSV Files

### Core Game Data
- **`games_catalog.csv`** - Master list of games with Steam IDs, release dates, and lifetime sales
- **`battlefield_launch_content.csv`** - Launch maps and weapons count for each Battlefield game
- **`battlefield_class_systems.csv`** - Class/specialist systems evolution across Battlefield games
- **`battlefield_progression_systems.csv`** - Progression and unlock mechanics history

### Generated Data (from API)
After running `fetch_and_save_data.R`, these files will be created:
- **`ccu_history_data.csv`** - Daily concurrent player data from Steam
- **`pricing_revenue_data.csv`** - Current pricing and revenue summary
- **`units_history_data.csv`** - Daily unit sales history
- **`revenue_history_data.csv`** - Daily revenue history
- **`data_fetch_metadata.csv`** - Metadata about when data was fetched

## Scripts

- **`fetch_and_save_data.R`** - Fetches all data from Video Game Insights API and saves to CSV files

## Usage

1. **Add new games**: Edit `games_catalog.csv` with game details
2. **Fetch API data**: Run `Rscript data/fetch_and_save_data.R` from the parent directory
3. **Use cached data**: The main visualization scripts will automatically use cached CSV files if available

## Data Structure

### games_catalog.csv
- `franchise` - Battlefield or Call of Duty
- `name` - Full game name
- `steam_app_id` - Steam application ID (leave blank if not on Steam)
- `release_date` - YYYY-MM-DD format
- `release_year` - Year of release
- `lifetime_units_millions` - Lifetime unit sales in millions (from industry reports)
- `key_factors` - Success/failure factors

### Other CSV structures
See the header row in each CSV file for column definitions.