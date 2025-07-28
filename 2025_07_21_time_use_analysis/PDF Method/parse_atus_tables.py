import fitz
import pandas as pd
import re
import json
from pathlib import Path

def extract_specific_tables(pdf_path):
    """Extract specific tables mentioned in the summary"""
    doc = fitz.open(pdf_path)
    
    target_tables = {
        'Table 1': 'Primary time use data',
        'Table 11A': 'Leisure activities by demographic',
        'Table 11B': 'Leisure activities by day type',
        'Table A-1': 'Detailed activity breakdown'
    }
    
    extracted_tables = {}
    
    for page_num in range(len(doc)):
        page = doc[page_num]
        text = page.get_text()
        
        # Check if this page contains any of our target tables
        for table_name, description in target_tables.items():
            if table_name.lower() in text.lower():
                print(f"\nFound {table_name} on page {page_num + 1}")
                
                # Extract the full page text for manual parsing
                extracted_tables[table_name] = {
                    'page': page_num + 1,
                    'description': description,
                    'text': text,
                    'lines': text.split('\n')
                }
    
    doc.close()
    return extracted_tables

def parse_time_use_data(extracted_tables):
    """Parse the extracted table text to find gaming, TV, and social media data"""
    
    parsed_data = []
    
    # Key activity patterns to look for
    activity_mappings = {
        'gaming': [
            'playing games',
            'computer use for leisure',
            'games and computer use',
            'playing games and computer use'
        ],
        'tv': [
            'watching television',
            'watching tv',
            'television'
        ],
        'social_media': [
            'social media',
            'social networking',
            'computer use.*social'
        ],
        'leisure_total': [
            'leisure and sports',
            'total leisure',
            'leisure activities'
        ],
        'socializing': [
            'socializing and communicating',
            'socializing, relaxing'
        ]
    }
    
    # Time extraction patterns
    time_patterns = [
        r'(\d+\.\d+)\s*(?:hours?|hrs?)',  # Decimal hours
        r'(\d+):(\d+)',  # HH:MM format
        r'(\d+)\s*(?:hours?|hrs?)\s*(?:and\s*)?(\d+)\s*(?:minutes?|mins?)',  # X hours Y minutes
        r'(\d+)\s*(?:minutes?|mins?)'  # Just minutes
    ]
    
    for table_name, table_data in extracted_tables.items():
        print(f"\nParsing {table_name}...")
        lines = table_data['lines']
        
        for i, line in enumerate(lines):
            line_lower = line.lower()
            
            # Check each activity type
            for activity_type, patterns in activity_mappings.items():
                for pattern in patterns:
                    if pattern in line_lower or re.search(pattern, line_lower):
                        # Found an activity, now look for time values
                        # Check current line and next few lines
                        for j in range(i, min(i + 3, len(lines))):
                            check_line = lines[j]
                            
                            # Look for time values
                            for time_pattern in time_patterns:
                                matches = re.findall(time_pattern, check_line)
                                if matches:
                                    # Convert to minutes
                                    minutes = 0
                                    if isinstance(matches[0], tuple):
                                        if len(matches[0]) == 2:
                                            # Either HH:MM or hours and minutes
                                            if ':' in check_line:
                                                hours, mins = matches[0]
                                                minutes = int(hours) * 60 + int(mins)
                                            else:
                                                hours, mins = matches[0]
                                                minutes = int(hours) * 60 + int(mins)
                                    else:
                                        # Single value (hours or minutes)
                                        value = float(matches[0])
                                        if 'hour' in check_line.lower():
                                            minutes = int(value * 60)
                                        else:
                                            minutes = int(value)
                                    
                                    if minutes > 0:
                                        parsed_data.append({
                                            'table': table_name,
                                            'page': table_data['page'],
                                            'activity_type': activity_type,
                                            'activity_description': line.strip(),
                                            'time_minutes': minutes,
                                            'time_string': check_line.strip(),
                                            'context': '\n'.join(lines[max(0, i-1):min(len(lines), i+3)])
                                        })
                                        break
    
    return parsed_data

def extract_demographic_breakdowns(extracted_tables, parsed_data):
    """Look for demographic breakdowns in the data"""
    
    demographic_patterns = {
        'age_groups': [
            r'(\d+)\s*(?:to|-)\s*(\d+)\s*(?:years?)?',
            r'(\d+)\s*and\s*(?:over|older)',
            r'ages?\s*(\d+)\s*(?:to|-)\s*(\d+)'
        ],
        'gender': [
            r'\b(men|male)\b',
            r'\b(women|female)\b'
        ],
        'day_type': [
            r'\b(weekday|weekdays)\b',
            r'\b(weekend|weekends)\b'
        ]
    }
    
    enhanced_data = []
    
    for item in parsed_data:
        context = item['context']
        demographics = {}
        
        # Check for age groups
        for pattern in demographic_patterns['age_groups']:
            age_match = re.search(pattern, context, re.IGNORECASE)
            if age_match:
                demographics['age_group'] = age_match.group(0)
                break
        
        # Check for gender
        for pattern in demographic_patterns['gender']:
            gender_match = re.search(pattern, context, re.IGNORECASE)
            if gender_match:
                demographics['gender'] = gender_match.group(1).lower()
                break
        
        # Check for day type
        for pattern in demographic_patterns['day_type']:
            day_match = re.search(pattern, context, re.IGNORECASE)
            if day_match:
                demographics['day_type'] = day_match.group(1).lower()
                break
        
        item['demographics'] = demographics
        enhanced_data.append(item)
    
    return enhanced_data

def save_parsed_results(parsed_data, enhanced_data):
    """Save the parsed results"""
    
    # Create DataFrame for easier analysis
    if enhanced_data:
        df = pd.DataFrame(enhanced_data)
        
        # Save full data
        df.to_csv('data/atus_parsed_data.csv', index=False)
        
        # Create summary by activity type
        summary = df.groupby('activity_type')['time_minutes'].agg(['count', 'mean', 'min', 'max'])
        summary.to_csv('data/activity_summary.csv')
        
        print("\n=== Activity Summary ===")
        print(summary)
        
        # Create demographic breakdown if available
        if 'demographics' in df.columns and df['demographics'].apply(bool).any():
            demo_data = []
            for _, row in df.iterrows():
                demo_dict = row.to_dict()
                demo_dict.update(row['demographics'])
                demo_data.append(demo_dict)
            
            demo_df = pd.DataFrame(demo_data)
            demo_df.to_csv('data/demographic_breakdown.csv', index=False)
        
        print(f"\n✓ Saved {len(enhanced_data)} data points to CSV files")
    
    # Save raw parsed data as JSON for review
    with open('data/parsed_data.json', 'w') as f:
        json.dump(enhanced_data, f, indent=2)
    
    # Print sample results
    if enhanced_data:
        print("\n=== Sample Parsed Data ===")
        for activity in ['gaming', 'tv', 'socializing']:
            activity_data = [d for d in enhanced_data if d['activity_type'] == activity]
            if activity_data:
                sample = activity_data[0]
                print(f"\n{activity.upper()}:")
                print(f"  Description: {sample['activity_description']}")
                print(f"  Time: {sample['time_minutes']} minutes")
                if sample.get('demographics'):
                    print(f"  Demographics: {sample['demographics']}")

def main():
    pdf_path = Path("source/American Time Use Survey 2024.pdf")
    output_dir = Path("data")
    output_dir.mkdir(exist_ok=True)
    
    print("Extracting specific tables from ATUS PDF...")
    extracted_tables = extract_specific_tables(pdf_path)
    
    if not extracted_tables:
        print("No target tables found. The PDF structure might be different than expected.")
        return
    
    print(f"\nFound {len(extracted_tables)} tables")
    
    print("\nParsing time use data...")
    parsed_data = parse_time_use_data(extracted_tables)
    
    print(f"\nExtracted {len(parsed_data)} time use data points")
    
    print("\nExtracting demographic breakdowns...")
    enhanced_data = extract_demographic_breakdowns(extracted_tables, parsed_data)
    
    print("\nSaving results...")
    save_parsed_results(parsed_data, enhanced_data)
    
    print("\n✓ Extraction complete! Check the 'data' folder for:")
    print("  - atus_parsed_data.csv (full parsed data)")
    print("  - activity_summary.csv (summary statistics)")
    print("  - demographic_breakdown.csv (data with demographics)")
    print("  - parsed_data.json (raw JSON for review)")

if __name__ == "__main__":
    main()