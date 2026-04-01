#!/bin/bash
################################################################################
# Script Name: cleanup_dicom_folders.sh
# Author: Avantika Mathur
# Date: 25 March 2026
#
# Description:
#   Cleans up DICOM directories by removing .nii, .nii.gz, and .json files
#   while preserving .dcm and .txt files.
#
# Usage:
#   # Dry run (see what will be deleted):
#   ./cleanup_dicom_folders.sh
#
#   # Actually delete files:
#   ./cleanup_dicom_folders.sh --delete
#
################################################################################

# ===== CONFIGURATION =====
#BASE_DIR="/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/dicoms_downloads"
BASE_DIR="/panfs/accrepfs.vampire/data/booth_lab/DHH/dicoms_downloads"
IDFILE=""  # Optional: specify subjects, or leave blank to process all
# =========================

# Check if --delete flag was provided
DELETE_MODE=false
if [[ "$1" == "--delete" ]]; then
    DELETE_MODE=true
    echo "⚠️  DELETE MODE ENABLED - Files will be permanently removed"
else
    echo "? DRY RUN MODE - No files will be deleted (use --delete to actually remove files)"
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "Cleaning DICOM Directories"
echo "Base Directory: $BASE_DIR"
echo "════════════════════════════════════════════════════"
echo ""

# Counters
TOTAL_SUBJECTS=0
TOTAL_NII_FILES=0
TOTAL_JSON_FILES=0
TOTAL_FILES_DELETED=0

# Function to process a subject directory
process_subject() {
    local subject_dir="$1"
    local subject=$(basename "$subject_dir" | sed 's/_dicoms$//')
    
    echo "Processing: $subject"
    
    # Find all session/acquisition subdirectories
    for session_dir in "$subject_dir"/*_dicoms; do
        [ -d "$session_dir" ] || continue
        
        local session_name=$(basename "$session_dir")
        echo "  → $session_name"
        
        local files_found=false
        
        # Find and handle .nii and .nii.gz files
        while IFS= read -r -d '' file; do
            files_found=true
            if [ "$DELETE_MODE" = true ]; then
                rm -f "$file"
                echo "    ❌ Deleted: $(basename "$file")"
                ((TOTAL_FILES_DELETED++))
            else
                echo "    ? Would delete: $(basename "$file")"
            fi
            ((TOTAL_NII_FILES++))
        done < <(find "$session_dir" -type f \( -name "*.nii" -o -name "*.nii.gz" \) -print0)
        
        # Find and handle .json files
        while IFS= read -r -d '' file; do
            files_found=true
            if [ "$DELETE_MODE" = true ]; then
                rm -f "$file"
                echo "    ❌ Deleted: $(basename "$file")"
                ((TOTAL_FILES_DELETED++))
            else
                echo "    ? Would delete: $(basename "$file")"
            fi
            ((TOTAL_JSON_FILES++))
        done < <(find "$session_dir" -type f -name "*.json" -print0)
        
        if [ "$files_found" = false ]; then
            echo "    ✅ Clean (no .nii or .json files found)"
        fi
    done
    
    echo ""
}

# Check if IDFILE exists and process specific subjects
if [ -n "$IDFILE" ] && [ -f "$IDFILE" ]; then
    echo "Using subject list from: $IDFILE"
    echo ""
    
    while read -r subject; do
        # Remove 'sub-' prefix if present and add '_dicoms' suffix
        subject=$(echo "$subject" | sed 's/^sub-//')
        subject_dir="$BASE_DIR/sub-${subject}_dicoms"
        
        if [ -d "$subject_dir" ]; then
            ((TOTAL_SUBJECTS++))
            process_subject "$subject_dir"
        else
            echo "⚠️  Not found: $subject_dir"
        fi
    done < "$IDFILE"
    
else
    # Process all subject directories
    echo "Processing all subjects in $BASE_DIR"
    echo ""
    
    for subject_dir in "$BASE_DIR"/sub-*_dicoms; do
        [ -d "$subject_dir" ] || continue
        ((TOTAL_SUBJECTS++))
        process_subject "$subject_dir"
    done
fi

# Summary
echo "════════════════════════════════════════════════════"
if [ "$DELETE_MODE" = true ]; then
    echo "✅ Cleanup Complete"
else
    echo "? Dry Run Complete"
fi
echo "════════════════════════════════════════════════════"
echo "Subjects processed:      $TOTAL_SUBJECTS"
echo ".nii/.nii.gz files:      $TOTAL_NII_FILES"
echo ".json files:             $TOTAL_JSON_FILES"
echo "Total files:             $((TOTAL_NII_FILES + TOTAL_JSON_FILES))"

if [ "$DELETE_MODE" = true ]; then
    echo "Files deleted:           $TOTAL_FILES_DELETED"
else
    echo ""
    echo "⚠️  No files were deleted (dry run mode)"
    echo "To actually delete files, run:"
    echo "  ./cleanup_dicom_folders.sh --delete"
fi
echo ""