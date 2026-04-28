#!/bin/bash

# ==============================================================================
# Slurm Submission Script for Polreason Analysis Pipeline (Fallback Models)
# ==============================================================================

#SBATCH --job-name=nemo_fallbacks
#SBATCH --output=logs/fallbacks_%j.out
#SBATCH --error=logs/fallbacks_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --account=pi_ju78
#SBATCH --partition=day_amd

# --- Environment Setup ---

mkdir -p logs

module load R || module load R/4.3.3 || echo "Warning: R module not found. Assuming R is in PATH."

# --- Execute Analysis ---

echo "Starting polreason analysis pipeline: master.R (Fallback Imputation Models)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODENAME"
echo "Start time: $(date)"

# Run the master R script with the new fallback models as arguments
Rscript analysis/scripts/master.R "nemo_temp_1.3_fallback_random" "nemo_temp_1.3_fallback_temp0.9" "nemo_temp_1.7_fallback_random" "nemo_temp_1.7_fallback_temp0.9"

echo "Pipeline completed at: $(date)"
