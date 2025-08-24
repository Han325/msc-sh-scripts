#!/bin/bash
# improved-mutation-organizer.sh

# Configuration
MUTATIONS_BASE_DIR="/home/dimeshift-application"
ORIGINAL_BASE="/home/dimeshift-application"

# Find the most recent all-mutations folder
MUTATIONS_DIR=$(ls -dt "$MUTATIONS_BASE_DIR"/all-mutations-* 2>/dev/null | head -1)

if [ -z "$MUTATIONS_DIR" ]; then
   echo "❌ No mutations folder found!"
   exit 1
fi

echo "🔍 Analyzing mutations in $(basename "$MUTATIONS_DIR")..."

# Create organized output directory
TIMESTAMP=$(date +%s)
OUTPUT_DIR="$MUTATIONS_BASE_DIR/organized-mutations-$TIMESTAMP"
mkdir -p "$OUTPUT_DIR"

# Define file categories and their paths
declare -A CATEGORIES=(
   ["wallet-routes"]="includes/routes/wallets/*.js"
   ["transaction-routes"]="includes/routes/wallets/transactions/*.js" 
   ["plan-routes"]="includes/routes/plans/*.js"
   ["access-routes"]="includes/routes/wallets/accesses/*.js"
   ["models"]="includes/models/*.js"
   ["frontend-pages"]="public/scripts/app/views/pages/*.js"
   ["frontend-dialogs"]="public/scripts/app/views/dialogs/*.js"
)

total_sandboxes=0
processed_sandboxes=0

# Process each sandbox
for sandbox in "$MUTATIONS_DIR"/sandbox*; do
   if [ ! -d "$sandbox" ]; then continue; fi
   
   sandbox_name=$(basename "$sandbox")
   total_sandboxes=$((total_sandboxes + 1))
   
   # Check which category this sandbox belongs to
   found_category=""
   mutated_files=()
   
   for category in "${!CATEGORIES[@]}"; do
       pattern="${CATEGORIES[$category]}"
       
       # Check files in this category for mutations
       for original_file in $ORIGINAL_BASE/$pattern; do
           if [ -f "$original_file" ]; then
               relative_path=${original_file#$ORIGINAL_BASE/}
               mutated_file="$sandbox/$relative_path"
               
               if [ -f "$mutated_file" ] && ! diff -q "$original_file" "$mutated_file" >/dev/null 2>&1; then
                   found_category="$category"
                   mutated_files+=("$relative_path")
               fi
           fi
       done
       
       # If we found mutations in this category, break
       if [ -n "$found_category" ]; then
           break
       fi
   done
   
   # If mutations found, copy to organized folder and show what was found
   if [ -n "$found_category" ]; then
       category_dir="$OUTPUT_DIR/$found_category"
       mkdir -p "$category_dir"
       cp -r "$sandbox" "$category_dir/"
       processed_sandboxes=$((processed_sandboxes + 1))
       
       # Show what was mutated (compact format)
       echo "  ✅ $sandbox_name → ${mutated_files[0]}"
       
       # Create a summary file for this sandbox
       echo "Sandbox: $sandbox_name" > "$category_dir/$sandbox_name-summary.txt"
       echo "Mutated files:" >> "$category_dir/$sandbox_name-summary.txt"
       for file in "${mutated_files[@]}"; do
           echo "  - $file" >> "$category_dir/$sandbox_name-summary.txt"
       done
   fi
done

# Generate final report
echo ""
echo "📊 ANALYSIS COMPLETE"
echo "===================="
echo "Total: $total_sandboxes | With mutations: $processed_sandboxes | Empty: $((total_sandboxes - processed_sandboxes))"
echo "Saved to: $(basename "$OUTPUT_DIR")"
echo ""

# Show category breakdown with file examples
echo "📁 MUTATIONS BY CATEGORY:"
for category in "${!CATEGORIES[@]}"; do
   category_dir="$OUTPUT_DIR/$category"
   if [ -d "$category_dir" ]; then
       count=$(ls "$category_dir" 2>/dev/null | grep sandbox | wc -l)
       if [ "$count" -gt 0 ]; then
           # Get first mutated file as example
           first_summary=$(ls "$category_dir"/*-summary.txt 2>/dev/null | head -1)
           if [ -f "$first_summary" ]; then
               example_file=$(grep "  - " "$first_summary" | head -1 | sed 's/  - //')
               echo "  $category: $count mutations (e.g., $example_file)"
           else
               echo "  $category: $count mutations"
           fi
       fi
   fi
done

echo ""
echo "✅ Ready for testing!"
