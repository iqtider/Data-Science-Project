##logistic regression for parking
library(tidymodels)

##Load prepared parking data
source("Parking.R")

##Adjust features
rotated_df <- rotated_df %>%
  mutate(
    numeric_time = case_when(
      time == "8_am_pct" ~ 8,
      time == "9_am_pct" ~ 9,
      time == "10_am_pct" ~ 10,
      time == "11_am_pct" ~ 11,
      time == "12_pm_pct" ~ 12,
      time == "1_pm_pct" ~ 13,
      time == "2_pm_pct" ~ 14,
      time == "3_pm_pct" ~ 15,
      time == "4_pm_pct" ~ 16,
      time == "5_pm_pct" ~ 17,
      time == "6_pm_pct" ~ 18,
      time == "7_pm_pct" ~ 19,
      time == "8_pm_pct" ~ 20
    ),
    day_of_week = as.factor(day_of_week),
    region = as.factor(region),
    log_inventory = log1p(total_inventory),

    #Full = occupancy at or above 100%
    isFull = factor(
      if_else(pct >= 1, "1", "0"),
      levels = c("1", "0")
    )
  ) %>%
  filter(
    !is.na(pct),
    !is.na(numeric_time),
    !is.na(day_of_week),
    !is.na(region),
    !is.na(total_inventory)
  )

set.seed(12345); #For reproduction

#Split data for training and testing
split <- group_initial_split(
  rotated_df,
  group = site_id,
  prop = 0.8
)

train_data <- training(split)
test_data <- testing(split)

cat("\nTraining Sites:", n_distinct(train_data$site_id), "\n")
cat("Testing Sites:", n_distinct(test_data$site_id), "\n")
cat(
  "Shared Sites:",
  length(intersect(unique(train_data$site_id), unique(test_data$site_id))),
  "\n"
)

#Create 10-fold cross-validation
folds <- group_vfold_cv(
  train_data,
  group = site_id,
  v = 10,
  balance = "observations"
)

#Create logistic regression recipe
parkingRecipeLogistic <- recipe(
  isFull ~ numeric_time + day_of_week + region + log_inventory,
  data = train_data
) |>
  step_dummy(
    all_nominal_predictors()
  )

#Create logistic regression model
parkingLogistic <- logistic_reg(
  mode = "classification"
) |>
  set_engine("glm")

#Create workflow
parkingLogisticWorkflow <- workflow() |>
  add_recipe(parkingRecipeLogistic) |>
  add_model(parkingLogistic)

#10-fold cross-validation
logistic_cv <- fit_resamples(
  parkingLogisticWorkflow,
  resamples = folds,
  metrics = metric_set(
    accuracy,
    precision,
    recall,
    yardstick::spec,
    f_meas,
    bal_accuracy,
    roc_auc
  )
)

cat("\nLogistic Regression 10-Fold Cross-Validation Results\n")

print(
  collect_metrics(logistic_cv)
)

#Fit final logistic regression model
logistic_fit <- parkingLogisticWorkflow |>
  fit(
    data = train_data
  )

#Predict test data
logistic_predictions <- augment(
  logistic_fit,
  test_data
)

#Show confusion matrix
cat("\nLogistic Regression Confusion Matrix\n")

print(
  conf_mat(
    logistic_predictions,
    truth = isFull,
    estimate = .pred_class
  )
)

#Show classification metrics
logistic_metrics <- metric_set(
  accuracy,
  precision,
  recall,
  yardstick::spec,
  f_meas,
  bal_accuracy
)

logistic_results <- logistic_metrics(
  logistic_predictions,
  truth = isFull,
  estimate = .pred_class
)

cat("\nLogistic Regression Test Results\n")

print(
  logistic_results
)

#Show ROC-AUC
logistic_auc <- logistic_predictions |>
  roc_auc(
    isFull,
    .pred_1
  )

cat("\nLogistic Regression ROC-AUC\n")

print(
  logistic_auc
)

#Create majority class baseline
majority_class <- names(
  which.max(
    table(train_data$isFull)
  )
)

baseline_predictions <- test_data %>%
  mutate(
    .pred_class = factor(
      majority_class,
      levels = levels(isFull)
    )
  )

baseline_results <- logistic_metrics(
  baseline_predictions,
  truth = isFull,
  estimate = .pred_class
)

cat("\nMajority-Class Baseline Results\n")

print(
  baseline_results
)

#Compare logistic regression to majority baseline
logistic_comparison <- bind_rows(
  logistic_results,
  logistic_auc
) %>%
  mutate(
    model = "Logistic Regression"
  )

baseline_comparison <- baseline_results %>%
  mutate(
    model = "Majority Baseline"
  )

comparison <- bind_rows(
  logistic_comparison,
  baseline_comparison
) %>%
  select(
    model,
    .metric,
    .estimate
  )

cat("\nLogistic Regression Model Comparison\n")

print(
  comparison
)