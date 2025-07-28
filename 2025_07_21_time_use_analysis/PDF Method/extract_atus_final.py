import fitz
import pandas as pd
import re
from pathlib import Path

def extract_key_statistics(pdf_path):
    """Extract key statistics from the summary section"""
    doc = fitz.open(pdf_path)
    
    key_stats = {}
    
    # Extract from page 2 summary
    page = doc[1]  # Page 2 (0-indexed)
    text = page.get_text()
    
    # Extract TV watching time
    tv_match = re.search(r'Watching TV was the leisure[^(]+\((\d+\.\d+) hours per day\)', text)
    if tv_match:
        key_stats['tv_hours'] = float(tv_match.group(1))
    
    # Extract total leisure time
    leisure_match = re.search(r'all leisure time[^(]+\((\d+\.\d+) hours per day\)', text)
    if leisure_match:
        key_stats['total_leisure_hours'] = float(leisure_match.group(1))
    
    # Extract gaming and computer use time
    gaming_match = re.search(r'(\d+) minutes playing games and\s+using a computer for leisure', text)
    if gaming_match:
        key_stats['gaming_minutes'] = int(gaming_match.group(1))
    
    # Extract socializing time
    social_match = re.search(r'(\d+) minutes socializing and communicating', text)
    if social_match:
        key_stats['socializing_minutes'] = int(social_match.group(1))
    
    # Extract gender differences in leisure
    gender_match = re.search(r'men spent more time[^(]+than\s+did women \((\d+\.\d+) hours, compared with (\d+\.\d+) hours\)', text)
    if gender_match:
        key_stats['men_leisure_hours'] = float(gender_match.group(1))
        key_stats['women_leisure_hours'] = float(gender_match.group(2))
    
    doc.close()
    return key_stats

def extract_table_11a_data(pdf_path, page_num=23):
    """Extract data from Table 11A which has demographic breakdowns"""
    doc = fitz.open(pdf_path)
    
    # Get page with Table 11A
    page = doc[page_num - 1]  # 0-indexed
    text = page.get_text()
    lines = text.split('\n')
    
    # Find the data section
    data_rows = []
    in_data_section = False
    
    for line in lines:
        # Skip empty lines
        if not line.strip():
            continue
            
        # Look for demographic categories
        if any(keyword in line for keyword in ['Total, 15 years and over', 'Men', 'Women', 'to 24 years', 
                                                'to 34 years', 'to 44 years', 'to 54 years', 
                                                'to 64 years', '65 to 74 years', '75 years and over',
                                                'Less than a high school', 'High school grad',
                                                "Bachelor's degree"]):
            # This line contains demographic info followed by numbers
            # Parse the numbers using regex
            numbers = re.findall(r'\d+\.\d+', line)
            
            if numbers and len(numbers) >= 7:  # Should have values for each activity
                demographic = line.split(numbers[0])[0].strip()
                
                # The order in table is: Total, Sports, Socializing, TV, Reading, Relaxing, Gaming, Other
                if len(numbers) >= 7:
                    data_rows.append({
                        'demographic': demographic,
                        'total_leisure': float(numbers[0]),
                        'sports': float(numbers[1]) if len(numbers) > 1 else 0,
                        'socializing': float(numbers[2]) if len(numbers) > 2 else 0,
                        'tv': float(numbers[3]) if len(numbers) > 3 else 0,
                        'reading': float(numbers[4]) if len(numbers) > 4 else 0,
                        'relaxing': float(numbers[5]) if len(numbers) > 5 else 0,
                        'gaming': float(numbers[6]) if len(numbers) > 6 else 0,
                        'other': float(numbers[7]) if len(numbers) > 7 else 0
                    })
    
    doc.close()
    return pd.DataFrame(data_rows)

def extract_table_11b_data(pdf_path, page_num=24):
    """Extract data from Table 11B which has weekday/weekend breakdowns"""
    doc = fitz.open(pdf_path)
    
    # Get page with Table 11B
    page = doc[page_num - 1]  # 0-indexed
    text = page.get_text()
    lines = text.split('\n')
    
    data_rows = []
    
    for i, line in enumerate(lines):
        # Look for demographic rows
        if any(keyword in line for keyword in ['Men', 'Women', 'Total, 15 years and over', 
                                                'to 19 years', 'to 24 years', 'to 34 years',
                                                'to 44 years', 'to 54 years', 'to 64 years']):
            # Extract numbers from this line
            numbers = re.findall(r'\d+\.\d+', line)
            
            if numbers and len(numbers) >= 2:  # At least weekday and weekend values
                demographic = line.split(numbers[0])[0].strip().replace('.', '')
                
                # Parse pairs of numbers (weekday, weekend) for each activity
                if len(numbers) >= 16:  # 8 activities × 2 (weekday/weekend)
                    data_rows.append({
                        'demographic': demographic,
                        'total_weekday': float(numbers[0]),
                        'total_weekend': float(numbers[1]),
                        'sports_weekday': float(numbers[2]),
                        'sports_weekend': float(numbers[3]),
                        'socializing_weekday': float(numbers[4]),
                        'socializing_weekend': float(numbers[5]),
                        'tv_weekday': float(numbers[6]),
                        'tv_weekend': float(numbers[7]),
                        'reading_weekday': float(numbers[8]),
                        'reading_weekend': float(numbers[9]),
                        'relaxing_weekday': float(numbers[10]),
                        'relaxing_weekend': float(numbers[11]),
                        'gaming_weekday': float(numbers[12]),
                        'gaming_weekend': float(numbers[13]),
                        'other_weekday': float(numbers[14]),
                        'other_weekend': float(numbers[15])
                    })
    
    doc.close()
    return pd.DataFrame(data_rows)

def process_and_save_data(key_stats, table_11a_df, table_11b_df):
    """Process extracted data and save to CSV files"""
    
    # Convert hours to minutes for consistency
    if 'tv_hours' in key_stats:
        key_stats['tv_minutes'] = key_stats['tv_hours'] * 60
    if 'total_leisure_hours' in key_stats:
        key_stats['total_leisure_minutes'] = key_stats['total_leisure_hours'] * 60
    
    # Save key statistics
    key_stats_df = pd.DataFrame([key_stats])
    key_stats_df.to_csv('data/key_statistics.csv', index=False)
    
    # Save demographic data
    if not table_11a_df.empty:
        table_11a_df.to_csv('data/leisure_by_demographics.csv', index=False)
        
        # Calculate gaming as percentage of leisure
        table_11a_df['gaming_pct_of_leisure'] = (table_11a_df['gaming'] / table_11a_df['total_leisure'] * 100).round(2)
        table_11a_df['tv_pct_of_leisure'] = (table_11a_df['tv'] / table_11a_df['total_leisure'] * 100).round(2)
        table_11a_df['socializing_pct_of_leisure'] = (table_11a_df['socializing'] / table_11a_df['total_leisure'] * 100).round(2)
        
        # Save enhanced data
        table_11a_df.to_csv('data/leisure_analysis.csv', index=False)
    
    # Save weekday/weekend data
    if not table_11b_df.empty:
        table_11b_df.to_csv('data/leisure_by_day_type.csv', index=False)
    
    # Create summary report
    print("\n=== AMERICAN TIME USE SURVEY 2024 - KEY FINDINGS ===\n")
    
    print("Overall Statistics:")
    print(f"  • Total leisure time: {key_stats.get('total_leisure_hours', 'N/A')} hours/day")
    print(f"  • TV watching: {key_stats.get('tv_hours', 'N/A')} hours/day")
    print(f"  • Gaming/computer leisure: {key_stats.get('gaming_minutes', 'N/A')} minutes/day")
    print(f"  • Socializing: {key_stats.get('socializing_minutes', 'N/A')} minutes/day")
    
    print("\nGender Differences:")
    print(f"  • Men: {key_stats.get('men_leisure_hours', 'N/A')} hours/day")
    print(f"  • Women: {key_stats.get('women_leisure_hours', 'N/A')} hours/day")
    
    if not table_11a_df.empty:
        print("\nAge Group Analysis (Gaming time in hours/day):")
        age_groups = table_11a_df[table_11a_df['demographic'].str.contains('years', na=False)]
        for _, row in age_groups.iterrows():
            print(f"  • {row['demographic']}: {row['gaming']:.2f} hours ({row['gaming_pct_of_leisure']:.1f}% of leisure)")

def main():
    pdf_path = Path("source/American Time Use Survey 2024.pdf")
    output_dir = Path("data")
    output_dir.mkdir(exist_ok=True)
    
    print("Extracting key statistics from ATUS 2024...")
    key_stats = extract_key_statistics(pdf_path)
    
    print("Extracting demographic breakdowns (Table 11A)...")
    table_11a_df = extract_table_11a_data(pdf_path)
    
    print("Extracting weekday/weekend breakdowns (Table 11B)...")
    table_11b_df = extract_table_11b_data(pdf_path)
    
    print("Processing and saving data...")
    process_and_save_data(key_stats, table_11a_df, table_11b_df)
    
    print("\n✓ Extraction complete! Files created:")
    print("  • data/key_statistics.csv - Overall statistics")
    print("  • data/leisure_by_demographics.csv - Raw demographic data")
    print("  • data/leisure_analysis.csv - Enhanced analysis with percentages")
    print("  • data/leisure_by_day_type.csv - Weekday vs weekend data")

if __name__ == "__main__":
    main()