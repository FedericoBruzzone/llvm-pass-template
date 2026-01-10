# Benchmarking with llvm-test-suite

> [!WARNING]
> The benchmarking setup is specifically for the LLVM `FunctionCounter` pass provided in this repository. If you are using a different pass, you will need to modify the `benchmark.sh` script accordingly.

This directory contains scripts and documentation for benchmarking the `FunctionCounter` LLVM pass using the `llvm-test-suite`.

## Prerequisites

Before running the benchmark script, ensure you have the following dependencies installed:

1.  **LLVM 21**: Although the `benchmark.sh` will try to infer the location of your LLVM 21 installation, it is recommended to explicitly set the `LLVM_DIR` environment variable to the root of your LLVM 21 installation. This is required to build both the pass and the `llvm-test-suite`.
2.  **lit**: The `llvm-lit` test runner is required to execute the benchmarks. You can install it via `pip`:
    ```bash
    pip install lit
    ```
3.  **Python 3**: Required for `lit` and the `compare.py` script used for analyzing results.
4.  **Pandas and SciPy**: To analyze the results with the `compare.py` script, you'll need these Python libraries.
    ```bash
    pip install pandas scipy
    ```
5.  **Standard Build Tools**: `git`, `cmake`, and a C++ compiler are required.

## Quickstart

The `benchmark.sh` script automates the entire process of cloning the `llvm-test-suite`, building the pass, and running the benchmarks.

### Usage

1.  (Recommended) **Set `LLVM_DIR`**: Make sure the `LLVM_DIR` environment variable is set.
    ```bash
    # For instance:
    # Linux GNU: /usr/lib/llvm-21
    # macOS Silicon: /opt/homebrew/opt/llvm@21
    # macOS x86_64: /usr/local/opt/llvm@21
    export LLVM_DIR=/path/to/your/llvm-21-install
    ```

2.  **Run the script**: Navigate to the `benchmarking` directory and execute the script.
    ```bash
    cd benchmarking
    ./benchmark.sh
    ```

### How It Works

The `benchmark.sh` script performs the following steps:

1.  **Clones `llvm-test-suite`**: If the `llvm-test-suite` directory doesn't already exist, it will be cloned from the official LLVM GitHub repository.
2.  **Builds the Pass**: The script navigates to the project's root, creates a `build` directory (if it doesn't exist), and builds the `FunctionCounter` pass.
3.  **Configures and Builds `llvm-test-suite`**: It creates a `test-suite-build` directory and configures the test suite with `cmake`. The crucial step here is passing `-fpass-plugin` to `clang` via `CMAKE_C_FLAGS` and `CMAKE_CXX_FLAGS`. This tells `clang` to load and run the `FunctionCounter` pass on every source file it compiles.
4.  **Runs Benchmarks**: The script uses `lit` to run the benchmarks. `lit` will collect metrics, including compilation time, and store them in `results.json`.

### Analyzing the Results

After the script finishes, a `results.json` file will be generated in the `benchmarking/test-suite-build` directory. You can analyze this file using the `compare.py` script provided with the `llvm-test-suite`.

```bash
python3 llvm-test-suite/utils/compare.py test-suite-build/results.json
```

This will display a summary of the benchmark results. Since the `FunctionCounter` pass is very simple, you are unlikely to see a significant impact on `exec_time`. However, you can use the `-m` flag to view other metrics, such as `compile_time`, which might show a small overhead from running the pass.

```bash
python3 llvm-test-suite/utils/compare.py -m compile_time test-suite-build/results.json
```
