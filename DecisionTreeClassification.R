library(tidyverse)
library(tidymodels)
library(ranger)

# Load and prepare data
source("Parking.R")

rotated_df <- rotated_df %>%
  mutate(
    numeric_time = as.integer(time) + 7,
    day_of_week = as.factor(day_of_week),
    region = as.factor(region),
    isFull = factor(
      if_else(pct >= 1, "1", "0"),
      levels = c("1", "0")
    )
  ) %>%
  filter(!is.na(pct), !is.na(numeric_time),
         !is.na(day_of_week), !is.na(region))

# Grouped 80/20 train/test split
set.seed(12345)

split <- group_initial_split(
  rotated_df,
  group = site_id,
  prop = 0.8
)

train_data <- training(split)
test_data <- testing(split)

# Grouped 10-fold cross-validation
folds <- group_vfold_cv(
  train_data,
  group = site_id,
  v = 10
)

# Recipe
parkingRecipeClass <- recipe(
  isFull ~ numeric_time + day_of_week + region,
  data = train_data
)

# Random Forest with selected hyperparameters
forest_model <- rand_forest(
  mode = "classification",
  trees = 500,
  mtry = 3,
  min_n = 2
) %>%
  set_engine("ranger", probability = TRUE)

forest_workflow <- workflow() %>%
  add_recipe(parkingRecipeClass) %>%
  add_model(forest_model)

# Classification threshold
threshold <- 0.25

# Cross-validation
set.seed(12345)

forest_cv <- fit_resamples(
  forest_workflow,
  resamples = folds,
  metrics = metric_set(roc_auc),
  control = control_resamples(save_pred = TRUE)
)

# Apply threshold to cross-validation predictions
cv_predictions <- collect_predictions(forest_cv) %>%
  mutate(
    .pred_class = factor(
      if_else(.pred_1 >= threshold, "1", "0"),
      levels = c("1", "0")
    )
  )

# Classification metrics
class_metrics <- metric_set(
  bal_accuracy,
  accuracy,
  precision,
  recall,
  specificity,
  f_meas
)

# Cross-validation results
cv_results <- cv_predictions %>%
  group_by(id) %>%
  class_metrics(truth = isFull, estimate = .pred_class)

cv_auc <- cv_predictions %>%
  group_by(id) %>%
  roc_auc(truth = isFull, .pred_1)

cv_summary <- bind_rows(cv_results, cv_auc) %>%
  group_by(.metric) %>%
  summarise(mean = mean(.estimate), .groups = "drop")

print(cv_summary)

# Train final model
set.seed(12345)

forest_fit <- fit(
  forest_workflow,
  data = train_data
)

# Test predictions
forest_predictions <- augment(forest_fit, test_data) %>%
  mutate(
    .pred_class = factor(
      if_else(.pred_1 >= threshold, "1", "0"),
      levels = c("1", "0")
    )
  )

# Test results
forest_results <- class_metrics(
  forest_predictions,
  truth = isFull,
  estimate = .pred_class
)

forest_auc <- roc_auc(
  forest_predictions,
  truth = isFull,
  .pred_1
)

# Confusion matrix
print(conf_mat(
  forest_predictions,
  truth = isFull,
  estimate = .pred_class
))

# Final results table
forest_comparison <- bind_rows(
  forest_results,
  forest_auc
) %>%
  mutate(model = "Random Forest") %>%
  select(model, .metric, .estimate)

print(forest_comparison)