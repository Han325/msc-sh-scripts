#!/bin/bash

# ===== CONFIG =====
DESKTOP_DIR="/home/vagrant/Desktop"
RETROBOARD_DIR="/home/vagrant/workspace/fse2019/retroboard"
CONSERVED_DIR="$DESKTOP_DIR/retroboard-conserved-extra-5"
MAX_RUNS=5
SLEEP_INTERVAL=60  # Check every 1 minute (not 10s) for long runs
LOG_PATTERN="llm_debug_story_*.log"
# ==================

# Initialize with existing folders
LAST_NUM=$(find "$CONSERVED_DIR" -maxdepth 1 -type d -name '[0-9]*' | sed 's|.*/||' | sort -n | tail -1)
LAST_NUM=${LAST_NUM:-0}

while [ "$LAST_NUM" -lt "$MAX_RUNS" ]; do
    NEXT_NUM=$((LAST_NUM + 1))
    echo "===== RUN $NEXT_NUM/$MAX_RUNS STARTING ====="
    echo "[$(date)] Experiment started"

    # --- Run Experiment ---
    cd "$RETROBOARD_DIR" || { echo "[ERROR] Failed to cd to $RETROBOARD_DIR"; exit 1; }
    ./runExp.sh 1 DIGSI APOGEN 7200 || {
        echo "[ERROR] Experiment failed! Retrying in 5 minutes...";
        sleep 300;
        continue;
    }

    # --- Wait for Completion ---
    echo "[$(date)] Waiting for output files..."
    while :; do
        # Check for BOTH required files
        if [[ -d "$DESKTOP_DIR/testretroboardAdaptiveComplete_0" ]] && \
           [[ -n "$(find "$DESKTOP_DIR" -maxdepth 1 -name "$LOG_PATTERN" -print -quit)" ]]; then
            break
        fi
        echo "[$(date)] Still waiting... (sleeping $SLEEP_INTERVAL seconds)"
        sleep $SLEEP_INTERVAL
    done

    # --- File Management ---
    echo "[$(date)] Moving results to $CONSERVED_DIR/$NEXT_NUM/"
    mkdir -p "$CONSERVED_DIR/$NEXT_NUM" || { echo "[ERROR] Failed to create folder"; exit 1; }

    # Move directory
    mv "$DESKTOP_DIR/testretroboardAdaptiveComplete_0" "$CONSERVED_DIR/$NEXT_NUM/" || {
        echo "[ERROR] Failed to move results directory";
        exit 1;
    }

    # Move ALL matching log files (handles multiple logs)
    find "$DESKTOP_DIR" -maxdepth 1 -name "$LOG_PATTERN" -exec mv {} "$CONSERVED_DIR/$NEXT_NUM/" \; || {
        echo "[WARNING] Some log files may not have moved";
    }

    # --- Cleanup & Prep Next ---
    LAST_NUM=$NEXT_NUM
    echo "[$(date)] Run $NEXT_NUM completed successfully"
    
    if [ "$LAST_NUM" -ge "$MAX_RUNS" ]; then
        echo "===== ALL $MAX_RUNS RUNS COMPLETED ====="
        exit 0
    fi

    echo "[$(date)] Cleaning up lingering Java processes..."
    pkill -f java

    echo "[$(date)] Cooling down for 5 minutes..."
    sleep 300
    
done
