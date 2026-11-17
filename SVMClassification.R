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

library(LiblineaR)

# ---------------------------------------------------------
# Load parking data
# ---------------------------------------------------------

parking_data <- read.csv(
  "parking_with_regions.csv",
  check.names = FALSE,
  stringsAsFactors = FALSE
)

# Remove locations with no usable parking capacity
parking_data <- parking_data[
  !is.na(parking_data$total_inventory) &
    parking_data$total_inventory > 0,
]

# ---------------------------------------------------------
# Convert hourly percentage columns to long format
# ---------------------------------------------------------

pct_columns <- grep(
  "_pct$",
  names(parking_data),
  value = TRUE
)

n_sites <- nrow(parking_data)

svm_data <- data.frame(
  site_id = rep(
    parking_data$site_id,
    times = length(pct_columns)
  ),

  time = rep(
    pct_columns,
    each = n_sites
  ),

  pct = as.numeric(
    unlist(
      parking_data[pct_columns],
      use.names = FALSE
    )
  ),

  day_of_week = rep(
    parking_data$day_of_week,
    times = length(pct_columns)
  ),

  region = rep(
    parking_data$region,
    times = length(pct_columns)
  )
)

# ---------------------------------------------------------
# Create numeric time variable
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

svm_data$numeric_time <- unname(
  time_lookup[svm_data$time]
)

# ---------------------------------------------------------
# Create classification target
# ---------------------------------------------------------

svm_data$isFull <- ifelse(
  svm_data$pct >= 1,
  "Full",
  "NotFull"
)

svm_data$isFull <- factor(
  svm_data$isFull,
  levels = c("Full", "NotFull")
)

# Remove unusable observations
svm_data <- svm_data[
  !is.na(svm_data$pct) &
    !is.na(svm_data$numeric_time) &
    !is.na(svm_data$day_of_week) &
    !is.na(svm_data$region),
]

svm_data$day_of_week <- factor(
  svm_data$day_of_week
)

svm_data$region <- factor(
  svm_data$region
)

# ---------------------------------------------------------
# Create predictor matrix
# ---------------------------------------------------------

x_all <- model.matrix(
  ~ numeric_time + day_of_week + region - 1,
  data = svm_data
)

y_all <- svm_data$isFull

# ---------------------------------------------------------
# Stratified 80/20 train-test split
# ---------------------------------------------------------

set.seed(12345)

full_rows <- which(
  y_all == "Full"
)

notfull_rows <- which(
  y_all == "NotFull"
)

train_full <- sample(
  full_rows,
  floor(length(full_rows) * 0.80)
)

train_notfull <- sample(
  notfull_rows,
  floor(length(notfull_rows) * 0.80)
)

train_index <- c(
  train_full,
  train_notfull
)

test_index <- setdiff(
  seq_len(nrow(svm_data)),
  train_index
)

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

y_train <- y_all[
  train_index
]

y_test <- y_all[
  test_index
]

cat(
  "\nTraining Class Distribution\n"
)

print(
  table(y_train)
)

cat(
  "\nTesting Class Distribution\n"
)

print(
  table(y_test)
)

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
# Create stratified 10-fold cross-validation assignments
# ---------------------------------------------------------

set.seed(12345)

k <- 10

fold_id <- integer(
  length(y_train)
)

full_train_rows <- which(
  y_train == "Full"
)

notfull_train_rows <- which(
  y_train == "NotFull"
)

full_train_rows <- sample(
  full_train_rows
)

notfull_train_rows <- sample(
  notfull_train_rows
)

fold_id[full_train_rows] <- rep(
  1:k,
  length.out = length(full_train_rows)
)

fold_id[notfull_train_rows] <- rep(
  1:k,
  length.out = length(notfull_train_rows)
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
    nrow = k,
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

  for (fold in 1:k) {

    validation_rows <- which(
      fold_id == fold
    )

    training_rows <- which(
      fold_id != fold
    )

    fold_x_train_raw <- x_train_raw[
      training_rows,
      ,
      drop = FALSE
    ]

    fold_x_validation_raw <- x_train_raw[
      validation_rows,
      ,
      drop = FALSE
    ]

    fold_y_train <- y_train[
      training_rows
    ]

    fold_y_validation <- y_train[
      validation_rows
    ]

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

cat(
  "\n10-Fold Cross-Validation Results\n"
)

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
# Predict held-out test data
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
# Confusion matrix
# ---------------------------------------------------------

confusion <- table(
  Actual = y_test,
  Predicted = predicted_class
)

cat(
  "\nFinal Test Confusion Matrix\n"
)

print(
  confusion
)

# ---------------------------------------------------------
# Final classification metrics
# ---------------------------------------------------------

final_metrics <- calculate_metrics(
  y_test,
  predicted_class
)

cat(
  "\nFinal Test Set Results\n"
)

cat(
  "Accuracy:",
  round(
    final_metrics["accuracy"],
    4
  ),
  "\n"
)

cat(
  "Precision:",
  round(
    final_metrics["precision"],
    4
  ),
  "\n"
)

cat(
  "Recall:",
  round(
    final_metrics["recall"],
    4
  ),
  "\n"
)

cat(
  "Specificity:",
  round(
    final_metrics["specificity"],
    4
  ),
  "\n"
)

cat(
  "F1 Score:",
  round(
    final_metrics["f1"],
    4
  ),
  "\n"
)

cat(
  "Balanced Accuracy:",
  round(
    final_metrics["balanced_accuracy"],
    4
  ),
  "\n"
)

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

cat(
  "\nMajority-Class Baseline\n"
)

cat(
  "Predicted Class:",
  majority_class,
  "\n"
)

cat(
  "Accuracy:",
  round(
    baseline_metrics["accuracy"],
    4
  ),
  "\n"
)

cat(
  "Recall:",
  round(
    baseline_metrics["recall"],
    4
  ),
  "\n"
)

cat(
  "Balanced Accuracy:",
  round(
    baseline_metrics["balanced_accuracy"],
    4
  ),
  "\n"
)

cat(
  "\nTraining Observations:",
  length(y_train),
  "\n"
)

cat(
  "Testing Observations:",
  length(y_test),
  "\n"
)