library(tidyverse)
source("Parking.R")

# Show clean data
View(clean_parking)

# Filter out specific columns from the table
regression_data <- clean_parking |>
  select(site_id, day_of_week, region, total_inventory, ends_with("_pct"))

# Converting each hourly occupancy in its own row.
regression_data <- regression_data |>
  pivot_longer(
    cols = ends_with("_pct"),
    names_to = "time",
    values_to = "pct"
  )

# Remove records with missing occupancy
regression_data <- regression_data |>
  filter(!is.na(pct))

# Use a 24-hour clock.
regression_data <- regression_data |>
  mutate(hour = case_when(
    time == "8_am_pct"  ~ 8,
    time == "9_am_pct"  ~ 9,
    time == "10_am_pct" ~ 10,
    time == "11_am_pct" ~ 11,
    time == "12_pm_pct" ~ 12,
    time == "1_pm_pct"  ~ 13,
    time == "2_pm_pct"  ~ 14,
    time == "3_pm_pct"  ~ 15,
    time == "4_pm_pct"  ~ 16,
    time == "5_pm_pct"  ~ 17,
    time == "6_pm_pct"  ~ 18,
    time == "7_pm_pct"  ~ 19,
    time == "8_pm_pct"  ~ 20
  ))

regression_data <- regression_data |>
  relocate(hour, .after = time)

# Mark observations at or above parking capacity.
regression_data <- regression_data |>
  mutate(is_full = if_else(pct >= 1, 1, 0))

View(regression_data)

# Make the random selection reproducible.
set.seed(12345)

# Remove repeats of parking site.
site_ids <- unique(regression_data$site_id)

# Randomly selected 80% of sites for training
train_sites <- sample(site_ids, size = floor(0.8 * length(site_ids)))

# Keep records from the selected training sites.
train_data <- regression_data |>
  filter(site_id %in% train_sites)

View(train_data)

# Keep records from the testing sites
test_data <- regression_data |>
  filter(!(site_id %in% train_sites))

View(test_data)

# Linear Regression model of train_data
linear_model <- lm(pct ~ hour, data = train_data)
summary(linear_model)

# Plot linear regression model.
plot(pct ~ jitter(hour, amount = 0.15), data = train_data,
     main = "Parking Occupancy by Hour",
     xlab = "Hour",
     ylab = "Occupancy rate",
     ylim = c(0, 1.2),
     pch = 16, cex = 0.25,
     col = "grey55",
     xaxt = "n",
     bty = "l")

# Label every hour.
axis(1, at = 8:20)

# Add the fitted regression line.
abline(linear_model, col = "steelblue", lwd = 2)

# Linear Regression model of test_data
test_data <- test_data |>
  mutate(predicted_pct = predict(linear_model, newdata = test_data))

View(test_data)

# Plot occupancy in the testing data.
plot(pct ~ jitter(hour, amount = 0.15), data = test_data,
     main = "Parking Occupancy by Hour",
     xlab = "Hour",
     ylab = "Occupancy rate",
     ylim = c(0, 1.2),
     pch = 16, cex = 0.25,
     col = "grey55",
     xaxt = "n",
     bty = "l")

# Label every hour.
axis(1, at = 8:20)

# Add predictions from the trained model.
abline(linear_model, col = "steelblue", lwd = 2)

# Calculate prediction errors on the testing data.
linear_errors <- test_data$pct - test_data$predicted_pct

# Calculate RMSE.
linear_rmse <- sqrt(mean(linear_errors^2))
linear_rmse * 100

# Use average training occupancy as the baseline prediction.
baseline_prediction <- mean(train_data$pct)

# Calculate baseline RMSE on the testing data.
baseline_rmse <- sqrt(mean((test_data$pct - baseline_prediction)^2))
baseline_rmse * 100


# Predict whether a site is empty/taken with logistic regression
logistic_model <- glm(
  is_full ~ hour,
  data = train_data,
  family = binomial()
)

summary(logistic_model)

test_data <- test_data |>
  mutate(prob_full = predict(
    logistic_model,
    newdata = test_data,
    type = "response"
  ))

View(test_data)

# Compare predictions with recorded outcomes.
table(
  Predicted = test_data$predicted_full,
  Actual = test_data$is_full
)

# Classify testing records using a 50% cutoff.
cutoff <- 0.5

test_data <- test_data |>
  mutate(predicted_full = if_else(prob_full >= cutoff, 1, 0))

# Compare predictions with recorded outcomes.
confusion_matrix <- table(
  Predicted = factor(test_data$predicted_full,
                     levels = c(0, 1),
                     labels = c("Not full", "Full")),
  Actual = factor(test_data$is_full,
                  levels = c(0, 1),
                  labels = c("Not full", "Full"))
)

print(confusion_matrix)

# Count correct predictions and mistakes.
TP <- sum(test_data$predicted_full == 1 & test_data$is_full == 1)
TN <- sum(test_data$predicted_full == 0 & test_data$is_full == 0)
FP <- sum(test_data$predicted_full == 1 & test_data$is_full == 0)
FN <- sum(test_data$predicted_full == 0 & test_data$is_full == 1)

# Calculate classification metrics.
accuracy <- (TP + TN) / nrow(test_data)

precision <- if (TP + FP == 0) NA_real_ else TP / (TP + FP)

recall <- if (TP + FN == 0) NA_real_ else TP / (TP + FN)

f1 <- if (2 * TP + FP + FN == 0) {
  NA_real_
} else {
  2 * TP / (2 * TP + FP + FN)
}

# Calculate ROC AUC from the predicted probability ranks.
n_full <- sum(test_data$is_full == 1)
n_not_full <- sum(test_data$is_full == 0)

positive_ranks <- sum(
  rank(test_data$prob_full)[test_data$is_full == 1]
)

auc <- if (n_full > 0 && n_not_full > 0) {
  (positive_ranks - n_full * (n_full + 1) / 2) /
    (n_full * n_not_full)
} else {
  NA_real_
}

# Compare with a constant training-rate baseline.
baseline_probability <- mean(train_data$is_full)
majority_class <- as.integer(baseline_probability >= 0.5)
baseline_accuracy <- mean(test_data$is_full == majority_class)

# Measure the quality of the predicted probabilities.
brier <- mean((test_data$prob_full - test_data$is_full)^2)
baseline_brier <- mean((baseline_probability - test_data$is_full)^2)

# Display logistic regression results.
logistic_results <- data.frame(
  Metric = c(
    "Accuracy", "Precision (full)", "Recall (full)",
    "F1 (full)", "ROC AUC", "Brier score",
    "Baseline accuracy", "Baseline Brier score"
  ),
  Value = c(
    accuracy, precision, recall, f1, auc, brier,
    baseline_accuracy, baseline_brier
  )
)

print(logistic_results)

# Calculate fitted probabilities for each hour.
hour_predictions <- data.frame(hour = 8:20)

hour_predictions$prob_full <- predict(
  logistic_model,
  newdata = hour_predictions,
  type = "response"
)

# Plot the fitted probabilities.
plot(prob_full ~ hour, data = hour_predictions,
     type = "b",
     pch = 16,
     col = "steelblue",
     main = "Predicted Probability of Full Parking",
     xlab = "Hour",
     ylab = "Probability of being full",
     ylim = c(0, 1),
     xaxt = "n",
     bty = "l")

axis(1, at = 8:20)

# Show the classification cutoff.
abline(h = cutoff, col = "grey50", lty = 2)

# Display the linear regression comparison.
linear_results <- data.frame(
  Model = c("Mean baseline", "Linear regression"),
  RMSE_percentage_points = 100 * c(baseline_rmse, linear_rmse)
)

print(linear_results)