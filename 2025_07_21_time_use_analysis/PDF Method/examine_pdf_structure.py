import fitz
from pathlib import Path

def examine_page_with_data(pdf_path, page_numbers=[1, 2, 23, 24]):
    """Examine specific pages that likely contain our data"""
    doc = fitz.open(pdf_path)
    
    for page_num in page_numbers:
        if page_num <= len(doc):
            page = doc[page_num - 1]  # 0-indexed
            text = page.get_text()
            
            print(f"\n{'='*80}")
            print(f"PAGE {page_num} - First 2000 characters:")
            print(f"{'='*80}")
            print(text[:2000])
            
            # Look for lines containing time patterns
            print(f"\n--- Lines with time values (HH:MM format) on page {page_num} ---")
            lines = text.split('\n')
            for line in lines:
                if re.search(r'\d+:\d+', line):
                    print(f"  > {line.strip()}")
            
            # Look for gaming/TV mentions
            print(f"\n--- Lines with gaming/TV/leisure mentions on page {page_num} ---")
            for line in lines:
                line_lower = line.lower()
                if any(word in line_lower for word in ['game', 'gaming', 'television', 'tv', 'leisure', 'computer']):
                    print(f"  > {line.strip()}")
    
    doc.close()

if __name__ == "__main__":
    import re
    pdf_path = Path("source/American Time Use Survey 2024.pdf")
    examine_page_with_data(pdf_path)