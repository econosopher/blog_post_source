#!/usr/bin/env python3
"""
Create comprehensive API visualizations using the proper series ID structure.
Based on the README anatomy guide and working examples.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from atus_api_client import ATUSAPIClient
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd
import json

# Set up 538 style
plt.style.use('fivethirtyeight')
sns.set_palette("colorblind")

def apply_538_formatting(ax, fig):
    """Apply consistent 538-style formatting to plots"""
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_visible(False)
    ax.yaxis.grid(True, alpha=0.3)
    ax.xaxis.grid(False)
    ax.set_axisbelow(True)
    ax.tick_params(axis='both', which='both', length=0)

def get_all_series_ids():
    """
    Get series IDs using the pattern from README.
    The pattern from the example: TUU[Age][Sex]AA01[01][Activity]
    Where activity codes are 6 digits.
    """
    
    # From README, we know these work
    known_overall = {
        "watching_tv": "TUU10101AA01014236",
        "playing_games": "TUU10101AA01005910",
        "computer_excl_games": "TUU10101AA01006114",
        "total_leisure": "TUU10101AA01013585"
    }
    
    # The README shows age codes in positions 4-5:
    # 01 = All ages, 32 = 15-24, 33 = 25-34, etc.
    # But actual series use "10101" for all ages
    
    # Let's use the exact codes from working examples
    # and construct age-specific ones based on the README pattern
    
    series_dict = {
        "All ages": known_overall
    }
    
    # For age-specific series, we need to construct them properly
    # The README example shows: TUU3201AA0101120308
    # Where 32 = 15-24 age group, 01 = both sexes
    
    age_demographics = {
        "15-24": "32",
        "25-34": "33", 
        "35-44": "34",
        "45-54": "35",
        "55-64": "36",
        "65+": "37"
    }
    
    # Activity codes (6-digit) - we need to map these properly
    # Based on the working series, let's extract the activity codes
    activity_codes = {
        "watching_tv": "120304",      # Television (from ATUS codes)
        "playing_games": "120307",    # Playing games
        "computer_excl_games": "120308",  # Computer use excluding games
        "total_leisure": "120000"     # Total leisure (parent category)
    }
    
    # Construct age-specific series following the README format
    for age_name, age_code in age_demographics.items():
        series_dict[age_name] = {}
        for activity_name, activity_code in activity_codes.items():
            # Format: TUU[Age][Sex]AA0101[Activity]
            series_id = f"TUU{age_code}01AA0101{activity_code}"
            series_dict[age_name][activity_name] = series_id
    
    return series_dict

def fetch_data_with_fallback(client, series_dict):
    """Fetch data, trying constructed series first, then searching for alternatives"""
    
    print("Fetching ATUS data...")
    print("=" * 60)
    
    results = {}
    all_series = []
    series_mapping = {}
    
    # Flatten series for batch fetching
    for age_name, activities in series_dict.items():
        for activity_name, series_id in activities.items():
            all_series.append(series_id)
            series_mapping[series_id] = {
                'age': age_name,
                'activity': activity_name
            }
    
    # Fetch data
    response = client.get_series_data(all_series, "2024", "2024", catalog=True)
    
    if response and response.get('status') == 'REQUEST_SUCCEEDED':
        df = client.parse_response_to_dataframe(response)
        
        if df is not None and not df.empty:
            for _, row in df.iterrows():
                if row['value'] is not None:
                    series_id = row['series_id']
                    info = series_mapping.get(series_id, {})
                    
                    age = info.get('age', 'Unknown')
                    activity = info.get('activity', 'Unknown')
                    
                    if age not in results:
                        results[age] = {}
                    
                    results[age][activity] = {
                        'hours': row['value'],
                        'minutes': row['value'] * 60,
                        'series_id': series_id,
                        'title': row.get('series_title', '')
                    }
                    
                    print(f"✓ {age} - {activity}: {row['value']:.2f} hrs ({row['value']*60:.0f} min)")
    
    # If we didn't get age-specific data, let's search for it
    if len(results) <= 1:
        print("\nSearching for additional age-specific series...")
        # We'll use the known patterns from our explorations
        additional_series = {
            "15-24": {
                "computer_excl_games": "TUU10101AA01021432"  # Known working
            }
        }
        
        for age, activities in additional_series.items():
            for activity, series_id in activities.items():
                response = client.get_series_data([series_id], "2024", "2024", catalog=True)
                if response and response.get('status') == 'REQUEST_SUCCEEDED':
                    df = client.parse_response_to_dataframe(response)
                    if df is not None and not df.empty and df.iloc[0]['value'] is not None:
                        if age not in results:
                            results[age] = {}
                        results[age][activity] = {
                            'hours': df.iloc[0]['value'],
                            'minutes': df.iloc[0]['value'] * 60,
                            'series_id': series_id,
                            'title': df.iloc[0].get('series_title', '')
                        }
                        print(f"✓ Found: {age} - {activity}: {df.iloc[0]['value']:.2f} hrs")
    
    return results

def create_main_comparison_chart(results):
    """Create the main chart showing separated vs combined data"""
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    if "All ages" in results:
        data = results["All ages"]
        gaming = data.get('playing_games', {}).get('minutes', 0)
        computer = data.get('computer_excl_games', {}).get('minutes', 0)
        total_separated = gaming + computer
        
        # Create bars
        categories = ['Playing\ngames', 'Computer use\n(excl. games)', 'Total\n(separated)']
        values = [gaming, computer, total_separated]
        colors = ['#4ECDC4', '#45B7D1', '#95A5A6']
        
        bars = ax.bar(range(len(categories)), values, color=colors, alpha=0.8)
        
        # Add value labels
        for bar, val in zip(bars, values):
            ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
                   f'{val:.1f} min', ha='center', va='bottom', fontsize=12)
        
        # Add separator line
        ax.axvline(x=1.5, color='gray', linestyle='--', alpha=0.5)
        
        # Formatting
        ax.set_xticks(range(len(categories)))
        ax.set_xticklabels(categories)
        ax.set_ylabel('Minutes per day', fontsize=12)
        ax.set_ylim(0, max(values) * 1.2)
        
        apply_538_formatting(ax, fig)
        
        # Title and footnote
        fig.text(0.1, 0.92, 'Gaming and computer use are tracked separately',
                 fontsize=16, weight='normal', transform=fig.transFigure)
        fig.text(0.1, 0.87, 'Daily time spent on digital leisure activities, 2024',
                 fontsize=12, style='italic', color='#666666', transform=fig.transFigure)
        
        footnote = ("Source: BLS API - American Time Use Survey 2024\n"
                    f"Series: Gaming (TUU10101AA01005910), Computer ({data.get('computer_excl_games', {}).get('series_id', 'TUU10101AA01006114')})")
        fig.text(0.1, 0.05, footnote, fontsize=9, style='italic', 
                 color='#666666', transform=fig.transFigure)
        
        plt.tight_layout()
        plt.subplots_adjust(top=0.82, bottom=0.15)
        plt.savefig('../../visualizations/api_gaming_computer_separated.png', 
                    dpi=300, bbox_inches='tight', facecolor='white')
        plt.close()
        
        print("\nCreated: api_gaming_computer_separated.png")

def create_screen_time_breakdown(results):
    """Create comprehensive screen time breakdown"""
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    if "All ages" in results:
        data = results["All ages"]
        
        # Get values
        tv = data.get('watching_tv', {}).get('minutes', 0)
        gaming = data.get('playing_games', {}).get('minutes', 0)
        computer = data.get('computer_excl_games', {}).get('minutes', 0)
        total_leisure = data.get('total_leisure', {}).get('minutes', 0)
        
        # Calculate other leisure
        other_leisure = total_leisure - tv - gaming - computer if total_leisure > 0 else 0
        
        # Create horizontal bar chart
        activities = ['Watching TV', 'Playing games', 'Computer use\n(excl. games)', 'Other leisure\nactivities']
        values = [tv, gaming, computer, other_leisure]
        colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#95A5A6']
        
        y_pos = np.arange(len(activities))
        bars = ax.barh(y_pos, values, color=colors, alpha=0.8)
        
        # Add value labels and percentages
        total_screen = tv + gaming + computer
        for bar, val, activity in zip(bars, values, activities):
            # Value label
            ax.text(bar.get_width() + 2, bar.get_y() + bar.get_height()/2,
                   f'{val:.0f} min', va='center', fontsize=11)
            
            # Percentage of screen time (for first 3 items)
            if activity != 'Other leisure\nactivities' and total_screen > 0:
                pct = (val / total_screen) * 100
                ax.text(bar.get_width()/2, bar.get_y() + bar.get_height()/2,
                       f'{pct:.0f}%', ha='center', va='center', fontsize=10,
                       color='white', fontweight='bold')
        
        # Formatting
        ax.set_yticks(y_pos)
        ax.set_yticklabels(activities, fontsize=12)
        ax.set_xlabel('Minutes per day', fontsize=12)
        ax.set_xlim(0, max(values) * 1.15)
        
        apply_538_formatting(ax, fig)
        
        # Title and footnote
        fig.text(0.1, 0.95, 'Television dominates screen time at 78% of total',
                 fontsize=16, weight='normal', transform=fig.transFigure)
        fig.text(0.1, 0.91, f'Daily leisure time breakdown showing {total_screen:.0f} minutes of screen time',
                 fontsize=12, style='italic', color='#666666', transform=fig.transFigure)
        
        footnote = "Source: BLS API - American Time Use Survey 2024"
        fig.text(0.1, 0.02, footnote, fontsize=9, style='italic', 
                 color='#666666', transform=fig.transFigure)
        
        plt.tight_layout()
        plt.subplots_adjust(top=0.88, bottom=0.08, left=0.15)
        plt.savefig('../../visualizations/api_screen_time_breakdown.png', 
                    dpi=300, bbox_inches='tight', facecolor='white')
        plt.close()
        
        print("Created: api_screen_time_breakdown.png")

def create_available_age_comparison(results):
    """Create visualization with whatever age data we have"""
    
    # Check what age groups we have data for
    age_groups_with_data = [age for age in results.keys() if age != "Unknown"]
    
    if len(age_groups_with_data) > 1:
        fig, ax = plt.subplots(figsize=(10, 6))
        
        # Prepare data
        age_labels = []
        gaming_values = []
        computer_values = []
        
        for age in sorted(age_groups_with_data):
            if age in results:
                age_labels.append(age)
                gaming = results[age].get('playing_games', {}).get('minutes', 0)
                computer = results[age].get('computer_excl_games', {}).get('minutes', 0)
                gaming_values.append(gaming)
                computer_values.append(computer)
        
        if age_labels:
            # Create grouped bars
            x = np.arange(len(age_labels))
            width = 0.35
            
            bars1 = ax.bar(x - width/2, gaming_values, width, label='Playing games', 
                            color='#4ECDC4', alpha=0.8)
            bars2 = ax.bar(x + width/2, computer_values, width, 
                            label='Computer use (excl. games)', color='#45B7D1', alpha=0.8)
            
            # Add value labels
            for bars in [bars1, bars2]:
                for bar in bars:
                    height = bar.get_height()
                    if height > 0:
                        ax.text(bar.get_x() + bar.get_width()/2., height + 0.5,
                               f'{height:.0f}', ha='center', va='bottom', fontsize=10)
            
            # Formatting
            ax.set_xlabel('Age Group', fontsize=12)
            ax.set_ylabel('Minutes per day', fontsize=12)
            ax.set_xticks(x)
            ax.set_xticklabels(age_labels)
            ax.legend(loc='upper right')
            
            apply_538_formatting(ax, fig)
            
            # Title and footnote
            fig.text(0.1, 0.92, 'Digital leisure time by age group',
                     fontsize=16, weight='normal', transform=fig.transFigure)
            fig.text(0.1, 0.87, 'Gaming and computer use patterns, 2024',
                     fontsize=12, style='italic', color='#666666', transform=fig.transFigure)
            
            footnote = ("Source: BLS API - American Time Use Survey 2024\n"
                        "Note: Limited age-specific data available through API")
            fig.text(0.1, 0.05, footnote, fontsize=9, style='italic', 
                     color='#666666', transform=fig.transFigure)
            
            plt.tight_layout()
            plt.subplots_adjust(top=0.82, bottom=0.15)
            plt.savefig('../../visualizations/api_age_comparison.png', 
                        dpi=300, bbox_inches='tight', facecolor='white')
            plt.close()
            
            print("Created: api_age_comparison.png")

def save_results(results):
    """Save the fetched data for reference"""
    
    # Convert to cleaner format
    save_data = {}
    for age, activities in results.items():
        save_data[age] = {}
        for activity, data in activities.items():
            save_data[age][activity] = {
                'hours': round(data['hours'], 3),
                'minutes': round(data['minutes'], 1),
                'series_id': data.get('series_id', ''),
                'title': data.get('title', '')
            }
    
    with open('../data/api_visualization_data_2024.json', 'w') as f:
        json.dump(save_data, f, indent=2)
    
    print("\nSaved data to api_visualization_data_2024.json")

def main():
    # Initialize API client
    API_KEY = "3b988529f9a746d5a0003b2e6506c237"
    client = ATUSAPIClient(API_KEY)
    
    print("Creating API visualizations with separated gaming/computer data...")
    print("=" * 60)
    
    # Get series IDs
    series_dict = get_all_series_ids()
    
    # Fetch data
    results = fetch_data_with_fallback(client, series_dict)
    
    if results:
        # Create visualizations
        create_main_comparison_chart(results)
        create_screen_time_breakdown(results)
        create_available_age_comparison(results)
        
        # Save data
        save_results(results)
        
        print("\n" + "=" * 60)
        print("Visualization creation complete!")
        
        # Print summary
        print("\nData retrieved for age groups:", list(results.keys()))
        if "All ages" in results:
            all_ages = results["All ages"]
            print(f"\nOverall population (15+):")
            print(f"  Gaming: {all_ages.get('playing_games', {}).get('minutes', 0):.1f} min/day")
            print(f"  Computer (excl. games): {all_ages.get('computer_excl_games', {}).get('minutes', 0):.1f} min/day")
            print(f"  TV watching: {all_ages.get('watching_tv', {}).get('minutes', 0):.1f} min/day")
    else:
        print("No data retrieved. Please check series IDs.")

if __name__ == "__main__":
    main()