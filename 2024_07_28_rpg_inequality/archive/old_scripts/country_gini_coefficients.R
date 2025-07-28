# Country Gini Coefficients - Latest Available Data
# Sources: World Bank, OECD

library(tidyverse)
library(kableExtra)

# Create data frame with latest Gini coefficients
country_gini <- tibble(
  Country = c("United States", "Japan", "Sweden", "Chile"),
  `Latest Year` = c(2021, 2018, 2021, 2020),
  `Gini Coefficient` = c(0.398, 0.334, 0.278, 0.449),
  Source = c("World Bank", "OECD", "World Bank", "World Bank"),
  Notes = c(
    "Post-tax and transfers",
    "Disposable income basis", 
    "Post-tax and transfers",
    "Post-tax and transfers"
  )
)

# Display as formatted table
print("Latest Gini Coefficients by Country:")
print("=====================================")
country_gini %>%
  kable(format = "simple", digits = 3) %>%
  print()

# Create a visualization
library(ggplot2)

p <- ggplot(country_gini, aes(x = reorder(Country, `Gini Coefficient`), y = `Gini Coefficient`)) +
  geom_bar(stat = "identity", fill = "steelblue", width = 0.7) +
  geom_text(aes(label = sprintf("%.3f", `Gini Coefficient`)), 
            vjust = -0.5, size = 4) +
  coord_cartesian(ylim = c(0, 0.5)) +
  labs(
    title = "Income Inequality: Gini Coefficients by Country",
    subtitle = paste0("Latest available data (", 
                      paste(unique(country_gini$`Latest Year`), collapse = ", "), ")"),
    x = "Country",
    y = "Gini Coefficient",
    caption = "Source: World Bank, OECD\nNote: Higher values indicate greater inequality"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold", hjust = 0),
    plot.subtitle = element_text(size = 12, hjust = 0),
    axis.text.x = element_text(size = 11),
    axis.text.y = element_text(size = 10),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  )

# Save the plot
ggsave("visualizations/country_gini_coefficients.png", p, width = 8, height = 6, dpi = 300)

# Save data as CSV for future reference
write_csv(country_gini, "country_gini_coefficients.csv")

print("\nFiles saved:")
print("- country_gini_coefficients.csv")
print("- visualizations/country_gini_coefficients.png")