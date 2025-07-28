import fitz
import pandas as pd
import re
from pathlib import Path

def extract_time_use_data(pdf_path):
    """Extract time use data from American Time Use Survey PDF"""
    doc = fitz.open(pdf_path)
    
    all_text = ""
    for page_num in range(len(doc)):
        page = doc[page_num]
        all_text += page.get_text()
    
    doc.close()
    
    lines = all_text.split('\n')
    
    data = []
    current_category = None
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        time_pattern = r'(\d+):(\d+)'
        match = re.search(time_pattern, line)
        
        if match:
            hours = int(match.group(1))
            minutes = int(match.group(2))
            total_minutes = hours * 60 + minutes
            
            category_text = re.sub(time_pattern, '', line).strip()
            category_text = re.sub(r'\.+$', '', category_text).strip()
            
            if category_text:
                data.append({
                    'category': category_text,
                    'hours': hours,
                    'minutes': minutes,
                    'total_minutes': total_minutes
                })
    
    df = pd.DataFrame(data)
    
    if not df.empty:
        df = df[df['total_minutes'] > 0]
        df = df.drop_duplicates(subset=['category'])
        df = df.sort_values('total_minutes', ascending=False)
    
    return df

def save_data(df, output_path):
    """Save extracted data to CSV"""
    df.to_csv(output_path, index=False)
    print(f"Data saved to {output_path}")

if __name__ == "__main__":
    pdf_path = Path("source/atus.pdf")
    output_path = Path("data/time_use_data.csv")
    
    output_path.parent.mkdir(exist_ok=True)
    
    if pdf_path.exists():
        df = extract_time_use_data(pdf_path)
        if not df.empty:
            save_data(df, output_path)
            print("\nExtracted Time Use Data:")
            print(df.head(10))
        else:
            print("No time use data found in the PDF")
    else:
        print(f"PDF not found at {pdf_path}. Please place the American Time Use Survey PDF in the source folder.")