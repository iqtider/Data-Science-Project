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

# See if you can convert site_id to ints
# Check to make sure nothing is changed first
parking_data %>%
  filter(parking_data$site_id != as.integer(parking_data$site_id)) %>%
  select(site_id) # You cannot

## See counts by day
parking_data %>%
  group_by(day_of_week) %>%
  summarize(n = n())

## See missings
# Several missings when total_inventory = 0
colSums(is.na(parking_data))

nrow(
  parking_data %>%
    filter(total_inventory == 0)
)

## Create cleaned dataset where total_inventory <= 0 are removed
clean_parking <- parking_data %>%
  filter(total_inventory > 0)

# Capacity distribution across unique parking sites
# A histogram is used instead of hiding large-capacity outliers.
capacity_by_site <- clean_parking %>%
  distinct(site_id, total_inventory)

parking_capacity_plot <- ggplot(
  capacity_by_site,
  aes(x = total_inventory)
) +
  geom_histogram(
    bins = 30
  ) +
  scale_x_log10() +
  theme_minimal(
    base_size = 14
  ) +
  labs(
    x = "Listed Parking Capacity (spaces, log scale)",
    y = "Number of Unique Sites",
    title = "Distribution of Parking Capacity Across Study Sites"
  )

# Save capacity histogram used in report
ggsave(
  filename = "docs/images/parking_capacity_histogram.png",
  plot = parking_capacity_plot,
  width = 9,
  height = 5.5,
  dpi = 300
)

# Five number summary
summary(
  capacity_by_site$total_inventory
)

# Whisker maximum
clean_parking %>%
  filter(
    total_inventory <
      quantile(
        total_inventory,
        0.75,
        na.rm = TRUE
      ) +
      (
        1.5 * IQR(
          total_inventory,
          na.rm = TRUE
        )
      )
  ) %>%
  pull(total_inventory) %>%
  max()

# Full boxplot with outliers
# Kept for exploratory analysis but not used in report
full_capacity_plot <- ggplot(
  clean_parking,
  aes(x = total_inventory)
) +
  geom_boxplot()

# Make sure to note that there are several outliers,
# it is just not feasible to plot them on the report graph
colSums(
  is.na(clean_parking)
)

# Check to see if occupancy ever is above max capacity
# and if pct is ever > 100
clean_parking %>%
  filter(
    if_any(
      names(clean_parking)[6:18],
      ~ .x > total_inventory
    )
  )

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

# Look at how much they were over
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

# Since the amount that cars are parked past capacity is a max of 6,
# this is likely not an issue and may instead represent cars parked
# on curbs, grass, dividers, outside marked spaces, etc.
#
# These observations are retained rather than capped at 100%.
# Capping them would change the original regression target and remove
# information about how far above listed capacity an observation was.

# Make sure that percents are correct
# Check for inconsistencies
sum(
  clean_parking[6:18] / clean_parking$total_inventory -
    clean_parking[19:31] > 0.001,
  na.rm = TRUE
)
# Sum = 0, so no mismatches

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

# Every missing 8_pm recording is on a Sunday
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

# Every Sunday recording does not have an 8pm recording,
# so it is likely not missing at random

# Prepare dataframe for plotting and modeling
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

# Plot average occupancy percentage by time and day
hourly_occupancy_plot <- ggplot(
  rotated_df %>%
    filter(!is.na(pct)) %>%
    group_by(
      time,
      day_of_week
    ) %>%
    summarize(
      avg_pct = mean(
        pct,
        na.rm = TRUE
      ),
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
    y = "Avg. Capacity (%)",
    title = "Average Parking Lot Occupancy by Day",
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
  theme_minimal(base_size = 14)

# Save hourly occupancy plot used in report
ggsave(
  filename = "docs/images/hourly_occupancy_by_day.png",
  plot = hourly_occupancy_plot,
  width = 9,
  height = 5.5,
  dpi = 300
)

# Plot percentage of locations at or above 100% occupancy
maximum_capacity_plot <- ggplot(
  rotated_df %>%
    filter(!is.na(pct)) %>%
    group_by(
      time,
      day_of_week
    ) %>%
    summarise(
      overall_pct = mean(
        pct >= 1,
        na.rm = TRUE
      ) * 100,
      .groups = "drop"
    ),
  aes(
    x = time,
    y = overall_pct,
    fill = day_of_week
  )
) +
  geom_col(position = "dodge") +
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
    y = "Percentage",
    title = "Percentage of Parking Lots at Maximum Capacity",
    fill = "Day"
  ) +
  theme_minimal(base_size = 14)

# Save maximum-capacity plot used in report
ggsave(
  filename = "docs/images/maximum_capacity_by_hour.png",
  plot = maximum_capacity_plot,
  width = 9,
  height = 5.5,
  dpi = 300
)

# Additional EDA requested after Deliverable 1 feedback
# Compare occupancy by geographic region.
region_occupancy_summary <- rotated_df %>%
  filter(!is.na(pct)) %>%
  group_by(region) %>%
  summarize(
    mean_occupancy_pct = mean(pct) * 100,
    unique_sites = n_distinct(site_id),
    observations = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_occupancy_pct))

cat("\nMean Occupancy by Region\n")
print(region_occupancy_summary)

# Compare occupancy across parking-capacity groups.
lot_size_summary <- rotated_df %>%
  filter(!is.na(pct)) %>%
  mutate(
    lot_size_group = cut(
      total_inventory,
      breaks = c(0, 5, 10, 20, 50, 100, Inf),
      labels = c("1-5", "6-10", "11-20", "21-50", "51-100", "101+"),
      include.lowest = TRUE
    )
  ) %>%
  group_by(lot_size_group) %>%
  summarize(
    mean_occupancy_pct = mean(pct) * 100,
    unique_sites = n_distinct(site_id),
    observations = n(),
    .groups = "drop"
  )

cat("\nMean Occupancy by Parking Capacity Group\n")
print(lot_size_summary)

# Final check of number of records by site
parking_data %>%
  group_by(site_id) %>%
  summarize(
    n = n()
  )