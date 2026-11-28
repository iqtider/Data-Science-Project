library(tidyverse)
library(tidymodels)
library(rpart)
library(ranger)

# Load and prepare data
source("Parking.R")

rotated_df <- rotated_df %>%
  mutate(
    numeric_time = as.integer(time) + 7,
    day_of_week = as.factor(day_of_week),
    region = as.factor(region),
    isFull = factor(pct >= 1),
    pct = ifelse(pct > 1, 1, pct)
  ) %>%
  filter(!is.na(pct), !is.na(numeric_time),
         !is.na(day_of_week), !is.na(region))

# Split data
set.seed(12345)

split <- initial_split(rotated_df, prop = 0.8, strata = isFull)
train_data <- training(split)
test_data <- testing(split)

# 10-fold cross-validation
folds <- vfold_cv(train_data, v = 10, strata = isFull)

# Recipe
parkingRecipeReg <- recipe(
  pct ~ numeric_time + day_of_week + region + total_inventory,
  data = train_data
)

# ----------------------------------------
# Decision Tree Regression
# ----------------------------------------

tree_model <- decision_tree(
  mode = "regression",
  tree_depth = 10,
  min_n = 10
) %>%
  set_engine("rpart")

tree_workflow <- workflow() %>%
  add_recipe(parkingRecipeReg) %>%
  add_model(tree_model)

# Cross-validation
tree_cv <- fit_resamples(
  tree_workflow,
  resamples = folds,
  metrics = metric_set(rmse, rsq)
)

collect_metrics(tree_cv)

# Train and test
tree_fit <- fit(tree_workflow, data = train_data)

tree_predictions <- augment(tree_fit, test_data)

# Results
metrics(tree_predictions, truth = pct, estimate = .pred)

# Actual vs predicted plot
ggplot(tree_predictions, aes(x = pct, y = .pred)) +
  geom_point(alpha = 0.3) +
  geom_abline(slope = 1, intercept = 0, color = "red") +
  labs(
    title = "Decision Tree Regression",
    x = "Actual Occupancy",
    y = "Predicted Occupancy"
  ) +
  theme_minimal()


# ----------------------------------------
# Random Forest Regression
# ----------------------------------------

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

# Cross-validation
forest_cv <- fit_resamples(
  forest_workflow,
  resamples = folds,
  metrics = metric_set(rmse, rsq)
)

collect_metrics(forest_cv)

# Train and test
forest_fit <- fit(forest_workflow, data = train_data)

forest_predictions <- augment(forest_fit, test_data)

# Results
metrics(forest_predictions, truth = pct, estimate = .pred)

# Actual vs predicted plot
ggplot(forest_predictions, aes(x = pct, y = .pred)) +
  geom_point(alpha = 0.3) +
  geom_abline(slope = 1, intercept = 0, color = "red") +
  labs(
    title = "Random Forest Regression",
    x = "Actual Occupancy",
    y = "Predicted Occupancy"
  ) +
  theme_minimal()


# ----------------------------------------
# Compare Models
# ----------------------------------------

tree_results <- metrics(
  tree_predictions,
  truth = pct,
  estimate = .pred
)

forest_results <- metrics(
  forest_predictions,
  truth = pct,
  estimate = .pred
)

comparison <- bind_rows(
  tree_results %>% mutate(model = "Decision Tree"),
  forest_results %>% mutate(model = "Random Forest")
)

print(comparison)
