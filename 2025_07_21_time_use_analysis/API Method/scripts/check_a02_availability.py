#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check which A02 series are available in the API.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from atus_api_client import ATUSAPIClient

def check_a02_series():
    """Test A02 series availability"""
    
    # Test a few key A02 series
    test_series = {
        "TV All ages A02": "TUU10101AA02014236",
        "Gaming All ages A02": "TUU10101AA02005910", 
        "Computer All ages A02": "TUU10101AA02006114",
        "TV 15-24 A02": "TUU10101AA02014264",
        "Gaming 15-24 A02": "TUU10101AA02021211",
        "Computer 15-24 A02": "TUU10101AA02021432"
    }
    
    # Initialize API client
    API_KEY = "3b988529f9a746d5a0003b2e6506c237"
    client = ATUSAPIClient(API_KEY)
    
    print("Checking A02 (participant average) series availability...")
    print("=" * 60)
    
    # Check each series individually
    for desc, series_id in test_series.items():
        print(f"\nChecking {desc}: {series_id}")
        response = client.get_series_data([series_id], "2024", "2024", catalog=True)
        
        if response and response.get('status') == 'REQUEST_SUCCEEDED':
            df = client.parse_response_to_dataframe(response)
            if df is not None and not df.empty:
                for _, row in df.iterrows():
                    if row['value'] is not None:
                        print(f"✓ Found: {row['value']:.2f} hrs ({row['value']*60:.0f} min)")
                        print(f"  Title: {row.get('series_title', '')}")
                    else:
                        print("✗ No data for 2024")
            else:
                print("✗ Series not found")
        else:
            print("✗ Request failed")
    
    # Try simpler A02 series
    print("\n" + "=" * 60)
    print("Trying broader A02 series (all ages, both sexes)...")
    
    simple_a02 = [
        "TUU10101AA02120303",  # TV watching
        "TUU10101AA02120307",  # Playing games  
        "TUU10101AA02120308"   # Computer use excl games
    ]
    
    response = client.get_series_data(simple_a02, "2024", "2024", catalog=True)
    
    if response and response.get('status') == 'REQUEST_SUCCEEDED':
        df = client.parse_response_to_dataframe(response)
        if df is not None and not df.empty:
            print("\nFound A02 data:")
            for _, row in df.iterrows():
                if row['value'] is not None:
                    print(f"✓ {row['series_id']}: {row['value']:.2f} hrs ({row['value']*60:.0f} min)")
                    print(f"  {row.get('series_title', '')}")

if __name__ == "__main__":
    check_a02_series()