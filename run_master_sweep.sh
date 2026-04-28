#!/bin/bash

# ==============================================================================
# Slurm Submission Script for Polreason Analysis Pipeline (Temperature Sweep)
# ==============================================================================

#SBATCH --job-name=nemo_temp_sweep
#SBATCH --output=logs/temp_sweep_%j.out
#SBATCH --error=logs/temp_sweep_%j.err
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

echo "Starting polreason analysis pipeline: master.R (Original Temp Sweep)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODENAME"
echo "Start time: $(date)"

# Run the master R script with the original temperature sweep models as arguments
Rscript analysis/scripts/master.R "nemo_temp_0.5" "nemo_temp_0.9" "nemo_temp_1.3" "nemo_temp_1.7"

echo "Pipeline completed at: $(date)"
