# American Time Use Survey Analysis

This project scrapes and visualizes data from the American Time Use Survey PDF.

## Setup

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Place your American Time Use Survey PDF in the `source/` folder and name it `atus.pdf`

3. Run the scraper:
   ```bash
   python scrape_atus.py
   ```

4. Generate visualizations:
   ```bash
   python visualize_atus.py
   ```

## Output

- `data/time_use_data.csv` - Extracted time use data
- `visualizations/time_use_analysis.png` - Multi-panel analysis visualization
- `visualizations/time_allocation_detailed.png` - Detailed time allocation chart

## File Structure

```
2025-07-21/
├── source/           # Place PDF here
├── data/            # Extracted data (CSV)
├── visualizations/  # Generated charts (ALL PNG outputs must be saved here)
├── scrape_atus.py   # PDF scraping script
├── visualize_atus.py # Visualization script
└── requirements.txt # Python dependencies
```

## Project Structure

The project now has two methods for accessing ATUS data:

### 1. PDF Method (folder: `PDF Method/`)
Contains all scripts for extracting data from the ATUS PDF report. 

### 2. API Method (folder: `API Method/`)
Contains scripts for accessing data via the BLS API v2. Currently functional but requires correct ATUS series IDs to retrieve specific leisure activity data.
