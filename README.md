# Predicting Urban Parking Occupancy in San Diego

CSC 3220 - Fundamentals of Data Science  
Team 8

## Team Members

- Joseph Dye
- Taseen Iqtider
- James Finnegan
- Matthew Richardson

## Project Overview

This project examines whether parking occupancy in San Diego can be predicted using:

- time of day
- day of week
- geographic region
- parking capacity

The project uses parking data from the City of San Diego Parking Demand Management Study.

We are working with two related prediction problems:

1. **Regression** - predict parking occupancy percentage.
2. **Classification** - predict whether a parking observation is full or not full.

For classification, an observation is considered `Full` when occupancy is at or above 100 percent.

---

# Important Evaluation Update After Deliverable 1

Deliverable 1 feedback identified an important issue with the original row-level random train/test split. The same `site_id` appears repeatedly across hours and days, so randomly splitting rows could place observations from the same physical parking location in both training and testing.

The project now uses a **site-grouped 80/20 train/test split**. Every observation from one `site_id` stays entirely in either training or testing.

The training data also use **site-grouped 10-fold cross-validation** so the same type of leakage does not occur during validation or tuning.

The main grouped resampling functions are:

```r
group_initial_split(
  data,
  group = site_id,
  prop = 0.8
)
```

and:

```r
group_vfold_cv(
  train_data,
  group = site_id,
  v = 10,
  balance = "observations"
)
```

This means the held-out test set now evaluates how well a model generalizes to parking sites it did not see during training.

Because the evaluation design and predictor set changed, model scores produced before this update are considered **preliminary** and should not be used as the final model comparison. All model scripts must be rerun under the grouped evaluation design.

---

# Common Modeling Setup

The updated modeling workflow uses:

```text
Approximately 80% of sites for training
Approximately 20% of sites for testing
10-fold site-grouped cross-validation
Random seed = 12345
```

The project uses:

```r
set.seed(12345)
```

The common predictor set is now:

- numeric time of day
- day of week
- geographic region
- log-transformed parking capacity

Parking capacity is represented as:

```r
log_inventory = log1p(total_inventory)
```

The capacity transformation is used because the observed capacities are strongly right-skewed, ranging from 1 to 1,595 spaces. It retains the large parking facilities while reducing the scale difference between typical sites and the largest lots.

Models that require numeric inputs convert categorical predictors into dummy variables. kNN and SVM also normalize numeric predictors because those models are sensitive to predictor scale.

---

# Repository Files

## Data Preparation and EDA

### `Parking.R`

This is the main data preparation and exploratory analysis file.

It:

- loads the parking dataset
- checks missing values and data types
- removes records with zero parking inventory
- examines occupancy values above the listed capacity
- reshapes hourly occupancy data from wide format to long format
- retains `site_id`, `total_inventory`, day, neighborhood, and region
- creates report figures
- summarizes occupancy by geographic region
- summarizes occupancy by parking-capacity group

Most model files use:

```r
source("Parking.R")
```

so the same prepared data are used throughout the project.

### EDA figure changes

After Deliverable 1 feedback:

- the capacity boxplot was replaced with a histogram on a logarithmic x-axis
- figure labels were enlarged
- report figures were numbered and captioned
- the full-capacity chart now uses side-by-side bars instead of stacked bars
- Sunday 8 p.m. missing values are omitted rather than treated as zero

The main report figures are saved in:

```text
docs/images/parking_capacity_histogram.png
docs/images/hourly_occupancy_by_day.png
docs/images/maximum_capacity_by_hour.png
```

---

# Regression Models

### `LinearRegression.R`

Linear regression predicts parking occupancy percentage using the common predictor set and is compared with a mean-occupancy baseline.

### `NonlinearRegression.R`

The nonlinear regression model uses the same common predictors and adds a squared time term so occupancy can follow a curved pattern across the day.

### `KNNRegression.R`

The k-nearest neighbors regression model retains the original kNN approach:

- rectangular weighting
- normalization
- dummy variables
- odd values of `k` from 1 through 51
- RMSE-based tuning

The tuning is now performed using site-grouped cross-validation. The best `k` must be recalculated under the revised evaluation design.

### `DecisionTreeRegression.R`

Contains:

- decision tree regression
- random forest regression

Both now use the common predictor set and site-grouped evaluation.

---

# Classification Models

### `LogisticRegression.R`

Logistic regression provides a simple probabilistic classification model and a comparison for the more complex classifiers.

### `KNNClassification.R`

The k-nearest neighbors classifier retains:

- rectangular weighting
- normalization
- dummy variables
- odd values of `k` from 1 through 51
- ROC-AUC-based tuning

The best `k` must be recalculated with site-grouped cross-validation.

### `DecisionTreeClassification.R`

Contains:

- decision tree classification
- random forest classification

Several metrics are used because `Full` is less common than `NotFull`.

### `SVMClassification.R`

The weighted linear SVM uses:

- `LiblineaR`
- the same prepared data from `Parking.R`
- the same site-grouped train/test split
- site-grouped 10-fold cross-validation
- the common predictor set including log-transformed capacity
- normalization based only on the training data in each fold
- class weighting for the less common `Full` class
- cost tuning using balanced accuracy

The tested cost values remain:

```text
0.01
0.1
1
10
100
```

The best cost must be recalculated under the revised grouped evaluation.

---

# Data Files

### `parking_study_occupancy_datasd.csv`

Original City of San Diego parking occupancy dataset.

### `parking_with_regions.csv`

Parking dataset with additional geographic region information used for analysis and modeling.

---

# Important Data Decisions

## Occupancy Above 100 Percent

Some observations contain slightly more occupied vehicles than the listed inventory. The largest observed difference was six vehicles above listed capacity.

These values are retained instead of being capped at 100 percent.

For regression, capping a value such as 105 percent to 100 percent would change the original target and remove information from the highest-demand observations.

For classification, all values at or above 100 percent are labeled `Full`.

## Missing Sunday 8 p.m. Values

Sunday 8 p.m. occupancy is missing for the Sunday observations in the cleaned data. These missing observations are not converted to zero and are omitted from hourly summaries and figures.

---

# Exploratory Analysis Added After Deliverable 1

## Occupancy by Region

The updated EDA compares mean occupancy across geographic regions because region is used as a predictor.

The regional values are descriptive and are not interpreted as proof that region causes differences in occupancy.

## Occupancy by Parking Capacity

The updated EDA also compares occupancy across capacity groups:

```text
1-5 spaces
6-10 spaces
11-20 spaces
21-50 spaces
51-100 spaces
101+ spaces
```

The observed relationship is not simply monotonic, which supports including capacity as a predictor without assuming that occupancy always rises or falls as capacity increases.

---

# Evaluation Metrics

## Regression

Regression models are evaluated using:

- RMSE
- MAE
- R-squared

A mean-occupancy baseline is also evaluated.

## Classification

Classification models are evaluated using:

- accuracy
- precision
- recall
- specificity
- F1 score
- balanced accuracy
- confusion matrix
- ROC-AUC when available

A majority-class baseline is also evaluated.

Accuracy is not used by itself because the target is imbalanced. A model can receive high accuracy by predicting `NotFull` most of the time while still missing many actual `Full` observations.

---

# Current Result Status

The earlier result tables were produced using a row-level random split.

Those values are now considered preliminary because the revised evaluation:

- holds out entire sites
- groups cross-validation by site
- includes parking capacity as a predictor

Do not combine the old scores with the new scores in one final comparison table.

The model scripts will print the new results when they are rerun. Those grouped-site results should be used for the final report.

---

# Project Requirements

The project includes:

```text
requirements.R
```

Current direct package requirements include:

- `tidyverse`
- `tidymodels`
- `kknn`
- `rpart`
- `ranger`
- `LiblineaR`

The project was developed with:

```text
R 4.6.1
```

Some packages may report that they were built under R 4.6.2. Those warnings have not prevented the scripts from running.

---

# Getting Started

Clone the repository:

```powershell
git clone https://github.com/iqtider/Data-Science-Project.git
```

Move into it:

```powershell
cd Data-Science-Project
```

If the repository is already cloned, retrieve the newest changes before beginning work:

```powershell
git pull origin main
```

---

# Installing Requirements

From the repository root:

```powershell
Rscript --vanilla .\requirements.R
```

or from R/RStudio:

```r
source("requirements.R")
```

If `Rscript` is not recognized, run the script from RStudio or use the local R installation path for that computer. Personal machine paths are not hard-coded into the shared repository.

---

# Running the Project

Run the data preparation and EDA first:

```powershell
Rscript --vanilla .\Parking.R
```

Then run the model files:

```powershell
Rscript --vanilla .\LinearRegression.R
Rscript --vanilla .\NonlinearRegression.R
Rscript --vanilla .\LogisticRegression.R
Rscript --vanilla .\KNNRegression.R
Rscript --vanilla .\KNNClassification.R
Rscript --vanilla .\DecisionTreeRegression.R
Rscript --vanilla .\DecisionTreeClassification.R
Rscript --vanilla .\SVMClassification.R
```

Every revised model should report:

```text
Training Sites
Testing Sites
Shared Sites
```

`Shared Sites` should be zero.

---

# Deliverable 2

The Quarto source is:

```text
docs/CSC3220 Team8 Deliverable2.qmd
```

The report contains:

1. Problem Statement and Background
2. Data and Exploratory Analysis
3. Methods
4. Tools and Reproducibility

The updated Methods section explains the site-grouped evaluation design and why the earlier row-level split was replaced.

The formal final model results will be added after all models are rerun using the revised design.

Render from the repository root with:

```powershell
quarto render "docs/CSC3220 Team8 Deliverable2.qmd"
```

---

# Team Update

A detailed explanation of what changed and why is maintained in:

```text
docs/Team Update.md
```

It includes a dedicated section covering the revisions made because of Deliverable 1 professor feedback.

---

# Git Workflow

Before editing:

```powershell
git status
git pull origin main
```

After editing:

```powershell
git status
git diff
```

This is especially important in a shared repository so another team member's changes are not accidentally overwritten.

---

# Data Source

City of San Diego Open Data Portal  
Parking Study: counts and percentages of occupied parking spaces

https://data.sandiego.gov/datasets/parking-study-occupancy/
