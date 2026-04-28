#!/bin/bash

# ==============================================================================
# Slurm Submission Script for Polreason Analysis Pipeline (Modes Subset)
# ==============================================================================
#
# This script executes the 'master.R' analysis pipeline for specific mode models.
#
# Usage:
#   sbatch run_master_modes.sh
#
# ==============================================================================

#SBATCH --job-name=polreason_modes
#SBATCH --output=logs/modes_%j.out
#SBATCH --error=logs/modes_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --account=pi_ju78
#SBATCH --partition=day_amd

# --- Environment Setup ---

# Create logs directory if it doesn't exist
mkdir -p logs

# Load R module (Adjust module name based on your cluster's naming convention)
# Some clusters use 'R/4.3.1', others just 'R'.
module load R || module load R/4.3.3 || echo "Warning: R module not found. Assuming R is in PATH."

# --- Execute Analysis ---

echo "Starting polreason analysis pipeline: master.R (Modes Subset)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODENAME"
echo "Start time: $(date)"

# Run the master R script with specific rater names as arguments
# Note: master.R has been updated to accept these as filters.
Rscript analysis/scripts/master.R "mode_1_first_person" "Mode_2_full_lifechain" "mode_3_nemo" "temp_0.7_thirdperson"

echo "Pipeline completed at: $(date)"
