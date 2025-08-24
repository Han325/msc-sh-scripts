#!/bin/bash

# ==============================================================================
# run_mutation_testing_baseline.sh (The ARGUMENT-DRIVEN Foreman - V2.1)
#
# MODIFICATIONS:
# 1. Accepts an OPTIONAL 11th argument: a file listing specific mutants to run.
# 2. If the file is provided, only mutants from that list will be processed.
# ==============================================================================

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
APPLY_MUTANT_SCRIPT="$SCRIPT_DIR/apply-mutant_baseline.sh"
RUN_TESTS_SCRIPT="$SCRIPT_DIR/run_tests_only.sh"

# --- CHANGE 1 START: Updated usage function ---
function usage() {
    echo "Usage: ./run_mutation_testing_targeted.sh <mutant_patch_dir> ... <express_port> [path_to_mutant_list_file]"
    echo "The 11th argument (mutant list file) is optional. If provided, only mutants listed in the file will be run."
    exit 1
}
# --- CHANGE 1 END ---

# --- CHANGE 2 START: Allow 10 or 11 arguments ---
if [ "$#" -ne 10 ] && [ "$#" -ne 11 ]; then
    echo "FUCKED UP: Incorrect number of arguments."
    usage
fi
# --- CHANGE 2 END ---

MUTANT_PATCH_DIR=$1
CONTAINER_NAME=$2
TEST_SUITES_FOLDER=$3
PROJECT_FOLDER=$4
PROJECT_NAME=$5
PROJECT_PORT_APP=$6
PROJECT_PORT_DB=$7
CHROMEDRIVER_PORT=$8
EXPRESS_SERVER_DIRECTORY=$9
EXPRESS_SERVER_PORT=${10}

# --- CHANGE 3 START: Logic to read the target mutant list ---
run_all=true
declare -A mutants_to_run
if [ -n "${11}" ]; then
    TARGET_LIST_FILE=${11}
    if [ ! -f "$TARGET_LIST_FILE" ]; then
        echo "FUCK: The specified mutant list file does not exist: $TARGET_LIST_FILE"
        exit 1
    fi
    echo ">>> TARGETED RUN ENABLED. Reading mutants from $TARGET_LIST_FILE <<<"
    while IFS= read -r line; do
        # Ignore empty lines or comments
        if [[ -n "$line" && ! "$line" =~ ^# ]]; then
            mutants_to_run["$line"]=1
        fi
    done < "$TARGET_LIST_FILE"
    run_all=false
fi
# --- CHANGE 3 END ---

# --- 2. GLOBAL SETUP ---
echo "============================================================"
echo "PHASE 1: Setting up global environment for project '$PROJECT_NAME'..."
echo "============================================================"

# Resolve paths
MUTANT_PATCH_DIR_EXPANDED=$(eval echo "$MUTANT_PATCH_DIR")
EXPRESS_SERVER_DIRECTORY_EXPANDED=$(eval echo "$EXPRESS_SERVER_DIRECTORY")

cd "$PROJECT_FOLDER" || { echo "FATAL: Could not cd to project folder $PROJECT_FOLDER"; exit 1; }
echo "Starting shared services (Chrome container)..."
docker compose up -d chrome

echo "Starting Express server for coverage..."
cd "$EXPRESS_SERVER_DIRECTORY_EXPANDED" || { echo "FATAL: Express server dir not found!"; exit 1; }
node . "$EXPRESS_SERVER_PORT" &
EXPRESS_PID=$!
cd "$PROJECT_FOLDER" # Go back to the main project dir

echo "Waiting a few seconds for services to settle..."
sleep 10

# --- 3. THE MASTER LOOP ---
echo "============================================================"
echo "PHASE 2: Starting mutation testing loop..."
echo "============================================================"

mutants_surviving_startup=0
mutants_killed_by_tests=0
mutants_with_errors=0
mutant_counter=0

for patch_file in "$MUTANT_PATCH_DIR_EXPANDED"/*.patch; do
    if [ -f "$patch_file" ]; then
        mutant_name=$(basename "$patch_file")
        mutant_counter=$((mutant_counter + 1))

        # --- CHANGE 4 START: Skip mutants not in our target list ---
        if ! $run_all && [[ ! -v mutants_to_run["$mutant_name"] ]]; then
            continue # Skip this mutant, it's not on our list
        fi
        # --- CHANGE 4 END ---

        echo "------------------------------------------------------------"
        echo "Processing Mutant #$mutant_counter: $mutant_name"
        echo "------------------------------------------------------------"

        "$APPLY_MUTANT_SCRIPT" "$patch_file" "$PROJECT_NAME"
        apply_exit_code=$?

        if [ $apply_exit_code -ne 0 ]; then
            echo "STATUS: SKIPPED (Failed to start). Moving to next mutant."
            continue
        fi

        mutants_surviving_startup=$((mutants_surviving_startup + 1))
        
        # --- MODIFIED SECTION START: Retry loop now shows output ---
        MAX_RETRIES=3
        clean_run=false
        final_tests_exit_code=-1
        # Use a temporary file to store output for analysis
        TEMP_LOG_FILE=$(mktemp) 

        for (( i=1; i<=$MAX_RETRIES; i++ )); do
            echo "Mutant started successfully. Executing test suites (Attempt $i/$MAX_RETRIES)..."
            
            # Run tests, show output on screen, AND save it to the temp file
            "$RUN_TESTS_SCRIPT" "$TEST_SUITES_FOLDER" "$PROJECT_FOLDER" \
                "$PROJECT_NAME" "$PROJECT_PORT_APP" "$PROJECT_PORT_DB" "$EXPRESS_SERVER_PORT" 2>&1 | tee "$TEMP_LOG_FILE"
            
            # Get the exit code of the FIRST command in the pipe (the test script), not tee
            tests_exit_code=${PIPESTATUS[0]}

            # Read the captured output from the temp file for analysis
            test_output=$(<"$TEMP_LOG_FILE")
            
            # Check for "unclean" output patterns
            if [[ "$test_output" == *'Aborted (core dumped)'* || \
                  ( "$test_output" == *'SLF4J: Failed to load class'* && "$test_output" == *'Test suite bug found'* ) ]]; then
                echo "WARN: Unclean output detected on attempt $i."
                if [ "$i" -lt "$MAX_RETRIES" ]; then
                    echo "Retrying..."
                    sleep 5
                fi
            else
                clean_run=true
                final_tests_exit_code=$tests_exit_code
                break 
            fi
        done

        # Clean up the temporary file
        rm -f "$TEMP_LOG_FILE"

        if [ "$clean_run" = true ]; then
            if [ $final_tests_exit_code -eq 0 ]; then
                echo "STATUS: SURVIVED (All tests passed)"
            else
                echo "STATUS: KILLED by test suite"
                mutants_killed_by_tests=$((mutants_killed_by_tests + 1))
            fi
        else
            echo "STATUS: ERROR (Test environment unstable after $MAX_RETRIES attempts)"
            mutants_with_errors=$((mutants_with_errors + 1))
        fi
        # --- MODIFIED SECTION END ---
    fi
done

# --- 4. FINAL REPORT & TEARDOWN ---
echo "============================================================"
echo "PHASE 3: Final Report and Cleanup"
echo "============================================================"

echo "Stopping final webapp container..."
docker compose stop webapp &>/dev/null

mutants_survived_tests=$((mutants_surviving_startup - mutants_killed_by_tests - mutants_with_errors))
echo "Total Mutants Processed: $mutant_counter"
echo "  -> Untestable (failed to start): $((mutant_counter - mutants_surviving_startup))"
echo "  -> Unstable (test errors):     $mutants_with_errors"
echo "------------------------------------------------------------"

truly_testable_mutants=$((mutants_surviving_startup - mutants_with_errors))

echo "Truly Testable Mutants: $truly_testable_mutants"
echo "  -> KILLED by tests:    $mutants_killed_by_tests"
echo "  -> SURVIVED tests:   $mutants_survived_tests"
echo "------------------------------------------------------------"

if [ $truly_testable_mutants -gt 0 ]; then
    mutation_score=$(echo "scale=2; ($mutants_killed_by_tests * 100) / $truly_testable_mutants" | bc)
    echo "FINAL MUTATION SCORE: $mutation_score%"
else
    echo "No mutants were reliably testable."
fi
echo "============================================================"

echo "Cleaning up global services..."
docker compose down
kill "$EXPRESS_PID"
echo "Done."