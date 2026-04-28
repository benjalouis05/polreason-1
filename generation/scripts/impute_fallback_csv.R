library(data.table)

YEAR <- 2024
source("analysis/scripts/0.config.R")
DIR_SYNTH <- "generation/synthetic_data/year_2024"

message("Loading GSS baseline...")
gss_raw <- readRDS(DIR_GSS)
setDT(gss_raw)

# Get valid levels for each question from the GSS
actual_questions <- setdiff(names(gss_raw), c("year", "persona_id", grep("^persona_", names(gss_raw), value = TRUE)))
valid_levels_list <- list()
for (q in actual_questions) {
  if (q %in% names(gss_raw)) {
    lvl <- unique(na.omit(gss_raw[[q]]))
    if (length(lvl) > 0) {
      valid_levels_list[[q]] <- lvl
    }
  }
}

# Helper to cleanly read CSV
read_synth_csv <- function(filename) {
  dt <- fread(file.path(DIR_SYNTH, filename))
  dt[, answer := suppressWarnings(as.numeric(answer))]
  dt
}

message("Loading raw synthetic CSVs...")
dt_10 <- read_synth_csv("nemo_temp_0.9.csv")
dt_13 <- read_synth_csv("nemo_temp_1.3.csv")
dt_17 <- read_synth_csv("nemo_temp_1.7.csv")

# Impute Random Function
impute_random_csv <- function(dt) {
  dt_imp <- copy(dt)
  # Find rows with NA answer or error
  bad_idx <- which(is.na(dt_imp$answer) | dt_imp$error != "")
  
  for (i in bad_idx) {
    q <- dt_imp$variable[i]
    lvl <- valid_levels_list[[q]]
    if (!is.null(lvl) && length(lvl) > 0) {
      dt_imp$answer[i] <- sample(lvl, 1)
      dt_imp$error[i] <- ""
      dt_imp$raw_response[i] <- "IMPUTED_RANDOM"
    }
  }
  return(dt_imp)
}

# Impute Fallback Function
impute_fallback_csv <- function(dt, dt_fallback) {
  dt_imp <- copy(dt)
  
  # Ensure fallback has an index for fast lookup
  setkey(dt_fallback, persona_id, variable, run)
  
  bad_idx <- which(is.na(dt_imp$answer) | dt_imp$error != "")
  
  for (i in bad_idx) {
    pid <- dt_imp$persona_id[i]
    var <- dt_imp$variable[i]
    r   <- dt_imp$run[i]
    
    # Lookup in fallback
    fallback_row <- dt_fallback[.(pid, var, r)]
    
    if (nrow(fallback_row) == 1 && !is.na(fallback_row$answer) && fallback_row$error == "") {
      dt_imp$answer[i] <- fallback_row$answer
      dt_imp$error[i] <- ""
      dt_imp$raw_response[i] <- "IMPUTED_TEMP0.9"
    }
  }
  return(dt_imp)
}

message("Generating Imputed Datasets...")

dt_13_rand <- impute_random_csv(dt_13)
dt_13_rand[, model := "nemo_temp_1.3_fallback_random"]

dt_13_fall <- impute_fallback_csv(dt_13, dt_10)
dt_13_fall[, model := "nemo_temp_1.3_fallback_temp0.9"]

dt_17_rand <- impute_random_csv(dt_17)
dt_17_rand[, model := "nemo_temp_1.7_fallback_random"]

dt_17_fall <- impute_fallback_csv(dt_17, dt_10)
dt_17_fall[, model := "nemo_temp_1.7_fallback_temp0.9"]

message("Saving new CSV files...")
fwrite(dt_13_rand, file.path(DIR_SYNTH, "nemo_temp_1.3_fallback_random.csv"))
fwrite(dt_13_fall, file.path(DIR_SYNTH, "nemo_temp_1.3_fallback_temp0.9.csv"))
fwrite(dt_17_rand, file.path(DIR_SYNTH, "nemo_temp_1.7_fallback_random.csv"))
fwrite(dt_17_fall, file.path(DIR_SYNTH, "nemo_temp_1.7_fallback_temp0.9.csv"))

message("Success! All fallback CSVs have been saved to ", DIR_SYNTH)
