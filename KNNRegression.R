##knn for parking
library(tidymodels)
library(kknn)

##Adjust features
rotated_df <- rotated_df %>% mutate(numeric_time = case_when(
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
))

set.seed(12345); #For reproduction

#Split data for training, validation, and testing
split <- initial_split(rotated_df %>% filter(!is.na(pct)) %>% mutate(pct = ifelse(pct > 1, 1, pct)), prop = 0.8, strata = isFull)
train_data <- training(split)
test_data <- testing(split)

folds <- vfold_cv(train_data, v=10, strata = isFull)

#Create default model and worflow
parkingKNNReg <- nearest_neighbor(mode="regression", neighbors = 5, weight_func = "rectangular")
parkingRecipeReg <- recipe(pct ~ numeric_time + day_of_week + region, data = train_data) |> step_normalize(all_numeric_predictors()) |> step_dummy(all_nominal_predictors())
parkingWorkflowReg <- workflow() |> add_recipe(parkingRecipeReg) |> add_model(parkingKNNReg)

parkingRegFit <- fit(parkingWorkflowReg, train_data)
testPredReg <- augment(parkingRegFit, test_data)
testPredReg |>
  ggplot(aes(x = pct, y = .pred)) + 
  geom_point()

#Function for using validation set
val_rmse <- function(k) {
  model <- nearest_neighbor(mode = "regression",
                            neighbors = k, weight_func = "rectangular")
  wf <- workflow() |> add_recipe(parkingRecipeReg) |>
    add_model(model)
  
  res_fit <- fit_resamples(wf, resamples = folds, metrics = metric_set(rmse))
  collect_metrics(res_fit)$mean
}

#Use validation set to find best k
ks <- seq(1, 51, by=2)
errs <- sapply(ks, val_rmse)
best_k <- ks[which.min(errs)]

#Fit best k
final_reg_model <- nearest_neighbor(mode="regression", neighbors = best_k, weight_func = "rectangular")
final_fit_reg <- workflow() |> add_recipe(parkingRecipeReg) |> add_model(final_reg_model) |> fit(data=train_data)

finalTestPredReg <- augment(final_fit_reg, test_data)
best_k

#Show results using best k
finalTestPredReg |>
  ggplot(aes(x = pct, y = .pred)) + 
  geom_point()

metrics <- metric_set(rmse, rsq) 
metrics(finalTestPredReg, pct, .pred)
