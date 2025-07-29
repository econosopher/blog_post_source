# Platform Information Fix for sensortowerR

## Problem Solved
API results didn't indicate which platform(s) the data represented, leading to iOS-only data being mistaken for global revenue (45-64% of actual).

## Solution Implemented
Added `platform` and `platform_coverage` columns to all API results.

## Functions Updated
1. **st_sales_report()** - Added platform info based on `os` parameter
2. **st_top_charts()** - Added platform info based on `os` parameter
3. **st_metrics()** - Added platform info with intelligent handling:
   - When `combine_platforms = TRUE`: Shows "unified" with "Global (iOS + Android)"
   - When `combine_platforms = FALSE`: Shows actual platform used
4. **st_ytd_metrics()** - Added platform info based on input parameters
5. **st_category_rankings()** - Added platform info based on `os` parameter

## Example Output

### Before (Confusing):
```r
# User calls with iOS ID only
revenue_data <- st_sales_report(app_ids = "1507582572", os = "ios", ...)

# Returns:
# app_id      revenue     date
# 1507582572  318969090   2025-06

# ❌ No indication this is iOS-only!
```

### After (Clear):
```r
# Same call
revenue_data <- st_sales_report(app_ids = "1507582572", os = "ios", ...)

# Returns:
# app_id      revenue     date      platform  platform_coverage
# 1507582572  318969090   2025-06   ios       iOS Only

# ✓ Immediately clear this is iOS-only data!
```

## Benefits
1. **No confusion** - Users always know data coverage
2. **Easy filtering** - `filter(platform == "unified")`
3. **Backward compatible** - Just adds columns
4. **No new functions needed** - Simple, elegant solution

## Usage Tips
- Always check `platform_coverage` to understand your data
- Use `os = "unified"` for global metrics when possible
- Provide both iOS and Android IDs for true unified data
- Filter by platform when combining data from multiple sources