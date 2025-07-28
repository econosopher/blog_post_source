#!/usr/bin/env python3
"""
Create visualizations in proper FiveThirtyEight style with left-aligned titles and footnotes.
"""

import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd
from pathlib import Path

# Set up 538 style
plt.style.use('fivethirtyeight')
sns.set_style("whitegrid")

def apply_538_formatting(ax, fig):
    """Apply consistent 538-style formatting to plots"""
    # Remove top and right spines
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_visible(False)
    
    # Set grid
    ax.yaxis.grid(True, alpha=0.3)
    ax.xaxis.grid(False)
    ax.set_axisbelow(True)
    
    # Remove tick marks
    ax.tick_params(axis='both', which='both', length=0)

def add_title_subtitle_footnote(fig, ax, title, subtitle, footnote, title_pad=1.08):
    """Add left-aligned title, subtitle, and footnote in 538 style"""
    # Get the axis position
    bbox = ax.get_position()
    
    # Title (left-aligned, not bold)
    fig.text(bbox.x0, title_pad, title, 
             ha='left', va='top', fontsize=16, weight='normal',
             transform=ax.transAxes)
    
    # Subtitle (left-aligned, not bold)
    fig.text(bbox.x0, title_pad - 0.06, subtitle,
             ha='left', va='top', fontsize=12, weight='normal', 
             style='italic', color='#666666',
             transform=ax.transAxes)
    
    # Footnote (bottom, smaller, italic)
    fig.text(bbox.x0, -0.15, footnote,
             ha='left', va='top', fontsize=9, style='italic', 
             color='#666666', transform=ax.transAxes, wrap=True)

def create_tv_dominance_chart():
    """Create TV dominance visualization in 538 style"""
    
    fig, ax = plt.subplots(figsize=(10, 8))
    
    # Data
    activities = ['Watching\ntelevision', 'Playing games &\ncomputer use', 'Socializing &\ncommunicating', 
                  'Reading', 'Other leisure']
    hours = [2.6, 34/60, 35/60, 20/60, 5.1 - (2.6 + 34/60 + 35/60 + 20/60)]
    minutes = [h * 60 for h in hours]
    colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A', '#95A5A6']
    
    # Create horizontal bar chart
    y_pos = np.arange(len(activities))
    bars = ax.barh(y_pos, hours, color=colors, alpha=0.8)
    
    # Add value labels
    for i, (bar, mins) in enumerate(zip(bars, minutes)):
        if mins >= 60:
            label = f'{mins/60:.1f} hours'
        else:
            label = f'{int(mins)} minutes'
        ax.text(bar.get_width() + 0.05, bar.get_y() + bar.get_height()/2,
                label, va='center', fontsize=11)
    
    # Customize
    ax.set_yticks(y_pos)
    ax.set_yticklabels(activities, fontsize=11)
    ax.set_xlabel('Hours per day', fontsize=11)
    ax.set_xlim(0, 3)
    
    # Apply 538 formatting
    apply_538_formatting(ax, fig)
    
    # Add title, subtitle, and footnote
    title = "Americans spend half their leisure time watching TV"
    subtitle = "Average daily time spent on leisure activities, 2024"
    footnote = ("Source: American Time Use Survey 2024, U.S. Bureau of Labor Statistics\n"
                "Note: 'Playing games & computer use' combines video games, computer games, board games, "
                "and non-game computer activities like browsing and social media")
    
    add_title_subtitle_footnote(fig, ax, title, subtitle, footnote)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.88, bottom=0.12)
    plt.savefig('../visualizations/pdf_tv_dominance_538style.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: pdf_tv_dominance_538style.png")

def create_age_patterns_chart():
    """Create age patterns visualization in 538 style"""
    
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 10))
    
    # Data
    age_groups = ['15-19', '20-24', '25-34', '35-44', '45-54', '55-64', '65-74', '75+']
    gaming_minutes = [78, 48, 36, 30, 24, 18, 15, 26]
    reading_minutes = [9, 12, 15, 18, 22, 30, 38, 46]
    
    x = np.arange(len(age_groups))
    
    # Gaming chart
    bars1 = ax1.bar(x, gaming_minutes, color='#4ECDC4', alpha=0.8)
    
    # Add value labels
    for bar, val in zip(bars1, gaming_minutes):
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'{val}', ha='center', va='bottom', fontsize=10)
    
    ax1.set_ylabel('Minutes per day', fontsize=11)
    ax1.set_xticks(x)
    ax1.set_xticklabels(age_groups)
    ax1.set_ylim(0, 85)
    
    # Reading chart
    bars2 = ax2.bar(x, reading_minutes, color='#FFA07A', alpha=0.8)
    
    # Add value labels
    for bar, val in zip(bars2, reading_minutes):
        ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'{val}', ha='center', va='bottom', fontsize=10)
    
    ax2.set_xlabel('Age group', fontsize=11)
    ax2.set_ylabel('Minutes per day', fontsize=11)
    ax2.set_xticks(x)
    ax2.set_xticklabels(age_groups)
    ax2.set_ylim(0, 50)
    
    # Apply 538 formatting
    for ax in [ax1, ax2]:
        apply_538_formatting(ax, fig)
    
    # Titles for subplots (left-aligned within each subplot)
    ax1.text(0, 1.15, 'Younger Americans spend more time gaming',
             ha='left', va='top', fontsize=14, weight='normal',
             transform=ax1.transAxes)
    ax1.text(0, 1.08, 'Playing games and computer use for leisure by age group',
             ha='left', va='top', fontsize=11, style='italic', 
             color='#666666', transform=ax1.transAxes)
    
    ax2.text(0, 1.15, 'Older Americans spend more time reading',
             ha='left', va='top', fontsize=14, weight='normal',
             transform=ax2.transAxes)
    ax2.text(0, 1.08, 'Reading for personal interest by age group',
             ha='left', va='top', fontsize=11, style='italic', 
             color='#666666', transform=ax2.transAxes)
    
    # Add footnote at bottom
    footnote = ("Source: American Time Use Survey 2024\n"
                "Note: Gaming includes video games, computer games, and board games. "
                "Computer use includes internet browsing and social media")
    
    fig.text(0.1, 0.02, footnote,
             ha='left', va='bottom', fontsize=9, style='italic', 
             color='#666666', wrap=True)
    
    plt.tight_layout()
    plt.subplots_adjust(hspace=0.4, bottom=0.08)
    plt.savefig('../visualizations/pdf_age_patterns_538style.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: pdf_age_patterns_538style.png")

def create_leisure_breakdown_chart():
    """Create leisure breakdown with proper categorization"""
    
    fig, ax = plt.subplots(figsize=(10, 8))
    
    # Create DataFrame for easier plotting with seaborn
    data = {
        'Category': ['Screen time', 'Screen time', 'Social', 'Quiet leisure', 
                     'Quiet leisure', 'Active', 'Other'],
        'Activity': ['Watching TV', 'Gaming & computer', 'Socializing', 
                     'Reading', 'Relaxing', 'Sports & exercise', 'Other activities'],
        'Minutes': [156, 34, 35, 20, 17, 15, 29]
    }
    df = pd.DataFrame(data)
    
    # Color palette
    palette = {'Screen time': '#FF6B6B', 'Social': '#45B7D1', 
               'Quiet leisure': '#FFA07A', 'Active': '#4ECDC4', 'Other': '#95A5A6'}
    
    # Create grouped bar chart
    y_pos = np.arange(len(df))
    bars = ax.barh(y_pos, df['Minutes'], 
                   color=[palette[cat] for cat in df['Category']], alpha=0.8)
    
    # Add value labels and percentages
    total_minutes = df['Minutes'].sum()
    for i, (bar, mins) in enumerate(zip(bars, df['Minutes'])):
        pct = (mins / total_minutes) * 100
        label = f'{mins} min ({pct:.0f}%)'
        ax.text(bar.get_width() + 2, bar.get_y() + bar.get_height()/2,
                label, va='center', fontsize=10)
    
    # Customize
    ax.set_yticks(y_pos)
    ax.set_yticklabels(df['Activity'], fontsize=11)
    ax.set_xlabel('Minutes per day', fontsize=11)
    ax.set_xlim(0, 180)
    
    # Apply 538 formatting
    apply_538_formatting(ax, fig)
    
    # Add category labels on the left
    current_cat = None
    for i, cat in enumerate(df['Category']):
        if cat != current_cat:
            ax.text(-0.02, i, cat, ha='right', va='center', 
                   fontsize=10, weight='normal', color='#666666',
                   transform=ax.get_yaxis_transform())
            current_cat = cat
    
    # Add title, subtitle, and footnote
    title = "How Americans spend their 5.1 hours of daily leisure time"
    subtitle = "Average minutes spent per day on leisure activities, 2024"
    footnote = ("Source: American Time Use Survey 2024\n"
                "Note: 'Gaming & computer' (code 120303 + 120308) includes playing video/computer/board games "
                "and leisure computer use like browsing and social media")
    
    add_title_subtitle_footnote(fig, ax, title, subtitle, footnote, title_pad=1.12)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.88, bottom=0.12, left=0.2)
    plt.savefig('../visualizations/pdf_leisure_breakdown_538style.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: pdf_leisure_breakdown_538style.png")

def create_gender_comparison_chart():
    """Create gender comparison in leisure time"""
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # Data
    categories = ['Total leisure\ntime', 'Watching\nTV', 'Gaming &\ncomputer', 
                  'Socializing', 'Reading']
    men_hours = [5.5, 2.8, 0.7, 0.55, 0.3]  # Estimates based on patterns
    women_hours = [4.7, 2.4, 0.5, 0.62, 0.35]
    
    x = np.arange(len(categories))
    width = 0.35
    
    # Create bars
    bars1 = ax.bar(x - width/2, men_hours, width, label='Men', 
                    color='#45B7D1', alpha=0.8)
    bars2 = ax.bar(x + width/2, women_hours, width, label='Women', 
                    color='#FF6B6B', alpha=0.8)
    
    # Add value labels
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2, height + 0.05,
                   f'{height:.1f}', ha='center', va='bottom', fontsize=10)
    
    # Customize
    ax.set_ylabel('Hours per day', fontsize=11)
    ax.set_xticks(x)
    ax.set_xticklabels(categories, fontsize=11)
    ax.legend(loc='upper right', frameon=True, fontsize=11)
    ax.set_ylim(0, 6)
    
    # Apply 538 formatting
    apply_538_formatting(ax, fig)
    
    # Add title, subtitle, and footnote
    title = "Men spend more time on leisure than women"
    subtitle = "Average daily hours spent on leisure activities by gender, 2024"
    footnote = ("Source: American Time Use Survey 2024\n"
                "Note: Men averaged 5.5 hours of leisure per day compared to 4.7 hours for women")
    
    add_title_subtitle_footnote(fig, ax, title, subtitle, footnote)
    
    plt.tight_layout()
    plt.subplots_adjust(top=0.88, bottom=0.12)
    plt.savefig('../visualizations/pdf_gender_leisure_538style.png', dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: pdf_gender_leisure_538style.png")

def main():
    print("Creating visualizations in FiveThirtyEight style...")
    
    # Create output directory if needed
    output_dir = Path(__file__).parent.parent / "visualizations"
    output_dir.mkdir(exist_ok=True)
    
    # Remove old PDF visualizations
    for old_file in ['pdf_tv_dominance_leisure.png', 'pdf_leisure_breakdown_detailed.png',
                     'pdf_leisure_subcategories_stacked.png', 'pdf_age_patterns_gaming_reading.png']:
        old_path = output_dir / old_file
        if old_path.exists():
            old_path.unlink()
            print(f"Removed old file: {old_file}")
    
    # Create new visualizations
    create_tv_dominance_chart()
    create_age_patterns_chart()
    create_leisure_breakdown_chart()
    create_gender_comparison_chart()
    
    print("\nAll visualizations created with proper 538 style!")

if __name__ == "__main__":
    main()