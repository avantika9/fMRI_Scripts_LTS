#!/bin/bash
# Script to create a Volumes.txt file in the BIDS_raw_incomplete directory with the number of volumes for each nifti file, and a total at the end.

BIDS_INCOMPLETE="/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/BIDS_raw_incomplete"
OUTPUT_FILE="${BIDS_INCOMPLETE}/Volumes.txt"

> "$OUTPUT_FILE"

total_volumes=0

find "$BIDS_INCOMPLETE" \( -name "*.nii.gz" -o -name "*.nii" \) | sort | while read file; do
    volumes=$(3dinfo -nv "$file" 2>/dev/null)
    
    # Default to 1 if unable to read
    volumes=${volumes:-1}
    
    echo "$(basename $file): $volumes volumes" >> "$OUTPUT_FILE"
    
done

# Calculate and append total
total=$(awk -F': ' '{gsub(" volumes", ""); sum+=$2} END {print sum}' "$OUTPUT_FILE")
echo "---" >> "$OUTPUT_FILE"
echo "TOTAL: $total" >> "$OUTPUT_FILE"

echo "Volumes.txt created successfully"
cat "$OUTPUT_FILE"