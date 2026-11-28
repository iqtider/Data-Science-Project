# Team Update

Hey guys,

I went back through the project after the Deliverable 1 feedback and made the changes that affect the EDA, model setup, and how we evaluate the models. The biggest change is the train/test split. The professor pointed out that the same parking site appears many times across different hours and days, so a normal row-level random split can put observations from the same site in both training and testing. That can make the model results look better than they really are.

The model types and the general approaches we already chose are still the same. The changes were made to make the evaluation more realistic, to line the code up with the research question, and to address the specific feedback we received.

# Due to Professor Feedback, These Items Were Changed/Modified

## 1. The Train/Test Split Is Now Grouped by Parking Site

Previously, the model files used an 80/20 random split at the row level.

That was a problem because each `site_id` appears repeatedly across different hours and, for some sites, different days. A row-level split could do something like this:

```text
Site 32 at 8 AM  -> Training
Site 32 at 9 AM  -> Training
Site 32 at 2 PM  -> Testing
Site 32 at 3 PM  -> Training
```

The model would technically be tested on a row it had not seen, but it had already seen other observations from the same physical parking location.

The project now uses a site-grouped split:

```r
group_initial_split(
  rotated_df,
  group = site_id,
  prop = 0.8
)
```

This keeps every observation from a given site together. A site is either in training or testing, never both.

### Why this is important

This removes an important source of data leakage. The held-out test set now answers a harder and more useful question:

> Can the model predict parking behavior at a site it did not see during training?

The new scores may be lower than the old scores. If that happens, it does not mean the models became worse. It means the test is more realistic.

Every model file now prints the number of training sites, testing sites, and shared sites. The shared-site count should be:

```text
0
```

---

## 2. Cross-Validation Is Also Grouped by Site

Changing only the final train/test split would not fully solve the leakage problem if cross-validation still split individual rows.

The training folds now use:

```r
group_vfold_cv(
  train_data,
  group = site_id,
  v = 10,
  balance = "observations"
)
```

All observations from one site remain together inside a fold.

### Why this is important

We use cross-validation to tune models such as kNN and the SVM. If the same site appeared in both the analysis and validation portions of a fold, the tuning process itself could still benefit from site-specific information.

Grouping both the final split and the cross-validation folds makes the evaluation consistent from beginning to end.

---

## 3. Row-Level Class Stratification Was Removed

The earlier classification setup stratified the random split by `Full` and `NotFull` status.

That does not work cleanly with site grouping because one parking site can contain both full and not-full observations at different times.

The new priority is keeping each site intact.

### Why this is important

Trying to force row-level class stratification and site grouping at the same time could split a site across training and testing, which would recreate the leakage problem we were trying to fix.

The scripts still print class distributions so we can monitor imbalance. The weighted SVM also still uses class weighting to handle the less common `Full` class.

---

## 4. Parking Capacity Is Now Included in the Model Predictor Set

Our research question has included parking capacity, but the earlier common model formulas were using:

```text
time of day
day of week
region
```

without actually including `total_inventory` in the model formulas.

`Parking.R` now keeps `total_inventory` when the data are reshaped into long format.

The common predictor set is now:

```text
numeric time of day
day of week
region
log-transformed parking capacity
```

The capacity variable is represented as:

```r
log_inventory = log1p(total_inventory)
```

### Why this is important

The professor specifically asked us to explore occupancy by lot size because capacity was supposed to be one of our predictors.

Adding capacity now makes the modeling code match the research question and the EDA.

The capacity values are also extremely right-skewed. Most sites are small, but the largest site has 1,595 spaces. Using `log1p(total_inventory)` reduces the scale difference between the largest facilities and typical sites without deleting the large sites.

This is especially important for scale-sensitive models such as kNN and SVM.

---

## 5. The Capacity Boxplot Was Replaced With a Histogram

The professor pointed out that the old capacity boxplot did not show much because the large-capacity outliers were hidden from the plot.

The report now uses a capacity histogram with a logarithmic horizontal axis.

The data show:

```text
350 unique positive-capacity sites
Minimum capacity = 1
Q1 = 7
Median = 10
Q3 = 17
Maximum capacity = 1,595
```

### Why this is important

The large values were not removed from the data, so hiding them in the main figure made the distribution difficult to understand.

The histogram lets us show both the many small parking locations and the small number of very large facilities in the same figure.

---

## 6. The Maximum-Capacity Plot Is No Longer Stacked

The old graph stacked the percentages for Thursday, Saturday, and Sunday on top of one another.

That was misleading because those percentages are separate day-specific values and should not be added together.

The revised plot uses side-by-side bars.

### Why this is important

Side-by-side bars let us directly compare the percentage of full locations for each day at each hour without implying that the days form one combined total.

---

## 7. Figure Labels Were Enlarged and Captions Were Numbered

The main EDA figures now have larger text and explicit numbered captions:

```text
Figure 1. Parking capacity distribution
Figure 2. Mean hourly parking occupancy by day
Figure 3. Percentage of locations at or above capacity by hour and day
```

### Why this is important

This directly addresses the presentation feedback and makes the figures easier to read in the PDF and easier to reference in the written discussion.

---

## 8. More EDA Was Added for Location and Lot Size

The professor asked us to explore occupancy by the variables we plan to use as predictors.

Two additional summaries were added.

### Occupancy by Region

Current descriptive averages include:

| Region | Mean Occupancy | Unique Sites |
|---|---:|---:|
| Pacific Beach | 84.4% | 23 |
| Downtown | 76.1% | 66 |
| Greater Golden Hill | 73.9% | 6 |
| Old Town | 73.2% | 18 |
| Uptown | 70.4% | 18 |
| Balboa Park | 63.1% | 16 |
| Mid-City | 61.2% | 90 |
| North Park | 59.8% | 27 |
| Park lot (Mission Bay or Balboa Park) | 57.5% | 57 |
| College Area / Mid-City | 43.5% | 27 |
| College Area | 40.4% | 2 |

These are descriptive differences. We should not claim that the region itself causes higher or lower occupancy.

### Occupancy by Parking Capacity

| Capacity Group | Mean Occupancy | Unique Sites |
|---|---:|---:|
| 1-5 spaces | 66.9% | 54 |
| 6-10 spaces | 70.4% | 135 |
| 11-20 spaces | 62.0% | 86 |
| 21-50 spaces | 70.0% | 21 |
| 51-100 spaces | 57.6% | 18 |
| 101+ spaces | 57.2% | 36 |

### Why this is important

The occupancy-by-capacity relationship is not simply a straight increase or decrease. That is useful information because it supports keeping capacity as a predictor without assuming that larger lots automatically have higher occupancy.

The regional differences also support keeping location information in the models.

---

# Changes Across the Model Files

The following model families are still being used:

## Regression

- Linear Regression
- Nonlinear Regression
- kNN Regression
- Decision Tree Regression
- Random Forest Regression

## Classification

- Logistic Regression
- kNN Classification
- Decision Tree Classification
- Random Forest Classification
- Weighted Linear SVM Classification

The main model-specific approaches were retained. The important shared changes are:

- site-grouped 80/20 train/test split
- site-grouped 10-fold cross-validation
- random seed `12345`
- parking capacity added through `log_inventory`
- common train/test site audit output
- occupancy values above 100 percent still retained
- existing baseline comparisons retained
- classification imbalance still evaluated with more than raw accuracy

The SVM was also changed so it uses the same prepared long-format data from `Parking.R` instead of building a separate version of the data and using a separate row-level split.

### Why this is important

If one model used a site-grouped test set while another still used a random row-level test set, their scores would not be directly comparable.

The common evaluation design is more important than keeping the old scores.

---

# Previous Model Results Are Now Preliminary

The result tables we generated before this feedback used the earlier row-level split.

Those numbers should **not** be treated as the final model comparison anymore.

The old results were useful for getting the models working, but all models now need to be rerun with:

```text
site-grouped train/test splitting
site-grouped cross-validation
parking capacity included
```

### Why this is important

We should not mix old row-split results with new site-grouped results in one comparison table.

Once all scripts are rerun, the new results will replace the old values in the final report.

---

# Important Data Decision That Did Not Change

## Occupancy Values Above 100 Percent Are Still Retained

Some observations contain more occupied vehicles than the listed parking inventory. The maximum difference observed was six vehicles above the listed capacity.

We continue to retain those observations rather than cap them at 100 percent.

For example:

```text
20 listed spaces
21 observed vehicles
Occupancy = 105%
```

Changing 105 percent to 100 percent would alter the original regression target.

### Why this is important

For regression, 105 percent and 110 percent contain different information. Capping both at 100 percent would erase that difference and make the highest-demand cases easier to predict artificially.

For classification, all values at or above 100 percent are simply classified as `Full`, so the exact amount above 100 percent matters mainly to the regression task.

---

# Why We Still Use Baseline Models

Regression models are compared with a mean-occupancy baseline.

Classification models are compared with a majority-class baseline.

### Why this is important

A model score has very little meaning without a simple reference point.

The classification baseline is particularly important because most observations are `NotFull`. A model can receive high raw accuracy just by predicting the majority class while failing to identify actual full parking conditions.

That is why classification evaluation also includes:

- precision
- recall
- specificity
- F1 score
- balanced accuracy
- confusion matrix
- ROC-AUC when available

---

# Why Some Models Normalize Predictors

kNN and SVM are sensitive to numerical scale.

Parking capacity ranges from very small locations to facilities with more than 1,000 spaces. Time has a much smaller numerical range.

For models that depend on distances or margins, leaving predictors on very different scales could let one variable dominate simply because its numbers are larger.

The project therefore uses a log transformation for capacity and normalization where the model requires it.

Decision trees and random forests do not require the same type of normalization because they make threshold-based splits instead of distance calculations.

---

# Running the Updated Project

First pull the latest project:

```powershell
git pull origin main
```

Check/install packages:

```powershell
Rscript --vanilla .\requirements.R
```

Run the updated EDA:

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

If `Rscript` is not recognized, run the files through RStudio or use the local R installation path for that computer.

The updated report source is:

```text
docs/CSC3220 Team8 Deliverable2.qmd
```

Render it with:

```powershell
quarto render "docs/CSC3220 Team8 Deliverable2.qmd"
```

---

# What Still Needs to Be Done

The code and report methodology have been revised for the professor feedback.

The next step is to rerun every model under the new evaluation design and collect the new metrics.

After that we need to:

1. replace the preliminary result tables with the new site-grouped results
2. compare the models again using the new test set
3. add final model-comparison plots
4. complete the final Results section
5. complete Summary and Conclusions
6. finish the Appendix and contribution information

The main thing to remember is that the old scores and the new scores should not be compared as if they came from the same experiment. The new site-grouped results are the ones that should be used going forward.
