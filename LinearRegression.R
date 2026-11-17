##linear regression for parking
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

    #Used for stratified splitting
    isFull = factor(pct >= 1)
  ) %>%
  filter(
    !is.na(pct),
    !is.na(numeric_time),
    !is.na(day_of_week),
    !is.na(region)
  )

#Occupancy values above 100% are retained

set.seed(12345); #For reproduction

#Split data for training and testing
split <- initial_split(
  rotated_df,
  prop = 0.8,
  strata = isFull
)

train_data <- training(split)
test_data <- testing(split)

#Create 10-fold cross-validation
folds <- vfold_cv(
  train_data,
  v = 10,
  strata = isFull
)

#Create linear regression recipe
parkingRecipeLinear <- recipe(
  pct ~ numeric_time + day_of_week + region,
  data = train_data
) |>
  step_dummy(
    all_nominal_predictors()
  )

#Create linear regression model
parkingLinear <- linear_reg(
  mode = "regression"
) |>
  set_engine("lm")

#Create workflow
parkingLinearWorkflow <- workflow() |>
  add_recipe(parkingRecipeLinear) |>
  add_model(parkingLinear)

#10-fold cross-validation
linear_cv <- fit_resamples(
  parkingLinearWorkflow,
  resamples = folds,
  metrics = metric_set(
    rmse,
    rsq,
    mae
  )
)

cat("\nLinear Regression 10-Fold Cross-Validation Results\n")

print(
  collect_metrics(linear_cv)
)

#Fit final linear regression model
linear_fit <- parkingLinearWorkflow |>
  fit(
    data = train_data
  )

#Predict test data
linear_predictions <- augment(
  linear_fit,
  test_data
)

#Show test results
linear_results <- metric_set(
  rmse,
  rsq,
  mae
)(
  linear_predictions,
  truth = pct,
  estimate = .pred
)

cat("\nLinear Regression Test Results\n")

print(
  linear_results
)

#Actual vs predicted plot
linear_predictions |>
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
    title = "Linear Regression",
    x = "Actual Occupancy",
    y = "Predicted Occupancy"
  ) +
  theme_minimal()

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
  rsq,
  mae
)(
  baseline_predictions,
  truth = pct,
  estimate = .pred
)

cat("\nMean Occupancy Baseline Results\n")

cat(
  "Mean Training Occupancy:",
  round(mean_occupancy, 4),
  "\n"
)

print(
  baseline_results
)

#Compare linear regression to baseline
comparison <- bind_rows(
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

cat("\nLinear Regression Model Comparison\n")

print(
  comparison
)