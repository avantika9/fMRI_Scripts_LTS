#!/bin/bash
################################################################################
# Script Name: s04_bids_fix_funcfmapdti.sh
# Author: AM
# Date: 8th Dec 2025
# Last Updated: 24 March 2026
#
# Description:
#   This Bash script performs systematic modifications to BIDS (Brain Imaging 
#   Data Structure) JSON and file naming across multiple subject directories.
#
# Tasks:
#   1. Field Mapping (fmap) JSON Modifications:
#      - Replaces deprecated JSON keys with BIDS-compliant keys
#      - EstimatedEffectiveEchoSpacing → EffectiveEchoSpacing
#      - EstimatedTotalReadoutTime → TotalReadoutTime
#      - PhaseEncodingAxis → PhaseEncodingDirection
#
#   2. Functional (func) JSON Modifications:
#      - Extracts task name from filename
#      - Inserts TaskName key as first entry if not present
#      - Updates deprecated keys
#
#   3. Diffusion (dwi) Modifications:
#      - Renames dti/ folder to dwi/ if exists
#      - Updates deprecated JSON keys
#      - Renames files: _epi → _dwi
#      - Removes underscore between acquisition label and dti number
#
#   4. Sets all JSON files to permission 770
#
################################################################################

# ===== CONFIGURATION =====
BASE_DIR="/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/BIDS_raw"
IDFILE="idfile_ses2.txt"
SESSION="ses-2"  # Change to "ses-2" as needed
# ========================= do not edit below this line =========================

# Validate idfile exists
if [ ! -f "$IDFILE" ]; then
    echo "❌ Error: $IDFILE not found"
    exit 1
fi

echo "════════════════════════════════════════════════════"
echo "Starting BIDS Modifications for $SESSION"
echo "════════════════════════════════════════════════════"
echo ""

# Counters
TOTAL_SUBJECTS=0
TOTAL_JSON_MODIFIED=0

# Read subject IDs from idfile.txt
while read -r subj; do
    # Add 'sub-' prefix if not present
    [[ "$subj" != sub-* ]] && subj="sub-$subj"
    
    subj_dir="${BASE_DIR}/${subj}/${SESSION}"
    
    # Check if subject directory exists
    if [ ! -d "$subj_dir" ]; then
        echo "⚠️  Skipping $subj - directory not found"
        continue
    fi
    
    ((TOTAL_SUBJECTS++))
    echo "===================="
    echo "Processing ${subj} (${SESSION})"
    echo "===================="

    ## 1. === FOLDER: fmap ===
    fmap_dir="${subj_dir}/fmap"
    if [ -d "$fmap_dir" ]; then
        echo "  ? Processing fmap folder..."
        for json_file in "${fmap_dir}"/*.json; do
            [ -e "$json_file" ] || continue
            echo "    → Editing: $(basename ${json_file})"

            # Replace keys to conform with new BIDS format
            sed -i \
                -e 's/"EstimatedEffectiveEchoSpacing"/"EffectiveEchoSpacing"/g' \
                -e 's/"EstimatedTotalReadoutTime"/"TotalReadoutTime"/g' \
                -e 's/"PhaseEncodingAxis"/"PhaseEncodingDirection"/g' \
                "$json_file"
            
            # Set permissions to 770
            chmod 770 "$json_file"
            ((TOTAL_JSON_MODIFIED++))
        done
    else
        echo "  ⚠️  No fmap directory"
    fi

    ## 2. === FOLDER: func ===
    func_dir="${subj_dir}/func"
    if [ -d "$func_dir" ]; then
        echo "  ? Processing func folder..."
        for json_file in "${func_dir}"/*.json; do
            [ -e "$json_file" ] || continue
            echo "    → Editing: $(basename ${json_file})"
            
            # Check if TaskName already exists
            if grep -q '"TaskName"' "$json_file"; then
                echo "      ✅ TaskName already present, skipping insertion"
            else
                # Extract task name from filename
                fname=$(basename "$json_file")
                task_name=$(echo "$fname" | grep -o 'task-[^_]*' | cut -d'-' -f2)

                if [ -n "$task_name" ]; then
                    # Insert new TaskName as the first key (after opening brace)
                    tmpfile=$(mktemp)
                    echo '{' > "$tmpfile"
                    printf '    "TaskName": "%s",\n' "$task_name" >> "$tmpfile"
                    tail -n +2 "$json_file" >> "$tmpfile"
                    mv "$tmpfile" "$json_file"
                    echo "      ✅ Added TaskName: $task_name"
                else
                    echo "      ⚠️  Could not extract task name from filename"
                fi
            fi
            
            # Replace keys to conform with new BIDS format
            sed -i \
                -e 's/"EstimatedEffectiveEchoSpacing"/"EffectiveEchoSpacing"/g' \
                -e 's/"EstimatedTotalReadoutTime"/"TotalReadoutTime"/g' \
                -e 's/"PhaseEncodingAxis"/"PhaseEncodingDirection"/g' \
                "$json_file"
            
            # Set permissions to 770
            chmod 770 "$json_file"
            ((TOTAL_JSON_MODIFIED++))
        done
    else
        echo "  ⚠️  No func directory"
    fi

    ## 3. === FOLDER: dti → dwi ===
    dti_dir="${subj_dir}/dti"
    dwi_dir="${subj_dir}/dwi"
    
    # Rename dti folder to dwi if it exists
    if [ -d "$dti_dir" ]; then
        echo "  ? Renaming folder: dti → dwi"
        mv "$dti_dir" "$dwi_dir"
    fi
    
    # Process dwi directory (after potential rename)
    if [ -d "$dwi_dir" ]; then
        echo "  ? Processing dwi folder..."
        
        # Rename _epi files to _dwi
        for file in "${dwi_dir}"/*_epi.*; do
            [ -e "$file" ] || continue

            # First change "_epi" to "_dwi"
            newfile="${file/_epi./_dwi.}"

            # Then remove underscore between acquisition and dti label
            newfile=$(echo "$newfile" | sed -E 's/(acq-[^_]+)_(dti[0-9]+)/\1\2/')

            if [ "$file" != "$newfile" ]; then
                echo "    → Renaming: $(basename $file) → $(basename $newfile)"
                mv "$file" "$newfile"
            fi
        done
        
        ## 4. === DWI JSON Modifications ===
        for json_file in "${dwi_dir}"/*.json; do
            [ -e "$json_file" ] || continue
            echo "    → Editing: $(basename ${json_file})"

            # Replace keys to conform with new BIDS format
            sed -i \
                -e 's/"EstimatedEffectiveEchoSpacing"/"EffectiveEchoSpacing"/g' \
                -e 's/"EstimatedTotalReadoutTime"/"TotalReadoutTime"/g' \
                -e 's/"PhaseEncodingAxis"/"PhaseEncodingDirection"/g' \
                "$json_file"
            
            # Set permissions to 770
            chmod 770 "$json_file"
            ((TOTAL_JSON_MODIFIED++))
        done
    else
        echo "  ⚠️  No dwi/dti directory"
    fi
    
    echo ""

done < "$IDFILE"

# Summary
echo "════════════════════════════════════════════════════"
echo "✅ BIDS Modifications Complete for $SESSION"
echo "════════════════════════════════════════════════════"
echo "Subjects processed:     $TOTAL_SUBJECTS"
echo "JSON files modified:    $TOTAL_JSON_MODIFIED"
echo "All JSON files set to:  770 permissions"
echo ""