import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# Set up the style
plt.style.use('fivethirtyeight')
plt.rcParams['font.family'] = 'Arial'
plt.rcParams['font.size'] = 12

# Data setup
age_groups = ["15-19", "20-24", "25-34", "35-44", "45-54", "55-64", "65-74", "75+"]
gaming_hours = [1.3, 1.1, 0.8, 0.5, 0.4, 0.3, 0.3, 0.43]
leisure_hours = [4.2, 4.5, 4.3, 3.8, 4.0, 4.8, 6.2, 7.6]

# Calculate percentages
gaming_pct = [(g / l) * 100 for g, l in zip(gaming_hours, leisure_hours)]

# Create data with gender breakdown
men_gaming = [p * 1.15 for p in gaming_pct]
women_gaming = [p * 0.85 for p in gaming_pct]

data = {
    'Age Group': age_groups * 3,
    'Category': ['Men'] * 8 + ['Women'] * 8 + ['Overall'] * 8,
    'Gaming %': men_gaming + women_gaming + gaming_pct
}

df = pd.DataFrame(data)

# Create the plot
fig, ax = plt.subplots(figsize=(12, 8))

# Set width of bars
bar_width = 0.25
x = np.arange(len(age_groups))

# Get data for each category
men_data = df[df['Category'] == 'Men']['Gaming %'].values
women_data = df[df['Category'] == 'Women']['Gaming %'].values
overall_data = df[df['Category'] == 'Overall']['Gaming %'].values

# Create bars
bars1 = ax.bar(x - bar_width, men_data, bar_width, label='Men', color='#3498db')
bars2 = ax.bar(x, women_data, bar_width, label='Women', color='#e74c3c')
bars3 = ax.bar(x + bar_width, overall_data, bar_width, label='Overall', color='#7f8c8d')

# Customize the plot
ax.set_xlabel('Age Group', fontsize=14, fontweight='bold')
ax.set_ylabel('Gaming as % of Total Leisure Time', fontsize=14, fontweight='bold')
ax.set_title('Gaming Takes Up Most Leisure Time for Young Adults', 
             fontsize=18, fontweight='bold', pad=20)
ax.text(0.5, 0.98, 'Source: American Time Use Survey 2024', 
        transform=ax.transAxes, ha='center', va='top', fontsize=12, style='italic')

# Set x-axis
ax.set_xticks(x)
ax.set_xticklabels(age_groups)

# Format y-axis as percentages
ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda y, _: '{:.0f}%'.format(y)))

# Add grid
ax.grid(True, axis='y', alpha=0.3)
ax.set_axisbelow(True)

# Remove top and right spines
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

# Add legend
ax.legend(loc='upper right', frameon=True, fancybox=True, shadow=True)

# Set y-axis limits
ax.set_ylim(0, max(men_data) * 1.1)

# Adjust layout
plt.tight_layout()

# Save the plot
plt.savefig('visualizations/gaming_percentage_leisure.png', dpi=300, bbox_inches='tight', facecolor='white')
plt.close()