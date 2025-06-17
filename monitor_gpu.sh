#!/bin/bash
OUTPUT_FILE="gpu_metrics.csv"
INTERVAL=1  # seconds between samples

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output|-o)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --interval|-i)
            INTERVAL="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Write CSV header if file doesn't exist
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "timestamp,gpu_name,gpu_index,power_draw,temperature,utilization" > "$OUTPUT_FILE"
fi

while true; do
    nvidia-smi --query-gpu=timestamp,name,index,power.draw,temperature.gpu,utilization.gpu \
               --format=csv,noheader,nounits >> "$OUTPUT_FILE"
    sleep $INTERVAL
done
