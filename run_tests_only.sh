#!/bin/bash

# ==============================================================================
# run_tests_only.sh (CORRECTED AND ROBUST)
#
# FIXES:
# 1. Removed invalid 'local' declarations from the main script body.
# 2. Uses an absolute path to call 'run-test-suite.sh' so it works from any dir.
# 3. Adds robust error checking to fail if the test log file is not created.
# ==============================================================================

# --- FIX #2: Determine the absolute path to this script's directory ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# --- Helper functions from original run.sh (unchanged) ---
os=$(uname)

function checkFolderExistence(){
	local folder=$1
	if [ ! -d "$folder" ]; then
    	echo "  ERROR: Folder not found: $folder"
    	exit 1 # This should be a hard exit
	fi
}

function checkProjectName(){
	local project_name=$1
	if [[ $project_name != "dimeshift" && $project_name != "phoenix" && $project_name != "pagekit" \
		&& $project_name != "splittypie" && $project_name != "retroboard" && $project_name != "petclinic" ]]; then
		echo "  ERROR: Unknown project name: $project_name"
		exit 1 # This should be a hard exit
	fi
}

# --- Core Test Execution Logic ---
function scanTestSuitesFolder(){
	local current_directory=$(pwd)
	local test_suites_folder=$1
	local project_folder=$2
	local project_name=$3
	local project_port_app=$4
	local project_port_db=$5
	local production=$6
	local session_file_name=$7
	local express_server_port=$8

    local overall_test_result=0

	local test_suite_counter=0
	for i in $( ls "$test_suites_folder" ); do
		local dir="$test_suites_folder/$i"
		echo "* Running Test Suite: $dir"
		cp "$dir"/main/* "$project_folder"/src/main/java/main/
		
        # --- FIX #2 (continued): Call run-test-suite.sh using its absolute path ---
        "$SCRIPT_DIR/run-test-suite.sh" "$project_name" "$session_file_name" "$project_port_db" "$project_port_app" \
            "4444" "$dir" "$project_folder" "$production" "$express_server_port" "$test_suite_counter"

		local test_runner_exit_code=$?
        if [ $test_runner_exit_code -ne 0 ]; then
            echo "  -> FATAL FAILURE: The test runner script itself failed or crashed (exit code: $test_runner_exit_code)."
            overall_test_result=1
            # Continue to the next test suite in the loop, but the overall result is now marked as failed
            continue 
        fi

        # --- FIX #3: Robust Error Checking ---
        local code_coverage_log="$dir/code-coverage-$session_file_name-$test_suite_counter.txt"
		
        if [ ! -f "$code_coverage_log" ]; then
            echo "  -> FATAL FAILURE: Test script did not produce a log file at '$code_coverage_log'."
            overall_test_result=1
        else
            # Only check the log if it exists
            local test_suite_bug=0
            test_suite_bug=$(grep -i "Test execution failed" "$code_coverage_log" | wc -l | awk '{print $1}')
            if [ $test_suite_bug -gt 0 ]; then
                echo "  -> FAILURE: Test suite bug found in $dir."
                overall_test_result=1 # Set failure flag
            else
                echo "  -> SUCCESS: Test suite completed without errors."
            fi
        fi

		# Cleanup
		cd "$project_folder"/src/main/java/main
		rm ClassUnderTest*_ESTest_scaffolding.java
		rm ClassUnderTest*_ESTest.java
		cd "$current_directory"
		test_suite_counter=$(($test_suite_counter+1))
	done

    return $overall_test_result
}

# --- Main Script ---
test_suites_folder=$1
project_folder=$2
project_name=$3
project_port_app=$4
project_port_db=$5
express_server_port=$6

if [ -z "$express_server_port" ]; then
    echo "Usage: ./run_tests_only.sh <test_suites_folder> <project_folder> <project_name> <app_port> <db_port> <express_port>"
    exit 1
fi

checkFolderExistence "$test_suites_folder"
checkFolderExistence "$project_folder"
checkProjectName "$project_name"

echo "Starting test execution against the currently running application..."

# --- FIX #1: Removed 'local' from these variable assignments ---
production="true"
session_file_name="mutation_run"

scanTestSuitesFolder "$test_suites_folder" "$project_folder" "$project_name" \
    "$project_port_app" "$project_port_db" "$production" "$session_file_name" \
    "$express_server_port"

test_run_status=$?

if [ $test_run_status -eq 0 ]; then
    echo "TESTS PASSED: All test suites completed successfully."
    exit 0
else
    echo "TESTS FAILED: At least one test suite reported a failure."
    exit 1
fi
