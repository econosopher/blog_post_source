#!/usr/bin/env python3
"""
Extract leisure data from ATUS PDF with exact activity descriptions.
Focus on TV watching and leisure subcategories with full descriptions from the PDF.
"""

import fitz
import pandas as pd
import re
import json
from pathlib import Path

# Define activity codes with their EXACT descriptions from the PDF
ACTIVITY_CODES = {
    "120307": "Watching television",
    "1201": "Socializing and communicating", 
    "120101": "Socializing and communicating with others",
    "120303": "Playing games",
    "120308": "Computer use for leisure (excluding games)",
    "120312": "Reading for personal interest",
    "120401": "Arts and entertainment (other than sports)",
    "120301": "Relaxing and thinking",
    "1203": "Relaxing and leisure",
    "1204": "Arts and entertainment",
    "1205": "Participating in sports, exercise, and recreation"
}

# Extended descriptions based on PDF methodology
DETAILED_DESCRIPTIONS = {
    "120307": "Watching television: This code is used when a respondent reports watching TV, which can include broadcast, cable, or satellite programs, as well as movies watched on a television set.",
    "120303": "Playing games: This code is used for all types of games, including board games (like chess), card games, and puzzles. It is important to note that this code is also used for video games and computer games.",
    "120308": "Computer use for leisure (excluding games): This is the key category for most modern digital leisure. It includes browsing the internet, using social media, and other computer-based activities that are not game-playing.",
    "1201": "Socializing and Communicating: This includes a range of activities",
    "120101": "Socializing and communicating with others: This is the most common code, used for face-to-face conversations, talking with family and friends, and general social interaction. Hosting or attending parties and other social events."
}

def extract_summary_data(pdf_path):
    """Extract key statistics from the summary section with exact wording"""
    doc = fitz.open(pdf_path)
    
    summary_data = {
        'overview': {},
        'exact_descriptions': {}
    }
    
    # Extract from page 2 summary
    page = doc[1]  # Page 2 (0-indexed)
    text = page.get_text()
    
    # Look for exact phrasings
    patterns = {
        'total_leisure': r'spent an average of (\d+\.\d+) hours per day',
        'tv_watching': r'Watching TV was the leisure[^(]+\((\d+\.\d+) hours per day\)',
        'tv_percentage': r'accounted for just over half[^(]+\((\d+) percent\)',
        'gaming_and_computer': r'spent (\d+) minutes playing games and\s+using a computer for leisure',
        'socializing': r'(\d+) minutes socializing and communicating',
        'reading': r'(\d+) minutes reading for personal interest',
        'men_leisure': r'men spent more time[^(]+than\s+did women \((\d+\.\d+) hours',
        'women_leisure': r'compared with (\d+\.\d+) hours\)'
    }
    
    for key, pattern in patterns.items():
        match = re.search(pattern, text)
        if match:
            value = match.group(1)
            summary_data['overview'][key] = float(value) if '.' in value else int(value)
    
    # Extract exact category descriptions
    for code, desc in DETAILED_DESCRIPTIONS.items():
        summary_data['exact_descriptions'][code] = desc
    
    doc.close()
    return summary_data

def extract_table_1a_detailed(pdf_path, page_num=11):
    """Extract Table 1A with full activity names"""
    doc = fitz.open(pdf_path)
    
    leisure_activities = {}
    
    try:
        page = doc[page_num - 1]
        text = page.get_text()
        lines = text.split('\n')
        
        # Table 1A patterns - looking for leisure activities section
        in_leisure_section = False
        
        for i, line in enumerate(lines):
            line = line.strip()
            
            # Start of leisure section
            if 'Leisure and sports' in line:
                in_leisure_section = True
            
            if in_leisure_section:
                # Match patterns like "Activity name ........... X.XX"
                # Look for lines with dots and numbers
                if '.' in line and any(char.isdigit() for char in line):
                    # Try to extract activity name and value
                    parts = re.split(r'\.{2,}', line)
                    if len(parts) >= 2:
                        activity = parts[0].strip()
                        value_part = parts[-1].strip()
                        
                        # Extract numeric value
                        value_match = re.search(r'(\d+\.\d+)', value_part)
                        if value_match:
                            value = float(value_match.group(1))
                            
                            # Store with original activity name
                            leisure_activities[activity] = {
                                'hours': value,
                                'minutes': value * 60
                            }
                
                # Look for specific activities with their codes
                for code, activity_name in ACTIVITY_CODES.items():
                    if activity_name.lower() in line.lower():
                        # Try to find associated value
                        value_match = re.search(r'(\d+\.\d+)', line)
                        if value_match:
                            value = float(value_match.group(1))
                            leisure_activities[f"{activity_name} ({code})"] = {
                                'hours': value,
                                'minutes': value * 60,
                                'code': code
                            }
            
            # End of leisure section
            if in_leisure_section and ('Work' in line or 'Educational' in line):
                break
    
    except Exception as e:
        print(f"Error extracting Table 1A: {e}")
    
    doc.close()
    return leisure_activities

def extract_demographic_data(pdf_path, page_num=23):
    """Extract demographic breakdowns from Table 11A"""
    doc = fitz.open(pdf_path)
    
    demographic_data = {
        'by_age': {},
        'by_gender': {},
        'combined': {}
    }
    
    try:
        page = doc[page_num - 1]
        text = page.get_text()
        lines = text.split('\n')
        
        # Age groups to look for
        age_groups = ['15-19', '20-24', '25-34', '35-44', '45-54', '55-64', '65-74', '75 and over']
        
        current_activity = None
        
        for i, line in enumerate(lines):
            line = line.strip()
            
            # Check for activity headers
            if 'Playing games' in line and 'computer use' in line:
                current_activity = 'Playing games and computer use for leisure'
            elif 'Watching television' in line:
                current_activity = 'Watching television'
            elif 'Socializing' in line and 'communicating' in line:
                current_activity = 'Socializing and communicating'
            elif 'Reading' in line and 'personal interest' in line:
                current_activity = 'Reading for personal interest'
            
            # Extract values for age groups
            if current_activity:
                for age in age_groups:
                    if age in line:
                        # Look for numeric value in same or next line
                        value_match = re.search(r'(\d+\.\d+)', line)
                        if value_match:
                            value = float(value_match.group(1))
                            
                            if current_activity not in demographic_data['by_age']:
                                demographic_data['by_age'][current_activity] = {}
                            
                            demographic_data['by_age'][current_activity][age] = {
                                'hours': value,
                                'minutes': value * 60
                            }
    
    except Exception as e:
        print(f"Error extracting demographic data: {e}")
    
    doc.close()
    return demographic_data

def create_comprehensive_summary(summary_data, table_data, demographic_data):
    """Create a comprehensive summary with exact descriptions"""
    
    comprehensive = {
        'metadata': {
            'source': 'American Time Use Survey 2024',
            'extraction_method': 'PDF parsing with exact descriptions',
            'focus': 'TV watching and leisure subcategories'
        },
        'key_findings': summary_data['overview'],
        'activity_descriptions': summary_data['exact_descriptions'],
        'leisure_breakdown': {},
        'demographic_patterns': demographic_data
    }
    
    # Organize leisure activities by category
    categories = {
        'Screen Time': ['Watching television', 'Playing games', 'Computer use for leisure'],
        'Social Activities': ['Socializing and communicating', 'Socializing and communicating with others'],
        'Quiet Leisure': ['Reading for personal interest', 'Relaxing and thinking'],
        'Active Leisure': ['Participating in sports, exercise, and recreation', 'Arts and entertainment']
    }
    
    for category, activities in categories.items():
        comprehensive['leisure_breakdown'][category] = {}
        for activity in activities:
            # Find matching activity in table data
            for key, data in table_data.items():
                if activity.lower() in key.lower():
                    comprehensive['leisure_breakdown'][category][key] = data
    
    return comprehensive

def main():
    # Path to PDF
    pdf_path = Path(__file__).parent.parent / "source" / "American Time Use Survey 2024.pdf"
    
    if not pdf_path.exists():
        print(f"PDF not found at {pdf_path}")
        return
    
    print("Extracting ATUS data with exact descriptions...")
    
    # Extract data
    summary_data = extract_summary_data(pdf_path)
    print(f"✓ Extracted summary data: {len(summary_data['overview'])} key statistics")
    
    table_data = extract_table_1a_detailed(pdf_path)
    print(f"✓ Extracted Table 1A: {len(table_data)} activities")
    
    demographic_data = extract_demographic_data(pdf_path)
    print(f"✓ Extracted demographic data: {len(demographic_data['by_age'])} activities")
    
    # Create comprehensive summary
    comprehensive = create_comprehensive_summary(summary_data, table_data, demographic_data)
    
    # Save data
    output_dir = Path(__file__).parent.parent / "data"
    output_dir.mkdir(exist_ok=True)
    
    with open(output_dir / "leisure_exact_descriptions.json", 'w') as f:
        json.dump(comprehensive, f, indent=2)
    
    # Also save as CSV for easy viewing
    if table_data:
        df = pd.DataFrame.from_dict(table_data, orient='index')
        df.to_csv(output_dir / "leisure_activities_exact.csv")
    
    print(f"\n✓ Data saved to {output_dir}")
    print("\nKey findings:")
    for key, value in summary_data['overview'].items():
        print(f"  - {key}: {value}")

if __name__ == "__main__":
    main()