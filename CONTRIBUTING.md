# Contributing to LLM Inference Benchmarks

We welcome contributions to improve and expand the LLM inference benchmarking suite. Here's how you can help:

## Ways to Contribute

- **Add New Models**: Submit benchmarks for additional LLM models
- **Hardware Configurations**: Share results from different GPU/accelerator setups
- **Backend Engines**: Add support for other inference engines beyond vLLM
- **Improve Scripts**: Enhance benchmark automation, add new metrics, or optimize existing code
- **Improve Presentation**: Create visualizations, dashboards, or tools to better display and compare benchmark results
- **Documentation**: Fix typos, clarify instructions, or add examples
- **Bug Reports**: Report issues with clear reproduction steps

## Submitting Contributions

1. **Fork the Repository**: Create your own fork of the project
2. **Create a Feature Branch**: Work on a dedicated branch for your feature or fix
3. **Make Your Changes**: Follow existing code style and conventions
4. **Test Your Changes**: Ensure benchmarks run successfully with your modifications
5. **Commit with Clear Messages**: Use descriptive commit messages
6. **Push and Create PR**: Submit a pull request with a detailed description

## Guidelines

### Benchmark Results

When submitting new benchmark results, include:

- Hardware specifications (GPU model, VRAM, CPU, RAM)
- Software versions (CUDA, PyTorch, vLLM version)
- Complete benchmark parameters used
- Raw result JSON files in the `results/` directory

### Testing

- Test with at least one model before submitting
- Verify that it works with `sharegpt` dataset
- Ensure backwards compatibility

## Reporting Issues

When reporting issues, please include:

- System specifications (OS, GPU, CUDA version)
- Complete error messages and stack traces
- Steps to reproduce the issue
- Expected vs. actual behavior

## Questions or Suggestions

For questions, suggestions, or discussions about new features, please open an issue with the appropriate label.