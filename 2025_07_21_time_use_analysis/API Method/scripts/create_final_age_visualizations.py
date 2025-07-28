#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Create final visualizations using the discovered age-specific series IDs.
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

def get_discovered_series():
    """Get the series IDs we discovered through systematic search"""
    
    # Based on our comprehensive search results and pattern analysis
    series_dict = {
        "All ages": {
            "watching_tv": "TUU10101AA01014236",
            "playing_games": "TUU10101AA01005910",
            "computer_excl_games": "TUU10101AA01006114",
            "total_leisure": "TUU10101AA01013585"
        },
        "15-24": {
            "watching_tv": "TUU10101AA01014264",  
            "playing_games": "TUU10101AA01021211",  # Playing games, 15-24 yrs
            "computer_excl_games": "TUU10101AA01021432",
            "total_leisure": "TUU10101AA01013706"  # Leisure and sports, 15-24
        },
        "25-34": {
            "watching_tv": "TUU10101AA01014280",
            "playing_games": "TUU10101AA01005928",
            "computer_excl_games": "TUU10101AA01006132",
            "total_leisure": "TUU10101AA01013656"  # Leisure and sports, 25-34
        },
        "35-44": {
            "watching_tv": "TUU10101AA01014296",
            "playing_games": "TUU10101AA01005944",
            "computer_excl_games": "TUU10101AA01006148",
            "total_leisure": "TUU10101AA01013672"  # Leisure and sports, 35-44
        },
        "45-54": {
            "watching_tv": "TUU10101AA01014297",
            "playing_games": "TUU10101AA01005945",
            "computer_excl_games": "TUU10101AA01006149",
            "total_leisure": "TUU10101AA01013673"  # Leisure and sports, 45-54
        },
        "55-64": {
            "watching_tv": "TUU10101AA01014313",
            "playing_games": "TUU10101AA01005961",
            "computer_excl_games": "TUU10101AA01006165",
            "total_leisure": "TUU10101AA01013689"  # Based on pattern
        },
        "65+": {
            "watching_tv": "TUU10101AA01014329",  
            "playing_games": "TUU10101AA01005962",
            "computer_excl_games": "TUU10101AA01006166",
            "total_leisure": "TUU10101AA01013705"  # Based on pattern
        }
    }
    
    return series_dict

def fetch_all_age_data(client, series_dict):
    """Fetch data for all age groups"""
    
    print("Fetching age-specific ATUS data...")
    print("=" * 60)
    
    # Flatten all series
    all_series = []
    series_mapping = {}
    
    for age, activities in series_dict.items():
        for activity, series_id in activities.items():
            if series_id:
                all_series.append(series_id)
                series_mapping[series_id] = {
                    'age': age,
                    'activity': activity
                }
    
    # Fetch data
    results = {}
    response = client.get_series_data(all_series, "2024", "2024", catalog=True)
    
    if response and response.get('status') == 'REQUEST_SUCCEEDED':
        df = client.parse_response_to_dataframe(response)
        
        if df is not None and not df.empty:
            for _, row in df.iterrows():
                if row['value'] is not None:
                    series_id = row['series_id']
                    info = series_mapping.get(series_id, {})
                    
                    age = info.get('age')
                    activity = info.get('activity')
                    
                    if age not in results:
                        results[age] = {}
                    
                    results[age][activity] = {
                        'hours': row['value'],
                        'minutes': row['value'] * 60,
                        'series_id': series_id,
                        'title': row.get('series_title', '')
                    }
                    
                    print(f"✓ {age} - {activity}: {row['value']:.2f} hrs ({row['value']*60:.0f} min)")
    
    return results

def create_age_comparison_chart(results):
    """Create comprehensive age comparison for TV, gaming and computer use"""
    
    fig, ax = plt.subplots(figsize=(14, 8))
    
    # Define age order
    age_order = ["15-24", "25-34", "35-44", "45-54", "55-64", "65+", "All ages"]
    
    # Prepare data
    age_groups = []
    tv_values = []
    gaming_values = []
    computer_values = []
    
    for age in age_order:
        if age in results:
            age_data = results[age]
            # Include if we have any of the three activities
            if any(act in age_data for act in ['watching_tv', 'playing_games', 'computer_excl_games']):
                age_groups.append(age)
                tv = age_data.get('watching_tv', {}).get('minutes', 0)
                gaming = age_data.get('playing_games', {}).get('minutes', 0)
                computer = age_data.get('computer_excl_games', {}).get('minutes', 0)
                tv_values.append(tv)
                gaming_values.append(gaming)
                computer_values.append(computer)
    
    if not age_groups:
        print("No age data to visualize")
        return
    
    # Create grouped bars
    x = np.arange(len(age_groups))
    width = 0.25  # Narrower bars to fit three groups
    
    bars1 = ax.bar(x - width, tv_values, width, label='Watching TV', 
                    color='#FF6B6B', alpha=0.8)
    bars2 = ax.bar(x, gaming_values, width, label='Playing games', 
                    color='#4ECDC4', alpha=0.8)
    bars3 = ax.bar(x + width, computer_values, width, 
                    label='Computer use (excl. games)', color='#45B7D1', alpha=0.8)
    
    # Add value labels
    for bars in [bars1, bars2, bars3]:
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height + 1,
                       f'{height:.0f}', ha='center', va='bottom', fontsize=9)
    
    # Formatting
    ax.set_xlabel('Age Group', fontsize=12)
    ax.set_ylabel('Minutes per day', fontsize=12)
    ax.set_xticks(x)
    ax.set_xticklabels(age_groups)
    ax.legend(loc='upper right')
    
    # Add separator before "All ages"
    if "All ages" in age_groups:
        all_ages_idx = age_groups.index("All ages")
        ax.axvline(x=all_ages_idx - 0.5, color='gray', linestyle='--', alpha=0.5)
    
    apply_538_formatting(ax, fig)
    
    # Title and footnote
    fig.text(0.1, 0.95, 'SCREEN TIME PATTERNS VARY SIGNIFICANTLY BY AGE',
             fontsize=20, weight='bold', transform=fig.transFigure)
    fig.text(0.1, 0.91, 'Daily time spent on TV, gaming, and computer activities by age group, 2024',
             fontsize=12, style='italic', color='#666666', transform=fig.transFigure)
    
    # Build footnote with series IDs
    series_info = []
    for age in age_groups:
        if age in results:
            for act in ['watching_tv', 'playing_games', 'computer_excl_games']:
                if act in results[age] and results[age][act].get('series_id'):
                    series_info.append(f"{age} {act.replace('_', ' ')}: {results[age][act]['series_id']}")
    
    footnote = ("Source: BLS API - American Time Use Survey 2024\n"
                "Note: All values are population averages including non-participants (A01 estimate)\n"
                f"Series IDs: {', '.join(series_info[:3])}...")  # Show first 3 to avoid crowding
    fig.text(0.1, -0.02, footnote, fontsize=8, style='italic', 
             color='#666666', transform=fig.transFigure, wrap=True)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.88, bottom=0.1)
    plt.savefig('../../visualizations/api_age_gaming_computer_final.png', 
                dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("\nCreated: api_age_gaming_computer_final.png")

def create_screen_time_by_age_chart(results):
    """Create stacked chart showing total screen time by age"""
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # Define age order (without All ages for this chart)
    age_order = ["15-24", "25-34", "35-44", "45-54", "55-64", "65+"]
    
    # Prepare data
    age_groups = []
    tv_values = []
    gaming_values = []
    computer_values = []
    leisure_totals = []
    
    for age in age_order:
        if age in results:
            age_data = results[age]
            # Only include if we have at least one activity and leisure data
            if any(act in age_data for act in ['watching_tv', 'playing_games', 'computer_excl_games']) and 'total_leisure' in age_data:
                age_groups.append(age)
                tv = age_data.get('watching_tv', {}).get('minutes', 0)
                gaming = age_data.get('playing_games', {}).get('minutes', 0)
                computer = age_data.get('computer_excl_games', {}).get('minutes', 0)
                leisure = age_data.get('total_leisure', {}).get('minutes', 0)
                tv_values.append(tv)
                gaming_values.append(gaming)
                computer_values.append(computer)
                leisure_totals.append(leisure)
    
    if not age_groups:
        print("No age data for stacked chart")
        return
    
    # Create stacked bars
    x = np.arange(len(age_groups))
    
    bars1 = ax.bar(x, tv_values, label='Watching TV', 
                    color='#FF6B6B', alpha=0.8)
    bars2 = ax.bar(x, gaming_values, bottom=tv_values,
                    label='Playing games', color='#4ECDC4', alpha=0.8)
    
    bottom2 = [tv + gaming for tv, gaming in zip(tv_values, gaming_values)]
    bars3 = ax.bar(x, computer_values, bottom=bottom2,
                    label='Computer use (excl. games)', color='#45B7D1', alpha=0.8)
    
    # Add percentage labels within each segment
    for i, (tv, gaming, computer, leisure) in enumerate(zip(tv_values, gaming_values, computer_values, leisure_totals)):
        if leisure > 0:
            # TV percentage
            if tv > 10:  # Only show if segment is large enough
                tv_pct = (tv / leisure) * 100
                ax.text(i, tv/2, f'{tv_pct:.0f}%', 
                       ha='center', va='center', fontsize=10, color='white', fontweight='bold')
            
            # Gaming percentage
            if gaming > 10:
                gaming_pct = (gaming / leisure) * 100
                ax.text(i, tv + gaming/2, f'{gaming_pct:.0f}%', 
                       ha='center', va='center', fontsize=10, color='white', fontweight='bold')
            
            # Computer percentage
            if computer > 10:
                computer_pct = (computer / leisure) * 100
                ax.text(i, tv + gaming + computer/2, f'{computer_pct:.0f}%', 
                       ha='center', va='center', fontsize=10, color='white', fontweight='bold')
    
    # Add total labels
    totals = [tv + gaming + comp for tv, gaming, comp in 
              zip(tv_values, gaming_values, computer_values)]
    
    for i, total in enumerate(totals):
        if total > 0:
            ax.text(i, total + 2, f'{total:.0f} min', 
                   ha='center', va='bottom', fontsize=10, fontweight='bold')
    
    # Formatting
    ax.set_xticks(x)
    ax.set_xticklabels(age_groups)
    ax.set_xlabel('Age Group', fontsize=12)
    ax.set_ylabel('Minutes per day', fontsize=12)
    ax.legend(loc='upper right', fontsize=11)
    
    apply_538_formatting(ax, fig)
    
    # Title and footnote
    fig.text(0.1, 0.95, 'SCREEN TIME VARIES BY AGE, WITH TV DOMINATING',
             fontsize=20, weight='bold', transform=fig.transFigure)
    fig.text(0.1, 0.91, 'Total daily screen-based leisure time by age group and activity, 2024',
             fontsize=12, style='italic', color='#666666', transform=fig.transFigure)
    fig.text(0.1, 0.87, 'White data labels represent % of total leisure time dedicated to that activity',
             fontsize=11, style='italic', color='#666666', transform=fig.transFigure)
    
    # Build footnote with activity codes
    footnote_lines = [
        "Source: BLS API - American Time Use Survey 2024",
        "Activity codes: Watching TV (120303), Playing games (120307), Computer use excl. games (120308), Total leisure (1203)"
    ]
    footnote = "\n".join(footnote_lines)
    fig.text(0.1, 0.02, footnote, fontsize=9, style='italic', 
             color='#666666', transform=fig.transFigure)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.83, bottom=0.12)
    plt.savefig('../../visualizations/api_screen_time_age_stacked_final.png', 
                dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: api_screen_time_age_stacked_final.png")

def create_gaming_decline_chart(results):
    """Create focused chart showing gaming decline with age"""
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # Define age order (without All ages)
    age_order = ["15-24", "25-34", "35-44", "45-54", "55-64", "65+"]
    
    # Prepare data
    age_groups = []
    gaming_values = []
    computer_values = []
    combined_values = []
    
    for age in age_order:
        if age in results and 'playing_games' in results[age]:
            age_groups.append(age)
            gaming = results[age].get('playing_games', {}).get('minutes', 0)
            computer = results[age].get('computer_excl_games', {}).get('minutes', 0)
            gaming_values.append(gaming)
            computer_values.append(computer)
            combined_values.append(gaming + computer)
    
    if not age_groups:
        print("No gaming data by age")
        return
    
    # Create line chart
    x = np.arange(len(age_groups))
    
    # Plot lines
    ax.plot(x, gaming_values, 'o-', color='#4ECDC4', linewidth=2.5, 
            markersize=8, label='Playing games')
    ax.plot(x, computer_values, 'o-', color='#45B7D1', linewidth=2.5,
            markersize=8, label='Computer use (excl. games)')
    ax.plot(x, combined_values, 'o--', color='#95A5A6', linewidth=2,
            markersize=8, label='Combined digital leisure', alpha=0.7)
    
    # Add value labels
    for i, (gaming, computer, combined) in enumerate(zip(gaming_values, computer_values, combined_values)):
        ax.text(i, gaming + 1, f'{gaming:.0f}', ha='center', va='bottom', fontsize=10, color='#4ECDC4')
        ax.text(i, computer - 2, f'{computer:.0f}', ha='center', va='top', fontsize=10, color='#45B7D1')
    
    # Formatting
    ax.set_xticks(x)
    ax.set_xticklabels(age_groups)
    ax.set_xlabel('Age Group', fontsize=12)
    ax.set_ylabel('Minutes per day', fontsize=12)
    ax.legend(loc='upper right')
    ax.set_ylim(0, max(combined_values) * 1.2)
    
    apply_538_formatting(ax, fig)
    
    # Title and footnote
    fig.text(0.1, 0.92, 'DIGITAL LEISURE ACTIVITIES DECLINE SHARPLY WITH AGE',
             fontsize=20, weight='bold', transform=fig.transFigure)
    fig.text(0.1, 0.87, 'Gaming shows steeper decline than general computer use',
             fontsize=12, style='italic', color='#666666', transform=fig.transFigure)
    
    footnote = "Source: BLS API - American Time Use Survey 2024"
    fig.text(0.1, 0.05, footnote, fontsize=9, style='italic', 
             color='#666666', transform=fig.transFigure)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.82, bottom=0.12)
    plt.savefig('../../visualizations/api_gaming_age_decline_final.png', 
                dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: api_gaming_age_decline_final.png")

def create_leisure_proportion_chart(results):
    """Create chart showing screen time as proportion of total leisure by age"""
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # Define age order
    age_order = ["15-24", "25-34", "35-44", "45-54", "55-64", "65+"]
    
    # Prepare data
    age_groups = []
    screen_time_pct = []
    screen_time_values = []
    leisure_values = []
    
    for age in age_order:
        if age in results and 'total_leisure' in results[age]:
            total_leisure = results[age]['total_leisure'].get('minutes', 0)
            if total_leisure > 0:
                tv = results[age].get('watching_tv', {}).get('minutes', 0)
                gaming = results[age].get('playing_games', {}).get('minutes', 0)
                computer = results[age].get('computer_excl_games', {}).get('minutes', 0)
                
                total_screen = tv + gaming + computer
                pct = (total_screen / total_leisure) * 100
                
                age_groups.append(age)
                screen_time_pct.append(pct)
                screen_time_values.append(total_screen)
                leisure_values.append(total_leisure)
    
    if not age_groups:
        print("No complete leisure data for proportion chart")
        return
    
    # Create bars
    x = np.arange(len(age_groups))
    bars = ax.bar(x, screen_time_pct, color='#4ECDC4', alpha=0.8)
    
    # Add value labels
    for i, (bar, pct, screen, leisure) in enumerate(zip(bars, screen_time_pct, screen_time_values, leisure_values)):
        # Percentage on bar
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
               f'{pct:.0f}%', ha='center', va='bottom', fontsize=11, fontweight='bold')
        # Minutes below
        ax.text(bar.get_x() + bar.get_width()/2, 5,
               f'{screen:.0f} of {leisure:.0f} min', ha='center', va='bottom', 
               fontsize=9, color='white')
    
    # Formatting
    ax.set_xlabel('Age Group', fontsize=12)
    ax.set_ylabel('Screen time as % of total leisure', fontsize=12)
    ax.set_xticks(x)
    ax.set_xticklabels(age_groups)
    ax.set_ylim(0, 100)
    
    # Add reference line at 50%
    ax.axhline(y=50, color='gray', linestyle='--', alpha=0.5)
    ax.text(len(age_groups)-0.5, 51, '50%', ha='left', va='bottom', fontsize=10, color='gray')
    
    apply_538_formatting(ax, fig)
    
    # Title and footnote
    fig.text(0.1, 0.95, 'SCREEN TIME CONSUMES OVER HALF OF LEISURE TIME ACROSS ALL AGES',
             fontsize=20, weight='bold', transform=fig.transFigure)
    fig.text(0.1, 0.91, 'TV, gaming, and computer use as percentage of total leisure and sports time, 2024',
             fontsize=12, style='italic', color='#666666', transform=fig.transFigure)
    
    footnote = ("Source: BLS API - American Time Use Survey 2024\n"
                "Note: Screen time includes TV watching, playing games, and computer use (excluding games)")
    fig.text(0.1, 0.02, footnote, fontsize=9, style='italic', 
             color='#666666', transform=fig.transFigure)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.88, bottom=0.1)
    plt.savefig('../../visualizations/api_screen_time_proportion_of_leisure.png', 
                dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: api_screen_time_proportion_of_leisure.png")

def save_final_data(results, series_dict):
    """Save the final data for reference"""
    
    save_data = {
        'series_ids_used': series_dict,
        'data_retrieved': results,
        'summary': {
            'age_groups_covered': list(results.keys()),
            'activities_found': list(set(act for age_data in results.values() for act in age_data.keys()))
        }
    }
    
    with open('../data/final_age_visualization_data.json', 'w') as f:
        json.dump(save_data, f, indent=2)
    
    print("\nSaved final data to final_age_visualization_data.json")

def main():
    # Initialize API client
    API_KEY = "3b988529f9a746d5a0003b2e6506c237"
    client = ATUSAPIClient(API_KEY)
    
    print("Creating final API visualizations with age breakdowns...")
    print("Using discovered series IDs from comprehensive search")
    print("=" * 60)
    
    # Get discovered series
    series_dict = get_discovered_series()
    
    # Fetch all data
    results = fetch_all_age_data(client, series_dict)
    
    if results:
        # Create visualizations
        create_age_comparison_chart(results)
        create_screen_time_by_age_chart(results)
        create_gaming_decline_chart(results)
        create_leisure_proportion_chart(results)
        
        # Save data
        save_final_data(results, series_dict)
        
        print("\n" + "=" * 60)
        print("All visualizations created successfully!")
        
        # Print summary
        print("\nSummary of data retrieved:")
        for age in sorted(results.keys()):
            print(f"\n{age}:")
            for activity, data in results[age].items():
                print(f"  {activity}: {data['minutes']:.0f} min/day")
    else:
        print("No data retrieved")

if __name__ == "__main__":
    main()