# API Method for ATUS Data Analysis

This directory contains scripts and data for accessing American Time Use Survey (ATUS) data through the BLS API.

## Directory Structure

```
API Method/
├── README.md                   # This file
├── api_findings_summary.md     # Summary of API findings
├── scripts/                    # Essential scripts
│   ├── atus_api_client.py     # Main API client for fetching ATUS data
│   ├── create_final_separated_visualizations.py  # Visualizations with separated gaming/computer data
│   └── create_available_age_visualizations.py    # Age-specific visualizations
└── data/                       # Data files and API responses
    ├── api_final_summary.json  # Final API data used for visualizations
    ├── separated_gaming_findings.json  # Key discovery of separated series
    ├── available_age_data_2024.json    # Age-specific data
    └── atus_activity_code_mapping.csv  # Activity code reference
```

## Setup

1. Install required packages:
```bash
pip install requests pandas matplotlib seaborn
```

2. Set your BLS API key in the scripts:
```python
API_KEY = "3b988529f9a746d5a0003b2e6506c237"
```

## Key Findings

### UPDATE: Gaming Data IS Available via API!
- **Found**: Separated gaming and computer use data via API
- Playing games: 22.2 minutes/day (series `TUU10101AA01005910`)
- Computer use (excl. games): 12.0 minutes/day (series `TUU10101AA01006114`)
- Combined total: 34.2 minutes (closely matches PDF report)

### Important: Understanding the Data
All series codes in this analysis use the **A01** estimate type, which means:
- **Average hours per day, population**: Calculated across EVERYONE in the demographic group
- This includes people who didn't do the activity at all (zero minutes)
- For example: If only 50% of people play games, and those who do play for 44 minutes, the population average would be 22 minutes

Alternative estimate types available (but not used here):
- **A02**: Average hours per day, participants only (just those who did the activity)
- **P01**: Percent of population engaging in the activity

This "population average" approach (A01) provides the most accurate picture of how Americans as a whole allocate their time.

### Series ID Pattern Structure:
ATUS series IDs follow this 18-character pattern:
```
TUU10101AA01016300
│││││││││││││││││└─ Activity code (4 digits: 6100=games, 6300=games+computer)
││││││││││││││└──── Data type code (2 digits)
│││││││││││└─────── Estimate type (A01)
││││││││││└──────── Periodicity (A=Annual)
│││││││└─────────── Demographic code (4 digits)
││││││└──────────── Population type (1, 2, or 3)
│││││└───────────── Seasonal adjustment (U=Unadjusted)
└────────────────── Survey code (TU=Time Use)
```

### Available Data via API:
- Total leisure time: 5.07 hours/day
- TV watching: 2.6 hours/day (51% of leisure)
- **Playing games & computer use**: 0.62 hours/day (37.2 minutes)
- Socializing: 35 minutes/day
- Reading: 17 minutes/day
- Other major time categories (household, eating, etc.)

### Known Gaming-Related Series:
- `TUU10101AA01016300` - Games & computer use, no children under 18 (0.62 hrs)
- `TUU10101AA01006100` - Playing games only, 65+ women, weekdays (0.31 hrs)
- `TUU10101AA01028700` - Games & computer use, weekends, employed (0.79 hrs)

## Usage

To recreate the final visualizations:
```bash
cd scripts
python3 create_final_api_visualizations.py
```

This will generate:
- `leisure_breakdown_api_final.png` - 100% stacked bar chart of leisure activities
- `24hour_breakdown_api_final.png` - 24-hour daily time use breakdown

Output visualizations are saved to `../visualizations/`

## API Client Usage

```python
from atus_api_client import ATUSAPIClient

# Initialize client
client = ATUSAPIClient("your_api_key")

# Get latest data
data = client.get_latest_series(["TUU10101AA01013585"])  # Total leisure

# Get historical data
data = client.get_series_data(["TUU10101AA01014236"], "2020", "2024")  # TV watching
```

## Anatomy of an ATUS API Series ID

The ID is a 19-character string composed of several segments. Let's use the example `TUU3201AA0101120308` to decode it.

**Format:** `[Prefix][Seasonal Adj.][Demographics][Periodicity][Estimates][Day Type][Activity Code]`

| Position(s) | Segment | Example Code | Meaning |
|------------|---------|--------------|---------|
| 1-2 | Survey Prefix | TU | American Time Use Survey |
| 3 | Seasonal Adjustment | U | Unadjusted (ATUS data is not seasonally adjusted) |
| 4-7 | Demographics | 3201 | See detailed breakdown below |
| 8 | Periodicity | A | Annual data |
| 9-11 | Estimates | A01 | See detailed breakdown below |
| 12-13 | Day Type | 01 | See detailed breakdown below |
| 14-19 | Activity Code | 120308 | The 6-digit code for the specific activity |

### Code Breakdown Tables

#### 1. Demographics (Positions 4-7)
This segment is a combination of two codes: a Demographic Group Code (e.g., Age) and a Subgroup Code (e.g., 15-24 years).

**Common Age Codes (for Positions 4-5)**
| Code | Age Group |
|------|-----------|
| 01 | Total, 15 years and over (the overall population) |
| 32 | 15 to 24 years |
| 33 | 25 to 34 years |
| 34 | 35 to 44 years |
| 35 | 45 to 54 years |
| 36 | 55 to 64 years |
| 37 | 65 years and over |

**Sex Codes (for Positions 6-7)**
| Code | Sex |
|------|-----|
| 01 | Both Sexes |
| 02 | Men |
| 03 | Women |

Example: `3201` = Age group 15-24 (32) and Both Sexes (01).

#### 2. Estimates Code (Positions 9-11)
This code specifies what is being measured about the activity.

| Code | Measurement |
|------|-------------|
| A01 | Average hours per day, population (calculated across everyone, including those who didn't do the activity) |
| A02 | Average hours per day, participants (calculated only for those who did the activity) |
| P01 | Percent of population engaging in the activity |

#### 3. Day Type Code (Positions 12-13)
This code specifies which days of the week the data represents.

| Code | Day Type |
|------|----------|
| 01 | All days of the week |
| 02 | Weekdays (Monday-Friday, excluding holidays) |
| 03 | Weekends and Holidays |

### Putting It All Together: A Final Example

Let's decode `TUU3201AA0101120308` again using our new legend:
- **TU**: ATUS data
- **U**: Unadjusted
- **32**: For persons aged 15 to 24 years
- **01**: For both sexes
- **A**: Annual data
- **A01**: Measuring the average hours per day (population)
- **01**: For all days of the week
- **120308**: For the activity "Computer use for leisure (excluding games)"

This single key precisely requests that one specific data point from the entire BLS database.

## Key Series Codes for Gaming, TV, and Leisure Analysis

Here are the specific BLS API series codes for the main activities we've been analyzing:

### Overall Population (All Ages, Both Sexes, All Days)
- **Total Leisure Time**: `TUU10101AA01013585` - Total leisure and sports time
- **Watching TV**: `TUU10101AA01014236` - Television watching 
- **Playing Games**: `TUU10101AA01005910` - Playing games only
- **Computer Use (excl. games)**: `TUU10101AA01006114` - Computer use for leisure, excluding games

### Age-Specific Series Examples
- **Computer Use (excl. games), 15-24**: `TUU10101AA01021432`
- **Playing Games, 25-34**: `TUU10101AA01005928`
- **Watching TV, 35-44**: `TUU10101AA01014296`

**Important Note**: All these series use the **A01** estimate code (positions 9-11), meaning they show population averages including non-participants. This is why gaming averages seem low - they include everyone, not just gamers.

## Notes

See `api_findings_summary.md` for detailed analysis of what we tried and why certain data isn't available through the API.