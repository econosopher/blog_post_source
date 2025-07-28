library(tidyverse)

# Test Gini calculation
calculate_gini <- function(values) {
  values <- values[!is.na(values) & values > 0]
  if (length(values) < 2) return(NA)
  
  values <- sort(values)
  n <- length(values)
  index <- 1:n
  
  gini <- (2 * sum(index * values)) / (n * sum(values)) - (n + 1) / n
  return(gini)
}

# Test with known data
test_values <- c(100, 200, 300, 400, 500)
cat("Test Gini calculation:\n")
cat(sprintf("Values: %s\n", paste(test_values, collapse = ", ")))
cat(sprintf("Gini: %.3f\n", calculate_gini(test_values)))

# Test with all equal values
equal_values <- rep(100, 10)
cat(sprintf("\nEqual values Gini: %.3f\n", calculate_gini(equal_values)))

# Test with highly unequal values
unequal_values <- c(rep(1, 9), 1000)
cat(sprintf("Unequal values Gini: %.3f\n", calculate_gini(unequal_values)))