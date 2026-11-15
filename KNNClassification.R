##knn for parking
library(tidymodels)
library(kknn)

##Adjust features
rotated_df$isFull <- rotated_df$pct >= 1
rotated_df <- rotated_df %>% mutate(isFull = factor(isFull, levels = c(1, 0)))
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
split <- initial_split(rotated_df, prop = 0.8, strata = isFull)
train_data <- training(split)
test_data <- testing(split)

folds <- vfold_cv(train_data, v=10, strata = isFull)

#Create default model and worflow
parkingKNNClass <- nearest_neighbor(mode="classification", neighbors = 5, weight_func = "rectangular")
parkingRecipe <- recipe(isFull ~ numeric_time + day_of_week + region, data = train_data) |> step_normalize(all_numeric_predictors()) |> step_dummy(all_nominal_predictors())
parkingWorkflow <- workflow() |> add_recipe(parkingRecipe) |> add_model(parkingKNNClass)

parkingClassFit <- fit_resamples(parkingWorkflow, resamples = folds, metrics = metric_set(accuracy, roc_auc, recall))
collect_metrics(parkingClassFit)

#Function for using validation set
#Uses k-folds
val_class <- function(k) {
  model <- nearest_neighbor(mode = "classification",
                            neighbors = k, weight_func = "rectangular")
  wf <- workflow() |> add_recipe(parkingRecipe) |>
    add_model(model)
  fit_res <- fit_resamples(wf, resamples = folds, metrics = metric_set(roc_auc))
  collect_metrics(fit_res)$mean
}

#Use validation set to find best k
ks <- seq(1, 51, by=2)
scores <- sapply(ks, val_class)
best_k <- ks[which.max(scores)]

#Fit best k
final_class_model <- nearest_neighbor(mode="classification", neighbors = best_k, weight_func = "rectangular")
final_fit <- workflow() |> add_recipe(parkingRecipe) |> add_model(final_class_model) |> fit(data=train_data)

testPredClass <- augment(final_fit, test_data)
best_k

#Show results using best k
conf_mat(testPredClass, truth = isFull, estimate = .pred_class)
testPredClass |> roc_auc(isFull, .pred_1)
