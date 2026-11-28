library(tidyverse)
library(readr)

#parking_data <- read_csv("parking_study_occupancy_datasd.csv")
parking_data <- read_csv("parking_with_regions.csv")

#Create image directory for storing images if it does not already exist
dir.create("docs/images", recursive = TRUE, showWarnings = FALSE)

#See if you can convert site_id to ints (check to make sure nothing is changed first)
parking_data %>% filter(parking_data$site_id != as.integer(parking_data$site_id)) %>% select(site_id) #You cannot

#See counts by day
parking_data %>% group_by(day_of_week) %>% summarize(n=n())

##See missings (several missings when total_inventory = 0)
colSums(is.na(parking_data))
nrow(parking_data %>% filter(total_inventory == 0))

##Create cleaned dataset where total_inventory <= 0 are removed
clean_parking <- parking_data %>% 
  filter(total_inventory > 0)

#Outlier fences (IQR version)
ufence <- unname(quantile((clean_parking %>% distinct(site_id, total_inventory, .keep_all = TRUE))$total_inventory, 0.75, na.rm=TRUE) + (1.5 * IQR((clean_parking %>% distinct(site_id, total_inventory, .keep_all = TRUE))$total_inventory, na.rm=TRUE)))
lfence <- unname(quantile((clean_parking %>% distinct(site_id, total_inventory, .keep_all = TRUE))$total_inventory, 0.25, na.rm=TRUE) - (1.5 * IQR((clean_parking %>% distinct(site_id, total_inventory, .keep_all = TRUE))$total_inventory, na.rm=TRUE)))
#Five number summary
summary(clean_parking$total_inventory)
#Whisker minimum
clean_parking %>% filter(total_inventory < quantile(total_inventory, 0.75, na.rm=TRUE) + (1.5 * IQR(total_inventory, na.rm=TRUE))) %>% pull(total_inventory) %>% max()

#Full boxplot with outliers
ggplot(clean_parking %>% distinct(site_id, total_inventory, .keep_all = TRUE), aes(x=total_inventory)) + 
  geom_boxplot() + 
  scale_x_log10(breaks = c(2, 5, 25, 50, 100, 250, 500, 1000, unname(quantile((clean_parking %>% distinct(site_id, total_inventory, .keep_all = TRUE))$total_inventory,  probs = c(0, 0.25, .5,.75,1))))) + 
  theme_minimal() + 
  labs(x = "Parking Spots (logarithmic scale)", title = "Fig. 1: Spread of Parking Lot Capacity") +
  theme(axis.text.y=element_blank(),
        plot.title    = element_text(size = 20, face = "bold"),
        plot.subtitle = element_text(size = 14),
        axis.title    = element_text(size = 16),   # both x and y axis titles
        axis.text     = element_text(size = 13))

#Histogram of parking lot capacity (not great, likely don't use)
ggplot(clean_parking %>% distinct(site_id, total_inventory, .keep_all = TRUE), aes(x=total_inventory)) + 
  geom_histogram(binwidth = 0.1) + 
  theme_minimal() +
  theme( plot.title    = element_text(size = 20, face = "bold"),
         plot.subtitle = element_text(size = 14),
         axis.title    = element_text(size = 16),   # both x and y axis titles
         axis.text     = element_text(size = 13),   # tick labels
         legend.title  = element_text(size = 14),
         legend.text   = element_text(size = 12)) +
  scale_x_log10(breaks = c(1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 1500),
                labels = scales::label_comma())


#Make sure to note that there are several outliers, its just not feasible to plot them on the graph
colSums(is.na(clean_parking))

#Check to see if occupancy ever is above max capacity and if pct is ever > 100
clean_parking %>% filter(if_any(names(clean_parking)[6:18], ~ .x > total_inventory))
clean_parking %>% filter(if_any(names(clean_parking)[19:31], ~ .x > 1)) %>% 
  select(total_inventory, names(clean_parking)[19:31])

#Look at how much they were over
max_overflows <- clean_parking %>% 
  mutate(row_max = apply(pick(6:18), 1, max, na.rm=TRUE), 
         max_col = names(pick(6:18))[apply(pick(6:18), 1, which.max)]) %>% 
  filter(row_max > total_inventory) %>%
  select(total_inventory, row_max, max_col) %>% 
  mutate(overflow_cnt = row_max - total_inventory, overflow_pct = row_max/total_inventory - 1)

max(max_overflows$overflow_cnt)

#Since the amount that cars are parked past capacity is a max of 6, this is likely not an issue and is instead cars parked on curbs, the grass, dividers, etc.

#Make sure that percents are correct (check for inconsistencies)
sum(clean_parking[6:18]/clean_parking$total_inventory - clean_parking[19:31] > 0.001, na.rm=TRUE) #sum = 0, so no mismatches

findIQROutliers <- function(x, s, n){
  lfence <- quantile(x, 0.25, na.rm=TRUE) - (1.5 * IQR(x, na.rm=TRUE))
  ufence <- quantile(x, 0.75, na.rm=TRUE) + (1.5 * IQR(x, na.rm=TRUE))
  out <- !is.na(x) & (x < lfence | x > ufence)
  data.frame(site = s[out], name = rep(n, sum(out)), pct = x[out], lfence = rep(lfence, sum(out)), ufence = rep(ufence, sum(out)))
}

#Claude suggested using 'Map' here to apply the IQR function across the dataframe
outliers <- Map(findIQROutliers, 
                clean_parking[19:31], 
                s = list(clean_parking[[1]]),
                n = names(clean_parking)[19:31]) %>%
  bind_rows()

#Every missing 8_pm recording is on a Sunday
colSums(is.na(clean_parking %>% filter(day_of_week == "sunday")))
nrow(clean_parking %>% filter(day_of_week == "sunday")) #Every Sunday recording does not have an 8pm recording -> likely not missing at random

#See sites that have the same id but different capacities (Debugged via Claude, namely the '.groups = "drop"')
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

cat("\nUnique positive-capacity sites:",nrow(capacity_by_site),"\n")

#Prepare dataframe for plotting
rotated_df <- clean_parking |> pivot_longer(cols = c((names(clean_parking)[19:31])),
                                            names_to = "time",
                                            values_to = "pct") |> select(site_id, time, pct, day_of_week, neighborhood, region, total_inventory)
rotated_df$time <- factor(rotated_df$time, levels = names(clean_parking)[19:31])
rotated_df$day_of_week <- case_when(rotated_df$day_of_week == "saturday" ~ "Saturday",
                                    rotated_df$day_of_week == "sunday" ~ "Sunday",
                                    rotated_df$day_of_week == "thursday" ~ "Thursday")

#Plot occupancy percentages (x=time, y=pct, col=day)
ggplot(rotated_df %>% 
         group_by(time, day_of_week) %>% 
         summarize(avg_pct = mean(pct, na.rm=TRUE), .groups = "drop"), 
       aes(x=time, y=avg_pct*100, col=day_of_week, group = day_of_week)) + 
  geom_point() + 
  geom_line() + 
  labs(x="Time of Day", y = "Avg. Capacity (%)", title = "Fig. 2: Average Parking Lot Occupancy by Day", col= "Day") +
  scale_x_discrete(labels = c(
                      "8am", "9am", "10am", "11am", "12pm", "1pm", "2pm", "3pm", "4pm", "5pm", "6pm", "7pm", "8pm"
  )) +
  theme_minimal() +
  theme(plot.title    = element_text(size = 20, face = "bold"),
        plot.subtitle = element_text(size = 14),
        axis.title    = element_text(size = 16),   # both x and y axis titles
        axis.text     = element_text(size = 13),   # tick labels
        legend.title  = element_text(size = 14),
        legend.text   = element_text(size = 12))

#Plot percentages by time that are >= 100%
ggplot(rotated_df %>%
         group_by(time, day_of_week) %>%
         summarise(overall_pct = mean(pct >= 1) * 100, .groups = "drop"),
       aes(x=time, y= overall_pct, fill=day_of_week)) + geom_col(position = "dodge") +
  scale_x_discrete(labels = c("8am", "9am", "10am", "11am", "12pm", "1pm", "2pm", "3pm", "4pm", "5pm", "6pm", "7pm", "8pm")) +
  labs(x="Time of Day", y="Percentage", title = "Fig. 3: Percentage of Parking Lots at Maximum Capacity", fill="Day") + 
  theme_minimal() +
  theme(
    plot.title    = element_text(size = 20, face = "bold"),
    plot.subtitle = element_text(size = 14),
    axis.title    = element_text(size = 16),   # both x and y axis titles
    axis.text     = element_text(size = 13),   # tick labels
    legend.title  = element_text(size = 14),
    legend.text   = element_text(size = 12)
  ) +
  scale_y_continuous(breaks = seq(0, 60, by=5))

parking_data %>% group_by(site_id) %>% summarize(n=n())

#View occupancy by region
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
print(
  region_occupancy_summary
)

#Site capacity occupancy
site_capacity_groups <- capacity_by_site %>%
  mutate(lot_size_group = cut(
    site_capacity,
    breaks = c(-Inf, 5, 10, 20, 50, 100, Inf),
    labels = c("1-5", "6-10", "11-20", "21-50", "51-100", "101+"),
    right = TRUE
    ))

capacity_occupancy_summary <- rotated_df %>%
  filter(!is.na(pct)) %>%
  left_join(
    site_capacity_groups %>%
      select(site_id, site_capacity, lot_size_group),
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
print(capacity_occupancy_summary)
cat(
  "\nUnique sites represented across capacity groups:",
  sum(capacity_occupancy_summary$unique_sites),
  "\n"
)

