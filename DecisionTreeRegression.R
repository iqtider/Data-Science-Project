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
    pct = ifelse(pct > 1, 1, pct)
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
parkingRecipeReg <- recipe(
  pct ~ numeric_time + day_of_week + region,
  data = train_data
)

# Random Forest with selected hyperparameters
forest_model <- rand_forest(
  mode = "regression",
  trees = 500,
  mtry = 2,
  min_n = 20
) %>%
  set_engine("ranger")

forest_workflow <- workflow() %>%
  add_recipe(parkingRecipeReg) %>%
  add_model(forest_model)

# Regression metrics
reg_metrics <- metric_set(rmse, mae, rsq_trad)

# Cross-validation
set.seed(12345)

forest_cv <- fit_resamples(
  forest_workflow,
  resamples = folds,
  metrics = reg_metrics
)

print(collect_metrics(forest_cv))

# Train final model
set.seed(12345)

forest_fit <- fit(
  forest_workflow,
  data = train_data
)

# Test predictions
forest_predictions <- augment(forest_fit, test_data)

# Test results
forest_results <- reg_metrics(
  forest_predictions,
  truth = pct,
  estimate = .pred
)

# Actual vs predicted plot
print(
  ggplot(forest_predictions, aes(x = pct, y = .pred)) +
    geom_point(alpha = 0.3) +
    geom_abline(slope = 1, intercept = 0, color = "red") +
    labs(
      title = "Random Forest Regression",
      x = "Actual Occupancy",
      y = "Predicted Occupancy"
    ) +
    theme_minimal()
)

# Final results table
forest_comparison <- forest_results %>%
  mutate(model = "Random Forest") %>%
  select(model, .metric, .estimate)

print(forest_comparison)