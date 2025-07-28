import requests
import json
import pandas as pd
from datetime import datetime

def fetch_atus_data(series_ids, start_year="2023", end_year="2024"):
    """
    Fetch ATUS data from BLS API
    
    Args:
        series_ids: List of ATUS series IDs
        start_year: Start year for data
        end_year: End year for data
    
    Returns:
        Dictionary containing the API response data
    """
    headers = {'Content-type': 'application/json'}
    
    # Prepare the data payload
    data = json.dumps({
        "seriesid": series_ids,
        "startyear": start_year, 
        "endyear": end_year
    })
    
    # Make API request to v2 endpoint
    print(f"Fetching data for series: {series_ids}")
    print(f"Years: {start_year} to {end_year}")
    
    try:
        response = requests.post(
            'https://api.bls.gov/publicAPI/v2/timeseries/data/', 
            data=data, 
            headers=headers
        )
        response.raise_for_status()
        
        json_data = response.json()
        
        if json_data['status'] == 'REQUEST_SUCCEEDED':
            print("API request successful!")
            return json_data
        else:
            print(f"API request failed: {json_data.get('message', 'Unknown error')}")
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"Error making API request: {e}")
        return None

def parse_atus_response(json_data):
    """
    Parse the ATUS API response into a structured format
    
    Args:
        json_data: JSON response from BLS API
    
    Returns:
        Pandas DataFrame with the parsed data
    """
    if not json_data or 'Results' not in json_data:
        return None
    
    all_data = []
    
    for series in json_data['Results']['series']:
        series_id = series['seriesID']
        series_catalog = series.get('catalog', {})
        
        print(f"\nProcessing series: {series_id}")
        print(f"Series title: {series_catalog.get('series_title', 'N/A')}")
        
        for item in series['data']:
            row = {
                'series_id': series_id,
                'series_title': series_catalog.get('series_title', ''),
                'year': item['year'],
                'period': item['period'],
                'value': float(item['value']),
                'periodName': item.get('periodName', ''),
                'latest': item.get('latest', False)
            }
            
            # Add footnotes if any
            footnotes = []
            for footnote in item.get('footnotes', []):
                if footnote:
                    footnotes.append(footnote.get('text', ''))
            row['footnotes'] = ', '.join(footnotes) if footnotes else ''
            
            all_data.append(row)
    
    df = pd.DataFrame(all_data)
    return df

# Common ATUS series IDs for leisure activities
# These are example series IDs - we'll need to find the correct ones for computer/gaming activities
atus_series_ids = [
    # Total leisure time
    "TUU10101AA01000000",  # Average hours per day spent in leisure and sports activities
    
    # TV watching
    "TUU10301AA01000000",  # Watching TV
    
    # Computer use for leisure (might include gaming)
    "TUU10801AA01000000",  # Playing games
    "TUU10802AA01000000",  # Computer use for leisure
    
    # Socializing
    "TUU10401AA01000000",  # Socializing and communicating
]

# Let's first try with a known working series to test the API
test_series = ["CUUR0000SA0"]  # Consumer Price Index as a test

print("Testing BLS API connection...")
test_data = fetch_atus_data(test_series, "2023", "2024")

if test_data:
    print("\nAPI connection successful! Now trying ATUS series...")
    
    # Try fetching ATUS data
    atus_data = fetch_atus_data(atus_series_ids, "2023", "2024")
    
    if atus_data:
        df = parse_atus_response(atus_data)
        
        if df is not None and not df.empty:
            print("\nATUS Data Retrieved:")
            print(df.head())
            
            # Save to CSV
            df.to_csv('data/atus_api_data.csv', index=False)
            print("\nData saved to data/atus_api_data.csv")
        else:
            print("\nNo data found in ATUS response")
    else:
        print("\nFailed to fetch ATUS data")
else:
    print("\nAPI connection test failed")