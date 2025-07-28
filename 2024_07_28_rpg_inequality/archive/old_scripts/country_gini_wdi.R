# Fetch Country Gini Coefficients using WDI package
library(pacman)
p_load(WDI, tidyverse, kableExtra, ggplot2)

# Fetch Gini coefficient data from World Bank
# SI.POV.GINI is the indicator code for Gini index
countries <- c("US", "JP", "SE", "CL")
country_names <- c("United States", "Japan", "Sweden", "Chile")

# Get the latest available data (2010-2023)
gini_data <- WDI(
  country = countries,
  indicator = "SI.POV.GINI",
  start = 2010,
  end = 2023,
  extra = TRUE
) %>%
  filter(!is.na(SI.POV.GINI)) %>%
  group_by(country) %>%
  filter(year == max(year)) %>%
  ungroup() %>%
  select(country, year, gini = SI.POV.GINI) %>%
  mutate(gini = gini / 100)  # Convert from percentage to decimal

# Create formatted table - more concise
gini_table <- gini_data %>%
  arrange(gini) %>%
  mutate(
    Country = paste0(country, " (", year, ")"),
    Gini = sprintf("%.3f", gini)
  ) %>%
  select(Country, Gini)

# Display table
cat("\nGini Coefficients\n")
cat("=================\n\n")
print(kable(gini_table, format = "simple", align = c("l", "r")))

# Create visualization
p <- ggplot(gini_data, aes(x = reorder(country, gini), y = gini)) +
  geom_bar(stat = "identity", fill = "#2E86AB", width = 0.7) +
  geom_text(aes(label = sprintf("%.3f\n(%d)", gini, year)), 
            vjust = -0.3, size = 3.5) +
  scale_y_continuous(limits = c(0, 0.5), expand = c(0, 0.02)) +
  labs(
    title = "Income Inequality by Country",
    subtitle = "Gini Coefficient: 0 = everyone has equal income, 1 = one person has all income",
    x = NULL,
    y = "Gini Coefficient",
    caption = "Source: World Bank Development Indicators\nNote: Shows latest available year for each country"
  ) +
  theme_minimal() +
  theme(
    plot.title.position = "panel",
    plot.subtitle.position = "panel",
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11, color = "gray40"),
    axis.text.x = element_text(size = 11),
    axis.text.y = element_text(size = 10),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  )

# Save outputs
ggsave("visualizations/country_gini_wdi.png", p, width = 8, height = 6, dpi = 300)
write_csv(gini_data, "country_gini_wdi_data.csv")

# Additional info
cat("\n\nNotes:\n")
cat("- Sweden has the lowest inequality (Gini =", sprintf("%.3f", gini_data$gini[gini_data$country == "Sweden"]), ")\n")
cat("- Chile has the highest inequality (Gini =", sprintf("%.3f", gini_data$gini[gini_data$country == "Chile"]), ")\n")
cat("\nData source: World Bank Development Indicators (WDI)\n")
cat("Files saved: country_gini_wdi.png, country_gini_wdi_data.csv\n")