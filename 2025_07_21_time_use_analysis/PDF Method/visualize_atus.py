import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

def create_time_use_visualizations(csv_path):
    """Create visualizations from time use data"""
    df = pd.read_csv(csv_path)
    
    plt.style.use('seaborn-v0_8-darkgrid')
    sns.set_palette("husl")
    
    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    fig.suptitle('American Time Use Survey Analysis', fontsize=20, fontweight='bold')
    
    top_10 = df.head(10)
    
    ax1 = axes[0, 0]
    bars = ax1.barh(top_10['category'], top_10['total_minutes'])
    ax1.set_xlabel('Minutes per Day', fontsize=12)
    ax1.set_title('Top 10 Time Use Categories', fontsize=14, fontweight='bold')
    ax1.invert_yaxis()
    
    for i, (bar, minutes) in enumerate(zip(bars, top_10['total_minutes'])):
        hours = minutes // 60
        mins = minutes % 60
        ax1.text(bar.get_width() + 5, bar.get_y() + bar.get_height()/2, 
                f'{hours}h {mins}m', va='center', fontsize=10)
    
    ax2 = axes[0, 1]
    df['hours_decimal'] = df['total_minutes'] / 60
    colors = plt.cm.Set3(range(len(top_10)))
    wedges, texts, autotexts = ax2.pie(top_10['hours_decimal'], 
                                        labels=top_10['category'], 
                                        autopct='%1.1f%%',
                                        colors=colors,
                                        startangle=90)
    ax2.set_title('Time Distribution (Top 10 Categories)', fontsize=14, fontweight='bold')
    
    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontweight('bold')
        autotext.set_fontsize(10)
    
    ax3 = axes[1, 0]
    df_sorted = df.sort_values('total_minutes', ascending=True)
    positions = range(len(df_sorted))
    ax3.scatter(df_sorted['total_minutes'], positions, 
                s=df_sorted['total_minutes']*2, 
                alpha=0.6, 
                c=df_sorted['total_minutes'], 
                cmap='viridis')
    ax3.set_xlabel('Minutes per Day', fontsize=12)
    ax3.set_ylabel('Activity Rank', fontsize=12)
    ax3.set_title('Time Use Distribution by Activity', fontsize=14, fontweight='bold')
    ax3.grid(True, alpha=0.3)
    
    ax4 = axes[1, 1]
    time_categories = []
    for minutes in df['total_minutes']:
        if minutes < 30:
            time_categories.append('< 30 min')
        elif minutes < 60:
            time_categories.append('30-60 min')
        elif minutes < 120:
            time_categories.append('1-2 hours')
        elif minutes < 240:
            time_categories.append('2-4 hours')
        else:
            time_categories.append('> 4 hours')
    
    df['time_category'] = time_categories
    category_counts = df['time_category'].value_counts()
    category_order = ['< 30 min', '30-60 min', '1-2 hours', '2-4 hours', '> 4 hours']
    category_counts = category_counts.reindex(category_order, fill_value=0)
    
    bars4 = ax4.bar(category_counts.index, category_counts.values, 
                     color=sns.color_palette("coolwarm", len(category_counts)))
    ax4.set_xlabel('Time Range', fontsize=12)
    ax4.set_ylabel('Number of Activities', fontsize=12)
    ax4.set_title('Activities by Duration', fontsize=14, fontweight='bold')
    ax4.tick_params(axis='x', rotation=45)
    
    for bar in bars4:
        height = bar.get_height()
        ax4.text(bar.get_x() + bar.get_width()/2., height + 0.1,
                f'{int(height)}', ha='center', va='bottom', fontsize=10)
    
    plt.tight_layout()
    
    output_path = Path("visualizations/time_use_analysis.png")
    output_path.parent.mkdir(exist_ok=True)
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.close()
    
    fig2, ax = plt.subplots(figsize=(12, 8))
    
    df['percentage'] = (df['total_minutes'] / df['total_minutes'].sum()) * 100
    df_filtered = df[df['percentage'] >= 1.0].copy()
    
    y_positions = range(len(df_filtered))
    bars = ax.barh(y_positions, df_filtered['total_minutes'], color=sns.color_palette("muted", len(df_filtered)))
    
    ax.set_yticks(y_positions)
    ax.set_yticklabels(df_filtered['category'])
    ax.set_xlabel('Minutes per Day', fontsize=14)
    ax.set_title('Daily Time Allocation (Activities ≥ 1% of Total Time)', fontsize=16, fontweight='bold')
    ax.invert_yaxis()
    
    for i, (bar, row) in enumerate(zip(bars, df_filtered.itertuples())):
        hours = row.total_minutes // 60
        mins = row.total_minutes % 60
        percentage = row.percentage
        ax.text(bar.get_width() + 5, bar.get_y() + bar.get_height()/2, 
                f'{hours}h {mins}m ({percentage:.1f}%)', 
                va='center', fontsize=10)
    
    ax.grid(True, axis='x', alpha=0.3)
    plt.tight_layout()
    
    output_path2 = Path("visualizations/time_allocation_detailed.png")
    plt.savefig(output_path2, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"Visualizations saved to:")
    print(f"  - {output_path}")
    print(f"  - {output_path2}")
    
    print("\nSummary Statistics:")
    print(f"Total activities tracked: {len(df)}")
    print(f"Total time accounted for: {df['total_minutes'].sum()} minutes ({df['total_minutes'].sum()/60:.1f} hours)")
    print(f"\nTop 5 time-consuming activities:")
    for i, row in df.head(5).iterrows():
        print(f"  {i+1}. {row['category']}: {row['hours']}h {row['minutes']}m")

if __name__ == "__main__":
    csv_path = Path("data/time_use_data.csv")
    
    if csv_path.exists():
        create_time_use_visualizations(csv_path)
    else:
        print(f"Data file not found at {csv_path}. Please run scrape_atus.py first.")