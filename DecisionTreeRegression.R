# Decision Tree and Random Forest Regression
# CSC 3220 - Team 8

library(tidyverse)
library(tidymodels)
library(rpart)
library(ranger)

# ---------------------------------------------------------
# Load and prepare data
# ---------------------------------------------------------

source("Parking.R")

rotated_df <- rotated_df %>%
  mutate(
    numeric_time = as.integer(time) + 7,
    day_of_week = as.factor(day_of_week),
    region = as.factor(region),

    # Used only to keep high-occupancy observations
    # distributed across the train/test split
    isFull = factor(pct >= 1)
  ) %>%
  filter(
    !is.na(pct),
    !is.na(numeric_time),
    !is.na(day_of_week),
    !is.na(region)
  )

# Occupancy values above 100% are intentionally retained.
# These observations were identified during exploratory analysis
# and are not automatically treated as data errors.

# ---------------------------------------------------------
# Train/test split
# ---------------------------------------------------------

set.seed(12345)

split <- initial_split(
  rotated_df,
  prop = 0.8,
  strata = isFull
)

train_data <- training(split)
test_data <- testing(split)

cat("\nTraining Observations:", nrow(train_data), "\n")
cat("Testing Observations:", nrow(test_data), "\n")

# ---------------------------------------------------------
# 10-fold cross-validation
# ---------------------------------------------------------

set.seed(12345)

folds <- vfold_cv(
  train_data,
  v = 10,
  strata = isFull
)

# ---------------------------------------------------------
# Modeling recipe
# ---------------------------------------------------------

parkingRecipeReg <- recipe(
  pct ~ numeric_time + day_of_week + region,
  data = train_data
)

# =========================================================
# Decision Tree Regression
# =========================================================

tree_model <- decision_tree(
  mode = "regression",
  tree_depth = 10,
  min_n = 10
) %>%
  set_engine("rpart")

tree_workflow <- workflow() %>%
  add_recipe(parkingRecipeReg) %>%
  add_model(tree_model)

# ---------------------------------------------------------
# Decision tree cross-validation
# ---------------------------------------------------------

set.seed(12345)

tree_cv <- fit_resamples(
  tree_workflow,
  resamples = folds,
  metrics = metric_set(
    rmse,
    rsq,
    mae
  )
)

tree_cv_results <- collect_metrics(
  tree_cv
)

cat(
  "\nDecision Tree 10-Fold Cross-Validation Results\n"
)

print(
  tree_cv_results
)

# ---------------------------------------------------------
# Train final decision tree
# ---------------------------------------------------------

set.seed(12345)

tree_fit <- fit(
  tree_workflow,
  data = train_data
)

tree_predictions <- augment(
  tree_fit,
  test_data
)

# ---------------------------------------------------------
# Decision tree test results
# ---------------------------------------------------------

tree_results <- metrics(
  tree_predictions,
  truth = pct,
  estimate = .pred
)

cat(
  "\nDecision Tree Test Results\n"
)

print(
  tree_results
)

# ---------------------------------------------------------
# Decision tree actual vs predicted plot
# ---------------------------------------------------------

tree_plot <- ggplot(
  tree_predictions,
  aes(
    x = pct,
    y = .pred
  )
) +
  geom_point(
    alpha = 0.3
  ) +
  geom_abline(
    slope = 1,
    intercept = 0,
    color = "red"
  ) +
  labs(
    title = "Decision Tree Regression",
    x = "Actual Occupancy",
    y = "Predicted Occupancy"
  ) +
  theme_minimal()

print(
  tree_plot
)

# =========================================================
# Random Forest Regression
# =========================================================

forest_model <- rand_forest(
  mode = "regression",
  trees = 500,
  mtry = 2,
  min_n = 5
) %>%
  set_engine("ranger")

forest_workflow <- workflow() %>%
  add_recipe(parkingRecipeReg) %>%
  add_model(forest_model)

# ---------------------------------------------------------
# Random forest cross-validation
# ---------------------------------------------------------

set.seed(12345)

forest_cv <- fit_resamples(
  forest_workflow,
  resamples = folds,
  metrics = metric_set(
    rmse,
    rsq,
    mae
  )
)

forest_cv_results <- collect_metrics(
  forest_cv
)

cat(
  "\nRandom Forest 10-Fold Cross-Validation Results\n"
)

print(
  forest_cv_results
)

# ---------------------------------------------------------
# Train final random forest
# ---------------------------------------------------------

set.seed(12345)

forest_fit <- fit(
  forest_workflow,
  data = train_data
)

forest_predictions <- augment(
  forest_fit,
  test_data
)

# ---------------------------------------------------------
# Random forest test results
# ---------------------------------------------------------

forest_results <- metrics(
  forest_predictions,
  truth = pct,
  estimate = .pred
)

cat(
  "\nRandom Forest Test Results\n"
)

print(
  forest_results
)

# ---------------------------------------------------------
# Random forest actual vs predicted plot
# ---------------------------------------------------------

forest_plot <- ggplot(
  forest_predictions,
  aes(
    x = pct,
    y = .pred
  )
) +
  geom_point(
    alpha = 0.3
  ) +
  geom_abline(
    slope = 1,
    intercept = 0,
    color = "red"
  ) +
  labs(
    title = "Random Forest Regression",
    x = "Actual Occupancy",
    y = "Predicted Occupancy"
  ) +
  theme_minimal()

print(
  forest_plot
)

# =========================================================
# Final Model Comparison
# =========================================================

comparison <- bind_rows(
  tree_results %>%
    mutate(
      model = "Decision Tree"
    ),

  forest_results %>%
    mutate(
      model = "Random Forest"
    )
) %>%
  select(
    model,
    .metric,
    .estimate
  )

cat(
  "\nRegression Model Comparison\n"
)

print(
  comparison
)