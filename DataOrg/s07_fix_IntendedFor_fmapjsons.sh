#!/bin/bash
################################################################################
# Script Name: update_fmap_intendedfor.sh
# BIDS Fieldmap IntendedFor Metadata Updater
# Author: Avantika Mathur
# Date: 17 Dec 2025
# Last Modified: 25 March 2026
#
# Description:
#   This script automates the process of updating fieldmap JSON files in a BIDS 
#   dataset by adding an IntendedFor field. It matches functional MRI and DWI 
#   files with corresponding fieldmaps based on a shared day identifier 
#   (e.g., D1, D2, D3).
#
# Important:
#   - Merges with existing IntendedFor entries (no duplicates)
#   - Only matches dti96 files (96-direction DTI scans)
#   - Excludes dti6 files (low-resolution calibration scans)
#   - Matches all func files from the same day
#   - Safe to run multiple times (idempotent)
#
################################################################################

# ===== USER INPUT =====
read -p "Enter session number (e.g., 1): " SESSION_NUM

if [[ -z "$SESSION_NUM" ]]; then
    echo "❌ Error: Session number cannot be empty"
    exit 1
fi

SESSION_DIR="ses-$SESSION_NUM"

# Check if idfile exists
IDFILE="idfile.txt"
if [ ! -f "$IDFILE" ]; then
    echo "❌ Error: $IDFILE not found"
    exit 1
fi

# BIDS directory configuration
BIDS_DIR="/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/BIDS_raw"

###############do not change anything below this line##################
echo ""
echo "════════════════════════════════════════════════════"
echo "Starting IntendedFor Update for Session $SESSION_NUM"
echo "════════════════════════════════════════════════════"
echo ""

# Initialize counters
TOTAL_SUBJECTS=0
TOTAL_FMAPS_UPDATED=0
TOTAL_FMAPS_SKIPPED=0
TOTAL_FUNC_FILES=0
TOTAL_DWI_FILES=0
TOTAL_DTI6_SKIPPED=0
TOTAL_DUPLICATES_AVOIDED=0


# Read subject IDs from idfile
while read -r SUBJ_ID; do
    [[ "$SUBJ_ID" != sub-* ]] && SUBJ_ID="sub-$SUBJ_ID"
    
    subject="$BIDS_DIR/$SUBJ_ID"
    
    if [ ! -d "$subject" ]; then
        echo "⚠️  Skipping $SUBJ_ID - directory not found"
        continue
    fi

    ((TOTAL_SUBJECTS++))
    echo "===================="
    echo "Processing: $SUBJ_ID"
    echo "===================="

    # Find directories
    fmap_dir="$subject/$SESSION_DIR/fmap"
    func_dir="$subject/$SESSION_DIR/func"
    dwi_dir="$subject/$SESSION_DIR/dwi"
    
    echo "  Directories:"
    echo "    fmap: $fmap_dir"
    echo "    func: $func_dir"
    echo "    dwi:  $dwi_dir"

    if [ ! -d "$fmap_dir" ]; then
        echo "  ⚠️  No fmap directory - skipping subject"
        continue
    fi

    # Check if func and/or dwi directories exist
    HAS_FUNC=false
    HAS_DWI=false
    [ -d "$func_dir" ] && HAS_FUNC=true
    [ -d "$dwi_dir" ] && HAS_DWI=true

    if [ "$HAS_FUNC" = false ] && [ "$HAS_DWI" = false ]; then
        echo "  ⚠️  No func or dwi directories - skipping subject"
        continue
    fi

    # Process each fmap JSON
    for fmap_json in "$fmap_dir"/*.json; do
        [ -f "$fmap_json" ] || continue

        fmap_basename=$(basename "$fmap_json")
        echo ""
        echo "  ? Processing fmap: $fmap_basename"

        # Extract day from fmap filename
        fmap_day=$(basename "$fmap_json" | grep -oP 'D\d+')
        
        if [[ -z "$fmap_day" ]]; then
            echo "    ⚠️  No day identifier found - skipping"
            continue
        fi
        
        echo "    → Detected Day: $fmap_day"

        # ===== CHECK FOR EXISTING IntendedFor =====
        existing_files=()
        if jq -e '.IntendedFor' "$fmap_json" >/dev/null 2>&1; then
            echo "    ? Found existing IntendedFor field"
            # Read existing entries into array
            while IFS= read -r line; do
                existing_files+=("$line")
            done < <(jq -r '.IntendedFor[]?' "$fmap_json")
            
            if [ ${#existing_files[@]} -gt 0 ]; then
                echo "      → Existing entries: ${#existing_files[@]} file(s)"
            fi
        fi

        # Initialize array for NEW intended files
        new_intended_files=()

        # ===== MATCH FUNCTIONAL FILES =====
        if [ "$HAS_FUNC" = true ]; then
            echo "    ? Checking func files..."
            func_count=0
            
            for func_nii in "$func_dir"/*.nii.gz; do
                [ -f "$func_nii" ] || continue

                func_filename=$(basename "$func_nii")
                func_day=$(echo "$func_filename" | grep -oP 'D\d+')
                
                if [[ "$func_day" == "$fmap_day" ]]; then
                    relative_path="$SESSION_DIR/func/$func_filename"
                    
                    # Check if already in existing_files
                    if [[ " ${existing_files[@]} " =~ " ${relative_path} " ]]; then
                        echo "      ⏭️  Already exists: $func_filename"
                        ((TOTAL_DUPLICATES_AVOIDED++))
                    else
                        new_intended_files+=("$relative_path")
                        echo "      ✅ Matched func: $func_filename"
                        ((func_count++))
                        ((TOTAL_FUNC_FILES++))
                    fi
                fi
            done
            
            if [ $func_count -eq 0 ]; then
                echo "      ⚠️  No new matching func files for $fmap_day"
            fi
        fi

        # ===== MATCH DIFFUSION FILES (dti96 ONLY) =====
        if [ "$HAS_DWI" = true ]; then
            echo "    ? Checking dwi files (dti96 only)..."
            dwi_count=0
            
            for dwi_nii in "$dwi_dir"/*.nii.gz; do
                [ -f "$dwi_nii" ] || continue

                dwi_filename=$(basename "$dwi_nii")
                dwi_day=$(echo "$dwi_filename" | grep -oP 'D\d+')
                
                # Filter: Only include dti96 files
                if [[ ! "$dwi_filename" =~ dti96 ]]; then
                    echo "      ⏭️  Skipped (not dti96): $dwi_filename"
                    ((TOTAL_DTI6_SKIPPED++))
                    continue
                fi
                
                if [[ "$dwi_day" == "$fmap_day" ]]; then
                    relative_path="$SESSION_DIR/dwi/$dwi_filename"
                    
                    # Check if already in existing_files
                    if [[ " ${existing_files[@]} " =~ " ${relative_path} " ]]; then
                        echo "      ⏭️  Already exists: $dwi_filename"
                        ((TOTAL_DUPLICATES_AVOIDED++))
                    else
                        new_intended_files+=("$relative_path")
                        echo "      ✅ Matched dti96: $dwi_filename"
                        ((dwi_count++))
                        ((TOTAL_DWI_FILES++))
                    fi
                fi
            done
            
            if [ $dwi_count -eq 0 ]; then
                echo "      ⚠️  No new matching dti96 files for $fmap_day"
            fi
        fi

        # ===== MERGE AND UPDATE JSON =====
        # Combine existing and new files
        all_intended_files=("${existing_files[@]}" "${new_intended_files[@]}")
        
        if [ ${#new_intended_files[@]} -gt 0 ]; then
            echo "    ? Updating IntendedFor..."
            echo "      → Total files: ${#all_intended_files[@]} (${#existing_files[@]} existing + ${#new_intended_files[@]} new)"
            
            # Create JSON array
            intended_files_json=$(printf '%s\n' "${all_intended_files[@]}" | jq -R . | jq -s . | tr -d '\n')
            
            # Update JSON
            jq --argjson files "$intended_files_json" \
               '. + {"IntendedFor": $files}' "$fmap_json" > "${fmap_json}.tmp" 
            
            # Validate and replace
            if jq empty "${fmap_json}.tmp" 2>/dev/null; then
                mv "${fmap_json}.tmp" "$fmap_json"
                echo "    ✅ Updated IntendedFor with ${#all_intended_files[@]} total file(s)"
                ((TOTAL_FMAPS_UPDATED++))
            else
                echo "    ❌ ERROR: Invalid JSON produced - original preserved"
                rm "${fmap_json}.tmp"
            fi
        elif [ ${#existing_files[@]} -gt 0 ]; then
            echo "    ✅ No new files to add (${#existing_files[@]} existing entries already correct)"
            ((TOTAL_FMAPS_SKIPPED++))
        else
            echo "    ⚠️  No matching files found for $fmap_day - no update"
            ((TOTAL_FMAPS_SKIPPED++))
        fi
    done

    echo ""

done < "$IDFILE"

# Summary
echo "════════════════════════════════════════════════════"
echo "✅ Completed IntendedFor Updates for $SESSION_DIR"
echo "════════════════════════════════════════════════════"
echo "Subjects processed:        $TOTAL_SUBJECTS"
echo "Fmaps updated:             $TOTAL_FMAPS_UPDATED"
echo "Fmaps skipped (no change): $TOTAL_FMAPS_SKIPPED"
echo "Func files added:          $TOTAL_FUNC_FILES"
echo "DTI96 files added:         $TOTAL_DWI_FILES"
echo "DTI6 files skipped:        $TOTAL_DTI6_SKIPPED"
echo "Duplicates avoided:        $TOTAL_DUPLICATES_AVOIDED"
echo "Total new files added:     $((TOTAL_FUNC_FILES + TOTAL_DWI_FILES))"
echo ""