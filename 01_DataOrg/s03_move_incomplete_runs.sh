#!/bin/bash
################################################################################
# Script Name: move_incomplete_runs.sh
# Author: Avantika Mathur
# Date: Dec 18th, 2025
#
# Description:
#   This bash script processes neuroimaging data across multiple subjects in 
#   BIDS format. It performs volume integrity checks on functional neuroimaging 
#   files (.nii.gz). For each subject, it identifies functional runs with fewer 
#   than 153 volumes, moves these incomplete runs to a designated incomplete 
#   data directory, and generates a Volumes.txt log file.
#
# Requirements:
#   - AFNI must be loaded (uses 3dinfo command)
#   - Module load: module load afni
#
# Usage:
#   1. Configure IDFILE and SESSION variables below
#   2. Load AFNI: module load afni
#   3. Run: ./check_incomplete_volumes.sh
#
# Creates ID file:
#   cd /path/to/BIDS_raw
#   ls -d sub-* | sort > /path/to/idfile.txt
#
################################################################################

# ===== CONFIGURATION =====
# Path to file containing subject IDs (one per line)
IDFILE="/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/fMRI_Scripts/fMRI_Scripts_LTS_Git/01_DataOrg/idfile_Alisha.txt"

# Session to process (ses-1, ses-2, etc.)
SESSION="ses-2"

# Base paths
BASE_BIDS_RAW="/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/BIDS_raw"
BASE_BIDS_INCOMPLETE="/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/BIDS_raw_incomplete"

# Volume threshold (runs with fewer volumes will be flagged as incomplete)
VOLUME_THRESHOLD=153
# =========================do not change below this line =========================

# Validate idfile exists
if [ ! -f "$IDFILE" ]; then
    echo "❌ Error: $IDFILE not found"
    exit 1
fi

echo "════════════════════════════════════════════════════"
echo "Checking Incomplete Volumes for $SESSION"
echo "Volume Threshold: $VOLUME_THRESHOLD"
echo "════════════════════════════════════════════════════"
echo ""

# Counters
TOTAL_SUBJECTS=0
SUBJECTS_WITH_INCOMPLETE=0
TOTAL_INCOMPLETE_RUNS=0

# Read subject IDs from file
while read -r subject; do
    # Add 'sub-' prefix if not present
    [[ "$subject" != sub-* ]] && subject="sub-$subject"
    
    ((TOTAL_SUBJECTS++))
    
    # Source and destination paths for this subject
    SOURCE_BASE="${BASE_BIDS_RAW}/${subject}/${SESSION}/func"
    DEST_BASE="${BASE_BIDS_INCOMPLETE}/${subject}/${SESSION}/func"

    # Check if source directory exists
    if [ ! -d "$SOURCE_BASE" ]; then
        echo "⚠️  Subject ${subject}: No func directory found"
        continue
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$DEST_BASE"

    # Create or clear the Volumes.txt file
    > "$DEST_BASE/Volumes.txt"

    # Flag to track if any files were moved
    files_moved=false
    incomplete_count=0

    # Iterate through .nii.gz files
    for nifti_file in "$SOURCE_BASE"/*.nii.gz; do
        # Check if file exists
        [ -e "$nifti_file" ] || continue

        # Get number of volumes using 3dinfo
        volumes=$(3dinfo -nv "$nifti_file")

        # Check if volumes are less than threshold
        if [ "$volumes" -lt "$VOLUME_THRESHOLD" ]; then
            # Base filename without extension
            base_filename=$(basename "$nifti_file" .nii.gz)

            # Append volume information to Volumes.txt
            echo "$base_filename: $volumes volumes" >> "$DEST_BASE/Volumes.txt"

            # Move nifti file
            mv "$nifti_file" "$DEST_BASE/"
            files_moved=true
            ((incomplete_count++))
            ((TOTAL_INCOMPLETE_RUNS++))

            # Move corresponding events.tsv if it exists
            if [ -f "$SOURCE_BASE/${base_filename}_events.tsv" ]; then
                mv "$SOURCE_BASE/${base_filename}_events.tsv" "$DEST_BASE/"
            fi

            # Move corresponding .json if it exists
            if [ -f "$SOURCE_BASE/${base_filename}.json" ]; then
                mv "$SOURCE_BASE/${base_filename}.json" "$DEST_BASE/"
            fi
            
            echo "  → Moved: $base_filename ($volumes volumes)"
        fi
    done

    # Provide feedback to terminal
    if [ "$files_moved" = true ]; then
        echo "✅ Subject ${subject}: $incomplete_count incomplete run(s) detected and moved"
        ((SUBJECTS_WITH_INCOMPLETE++))
    else
        echo "✔️  Subject ${subject}: No incomplete runs found"
    fi

    # Remove destination folder if no files were moved and Volumes.txt is empty
    if [ "$files_moved" = false ] && [ ! -s "$DEST_BASE/Volumes.txt" ]; then
        rm "$DEST_BASE/Volumes.txt"
        rmdir "${BASE_BIDS_INCOMPLETE}/${subject}/${SESSION}/func" 2>/dev/null
        rmdir "${BASE_BIDS_INCOMPLETE}/${subject}/${SESSION}" 2>/dev/null
        rmdir "${BASE_BIDS_INCOMPLETE}/${subject}" 2>/dev/null
    fi

done < "$IDFILE"

# Summary
echo ""
echo "════════════════════════════════════════════════════"
echo "✅ Volume Check Complete for $SESSION"
echo "════════════════════════════════════════════════════"
echo "Total subjects processed:     $TOTAL_SUBJECTS"
echo "Subjects with incomplete:     $SUBJECTS_WITH_INCOMPLETE"
echo "Total incomplete runs moved:  $TOTAL_INCOMPLETE_RUNS"
echo ""
echo "Incomplete data location: $BASE_BIDS_INCOMPLETE"