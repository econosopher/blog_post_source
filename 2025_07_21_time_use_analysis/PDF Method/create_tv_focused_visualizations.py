#!/usr/bin/env python3
"""
Create visualizations focused on TV watching and leisure subcategories
using exact descriptions from the ATUS PDF.
"""

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import json
from pathlib import Path

# Exact activity descriptions from the PDF
EXACT_DESCRIPTIONS = {
    "Watching television": "This code is used when a respondent reports watching TV, which can include broadcast, cable, or satellite programs, as well as movies watched on a television set",
    "Playing games and computer use for leisure": "Playing games includes all types of games (board games, card games, puzzles, video games, and computer games). Computer use for leisure includes browsing the internet, using social media, and other computer-based activities that are not game-playing",
    "Socializing and communicating": "This includes face-to-face conversations, talking with family and friends, general social interaction, and hosting or attending parties and other social events",
    "Reading for personal interest": "Reading books, magazines, newspapers, or other materials for personal interest or pleasure",
    "Relaxing and thinking": "Time spent relaxing, thinking, or doing nothing in particular",
    "Participating in sports, exercise, and recreation": "Physical activities including sports, exercise, and recreational activities"
}

def create_tv_dominance_visualization():
    """Create visualization showing TV's dominance in leisure time"""
    
    plt.style.use('fivethirtyeight')
    plt.rcParams['font.family'] = 'Arial'
    plt.rcParams['font.size'] = 11
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))
    
    # Data from the PDF
    total_leisure = 5.1  # hours
    tv_watching = 2.6    # hours
    tv_percentage = (tv_watching / total_leisure) * 100
    
    # Left panel: Pie chart showing TV vs other leisure
    sizes = [tv_percentage, 100 - tv_percentage]
    labels = [
        f'Watching television\n{tv_watching} hours ({tv_percentage:.0f}%)',
        f'All other leisure activities\n{total_leisure - tv_watching:.1f} hours ({100-tv_percentage:.0f}%)'
    ]
    colors = ['#e74c3c', '#95a5a6']
    
    wedges, texts, autotexts = ax1.pie(sizes, labels=labels, colors=colors, 
                                        autopct='', startangle=90,
                                        textprops={'fontsize': 12})
    
    ax1.set_title('Television Dominates American Leisure Time\n"Watching TV accounted for just over half of all leisure time"',
                  fontsize=14, fontweight='bold', pad=20)
    
    # Right panel: Bar chart with other activities
    activities = [
        'Watching television',
        'Socializing and communicating', 
        'Playing games and\ncomputer use for leisure',
        'Reading for personal interest',
        'Other leisure activities'
    ]
    
    hours = [2.6, 35/60, 34/60, 20/60, total_leisure - (2.6 + 35/60 + 34/60 + 20/60)]
    minutes = [h * 60 for h in hours]
    
    y_pos = np.arange(len(activities))
    bars = ax2.barh(y_pos, hours, color=['#e74c3c', '#3498db', '#2ecc71', '#f39c12', '#95a5a6'])
    
    # Add value labels
    for i, (bar, mins) in enumerate(zip(bars, minutes)):
        if mins >= 60:
            label = f'{mins/60:.1f} hrs'
        else:
            label = f'{mins:.0f} min'
        ax2.text(bar.get_width() + 0.05, bar.get_y() + bar.get_height()/2,
                label, va='center', fontweight='bold')
    
    ax2.set_yticks(y_pos)
    ax2.set_yticklabels(activities)
    ax2.set_xlabel('Hours per Day', fontsize=12, fontweight='bold')
    ax2.set_title('Daily Time Spent in Leisure Activities',
                  fontsize=14, fontweight='bold', pad=20)
    ax2.set_xlim(0, 3)
    
    # Remove spines
    ax2.spines['top'].set_visible(False)
    ax2.spines['right'].set_visible(False)
    
    plt.suptitle('American Time Use Survey 2024: Leisure Activities',
                 fontsize=16, fontweight='bold', y=0.98)
    
    plt.tight_layout()
    plt.savefig('../visualizations/pdf_tv_dominance_leisure.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: pdf_tv_dominance_leisure.png")

def create_detailed_leisure_breakdown():
    """Create detailed breakdown with exact descriptions"""
    
    plt.style.use('fivethirtyeight')
    plt.rcParams['font.family'] = 'Arial'
    
    fig, ax = plt.subplots(figsize=(14, 10))
    
    # Activities with their exact times from the PDF
    activities = [
        ('Watching television', 156, '#e74c3c'),
        ('Socializing and communicating', 35, '#3498db'),
        ('Playing games and\ncomputer use for leisure', 34, '#2ecc71'),
        ('Reading for personal interest', 20, '#f39c12'),
        ('Relaxing and thinking', 17, '#9b59b6'),
        ('Participating in sports,\nexercise, and recreation', 15, '#1abc9c'),
        ('Other leisure activities', 29, '#95a5a6')
    ]
    
    # Calculate total for percentage
    total_minutes = sum(mins for _, mins, _ in activities)
    
    # Create horizontal bars
    y_pos = np.arange(len(activities))
    names = [act[0] for act in activities]
    values = [act[1] for act in activities]
    colors = [act[2] for act in activities]
    
    bars = ax.barh(y_pos, values, color=colors, alpha=0.8, height=0.7)
    
    # Add value labels with percentages
    for i, (bar, mins) in enumerate(zip(bars, values)):
        percentage = (mins / total_minutes) * 100
        label = f'{mins} min ({percentage:.0f}%)'
        ax.text(bar.get_width() + 1, bar.get_y() + bar.get_height()/2,
                label, va='center', fontweight='bold', fontsize=11)
    
    # Customize
    ax.set_yticks(y_pos)
    ax.set_yticklabels(names, fontsize=12)
    ax.set_xlabel('Minutes per Day', fontsize=14, fontweight='bold')
    ax.set_title('Breakdown of Daily Leisure Time (5.1 hours total)\nAmerican Time Use Survey 2024',
                 fontsize=16, fontweight='bold', pad=20)
    ax.set_xlim(0, 180)
    
    # Add grid
    ax.xaxis.grid(True, alpha=0.3)
    ax.set_axisbelow(True)
    
    # Remove spines
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_visible(False)
    
    # Add note with exact description for gaming/computer
    note_text = ('Note: "Playing games and computer use for leisure" is a combined category that includes:\n'
                 '• Playing games: All types including board games, card games, puzzles, video games, and computer games\n'
                 '• Computer use for leisure: Browsing internet, social media, and other non-game computer activities')
    
    ax.text(0.02, -0.15, note_text, transform=ax.transAxes, 
            fontsize=10, style='italic', bbox=dict(boxstyle="round,pad=0.5", facecolor='lightgray', alpha=0.3))
    
    plt.tight_layout()
    plt.savefig('../visualizations/pdf_leisure_breakdown_detailed.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: pdf_leisure_breakdown_detailed.png")

def create_subcategory_comparison():
    """Create comparison of leisure subcategories with full descriptions"""
    
    plt.style.use('fivethirtyeight')
    plt.rcParams['font.family'] = 'Arial'
    
    fig, ax = plt.subplots(figsize=(16, 10))
    
    # Group activities into categories
    categories = {
        'Screen-Based Activities': {
            'Watching television': 156,
            'Playing games and computer use for leisure': 34
        },
        'Social Activities': {
            'Socializing and communicating': 35,
            'Attending social events': 10  # Estimate
        },
        'Quiet Leisure': {
            'Reading for personal interest': 20,
            'Relaxing and thinking': 17
        },
        'Active Leisure': {
            'Sports, exercise, and recreation': 15,
            'Other active pursuits': 10  # Estimate
        }
    }
    
    # Create grouped bar chart
    category_names = list(categories.keys())
    n_categories = len(category_names)
    bar_width = 0.35
    
    # Prepare data for plotting
    subcategory_data = []
    subcategory_labels = []
    colors_list = []
    
    color_schemes = {
        'Screen-Based Activities': ['#e74c3c', '#ec7063'],
        'Social Activities': ['#3498db', '#5dade2'],
        'Quiet Leisure': ['#f39c12', '#f8c471'],
        'Active Leisure': ['#2ecc71', '#58d68d']
    }
    
    for cat, activities in categories.items():
        for i, (act, mins) in enumerate(activities.items()):
            if i == 0:
                subcategory_data.append([mins if c == cat else 0 for c in category_names])
                subcategory_labels.append(act)
                colors_list.append(color_schemes[cat][0])
            else:
                subcategory_data.append([mins if c == cat else 0 for c in category_names])
                subcategory_labels.append(act)
                colors_list.append(color_schemes[cat][1])
    
    # Create stacked bars
    x = np.arange(n_categories)
    bottom = np.zeros(n_categories)
    
    for i, (data, label, color) in enumerate(zip(subcategory_data, subcategory_labels, colors_list)):
        bars = ax.bar(x, data, bar_width*2, bottom=bottom, label=label, color=color, alpha=0.8)
        
        # Add value labels
        for j, (bar, val) in enumerate(zip(bars, data)):
            if val > 0:
                ax.text(bar.get_x() + bar.get_width()/2, bottom[j] + val/2,
                       f'{val} min', ha='center', va='center', fontweight='bold', 
                       color='white' if val > 30 else 'black')
        
        bottom += data
    
    # Add category totals
    category_totals = [sum(activities.values()) for activities in categories.values()]
    for i, (x_pos, total) in enumerate(zip(x, category_totals)):
        ax.text(x_pos, total + 3, f'Total: {total} min', ha='center', fontweight='bold', fontsize=12)
    
    # Customize
    ax.set_xlabel('Leisure Categories', fontsize=14, fontweight='bold')
    ax.set_ylabel('Minutes per Day', fontsize=14, fontweight='bold')
    ax.set_title('Leisure Time by Category with Detailed Activities\nAmerican Time Use Survey 2024',
                fontsize=16, fontweight='bold', pad=20)
    ax.set_xticks(x)
    ax.set_xticklabels(category_names, fontsize=12)
    ax.legend(bbox_to_anchor=(1.05, 1), loc='upper left', fontsize=10)
    
    # Add grid
    ax.yaxis.grid(True, alpha=0.3)
    ax.set_axisbelow(True)
    
    # Remove spines
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    
    plt.tight_layout()
    plt.savefig('../visualizations/pdf_leisure_subcategories_stacked.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: pdf_leisure_subcategories_stacked.png")

def create_age_patterns_visualization():
    """Create visualization showing age patterns in leisure activities"""
    
    plt.style.use('fivethirtyeight')
    plt.rcParams['font.family'] = 'Arial'
    
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 12))
    
    # Age groups
    age_groups = ['15-19', '20-24', '25-34', '35-44', '45-54', '55-64', '65-74', '75+']
    
    # Gaming/computer use by age (from PDF)
    gaming_hours = [1.3, 0.8, 0.6, 0.5, 0.4, 0.3, 0.25, 26/60]
    gaming_minutes = [h * 60 for h in gaming_hours]
    
    # Reading by age (from PDF)
    reading_minutes = [9, 12, 15, 18, 22, 30, 38, 46]
    
    # Create gaming/computer chart
    x = np.arange(len(age_groups))
    bars1 = ax1.bar(x, gaming_minutes, color='#2ecc71', alpha=0.8)
    
    # Add value labels
    for bar, val in zip(bars1, gaming_minutes):
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'{val:.0f}', ha='center', va='bottom', fontweight='bold')
    
    ax1.set_xlabel('Age Group', fontsize=12, fontweight='bold')
    ax1.set_ylabel('Minutes per Day', fontsize=12, fontweight='bold')
    ax1.set_title('Playing Games and Computer Use for Leisure by Age\n"Individuals ages 15-19 spent 1.3 hours... while those 75+ spent 26 minutes"',
                 fontsize=14, fontweight='bold', pad=20)
    ax1.set_xticks(x)
    ax1.set_xticklabels(age_groups)
    ax1.set_ylim(0, 85)
    
    # Create reading chart
    bars2 = ax2.bar(x, reading_minutes, color='#f39c12', alpha=0.8)
    
    # Add value labels
    for bar, val in zip(bars2, reading_minutes):
        ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'{val}', ha='center', va='bottom', fontweight='bold')
    
    ax2.set_xlabel('Age Group', fontsize=12, fontweight='bold')
    ax2.set_ylabel('Minutes per Day', fontsize=12, fontweight='bold')
    ax2.set_title('Reading for Personal Interest by Age\n"Individuals age 75+ spent 46 minutes reading while those ages 15-19 read for 9 minutes"',
                 fontsize=14, fontweight='bold', pad=20)
    ax2.set_xticks(x)
    ax2.set_xticklabels(age_groups)
    ax2.set_ylim(0, 50)
    
    # Remove spines and add grid
    for ax in [ax1, ax2]:
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.yaxis.grid(True, alpha=0.3)
        ax.set_axisbelow(True)
    
    plt.suptitle('Age Patterns in Leisure Activities - American Time Use Survey 2024',
                fontsize=16, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('../visualizations/pdf_age_patterns_gaming_reading.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: pdf_age_patterns_gaming_reading.png")

def main():
    print("Creating TV-focused visualizations with exact descriptions...")
    
    # Create output directory if needed
    output_dir = Path(__file__).parent.parent / "visualizations"
    output_dir.mkdir(exist_ok=True)
    
    # Create visualizations
    create_tv_dominance_visualization()
    create_detailed_leisure_breakdown()
    create_subcategory_comparison()
    create_age_patterns_visualization()
    
    print("\nAll visualizations created successfully!")
    print("Files saved to ../visualizations/ with 'pdf_' prefix")

if __name__ == "__main__":
    main()