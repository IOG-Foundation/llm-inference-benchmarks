# LLM Inference Benchmarks

LLM Inference Benchmarks on Consumer- and Enterprise-Grade Accelerators

The [`scripts/benchmarks`](scripts/benchmarks/) folder is from `vllm`'s benchmark implementation [`vllm 0.8.5`](https://github.com/vllm-project/vllm/blob/ba41cc90e8ef7f236347b2f1599eec2cbb9e1f0d/benchmarks/) release. Added `__init__.py` for convenience.

## How to Reproduce

### Setup Environment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

If using docker, then get [`vllm/vllm-openai:v0.8.5`](https://hub.docker.com/layers/vllm/vllm-openai/v0.8.5/images/sha256-6cf9808ca8810fc6c3fd0451c2e7784fb224590d81f7db338e7eaf3c02a33d33)

### Prepare Dataset

For dataset `random`, nothing to be done. For `sharegpt` dataset, download:

```bash
wget https://huggingface.co/datasets/anon8231489123/ShareGPT_Vicuna_unfiltered/resolve/main/ShareGPT_V3_unfiltered_cleaned_split.json
```

### Serve the Model

Example with vllm backend limited to 1 gpu:

```bash
CUDA_VISIBLE_DEVICES=0 vllm serve deepseek-ai/DeepSeek-R1-Distill-Qwen-14B  \
  --disable-log-requests \
  --dtype float16 \
  --tensor-parallel-size 1
```

Optional: set `--max-model-len` and `--gpu-memory-utilization` as needed based on the model requirements and hardware capacity. See [Engine Arguments doc](https://docs.vllm.ai/en/v0.8.5/serving/engine_args.html).

### Run Benchmark

Run `run_benchmark.sh` with the desired parameters. Example for 200 prompts from `sharegpt` dataset:

```bash
./run_benchmark.sh --model deepseek-ai/DeepSeek-R1-Distill-Qwen-14B \
                   --backend vllm \
                   --dataset sharegpt \
                   --dataset-path ./ShareGPT_V3_unfiltered_cleaned_split.json \
                   --result-dir ./results \
                   --num-prompts 200 \
                   --gpu-name NVIDIA-H100-PCIe \
                   --gpu-count 1

```

- it runs the complete benchmark for different queries-per-second (QPS) values: 32, 16, 8, 4, 1
- with burstiness 1.0 (Poisson) and max concurrency set as None (requests follow RPS without limitation)
- collects metric percentiles (50, 90, 95, 99, 100) for: time-to-first-token (TTFT), time-per-output-token (TPOT), inter-token-latency (ITL)
- for `goodput` metric evaluation, it sets 2000ms threshold for TTFT
- it saves results to file `result-dir/{BACKEND}_{NUM_PROMPTS}prompts{QPS}qps_{MODEL}_{DATASET}_{GPU_COUNT}x{GPU_NAME}.json`
- throughput definition: requests completed / duration in seconds
- goodput definition: requests completed under the goodput metric / duration in seconds
- parameters gpu-name and gpu-count here serve only as metadata for the saved benchmark results and do not influence the benchmark execution, as they are actually defined on the `vllm serve`.

The script `run_benchmark.sh` calls `benchmark_serving.py` under the hood. For more information on the underlying parameters, check `vllm`'s benchmark [`README.md`](scripts/benchmarks/README.md).

## Results

Complete raw results are on [`results`](results). Benchmarks executed on [io.net](https://io.net)'s cloud. 

### Pricing Context

As of May 2025, GPU rental pricing shows marked differences between hyperscale cloud providers (AWS, GCP, Azure) and emerging cloud computing platforms including GPU as a Service (GPUaaS). New entrants offer enterprise GPUs at approximately 20% of hyperscaler rates, while consumer GPUs remain exclusive to these platforms. NVIDIA H100 pricing differentials approach 5×, significantly impacting AI workload economics.

**Table** GPU Rental Pricing Comparison Across Cloud Providers

| GPU Model | Alternative Providers (USD/hour) | Hyperscalers (USD/hour) | Notes |
| --- | --- | --- | --- |
| NVIDIA H100 SXM | 2.49 | 12.29ᵃ | ᵃ8-GPU instance normalized per unit |
| NVIDIA H100 PCIe | 1.99 | 8.00–10.00ᵇ | ᵇEstimated range based on typical 65–80% pricing ratio relative to SXM variant |
| NVIDIA RTX 4090 | 0.25 | N/A | Alternative providers only |

*Note: On-demand hourly rates as of May 2025. Base compute costs only; excludes storage, networking, and data transfer charges, which are typically lower or bundled on alternative platforms.*

Subsequent cost-performance analyses utilize alternative provider pricing, as these platforms uniquely offer both consumer and enterprise GPUs, enabling direct comparison between GPU categories within a consistent pricing framework. Readers using hyperscaler services should multiply enterprise GPU costs by approximately 5× to reflect their pricing structure.

### Online Serving

The benchmark was executed with `200` prompts using dataset `sharegpt`. The tensor parallelism was set to the maximum available GPUs on the hardware configuration being evaluated, to collect metrics on the overall behaviour.

It's worth noting that when serving models via vLLM, unnecessarily increasing the tensor parallelism to utilize all the available GPUs can, in fact, negatively impact performance due to communication overhead. Thus, one should find the adequate tensor parallelism that handles the model and context size, and identify the optimal QPS (queries-per-second) for the given model/hardware configuration. Then, deliver higher QPSs by load balancing requests across multiple vLLM servers. The orchestration of such a scenario can be achieved in various ways and will not be detailed in this work. It can be handled using Ray/Kubernetes, or even a load balancer that routes traffic to geo-distributed nodes based on location, capacity, Service Level Objective (SLO), and other requirements.

#### Meta-Llama-3-8B-Instruct

| QPS | Hardware      | Duration (s) | Hardware pricing / h | Cost / benchmark duration | Throughput (tokens/s) | Throughput (req/s) | TTFT mean (ms) | TTFT median (ms) | TTFT p90 (ms) | TTFT p99 (ms) |
| --- | ------------- | ------------ | -------------------- | ------------------------- | --------------------- | ------------------ | -------------- | ---------------- | ------------- | ------------- |
| 1   | 1 × H100-PCIe | 190.21       | \$2.00               | \$0.106                   | 428.54                | 1.05               | 20.60          | 20.36            | 25.50         | 27.43         |
| 1   | 1 × RTX-4090  | 192.07       | \$0.25               | \$0.013                   | 424.43                | 1.04               | 49.16          | 43.50            | 77.43         | 110.69        |
| 4   | 1 × H100-PCIe | 52.19        | \$2.00               | \$0.029                   | 1562.05               | 3.83               | 21.65          | 21.65            | 26.04         | 27.93         |
| 4   | 1 × RTX-4090  | 58.91        | \$0.25               | \$0.004                   | 1384.26               | 3.39               | 56.86          | 50.02            | 90.25         | 132.07        |
| 8   | 1 × H100-PCIe | 30.36        | \$2.00               | \$0.017                   | 2685.11               | 6.59               | 23.12          | 22.73            | 27.79         | 30.16         |
| 8   | 1 × RTX-4090  | 37.95        | \$0.25               | \$0.003                   | 2147.82               | 5.27               | 69.22          | 60.99            | 111.09        | 180.34        |
| 16  | 1 × H100-PCIe | 19.66        | \$2.00               | \$0.011                   | 4145.92               | 10.17              | 24.75          | 24.95            | 29.80         | 31.06         |
| 16  | 1 × RTX-4090  | 28.68        | \$0.25               | \$0.002                   | 2843.04               | 6.97               | 85.85          | 74.37            | 143.88        | 193.13        |
| 32  | 1 × H100-PCIe | 14.99        | \$2.00               | \$0.008                   | 5438.38               | 13.34              | 40.44          | 37.74            | 60.43         | 77.54         |
| 32  | 1 × RTX-4090  | 24.52        | \$0.25               | \$0.002                   | 3325.26               | 8.16               | 161.46         | 162.92           | 260.01        | 330.49        |

#### DeepSeek-R1-Distill-Llama-8B

| QPS | Hardware      | Duration (s) | Hardware pricing / h | Cost / benchmark duration | Throughput (tokens/s) | Throughput (req/s) | TTFT mean (ms) | TTFT median (ms) | TTFT p90 (ms) | TTFT p99 (ms) |
| --- | ------------- | ------------ | -------------------- | ------------------------- | --------------------- | ------------------ | -------------- | ---------------- | ------------- | ------------- |
| 1   | 1 × H100-PCIe | 190.17       | \$2.00               | \$0.106                   | 439.03                | 1.05               | 20.49          | 20.59            | 25.52         | 26.74         |
| 1   | 1 × RTX-4090  | 191.99       | \$0.25               | \$0.013                   | 437.06                | 1.04               | 47.65          | 39.85            | 76.04         | 110.90        |
| 1   | 2 × RTX-4090  | 190.96       | \$0.50               | \$0.027                   | 437.22                | 1.05               | 1187.81        | 1173.37          | 2206.91       | 2767.89       |
| 4   | 1 × H100-PCIe | 52.30        | \$2.00               | \$0.029                   | 1596.42               | 3.82               | 22.17          | 22.48            | 26.44         | 27.84         |
| 4   | 1 × RTX-4090  | 58.81        | \$0.25               | \$0.004                   | 1426.92               | 3.40               | 58.03          | 49.67            | 92.83         | 144.55        |
| 4   | 2 × RTX-4090  | 56.01        | \$0.50               | \$0.008                   | 1490.56               | 3.57               | 363.24         | 223.10           | 814.06        | 1003.69       |
| 8   | 1 × H100-PCIe | 30.43        | \$2.00               | \$0.017                   | 2744.12               | 6.57               | 22.50          | 22.35            | 27.72         | 29.29         |
| 8   | 1 × RTX-4090  | 38.06        | \$0.25               | \$0.003                   | 2193.92               | 5.26               | 67.82          | 60.23            | 108.35        | 148.29        |
| 8   | 2 × RTX-4090  | 35.60        | \$0.50               | \$0.005                   | 2345.28               | 5.62               | 114.28         | 92.65            | 207.90        | 365.97        |
| 16  | 1 × H100-PCIe | 19.76        | \$2.00               | \$0.011                   | 4225.61               | 10.12              | 24.15          | 24.67            | 29.21         | 32.35         |
| 16  | 1 × RTX-4090  | 31.59        | \$0.25               | \$0.002                   | 2655.99               | 6.33               | 86.87          | 73.60            | 147.44        | 195.46        |
| 16  | 2 × RTX-4090  | 29.53        | \$0.50               | \$0.004                   | 2827.67               | 6.77               | 251.60         | 198.02           | 429.94        | 1022.01       |
| 32  | 1 × H100-PCIe | 16.58        | \$2.00               | \$0.009                   | 5034.81               | 12.06              | 42.10          | 40.26            | 62.41         | 82.89         |
| 32  | 1 × RTX-4090  | 29.27        | \$0.25               | \$0.002                   | 2866.80               | 6.83               | 157.86         | 151.39           | 253.06        | 335.53        |
| 32  | 2 × RTX-4090  | 32.74        | \$0.50               | \$0.005                   | 2550.39               | 6.11               | 1627.97        | 1603.34          | 2459.90       | 2685.79       |

#### DeepSeek-R1-Distill-Qwen-1.5B

| QPS | Hardware      | Duration (s) | Hardware pricing / h | Cost / benchmark duration | Throughput (tokens/s) | Throughput (req/s) | TTFT mean (ms) | TTFT median (ms) | TTFT p90 (ms) | TTFT p99 (ms) |
| --- | ------------- | ------------ | -------------------- | ------------------------- | --------------------- | ------------------ | -------------- | ---------------- | ------------- | ------------- |
| 1   | 1 × H100-PCIe | 189.31       | \$2.00               | \$0.105                   | 447.53                | 1.06               | 10.93          | 10.69            | 12.80         | 14.17         |
| 1   | 1 × RTX-4090  | 189.99       | \$0.25               | \$0.013                   | 445.90                | 1.05               | 19.15          | 18.70            | 24.20         | 27.65         |
| 4   | 1 × H100-PCIe | 47.97        | \$2.00               | \$0.027                   | 1766.12               | 4.17               | 10.94          | 10.78            | 13.04         | 14.30         |
| 4   | 1 × RTX-4090  | 52.71        | \$0.25               | \$0.004                   | 1607.46               | 3.79               | 20.84          | 21.08            | 25.37         | 28.57         |
| 8   | 1 × H100-PCIe | 25.21        | \$2.00               | \$0.014                   | 3360.08               | 7.93               | 11.13          | 10.86            | 13.40         | 14.74         |
| 8   | 1 × RTX-4090  | 30.85        | \$0.25               | \$0.002                   | 2746.06               | 6.48               | 22.87          | 22.74            | 28.62         | 30.21         |
| 16  | 1 × H100-PCIe | 14.30        | \$2.00               | \$0.008                   | 5924.98               | 13.99              | 11.85          | 11.85            | 14.43         | 15.79         |
| 16  | 1 × RTX-4090  | 20.17        | \$0.25               | \$0.001                   | 4200.67               | 9.92               | 26.38          | 26.38            | 33.92         | 40.39         |
| 32  | 1 × H100-PCIe | 8.88         | \$2.00               | \$0.005                   | 9536.68               | 22.51              | 21.03          | 16.21            | 22.55         | 145.23        |
| 32  | 1 × RTX-4090  | 16.61        | \$0.25               | \$0.001                   | 5100.88               | 12.04              | 39.78          | 37.14            | 54.74         | 105.53        |

#### DeepSeek-R1-Distill-Qwen-7B

| QPS | Hardware      | Duration (s) | Hardware pricing / h | Cost / benchmark duration | Throughput (tokens/s) | Throughput (req/s) | TTFT mean (ms) | TTFT median (ms) | TTFT p90 (ms) | TTFT p99 (ms) |
| --- | ------------- | ------------ | -------------------- | ------------------------- | --------------------- | ------------------ | -------------- | ---------------- | ------------- | ------------- |
| 1   | 1 × H100-PCIe | 190.07       | \$2.00               | \$0.106                   | 448.67                | 1.05               | 20.22          | 20.17            | 24.70         | 26.24         |
| 1   | 1 × RTX-4090  | 191.71       | \$0.25               | \$0.013                   | 443.91                | 1.04               | 33.50          | 33.86            | 40.29         | 43.85         |
| 1   | 2 × RTX-4090  | 190.40       | \$0.50               | \$0.026                   | 447.53                | 1.05               | 4253.82        | 2724.50          | 9964.76       | 16206.69      |
| 4   | 1 × H100-PCIe | 51.77        | \$2.00               | \$0.029                   | 1644.85               | 3.86               | 21.49          | 21.08            | 25.56         | 27.81         |
| 4   | 1 × RTX-4090  | 57.74        | \$0.25               | \$0.004                   | 1475.33               | 3.46               | 38.56          | 39.28            | 46.56         | 49.75         |
| 4   | 2 × RTX-4090  | 53.99        | \$0.50               | \$0.007                   | 1577.77               | 3.70               | 494.29         | 322.24           | 1203.65       | 1763.86       |
| 8   | 1 × H100-PCIe | 29.89        | \$2.00               | \$0.017                   | 2843.24               | 6.69               | 22.53          | 22.36            | 26.68         | 28.54         |
| 8   | 1 × RTX-4090  | 36.61        | \$0.25               | \$0.003                   | 2327.15               | 5.46               | 44.46          | 44.79            | 54.03         | 58.15         |
| 8   | 2 × RTX-4090  | 33.40        | \$0.50               | \$0.005                   | 2547.06               | 5.99               | 102.30         | 86.10            | 174.14        | 290.63        |
| 8   | 4 × RTX-4090  | 31.68        | \$1.00               | \$0.009                   | 2687.71               | 6.31               | 124.65         | 94.99            | 234.67        | 353.82        |
| 16  | 1 × H100-PCIe | 19.12        | \$2.00               | \$0.011                   | 4461.08               | 10.46              | 24.04          | 24.04            | 28.84         | 31.23         |
| 16  | 1 × RTX-4090  | 26.97        | \$0.25               | \$0.002                   | 3157.55               | 7.41               | 49.96          | 49.75            | 63.14         | 74.86         |
| 16  | 2 × RTX-4090  | 25.63        | \$0.50               | \$0.004                   | 3319.17               | 7.80               | 371.93         | 242.15           | 745.85        | 937.87        |
| 16  | 4 × RTX-4090  | 24.92        | \$1.00               | \$0.007                   | 3419.58               | 8.02               | 287.77         | 244.50           | 550.65        | 730.39        |
| 32  | 1 × H100-PCIe | 15.74        | \$2.00               | \$0.009                   | 5413.64               | 12.71              | 38.41          | 36.75            | 56.29         | 69.63         |
| 32  | 1 × RTX-4090  | 27.72        | \$0.25               | \$0.002                   | 3074.63               | 7.21               | 145.71         | 150.03           | 227.90        | 307.21        |
| 32  | 2 × RTX-4090  | 29.07        | \$0.50               | \$0.004                   | 2931.55               | 6.88               | 1021.83        | 949.28           | 1534.68       | 1695.71       |
| 32  | 4 × RTX-4090  | 26.53        | \$1.00               | \$0.007                   | 3208.07               | 7.54               | 1032.83        | 1027.77          | 1338.91       | 1491.44       |

#### DeepSeek-R1-Distill-Qwen-14B

| QPS | Hardware      | Duration (s) | Hardware pricing / h | Cost / benchmark duration | Throughput (tokens/s) | Throughput (req/s) | TTFT mean (ms) | TTFT median (ms) | TTFT p90 (ms) | TTFT p99 (ms) |
| --- | ------------- | ------------ | -------------------- | ------------------------- | --------------------- | ------------------ | -------------- | ---------------- | ------------- | ------------- |
| 1   | 1 × H100-PCIe | 192.17       | \$2.00               | \$0.107                   | 433.76                | 1.04               | 35.10          | 35.05            | 43.12         | 45.55         |
| 1   | 2 × RTX-4090  | 193.62       | \$0.50               | \$0.027                   | 430.51                | 1.03               | 355.29         | 300.75           | 649.22        | 1031.91       |
| 1   | 4 × RTX-4090  | 192.77       | \$1.00               | \$0.054                   | 431.19                | 1.04               | 389.44         | 304.36           | 846.98        | 1199.15       |
| 1   | 8 × RTX-4090  | 191.75       | \$2.00               | \$0.107                   | 434.92                | 1.04               | 6457.09        | 7269.67          | 12589.86      | 14453.35      |
| 4   | 1 × H100-PCIe | 59.04        | \$2.00               | \$0.033                   | 1411.84               | 3.39               | 36.53          | 36.26            | 44.95         | 46.79         |
| 4   | 2 × RTX-4090  | 66.47        | \$0.50               | \$0.009                   | 1250.59               | 3.01               | 240.39         | 207.68           | 463.89        | 638.69        |
| 4   | 4 × RTX-4090  | 61.82        | \$1.00               | \$0.017                   | 1344.58               | 3.24               | 156.97         | 131.61           | 289.73        | 482.13        |
| 4   | 8 × RTX-4090  | 59.68        | \$2.00               | \$0.033                   | 1393.08               | 3.35               | 132.29         | 92.70            | 215.01        | 752.63        |
| 8   | 1 × H100-PCIe | 37.20        | \$2.00               | \$0.021                   | 2240.95               | 5.38               | 38.29          | 38.21            | 46.65         | 49.09         |
| 8   | 2 × RTX-4090  | 55.56        | \$0.50               | \$0.008                   | 1500.34               | 3.60               | 335.95         | 311.47           | 571.83        | 802.63        |
| 8   | 4 × RTX-4090  | 44.68        | \$1.00               | \$0.012                   | 1858.57               | 4.48               | 154.99         | 133.90           | 265.25        | 448.04        |
| 8   | 8 × RTX-4090  | 44.84        | \$2.00               | \$0.025                   | 1849.74               | 4.46               | 132.48         | 122.05           | 210.40        | 268.73        |
| 16  | 1 × H100-PCIe | 27.68        | \$2.00               | \$0.015                   | 3011.13               | 7.22               | 40.89          | 41.88            | 50.38         | 54.41         |
| 16  | 2 × RTX-4090  | 51.47        | \$0.50               | \$0.007                   | 1619.37               | 3.89               | 843.12         | 727.63           | 1571.76       | 1947.71       |
| 16  | 4 × RTX-4090  | 41.67        | \$1.00               | \$0.012                   | 1994.82               | 4.80               | 163.87         | 159.71           | 250.68        | 337.07        |
| 16  | 8 × RTX-4090  | 41.16        | \$2.00               | \$0.023                   | 2026.68               | 4.86               | 148.55         | 144.75           | 221.16        | 266.40        |


## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.
