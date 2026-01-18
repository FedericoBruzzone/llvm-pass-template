#!/bin/bash

# ==============================================================================
# Build & Test Script
# ==============================================================================
#
# This script provides a streamlined workflow for building, testing, and
# running the LLVM pass.
#
# Usage:
#   ./x.sh <command> [arguments]
#
# Environment:
#   LLVM_DIR                   Path to LLVM installation (default: ~/dev/llvm-project/llvm-build)
#
# Commands:
#   config                     Configure the project with CMake for a debug build.
#   build                      Build the project using make.
#   rebuild                    Re-configure and build the project from scratch.
#   run <file.ll>              Run the pass on a specific LLVM IR file.
#   test                       Run the lit test suite.
#   pipeline [level]           Print the optimization pipeline (default: -O0).
#   inject <level> <file.ll>   Inject/replace the custom pass in an optimization pipeline.
#   emit-llvm <file.c> [level] Generate LLVM IR from a C file (default: -O0).
#   clean                      Clean the build directory.
#   help                       Show this help message.
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
LLVM_DIR=${LLVM_DIR:-~/dev/llvm-project/llvm-build}
PASS_LIB_NAME=libFunctionCounter.dylib
PASS_NAME="print<function-counter>"
DEFAULT_PASS_TO_REPLACE=tailcallelim
BUILD_DIR=./build

# --- Helper Functions ---
print_usage() {
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Environment:"
    echo "  LLVM_DIR                   Path to LLVM installation (default: ~/dev/llvm-project/llvm-build)"
    echo ""
    echo "Commands:"
    echo "  config                     Configure the project with CMake for a debug build."
    echo "  build                      Build the project using make."
    echo "  rebuild                    Re-configure and build the project from scratch."
    echo "  run <file.ll>              Run the pass on a specific LLVM IR file."
    echo "  test                       Run the lit test suite."
    echo "  pipeline [level]           Print the optimization pipeline (default: -O0)."
    echo "  inject <level> <file.ll>   Inject/replace the custom pass in an optimization pipeline."
    echo "  emit-llvm <file.c> [level] Generate LLVM IR from a C file (default: -O0)."
    echo "  clean                      Clean the build directory."
    echo "  help                       Show this help message."
}

# --- Main Script Logic ---

# Show help message if no arguments are provided
if [ $# -eq 0 ]; then
    print_usage
    exit 0
fi

COMMAND=$1
shift # Remove the command from the arguments list

case $COMMAND in
    config)
        echo "--- Configuring project ---"
        mkdir -p ${BUILD_DIR}
        cd ${BUILD_DIR}
        cmake -DLLVM_INSTALL_DIR=${LLVM_DIR} -DLLVM_ENABLE_ASSERTIONS=ON ..
        ;;

    build)
        echo "--- Building project ---"
        cd ${BUILD_DIR}
        make -j$(nproc)
        ;;

    rebuild)
        echo "--- Rebuilding project from scratch ---"
        rm -rf ${BUILD_DIR}
        $0 config
        $0 build
        ;;

    run)
        if [ -z "$1" ]; then
            echo "Error: Missing file argument for 'run' command."
            print_usage
            exit 1
        fi
        INPUT_FILE=$1
        echo "--- Running pass on ${INPUT_FILE} ---"
        ${LLVM_DIR}/bin/opt \
            --load-pass-plugin ${BUILD_DIR}/lib/${PASS_LIB_NAME} \
            --passes="${PASS_NAME}" \
            -disable-output -stats -debug \
            ${INPUT_FILE}
        ;;

    test)
        echo "--- Running lit tests ---"
        cd ${BUILD_DIR}
        lit -a -v test
        ;;

    pipeline)
        # Set default optimization level to -O0 if not provided
        OPT_LEVEL=${1:--O0}

        echo "--- Printing pipeline for ${OPT_LEVEL} ---"
        ${LLVM_DIR}/bin/opt --print-pipeline-passes ${OPT_LEVEL} -S /dev/null -o /dev/null
        ;;

    inject)
        if [ -z "$1" ] || [ -z "$2" ]; then
            echo "Error: Missing arguments for 'inject' command."
            echo "Usage: $0 inject <opt_level> <file>"
            exit 1
        fi
        OPT_LEVEL=$1
        INPUT_FILE=$2

        echo "--- Injecting pass into ${OPT_LEVEL} pipeline for ${INPUT_FILE} ---"

        # Get the original pipeline and remove the 'Passes:' header
        ORIGINAL_PIPELINE=$(${LLVM_DIR}/bin/opt --print-pipeline-passes ${OPT_LEVEL} -S /dev/null -o /dev/null | sed 's/Passes: //')

        # Check if the default pass exists and replace it. If not, do nothing.
        if echo "${ORIGINAL_PIPELINE}" | grep -q "${DEFAULT_PASS_TO_REPLACE}"; then
            echo "Found and replacing '${DEFAULT_PASS_TO_REPLACE}' with '${PASS_NAME}'."
            MODIFIED_PIPELINE=$(echo "${ORIGINAL_PIPELINE}" | sed "s/${DEFAULT_PASS_TO_REPLACE}/${PASS_NAME}/")

            echo "Running with modified pipeline: ${MODIFIED_PIPELINE}"

            # Run opt with the modified pipeline
            ${LLVM_DIR}/bin/opt \
                --load-pass-plugin ${BUILD_DIR}/lib/${PASS_LIB_NAME} \
                --passes="${MODIFIED_PIPELINE}" \
                -disable-output \
                ${INPUT_FILE}
        else
            echo "Nothing to do: '${DEFAULT_PASS_TO_REPLACE}' not found in the ${OPT_LEVEL} pipeline."
        fi
        ;;

    emit-llvm)
        if [ -z "$1" ]; then
            echo "Error: Missing input file for 'emit-llvm' command."
            print_usage
            exit 1
        fi
        INPUT_FILE=$1
        OPT_LEVEL=${2:--O0}
        OUTPUT_FILE="${INPUT_FILE%.c}.ll"

        echo "--- Emitting LLVM IR for ${INPUT_FILE} to ${OUTPUT_FILE} with ${OPT_LEVEL} ---"
        ${LLVM_DIR}/bin/clang \
            -S -emit-llvm ${OPT_LEVEL} \
            -fno-discard-value-names \
            ${INPUT_FILE} -o ${OUTPUT_FILE}
        ;;

    clean)
        echo "--- Cleaning build directory ---"
        rm -rf ${BUILD_DIR}
        ;;

    clean)
        echo "--- Cleaning build directory ---"
        rm -rf ${BUILD_DIR}
        ;;

    help|*)
        print_usage
        ;;
esac

echo "--- Done ---"
