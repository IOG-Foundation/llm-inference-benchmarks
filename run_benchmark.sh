#!/bin/bash

# Default values
MODEL=${MODEL:-"deepseek-ai/DeepSeek-R1-Distill-Qwen-14B"}
BACKEND=${BACKEND:-"vllm"}
DATASET=${DATASET:-"sharegpt"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATASET_PATH=${DATASET_PATH:-"$SCRIPT_DIR/ShareGPT_V3_unfiltered_cleaned_split.json"}
RESULT_DIR=${RESULT_DIR:-"$SCRIPT_DIR/results"}
NUM_PROMPTS=${NUM_PROMPTS:-100}
GPU_NAME=${GPU_NAME:-"$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"}
GPU_COUNT=${GPU_COUNT:-"$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)"}
TOKENIZER_MODE=${TOKENIZER_MODE:-"auto"}
PORT=${PORT:-8000}

# Replace spaces in GPU model name with -
GPU_NAME=$(echo "$GPU_NAME" | tr ' ' '-')

# Define QPS values to test
QPS_VALUES=(32 16 8 4 1)

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --model MODEL                  Model to benchmark (default: $MODEL)"
    echo "  --backend BACKEND              Backend to use (default: $BACKEND)"
    echo "  --dataset DATASET              Dataset to use (default: $DATASET)"
    echo "  --dataset-path PATH            Path to the dataset (default: $DATASET_PATH)"
    echo "  --result-dir DIR               Output directory for results (default: $RESULT_DIR)"
    echo "  --gpu-name GPU_NAME            Metadata to be saved with the results. Name of the GPU (default: $GPU_NAME)"
    echo "  --gpu-count GPU_COUNT          Metadata to be saved with the results. Number of GPUs (default: $GPU_COUNT)"
    echo "  --tokenizer-mode MODE          Tokenizer mode to use (default: $TOKENIZER_MODE)"
    echo "  --port PORT                    Port to use (default: $PORT)"
    echo "  -h, --help                     Show this help message and exit"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --model)
      MODEL="$2"
      shift 2
      ;;
    --backend)
      BACKEND="$2"
      shift 2
      ;;
    --dataset)
      DATASET="$2"
      shift 2
      ;;
    --dataset-path)
      DATASET_PATH="$2"
      shift 2
      ;;
    --result-dir)
      RESULT_DIR="$2"
      shift 2
      ;;
    --gpu-name)
      GPU_NAME="$2"
      shift 2
      ;;
    --gpu-count)
      GPU_COUNT="$2"
      shift 2
      ;;
    --num-prompts)
      NUM_PROMPTS="$2"
      shift 2
      ;;
    --tokenizer-mode)
      TOKENIZER_MODE="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1\n"
      usage
      ;;
  esac
done

# Create output directory if it doesn't exist
mkdir -p "$RESULT_DIR"

# Common parameters
COMMON_PARAMS="--backend $BACKEND \
               --model $MODEL \
               --dataset-name $DATASET \
               --dataset-path $DATASET_PATH \
               --save-result \
               --append-result \
               --metric-percentiles 50,90,95,99,100 \
               --seed 42 \
               --goodput ttft:2000 \
               --metadata gpu_name=$GPU_NAME gpu_count=$GPU_COUNT \
               --num-prompts $NUM_PROMPTS \
               --result-dir $RESULT_DIR"

echo "Starting benchmark llm serving with model: $MODEL"
echo "Backend: $BACKEND"
echo "Dataset: $DATASET"
echo "Dataset Path: $DATASET_PATH"
echo "Results will be saved to: $RESULT_DIR"
echo "----------------------------------------"

# Run benchmarks with different QPS values
for qps in "${QPS_VALUES[@]}"; do
  echo "Running benchmark with QPS: $qps"

  # Construct filename for this run
  FILENAME="${BACKEND}_${NUM_PROMPTS}prompts${qps}qps_$(basename $MODEL)_${DATASET}_${GPU_COUNT}x${GPU_NAME}.json"

  # Run the benchmark
  python "$SCRIPT_DIR/scripts/benchmarks/benchmark_serving.py" $COMMON_PARAMS \
    --request-rate $qps \
    --result-filename "$FILENAME" \
    --tokenizer-mode $TOKENIZER_MODE \
    --port $PORT

  echo "Completed benchmark with QPS: $qps"
  echo "----------------------------------------"
done

echo "All benchmarks completed!"
echo "Results saved to: $RESULT_DIR"