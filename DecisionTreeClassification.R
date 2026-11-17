# Decision Tree and Random Forest Classification
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

    # Full = occupancy at or above 100%
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

cat("\nTraining Class Distribution\n")
print(table(train_data$isFull))

cat("\nTesting Class Distribution\n")
print(table(test_data$isFull))

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

parkingRecipeClass <- recipe(
  isFull ~ numeric_time + day_of_week + region,
  data = train_data
)

# ---------------------------------------------------------
# Classification metrics
# ---------------------------------------------------------

classification_metrics <- metric_set(
  accuracy,
  precision,
  recall,
  spec,
  f_meas,
  bal_accuracy
)

cv_metrics <- metric_set(
  accuracy,
  precision,
  recall,
  spec,
  f_meas,
  bal_accuracy,
  roc_auc
)

# =========================================================
# Decision Tree Classification
# =========================================================

tree_model <- decision_tree(
  mode = "classification",
  tree_depth = 10,
  min_n = 10
) %>%
  set_engine("rpart")

tree_workflow <- workflow() %>%
  add_recipe(parkingRecipeClass) %>%
  add_model(tree_model)

# ---------------------------------------------------------
# Decision tree cross-validation
# ---------------------------------------------------------

set.seed(12345)

tree_cv <- fit_resamples(
  tree_workflow,
  resamples = folds,
  metrics = cv_metrics
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

tree_results <- classification_metrics(
  tree_predictions,
  truth = isFull,
  estimate = .pred_class
)

tree_auc <- roc_auc(
  tree_predictions,
  truth = isFull,
  .pred_1
)

cat(
  "\nDecision Tree Test Results\n"
)

print(
  tree_results
)

print(
  tree_auc
)

cat(
  "\nDecision Tree Confusion Matrix\n"
)

print(
  conf_mat(
    tree_predictions,
    truth = isFull,
    estimate = .pred_class
  )
)

# =========================================================
# Random Forest Classification
# =========================================================

forest_model <- rand_forest(
  mode = "classification",
  trees = 500,
  mtry = 2,
  min_n = 5
) %>%
  set_engine(
    "ranger",
    probability = TRUE
  )

forest_workflow <- workflow() %>%
  add_recipe(parkingRecipeClass) %>%
  add_model(forest_model)

# ---------------------------------------------------------
# Random forest cross-validation
# ---------------------------------------------------------

set.seed(12345)

forest_cv <- fit_resamples(
  forest_workflow,
  resamples = folds,
  metrics = cv_metrics
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

forest_results <- classification_metrics(
  forest_predictions,
  truth = isFull,
  estimate = .pred_class
)

forest_auc <- roc_auc(
  forest_predictions,
  truth = isFull,
  .pred_1
)

cat(
  "\nRandom Forest Test Results\n"
)

print(
  forest_results
)

print(
  forest_auc
)

cat(
  "\nRandom Forest Confusion Matrix\n"
)

print(
  conf_mat(
    forest_predictions,
    truth = isFull,
    estimate = .pred_class
  )
)

# =========================================================
# Majority-Class Baseline
# =========================================================

majority_class <- names(
  which.max(
    table(train_data$isFull)
  )
)

baseline_predictions <- test_data %>%
  mutate(
    .pred_class = factor(
      rep(
        majority_class,
        nrow(test_data)
      ),
      levels = levels(isFull)
    )
  )

baseline_results <- classification_metrics(
  baseline_predictions,
  truth = isFull,
  estimate = .pred_class
)

cat(
  "\nMajority-Class Baseline Results\n"
)

cat(
  "Predicted Class:",
  majority_class,
  "\n"
)

print(
  baseline_results
)

# =========================================================
# Final Model Comparison
# =========================================================

tree_comparison <- bind_rows(
  tree_results,
  tree_auc
) %>%
  mutate(
    model = "Decision Tree"
  )

forest_comparison <- bind_rows(
  forest_results,
  forest_auc
) %>%
  mutate(
    model = "Random Forest"
  )

baseline_comparison <- baseline_results %>%
  mutate(
    model = "Majority Baseline"
  )

comparison <- bind_rows(
  tree_comparison,
  forest_comparison,
  baseline_comparison
) %>%
  select(
    model,
    .metric,
    .estimate
  )

cat(
  "\nClassification Model Comparison\n"
)

print(
  comparison
)