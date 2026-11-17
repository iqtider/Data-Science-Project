library(tidyverse)
library(tidymodels)
library(rpart)
library(ranger)

# Load data
source("Parking.R")

# Prepare classification data
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
  filter(
    !is.na(pct),
    !is.na(numeric_time),
    !is.na(day_of_week),
    !is.na(region)
  )

# Train/test split
set.seed(12345)

split <- initial_split(
  rotated_df,
  prop = 0.8,
  strata = isFull
)

train_data <- training(split)
test_data <- testing(split)

# Cross-validation
folds <- vfold_cv(
  train_data,
  v = 10,
  strata = isFull
)

# Recipe
parkingRecipeClass <- recipe(
  isFull ~ numeric_time + day_of_week + region,
  data = train_data
)

# ----------------------------------------
# Decision Tree Classification
# ----------------------------------------

tree_model <- decision_tree(
  mode = "classification",
  tree_depth = 10,
  min_n = 10
) %>%
  set_engine("rpart")

tree_workflow <- workflow() %>%
  add_recipe(parkingRecipeClass) %>%
  add_model(tree_model)

# Cross-validation
tree_cv <- fit_resamples(
  tree_workflow,
  resamples = folds,
  metrics = metric_set(
    accuracy,
    roc_auc,
    recall
  )
)

print(collect_metrics(tree_cv))

# Train model
tree_fit <- fit(
  tree_workflow,
  data = train_data
)

# Test predictions
tree_predictions <- augment(
  tree_fit,
  test_data
)

# Test metrics
tree_results <- metric_set(
  accuracy,
  recall
)(
  tree_predictions,
  truth = isFull,
  estimate = .pred_class
)

tree_auc <- roc_auc(
  tree_predictions,
  truth = isFull,
  .pred_1
)

print(tree_results)
print(tree_auc)

# Confusion matrix
conf_mat(
  tree_predictions,
  truth = isFull,
  estimate = .pred_class
)


# ----------------------------------------
# Random Forest Classification
# ----------------------------------------

forest_model <- rand_forest(
  mode = "classification",
  trees = 500,
  mtry = 2,
  min_n = 5
) %>%
  set_engine("ranger", probability = TRUE)

forest_workflow <- workflow() %>%
  add_recipe(parkingRecipeClass) %>%
  add_model(forest_model)

# Cross-validation
forest_cv <- fit_resamples(
  forest_workflow,
  resamples = folds,
  metrics = metric_set(
    accuracy,
    roc_auc,
    recall
  )
)

print(collect_metrics(forest_cv))

# Train model
forest_fit <- fit(
  forest_workflow,
  data = train_data
)

# Test predictions
forest_predictions <- augment(
  forest_fit,
  test_data
)

# Test metrics
forest_results <- metric_set(
  accuracy,
  recall
)(
  forest_predictions,
  truth = isFull,
  estimate = .pred_class
)

forest_auc <- roc_auc(
  forest_predictions,
  truth = isFull,
  .pred_1
)

print(forest_results)
print(forest_auc)

# Confusion matrix
conf_mat(
  forest_predictions,
  truth = isFull,
  estimate = .pred_class
)


# ----------------------------------------
# Compare Models
# ----------------------------------------

tree_comparison <- bind_rows(
  tree_results,
  tree_auc
) %>%
  mutate(model = "Decision Tree")

forest_comparison <- bind_rows(
  forest_results,
  forest_auc
) %>%
  mutate(model = "Random Forest")

comparison <- bind_rows(
  tree_comparison,
  forest_comparison
) %>%
  select(model, .metric, .estimate)

print(comparison)
