library(data.table)

# Directory with synthetic data
data_dir <- "generation/synthetic_data/year_2024"
files <- list.files(data_dir, pattern = "\\.csv$", full.names = TRUE)

audit_results <- list()

for (f in files) {
  # Read file
  dt <- fread(f)
  
  # Total rows
  total_rows <- nrow(dt)
  
  # Count "Could not parse" errors
  non_parseable <- sum(grepl("Could not parse answer", dt$error, ignore.case = TRUE))
  
  # Count API errors (400, 422, etc.)
  api_errors <- sum(grepl("Client Error", dt$error, ignore.case = TRUE))
  
  # Count total NAs in answer column
  total_na_answers <- sum(is.na(dt$answer))
  
  audit_results[[basename(f)]] <- data.table(
    file = basename(f),
    total_rows = total_rows,
    non_parseable = non_parseable,
    api_errors = api_errors,
    total_na_answers = total_na_answers,
    na_percent = round((total_na_answers / total_rows) * 100, 2)
  )
}

final_audit <- rbindlist(audit_results)
setorder(final_audit, -na_percent)

# Print for the user
print(final_audit)

# Save to output for persistent reference
fwrite(final_audit, "analysis/output/synthetic_data_error_audit.csv")
