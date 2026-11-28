##nonlinear regression for parking
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
    numeric_time_squared = numeric_time^2,
    day_of_week = as.factor(day_of_week),
    region = as.factor(region),
    log_inventory = log1p(total_inventory),

    #Used to monitor high-occupancy observations after grouped site splitting
    isFull = factor(pct >= 1)
  ) %>%
  filter(
    !is.na(pct),
    !is.na(numeric_time),
    !is.na(day_of_week),
    !is.na(region),
    !is.na(total_inventory)
  )

#Occupancy values above 100% are retained

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

#Create nonlinear regression recipe
#The squared time term allows occupancy to follow a curved pattern
parkingRecipeNonlinear <- recipe(
  pct ~ numeric_time + numeric_time_squared + day_of_week + region + log_inventory,
  data = train_data
) |>
  step_dummy(
    all_nominal_predictors()
  )

#Create nonlinear regression model
parkingNonlinear <- linear_reg(
  mode = "regression"
) |>
  set_engine("lm")

#Create workflow
parkingNonlinearWorkflow <- workflow() |>
  add_recipe(parkingRecipeNonlinear) |>
  add_model(parkingNonlinear)

#10-fold cross-validation
nonlinear_cv <- fit_resamples(
  parkingNonlinearWorkflow,
  resamples = folds,
  metrics = metric_set(
    rmse,
    rsq,
    mae
  )
)

cat("\nNonlinear Regression 10-Fold Cross-Validation Results\n")

print(
  collect_metrics(nonlinear_cv)
)

#Fit final nonlinear regression model
nonlinear_fit <- parkingNonlinearWorkflow |>
  fit(
    data = train_data
  )

#Predict test data
nonlinear_predictions <- augment(
  nonlinear_fit,
  test_data
)

#Show test results
nonlinear_results <- metric_set(
  rmse,
  rsq,
  mae
)(
  nonlinear_predictions,
  truth = pct,
  estimate = .pred
)

cat("\nNonlinear Regression Test Results\n")

print(
  nonlinear_results
)

#Actual vs predicted plot
nonlinear_predictions |>
  ggplot(
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
    title = "Nonlinear Regression",
    x = "Actual Occupancy",
    y = "Predicted Occupancy"
  ) +
  theme_minimal()

#Create linear regression model for comparison
parkingRecipeLinear <- recipe(
  pct ~ numeric_time + day_of_week + region + log_inventory,
  data = train_data
) |>
  step_dummy(
    all_nominal_predictors()
  )

parkingLinear <- linear_reg(
  mode = "regression"
) |>
  set_engine("lm")

parkingLinearWorkflow <- workflow() |>
  add_recipe(parkingRecipeLinear) |>
  add_model(parkingLinear)

linear_fit <- parkingLinearWorkflow |>
  fit(
    data = train_data
  )

linear_predictions <- augment(
  linear_fit,
  test_data
)

linear_results <- metric_set(
  rmse,
  rsq,
  mae
)(
  linear_predictions,
  truth = pct,
  estimate = .pred
)

#Create mean occupancy baseline
mean_occupancy <- mean(
  train_data$pct,
  na.rm = TRUE
)

baseline_predictions <- test_data %>%
  mutate(
    .pred = mean_occupancy
  )

baseline_results <- metric_set(
  rmse,
  mae
)(
  baseline_predictions,
  truth = pct,
  estimate = .pred
)

#Compare models
comparison <- bind_rows(
  nonlinear_results %>%
    mutate(
      model = "Nonlinear Regression"
    ),

  linear_results %>%
    mutate(
      model = "Linear Regression"
    ),

  baseline_results %>%
    mutate(
      model = "Mean Baseline"
    )
) %>%
  select(
    model,
    .metric,
    .estimate
  )

cat("\nRegression Model Comparison\n")

print(
  comparison
)