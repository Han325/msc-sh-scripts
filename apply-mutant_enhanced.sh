#!/bin/bash

# ==============================================================================
# apply-mutant.sh (FLEXIBLE VERSION)
#
# Takes a patch file AND the project's base folder as arguments.
# It derives all other paths from the project folder.
# ==============================================================================

# --- Main Logic ---

# 1. Check for input
PATCH_FILE=$1
PROJECT_NAME=$2 # NEW: The main project folder, e.g., /home/vagrant/.../dimeshift
if [ -z "$PATCH_FILE" ] || [ -z "$PROJECT_NAME" ]; then
  echo "FUCK: You need to provide a patch file AND the project folder."
  echo "Usage: ./apply-mutant.sh /path/to/patch.diff project_name"
  exit 1
fi
if [ ! -f "$PATCH_FILE" ]; then
  echo "FUCK: Can't find the patch file at '$PATCH_FILE'"
  exit 1
fi

# --- Dynamically determine paths based on project folder ---
COMPOSE_DIRECTORY="/home/vagrant-cc-enhanced/workspace/fse2019/${PROJECT_NAME}"
HOST_CODE_DIR="/home/vagrant-cc-enhanced/Desktop/${PROJECT_NAME}-code"
ORIGINAL_CODE_DIR="/home/vagrant-cc-enhanced/Desktop/${PROJECT_NAME}-og-code"

echo "--- Applying Mutant: $(basename "$PATCH_FILE") ---"
echo "  -> Project:           $PROJECT_NAME"
echo "  -> Compose Directory:   $COMPOSE_DIRECTORY"
echo "  -> Working Code Dir:    $HOST_CODE_DIR"
echo "  -> Original Code Dir:   $ORIGINAL_CODE_DIR"
echo "------------------------------------------------------------"

# Go to the docker-compose project directory
cd "$COMPOSE_DIRECTORY" || { echo "FATAL: Could not cd to $COMPOSE_DIRECTORY"; exit 1; }

# ... (The rest of the script is the same, but more robust now) ...
echo "[Step 1/5] Stopping service 'webapp'..."
docker compose stop webapp &>/dev/null

echo "[Step 2/5] Restoring clean code from '$ORIGINAL_CODE_DIR'..."
rm -rf "${HOST_CODE_DIR:?}"/*
cp -r "$ORIGINAL_CODE_DIR"/* "$HOST_CODE_DIR/"
echo "  -> Clean code restored."

echo "[Step 3/5] Applying patch..."
patch_output=$(patch -p1 -d "$HOST_CODE_DIR" < "$PATCH_FILE" 2>&1)
patch_exit_code=$?
if [ $patch_exit_code -ne 0 ]; then
    echo "FUCK! The patch command failed. Here's what it said:"
    echo "$patch_output"
    exit 1
fi
echo "  -> Patch applied successfully."

echo "[Step 4/5] Starting service 'webapp' with mutated code..."
docker compose up -d webapp

echo "[Step 5/5] Waiting for container '${PROJECT_NAME}' to become healthy..."
healthy=false
for i in {1..180}; do
    status=$(docker inspect --format='{{.State.Health.Status}}' "$PROJECT_NAME" 2>/dev/null)
    if [ "$status" == "healthy" ]; then
        healthy=true
        break
    fi
    sleep 1
done

echo "------------------------------------------------------------"
if [ "$healthy" = true ]; then
    echo "SUCCESS: Mutant applied. Container is healthy."
    exit 0
else
    echo "FAILURE: Mutant KILLED. Container failed to become healthy."
    exit 1
fi
