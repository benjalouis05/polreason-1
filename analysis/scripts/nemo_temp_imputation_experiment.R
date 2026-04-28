library(data.table)
library(ggplot2)

YEAR <- 2024
source("analysis/scripts/0.config.R")
BASE_OUT_DIR <- "analysis/output"
BASE_VIZ_DIR <- "analysis/viz"

# Load GSS
message("Loading GSS...")
gss_raw <- readRDS(DIR_GSS)
setDT(gss_raw)
actual_questions <- setdiff(names(gss_raw), c("year", "persona_id", PERSONA_VARS_CANONICAL))

get_marginals <- function(dt, vars) {
  lapply(vars, function(v) {
    if (v %in% names(dt)) {
      counts <- table(dt[[v]])
      if (length(counts) == 0) return(NULL)
      return(prop.table(counts))
    }
    return(NULL)
  })
}

gss_marginals <- get_marginals(gss_raw, actual_questions)
names(gss_marginals) <- actual_questions

calc_tvd <- function(p1, p2) {
  all_cats <- union(names(p1), names(p2))
  p1_full <- setNames(numeric(length(all_cats)), all_cats)
  p2_full <- setNames(numeric(length(all_cats)), all_cats)
  p1_full[names(p1)] <- as.numeric(p1)
  p2_full[names(p2)] <- as.numeric(p2)
  0.5 * sum(abs(p1_full - p2_full))
}

load_wide_data <- function(rater) {
  message("Loading data for: ", rater)
  dir_rater <- file.path(BASE_OUT_DIR, sprintf("%s-%s", rater, YEAR))
  file_h <- file.path(dir_rater, paste0("harmonised_data", FILE_SUFFIX, ".rds"))
  if(!file.exists(file_h)) file_h <- file.path(dir_rater, "harmonised_data.rds")
  if(!file.exists(file_h)) stop("File not found: ", file_h)
  data_r <- readRDS(file_h)
  setDT(data_r)
  dt_wide <- dcast(data_r[variable %in% actual_questions], persona_id + run ~ variable, value.var = "answer")
  setorder(dt_wide, persona_id, run)
  return(dt_wide)
}

dt_10 <- load_wide_data("mistralai_mistral-nemo")
dt_13 <- load_wide_data("nemo_temp_1.3")
dt_17 <- load_wide_data("nemo_temp_1.7")

compute_score <- function(dt) {
  rater_marginals <- get_marginals(dt, actual_questions)
  names(rater_marginals) <- actual_questions
  tvds <- numeric()
  for (q in actual_questions) {
    if (!is.null(rater_marginals[[q]]) && !is.null(gss_marginals[[q]])) {
      tvds <- c(tvds, calc_tvd(rater_marginals[[q]], gss_marginals[[q]]))
    }
  }
  return(1 - mean(tvds))
}

message("Imputing Random Fallback...")
impute_random <- function(dt, gss_dt) {
  dt_imp <- copy(dt)
  for (q in actual_questions) {
    if (q %in% names(dt_imp)) {
      na_idx <- which(is.na(dt_imp[[q]]))
      if (length(na_idx) > 0) {
        valid_levels <- unique(na.omit(gss_dt[[q]]))
        if (length(valid_levels) > 0) {
          dt_imp[[q]][na_idx] <- sample(valid_levels, length(na_idx), replace = TRUE)
        }
      }
    }
  }
  return(dt_imp)
}

message("Imputing Temp 1.0 Fallback...")
impute_fallback <- function(dt, dt_fallback) {
  dt_imp <- copy(dt)
  for (q in actual_questions) {
    if (q %in% names(dt_imp) && q %in% names(dt_fallback)) {
      na_idx <- which(is.na(dt_imp[[q]]))
      if (length(na_idx) > 0) {
        dt_imp[[q]][na_idx] <- dt_fallback[[q]][na_idx]
      }
    }
  }
  return(dt_imp)
}

dt_13_rand <- impute_random(dt_13, gss_raw)
dt_13_fall <- impute_fallback(dt_13, dt_10)

dt_17_rand <- impute_random(dt_17, gss_raw)
dt_17_fall <- impute_fallback(dt_17, dt_10)

results <- list()
add_res <- function(temp, strategy, score) {
  results[[length(results) + 1]] <<- data.table(
    Temperature = temp,
    Strategy = strategy,
    FitScore = score
  )
}

message("Calculating TVD Scores...")
add_res("Temp 1.0", "Original (No NAs)", compute_score(dt_10))

add_res("Temp 1.3", "Original (Drop NAs)", compute_score(dt_13))
add_res("Temp 1.3", "Random Fallback", compute_score(dt_13_rand))
add_res("Temp 1.3", "Temp 1.0 Fallback", compute_score(dt_13_fall))

add_res("Temp 1.7", "Original (Drop NAs)", compute_score(dt_17))
add_res("Temp 1.7", "Random Fallback", compute_score(dt_17_rand))
add_res("Temp 1.7", "Temp 1.0 Fallback", compute_score(dt_17_fall))

final_dt <- rbindlist(results)

final_dt[, Temperature := factor(Temperature, levels=c("Temp 1.0", "Temp 1.3", "Temp 1.7"))]
final_dt[, Strategy := factor(Strategy, levels=c("Original (No NAs)", "Original (Drop NAs)", "Temp 1.0 Fallback", "Random Fallback"))]

message("Plotting...")
p <- ggplot(final_dt, aes(x = Temperature, y = FitScore, fill = Strategy)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = sprintf("%.3f", FitScore)), 
            position = position_dodge(width = 0.8), vjust = -0.5, fontface = "bold", size = 4) +
  scale_y_continuous(limits = c(0, 1.1), expand = expansion(mult = c(0, 0.05)), breaks = seq(0, 1, 0.2)) +
  scale_fill_manual(values = c(
    "Original (No NAs)" = "#2c3e50",
    "Original (Drop NAs)" = "#3498db",
    "Temp 1.0 Fallback" = "#f39c12",
    "Random Fallback" = "#e74c3c"
  )) +
  labs(
    title = "Missing Data Imputation Experiment: First-Order Fit",
    subtitle = "Comparing TVD fit scores when NA responses (gibberish) are imputed via different fallback strategies.",
    x = "Model Temperature",
    y = "Fit Score (1 - Mean TVD)",
    fill = "Imputation Strategy"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.x = element_blank(),
    legend.position = "top"
  )

viz_file <- file.path(BASE_VIZ_DIR, "nemo_imputation_experiment.pdf")
pdf(viz_file, width = 10, height = 7)
print(p)
dev.off()

message("Success! Saved plot to: ", viz_file)
print(final_dt)
