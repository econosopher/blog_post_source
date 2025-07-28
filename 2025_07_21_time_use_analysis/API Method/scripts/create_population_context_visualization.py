#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Create visualization showing population averages with context about what they mean.
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

def load_existing_data():
    """Load the existing age visualization data"""
    with open('../data/final_age_visualization_data.json', 'r') as f:
        data = json.load(f)
    return data['data_retrieved']

def create_context_visualization(results):
    """Create visualization showing population averages with participation context"""
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))
    
    # Define age order
    age_order = ["15-24", "25-34", "35-44", "45-54", "55-64", "65+"]
    
    # Left panel: Stacked chart with leisure time reference
    age_groups = []
    tv_values = []
    gaming_values = []
    computer_values = []
    leisure_values = []
    
    for age in age_order:
        if age in results:
            age_data = results[age]
            if all(act in age_data for act in ['watching_tv', 'playing_games', 'computer_excl_games', 'total_leisure']):
                age_groups.append(age)
                tv = age_data.get('watching_tv', {}).get('minutes', 0)
                gaming = age_data.get('playing_games', {}).get('minutes', 0)
                computer = age_data.get('computer_excl_games', {}).get('minutes', 0)
                leisure = age_data.get('total_leisure', {}).get('minutes', 0)
                tv_values.append(tv)
                gaming_values.append(gaming)
                computer_values.append(computer)
                leisure_values.append(leisure)
    
    if age_groups:
        # Create stacked bars
        x = np.arange(len(age_groups))
        
        # First show screen time stacked
        bars1 = ax1.bar(x, tv_values, label='Watching TV', 
                        color='#FF6B6B', alpha=0.8)
        bars2 = ax1.bar(x, gaming_values, bottom=tv_values,
                        label='Playing games', color='#4ECDC4', alpha=0.8)
        
        bottom2 = [tv + gaming for tv, gaming in zip(tv_values, gaming_values)]
        bars3 = ax1.bar(x, computer_values, bottom=bottom2,
                        label='Computer use (excl. games)', color='#45B7D1', alpha=0.8)
        
        # Add leisure time outline
        for i, leisure in enumerate(leisure_values):
            ax1.plot([i-0.4, i-0.4, i+0.4, i+0.4], [0, leisure, leisure, 0], 
                    'k--', alpha=0.5, linewidth=2)
        
        # Add percentage labels
        for i, (tv, gaming, computer, leisure) in enumerate(zip(tv_values, gaming_values, computer_values, leisure_values)):
            total_screen = tv + gaming + computer
            if leisure > 0:
                screen_pct = (total_screen / leisure) * 100
                ax1.text(i, total_screen + 5, f'{total_screen:.0f} min\n({screen_pct:.0f}% of leisure)', 
                       ha='center', va='bottom', fontsize=10, fontweight='bold')
        
        # Formatting
        ax1.set_xticks(x)
        ax1.set_xticklabels(age_groups)
        ax1.set_xlabel('Age Group', fontsize=12)
        ax1.set_ylabel('Minutes per day', fontsize=12)
        ax1.set_title('Screen Time vs. Total Leisure Time', fontsize=14, fontweight='bold', pad=10)
        ax1.legend(loc='upper right')
        
        apply_538_formatting(ax1, fig)
        
        # Add custom legend entry for leisure outline
        ax1.plot([], [], 'k--', alpha=0.5, linewidth=2, label='Total leisure time')
        ax1.legend(loc='upper right')
    
    # Right panel: Context about population averages
    ax2.axis('off')
    
    # Add explanatory text
    context_text = """Understanding Population Averages (A01)

These numbers represent the average time spent across
EVERYONE in each age group, including people who
don't participate in the activity at all.

For example:
• If 50% of 15-24 year olds play games for 104 min/day
  → Population average = 52 min/day

• If 90% of people watch TV for 121 min/day
  → Population average = 109 min/day

Key Insights:

Gaming (15-24): 52 min/day population average
• Suggests ~50% participation rate
• Gamers likely play 1.5-2 hours when they do

Computer use: 9-17 min/day population average
• Suggests lower participation rates
• Users likely spend 30-60 min when they do

TV watching: 109-185 min/day population average
• High averages suggest high participation
• Most people watch TV daily"""
    
    ax2.text(0.1, 0.9, context_text, fontsize=12, verticalalignment='top',
             transform=ax2.transAxes, family='monospace')
    
    # Add note about missing A02 data
    note_text = """Note: The BLS API doesn't provide participant-only
averages (A02) for these specific demographic and
activity combinations, so we can only estimate
participation rates based on the population averages."""
    
    ax2.text(0.1, 0.15, note_text, fontsize=10, style='italic',
             color='#666666', verticalalignment='top',
             transform=ax2.transAxes, family='monospace')
    
    # Main title
    fig.text(0.5, 0.95, 'SCREEN TIME POPULATION AVERAGES INCLUDE NON-PARTICIPANTS',
             fontsize=20, weight='bold', ha='center', transform=fig.transFigure)
    fig.text(0.5, 0.91, 'Understanding what population averages mean for different activities',
             fontsize=12, style='italic', color='#666666', ha='center', transform=fig.transFigure)
    
    # Footnote
    footnote_lines = [
        "Source: BLS API - American Time Use Survey 2024",
        "Population averages (A01) include everyone in the age group, whether they participate or not",
        "Dashed lines show total leisure time available | Activity codes: TV (120303), Gaming (120307), Computer (120308)"
    ]
    footnote = "\n".join(footnote_lines)
    fig.text(0.5, 0.01, footnote, fontsize=9, style='italic', 
             color='#666666', ha='center', transform=fig.transFigure)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.88, bottom=0.08)
    plt.savefig('../../visualizations/api_population_average_context.png', 
                dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: api_population_average_context.png")

def create_implied_participation_chart(results):
    """Create chart showing implied participation rates based on typical usage patterns"""
    
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # Define age order
    age_order = ["15-24", "25-34", "35-44", "45-54", "55-64", "65+"]
    
    # Typical session durations (based on research and common patterns)
    typical_durations = {
        'watching_tv': 150,  # 2.5 hours typical TV session
        'playing_games': 120,  # 2 hours typical gaming session
        'computer_excl_games': 60  # 1 hour typical computer session
    }
    
    # Prepare data
    age_groups = []
    tv_participation = []
    gaming_participation = []
    computer_participation = []
    
    for age in age_order:
        if age in results:
            age_data = results[age]
            age_groups.append(age)
            
            # Calculate implied participation rates
            tv_avg = age_data.get('watching_tv', {}).get('minutes', 0)
            gaming_avg = age_data.get('playing_games', {}).get('minutes', 0)
            computer_avg = age_data.get('computer_excl_games', {}).get('minutes', 0)
            
            # Implied participation = population average / typical session duration * 100
            tv_part = min((tv_avg / typical_durations['watching_tv']) * 100, 100)
            gaming_part = min((gaming_avg / typical_durations['playing_games']) * 100, 100)
            computer_part = min((computer_avg / typical_durations['computer_excl_games']) * 100, 100)
            
            tv_participation.append(tv_part)
            gaming_participation.append(gaming_part)
            computer_participation.append(computer_part)
    
    if not age_groups:
        return
    
    # Create grouped bars
    x = np.arange(len(age_groups))
    width = 0.25
    
    bars1 = ax.bar(x - width, tv_participation, width, label='Watching TV', 
                    color='#FF6B6B', alpha=0.8)
    bars2 = ax.bar(x, gaming_participation, width, label='Playing games', 
                    color='#4ECDC4', alpha=0.8)
    bars3 = ax.bar(x + width, computer_participation, width, 
                    label='Computer use (excl. games)', color='#45B7D1', alpha=0.8)
    
    # Add value labels
    for bars in [bars1, bars2, bars3]:
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height + 1,
                       f'{height:.0f}%', ha='center', va='bottom', fontsize=9)
    
    # Formatting
    ax.set_xlabel('Age Group', fontsize=12)
    ax.set_ylabel('Estimated participation rate (%)', fontsize=12)
    ax.set_xticks(x)
    ax.set_xticklabels(age_groups)
    ax.legend(loc='upper right')
    ax.set_ylim(0, 110)
    
    # Add reference line at 50%
    ax.axhline(y=50, color='gray', linestyle='--', alpha=0.5)
    ax.text(len(age_groups)-0.1, 51, '50%', ha='right', va='bottom', fontsize=10, color='gray')
    
    apply_538_formatting(ax, fig)
    
    # Title and footnote
    fig.text(0.1, 0.95, 'IMPLIED PARTICIPATION RATES BY ACTIVITY AND AGE',
             fontsize=20, weight='bold', transform=fig.transFigure)
    fig.text(0.1, 0.91, 'Estimated percentage of population engaging in each activity',
             fontsize=12, style='italic', color='#666666', transform=fig.transFigure)
    fig.text(0.1, 0.87, 'Based on typical session durations: TV (2.5 hrs), Gaming (2 hrs), Computer (1 hr)',
             fontsize=11, style='italic', color='#666666', transform=fig.transFigure)
    
    footnote = ("Source: BLS API - American Time Use Survey 2024\n"
                "Note: These are estimates based on population averages and typical usage patterns")
    fig.text(0.1, 0.02, footnote, fontsize=9, style='italic', 
             color='#666666', transform=fig.transFigure)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.83, bottom=0.08)
    plt.savefig('../../visualizations/api_implied_participation_rates.png', 
                dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: api_implied_participation_rates.png")

def main():
    print("Creating population average context visualizations...")
    print("Since A02 data is not available, we'll provide context for A01 data")
    print("=" * 60)
    
    # Load existing data
    results = load_existing_data()
    
    if results:
        # Create visualizations
        create_context_visualization(results)
        create_implied_participation_chart(results)
        
        print("\n" + "=" * 60)
        print("Context visualizations created successfully!")
        
        # Print insights
        print("\nKey insights about population averages:")
        print("- Gaming shows low population averages, suggesting many don't game at all")
        print("- TV watching shows high averages, suggesting most people watch daily")
        print("- Computer use (excl. games) shows very low averages across all ages")
        print("\nThese population averages help us understand both participation")
        print("rates and time allocation across entire demographic groups.")
    else:
        print("No data found")

if __name__ == "__main__":
    main()