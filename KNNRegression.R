##knn for parking
library(tidymodels)
library(kknn)

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

    #Used for stratified splitting
    isFull = factor(pct >= 1)
  ) %>%
  filter(
    !is.na(pct),
    !is.na(numeric_time),
    !is.na(day_of_week),
    !is.na(region)
  )

#Occupancy percentages above 100% are retained

set.seed(12345); #For reproduction

#Split data for training, validation, and testing
split <- initial_split(
  rotated_df,
  prop = 0.8,
  strata = isFull
)

train_data <- training(split)
test_data <- testing(split)

folds <- vfold_cv(
  train_data,
  v = 10,
  strata = isFull
)

#Create default model and worflow
parkingKNNReg <- nearest_neighbor(
  mode = "regression",
  neighbors = 5,
  weight_func = "rectangular"
)

parkingRecipeReg <- recipe(
  pct ~ numeric_time + day_of_week + region,
  data = train_data
) |>
  step_normalize(
    all_numeric_predictors()
  ) |>
  step_dummy(
    all_nominal_predictors()
  )

parkingWorkflowReg <- workflow() |>
  add_recipe(parkingRecipeReg) |>
  add_model(parkingKNNReg)

#Fit default k = 5 model
parkingRegFit <- fit(
  parkingWorkflowReg,
  train_data
)

testPredReg <- augment(
  parkingRegFit,
  test_data
)

#Show default model results
cat("\nDefault k = 5 Test Results\n")

print(
  metric_set(
    rmse,
    rsq,
    mae
  )(
    testPredReg,
    truth = pct,
    estimate = .pred
  )
)

#Actual vs predicted plot for default model
testPredReg |>
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
    title = "KNN Regression - Default k = 5",
    x = "Actual Occupancy",
    y = "Predicted Occupancy"
  ) +
  theme_minimal()

#Function for using validation set
#Uses k-folds
val_rmse <- function(k) {

  cat(
    "Testing k =",
    k,
    "\n"
  )

  model <- nearest_neighbor(
    mode = "regression",
    neighbors = k,
    weight_func = "rectangular"
  )

  wf <- workflow() |>
    add_recipe(parkingRecipeReg) |>
    add_model(model)

  res_fit <- fit_resamples(
    wf,
    resamples = folds,
    metrics = metric_set(rmse)
  )

  score <- collect_metrics(
    res_fit
  )$mean

  cat(
    "RMSE =",
    round(score, 4),
    "\n\n"
  )

  return(score)
}

#Use validation set to find best k
ks <- seq(
  1,
  51,
  by = 2
)

cat("\nBeginning k tuning\n\n")

errs <- sapply(
  ks,
  val_rmse
)

best_k <- ks[
  which.min(errs)
]

#Show tuning results
tuning_results <- data.frame(
  k = ks,
  rmse = errs
)

cat("\nKNN Regression Tuning Results\n")

print(
  tuning_results
)

#Fit best k
final_reg_model <- nearest_neighbor(
  mode = "regression",
  neighbors = best_k,
  weight_func = "rectangular"
)

final_fit_reg <- workflow() |>
  add_recipe(parkingRecipeReg) |>
  add_model(final_reg_model) |>
  fit(
    data = train_data
  )

finalTestPredReg <- augment(
  final_fit_reg,
  test_data
)

cat("\nBest k:\n")

print(
  best_k
)

#Show results using best k
final_results <- metric_set(
  rmse,
  rsq,
  mae
)(
  finalTestPredReg,
  truth = pct,
  estimate = .pred
)

cat("\nFinal KNN Regression Results\n")

print(
  final_results
)

#Actual vs predicted plot for best k
finalTestPredReg |>
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
    title = "KNN Regression",
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

#Compare final kNN model to baseline
comparison <- bind_rows(
  final_results %>%
    mutate(
      model = "KNN Regression"
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

cat("\nKNN Regression Model Comparison\n")

print(
  comparison
)