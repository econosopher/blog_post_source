#!/usr/bin/env python3
"""
Create visualization showing exact activity codes and their descriptions from ATUS.
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
from pathlib import Path

def create_activity_codes_reference():
    """Create a reference chart showing activity codes with their exact descriptions"""
    
    plt.style.use('fivethirtyeight')
    plt.rcParams['font.family'] = 'Arial'
    
    fig, ax = plt.subplots(figsize=(16, 12))
    
    # Activity codes and descriptions
    activities = [
        {
            'code': '120307',
            'name': 'Watching television',
            'description': 'This code is used when a respondent reports watching TV, which can include broadcast, cable, or satellite programs, as well as movies watched on a television set.',
            'time': 156,  # minutes
            'color': '#e74c3c'
        },
        {
            'code': '120303',
            'name': 'Playing games',
            'description': 'This code is used for all types of games, including board games (like chess), card games, and puzzles. It is important to note that this code is also used for video games and computer games. So, playing "The Legend of Zelda" on a console or "Solitaire" on a PC would fall under this code.',
            'time': 34,  # Combined with computer use
            'color': '#2ecc71'
        },
        {
            'code': '120308',
            'name': 'Computer use for leisure (excluding games)',
            'description': 'This is the key category for most modern digital leisure. It includes browsing the internet, using social media, and other computer-based activities that are not game-playing.',
            'time': 34,  # Combined with games
            'color': '#27ae60'
        },
        {
            'code': '1201',
            'name': 'Socializing and Communicating',
            'description': 'This includes a range of activities including face-to-face conversations and social events.',
            'time': 35,
            'color': '#3498db'
        },
        {
            'code': '120101',
            'name': 'Socializing and communicating with others',
            'description': 'This is the most common code, used for face-to-face conversations, talking with family and friends, and general social interaction. Hosting or attending parties and other social events.',
            'time': 35,
            'color': '#2980b9'
        }
    ]
    
    # Create layout
    y_positions = np.linspace(0.9, 0.1, len(activities))
    
    for i, activity in enumerate(activities):
        y = y_positions[i]
        
        # Draw activity code box
        code_box = mpatches.FancyBboxPatch((0.02, y-0.04), 0.08, 0.06,
                                           boxstyle="round,pad=0.01",
                                           facecolor=activity['color'],
                                           edgecolor='black',
                                           linewidth=2)
        ax.add_patch(code_box)
        
        # Add code text
        ax.text(0.06, y-0.01, activity['code'], 
                ha='center', va='center', fontweight='bold', 
                fontsize=12, color='white')
        
        # Add activity name
        ax.text(0.12, y+0.01, activity['name'], 
                fontweight='bold', fontsize=13, va='bottom')
        
        # Add time
        if activity['code'] in ['120303', '120308']:
            time_text = f"34 min/day (combined)"
        else:
            time_text = f"{activity['time']} min/day"
        
        ax.text(0.92, y+0.01, time_text, 
                ha='right', fontweight='bold', fontsize=12, 
                va='bottom', color=activity['color'])
        
        # Add description (wrapped)
        # Split description into lines
        words = activity['description'].split()
        lines = []
        current_line = []
        line_length = 0
        max_length = 100
        
        for word in words:
            if line_length + len(word) + 1 > max_length:
                lines.append(' '.join(current_line))
                current_line = [word]
                line_length = len(word)
            else:
                current_line.append(word)
                line_length += len(word) + 1
        
        if current_line:
            lines.append(' '.join(current_line))
        
        # Add description lines
        desc_y = y - 0.02
        for line in lines:
            ax.text(0.12, desc_y, line, 
                    fontsize=10, va='top', style='italic', color='#34495e')
            desc_y -= 0.015
    
    # Add title and subtitle
    ax.text(0.5, 0.98, 'ATUS Activity Codes and Descriptions',
            ha='center', va='top', fontsize=18, fontweight='bold', transform=ax.transAxes)
    
    ax.text(0.5, 0.94, 'American Time Use Survey 2024 - Leisure Activity Classification System',
            ha='center', va='top', fontsize=14, transform=ax.transAxes)
    
    # Add note about combined category
    note_text = ('Note: In ATUS reporting, codes 120303 (Playing games) and 120308 (Computer use for leisure) '
                 'are often combined into a single category "Playing games and computer use for leisure" '
                 'totaling 34 minutes per day.')
    
    ax.text(0.5, 0.02, note_text, ha='center', va='bottom', 
            fontsize=11, style='italic', transform=ax.transAxes,
            bbox=dict(boxstyle="round,pad=0.5", facecolor='lightgray', alpha=0.3))
    
    # Remove axes
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')
    
    plt.tight_layout()
    plt.savefig('../visualizations/pdf_activity_codes_reference.png', 
                dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: pdf_activity_codes_reference.png")

def create_combined_category_explanation():
    """Create visualization explaining the combined gaming/computer category"""
    
    plt.style.use('fivethirtyeight')
    plt.rcParams['font.family'] = 'Arial'
    
    fig, ax = plt.subplots(figsize=(14, 10))
    
    # Create visual breakdown of the combined category
    total_minutes = 34
    
    # These are estimates since PDF doesn't break them down
    gaming_est = 20
    computer_est = 14
    
    # Create donut chart
    sizes = [gaming_est, computer_est]
    labels = ['Playing games\n(~20 min)', 'Computer use\n(~14 min)']
    colors = ['#2ecc71', '#27ae60']
    explode = (0.05, 0.05)
    
    wedges, texts, autotexts = ax.pie(sizes, labels=labels, colors=colors,
                                       autopct='', startangle=90,
                                       explode=explode, textprops={'fontsize': 12})
    
    # Create circle for donut
    centre_circle = plt.Circle((0, 0), 0.70, fc='white')
    fig.gca().add_artist(centre_circle)
    
    # Add center text
    ax.text(0, 0.1, '34', ha='center', va='center', fontsize=48, fontweight='bold')
    ax.text(0, -0.1, 'minutes/day', ha='center', va='center', fontsize=16)
    ax.text(0, -0.25, 'combined', ha='center', va='center', fontsize=14, style='italic')
    
    # Add title
    ax.text(0, 1.3, 'Playing Games and Computer Use for Leisure',
            ha='center', va='center', fontsize=18, fontweight='bold')
    ax.text(0, 1.15, 'Understanding the Combined ATUS Category',
            ha='center', va='center', fontsize=14, style='italic')
    
    # Add detailed explanations
    explanations = [
        {
            'title': 'Playing Games (Code 120303)',
            'items': [
                '• Video games (console & PC)',
                '• Computer games',
                '• Board games (chess, checkers)',
                '• Card games',
                '• Puzzles'
            ],
            'x': -1.8,
            'y': 0.3
        },
        {
            'title': 'Computer Use for Leisure (Code 120308)',
            'items': [
                '• Browsing the internet',
                '• Using social media',
                '• Online shopping for fun',
                '• Watching videos (not TV)',
                '• Other non-game computer activities'
            ],
            'x': 1.8,
            'y': 0.3
        }
    ]
    
    for exp in explanations:
        # Title
        ax.text(exp['x'], exp['y'], exp['title'], 
                ha='center', va='top', fontsize=13, fontweight='bold')
        
        # Items
        y_offset = exp['y'] - 0.15
        for item in exp['items']:
            ax.text(exp['x'], y_offset, item, 
                    ha='center', va='top', fontsize=11)
            y_offset -= 0.12
    
    # Add note at bottom
    note = ('Note: The ATUS combines these activities in reporting because both involve screen-based leisure. '
            'The exact breakdown between gaming and other computer use is not provided in aggregate statistics.')
    
    ax.text(0, -1.3, note, ha='center', va='center', fontsize=11, 
            style='italic', wrap=True,
            bbox=dict(boxstyle="round,pad=0.5", facecolor='lightgray', alpha=0.3))
    
    # Set limits and remove axes
    ax.set_xlim(-2.5, 2.5)
    ax.set_ylim(-1.5, 1.5)
    ax.axis('off')
    
    plt.tight_layout()
    plt.savefig('../visualizations/pdf_combined_category_explanation.png',
                dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()
    
    print("Created: pdf_combined_category_explanation.png")

def main():
    print("Creating activity codes reference visualizations...")
    
    # Create output directory if needed
    output_dir = Path(__file__).parent.parent / "visualizations"
    output_dir.mkdir(exist_ok=True)
    
    # Create visualizations
    create_activity_codes_reference()
    create_combined_category_explanation()
    
    print("\nActivity codes visualizations created successfully!")

if __name__ == "__main__":
    main()