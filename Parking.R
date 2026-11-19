library(tidyverse)
library(readr)

# parking_data <- read_csv("parking_study_occupancy_datasd.csv")
parking_data <- read_csv("parking_with_regions.csv")

# Create report image directory if it does not already exist
dir.create(
  "docs/images",
  recursive = TRUE,
  showWarnings = FALSE
)

# See if site_id can be converted to integers
# Some identifiers contain decimals such as 38.1, so it cannot.
parking_data %>%
  filter(site_id != as.integer(site_id)) %>%
  select(site_id)

## See counts by day
parking_data %>%
  group_by(day_of_week) %>%
  summarize(n = n())

## See missings
# Several missing occupancy percentages occur when total_inventory = 0.
colSums(is.na(parking_data))

nrow(
  parking_data %>%
    filter(total_inventory == 0)
)

## Create cleaned dataset where total_inventory <= 0 is removed
clean_parking <- parking_data %>%
  filter(total_inventory > 0)

# -------------------------------------------------------------------
# Capacity EDA
# -------------------------------------------------------------------

# A small number of site_id values have slightly different
# total_inventory values across repeated records.
#
# For site-level exploratory analysis, assign each site one
# representative capacity using the median listed inventory.
#
# This prevents the same site from being counted in more than one
# capacity group while leaving the original row-level capacity values
# unchanged for the modeling data.

capacity_variation <- clean_parking %>%
  group_by(site_id) %>%
  summarize(
    capacity_values = n_distinct(total_inventory),
    min_capacity = min(total_inventory, na.rm = TRUE),
    max_capacity = max(total_inventory, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(capacity_values > 1)

cat("\nSites with more than one listed capacity\n")
print(capacity_variation)

capacity_by_site <- clean_parking %>%
  group_by(site_id) %>%
  summarize(
    site_capacity = median(total_inventory, na.rm = TRUE),
    .groups = "drop"
  )

cat(
  "\nUnique positive-capacity sites:",
  nrow(capacity_by_site),
  "\n"
)

# Histogram of one representative capacity per unique site.
#
# A logarithmic x-axis allows both the many small locations and the
# few very large parking facilities to remain visible.

parking_capacity_plot <- ggplot(
  capacity_by_site,
  aes(x = site_capacity)
) +
  geom_histogram(
    bins = 30
  ) +
  scale_x_log10() +
  labs(
    x = "Listed Parking Capacity (log scale)",
    y = "Number of Sites",
    title = "Distribution of Parking Capacity"
  ) +
  theme_minimal(
    base_size = 14
  )

ggsave(
  filename = "docs/images/parking_capacity_histogram.png",
  plot = parking_capacity_plot,
  width = 8,
  height = 5,
  dpi = 300
)

# Capacity summary based on one representative value per unique site
cat("\nParking Capacity Summary by Unique Site\n")

print(
  summary(
    capacity_by_site$site_capacity
  )
)

# Make sure to note that there are several large-capacity facilities.
# These are retained because they appear to be legitimate study sites.

colSums(
  is.na(clean_parking)
)

# -------------------------------------------------------------------
# Occupancy validity checks
# -------------------------------------------------------------------

# Check whether occupied counts ever exceed listed capacity.

clean_parking %>%
  filter(
    if_any(
      names(clean_parking)[6:18],
      ~ .x > total_inventory
    )
  )

# Check whether occupancy percentage ever exceeds 100%.

clean_parking %>%
  filter(
    if_any(
      names(clean_parking)[19:31],
      ~ .x > 1
    )
  ) %>%
  select(
    total_inventory,
    names(clean_parking)[19:31]
  )

# Look at how much observations exceeded listed capacity.

max_overflows <- clean_parking %>%
  mutate(
    row_max = apply(
      pick(6:18),
      1,
      max,
      na.rm = TRUE
    ),
    max_col = names(
      pick(6:18)
    )[
      apply(
        pick(6:18),
        1,
        which.max
      )
    ]
  ) %>%
  filter(
    row_max > total_inventory
  ) %>%
  select(
    total_inventory,
    row_max,
    max_col
  ) %>%
  mutate(
    overflow_cnt = row_max - total_inventory,
    overflow_pct = row_max / total_inventory - 1
  )

max(
  max_overflows$overflow_cnt
)

# The maximum overflow is only a small number of vehicles.
#
# These observations are retained rather than capped at 100%.
# Capping them would change the original regression target.

# Check that recorded occupancy percentages match:
#
# occupied count / total_inventory

sum(
  clean_parking[6:18] / clean_parking$total_inventory -
    clean_parking[19:31] > 0.001,
  na.rm = TRUE
)

# Sum = 0, so no mismatches.

findIQROutliers <- function(x, s, n) {

  lfence <- quantile(
    x,
    0.25,
    na.rm = TRUE
  ) - (
    1.5 * IQR(
      x,
      na.rm = TRUE
    )
  )

  ufence <- quantile(
    x,
    0.75,
    na.rm = TRUE
  ) + (
    1.5 * IQR(
      x,
      na.rm = TRUE
    )
  )

  out <- !is.na(x) & (
    x < lfence |
      x > ufence
  )

  data.frame(
    site = s[out],
    name = rep(
      n,
      sum(out)
    ),
    pct = x[out],
    lfence = rep(
      lfence,
      sum(out)
    ),
    ufence = rep(
      ufence,
      sum(out)
    )
  )
}

outliers <- Map(
  findIQROutliers,
  clean_parking[19:31],
  s = list(
    clean_parking[[1]]
  ),
  n = names(
    clean_parking
  )[19:31]
) %>%
  bind_rows()

# -------------------------------------------------------------------
# Sunday missing-value check
# -------------------------------------------------------------------

# Every missing 8_pm recording is on a Sunday.

colSums(
  is.na(
    clean_parking %>%
      filter(
        day_of_week == "sunday"
      )
  )
)

nrow(
  clean_parking %>%
    filter(
      day_of_week == "sunday"
    )
)

# Sunday observations do not have an 8 p.m. recording,
# so these values are treated as missing rather than zero.

# -------------------------------------------------------------------
# Prepare long-format dataframe for plotting and modeling
# -------------------------------------------------------------------

# IMPORTANT:
#
# Keep the original row-level total_inventory value here.
#
# The median site capacity created above is used only for site-level
# EDA grouping. It does NOT change the capacity values used by the
# modeling scripts.

rotated_df <- clean_parking |>
  pivot_longer(
    cols = c(
      names(clean_parking)[19:31]
    ),
    names_to = "time",
    values_to = "pct"
  ) |>
  select(
    site_id,
    time,
    pct,
    day_of_week,
    neighborhood,
    region,
    total_inventory
  )

rotated_df$time <- factor(
  rotated_df$time,
  levels = names(clean_parking)[19:31]
)

rotated_df$day_of_week <- case_when(
  rotated_df$day_of_week == "saturday" ~ "Saturday",
  rotated_df$day_of_week == "sunday" ~ "Sunday",
  rotated_df$day_of_week == "thursday" ~ "Thursday"
)

# -------------------------------------------------------------------
# Occupancy by region
# -------------------------------------------------------------------

region_occupancy_summary <- rotated_df %>%
  filter(
    !is.na(pct)
  ) %>%
  group_by(region) %>%
  summarize(
    mean_occupancy_pct = mean(pct) * 100,
    unique_sites = n_distinct(site_id),
    observations = n(),
    .groups = "drop"
  ) %>%
  arrange(
    desc(mean_occupancy_pct)
  )

cat("\nMean Occupancy by Region\n")

print(
  region_occupancy_summary
)

# -------------------------------------------------------------------
# Occupancy by parking capacity group
# -------------------------------------------------------------------

# Assign each unique site to exactly one capacity group using its
# representative median capacity.

site_capacity_groups <- capacity_by_site %>%
  mutate(
    lot_size_group = cut(
      site_capacity,
      breaks = c(
        -Inf,
        5,
        10,
        20,
        50,
        100,
        Inf
      ),
      labels = c(
        "1-5",
        "6-10",
        "11-20",
        "21-50",
        "51-100",
        "101+"
      ),
      right = TRUE
    )
  )

capacity_occupancy_summary <- rotated_df %>%
  filter(
    !is.na(pct)
  ) %>%
  left_join(
    site_capacity_groups %>%
      select(
        site_id,
        site_capacity,
        lot_size_group
      ),
    by = "site_id"
  ) %>%
  group_by(lot_size_group) %>%
  summarize(
    mean_occupancy_pct = mean(pct) * 100,
    unique_sites = n_distinct(site_id),
    observations = n(),
    .groups = "drop"
  )

cat("\nMean Occupancy by Parking Capacity Group\n")

print(
  capacity_occupancy_summary
)

cat(
  "\nUnique sites represented across capacity groups:",
  sum(capacity_occupancy_summary$unique_sites),
  "\n"
)

# -------------------------------------------------------------------
# Plot average occupancy percentage by time and day
# -------------------------------------------------------------------

hourly_occupancy_plot <- ggplot(
  rotated_df %>%
    filter(
      !is.na(pct)
    ) %>%
    group_by(
      time,
      day_of_week
    ) %>%
    summarize(
      avg_pct = mean(pct),
      .groups = "drop"
    ),
  aes(
    x = time,
    y = avg_pct * 100,
    col = day_of_week,
    group = day_of_week
  )
) +
  geom_point() +
  geom_line() +
  labs(
    x = "Time of Day",
    y = "Average Occupancy (%)",
    title = "Average Parking Occupancy by Day",
    col = "Day"
  ) +
  scale_x_discrete(
    labels = c(
      "8am",
      "9am",
      "10am",
      "11am",
      "12pm",
      "1pm",
      "2pm",
      "3pm",
      "4pm",
      "5pm",
      "6pm",
      "7pm",
      "8pm"
    )
  ) +
  theme_minimal(
    base_size = 14
  )

ggsave(
  filename = "docs/images/hourly_occupancy_by_day.png",
  plot = hourly_occupancy_plot,
  width = 9,
  height = 5.5,
  dpi = 300
)

# -------------------------------------------------------------------
# Plot percentage of locations at or above 100% occupancy
# -------------------------------------------------------------------

maximum_capacity_plot <- ggplot(
  rotated_df %>%
    filter(
      !is.na(pct)
    ) %>%
    group_by(
      time,
      day_of_week
    ) %>%
    summarise(
      overall_pct = mean(
        pct >= 1
      ) * 100,
      .groups = "drop"
    ),
  aes(
    x = time,
    y = overall_pct,
    fill = day_of_week
  )
) +
  geom_col(
    position = "dodge"
  ) +
  scale_x_discrete(
    labels = c(
      "8am",
      "9am",
      "10am",
      "11am",
      "12pm",
      "1pm",
      "2pm",
      "3pm",
      "4pm",
      "5pm",
      "6pm",
      "7pm",
      "8pm"
    )
  ) +
  labs(
    x = "Time of Day",
    y = "Locations at or Above Capacity (%)",
    title = "Percentage of Parking Locations at Maximum Capacity",
    fill = "Day"
  ) +
  theme_minimal(
    base_size = 14
  )

ggsave(
  filename = "docs/images/maximum_capacity_by_hour.png",
  plot = maximum_capacity_plot,
  width = 9,
  height = 5.5,
  dpi = 300
)

# -------------------------------------------------------------------
# Final check of number of records by site
# -------------------------------------------------------------------

parking_data %>%
  group_by(site_id) %>%
  summarize(
    n = n()
  )