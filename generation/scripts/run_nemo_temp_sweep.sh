#!/bin/bash

# Temperatures to sweep
TEMPS=(0.5 0.9 1.3 1.7 2.1 3.0 5.0)

# Other parameters
YEAR=2024
PERSONAS=300  # Number of personas to query per temperature

echo "Starting Mistral Nemo Temperature Sweep..."
echo "Temperatures: ${TEMPS[*]}"
echo "Year: $YEAR"
echo "Personas: $PERSONAS"
echo "----------------------------------------"

for TEMP in "${TEMPS[@]}"; do
    echo "Running generation for Temperature: $TEMP"
    python generation/scripts/01_generate_synthetic_GSS.py \
        --year $YEAR \
        --models "mistralai/mistral-nemo" \
        --personas $PERSONAS \
        --temperature $TEMP
    
    echo "Completed $TEMP"
    echo "----------------------------------------"
done

echo "Temperature Sweep Complete!"
