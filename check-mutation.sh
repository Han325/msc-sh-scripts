#!/bin/bash
# mutation-summary.sh

# Find the most recent all-mutations folder
MUTATIONS_DIR=$(ls -dt /home/dimeshift-application/all-mutations-* 2>/dev/null | head -1)

if [ -z "$MUTATIONS_DIR" ]; then
    echo "No mutations folder found!"
    exit 1
fi

echo "=== MUTATION SUMMARY ==="
echo "Folder: $(basename $MUTATIONS_DIR)"
echo

total_sandboxes=$(ls "$MUTATIONS_DIR" | grep sandbox | wc -l)
mutated_count=0

# Count sandboxes with actual mutations
for sandbox in "$MUTATIONS_DIR"/sandbox*; do
    if [ ! -d "$sandbox" ]; then continue; fi
    
    # Quick check if any files are different
    has_mutations=false
    for original_file in /home/dimeshift-application/includes/routes/wallets/*.js /home/dimeshift-application/includes/routes/wallets/transactions/*.js; do
        if [ -f "$original_file" ]; then
            relative_path=${original_file#/home/dimeshift-application/}
            mutated_file="$sandbox/$relative_path"
            if [ -f "$mutated_file" ] && ! diff -q "$original_file" "$mutated_file" >/dev/null 2>&1; then
                has_mutations=true
                break
            fi
        fi
    done
    
    if [ "$has_mutations" = true ]; then
        mutated_count=$((mutated_count + 1))
    fi
done

echo "Total sandboxes: $total_sandboxes"
echo "Sandboxes with mutations: $mutated_count"
echo "Empty sandboxes: $((total_sandboxes - mutated_count))"

# Show which files were mutated (unique list)
echo
echo "Files that got mutated:"
for sandbox in "$MUTATIONS_DIR"/sandbox*; do
    for original_file in /home/dimeshift-application/includes/routes/wallets/*.js /home/dimeshift-application/includes/routes/wallets/transactions/*.js; do
        if [ -f "$original_file" ]; then
            relative_path=${original_file#/home/dimeshift-application/}
            mutated_file="$sandbox/$relative_path"
            if [ -f "$mutated_file" ] && ! diff -q "$original_file" "$mutated_file" >/dev/null 2>&1; then
                echo "$relative_path"
            fi
        fi
    done
done | sort | uniq

echo "=== DONE ==="
