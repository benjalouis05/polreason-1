################################################################################
# Nemo Temperature Sweep: First-Order Fit Analysis
#
# This script calculates the "First-Order Fit" (1 - Mean JSD) for Nemo models
# across different temperatures by comparing their marginal distributions to GSS.
################################################################################

# Load config and utils
YEAR <- 2024
DIR_SCRIPTS <- "analysis/scripts"
source(file.path(DIR_SCRIPTS, "0.config.R"))
source(file.path(DIR_SCRIPTS, "v.common_utils.R"))

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(scales)
})

# 1. Define raters for the temperature sweep
temp_raters <- c(
  "nemo_temp_0.5",
  "nemo_temp_0.9",
  "mistralai_mistral-nemo", # This is the standard temp 1.0
  "nemo_temp_1.3",
  "nemo_temp_1.7",
  "random_guesser"
)

clean_names <- c(
  "nemo_temp_0.5"          = "Temp 0.5",
  "nemo_temp_0.9"          = "Temp 0.9",
  "mistralai_mistral-nemo" = "Temp 1.0 (Standard)",
  "nemo_temp_1.3"          = "Temp 1.3",
  "nemo_temp_1.7"          = "Temp 1.7",
  "random_guesser"         = "Random Guesser"
)

# 2. Load GSS baseline
message("Loading GSS baseline...")
gss_raw <- readRDS(DIR_GSS)
setDT(gss_raw)

# Identify survey variables
actual_questions <- setdiff(names(gss_raw), c("year", "persona_id", PERSONA_VARS_CANONICAL))

get_marginals <- function(dt, vars) {
  lapply(vars, function(v) {
    counts <- table(dt[[v]])
    if (length(counts) == 0) return(NULL)
    prop.table(counts)
  })
}

gss_marginals <- get_marginals(gss_raw, actual_questions)
names(gss_marginals) <- actual_questions

# 3. JSD Calculation Helper
calc_jsd <- function(p1, p2) {
  all_cats <- union(names(p1), names(p2))
  p1_full <- setNames(numeric(length(all_cats)), all_cats)
  p2_full <- setNames(numeric(length(all_cats)), all_cats)
  p1_full[names(p1)] <- as.numeric(p1)
  p2_full[names(p2)] <- as.numeric(p2)
  
  # Add small epsilon to avoid log(0)
  eps <- 1e-10
  p1_full <- p1_full + eps
  p2_full <- p2_full + eps
  
  # Normalize
  p1_full <- p1_full / sum(p1_full)
  p2_full <- p2_full / sum(p2_full)
  
  m <- 0.5 * (p1_full + p2_full)
  
  kl_1 <- sum(p1_full * log2(p1_full / m))
  kl_2 <- sum(p2_full * log2(p2_full / m))
  
  0.5 * kl_1 + 0.5 * kl_2
}

# 4. Process each rater
results <- list()

# Add GSS baseline to results for visualization
results[["GSS"]] <- data.table(
  rater = "GSS",
  clean_name = "Human GSS (Reference)",
  fit_score = 1.000,
  type = "Human"
)

for (rater in temp_raters) {
  message("Processing rater: ", rater)
  
  dir_rater <- file.path(BASE_OUT_DIR, sprintf("%s-%s", rater, YEAR))
  file_h <- file.path(dir_rater, paste0("harmonised_data", FILE_SUFFIX, ".rds"))
  
  if (!file.exists(file_h)) {
    # Try without suffix
    file_h <- file.path(dir_rater, "harmonised_data.rds")
  }
  
  if (!file.exists(file_h)) {
    warning("Harmonized data not found for ", rater)
    next
  }
  
  data_r <- readRDS(file_h)
  setDT(data_r)
  
  # Cast to wide
  dt_wide_r <- dcast(data_r[variable %in% actual_questions], persona_id + run ~ variable, value.var = "answer")
  
  rater_marginals <- get_marginals(dt_wide_r, actual_questions)
  names(rater_marginals) <- actual_questions
  
  jsds <- numeric()
  for (q in actual_questions) {
    if (!is.null(rater_marginals[[q]]) && !is.null(gss_marginals[[q]])) {
      jsds <- c(jsds, calc_jsd(rater_marginals[[q]], gss_marginals[[q]]))
    }
  }
  
  if (length(jsds) > 0) {
    type_label <- if(rater == "random_guesser") "Random Baseline" else "Mistral Nemo"
    results[[rater]] <- data.table(
      rater = rater,
      clean_name = clean_names[rater],
      fit_score = 1 - mean(jsds),
      type = type_label
    )
  }
}

final_dt <- rbindlist(results)
# Sort by rater order (or temperature value)
final_dt[, clean_name := factor(clean_name, levels = c("Human GSS (Reference)", clean_names))]

# 5. Visualization
message("Creating visualization...")

plot_theme <- theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1, face = "bold", color = "#2c3e50"),
    plot.title = element_text(face = "bold", size = 18, color = "#2c3e50", margin = margin(b = 10)),
    plot.subtitle = element_text(size = 12, color = "#7f8c8d", margin = margin(b = 20)),
    plot.background = element_rect(fill = "#f8f9fa", color = NA),
    panel.background = element_rect(fill = "#f8f9fa", color = NA),
    legend.position = "top"
  )

p <- ggplot(final_dt, aes(x = clean_name, y = fit_score, fill = type)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.3f", fit_score)), 
            vjust = -0.5, fontface = "bold", size = 4.5, color = "#2c3e50") +
  scale_y_continuous(limits = c(0, 1.1), expand = expansion(mult = c(0, 0.05)),
                     breaks = seq(0, 1, 0.2)) +
  scale_fill_manual(values = c("Human" = "#34495e", "Mistral Nemo" = "#3498db", "Random Baseline" = "#e74c3c")) +
  labs(
    title = "Nemo Temperature Sweep: First-Order Fit (JSD)",
    subtitle = "Comparing marginal response distributions (1 - Mean JSD) across temperatures.\nA higher score indicates better alignment with the human GSS 2024 baseline.",
    x = "Model / Temperature Setting",
    y = "Fit Score (1 - Mean JSD)",
    fill = "Data Source"
  ) +
  plot_theme

# Save
viz_file <- file.path(BASE_VIZ_DIR, "nemo_temperature_jsd_sweep.pdf")
pdf(viz_file, width = 10, height = 7)
print(p)
dev.off()

message("Success! Plot saved to: ", viz_file)

# Save stats
stats_file <- file.path(BASE_OUT_DIR, "nemo_temp_sweep_jsd_stats.csv")
fwrite(final_dt, stats_file)
message("Stats saved to: ", stats_file)
