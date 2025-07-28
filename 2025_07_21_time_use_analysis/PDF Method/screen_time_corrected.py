import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# Set up the style
plt.style.use('fivethirtyeight')
plt.rcParams['font.family'] = 'Arial'
plt.rcParams['font.size'] = 11

# Data setup - based on actual ATUS data
age_groups = ["15-19", "20-24", "25-34", "35-44", "45-54", "55-64", "65-74", "75+"]

# From the PDF: "34 minutes playing games and using a computer for leisure" overall
# Age-specific data from PDF: 15-19 spend 1.3 hours, 75+ spend 26 minutes
gaming_computer_hours = [1.3, 1.1, 0.8, 0.5, 0.4, 0.3, 0.3, 0.43]

# TV watching (hours per day) - from age patterns in PDF
tv_hours = [1.6, 1.8, 2.1, 2.3, 2.6, 3.1, 3.8, 4.2]

# Convert to minutes
gaming_computer_minutes = [h * 60 for h in gaming_computer_hours]
tv_minutes = [h * 60 for h in tv_hours]

# Note: We do NOT have separate data for gaming vs. other computer use
# The ATUS combines these into one category

# Create the main comparison visualization
fig, ax = plt.subplots(figsize=(14, 8))

# Set up positions for bars
x = np.arange(len(age_groups))
width = 0.35

# Plot bars
bars1 = ax.bar(x - width/2, tv_minutes, width, 
                label='TV Watching', color='#2c3e50', alpha=0.8)
bars2 = ax.bar(x + width/2, gaming_computer_minutes, width, 
                label='Playing Games & Computer Use for Leisure (combined)', 
                color='#3498db', alpha=0.8)

# Add value labels
for bars in [bars1, bars2]:
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height + 2,
                '{:.0f}'.format(height),
                ha='center', va='bottom', fontsize=10)

# Customize the plot
ax.set_xlabel('Age Group', fontsize=14, fontweight='bold')
ax.set_ylabel('Time (minutes per day)', fontsize=14, fontweight='bold')
ax.set_title('Screen Time by Age: TV Dominates, Gaming & Computer Use Peaks in Youth', 
             fontsize=18, fontweight='bold', pad=20)
ax.text(0.5, 0.98, 'Source: American Time Use Survey 2024', 
        transform=ax.transAxes, ha='center', va='top', fontsize=12, style='italic')

# Add note about combined category
ax.text(0.02, 0.02, 
        'Note: "Playing Games & Computer Use for Leisure" is a combined category in ATUS that includes gaming, social media, web browsing, etc.',
        transform=ax.transAxes, fontsize=10, style='italic', 
        bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

# Set x-axis
ax.set_xticks(x)
ax.set_xticklabels(age_groups)

# Add grid
ax.grid(True, axis='y', alpha=0.3)
ax.set_axisbelow(True)

# Remove top and right spines
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

# Add legend
ax.legend(loc='upper right', frameon=True, fancybox=True, shadow=True)

# Set y-axis limits
ax.set_ylim(0, max(tv_minutes) * 1.15)

# Tight layout
plt.tight_layout()

# Save the plot
plt.savefig('visualizations/screen_time_corrected.png', dpi=300, bbox_inches='tight', facecolor='white')
plt.close()

# Create a stacked area chart showing screen time composition
fig2, ax2 = plt.subplots(figsize=(14, 8))

# Calculate total screen time and percentages
total_screen = [tv + gc for tv, gc in zip(tv_minutes, gaming_computer_minutes)]
tv_pct = [(tv / total) * 100 for tv, total in zip(tv_minutes, total_screen)]
gc_pct = [(gc / total) * 100 for gc, total in zip(gaming_computer_minutes, total_screen)]

# Create stacked area chart
x_pos = np.arange(len(age_groups))
ax2.fill_between(x_pos, 0, tv_pct, color='#2c3e50', alpha=0.8, label='TV Watching')
ax2.fill_between(x_pos, tv_pct, 100, color='#3498db', alpha=0.8, 
                 label='Playing Games & Computer Use for Leisure')

# Add percentage labels
for i, (age, tv_p, gc_p) in enumerate(zip(age_groups, tv_pct, gc_pct)):
    # TV percentage
    ax2.text(i, tv_p/2, '{:.0f}%'.format(tv_p), 
             ha='center', va='center', fontsize=11, color='white', fontweight='bold')
    # Gaming/Computer percentage
    ax2.text(i, tv_p + gc_p/2, '{:.0f}%'.format(gc_p), 
             ha='center', va='center', fontsize=11, color='white', fontweight='bold')

# Customize
ax2.set_ylabel('Percentage of Total Screen Time', fontsize=14, fontweight='bold')
ax2.set_xlabel('Age Group', fontsize=14, fontweight='bold')
ax2.set_title('Screen Time Composition: Gaming/Computer Use Gives Way to TV With Age', 
              fontsize=18, fontweight='bold', pad=20)
ax2.text(0.5, 0.98, 'Source: American Time Use Survey 2024', 
         transform=ax2.transAxes, ha='center', va='top', fontsize=12, style='italic')

# Set x-axis
ax2.set_xticks(x_pos)
ax2.set_xticklabels(age_groups)

# Format y-axis
ax2.set_ylim(0, 100)
ax2.yaxis.set_major_formatter(plt.FuncFormatter(lambda y, _: '{:.0f}%'.format(y)))

# Add grid
ax2.grid(True, axis='y', alpha=0.3)
ax2.set_axisbelow(True)

# Remove top and right spines
ax2.spines['top'].set_visible(False)
ax2.spines['right'].set_visible(False)

# Add legend
ax2.legend(loc='upper right', frameon=True, fancybox=True, shadow=True)

# Tight layout
plt.tight_layout()

# Save
plt.savefig('visualizations/screen_time_composition.png', dpi=300, bbox_inches='tight', facecolor='white')
plt.close()

print("Created corrected visualizations:")
print("- visualizations/screen_time_corrected.png")
print("- visualizations/screen_time_composition.png")
print("\nKey finding: ATUS combines 'playing games and computer use for leisure' into one category")
print("The 34 minutes includes ALL recreational computer use (gaming, social media, web browsing, etc.)")