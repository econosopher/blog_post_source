#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Create comparison visualization showing population average (A01) vs participant average (A02).
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from atus_api_client import ATUSAPIClient
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd

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

def get_a01_and_a02_series():
    """Get both A01 (population) and A02 (participants) series IDs"""
    
    # Define age order
    age_order = ["15-24", "25-34", "35-44", "45-54", "55-64", "65+"]
    
    # Base series from our existing data - these are A01 (population average)
    a01_series = {
        "15-24": {
            "watching_tv": "TUU10101AA01014264",
            "playing_games": "TUU10101AA01021211",
            "computer_excl_games": "TUU10101AA01021432"
        },
        "25-34": {
            "watching_tv": "TUU10101AA01014280",
            "playing_games": "TUU10101AA01005928",
            "computer_excl_games": "TUU10101AA01006132"
        },
        "35-44": {
            "watching_tv": "TUU10101AA01014296",
            "playing_games": "TUU10101AA01005944",
            "computer_excl_games": "TUU10101AA01006148"
        },
        "45-54": {
            "watching_tv": "TUU10101AA01014297",
            "playing_games": "TUU10101AA01005945",
            "computer_excl_games": "TUU10101AA01006149"
        },
        "55-64": {
            "watching_tv": "TUU10101AA01014313",
            "playing_games": "TUU10101AA01005961",
            "computer_excl_games": "TUU10101AA01006165"
        },
        "65+": {
            "watching_tv": "TUU10101AA01014329",
            "playing_games": "TUU10101AA01005962",
            "computer_excl_games": "TUU10101AA01006166"
        }
    }
    
    # Convert A01 to A02 by replacing positions 9-11
    a02_series = {}
    for age, activities in a01_series.items():
        a02_series[age] = {}
        for activity, series_id in activities.items():
            # Replace A01 with A02 in the series ID
            a02_series[age][activity] = series_id.replace("AA01", "AA02")
    
    return a01_series, a02_series, age_order

def fetch_comparison_data(client, a01_series, a02_series):
    """Fetch both A01 and A02 data for comparison"""
    
    print("Fetching A01 (population average) and A02 (participant average) data...")
    print("=" * 60)
    
    # Flatten all series
    all_series = []
    series_mapping = {}
    
    # Add A01 series
    for age, activities in a01_series.items():
        for activity, series_id in activities.items():
            if series_id:
                all_series.append(series_id)
                series_mapping[series_id] = {
                    'age': age,
                    'activity': activity,
                    'type': 'A01'
                }
    
    # Add A02 series
    for age, activities in a02_series.items():
        for activity, series_id in activities.items():
            if series_id:
                all_series.append(series_id)
                series_mapping[series_id] = {
                    'age': age,
                    'activity': activity,
                    'type': 'A02'
                }
    
    # Fetch data
    results = {'A01': {}, 'A02': {}}
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
                    data_type = info.get('type')
                    
                    if data_type and age:
                        if age not in results[data_type]:
                            results[data_type][age] = {}
                        
                        results[data_type][age][activity] = {
                            'hours': row['value'],
                            'minutes': row['value'] * 60,
                            'series_id': series_id
                        }
                        
                        print(f"✓ {data_type} - {age} - {activity}: {row['value']:.2f} hrs ({row['value']*60:.0f} min)")
    
    return results

def create_participant_comparison_chart(results, age_order):
    """Create stacked chart comparing A01 vs A02 data"""
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8), sharey=True)
    
    for ax, data_type, title_suffix in [(ax1, 'A01', 'Population Average'), 
                                         (ax2, 'A02', 'Participants Only')]:
        # Prepare data
        age_groups = []
        tv_values = []
        gaming_values = []
        computer_values = []
        
        for age in age_order:
            if age in results[data_type]:
                age_data = results[data_type][age]
                if any(act in age_data for act in ['watching_tv', 'playing_games', 'computer_excl_games']):
                    age_groups.append(age)
                    tv = age_data.get('watching_tv', {}).get('minutes', 0)
                    gaming = age_data.get('playing_games', {}).get('minutes', 0)
                    computer = age_data.get('computer_excl_games', {}).get('minutes', 0)
                    tv_values.append(tv)
                    gaming_values.append(gaming)
                    computer_values.append(computer)
        
        if not age_groups:
            continue
        
        # Create stacked bars
        x = np.arange(len(age_groups))
        
        bars1 = ax.bar(x, tv_values, label='Watching TV', 
                        color='#FF6B6B', alpha=0.8)
        bars2 = ax.bar(x, gaming_values, bottom=tv_values,
                        label='Playing games', color='#4ECDC4', alpha=0.8)
        
        bottom2 = [tv + gaming for tv, gaming in zip(tv_values, gaming_values)]
        bars3 = ax.bar(x, computer_values, bottom=bottom2,
                        label='Computer use (excl. games)', color='#45B7D1', alpha=0.8)
        
        # Add value labels inside bars
        for i, (tv, gaming, computer) in enumerate(zip(tv_values, gaming_values, computer_values)):
            # TV value
            if tv > 10:
                ax.text(i, tv/2, f'{tv:.0f}', 
                       ha='center', va='center', fontsize=10, color='white', fontweight='bold')
            
            # Gaming value
            if gaming > 10:
                ax.text(i, tv + gaming/2, f'{gaming:.0f}', 
                       ha='center', va='center', fontsize=10, color='white', fontweight='bold')
            
            # Computer value
            if computer > 10:
                ax.text(i, tv + gaming + computer/2, f'{computer:.0f}', 
                       ha='center', va='center', fontsize=10, color='white', fontweight='bold')
        
        # Add total labels
        totals = [tv + gaming + comp for tv, gaming, comp in 
                  zip(tv_values, gaming_values, computer_values)]
        
        for i, total in enumerate(totals):
            if total > 0:
                ax.text(i, total + 5, f'{total:.0f} min', 
                       ha='center', va='bottom', fontsize=11, fontweight='bold')
        
        # Formatting
        ax.set_xticks(x)
        ax.set_xticklabels(age_groups)
        ax.set_xlabel('Age Group', fontsize=12)
        if ax == ax1:
            ax.set_ylabel('Minutes per day', fontsize=12)
        ax.set_title(title_suffix, fontsize=14, fontweight='bold', pad=10)
        
        apply_538_formatting(ax, fig)
    
    # Add legend to the right subplot
    ax2.legend(loc='upper right', fontsize=11)
    
    # Main title
    fig.text(0.5, 0.95, 'SCREEN TIME: EVERYONE VS. ONLY THOSE WHO PARTICIPATE',
             fontsize=20, weight='bold', ha='center', transform=fig.transFigure)
    fig.text(0.5, 0.91, 'Average daily minutes spent on screen activities by age group, 2024',
             fontsize=12, style='italic', color='#666666', ha='center', transform=fig.transFigure)
    fig.text(0.5, 0.87, 'Left: Average across entire population (includes non-participants) | Right: Average among participants only',
             fontsize=11, style='italic', color='#666666', ha='center', transform=fig.transFigure)
    
    # Footnote
    footnote_lines = [
        "Source: BLS API - American Time Use Survey 2024",
        "A01 = Population average (includes people who don't do the activity) | A02 = Participant average (only those who do the activity)",
        "Activity codes: Watching TV (120303), Playing games (120307), Computer use excl. games (120308)"
    ]
    footnote = "\n".join(footnote_lines)
    fig.text(0.5, 0.01, footnote, fontsize=9, style='italic', 
             color='#666666', ha='center', transform=fig.transFigure)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.82, bottom=0.12, wspace=0.05)
    plt.savefig('../../visualizations/api_screen_time_participant_comparison.png', 
                dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("\nCreated: api_screen_time_participant_comparison.png")

def create_multiplier_chart(results, age_order):
    """Create chart showing the multiplier effect between A01 and A02"""
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # Calculate multipliers
    age_groups = []
    tv_mult = []
    gaming_mult = []
    computer_mult = []
    
    for age in age_order:
        if age in results['A01'] and age in results['A02']:
            a01_data = results['A01'][age]
            a02_data = results['A02'][age]
            
            # Calculate multipliers (A02/A01) only if both values exist and A01 > 0
            tv_a01 = a01_data.get('watching_tv', {}).get('minutes', 0)
            tv_a02 = a02_data.get('watching_tv', {}).get('minutes', 0)
            gaming_a01 = a01_data.get('playing_games', {}).get('minutes', 0)
            gaming_a02 = a02_data.get('playing_games', {}).get('minutes', 0)
            computer_a01 = a01_data.get('computer_excl_games', {}).get('minutes', 0)
            computer_a02 = a02_data.get('computer_excl_games', {}).get('minutes', 0)
            
            if tv_a01 > 0 or gaming_a01 > 0 or computer_a01 > 0:
                age_groups.append(age)
                tv_mult.append(tv_a02 / tv_a01 if tv_a01 > 0 else 0)
                gaming_mult.append(gaming_a02 / gaming_a01 if gaming_a01 > 0 else 0)
                computer_mult.append(computer_a02 / computer_a01 if computer_a01 > 0 else 0)
    
    if not age_groups:
        print("No multiplier data to visualize")
        return
    
    # Create grouped bars
    x = np.arange(len(age_groups))
    width = 0.25
    
    bars1 = ax.bar(x - width, tv_mult, width, label='Watching TV', 
                    color='#FF6B6B', alpha=0.8)
    bars2 = ax.bar(x, gaming_mult, width, label='Playing games', 
                    color='#4ECDC4', alpha=0.8)
    bars3 = ax.bar(x + width, computer_mult, width, 
                    label='Computer use (excl. games)', color='#45B7D1', alpha=0.8)
    
    # Add value labels
    for bars in [bars1, bars2, bars3]:
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height + 0.05,
                       f'{height:.1f}x', ha='center', va='bottom', fontsize=10)
    
    # Add reference line at 1.0
    ax.axhline(y=1.0, color='gray', linestyle='--', alpha=0.5)
    ax.text(len(age_groups)-0.1, 1.05, '1.0x', ha='right', va='bottom', fontsize=10, color='gray')
    
    # Formatting
    ax.set_xlabel('Age Group', fontsize=12)
    ax.set_ylabel('Multiplier (Participant avg ÷ Population avg)', fontsize=12)
    ax.set_xticks(x)
    ax.set_xticklabels(age_groups)
    ax.legend(loc='upper right')
    ax.set_ylim(0, max(max(tv_mult), max(gaming_mult), max(computer_mult)) * 1.2)
    
    apply_538_formatting(ax, fig)
    
    # Title and footnote
    fig.text(0.1, 0.95, 'PARTICIPATION RATES VARY BY ACTIVITY AND AGE',
             fontsize=20, weight='bold', transform=fig.transFigure)
    fig.text(0.1, 0.91, 'How much more time participants spend vs. population average',
             fontsize=12, style='italic', color='#666666', transform=fig.transFigure)
    fig.text(0.1, 0.87, 'Higher multipliers indicate lower participation rates in that activity',
             fontsize=11, style='italic', color='#666666', transform=fig.transFigure)
    
    footnote = ("Source: BLS API - American Time Use Survey 2024\n"
                "A multiplier of 2.0x means participants spend twice as much time as the population average")
    fig.text(0.1, 0.02, footnote, fontsize=9, style='italic', 
             color='#666666', transform=fig.transFigure)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.83, bottom=0.1)
    plt.savefig('../../visualizations/api_participation_multiplier.png', 
                dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: api_participation_multiplier.png")

def main():
    # Initialize API client
    API_KEY = "3b988529f9a746d5a0003b2e6506c237"
    client = ATUSAPIClient(API_KEY)
    
    print("Creating participant comparison visualizations...")
    print("Comparing A01 (population average) vs A02 (participant average)")
    print("=" * 60)
    
    # Get series IDs
    a01_series, a02_series, age_order = get_a01_and_a02_series()
    
    # Fetch all data
    results = fetch_comparison_data(client, a01_series, a02_series)
    
    if results['A01'] and results['A02']:
        # Create visualizations
        create_participant_comparison_chart(results, age_order)
        create_multiplier_chart(results, age_order)
        
        print("\n" + "=" * 60)
        print("Participant comparison visualizations created successfully!")
        
        # Print summary
        print("\nKey insights:")
        for age in age_order:
            if age in results['A01'] and age in results['A02']:
                print(f"\n{age}:")
                for activity in ['watching_tv', 'playing_games', 'computer_excl_games']:
                    a01_val = results['A01'][age].get(activity, {}).get('minutes', 0)
                    a02_val = results['A02'][age].get(activity, {}).get('minutes', 0)
                    if a01_val > 0:
                        mult = a02_val / a01_val
                        participation = (a01_val / a02_val) * 100 if a02_val > 0 else 0
                        print(f"  {activity}: {a01_val:.0f} min (all) vs {a02_val:.0f} min (participants)")
                        print(f"    → {mult:.1f}x multiplier, ~{participation:.0f}% participation rate")
    else:
        print("No data retrieved")

if __name__ == "__main__":
    main()