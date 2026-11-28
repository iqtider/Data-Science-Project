##linear regression for parking
library(tidymodels)

##Load prepared parking data
source("Parking.R")

# FIX: Single metric set for cross-validation
regression_metrics <- metric_set(rmse, mae, rsq_trad)

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

    #FIX: Cap occupancy at 100% for regression (even for values above 100%)
    pct = pmin(pct, 1)
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

#Create linear regression recipe (FIX: remove any all zeros columns)
parkingRecipeLinear <- recipe(
  pct ~ numeric_time + day_of_week + region + log_inventory,
  data = train_data
) |>
  step_dummy(
    all_nominal_predictors()
  )  |>
  step_zv(
    all_predictors()
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
  metrics = regression_metrics # was metric_set(rmse, rsq, mae)
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
cat("\nLinear Regression Coefficients\n")  #FIX: Prints out fitted coefficients
print(tidy(linear_fit), n = Inf)

#Predict test data
linear_predictions <- augment(
  linear_fit,
  test_data
)

#Show test results (FIX: used the shared metric set)
linear_results <- regression_metrics(
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
  theme_minimal() + 
  coord_equal(xlim = c(0, 1), ylim = c(0, 1))

#Create mean occupancy baseline
mean_occupancy <- mean(
  train_data$pct,
  na.rm = TRUE
)

baseline_predictions <- test_data %>%
  mutate(
    .pred = mean_occupancy
  )

# FIX: used the shared metric set
baseline_results <- regression_metrics(
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
  )   %>%
  pivot_wider(names_from = .metric, values_from = .estimate) %>%
  #FIX: Round to 3 digits to maintain consistency as the other rows
  mutate(across(c(rmse, mae, rsq_trad), ~ signif(.x, 3)))

cat("\nLinear Regression Model Comparison\n")

print(
  comparison
)