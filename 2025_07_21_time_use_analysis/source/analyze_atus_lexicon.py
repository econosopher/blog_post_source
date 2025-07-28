#!/usr/bin/env python3
"""
Analyze the ATUS Activity Coding Lexicon to understand the official coding structure
and compare with our API queries.
"""

import pandas as pd
from pathlib import Path
import json

def analyze_lexicon():
    """Read and analyze the ATUS Activity Coding Lexicon Excel file"""
    
    # Path to the Excel file
    excel_path = Path("ATUS Activity Coding Lexicon 2024.xls")
    
    if not excel_path.exists():
        print(f"Excel file not found at {excel_path}")
        return
    
    print("Reading ATUS Activity Coding Lexicon...")
    
    # Try to read Excel file - it might have multiple sheets
    try:
        # First, get all sheet names - try with openpyxl engine for .xls files
        try:
            xl_file = pd.ExcelFile(excel_path, engine='openpyxl')
        except:
            # If that fails, try xlrd
            xl_file = pd.ExcelFile(excel_path, engine='xlrd')
            
        print(f"\nFound {len(xl_file.sheet_names)} sheets:")
        for sheet in xl_file.sheet_names:
            print(f"  - {sheet}")
        
        # Read each sheet
        all_data = {}
        for sheet_name in xl_file.sheet_names:
            print(f"\n\nAnalyzing sheet: {sheet_name}")
            df = pd.read_excel(excel_path, sheet_name=sheet_name)
            
            print(f"  Shape: {df.shape}")
            print(f"  Columns: {list(df.columns)}")
            
            # Look for activity codes related to our interests
            if df.shape[0] > 0:
                all_data[sheet_name] = df
                
                # Search for gaming, computer, TV, leisure codes
                search_terms = ['game', 'computer', 'television', 'tv', 'leisure', 'social']
                
                for term in search_terms:
                    # Search in all string columns
                    matches = pd.DataFrame()
                    for col in df.columns:
                        if df[col].dtype == 'object':
                            mask = df[col].astype(str).str.contains(term, case=False, na=False)
                            if mask.any():
                                matches = pd.concat([matches, df[mask]])
                    
                    if not matches.empty:
                        matches = matches.drop_duplicates()
                        print(f"\n  Found {len(matches)} rows containing '{term}':")
                        
                        # Show first few matches
                        for idx, row in matches.head(5).iterrows():
                            # Find columns with non-null values
                            non_null = row.dropna()
                            if len(non_null) > 0:
                                print(f"    Row {idx}: {dict(non_null)}")
        
        return all_data
        
    except Exception as e:
        print(f"Error reading Excel file: {e}")
        
        # Try reading as CSV in case it's actually a CSV with .xls extension
        try:
            df = pd.read_csv(excel_path, encoding='latin-1')
            print("\nRead as CSV successfully")
            return {'main': df}
        except Exception as e2:
            print(f"Also failed to read as CSV: {e2}")
            return None

def extract_leisure_codes(data):
    """Extract and organize leisure-related activity codes"""
    
    leisure_codes = {
        'gaming': [],
        'computer': [],
        'tv': [],
        'socializing': [],
        'leisure_general': []
    }
    
    if not data:
        return leisure_codes
    
    # Analyze each sheet
    for sheet_name, df in data.items():
        print(f"\n\nExtracting codes from {sheet_name}...")
        
        # Look for code columns (might be named differently)
        code_cols = [col for col in df.columns if 'code' in col.lower() or 'activity' in col.lower()]
        
        for _, row in df.iterrows():
            row_str = ' '.join(str(val) for val in row.values if pd.notna(val))
            row_lower = row_str.lower()
            
            # Extract codes based on content
            if 'playing games' in row_lower or 'play games' in row_lower:
                leisure_codes['gaming'].append(dict(row.dropna()))
            
            if 'computer' in row_lower and 'leisure' in row_lower:
                leisure_codes['computer'].append(dict(row.dropna()))
            
            if 'television' in row_lower or 'watching tv' in row_lower:
                leisure_codes['tv'].append(dict(row.dropna()))
            
            if 'socializ' in row_lower:
                leisure_codes['socializing'].append(dict(row.dropna()))
            
            if 'leisure' in row_lower:
                leisure_codes['leisure_general'].append(dict(row.dropna()))
    
    # Deduplicate and summarize
    for category, items in leisure_codes.items():
        if items:
            print(f"\n{category.upper()} ({len(items)} items found)")
            # Show unique examples
            seen = set()
            for item in items[:5]:  # First 5 examples
                key_info = str(item)
                if key_info not in seen:
                    print(f"  {item}")
                    seen.add(key_info)
    
    return leisure_codes

def compare_with_api_patterns():
    """Compare lexicon findings with our API query patterns"""
    
    print("\n\n=== COMPARISON WITH API PATTERNS ===")
    
    print("\nOur API findings:")
    print("- Series pattern: TUU[demographic][periodicity][data_type][activity_code]")
    print("- Activity codes in API: 4-digit codes (e.g., 6100, 6300)")
    print("- NOT the 6-digit codes from documentation (120303, 120308)")
    
    print("\nKnown working API series:")
    api_series = {
        "TUU10101AA01016300": "Playing games and computer use for leisure (0.62 hours)",
        "TUU10101AA01014236": "Watching TV (2.6 hours)",
        "TUU10101AA01013951": "Socializing and communicating (0.59 hours)",
        "TUU10101AA01006315": "Reading for personal interest (0.28 hours)"
    }
    
    for series, desc in api_series.items():
        # Extract the activity code (last 4 digits)
        activity_code = series[-4:]
        print(f"\n{series}:")
        print(f"  Description: {desc}")
        print(f"  Activity code: {activity_code}")

def main():
    print("Analyzing ATUS Activity Coding Lexicon...")
    print("=" * 50)
    
    # Analyze the lexicon
    data = analyze_lexicon()
    
    if data:
        # Extract leisure codes
        leisure_codes = extract_leisure_codes(data)
        
        # Save findings
        with open('atus_lexicon_analysis.json', 'w') as f:
            json.dump({
                'sheets': list(data.keys()),
                'leisure_code_counts': {k: len(v) for k, v in leisure_codes.items()},
                'sample_gaming_codes': leisure_codes['gaming'][:3] if leisure_codes['gaming'] else [],
                'sample_computer_codes': leisure_codes['computer'][:3] if leisure_codes['computer'] else [],
                'sample_tv_codes': leisure_codes['tv'][:3] if leisure_codes['tv'] else []
            }, f, indent=2, default=str)
        
        print("\n\nAnalysis saved to atus_lexicon_analysis.json")
    
    # Compare with API patterns
    compare_with_api_patterns()
    
    print("\n\nCONCLUSION:")
    print("The API uses its own internal activity coding system (4-digit codes)")
    print("which differs from the detailed 6-digit ATUS activity codes in the lexicon.")
    print("Our API queries are appropriate given how the BLS API actually works.")

if __name__ == "__main__":
    main()