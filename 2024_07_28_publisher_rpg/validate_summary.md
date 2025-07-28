# Scopely US YTD Validation Summary

## Key Finding
The monthly data matches PERFECTLY between CSV and API. The YTD discrepancy occurs because the API's `time_range = "year"` calculation differs from summing monthly data.

## Revenue Validation (US Market)

### Monthly Data (2025) - PERFECT MATCH ✓
- January: $123,785,228 (both CSV and API)
- February: $117,911,083 (both CSV and API)
- March: $139,262,107 (both CSV and API)
- April: $122,896,895 (both CSV and API)
- May: $122,263,399 (both CSV and API)
- June: $142,258,155 (both CSV and API)
- July: $115,725,797 (both CSV and API)

### YTD Calculation
- **CSV Method**: Sum of Jan-Jul daily data = $884,102,663
- **API Manual Sum**: Sum of Jan-Jul monthly = $884,102,663 ✓
- **API Year Endpoint**: Returns -55.0% (different calculation method)

### Actual YTD Change
- 2024 (Jan-Jul): $1,286,825,437
- 2025 (Jan-Jul): $884,102,663
- **True YTD Change: -31.3%**

## Downloads Validation (US Market)
- **CSV YTD Change**: -44.8%
- **API Year Endpoint**: -62.8% (likely same issue as revenue)

## Conclusion
The data is accurate when using monthly aggregation. The discrepancy comes from the API's `time_range = "year"` endpoint which appears to use a different calculation method (possibly annualized projections or different date ranges) rather than simple YTD summation.

## Recommendation
For accurate YTD metrics in the publisher analysis, we should:
1. Sum monthly data instead of using the year endpoint
2. OR adjust the table to clarify that YTD metrics are from the API's calculation method