import fitz
import pandas as pd
import re
import json
from pathlib import Path

def extract_tables_from_pdf(pdf_path):
    """Extract all text and identify table structures from ATUS PDF"""
    doc = fitz.open(pdf_path)
    
    all_pages_data = []
    
    for page_num in range(len(doc)):
        page = doc[page_num]
        text = page.get_text()
        
        # Also try to extract table data
        tables = page.find_tables()
        
        page_data = {
            'page_num': page_num + 1,
            'text': text,
            'tables': []
        }
        
        if tables:
            for table in tables:
                extracted_table = table.extract()
                page_data['tables'].append(extracted_table)
        
        all_pages_data.append(page_data)
    
    doc.close()
    return all_pages_data

def find_gaming_tv_social_media_data(pages_data):
    """Search for gaming, TV, and social media data in the extracted pages"""
    
    gaming_patterns = [
        r'playing games',
        r'computer games',
        r'video games',
        r'gaming',
        r'game playing',
        r'electronic games'
    ]
    
    tv_patterns = [
        r'watching tv',
        r'television',
        r'tv watching',
        r'watching television'
    ]
    
    social_media_patterns = [
        r'social media',
        r'social networking',
        r'facebook',
        r'twitter',
        r'instagram',
        r'computer use.*social'
    ]
    
    leisure_patterns = [
        r'leisure',
        r'socializing',
        r'relaxing'
    ]
    
    demographic_patterns = [
        r'age',
        r'gender',
        r'sex',
        r'male',
        r'female',
        r'men',
        r'women',
        r'15[-\s]?to[-\s]?24',
        r'25[-\s]?to[-\s]?34',
        r'35[-\s]?to[-\s]?44',
        r'45[-\s]?to[-\s]?54',
        r'55[-\s]?to[-\s]?64',
        r'65[-\s]?and[-\s]?over',
        r'65\+',
        r'employed',
        r'unemployed',
        r'education'
    ]
    
    results = {
        'gaming_data': [],
        'tv_data': [],
        'social_media_data': [],
        'leisure_data': [],
        'demographic_tables': []
    }
    
    for page_data in pages_data:
        page_num = page_data['page_num']
        text = page_data['text'].lower()
        
        # Check if this page contains relevant data
        has_gaming = any(re.search(pattern, text, re.IGNORECASE) for pattern in gaming_patterns)
        has_tv = any(re.search(pattern, text, re.IGNORECASE) for pattern in tv_patterns)
        has_social = any(re.search(pattern, text, re.IGNORECASE) for pattern in social_media_patterns)
        has_leisure = any(re.search(pattern, text, re.IGNORECASE) for pattern in leisure_patterns)
        has_demographics = any(re.search(pattern, text, re.IGNORECASE) for pattern in demographic_patterns)
        
        if has_gaming or has_tv or has_social or has_leisure:
            print(f"\nPage {page_num} contains relevant data:")
            if has_gaming:
                print("  - Gaming data found")
            if has_tv:
                print("  - TV data found")
            if has_social:
                print("  - Social media data found")
            if has_leisure:
                print("  - Leisure data found")
            if has_demographics:
                print("  - Demographic breakdowns found")
            
            # Extract tables from this page
            if page_data['tables']:
                for i, table in enumerate(page_data['tables']):
                    results['demographic_tables'].append({
                        'page': page_num,
                        'table_index': i,
                        'data': table,
                        'has_gaming': has_gaming,
                        'has_tv': has_tv,
                        'has_social': has_social,
                        'has_leisure': has_leisure,
                        'has_demographics': has_demographics
                    })
    
    return results

def extract_time_values(text):
    """Extract time values in hours:minutes format"""
    time_pattern = r'(\d+):(\d+)'
    matches = re.findall(time_pattern, str(text))
    if matches:
        hours, minutes = matches[0]
        return int(hours) * 60 + int(minutes)
    return None

def process_demographic_tables(results):
    """Process tables to extract demographic breakdowns"""
    processed_data = []
    
    for table_info in results['demographic_tables']:
        table_data = table_info['data']
        
        if not table_data:
            continue
            
        # Convert table to DataFrame for easier processing
        try:
            df = pd.DataFrame(table_data[1:], columns=table_data[0] if table_data[0] else None)
            
            # Look for columns that might contain activity names and time values
            for col in df.columns:
                if col and any(keyword in str(col).lower() for keyword in ['activity', 'category', 'item']):
                    activity_col = col
                    
                    # Look for time columns
                    for time_col in df.columns:
                        if time_col and any(keyword in str(time_col).lower() for keyword in ['time', 'hours', 'minutes', 'average']):
                            
                            # Extract relevant rows
                            for idx, row in df.iterrows():
                                activity = str(row[activity_col]).lower()
                                
                                # Check if this row contains our target activities
                                if any(keyword in activity for keyword in ['game', 'gaming', 'playing games']):
                                    activity_type = 'gaming'
                                elif any(keyword in activity for keyword in ['tv', 'television']):
                                    activity_type = 'tv'
                                elif any(keyword in activity for keyword in ['social media', 'social networking']):
                                    activity_type = 'social_media'
                                elif any(keyword in activity for keyword in ['leisure', 'relaxing']):
                                    activity_type = 'leisure_total'
                                else:
                                    continue
                                
                                time_value = extract_time_values(row[time_col])
                                if time_value:
                                    processed_data.append({
                                        'page': table_info['page'],
                                        'activity_type': activity_type,
                                        'activity_description': row[activity_col],
                                        'time_minutes': time_value,
                                        'demographic': 'overall',  # Will be updated if demographic info found
                                        'raw_data': row.to_dict()
                                    })
            
        except Exception as e:
            print(f"Error processing table on page {table_info['page']}: {e}")
    
    return processed_data

def save_results(results, processed_data):
    """Save extracted data to files"""
    # Save raw results
    with open('data/raw_extraction_results.json', 'w') as f:
        json.dump({
            'total_tables': len(results['demographic_tables']),
            'pages_with_data': list(set(t['page'] for t in results['demographic_tables']))
        }, f, indent=2)
    
    # Save processed data
    if processed_data:
        df = pd.DataFrame(processed_data)
        df.to_csv('data/gaming_tv_social_extracted.csv', index=False)
        print(f"\nExtracted {len(processed_data)} data points")
        print("\nActivity type breakdown:")
        print(df['activity_type'].value_counts())
    else:
        print("\nNo structured time data found. Manual inspection may be needed.")
    
    # Save sample of text from relevant pages for manual inspection
    sample_pages = []
    for table_info in results['demographic_tables'][:5]:  # First 5 relevant pages
        sample_pages.append({
            'page': table_info['page'],
            'has_gaming': table_info['has_gaming'],
            'has_tv': table_info['has_tv'],
            'has_social': table_info['has_social'],
            'table_sample': table_info['data'][:3] if table_info['data'] else None
        })
    
    with open('data/sample_pages_for_review.json', 'w') as f:
        json.dump(sample_pages, f, indent=2)

def main():
    pdf_path = Path("source/American Time Use Survey 2024.pdf")  # Updated filename
    output_dir = Path("data")
    output_dir.mkdir(exist_ok=True)
    
    if not pdf_path.exists():
        print(f"PDF not found at {pdf_path}")
        return
    
    print("Extracting data from ATUS PDF...")
    pages_data = extract_tables_from_pdf(pdf_path)
    print(f"Extracted data from {len(pages_data)} pages")
    
    print("\nSearching for gaming, TV, and social media data...")
    results = find_gaming_tv_social_media_data(pages_data)
    
    print(f"\nFound {len(results['demographic_tables'])} tables with relevant data")
    
    print("\nProcessing demographic tables...")
    processed_data = process_demographic_tables(results)
    
    print("\nSaving results...")
    save_results(results, processed_data)
    
    print("\nExtraction complete! Check the 'data' folder for results.")
    print("\nFiles created:")
    print("  - data/raw_extraction_results.json")
    print("  - data/gaming_tv_social_extracted.csv (if data found)")
    print("  - data/sample_pages_for_review.json")

if __name__ == "__main__":
    main()