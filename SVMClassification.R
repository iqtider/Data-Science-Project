# SVM Classification for Parking Occupancy
# Matthew Richardson
# CSC 3220 - Team 8

# ---------------------------------------------------------
# Package setup
# ---------------------------------------------------------

.libPaths(c(
  file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", "4.6"),
  .libPaths()
))

library(tidymodels)
library(LiblineaR)

# ---------------------------------------------------------
# Load prepared parking data
# ---------------------------------------------------------

source("Parking.R")

# ---------------------------------------------------------
# Prepare features and target
# ---------------------------------------------------------

time_lookup <- c(
  "8_am_pct"  = 8,
  "9_am_pct"  = 9,
  "10_am_pct" = 10,
  "11_am_pct" = 11,
  "12_pm_pct" = 12,
  "1_pm_pct"  = 13,
  "2_pm_pct"  = 14,
  "3_pm_pct"  = 15,
  "4_pm_pct"  = 16,
  "5_pm_pct"  = 17,
  "6_pm_pct"  = 18,
  "7_pm_pct"  = 19,
  "8_pm_pct"  = 20
)

svm_data <- rotated_df %>%
  mutate(
    numeric_time = unname(time_lookup[as.character(time)]),
    log_inventory = log1p(total_inventory),
    day_of_week = factor(day_of_week),
    region = factor(region),
    isFull = factor(
      if_else(pct >= 1, "Full", "NotFull"),
      levels = c("Full", "NotFull")
    )
  ) %>%
  filter(
    !is.na(pct),
    !is.na(numeric_time),
    !is.na(day_of_week),
    !is.na(region),
    !is.na(total_inventory)
  ) %>%
  mutate(
    row_id = row_number()
  )

# ---------------------------------------------------------
# Create common predictor matrix
# ---------------------------------------------------------

x_all <- model.matrix(
  ~ numeric_time + day_of_week + region + log_inventory - 1,
  data = svm_data
)

y_all <- svm_data$isFull

# ---------------------------------------------------------
# Site-grouped 80/20 train-test split
# ---------------------------------------------------------

set.seed(12345)

split <- group_initial_split(
  svm_data,
  group = site_id,
  prop = 0.8
)

train_data <- training(split)
test_data <- testing(split)

train_index <- train_data$row_id
test_index <- test_data$row_id

x_train_raw <- x_all[
  train_index,
  ,
  drop = FALSE
]

x_test_raw <- x_all[
  test_index,
  ,
  drop = FALSE
]

y_train <- y_all[train_index]
y_test <- y_all[test_index]

cat("\nTraining Sites:", n_distinct(train_data$site_id), "\n")
cat("Testing Sites:", n_distinct(test_data$site_id), "\n")
cat(
  "Shared Sites:",
  length(intersect(unique(train_data$site_id), unique(test_data$site_id))),
  "\n"
)

cat("\nTraining Class Distribution\n")
print(table(y_train))

cat("\nTesting Class Distribution\n")
print(table(y_test))

# ---------------------------------------------------------
# Helper function: normalize using training subset only
# ---------------------------------------------------------

normalize_data <- function(train_x, other_x) {

  means <- apply(
    train_x,
    2,
    mean
  )

  sds <- apply(
    train_x,
    2,
    sd
  )

  sds[
    is.na(sds) |
      sds == 0
  ] <- 1

  scaled_train <- sweep(
    train_x,
    2,
    means,
    "-"
  )

  scaled_train <- sweep(
    scaled_train,
    2,
    sds,
    "/"
  )

  scaled_other <- sweep(
    other_x,
    2,
    means,
    "-"
  )

  scaled_other <- sweep(
    scaled_other,
    2,
    sds,
    "/"
  )

  list(
    train = scaled_train,
    other = scaled_other,
    means = means,
    sds = sds
  )
}

# ---------------------------------------------------------
# Helper function: classification metrics
# ---------------------------------------------------------

calculate_metrics <- function(actual, predicted) {

  actual <- factor(
    actual,
    levels = c("Full", "NotFull")
  )

  predicted <- factor(
    predicted,
    levels = c("Full", "NotFull")
  )

  cm <- table(
    Actual = actual,
    Predicted = predicted
  )

  TP <- cm["Full", "Full"]
  TN <- cm["NotFull", "NotFull"]
  FP <- cm["NotFull", "Full"]
  FN <- cm["Full", "NotFull"]

  accuracy <- (
    TP + TN
  ) / sum(cm)

  precision <- ifelse(
    TP + FP == 0,
    NA,
    TP / (TP + FP)
  )

  recall <- ifelse(
    TP + FN == 0,
    NA,
    TP / (TP + FN)
  )

  specificity <- ifelse(
    TN + FP == 0,
    NA,
    TN / (TN + FP)
  )

  f1 <- ifelse(
    is.na(precision) |
      is.na(recall) |
      precision + recall == 0,
    NA,
    2 * precision * recall /
      (precision + recall)
  )

  balanced_accuracy <- mean(
    c(
      recall,
      specificity
    ),
    na.rm = TRUE
  )

  c(
    accuracy = accuracy,
    precision = precision,
    recall = recall,
    specificity = specificity,
    f1 = f1,
    balanced_accuracy = balanced_accuracy
  )
}

# ---------------------------------------------------------
# Site-grouped 10-fold cross-validation
# ---------------------------------------------------------

set.seed(12345)

folds <- group_vfold_cv(
  train_data,
  group = site_id,
  v = 10,
  balance = "observations"
)

# ---------------------------------------------------------
# Tune SVM cost using balanced accuracy
# ---------------------------------------------------------

cost_values <- c(
  0.01,
  0.1,
  1,
  10,
  100
)

cv_results <- data.frame(
  cost = cost_values,
  accuracy = NA_real_,
  precision = NA_real_,
  recall = NA_real_,
  specificity = NA_real_,
  f1 = NA_real_,
  balanced_accuracy = NA_real_
)

for (cost_index in seq_along(cost_values)) {

  fold_metrics <- matrix(
    NA_real_,
    nrow = nrow(folds),
    ncol = 6
  )

  colnames(fold_metrics) <- c(
    "accuracy",
    "precision",
    "recall",
    "specificity",
    "f1",
    "balanced_accuracy"
  )

  for (fold in seq_len(nrow(folds))) {

    fold_train_data <- analysis(
      folds$splits[[fold]]
    )

    fold_validation_data <- assessment(
      folds$splits[[fold]]
    )

    training_rows <- fold_train_data$row_id
    validation_rows <- fold_validation_data$row_id

    fold_x_train_raw <- x_all[
      training_rows,
      ,
      drop = FALSE
    ]

    fold_x_validation_raw <- x_all[
      validation_rows,
      ,
      drop = FALSE
    ]

    fold_y_train <- y_all[training_rows]
    fold_y_validation <- y_all[validation_rows]

    # Normalize using only the current fold's training data
    scaled <- normalize_data(
      fold_x_train_raw,
      fold_x_validation_raw
    )

    fold_x_train <- scaled$train
    fold_x_validation <- scaled$other

    # Calculate class weight using current fold training data only
    fold_full_count <- sum(
      fold_y_train == "Full"
    )

    fold_notfull_count <- sum(
      fold_y_train == "NotFull"
    )

    fold_full_weight <- (
      fold_notfull_count /
        fold_full_count
    )

    # Train weighted linear SVM
    fold_model <- LiblineaR(
      data = fold_x_train,
      target = fold_y_train,
      type = 2,
      cost = cost_values[cost_index],
      wi = c(
        Full = fold_full_weight
      )
    )

    # Predict validation fold
    fold_prediction <- predict(
      fold_model,
      fold_x_validation
    )

    fold_predicted_class <- factor(
      fold_prediction$predictions,
      levels = levels(y_train)
    )

    fold_metrics[
      fold,
    ] <- calculate_metrics(
      fold_y_validation,
      fold_predicted_class
    )
  }

  cv_results[
    cost_index,
    2:7
  ] <- colMeans(
    fold_metrics,
    na.rm = TRUE
  )
}

cat("\nSite-Grouped 10-Fold Cross-Validation Results\n")

print(
  round(
    cv_results,
    4
  )
)

# ---------------------------------------------------------
# Select best cost using balanced accuracy
# ---------------------------------------------------------

best_row <- which.max(
  cv_results$balanced_accuracy
)

best_cost <- cv_results$cost[
  best_row
]

cat(
  "\nBest Cost:",
  best_cost,
  "\n"
)

cat(
  "Best CV Balanced Accuracy:",
  round(
    cv_results$balanced_accuracy[
      best_row
    ],
    4
  ),
  "\n"
)

cat(
  "Best CV F1 Score:",
  round(
    cv_results$f1[
      best_row
    ],
    4
  ),
  "\n"
)

# ---------------------------------------------------------
# Normalize full training set and test set
# ---------------------------------------------------------

final_scaled <- normalize_data(
  x_train_raw,
  x_test_raw
)

x_train <- final_scaled$train
x_test <- final_scaled$other

# ---------------------------------------------------------
# Calculate final class weight
# ---------------------------------------------------------

full_count <- sum(
  y_train == "Full"
)

notfull_count <- sum(
  y_train == "NotFull"
)

full_weight <- (
  notfull_count /
    full_count
)

cat(
  "\nFinal Full Class Weight:",
  round(
    full_weight,
    4
  ),
  "\n"
)

# ---------------------------------------------------------
# Train final weighted linear SVM
# ---------------------------------------------------------

final_svm <- LiblineaR(
  data = x_train,
  target = y_train,
  type = 2,
  cost = best_cost,
  wi = c(
    Full = full_weight
  )
)

# ---------------------------------------------------------
# Predict held-out unseen-site test data
# ---------------------------------------------------------

svm_prediction <- predict(
  final_svm,
  x_test
)

predicted_class <- factor(
  svm_prediction$predictions,
  levels = levels(y_test)
)

# ---------------------------------------------------------
# Confusion matrix and final metrics
# ---------------------------------------------------------

confusion <- table(
  Actual = y_test,
  Predicted = predicted_class
)

cat("\nFinal Test Confusion Matrix\n")
print(confusion)

final_metrics <- calculate_metrics(
  y_test,
  predicted_class
)

cat("\nFinal Unseen-Site Test Results\n")

cat("Accuracy:", round(final_metrics["accuracy"], 4), "\n")
cat("Precision:", round(final_metrics["precision"], 4), "\n")
cat("Recall:", round(final_metrics["recall"], 4), "\n")
cat("Specificity:", round(final_metrics["specificity"], 4), "\n")
cat("F1 Score:", round(final_metrics["f1"], 4), "\n")
cat("Balanced Accuracy:", round(final_metrics["balanced_accuracy"], 4), "\n")

# ---------------------------------------------------------
# Majority-class baseline
# ---------------------------------------------------------

majority_class <- names(
  which.max(
    table(y_train)
  )
)

baseline_predictions <- factor(
  rep(
    majority_class,
    length(y_test)
  ),
  levels = levels(y_test)
)

baseline_metrics <- calculate_metrics(
  y_test,
  baseline_predictions
)

cat("\nMajority-Class Baseline\n")
cat("Predicted Class:", majority_class, "\n")
cat("Accuracy:", round(baseline_metrics["accuracy"], 4), "\n")
cat("Recall:", round(baseline_metrics["recall"], 4), "\n")
cat("Balanced Accuracy:", round(baseline_metrics["balanced_accuracy"], 4), "\n")

cat("\nTraining Observations:", length(y_train), "\n")
cat("Testing Observations:", length(y_test), "\n")
