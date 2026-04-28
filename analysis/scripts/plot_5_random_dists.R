################################################################################
# Plot 5 Random Questions: Nemo Temp 2.3 vs GSS
################################################################################

# Load config and utils
YEAR <- 2024
DIR_SCRIPTS <- "analysis/scripts"
source(file.path(DIR_SCRIPTS, "0.config.R"))
source(file.path(DIR_SCRIPTS, "v.common_utils.R"))

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

set.seed(42) # For reproducible random selection

# 1. Load Data
message("Loading GSS baseline...")
gss_raw <- readRDS(DIR_GSS)
setDT(gss_raw)
actual_questions <- setdiff(names(gss_raw), c("year", "persona_id", PERSONA_VARS_CANONICAL))

message("Loading Nemo Temp 2.3...")
dir_rater <- file.path(BASE_OUT_DIR, sprintf("nemo_temp_2.3-%s", YEAR))
data_r <- readRDS(file.path(dir_rater, paste0("harmonised_data", FILE_SUFFIX, ".rds")))
setDT(data_r)
dt_wide_r <- dcast(data_r[variable %in% actual_questions], persona_id + run ~ variable, value.var = "answer")

# 2. Select 5 random questions
sel_questions <- sample(actual_questions, 5)
message("Selected questions: ", paste(sel_questions, collapse = ", "))

# 3. Calculate distributions and shape for ggplot
plot_data <- list()

for (q in sel_questions) {
  # GSS Proportions
  gss_counts <- table(gss_raw[[q]])
  gss_props <- prop.table(gss_counts)
  
  if (length(gss_props) > 0) {
    df_gss <- data.table(
      question = q,
      answer = names(gss_props),
      proportion = as.numeric(gss_props),
      source = "GSS (Human)"
    )
    plot_data[[paste0(q, "_gss")]] <- df_gss
  }
  
  # Nemo Proportions
  nemo_counts <- table(dt_wide_r[[q]])
  nemo_props <- prop.table(nemo_counts)
  
  if (length(nemo_props) > 0) {
    df_nemo <- data.table(
      question = q,
      answer = names(nemo_props),
      proportion = as.numeric(nemo_props),
      source = "Nemo Temp 2.3"
    )
    plot_data[[paste0(q, "_nemo")]] <- df_nemo
  }
}

final_dt <- rbindlist(plot_data)

# Map question text (truncate for facet headers)
# We can use GSS_QUESTIONS from config if needed, but variables are fine
final_dt[, q_text := sapply(question, function(v) {
  if (v %in% names(GSS_QUESTIONS)) {
    substr(GSS_QUESTIONS[[v]]$text, 1, 60)
  } else {
    v
  }
})]
final_dt[, facet_label := paste0(question, ":\n", q_text, "...")]

# 4. Plot
plot_theme <- theme_minimal(base_size = 12) +
  theme(
    legend.position = "top",
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", size = 10, margin = margin(b=10)),
    axis.text.x = element_text(angle = 0, hjust = 0.5)
  )

p <- ggplot(final_dt, aes(x = answer, y = proportion, fill = source)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = sprintf("%.2f", proportion)), 
            position = position_dodge(width = 0.8), vjust = -0.5, size = 3) +
  facet_wrap(~ facet_label, ncol = 2, scales = "free_x") +
  scale_y_continuous(labels = scales::percent_format(accuracy=1), limits=c(0, 1.1)) +
  scale_fill_manual(values = c("GSS (Human)" = "#34495e", "Nemo Temp 2.3" = "#e74c3c")) +
  labs(
    title = "Categorical Distributions: Mistral Nemo (Temp 2.3) vs. GSS 2024",
    subtitle = "5 Randomly Selected Survey Questions",
    x = "Categorical Answer Option",
    y = "Proportion of Responses",
    fill = "Data Source"
  ) +
  plot_theme

viz_file <- file.path(BASE_VIZ_DIR, "nemo_temp2.3_vs_gss_5_random.pdf")
pdf(viz_file, width = 12, height = 10)
print(p)
dev.off()

message("Success! Plot saved to: ", viz_file)
