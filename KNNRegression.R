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
split <- group_initial_split(rotated_df %>% filter(!is.na(pct)) %>% mutate(pct = ifelse(pct > 1, 1, pct)), prop = 0.8, group = site_id)
train_data <- training(split)
test_data <- testing(split)

folds <- group_vfold_cv(train_data, v=10, group = site_id)

#Create default model and worflow
parkingKNNReg <- nearest_neighbor(mode="regression", neighbors = 5, weight_func = "rectangular")
parkingRecipeReg <- recipe(pct ~ numeric_time + day_of_week + region + total_inventory, data = train_data) |> step_normalize(all_numeric_predictors()) |> step_dummy(all_nominal_predictors())
parkingWorkflowReg <- workflow() |> add_recipe(parkingRecipeReg) |> add_model(parkingKNNReg)

#parkingRegFit <- fit(parkingWorkflowReg, train_data)
#testPredReg <- augment(parkingRegFit, test_data)
#testPredReg |>
#  ggplot(aes(x = pct, y = .pred)) + 
#  geom_point()

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
best_k #31

#Show results using best k
finalTestPredReg |>
  ggplot(aes(x = pct, y = .pred)) + 
  geom_point() +
  geom_abline(linetype = "dashed", color = "red") +
  coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
  labs(x = "Actual occupancy", y = "Predicted occupancy",
       title = "Predicted vs. actual (test set)") +
  theme_minimal() +
  theme(,
        plot.title    = element_text(size = 20, face = "bold"),
        plot.subtitle = element_text(size = 14),
        axis.title    = element_text(size = 16),   # both x and y axis titles
        axis.text     = element_text(size = 13))

metrics <- metric_set(rmse, rsq_trad, mae) 
metrics(finalTestPredReg, pct, .pred)

#Graphic for best k
tibble(k = ks, rmse = errs) |>
  ggplot(aes(k, rmse)) +
  geom_line() + geom_point() +
  geom_vline(xintercept = best_k, linetype = "dashed") +
  labs(x = "Number of neighbors (k)", y = "Mean CV RMSE", title = "KNN tuning") +
  theme_minimal() +
  theme(
        plot.title    = element_text(size = 20, face = "bold"),
        plot.subtitle = element_text(size = 14),
        axis.title    = element_text(size = 16),   # both x and y axis titles
        axis.text     = element_text(size = 13))

#Baseline comparison
meanOcc <- mean(train_data$pct, na.rm = TRUE)
baseline_reg <- test_data %>% mutate(.pred = meanOcc)
metrics(baseline_reg, pct, .pred)
