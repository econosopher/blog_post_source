import fitz
import pandas as pd
import re
import json
from pathlib import Path

def extract_all_text_and_tables(pdf_path):
    """Extract all text page by page and look for table-like structures"""
    doc = fitz.open(pdf_path)
    
    all_data = []
    
    for page_num in range(len(doc)):
        page = doc[page_num]
        
        # Get full text
        full_text = page.get_text()
        
        # Get text blocks for better structure understanding
        blocks = page.get_text("blocks")
        
        # Extract tables using PyMuPDF's table detection
        tables = page.find_tables()
        
        page_data = {
            'page_num': page_num + 1,
            'full_text': full_text,
            'text_blocks': blocks,
            'tables': []
        }
        
        # Process tables
        if tables:
            for table in tables:
                extracted = table.extract()
                page_data['tables'].append(extracted)
        
        all_data.append(page_data)
    
    doc.close()
    return all_data

def search_for_specific_data(all_data):
    """Search for gaming, TV, social media, and demographic data"""
    
    findings = {
        'gaming': [],
        'tv': [],
        'social_media': [],
        'leisure': [],
        'demographics': []
    }
    
    # Enhanced patterns for finding time data
    time_patterns = [
        r'(\d+):(\d+)',  # Standard time format
        r'(\d+\.\d+)\s*hours?',  # Decimal hours
        r'(\d+)\s*hours?\s*(?:and\s*)?(\d+)\s*minutes?',  # Written out
    ]
    
    # Activity patterns
    activity_patterns = {
        'gaming': [
            r'playing\s+games',
            r'computer\s+games',
            r'video\s+games',
            r'gaming',
            r'games\s*\(not\s+sports\)',
            r'electronic\s+games'
        ],
        'tv': [
            r'watching\s+tv',
            r'television',
            r'tv\s+watching',
            r'watching\s+television'
        ],
        'social_media': [
            r'social\s+media',
            r'social\s+networking',
            r'computer\s+use.*social',
            r'internet.*social'
        ],
        'leisure': [
            r'leisure\s+and\s+sports',
            r'leisure\s+activities',
            r'relaxing\s+and\s+leisure',
            r'socializing'
        ]
    }
    
    # Demographic patterns
    demo_patterns = [
        r'by\s+age',
        r'by\s+sex',
        r'by\s+gender',
        r'men.*women',
        r'male.*female',
        r'age\s+group',
        r'\d+[-\s]to[-\s]\d+\s*years?',
        r'\d+\s*and\s*over'
    ]
    
    for page_data in all_data:
        page_num = page_data['page_num']
        text = page_data['full_text'].lower()
        
        # Check for each activity type
        for activity_type, patterns in activity_patterns.items():
            for pattern in patterns:
                if re.search(pattern, text, re.IGNORECASE):
                    # Look for time values nearby
                    lines = text.split('\n')
                    for i, line in enumerate(lines):
                        if re.search(pattern, line, re.IGNORECASE):
                            # Check this line and surrounding lines for time values
                            context_lines = lines[max(0, i-3):min(len(lines), i+4)]
                            context = '\n'.join(context_lines)
                            
                            # Look for time patterns
                            for time_pattern in time_patterns:
                                time_matches = re.findall(time_pattern, context)
                                if time_matches:
                                    findings[activity_type].append({
                                        'page': page_num,
                                        'activity_match': line.strip(),
                                        'context': context,
                                        'time_values': time_matches
                                    })
        
        # Check for demographic breakdowns
        for demo_pattern in demo_patterns:
            if re.search(demo_pattern, text, re.IGNORECASE):
                findings['demographics'].append({
                    'page': page_num,
                    'pattern': demo_pattern
                })
    
    return findings

def extract_table_data_manually(all_data):
    """Try to extract structured data by looking for table-like patterns in text"""
    
    extracted_data = []
    
    # Pattern for finding table-like structures with activities and times
    table_patterns = [
        # Activity followed by time
        r'([A-Za-z\s,\(\)]+?)\s+(\d+:\d+)',
        # Activity with percentage and time
        r'([A-Za-z\s,\(\)]+?)\s+(\d+\.\d+%?)\s+(\d+:\d+)',
        # Table A-1 style entries
        r'([A-Za-z\s,\(\)]+?)\s+\.+\s+(\d+:\d+)'
    ]
    
    for page_data in all_data:
        page_num = page_data['page_num']
        text = page_data['full_text']
        
        # Look for "Table" mentions
        if 'table' in text.lower():
            lines = text.split('\n')
            
            for line in lines:
                # Skip empty lines and headers
                if not line.strip() or len(line.strip()) < 5:
                    continue
                
                # Try each pattern
                for pattern in table_patterns:
                    matches = re.findall(pattern, line)
                    if matches:
                        for match in matches:
                            activity = match[0].strip()
                            time_str = match[-1] if ':' in match[-1] else match[1]
                            
                            # Check if this is one of our target activities
                            activity_lower = activity.lower()
                            if any(keyword in activity_lower for keyword in ['game', 'gaming', 'playing games']):
                                activity_type = 'gaming'
                            elif any(keyword in activity_lower for keyword in ['tv', 'television']):
                                activity_type = 'tv'
                            elif any(keyword in activity_lower for keyword in ['social media', 'social network']):
                                activity_type = 'social_media'
                            elif any(keyword in activity_lower for keyword in ['leisure', 'relaxing']):
                                activity_type = 'leisure'
                            else:
                                continue
                            
                            extracted_data.append({
                                'page': page_num,
                                'activity_type': activity_type,
                                'activity_description': activity,
                                'time_string': time_str,
                                'source_line': line.strip()
                            })
    
    return extracted_data

def save_detailed_findings(findings, extracted_data):
    """Save all findings for manual review"""
    
    # Save findings
    with open('data/detailed_findings.json', 'w') as f:
        json.dump(findings, f, indent=2)
    
    # Save extracted data
    if extracted_data:
        df = pd.DataFrame(extracted_data)
        df.to_csv('data/extracted_table_data.csv', index=False)
        print(f"\nExtracted {len(extracted_data)} table entries")
    
    # Create summary
    summary = {
        'gaming_mentions': len(findings['gaming']),
        'tv_mentions': len(findings['tv']),
        'social_media_mentions': len(findings['social_media']),
        'leisure_mentions': len(findings['leisure']),
        'demographic_pages': len(set(d['page'] for d in findings['demographics'])),
        'extracted_data_points': len(extracted_data)
    }
    
    with open('data/extraction_summary.json', 'w') as f:
        json.dump(summary, f, indent=2)
    
    print("\nExtraction Summary:")
    for key, value in summary.items():
        print(f"  {key}: {value}")

def main():
    pdf_path = Path("source/American Time Use Survey 2024.pdf")
    output_dir = Path("data")
    output_dir.mkdir(exist_ok=True)
    
    if not pdf_path.exists():
        print(f"PDF not found at {pdf_path}")
        return
    
    print("Extracting all data from ATUS PDF...")
    all_data = extract_all_text_and_tables(pdf_path)
    print(f"Processed {len(all_data)} pages")
    
    print("\nSearching for specific activity data...")
    findings = search_for_specific_data(all_data)
    
    print("\nExtracting table data...")
    extracted_data = extract_table_data_manually(all_data)
    
    print("\nSaving findings...")
    save_detailed_findings(findings, extracted_data)
    
    # Print sample findings for each category
    print("\n=== Sample Findings ===")
    for category in ['gaming', 'tv', 'social_media']:
        if findings[category]:
            print(f"\n{category.upper()} (Page {findings[category][0]['page']}):")
            print(f"Match: {findings[category][0]['activity_match']}")
            if 'time_values' in findings[category][0]:
                print(f"Time values found: {findings[category][0]['time_values']}")
    
    print("\n\nCheck the 'data' folder for detailed results:")
    print("  - detailed_findings.json (all mentions with context)")
    print("  - extracted_table_data.csv (structured data if found)")
    print("  - extraction_summary.json (summary statistics)")

if __name__ == "__main__":
    main()