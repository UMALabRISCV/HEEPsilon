#!/bin/bash
#
# run_kernel_tests.sh - Individual kernel test runner for HEEPsilon
#
# Description:
#   Tests each CGRA kernel individually by modifying main.c to enable one
#   kernel at a time. Supports timeout per kernel and provides detailed
#   timing information. Original main.c is restored automatically on exit
#   or Ctrl+C.
#
# Usage:
#   ./scripts/run_kernel_tests.sh [OPTIONS] [KERNELS...]
#
# Options:
#   -h, --help           Show help message
#   -l, --list           List available kernels
#   -t, --timeout SEC    Set timeout per kernel in seconds (default: 300)
#
# Examples:
#   ./scripts/run_kernel_tests.sh                         # Test all kernels (5 min timeout)
#   ./scripts/run_kernel_tests.sh strs_kernel bitc_kernel # Test only specific kernels
#   ./scripts/run_kernel_tests.sh -t 120                  # Test all with 2 min timeout
#   ./scripts/run_kernel_tests.sh -t 600 sha_kernel       # Test sha_kernel with 10 min timeout
#   TIMEOUT_SECONDS=120 ./scripts/run_kernel_tests.sh     # Alternative: set timeout via env var
#
# Environment Variables:
#   TIMEOUT_SECONDS  - Max time per kernel test in seconds (default: 300)
#
# Output:
#   PASS    - Kernel completed with 0 errors
#   FAIL    - Kernel completed with errors or unexpected output
#   TIMEOUT - Kernel exceeded timeout limit
#
# Requirements:
#   - Must be run from HEEPsilon root directory
#   - Virtual environment (.venv) must exist
#   - Verilator simulation must be built (make verilator-build)
#
# Author: Cristian Campos (UMA-DAC)
# Date: 2025
#

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

MAIN_C="sw/applications/kernel_test/main.c"

# Timeout per kernel test (in seconds) - default 5 minutes
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-300}

# All available kernels
ALL_KERNELS=("strs_kernel" "reve_kernel" "bitc_kernel" "sqrt_kernel" "gsm_kernel" "sha_kernel" "sha2_kernel" "conv_kernel")

# Show usage
show_help() {
    echo "Usage: $0 [OPTIONS] [KERNELS...]"
    echo ""
    echo "Individual kernel test runner for HEEPsilon CGRA kernels."
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -l, --list           List available kernels"
    echo "  -t, --timeout SEC    Set timeout per kernel in seconds (default: 300)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Test all kernels with 5 min timeout"
    echo "  $0 strs_kernel bitc_kernel   # Test only specific kernels"
    echo "  $0 -t 120                    # Test all with 2 min timeout"
    echo "  $0 -t 600 sha_kernel         # Test sha_kernel with 10 min timeout"
    echo "  TIMEOUT_SECONDS=120 $0       # Alternative: set timeout via env var"
    echo ""
    echo "Available kernels:"
    for k in "${ALL_KERNELS[@]}"; do
        echo "  - $k"
    done
    echo ""
    echo "Requirements:"
    echo "  - Run from HEEPsilon root directory"
    echo "  - Virtual environment (.venv) must exist"
    echo "  - Verilator simulation must be built (make verilator-build)"
}

# List kernels
list_kernels() {
    echo "Available kernels:"
    for k in "${ALL_KERNELS[@]}"; do
        echo "  $k"
    done
}

# Parse command line arguments
KERNELS_TO_TEST=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            list_kernels
            exit 0
            ;;
        -t|--timeout)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
        *)
            KERNELS_TO_TEST+=("$1")
            shift
            ;;
    esac
done

# If no kernels specified, test all
if [[ ${#KERNELS_TO_TEST[@]} -eq 0 ]]; then
    KERNELS_TO_TEST=("${ALL_KERNELS[@]}")
fi

# Validate specified kernels
for k in "${KERNELS_TO_TEST[@]}"; do
    valid=0
    for ak in "${ALL_KERNELS[@]}"; do
        if [[ "$k" == "$ak" ]]; then
            valid=1
            break
        fi
    done
    if [[ $valid -eq 0 ]]; then
        echo "Error: Unknown kernel '$k'"
        echo "Use -l or --list to see available kernels"
        exit 1
    fi
done

PASSED=0
FAILED=0
TIMEOUT_COUNT=0
INTERRUPTED=0
TOTAL_TIME=0

# Convert seconds to "Xs (Xm XXs)" format
format_time() {
    local seconds=$1
    local mins=$((seconds / 60))
    local secs=$((seconds % 60))
    printf "%ds (%dm%02ds)" $seconds $mins $secs
}

echo "========================================"
echo "  kernel_test Individual Kernel Tester"
echo "========================================"
echo -e "Timeout per kernel: ${CYAN}$(format_time $TIMEOUT_SECONDS)${NC}"
echo -e "Kernels to test: ${CYAN}${#KERNELS_TO_TEST[@]}${NC}"
echo ""

# Activate virtual environment
source .venv/bin/activate

# Backup original main.c
cp "$MAIN_C" "${MAIN_C}.bak"
echo "Backed up original main.c"

# Function to restore main.c
restore_main() {
    if [[ -f "${MAIN_C}.bak" ]]; then
        mv "${MAIN_C}.bak" "$MAIN_C"
        echo "Restored original main.c"
    fi
}

# Handle Ctrl+C
handle_interrupt() {
    echo ""
    echo "Interrupted by user!"
    INTERRUPTED=1
    pkill -P $$ 2>/dev/null || true
    restore_main
    exit 130
}

trap handle_interrupt INT TERM

# Function to enable only one kernel
enable_kernel() {
    local target_kernel=$1
    cp "${MAIN_C}.bak" "$MAIN_C"
    for k in "${ALL_KERNELS[@]}"; do
        sed -i "s|^\([[:space:]]*\)&${k},|\1// \&${k},|" "$MAIN_C"
    done
    sed -i "s|^\([[:space:]]*\)// \&${target_kernel},|\1\&${target_kernel},|" "$MAIN_C"
}

echo "Testing kernels individually..."
echo ""

for kernel in "${KERNELS_TO_TEST[@]}"; do
    [[ $INTERRUPTED -eq 1 ]] && break
    
    echo -n "Testing $kernel... "
    
    enable_kernel "$kernel"
    
    # Record start time
    START_TIME=$(date +%s)
    
    # Run and capture output with timeout
    TMPFILE=$(mktemp)
    timeout ${TIMEOUT_SECONDS}s make verilator-run-app PROJECT=kernel_test > "$TMPFILE" 2>&1 &
    PID=$!
    wait $PID 2>/dev/null
    EXIT_CODE=$?
    
    # Record end time and calculate elapsed
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    TOTAL_TIME=$((TOTAL_TIME + ELAPSED))
    ELAPSED_FMT=$(format_time $ELAPSED)
    
    OUTPUT=$(cat "$TMPFILE")
    rm -f "$TMPFILE"
    
    [[ $INTERRUPTED -eq 1 ]] && break
    
    # Check results
    if [[ $EXIT_CODE -eq 124 ]] || [[ $EXIT_CODE -eq 137 ]]; then
        echo -e "${YELLOW}TIMEOUT${NC} (exceeded $(format_time $TIMEOUT_SECONDS))"
        ((FAILED++))
        ((TIMEOUT_COUNT++))
    elif echo "$OUTPUT" | grep -q $'E\t0'; then
        CYCLE=$(echo "$OUTPUT" | grep "Simulation finished after" | grep -oP '\d+(?= clock cycles)' || echo "N/A")
        echo -e "${GREEN}PASS${NC} (${CYCLE} cycles, 0 errors) ${CYAN}[${ELAPSED_FMT}]${NC}"
        ((PASSED++))
    elif echo "$OUTPUT" | grep -q "Program Finished with value 0"; then
        CYCLE=$(echo "$OUTPUT" | grep "Simulation finished after" | grep -oP '\d+(?= clock cycles)' || echo "N/A")
        echo -e "${GREEN}PASS${NC} (${CYCLE} cycles) ${CYAN}[${ELAPSED_FMT}]${NC}"
        ((PASSED++))
    elif echo "$OUTPUT" | grep -q "error:"; then
        echo -e "${RED}COMPILE ERROR${NC} ${CYAN}[${ELAPSED_FMT}]${NC}"
        echo "  $(echo "$OUTPUT" | grep 'error:' | head -1)"
        ((FAILED++))
    else
        echo -e "${RED}FAIL${NC} ${CYAN}[${ELAPSED_FMT}]${NC}"
        echo "  Last output: $(echo "$OUTPUT" | tail -2 | tr '\n' ' ')"
        ((FAILED++))
    fi
done

echo ""
echo "========================================"
echo -e "  Summary: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC} (${TIMEOUT_COUNT} timeouts)"
echo -e "  Total time: ${CYAN}$(format_time $TOTAL_TIME)${NC}"
echo "========================================"

restore_main
exit $FAILED
