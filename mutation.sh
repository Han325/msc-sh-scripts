#!/bin/bash
# super-aggressive-save.sh

BACKUP_DIR="all-mutations-$(date +%s)"
mkdir -p $BACKUP_DIR

./node_modules/.bin/stryker run --logLevel debug  &
STRYKER_PID=$!

# Check every 0.1 seconds instead of 0.5
while kill -0 $STRYKER_PID 2>/dev/null; do
  if [ -d .stryker-tmp ]; then
    for sandbox in .stryker-tmp/sandbox*; do
      if [ -d "$sandbox" ]; then
        sandbox_name=$(basename "$sandbox")
        if [ ! -d "$BACKUP_DIR/$sandbox_name" ]; then
          cp -r "$sandbox" "$BACKUP_DIR/" 2>/dev/null
          echo "Captured: $sandbox_name"
        fi
      fi
    done
  fi
  sleep 0.1  # Check 10 times per second
done
