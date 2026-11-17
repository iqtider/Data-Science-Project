# Team Update

Hey guys,

I went through the repo and cleaned up the modeling side so everything is more consistent for Deliverable 2 and so we can actually compare the models fairly.

The goal was not to rewrite anyone's work. The model choices and general approaches that were already in the repo were kept. Most of the changes were things we needed across the whole project for consistency, reproducibility, and evaluation.

## Main Changes

Across the project, the main changes were:

- using the same random seed, `12345`
- using the same general 80/20 train/test setup
- using stratified splitting where appropriate
- using 10-fold cross-validation for validation and tuning
- making the model scripts runnable on their own
- keeping the treatment of occupancy values consistent
- adding common evaluation metrics
- adding simple baseline models
- making sure preprocessing matches the type of model being used
- cleaning up package requirements
- updating the README with run instructions
- finishing the Methods and Tools/Reproducibility sections for Deliverable 2

A lot of this sounds small, but it matters because otherwise we could end up comparing models that were trained or evaluated under different conditions.

---

# Why the Consistency Changes Matter

## Why We Use the Same Random Seed

The project uses:

```r
set.seed(12345)
```

A random seed makes operations such as train/test splitting and cross-validation reproducible.

Without a fixed seed, running the same script again could create a slightly different training set and test set.

That means a model's score could change simply because it received different data.

Using the same seed helps make sure that when we compare models, the difference is coming from the model itself rather than from a different random split.

---

## Why We Use the Same Train/Test Setup

The general setup is:

```text
80% training
20% testing
```

The training portion is used to build the model.

The test portion is kept separate until the model is ready to be evaluated.

This is important because evaluating a model on the same data it was trained on would make the model look better than it really is.

The held-out test set gives us a better idea of how the model performs on observations it did not see during training.

Keeping the same general split across models also makes the comparisons more meaningful.

---

## Why We Use Stratification

The classification data contain many more `NotFull` observations than `Full` observations.

Because of that, the train/test split is stratified by the full/not-full class.

Stratification helps maintain roughly the same class proportions in the training and test sets.

Without stratification, a random split could accidentally put too many of the less common `Full` observations into one side of the split.

That would make evaluation less stable and could make two models harder to compare fairly.

We also use the full/not-full status for stratification in the regression files so the higher-occupancy observations stay represented in both training and testing.

---

## Why We Use 10-Fold Cross-Validation

A single train/test split tells us how the model performs on one particular division of the data.

For tuning, that is not always enough.

With 10-fold cross-validation, the training data are divided into 10 sections. The model trains on 9 sections and validates on the remaining section, and this process is repeated until each section has been used for validation.

This gives us a more stable estimate of model performance than choosing parameters from one validation split.

We use this for things such as:

- choosing `k` in kNN
- choosing the SVM cost
- checking model performance before evaluating the final model on the held-out test set

---

# Important Decision About Occupancy Above 100%

Some observations in the original dataset have occupancy slightly above 100%.

This happens when the recorded number of vehicles is greater than the listed parking inventory.

For example, if a location has:

```text
20 listed spaces
21 observed vehicles
```

then the occupancy is:

```text
21 / 20 = 1.05 = 105%
```

An earlier version of some regression code capped anything above 100% back to 100%.

That was removed.

## Why We Did Not Cap These Values

There are a few reasons this matters.

### 1. The Values Are Part of the Original Observed Data

The dataset actually recorded more vehicles than the listed capacity for a small number of observations.

That could represent things such as:

- vehicles parked outside designated spaces
- differences between listed inventory and actual usable parking
- observation or counting differences
- legitimate over-capacity parking behavior

We do not have enough evidence to say that every value above 100% is an error.

Because of that, we decided during EDA to retain them.

### 2. Capping Them Changes the Target Variable

For regression, the model is trying to predict the actual recorded occupancy percentage.

If the data contain:

```text
105%
```

and we change that to:

```text
100%
```

we are no longer modeling the original observation.

### 3. Capping Removes Information

Suppose one observation is:

```text
105%
```

and another is:

```text
110%
```

If both are capped at 100%, they become identical to the regression model.

That removes information about how far above the listed capacity the location actually was.

### 4. It Could Make Regression Error Look Better Than It Really Is

If we reduce the highest observations before testing the models, the model no longer has to predict those larger values.

That can make RMSE and MAE slightly easier to achieve.

We want the evaluation to reflect the original target values rather than a simplified version of them.

### 5. It Keeps the Code Consistent With the Report

The EDA/report already explains that these observations were retained.

Keeping them in the regression models makes the code agree with the data-cleaning decision we documented.

## Why This Matters Less for Classification

For classification, we only care whether the occupancy crosses the threshold:

```text
Full = occupancy >= 100%
```

So:

```text
100%
105%
110%
```

are all simply:

```text
Full
```

The exact value above 100% matters much more for regression than classification.

---

# Why We Use Baseline Models

We added simple baselines so we know whether the more complicated models are actually doing anything useful.

Without a baseline, saying:

```text
Accuracy = 82%
```

or:

```text
RMSE = 0.29
```

does not tell us very much by itself.

We need something simple to compare against.

## Regression Baseline

The regression baseline predicts the average occupancy from the training data for every test observation.

If a more advanced model cannot beat that, then the advanced model is not providing much value.

## Classification Baseline

The classification baseline predicts the majority class every time.

In our data, that means predicting:

```text
NotFull
```

for every observation.

This baseline becomes especially important because of the class imbalance.

---

# Why Accuracy Alone Is Misleading

This is probably one of the most important things we found.

The majority baseline gets approximately:

```text
Accuracy = 81.6%
```

That sounds good at first.

But it does that by predicting:

```text
NotFull
```

for every single observation.

Its recall for actual `Full` observations is:

```text
0%
```

So an 81.6% accurate model can still be completely useless at identifying full parking conditions.

That is why we are also looking at:

- precision
- recall
- specificity
- F1
- balanced accuracy
- ROC-AUC

For this project, recall and balanced accuracy are especially useful because we care about whether the model actually detects the less common `Full` class.

---

# Why Some Models Need Normalization

kNN and SVM depend on the numerical scale of their predictors more directly than models such as decision trees.

For example, suppose one predictor ranged from:

```text
1 to 1000
```

and another ranged from:

```text
0 to 1
```

The large-scale variable could dominate the distance calculation even if it is not actually more important.

Normalization puts numeric predictors onto a comparable scale.

That is why normalization is used where the model requires it rather than being applied blindly to every model.

Decision trees and random forests do not require the same type of scaling because they split variables using thresholds rather than distance calculations.

---

# Why We Use Dummy Variables

Models such as kNN cannot directly calculate distances using categories such as:

```text
Thursday
Saturday
Sunday
```

or geographic region names.

Those categories are converted into numeric indicator columns, also called dummy variables.

For example, instead of one text column for day of week, the model can receive separate numeric indicators representing the different days.

This lets the model use categorical information without pretending that the category names themselves are numeric values.

---

# Why the SVM Uses Class Weighting

Most of the classification models naturally favor the majority `NotFull` class.

That is why several of them achieve around 82% accuracy but have very low recall for `Full`.

The SVM uses class weighting to make mistakes on the less common `Full` observations more costly during training.

The approximate weight for the `Full` class was:

```text
4.4365
```

This does not mean the SVM is automatically better.

It changes the tradeoff.

The weighted SVM predicts `Full` more aggressively, which:

- increases recall
- increases F1
- increases balanced accuracy

but also creates more false positives and reduces overall accuracy.

That tradeoff is visible in our current results.

---

# Why the SVM Was Tuned With Balanced Accuracy

If we tuned the SVM using only raw accuracy, the model would be rewarded heavily for predicting the majority class correctly.

Balanced accuracy considers both classes.

That makes it a better tuning metric for this particular dataset because `Full` and `NotFull` are not equally common.

The tested SVM cost values were:

```text
0.01
0.1
1
10
100
```

The best value was:

```text
Cost = 1
```

---

# Why kNN Tests Multiple Values of k

The value of `k` controls how many neighboring observations the model considers.

A very small `k` can make the model overly sensitive to individual observations.

A very large `k` can smooth the model too much.

Instead of choosing a value randomly, the scripts test:

```text
1, 3, 5, ... 51
```

using cross-validation.

For classification, the best `k` is selected using ROC-AUC.

For regression, the best `k` is selected using RMSE.

Current results:

```text
kNN Classification: k = 51
kNN Regression: k = 47
```

---

# Current Models

## Regression

We currently have:

- Linear Regression
- Nonlinear Regression
- kNN Regression
- Decision Tree Regression
- Random Forest Regression

## Classification

We currently have:

- Logistic Regression
- kNN Classification
- Decision Tree Classification
- Random Forest Classification
- Weighted SVM Classification

The main predictors currently being used are:

- time of day
- day of week
- geographic region

For classification:

```text
Full = occupancy >= 100%
NotFull = occupancy < 100%
```

---

# Current Regression Results

| Model | RMSE | R-squared | MAE |
|---|---:|---:|---:|
| Mean Baseline | 0.326 | NA | 0.266 |
| Linear Regression | 0.302 | 0.140 | 0.239 |
| Nonlinear Regression | 0.299 | 0.162 | 0.236 |
| Decision Tree | 0.300 | 0.155 | 0.238 |
| Random Forest | 0.290 | 0.211 | **0.227** |
| kNN, k = 47 | **0.289** | **0.214** | 0.228 |

The tuned kNN model and Random Forest are extremely close.

kNN currently has:

```text
Lowest RMSE = 0.289
Highest R-squared = 0.214
```

Random Forest currently has:

```text
Lowest MAE = 0.227
```

The nonlinear regression also performs slightly better than the normal linear regression.

That suggests allowing a curved relationship with time gives some improvement, although the difference is fairly small.

---

# Current Classification Results

| Model | Accuracy | Precision | Recall | Specificity | F1 | Balanced Accuracy | ROC-AUC |
|---|---:|---:|---:|---:|---:|---:|---:|
| Majority Baseline | 0.816 | NA | 0.000 | 1.000 | NA | 0.500 | NA |
| Logistic Regression | 0.819 | 0.545 | 0.112 | 0.979 | 0.186 | 0.545 | 0.716 |
| kNN, k = 51 | 0.822 | 0.603 | 0.101 | 0.985 | 0.174 | 0.543 | 0.718 |
| Decision Tree | 0.824 | 0.583 | 0.160 | 0.974 | 0.251 | 0.567 | 0.659 |
| Random Forest | **0.826** | **0.618** | 0.147 | 0.980 | 0.237 | 0.563 | **0.729** |
| Weighted SVM | 0.678 | 0.319 | **0.659** | 0.683 | **0.430** | **0.671** | NA |

The biggest takeaway so far is that raw accuracy does not tell the whole story.

The Random Forest has the highest raw accuracy and ROC-AUC among the models where ROC-AUC was calculated.

The weighted SVM has much stronger:

```text
Recall = 65.9%
F1 = 43.0%
Balanced Accuracy = 67.1%
```

So it is currently much better at identifying actual full parking observations.

---

# Installing the R Packages

The repository contains:

```text
requirements.R
```

Run:

```powershell
Rscript --vanilla .\requirements.R
```

or inside RStudio:

```r
source("requirements.R")
```

The current main packages are:

```text
tidyverse
tidymodels
kknn
rpart
ranger
LiblineaR
```

---

# Running the Files

Open PowerShell or another terminal in the repository folder.

## Data Cleaning / EDA

```powershell
Rscript --vanilla .\Parking.R
```

## Linear Regression

```powershell
Rscript --vanilla .\LinearRegression.R
```

## Nonlinear Regression

```powershell
Rscript --vanilla .\NonlinearRegression.R
```

## Logistic Regression

```powershell
Rscript --vanilla .\LogisticRegression.R
```

## kNN Regression

```powershell
Rscript --vanilla .\KNNRegression.R
```

## kNN Classification

```powershell
Rscript --vanilla .\KNNClassification.R
```

## Decision Tree / Random Forest Regression

```powershell
Rscript --vanilla .\DecisionTreeRegression.R
```

## Decision Tree / Random Forest Classification

```powershell
Rscript --vanilla .\DecisionTreeClassification.R
```

## SVM Classification

```powershell
Rscript --vanilla .\SVMClassification.R
```

If `Rscript` is not recognized, the files can also be run through RStudio.

---

# Deliverable 2

The current Deliverable 2 source is:

```text
docs/CSC3220 Team8 Deliverable2.qmd
```

It now contains:

1. Problem Statement and Background
2. Data and Exploratory Analysis
3. Methods
4. Tools and Reproducibility

The full Results section will be completed for the final report.

To build the PDF:

```powershell
quarto render "docs/CSC3220 Team8 Deliverable2.qmd"
```

---

# Git Commands

Before starting work:

```powershell
git status
```

Before editing shared files:

```powershell
git pull origin main
```

After editing:

```powershell
git status
```

To see exactly what changed:

```powershell
git diff
```

This should help us avoid accidentally overwriting each other's work.

---

# R Version Warnings

The project is currently running with:

```text
R 4.6.1
```

Some packages were built under:

```text
R 4.6.2
```

You may see warnings such as:

```text
package 'kknn' was built under R version 4.6.2
```

Those warnings have not stopped the models from running.

If the script continues and produces results, it is a version warning rather than a failed model run.

---

# Where We Are Now

At this point, all of the model families we planned are running and producing comparable results.

For Deliverable 2, we now have:

- updated Sections 1 and 2
- completed Methods
- completed Tools and Reproducibility
- working regression models
- working classification models
- common evaluation metrics
- baseline comparisons
- reproducible setup
- requirements file
- updated README
- run instructions

After Deliverable 2, the next major step will be using these results to build the final report's Results section, model comparison plots, conclusions, and appendix.