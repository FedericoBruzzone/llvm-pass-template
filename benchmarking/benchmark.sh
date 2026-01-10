#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Detected OS: Linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then 
    echo "Detected OS: macOS"
else
    echo "Error: Unsupported OS type: $OSTYPE"
    exit 1
fi


# Check for LLVM_DIR environment variable
if [ -z "$LLVM_DIR" ]; then
  echo "LLVM_DIR environment variable is not set."
  echo "Please set it to your LLVM 21 installation directory."
  echo "This script will try to set a default value based on your OS."

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    LLVM_DIR="${LLVM_DIR:-/usr/lib/llvm-21}"
  elif [[ "$OSTYPE" == "darwin"* ]]; then 
    # macOS Silicon
    if [ -d "/opt/homebrew/opt/llvm@21" ]; then
      LLVM_DIR="${LLVM_DIR:-/opt/homebrew/opt/llvm@21}"
    # macOS Intel
    else
        LLVM_DIR="${LLVM_DIR:-/usr/local/opt/llvm@21}"
    fi
  fi

  echo "Setting LLVM_DIR to: $LLVM_DIR"
  echo ""
fi

# Absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT_DIR="$(cd "$SCRIPT_DIR/.." &>/dev/null && pwd)"
BENCHMARKING_DIR="$SCRIPT_DIR"
# The pass name is hardcoded, assuming this script is for this project.
# Check OS to set the correct shared library extension
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PASS_PLUGIN_PATH="$PROJECT_ROOT_DIR/build/lib/libFunctionCounter.so"
elif [[ "$OSTYPE" == "darwin"* ]]; then 
    PASS_PLUGIN_PATH="$PROJECT_ROOT_DIR/build/lib/libFunctionCounter.dylib"
else
    echo "Error: Unsupported OS type: $OSTYPE"
    exit 1
fi

# --- Main Logic ---
echo "--- Starting Benchmark Process ---"

# 1. Clone llvm-test-suite if it doesn't exist
cd "$BENCHMARKING_DIR"
if [ ! -d "llvm-test-suite" ]; then
  echo "[1/4] Cloning llvm-test-suite..."
  git clone https://github.com/llvm/llvm-test-suite.git --depth 1
else
  echo "[1/4] llvm-test-suite already exists, skipping clone."
fi

# 2. Build the FunctionCounter pass
echo "[2/4] Building the FunctionCounter pass..."
cd "$PROJECT_ROOT_DIR"
mkdir -p build
cd build
# Configure and build the pass
cmake -DLLVM_INSTALL_DIR="$LLVM_DIR" .. > /dev/null # Redirect verbose cmake output
make FunctionCounter > /dev/null # Redirect verbose make output

# Check if the pass library was created
if [ ! -f "$PASS_PLUGIN_PATH" ]; then
    echo "Error: Pass plugin not found at $PASS_PLUGIN_PATH"
    echo "Build failed."
    exit 1
fi
echo "      Pass built successfully: $PASS_PLUGIN_PATH"

# 3. Configure and build the llvm-test-suite
echo "[3/4] Configuring and building llvm-test-suite..."
cd "$BENCHMARKING_DIR"
mkdir -p test-suite-build
cd test-suite-build

# Configure with CMake. We pass CMAKE_C_FLAGS and CMAKE_CXX_FLAGS
# to clang to load our pass plugin during the compilation of the benchmarks.
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    cmake \
        -DCMAKE_C_COMPILER="$LLVM_DIR/bin/clang" \
        -DCMAKE_CXX_COMPILER="$LLVM_DIR/bin/clang++" \
        -DCMAKE_C_FLAGS="-fpass-plugin=$PASS_PLUGIN_PATH" \
        -DCMAKE_CXX_FLAGS="-fpass-plugin=$PASS_PLUGIN_PATH" \
        -DTEST_SUITE_BENCHMARKING_ONLY=ON \
        -DTEST_SUITE_RUN_BENCHMARKS=ON \
        -C ../llvm-test-suite/cmake/caches/O3.cmake \
        ../llvm-test-suite # > /dev/null # Redirect verbose cmake output
elif [[ "$OSTYPE" == "darwin"* ]]; then 
    #-----------------------------------------------------------------------------------------------
    # macOS specific fix for libc++ for the error:
    # ```
    # Undefined symbols for architecture x86_64:
    #   "std::__1::__hash_memory(void const*, unsigned long)"
    # ```
    # This is due to the fact that the test suite is built with libc++ from LLVM 21,
    # but macOS provides an older version of libc++ that does not have
    # some of the symbols introduced in LLVM 21.
    #
    # To know more about this issue, see:
    # - https://github.com/llvm/llvm-project/issues/77653
    # - https://github.com/Homebrew/homebrew-core/issues/235411
    #-----------------------------------------------------------------------------------------------
    # $(brew --prefix llvm@21) should expand to something like:
    # - `/usr/local/opt/llvm@21` (or `/usr/local/opt/llvm`) on Intel macOS 
    # - `/opt/homebrew/opt/llvm@21` (or `/opt/homebrew/opt/llvm`) on Apple Silicon macOS    
    SED_PATH="$(brew --prefix llvm@21)/include/c++/v1/__configuration/availability.h"
    # Restore function
    restore_header() {
        echo "Restoring availability.h..."
        sed -i '' 's/_LIBCPP_INTRODUCED_IN_LLVM_21 0/_LIBCPP_INTRODUCED_IN_LLVM_21 1/g' "$SED_PATH"
    }
    # Set a trap to restore the header on exit
    trap restore_header EXIT
    # Apply patch
    echo "Patching availability.h..."
    sed -i '' 's/_LIBCPP_INTRODUCED_IN_LLVM_21 1/_LIBCPP_INTRODUCED_IN_LLVM_21 0/g' "$SED_PATH"
    #-----------------------------------------------------------------------------------------------

    SDKROOT=$(xcrun --show-sdk-path)
    cmake \
        -DCMAKE_C_COMPILER="$LLVM_DIR/bin/clang" \
        -DCMAKE_CXX_COMPILER="$LLVM_DIR/bin/clang++" \
        -DCMAKE_C_FLAGS="-fpass-plugin=$PASS_PLUGIN_PATH -isysroot $SDKROOT" \
        -DCMAKE_CXX_FLAGS="-fpass-plugin=$PASS_PLUGIN_PATH -isysroot $SDKROOT" \
        -DTEST_SUITE_BENCHMARKING_ONLY=ON \
        -C ../llvm-test-suite/cmake/caches/O3.cmake \
        ../llvm-test-suite # > /dev/null # Redirect verbose cmake output
else
    echo "Error: Unsupported OS type: $OSTYPE"
    exit 1
fi
echo "     Configuration complete."

# Build the test suite
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    make -j"$(nproc)" #> /dev/null # Redirect verbose make output
elif [[ "$OSTYPE" == "darwin"* ]]; then 
    make -j"$(sysctl -n hw.ncpu)" #> /dev/null # Redirect verbose make output
else
    echo "Error: Unsupported OS type: $OSTYPE"
    exit 1
fi
echo "      Test suite built."

# 4. Run the benchmarks
echo "[4/4] Running benchmarks with lit..."
# Check if lit is available
if ! command -v lit &> /dev/null && ! command -v "$LLVM_DIR/bin/llvm-lit" &> /dev/null;
then
    echo "Error: lit (llvm-lit) could not be found."
    echo "Please install it ('pip install lit') or ensure it's in your PATH."
    exit 1
fi

# Prefer the one from the LLVM directory if it exists
LIT_CMD="lit"
if command -v "$LLVM_DIR/bin/llvm-lit" &> /dev/null; then
    LIT_CMD="$LLVM_DIR/bin/llvm-lit"
fi

$LIT_CMD -v -j 1 -o results.json .

# 5. Done
echo "--- Benchmark run complete! ---"
echo "Results saved to: $BENCHMARKING_DIR/test-suite-build/results.json"
echo ""
echo "To analyze the results, you can use the compare.py script:"
echo "python3 $BENCHMARKING_DIR/llvm-test-suite/utils/compare.py results.json"
echo ""
echo "You might need to install pandas and scipy:"
echo "pip install pandas scipy"
