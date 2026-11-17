# Predicting Urban Parking Occupancy in San Diego

CSC 3220 - Fundamentals of Data Science  
Team 8

## Team Members

- Joseph Dye
- Taseen Iqtider
- James Finnegan
- Matthew Richardson

## Project Overview

This project examines whether parking occupancy in San Diego can be predicted using information such as:

- time of day
- day of week
- geographic region
- parking location information

The project uses parking data from the City of San Diego Parking Demand Management Study.

We are working with two related prediction problems:

1. **Regression** - predict the parking occupancy percentage.
2. **Classification** - predict whether a parking location is full or not full.

For classification, an observation is considered `Full` when the recorded occupancy is at or above 100 percent.

---

# Repository Files

## Main Data and Analysis

### `Parking.R`

This is the main data preparation and exploratory analysis file.

It:

- loads the parking dataset
- checks missing values and data types
- removes locations with zero parking inventory
- examines unusual capacity and occupancy values
- reshapes hourly occupancy data from wide format to long format
- prepares day, time, neighborhood, and region information
- creates exploratory plots used in the report

Most model files use:

```r
source("Parking.R")
```

so that the same prepared data are used throughout the project.

---

# Regression Models

### `LinearRegression.R`

Taseen's linear regression model.

Predicts parking occupancy percentage using:

- time of day
- day of week
- region

It also compares the model against a mean occupancy baseline.

### `NonlinearRegression.R`

Taseen's nonlinear regression model.

This uses the same main predictors as linear regression, but also includes a squared time term.

The squared term allows the model to represent a curved occupancy pattern across the day instead of assuming that occupancy changes in one straight line.

### `KNNRegression.R`

Joseph's k-nearest neighbors regression model.

The original kNN approach was retained, including:

- normalization
- dummy variables
- rectangular weighting
- 10-fold cross-validation
- testing odd values of `k` from 1 through 51
- selecting the best `k` using RMSE

Current best value:

```text
k = 47
```

### `DecisionTreeRegression.R`

James's regression models.

Contains:

- decision tree regression
- random forest regression

Both are evaluated using the same held-out test data and regression metrics used by the other models.

---

# Classification Models

### `LogisticRegression.R`

Taseen's logistic regression model.

This serves as a simple classification model and provides a useful comparison against the more complex classifiers.

### `KNNClassification.R`

Joseph's k-nearest neighbors classification model.

The original kNN approach was retained, including:

- normalization
- dummy variables
- rectangular weighting
- 10-fold cross-validation
- testing odd values of `k` from 1 through 51

Classification `k` is selected using ROC-AUC.

Current best value:

```text
k = 51
```

### `DecisionTreeClassification.R`

James's classification models.

Contains:

- decision tree classification
- random forest classification

The models are evaluated using several metrics because the classification dataset is imbalanced.

### `SVMClassification.R`

Matthew's support vector machine classification model.

The SVM uses:

- a linear SVM
- `LiblineaR`
- an 80/20 stratified train/test split
- 10-fold cross-validation
- class weighting
- cost tuning

Class weighting is used because `Full` observations are much less common than `NotFull` observations.

Current best SVM cost:

```text
Cost = 1
```

---

# Data Files

### `parking_study_occupancy_datasd.csv`

Original City of San Diego parking occupancy dataset.

### `parking_with_regions.csv`

Parking dataset with additional geographic region information added for analysis.

---

# Project Requirements

## `requirements.R`

The project includes a requirements script that checks whether the required R packages are installed and installs any that are missing.

Current project packages include:

- `tidyverse`
- `tidymodels`
- `kknn`
- `rpart`
- `ranger`
- `LiblineaR`

The project was developed and tested with:

```text
R 4.6.1
```

Some installed packages may display a warning saying that they were built under a slightly newer version of R.

For example:

```text
package 'kknn' was built under R version 4.6.2
```

These warnings did not prevent the project scripts from running successfully.

---

# Getting Started

Clone or download the repository, then open a terminal or PowerShell window in the project folder.

If using Git:

```powershell
git clone https://github.com/iqtider/Data-Science-Project.git
```

Then move into the repository:

```powershell
cd Data-Science-Project
```

If the repository has already been cloned, simply open a terminal in the existing project directory.

---

# Installing the Requirements

From the project directory, run:

```powershell
Rscript --vanilla .\requirements.R
```

The script will check the required packages and install any that are missing.

The requirements file can also be run from inside R or RStudio:

```r
source("requirements.R")
```

If `Rscript` is not recognized as a command, either:

- run the script from RStudio, or
- use the full path to the local R installation

The exact installation path depends on the computer and should not be hard-coded into the project.

---

# Running the Project

All commands below assume the terminal is already open in the repository root.

## Run the Data Preparation and EDA

```powershell
Rscript --vanilla .\Parking.R
```

## Run Linear Regression

```powershell
Rscript --vanilla .\LinearRegression.R
```

## Run Nonlinear Regression

```powershell
Rscript --vanilla .\NonlinearRegression.R
```

## Run Logistic Regression

```powershell
Rscript --vanilla .\LogisticRegression.R
```

## Run kNN Regression

```powershell
Rscript --vanilla .\KNNRegression.R
```

## Run kNN Classification

```powershell
Rscript --vanilla .\KNNClassification.R
```

## Run Decision Tree and Random Forest Regression

```powershell
Rscript --vanilla .\DecisionTreeRegression.R
```

## Run Decision Tree and Random Forest Classification

```powershell
Rscript --vanilla .\DecisionTreeClassification.R
```

## Run SVM Classification

```powershell
Rscript --vanilla .\SVMClassification.R
```

---

# Modeling Setup

The current modeling workflow uses:

```text
80% training data
20% test data
10-fold cross-validation
Random seed = 12345
```

The project uses:

```r
set.seed(12345)
```

to make the train/test splits and validation procedures reproducible.

The main predictors currently used by the models are:

- numeric time of day
- day of week
- geographic region

Models that require numeric inputs convert categorical predictors into dummy variables.

kNN and SVM models normalize numeric predictors when required.

---

# Regression Evaluation

Regression models are evaluated using:

### RMSE

Root Mean Squared Error.

Lower values are better.

### MAE

Mean Absolute Error.

Lower values are better.

### R-squared

Measures how much variation in parking occupancy is explained by the model.

Higher values are better.

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

The tuned kNN regression and random forest are currently very close.

kNN has:

- the lowest RMSE
- the highest R-squared

Random forest has:

- the lowest MAE

The nonlinear regression also slightly improves over regular linear regression.

---

# Classification Evaluation

Classification models are evaluated using:

- accuracy
- precision
- recall
- specificity
- F1 score
- balanced accuracy
- confusion matrix
- ROC-AUC when available

Accuracy is not used by itself because the classification data are imbalanced.

Most observations are `NotFull`, which means a model can receive high accuracy simply by predicting `NotFull` most of the time.

For this reason, recall, F1 score, balanced accuracy, and ROC-AUC are also important.

---

# Current Classification Results

| Model | Accuracy | Precision | Recall | Specificity | F1 | Balanced Accuracy | ROC-AUC |
|---|---:|---:|---:|---:|---:|---:|---:|
| Majority Baseline | 0.816 | NA | 0.000 | 1.000 | NA | 0.500 | NA |
| Logistic Regression | 0.819 | 0.545 | 0.112 | 0.979 | 0.186 | 0.545 | 0.716 |
| kNN, k = 51 | 0.822 | 0.603 | 0.101 | 0.985 | 0.174 | 0.543 | 0.718 |
| Decision Tree | 0.824 | 0.583 | 0.160 | 0.974 | 0.251 | 0.567 | 0.659 |
| Random Forest | **0.826** | 0.618 | 0.147 | 0.980 | 0.237 | 0.563 | **0.729** |
| Weighted SVM | 0.678 | 0.319 | **0.659** | 0.683 | **0.430** | **0.671** | NA |

The majority baseline receives about 81.6 percent accuracy even though it never correctly predicts a `Full` observation.

The weighted SVM behaves differently from the other classifiers.

It has lower raw accuracy, but much stronger:

- recall
- F1 score
- balanced accuracy

This means it is currently much better at identifying actual full parking observations.

---

# Important Data Decision

Some recorded occupancy values are slightly above 100 percent.

These values were reviewed during exploratory analysis and were retained instead of automatically being treated as errors.

Because of that decision, regression scripts should not cap:

```text
pct > 1
```

to:

```text
pct = 1
```

Earlier versions of some regression scripts did this. That cap has been removed so the modeling code matches the data-cleaning decisions described in the report.

---

# Team Code Integration

The goal of the model cleanup was not to rewrite another team member's work.

Where code already existed, we retained:

- the original model
- the original modeling approach
- the original tuning strategy
- the general structure and coding style

Changes were made only where needed for things such as:

- making scripts independently runnable
- using the same train/test approach
- using the same random seed
- keeping occupancy handling consistent
- adding common evaluation metrics
- adding baseline comparisons
- making results easier to compare across models

A more detailed explanation of these changes will be kept in the team update document.

---

# Deliverable 2

The Deliverable 2 Quarto source is located at:

```text
docs/CSC3220 Team8 Deliverable2.qmd
```

Deliverable 2 contains:

1. Problem Statement and Background
2. Data and Exploratory Analysis
3. Methods
4. Tools and Reproducibility

The formal Results section will be completed for the final report.

---

# Rendering Deliverable 2

Quarto must be installed before rendering the report.

From the repository root:

```powershell
quarto render "docs/CSC3220 Team8 Deliverable2.qmd"
```

The rendered PDF should appear in the `docs` folder.

If `quarto` is not recognized as a command, verify that Quarto is installed and available on the system PATH.

The exact Quarto installation path depends on the computer and should not be hard-coded into the repository.

---

# Git Workflow

Before beginning new work, check whether the local repository has changes:

```powershell
git status
```

Before editing shared files, retrieve the latest version from GitHub:

```powershell
git pull origin main
```

After making changes, check the repository again:

```powershell
git status
```

Review the actual changes before committing:

```powershell
git diff
```

This is especially important in a team repository so that another team member's work is not accidentally overwritten.

---

# General Troubleshooting

## `Rscript` is not recognized

Either:

- run the R files through RStudio, or
- add the local R installation to the system PATH

A full R installation path can also be used locally, but personal computer paths should not be committed to the shared repository.

## Missing R package

Run:

```powershell
Rscript --vanilla .\requirements.R
```

or from R:

```r
source("requirements.R")
```

## Package built under a newer R version

Warnings such as:

```text
package 'kknn' was built under R version 4.6.2
```

have not prevented the models from running.

A warning is different from an error. If the script continues and produces model results, the package loaded successfully.

---

# Data Source

City of San Diego Open Data Portal

Parking Study: counts and percentages of occupied parking spaces

https://data.sandiego.gov/datasets/parking-study-occupancy/