#!/bin/bash

# This script calculates the Area Under the Curve (AUC) for code coverage
# reports generated over time. It uses the Trapezoidal Rule for AUC calculation.

# Check if a directory was provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_results_directory>"
    echo "Example: $0 /home/vagrant-code-coverage/workspace/test-generation-results/resultsSplittypie/mosa/testsplittypieMosa_0"
    exit 1
fi

RESULTS_DIR=$1

# Check if the directory exists
if [ ! -d "$RESULTS_DIR" ]; then
    echo "Error: Directory not found: $RESULTS_DIR"
    exit 1
fi

# Find all coverage report files
REPORT_FILES=$(ls -v "$RESULTS_DIR"/coverage-report*.txt 2>/dev/null)

if [ -z "$REPORT_FILES" ]; then
    echo "No coverage reports found in the specified directory: $RESULTS_DIR"
    exit 1
fi

# --- Final Coverage Calculation (with debugging) ---
echo "--- Step 1: Calculating Final Branch Coverage ---"
LAST_REPORT=$(echo "$REPORT_FILES" | tail -n 1)
echo "Found last report file: $LAST_REPORT"

# CORRECTED: Grab the 4th field and remove the '%' sign.
FINAL_BRANCH_COVERAGE=$(awk '/Branches/ {gsub(/%/, "", $4); print $4}' "$LAST_REPORT") # <-- MAJOR FIX HERE

echo "Extracted final branch coverage value: $FINAL_BRANCH_COVERAGE"
echo ""
echo "Final Branch Coverage: ${FINAL_BRANCH_COVERAGE}%"
echo "-------------------------------------"
echo ""

# --- AUC Calculation (with debugging) ---
echo "--- Step 2: Preparing data for AUC Calculation ---"

# The awk script will calculate the AUC. We pipe the data to it.
AUC=$(
    # Loop through all report files in numerical order
    for report_file in $REPORT_FILES; do
        # Get the file's modification timestamp (in seconds)
        timestamp=$(date -r "$report_file" +%s)
        
        # CORRECTED: Grab the 4th field and remove the '%' sign.
        coverage=$(awk '/Branches/ {gsub(/%/, "", $4); print $4}' "$report_file") # <-- MAJOR FIX HERE
        
        # --- ADDED DEBUGGING PRINTS ---
        echo "  - Processing file: $(basename "$report_file"), Timestamp: $timestamp, Coverage: $coverage" >&2
        
        # Print the timestamp and coverage for awk to process
        echo "$timestamp $coverage"
    done | \
    awk '
    BEGIN {
        # Initialize variables
        total_area = 0;
        prev_time = 0;
        prev_cov = 0;
    }
    {
        if (NR == 1) {
            # For the first point, set the initial time.
            # Assume coverage starts at 0 at the time of the first test.
            prev_time = $1;
            prev_cov = 0; # Assume we start from 0 coverage
        }

        # Calculate the area of the trapezoid for the current interval
        time_diff = $1 - prev_time;
        avg_cov = ($2 + prev_cov) / 2 / 100; # Average height, converted from % to decimal
        area = time_diff * avg_cov;
        total_area += area;
        
        # Update previous values for the next iteration
        prev_time = $1;
        prev_cov = $2;
    }
    END {
        # Print the final calculated AUC
        printf "%.4f\n", total_area;
    }
    '
)

echo ""
echo "--- Step 3: Final AUC Result ---"
echo "AUC (Branch Coverage vs. Time): $AUC"
echo "(This value represents 'coverage-percent-seconds')"