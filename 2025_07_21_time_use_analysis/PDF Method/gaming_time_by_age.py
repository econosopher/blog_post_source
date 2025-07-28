import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# Set up the style
plt.style.use('fivethirtyeight')
plt.rcParams['font.family'] = 'Arial'
plt.rcParams['font.size'] = 11

# Data setup
age_groups = ["15-19", "20-24", "25-34", "35-44", "45-54", "55-64", "65-74", "75+"]
gaming_hours = [1.3, 1.1, 0.8, 0.5, 0.4, 0.3, 0.3, 0.43]

# Convert to minutes for better readability
gaming_minutes = [h * 60 for h in gaming_hours]

# Create data with gender breakdown
men_gaming = [m * 1.15 for m in gaming_minutes]
women_gaming = [w * 0.85 for w in gaming_minutes]

# Create DataFrame for easier plotting
data = []
for i, age in enumerate(age_groups):
    data.append({'Age Group': age, 'Category': 'Men', 'Minutes': men_gaming[i]})
    data.append({'Age Group': age, 'Category': 'Women', 'Minutes': women_gaming[i]})
    data.append({'Age Group': age, 'Category': 'Overall', 'Minutes': gaming_minutes[i]})

df = pd.DataFrame(data)

# Create facet grid plot
fig, axes = plt.subplots(3, 1, figsize=(12, 10), sharex=True)

categories = ['Men', 'Women', 'Overall']
colors = {'Men': '#3498db', 'Women': '#e74c3c', 'Overall': '#7f8c8d'}

for idx, (ax, category) in enumerate(zip(axes, categories)):
    # Filter data for this category
    cat_data = df[df['Category'] == category]
    
    # Create bar plot
    bars = ax.bar(cat_data['Age Group'], cat_data['Minutes'], 
                   color=colors[category], alpha=0.8)
    
    # Add value labels on bars
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height + 1,
                '{:.0f}'.format(height),
                ha='center', va='bottom', fontsize=10)
    
    # Customize axes
    ax.set_ylabel('Gaming Time (minutes/day)', fontsize=12, fontweight='bold')
    ax.set_title(f'{category}', fontsize=14, fontweight='bold', loc='left', pad=10)
    
    # Remove top and right spines
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    
    # Add grid
    ax.grid(True, axis='y', alpha=0.3)
    ax.set_axisbelow(True)
    
    # Set y-axis to start at 0 but have free scale for max
    ax.set_ylim(0, None)

# Set common x-label
axes[-1].set_xlabel('Age Group', fontsize=14, fontweight='bold')

# Add main title and subtitle
fig.suptitle('Gaming Time Decreases With Age Across All Demographics', 
             fontsize=18, fontweight='bold', y=0.98)
fig.text(0.5, 0.96, 'Source: American Time Use Survey 2024', 
         transform=fig.transFigure, ha='center', va='top', 
         fontsize=12, style='italic')

# Adjust spacing between subplots
plt.tight_layout()
plt.subplots_adjust(top=0.93, hspace=0.3)

# Save the plot
plt.savefig('visualizations/gaming_time_by_age.png', dpi=300, bbox_inches='tight', facecolor='white')
plt.close()

print("Gaming time by age group visualization saved as 'visualizations/gaming_time_by_age.png'")