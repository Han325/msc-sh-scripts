#!/bin/bash

# ===== CONFIG =====
SOURCE_DIR="/home/vagrant-cc-enhanced/Desktop/dimeshift-enhanced-15-run"
RESULTS_DIR="/home/vagrant-cc-enhanced/workspace/test-generation-results/resultsDimeshift"
CODECOVERAGE_DIR="/home/vagrant-cc-enhanced/workspace/codecoverage"
FINAL_RESULTS_DIR="/home/vagrant-cc-enhanced/dimeshift-15-run-RESULTS"
DESKTOP_DIR="/home/vagrant-cc-enhanced/Desktop"
MAX_RUNS=15
# ==================

echo "===== STARTING COMPLETE DIMESHIFT ANALYSIS FOR $MAX_RUNS RUNS ====="

# Check current swap space
echo "===== SYSTEM RESOURCES CHECK ====="
CURRENT_SWAP=$(free -h | grep Swap | awk '{print $2}')
echo "[$(date)] Current swap space: $CURRENT_SWAP"
echo "[$(date)] Available memory: $(free -h | grep Mem | awk '{print $7}')"

# Set JVM memory options
export MAVEN_OPTS="-Xmx1g -Xms512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
echo "[$(date)] JVM options set: $MAVEN_OPTS"

# Phase 1: Setup and copy files for all runs
echo "===== PHASE 1: COPYING FILES FOR ALL RUNS ====="
for run in $(seq 1 $MAX_RUNS); do
    echo "[$(date)] Processing run $run/$MAX_RUNS..."
    
    # Create directory structure in resultsDimeshift
    mkdir -p "$RESULTS_DIR/$run/testdimeshiftLLM_0/main" || {
        echo "[ERROR] Failed to create directory structure for run $run";
        exit 1;
    }
    
    # Create directory structure in final results
    mkdir -p "$FINAL_RESULTS_DIR/$run" || {
        echo "[ERROR] Failed to create final results directory for run $run";
        exit 1;
    }
    
    # Copy Java files from source to results directory
    SOURCE_MAIN="$SOURCE_DIR/$run/testdimeshiftAdaptiveSequence_0/main"
    DEST_MAIN="$RESULTS_DIR/$run/testdimeshiftLLM_0/main"
    
    if [[ -d "$SOURCE_MAIN" ]]; then
        cp "$SOURCE_MAIN/ClassUnderTestApogen_ESTest.java" "$DEST_MAIN/" || {
            echo "[ERROR] Failed to copy ESTest.java for run $run";
            exit 1;
        }
        cp "$SOURCE_MAIN/ClassUnderTestApogen_ESTest_scaffolding.java" "$DEST_MAIN/" || {
            echo "[ERROR] Failed to copy scaffolding.java for run $run";
            exit 1;
        }
        echo "[$(date)] Successfully copied Java files for run $run"
    else
        echo "[ERROR] Source directory not found: $SOURCE_MAIN";
        exit 1;
    fi
done

echo "[$(date)] Phase 1 completed - All files copied"

# Phase 2-6: Process each run individually
for run in $(seq 1 $MAX_RUNS); do
    echo "===== PROCESSING RUN $run/$MAX_RUNS ====="
    
    # Phase 2: Run code coverage analysis
    echo "[$(date)] Phase 2: Running code coverage analysis for run $run..."
    cd "$CODECOVERAGE_DIR" || { echo "[ERROR] Failed to cd to codecoverage directory"; exit 1; }
    
    # Clean up any lingering processes before starting
    echo "[$(date)] Cleaning up processes before code coverage analysis..."
    pkill -f java || echo "[INFO] No Java processes to kill"
    pkill -f chromedriver || echo "[INFO] No chromedriver processes to kill"
    pkill -f chrome || echo "[INFO] No chrome processes to kill"
    sleep 10
    
    # Run with retry logic for segmentation faults
    RETRY_COUNT=0
    MAX_RETRIES=3
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        echo "[$(date)] Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES for code coverage analysis..."
        
        ./run.sh dimeshift \
                 "/home/vagrant-cc-enhanced/workspace/test-generation-results/resultsDimeshift/$run" \
                 "/home/vagrant-cc-enhanced/workspace/fse2019/dimeshift" \
                 dimeshift \
                 3000 \
                 3306 \
                 4444 \
                 "/home/vagrant-cc-enhanced/workspace/code-coverage-server/express-istanbul" \
                 7014
        
        if [ $? -eq 0 ]; then
            echo "[$(date)] Code coverage analysis succeeded on attempt $((RETRY_COUNT + 1))"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                echo "[WARNING] Code coverage analysis failed (attempt $RETRY_COUNT/$MAX_RETRIES). Cleaning up and retrying..."
                pkill -f java || echo "[INFO] No Java processes to kill"
                pkill -f chromedriver || echo "[INFO] No chromedriver processes to kill"
                pkill -f chrome || echo "[INFO] No chrome processes to kill"
                sleep 30  # Longer wait for cleanup
            else
                echo "[ERROR] Code coverage analysis failed after $MAX_RETRIES attempts for run $run"
                exit 1
            fi
        fi
    done
    
    echo "[$(date)] Code coverage analysis completed for run $run"
    
    # Phase 3: Calculate AUC and save results
    echo "[$(date)] Phase 3: Calculating AUC for run $run..."
    echo "[DEBUG] Current directory: $(pwd)"
    echo "[DEBUG] Running: ./calculate-auc.sh \"/home/vagrant-cc-enhanced/workspace/test-generation-results/resultsDimeshift/$run/testdimeshiftLLM_0\""
    ./calculate-auc.sh "/home/vagrant-cc-enhanced/workspace/test-generation-results/resultsDimeshift/$run/testdimeshiftLLM_0" > "/home/vagrant-cc-enhanced/dimeshift-15-run-RESULTS/$run/results-auc.txt" 2>&1 || {
        echo "[ERROR] AUC calculation failed for run $run";
        echo "[DEBUG] Contents of results-auc.txt:";
        cat "/home/vagrant-cc-enhanced/dimeshift-15-run-RESULTS/$run/results-auc.txt" 2>/dev/null || echo "No results-auc.txt file found";
        exit 1;
    }
    
    echo "[$(date)] AUC calculation completed for run $run"
    
    # Phase 4: Copy code coverage results
    echo "[$(date)] Phase 4: Copying code coverage results for run $run..."
    cp -r "$RESULTS_DIR/$run"/* "$FINAL_RESULTS_DIR/$run/" || {
        echo "[ERROR] Failed to copy code coverage results for run $run";
        exit 1;
    }
    
    echo "[$(date)] Code coverage results copied for run $run"
    
    # Phase 5: Process fault data and generate discovery curve
    echo "[$(date)] Phase 5: Processing fault data and generating discovery curve for run $run..."
    cd "$DESKTOP_DIR" || { echo "[ERROR] Failed to cd to Desktop"; exit 1; }
    
    python3 fault-auc.py || {
        echo "[ERROR] Failed to run fault-auc.py for run $run";
        exit 1;
    }
    
    echo "[$(date)] Discovery curve generated for run $run"
    
    # Phase 6: Move Desktop output files to results
    echo "[$(date)] Phase 6: Moving Desktop output files for run $run..."
    
    # Move files if they exist
    [[ -f "$DESKTOP_DIR/fault_discovery_rate.csv" ]] && mv "$DESKTOP_DIR/fault_discovery_rate.csv" "$FINAL_RESULTS_DIR/$run/" || echo "[WARNING] fault_discovery_rate.csv not found for run $run"
    [[ -f "$DESKTOP_DIR/raw_browser_logs.txt" ]] && mv "$DESKTOP_DIR/raw_browser_logs.txt" "$FINAL_RESULTS_DIR/$run/" || echo "[WARNING] raw_browser_logs.txt not found for run $run"
    [[ -f "$DESKTOP_DIR/unique_faults.txt" ]] && mv "$DESKTOP_DIR/unique_faults.txt" "$FINAL_RESULTS_DIR/$run/" || echo "[WARNING] unique_faults.txt not found for run $run"
    [[ -f "$DESKTOP_DIR/discovery_curve.png" ]] && mv "$DESKTOP_DIR/discovery_curve.png" "$FINAL_RESULTS_DIR/$run/" || echo "[WARNING] discovery_curve.png not found for run $run"
    
    echo "[$(date)] Desktop output files moved for run $run"
    echo "[$(date)] === RUN $run COMPLETED SUCCESSFULLY ==="
    
    # Cleanup and rest between runs
    if [ "$run" -lt "$MAX_RUNS" ]; then
        echo "[$(date)] Cleaning up lingering Java processes..."
        pkill -f java || echo "[INFO] No Java processes to kill"
        echo "[$(date)] Resting for 2 minutes before next run..."
        sleep 120
    fi
done

echo "===== ALL $MAX_RUNS RUNS COMPLETED SUCCESSFULLY ====="
echo "[$(date)] Complete analysis finished!"
echo "Results available in: $FINAL_RESULTS_DIR"