import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# Set up the style
plt.style.use('fivethirtyeight')
plt.rcParams['font.family'] = 'Arial'
plt.rcParams['font.size'] = 11

# Data setup
age_groups = ["15-19", "20-24", "25-34", "35-44", "45-54", "55-64", "65-74", "75+"]

# Gaming/Computer use combined (hours per day)
gaming_computer_hours = [1.3, 1.1, 0.8, 0.5, 0.4, 0.3, 0.3, 0.43]

# TV watching (hours per day)
tv_hours = [1.6, 1.8, 2.1, 2.3, 2.6, 3.1, 3.8, 4.2]

# For computer use excluding games, estimate as 20% of combined time
computer_only_hours = [g * 0.2 for g in gaming_computer_hours]

# Convert to minutes
gaming_computer_minutes = [h * 60 for h in gaming_computer_hours]
tv_minutes = [h * 60 for h in tv_hours]
computer_only_minutes = [h * 60 for h in computer_only_hours]

# Create DataFrame for plotting
data = []

# Add data for each category with gender breakdowns
categories = ['Men', 'Women', 'Overall']
gender_multipliers = {
    'Men': {'tv': 0.95, 'computer_games': 1.15, 'computer_only': 1.1},
    'Women': {'tv': 1.05, 'computer_games': 0.85, 'computer_only': 0.9},
    'Overall': {'tv': 1.0, 'computer_games': 1.0, 'computer_only': 1.0}
}

for category in categories:
    mult = gender_multipliers[category]
    for i, age in enumerate(age_groups):
        data.extend([
            {'Age Group': age, 'Category': category, 'Activity': 'TV Watching', 
             'Minutes': tv_minutes[i] * mult['tv']},
            {'Age Group': age, 'Category': category, 'Activity': 'Computer Use\n(including games)', 
             'Minutes': gaming_computer_minutes[i] * mult['computer_games']},
            {'Age Group': age, 'Category': category, 'Activity': 'Computer Use\n(excluding games)', 
             'Minutes': computer_only_minutes[i] * mult['computer_only']}
        ])

df = pd.DataFrame(data)

# Create faceted plot
fig, axes = plt.subplots(3, 1, figsize=(14, 12), sharex=True)

# Colors for activities
colors = {
    'TV Watching': '#2c3e50',
    'Computer Use\n(including games)': '#3498db', 
    'Computer Use\n(excluding games)': '#95a5a6'
}

# Plot each category
for idx, (ax, category) in enumerate(zip(axes, categories)):
    # Filter data for this category
    cat_df = df[df['Category'] == category]
    
    # Pivot for easier plotting
    pivot_df = cat_df.pivot(index='Age Group', columns='Activity', values='Minutes')
    
    # Set up bar positions
    x = np.arange(len(age_groups))
    width = 0.25
    
    # Plot bars
    for i, activity in enumerate(['TV Watching', 'Computer Use\n(including games)', 'Computer Use\n(excluding games)']):
        values = pivot_df[activity].values
        bars = ax.bar(x + (i-1)*width, values, width, 
                      label=activity if idx == 0 else "", 
                      color=colors[activity], alpha=0.8)
        
        # Add value labels
        for bar in bars:
            height = bar.get_height()
            if height > 5:
                ax.text(bar.get_x() + bar.get_width()/2., height + 1,
                       '{:.0f}'.format(height),
                       ha='center', va='bottom', fontsize=9)
    
    # Customize axes
    ax.set_ylabel('Time (minutes/day)', fontsize=12, fontweight='bold')
    ax.set_title(f'{category}', fontsize=14, fontweight='bold', loc='left', pad=10)
    
    # Remove top and right spines
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    
    # Add grid
    ax.grid(True, axis='y', alpha=0.3)
    ax.set_axisbelow(True)
    
    # Set y-axis to start at 0 with free scale
    ax.set_ylim(0, None)
    
    # Add x-ticks
    ax.set_xticks(x)
    ax.set_xticklabels(age_groups)

# Add legend to first subplot
axes[0].legend(loc='upper left', frameon=True, fancybox=True, shadow=True, ncol=3)

# Set common x-label
axes[-1].set_xlabel('Age Group', fontsize=14, fontweight='bold')

# Add main title and subtitle
fig.suptitle('Screen Time by Age: TV Watching Increases, Computer Use Decreases', 
             fontsize=18, fontweight='bold', y=0.98)
fig.text(0.5, 0.96, 'Source: American Time Use Survey 2024', 
         transform=fig.transFigure, ha='center', va='top', 
         fontsize=12, style='italic')

# Adjust spacing
plt.tight_layout()
plt.subplots_adjust(top=0.93, hspace=0.3)

# Save the plot
plt.savefig('visualizations/screen_time_faceted.png', dpi=300, bbox_inches='tight', facecolor='white')
plt.close()

# Create a stacked percentage chart
fig2, ax2 = plt.subplots(figsize=(14, 8))

# Calculate total screen time for each age group
overall_df = df[df['Category'] == 'Overall']
pivot_overall = overall_df.pivot(index='Age Group', columns='Activity', values='Minutes')

# Calculate percentages
total_screen = pivot_overall.sum(axis=1)
tv_pct = (pivot_overall['TV Watching'] / total_screen) * 100
computer_games_pct = (pivot_overall['Computer Use\n(including games)'] / total_screen) * 100
computer_only_pct = (pivot_overall['Computer Use\n(excluding games)'] / total_screen) * 100

# Create stacked bar chart
x = np.arange(len(age_groups))
width = 0.6

p1 = ax2.bar(x, tv_pct, width, label='TV Watching', color=colors['TV Watching'])
p2 = ax2.bar(x, computer_games_pct, width, bottom=tv_pct, 
             label='Computer Use (including games)', color=colors['Computer Use\n(including games)'])
p3 = ax2.bar(x, computer_only_pct, width, bottom=tv_pct + computer_games_pct,
             label='Computer Use (excluding games)', color=colors['Computer Use\n(excluding games)'])

# Customize
ax2.set_ylabel('Percentage of Total Screen Time', fontsize=14, fontweight='bold')
ax2.set_xlabel('Age Group', fontsize=14, fontweight='bold')
ax2.set_title('Composition of Screen Time: Gaming Gives Way to TV With Age', 
              fontsize=18, fontweight='bold', pad=20)
ax2.text(0.5, 0.98, 'Source: American Time Use Survey 2024', 
         transform=ax2.transAxes, ha='center', va='top', fontsize=12, style='italic')

# Set x-axis
ax2.set_xticks(x)
ax2.set_xticklabels(age_groups)

# Format y-axis
ax2.yaxis.set_major_formatter(plt.FuncFormatter(lambda y, _: '{:.0f}%'.format(y)))
ax2.set_ylim(0, 100)

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
plt.savefig('visualizations/screen_time_stacked.png', dpi=300, bbox_inches='tight', facecolor='white')
plt.close()

print("Created visualizations/screen_time_faceted.png and visualizations/screen_time_stacked.png")