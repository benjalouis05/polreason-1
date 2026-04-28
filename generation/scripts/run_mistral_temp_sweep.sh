#!/bin/bash

# Temperatures to sweep (higher temps for Mistral native API)
TEMPS=(2.3 4.0)

# Other parameters
YEAR=2024
PERSONAS=300  # Number of personas to query per temperature
MODEL="open-mistral-nemo"
PROVIDER="mistral"

echo "Starting Mistral Native API Temperature Sweep..."
echo "Temperatures: ${TEMPS[*]}"
echo "Year: $YEAR"
echo "Personas: $PERSONAS"
echo "Provider: $PROVIDER"
echo "Model: $MODEL"
echo "----------------------------------------"

for TEMP in "${TEMPS[@]}"; do
    echo "Running generation for Temperature: $TEMP"
    python generation/scripts/01_generate_synthetic_GSS.py \
        --year $YEAR \
        --models "$MODEL" \
        --personas $PERSONAS \
        --temperature $TEMP \
        --provider $PROVIDER
    
    echo "Completed $TEMP"
    echo "----------------------------------------"
done

echo "Temperature Sweep Complete!"
