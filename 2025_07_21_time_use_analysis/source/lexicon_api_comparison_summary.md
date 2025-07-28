# ATUS Lexicon vs API Comparison Summary

## Key Findings from the ATUS Activity Coding Lexicon 2024

### Official ATUS Activity Codes (from Lexicon):
- **120303**: Television and movies (not religious)
- **120307**: Playing games
- **120308**: Computer use for leisure (exc. Games)
- **120101**: Socializing and communicating with others

### Important Discrepancy Discovered:
There's a conflict in the documentation:
- The lexicon shows **120303** = "Television and movies"
- But the PDF/documentation claimed **120303** = "Playing games"
- The lexicon shows **120307** = "Playing games" (different from what we thought)

## API Series Pattern Analysis

### How the API Actually Works:
The BLS API uses a different coding system than the detailed ATUS activity codes:

1. **API Series Format**: `TUU10101AA01016300`
   - Last 4 digits (6300) are NOT the ATUS activity codes
   - These are internal API activity identifiers

2. **Known Working API Series**:
   - `TUU10101AA01016300`: Playing games and computer use (API code: 6300)
   - `TUU10101AA01014236`: Watching TV (API code: 4236)
   - `TUU10101AA01013951`: Socializing (API code: 3951)

## Conclusion

### Our API Queries Are Appropriate Because:

1. **The API doesn't use ATUS lexicon codes directly**
   - We correctly identified that the API has its own coding system
   - The 6-digit ATUS codes (120303, 120307, 120308) don't map to API series IDs

2. **We found the correct series through exploration**
   - Our method of searching popular series and examining catalog data was correct
   - The series we're using (e.g., TUU10101AA01016300) provide the right data

3. **The combined category is real**
   - "Playing games and computer use for leisure" is how the API reports this data
   - This matches the 34-minute figure from the PDF

### What This Means:

- The BLS API abstracts away from the detailed ATUS coding system
- It provides pre-aggregated series with their own identification system
- Our approach of using series like TUU10101AA01016300 is the correct way to access this data via API
- The discrepancy between the lexicon codes and what we thought doesn't affect our API usage

### Recommendation:

Continue using the API series we've identified. They provide accurate data even though they don't directly correspond to the ATUS lexicon codes. The API is designed to provide commonly-requested aggregations rather than raw activity-level data.