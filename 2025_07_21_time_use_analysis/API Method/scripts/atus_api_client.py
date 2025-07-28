import requests
import json
import pandas as pd
from datetime import datetime
import os
from typing import List, Dict, Optional

class ATUSAPIClient:
    """Client for accessing ATUS data through the BLS API v2"""
    
    def __init__(self, api_key: str):
        """
        Initialize the ATUS API client
        
        Args:
            api_key: BLS API registration key
        """
        self.api_key = api_key
        self.base_url = "https://api.bls.gov/publicAPI/v2"
        self.headers = {'Content-type': 'application/json'}
    
    def get_latest_series(self, series_ids: List[str]) -> Optional[Dict]:
        """
        Get the latest data point for given series IDs
        
        Args:
            series_ids: List of BLS series IDs
            
        Returns:
            JSON response with latest data points
        """
        # Method 1: Using GET with latest parameter for single series
        if len(series_ids) == 1:
            url = f"{self.base_url}/timeseries/data/{series_ids[0]}?latest=true&registrationkey={self.api_key}"
            
            try:
                response = requests.get(url)
                response.raise_for_status()
                return response.json()
            except requests.exceptions.RequestException as e:
                print(f"Error fetching latest data: {e}")
                return None
        
        # Method 2: For multiple series, use POST with latest flag
        else:
            url = f"{self.base_url}/timeseries/data/"
            
            payload = {
                "seriesid": series_ids,
                "latest": True,
                "registrationkey": self.api_key
            }
            
            try:
                response = requests.post(url, data=json.dumps(payload), headers=self.headers)
                response.raise_for_status()
                return response.json()
            except requests.exceptions.RequestException as e:
                print(f"Error fetching latest data: {e}")
                return None
    
    def get_series_data(self, series_ids: List[str], start_year: str, end_year: str, 
                       catalog: bool = True, calculations: bool = True, 
                       annualaverage: bool = True, aspects: bool = True) -> Optional[Dict]:
        """
        Get full series data with optional parameters
        
        Args:
            series_ids: List of BLS series IDs
            start_year: Start year for data
            end_year: End year for data
            catalog: Include series catalog metadata
            calculations: Include calculations
            annualaverage: Include annual averages
            aspects: Include data aspects
            
        Returns:
            JSON response with series data
        """
        url = f"{self.base_url}/timeseries/data/"
        
        payload = {
            "seriesid": series_ids,
            "startyear": start_year,
            "endyear": end_year,
            "catalog": catalog,
            "calculations": calculations,
            "annualaverage": annualaverage,
            "aspects": aspects,
            "registrationkey": self.api_key
        }
        
        try:
            response = requests.post(url, data=json.dumps(payload), headers=self.headers)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error fetching series data: {e}")
            return None
    
    def parse_response_to_dataframe(self, json_data: Dict) -> Optional[pd.DataFrame]:
        """
        Parse API response into a pandas DataFrame
        
        Args:
            json_data: JSON response from API
            
        Returns:
            DataFrame with parsed data
        """
        if not json_data or json_data.get('status') != 'REQUEST_SUCCEEDED':
            print(f"Invalid response: {json_data.get('message', 'Unknown error')}")
            return None
        
        all_data = []
        
        for series in json_data['Results']['series']:
            series_id = series['seriesID']
            series_catalog = series.get('catalog', {})
            
            for item in series['data']:
                row = {
                    'series_id': series_id,
                    'series_title': series_catalog.get('series_title', ''),
                    'survey_name': series_catalog.get('survey_name', ''),
                    'survey_abbreviation': series_catalog.get('survey_abbreviation', ''),
                    'year': item['year'],
                    'period': item['period'],
                    'period_name': item.get('periodName', ''),
                    'value': float(item['value']) if item['value'] != '-' else None,
                    'latest': item.get('latest', False)
                }
                
                # Add footnotes
                footnotes = []
                for footnote in item.get('footnotes', []):
                    if footnote:
                        footnotes.append(f"{footnote.get('code', '')}: {footnote.get('text', '')}")
                row['footnotes'] = '; '.join(footnotes) if footnotes else ''
                
                # Add calculations if present
                if 'calculations' in item:
                    for calc_type, calc_value in item['calculations'].items():
                        row[f'calc_{calc_type}'] = calc_value
                
                all_data.append(row)
        
        return pd.DataFrame(all_data)


# Example usage and testing
if __name__ == "__main__":
    # Initialize client with API key
    API_KEY = "3b988529f9a746d5a0003b2e6506c237"
    client = ATUSAPIClient(API_KEY)
    
    # Test 1: Get latest data for a known series
    print("=== Test 1: Getting latest data for CPI series ===")
    test_series = ["CUUR0000SA0"]  # Consumer Price Index
    latest_data = client.get_latest_series(test_series)
    
    if latest_data:
        print(f"Status: {latest_data.get('status')}")
        print(f"Response time: {latest_data.get('responseTime')}ms")
        
        df = client.parse_response_to_dataframe(latest_data)
        if df is not None:
            print("\nLatest data:")
            print(df)
    
    # Test 2: Try ATUS series for latest data
    print("\n\n=== Test 2: Getting latest ATUS data ===")
    atus_test_series = [
        "TUU10101AA01000000",  # Total leisure time
        "TUU10301AA01000000",  # TV watching
        "TUU10801AA01000000",  # Playing games
    ]
    
    atus_latest = client.get_latest_series(atus_test_series)
    
    if atus_latest:
        print(f"Status: {atus_latest.get('status')}")
        
        df = client.parse_response_to_dataframe(atus_latest)
        if df is not None:
            print("\nATUS latest data:")
            print(df)
            
            # Save to CSV
            df.to_csv('atus_latest_data.csv', index=False)
            print("\nData saved to atus_latest_data.csv")