# Age-Stratified Gaming Data Available via ATUS API

## Summary of Findings

After extensive searching through the ATUS series cache, the API has **very limited** age-stratified gaming data for the general population (both sexes). Most age-specific series are gender-specific.

## Available Age-Specific Gaming/Computer Use Series

### 1. General Population (Both Sexes) - Only 1 Series Found:

#### Households Without Children Under 18
- **Series ID**: TUU10101AA01016300
- **Title**: Avg hrs per day - Playing games and computer use for leisure, No household children under 18 yrs
- **2024 Value**: 0.62 hours (37.2 minutes)
- **Type**: Combined gaming and computer use
- **Note**: This is demographic-based but not a traditional age group

### 2. Gender-Specific Age Groups:

#### 25-34 Years - Men Only
1. **Computer Use (excluding games)**:
   - Series ID: TUU10101AA01006200
   - Average hours per day: 0.26 hours (15.6 minutes)
   
2. **Computer Use for Participants**:
   - Series ID: TUU20101AA01006200
   - Average hours per day for participants: 1.83 hours
   
3. **Participation Rate**:
   - Series ID: TUU30105AA01006200
   - Percent participating: 14.0%

#### 65+ Years - Women Only
1. **Playing Games - Average Time**:
   - Series ID: TUU10101AA01006100
   - Average hours per day: 0.31 hours (18.6 minutes)
   - Note: Nonholiday weekdays only
   
2. **Playing Games - Time for Participants**:
   - Series ID: TUU20101AA01006100
   - Average hours per day for participants: 1.87 hours
   
3. **Playing Games - Participation Rate**:
   - Series ID: TUU30105AA01006100
   - Percent participating: 16.7%

### 3. Other Demographic Series (Not Age-Based):

#### Employment-Based
- **Series ID**: TUU10101AA01028700
- **Title**: Playing games and computer use for leisure - Full-time employed, wage/salary workers
- **2024 Value**: 0.79 hours (47.4 minutes)
- **Note**: Weekend days and holidays only, earnings 25th-50th percentile

## Key Limitations of API Data:

1. **No standard age brackets for general population**: The API lacks series for common age groups (15-24, 25-34, 35-44, etc.) for both sexes combined.

2. **Gender imbalance**: Only specific combinations exist:
   - 25-34 years: Men only, computer use only (no gaming)
   - 65+ years: Women only, gaming only (no computer use)

3. **Limited activity coverage**: Some age groups have only gaming OR computer use, not both.

4. **Day-type restrictions**: Some series are limited to weekdays or weekends only.

## Attempted Series IDs That Don't Exist:

The following standard pattern was attempted but returned no data:
- Pattern: TUU[demographic]1AA0101[activity_code]
- Demographics: 3201 (15-24), 3301 (25-34), 3401 (35-44), etc.
- Activities: 120303 (Playing games), 120308 (Computer use)

Example non-existent series:
- TUU32011AA0101120303 (15-24 years, playing games)
- TUU33011AA0101120303 (25-34 years, playing games)

## Conclusion:

The ATUS API provides very limited age-stratified gaming data compared to what might be available in the full survey microdata. For comprehensive age-based analysis of gaming behavior, researchers would need to:

1. Use the available gender-specific series with appropriate caveats
2. Access the ATUS microdata files directly for custom tabulations
3. Use the single combined metric (0.62 hours for households without children under 18) as a proxy

The most reliable general population metric from the API is the combined "playing games and computer use for leisure" series, which shows 37.2 minutes per day for households without children under 18 - close to the 34 minutes reported in official BLS publications.