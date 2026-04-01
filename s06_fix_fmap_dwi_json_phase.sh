# Script Name: fix_fmap_dwi_json_phase.sh
# Author: AM
# Date Created: March25th,2026
# Last Modified: March25th,2026
#
# Description:
#   This script processes BIDS neuroimaging data to fix naming conventions and
#   metadata for fieldmap (fmap) and diffusion weighted imaging (dwi) directories.
#   It performs three main operations:
#   1. Corrects PhaseEncodingDirection in JSON metadata (j → j-)
#   2. Renames files containing "APP" to "AP" (Anterior-Posterior)
#   3. Renames files containing "APA" to "PA" (Posterior-Anterior)
# Configuration:
#   BIDS_DIR  : Base directory containing BIDS dataset
#   IDFILE    : Text file with subject IDs (with or without 'sub-' prefix)
#   SESSION   : Session identifier (ses-1 or ses-2)
#
# Directories Processed:
#   - {BIDS_DIR}/{subject}/{session}/fmap/
#   - {BIDS_DIR}/{subject}/{session}/dwi/
#
# Files Modified:
#   FMAP folder:
#     - *.json (PhaseEncodingDirection field)
#     - *APP*.json, *APP*.nii.gz → *AP*.json, *AP*.nii.gz
#     - *APA*.json, *APA*.nii.gz → *PA*.json, *PA*.nii.gz
#
#   DWI folder:
#     - *.json (PhaseEncodingDirection field)
#     - *APP*.json, *APP*.nii.gz, *APP*.bval, *APP*.bvec → *AP*.*
#     - *APA*.json, *APA*.nii.gz, *APA*.bval, *APA*.bvec → *PA*.*
#
# Usage:
#   ./fix_app_json_phase.sh
#
# Notes:
#   - Script can be run multiple times safely (checks for files before renaming)
#   - Skips subjects/sessions if directories don't exist
#   - Provides detailed console output for tracking progress

# ===== CONFIGURATION =====
BIDS_DIR="/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/BIDS_raw"
IDFILE="idfile_ses2.txt"
SESSION="ses-2"  # Change to "ses-2" as needed
# =========================do not edit below this line =========================

for SUBJ_ID in $(cat "$IDFILE"); do
  [[ "$SUBJ_ID" != sub-* ]] && SUBJ_ID="sub-$SUBJ_ID"
  
  echo "===================="
  echo "Processing $SUBJ_ID ($SESSION)"
  echo "===================="
  
  ## === FMAP FOLDER ===
  FMAP_DIR="$BIDS_DIR/$SUBJ_ID/$SESSION/fmap"

  if [ ! -d "$FMAP_DIR" ]; then
    echo "⚠️  Skipping fmap — folder not found."
  else
    echo "📁 Processing fmap folder..."
    
   
    # Rename APA to PA in filenames
    for JSON in "$FMAP_DIR"/*APA*.json; do
      [ -f "$JSON" ] || continue
      base_filename=$(basename "$JSON" .json)
      nii_file="${FMAP_DIR}/${base_filename}.nii.gz"
      
      if [[ "$base_filename" == *"dir-APA"* ]]; then
        new_base_filename=$(echo "$base_filename" | sed 's/dir-APA/dir-PA/')
        
        # Move JSON
        if [ -f "$JSON" ]; then
          mv "$JSON" "${FMAP_DIR}/${new_base_filename}.json" || echo "  ❌ Error moving JSON"
        fi
        
        # Move NII if exists
        if [ -f "$nii_file" ]; then
          mv "$nii_file" "${FMAP_DIR}/${new_base_filename}.nii.gz" || echo "  ❌ Error moving NII"
        fi
        
        echo "  ✅ Renamed $base_filename: APA → PA"
      fi
    done 

    # Rename APP to AP in filenames
    for JSON in "$FMAP_DIR"/*APP*.json; do
      [ -f "$JSON" ] || continue
      base_filename=$(basename "$JSON" .json)
      nii_file="${FMAP_DIR}/${base_filename}.nii.gz"
      
      if [[ "$base_filename" == *"dir-APP"* ]]; then
        new_base_filename=$(echo "$base_filename" | sed 's/dir-APP/dir-AP/')
        
        # Move JSON
        if [ -f "$JSON" ]; then
          mv "$JSON" "${FMAP_DIR}/${new_base_filename}.json" || echo "  ❌ Error moving JSON"
        fi
        
        # Move NII if exists
        if [ -f "$nii_file" ]; then
          mv "$nii_file" "${FMAP_DIR}/${new_base_filename}.nii.gz" || echo "  ❌ Error moving NII"
        fi
        
        echo "  ✅ Renamed $base_filename: APP → AP"
      fi
    done 
  fi
 # Fix PhaseEncodingDirection for AP JSONs
    for JSON in "$FMAP_DIR"/*AP*.json; do
      [ -f "$JSON" ] || continue
      PHASE=$(jq -r '.PhaseEncodingDirection // empty' "$JSON")
      if [ "$PHASE" = "j" ]; then
        echo "  🔧 Fixing $JSON (j → j-)"
        jq '.PhaseEncodingDirection = "j-"' "$JSON" > "${JSON}.tmp" && mv "${JSON}.tmp" "$JSON"
      else
        echo "  ✅ OK: $(basename "$JSON") (PhaseEncodingDirection=$PHASE)"
      fi
    done
  ## === DWI FOLDER ===
  DWI_DIR="$BIDS_DIR/$SUBJ_ID/$SESSION/dwi"

  if [ ! -d "$DWI_DIR" ]; then
    echo "⚠️  Skipping dwi — folder not found."
  else
    echo "📁 Processing dwi folder..."
    
  

    # Rename APA to PA in filenames
    for JSON in "$DWI_DIR"/*APA*.json; do
      [ -f "$JSON" ] || continue
      base_filename=$(basename "$JSON" .json)
      nii_file="${DWI_DIR}/${base_filename}.nii.gz"
      bval_file="${DWI_DIR}/${base_filename}.bval"
      bvec_file="${DWI_DIR}/${base_filename}.bvec"
      
      if [[ "$base_filename" == *"dir-APA"* ]]; then
        new_base_filename=$(echo "$base_filename" | sed 's/dir-APA/dir-PA/')
        
        # Move files with existence checks
        [ -f "$JSON" ] && mv "$JSON" "${DWI_DIR}/${new_base_filename}.json"
        [ -f "$nii_file" ] && mv "$nii_file" "${DWI_DIR}/${new_base_filename}.nii.gz"
        [ -f "$bval_file" ] && mv "$bval_file" "${DWI_DIR}/${new_base_filename}.bval"
        [ -f "$bvec_file" ] && mv "$bvec_file" "${DWI_DIR}/${new_base_filename}.bvec"
        
        echo "  ✅ Renamed $base_filename: APA → PA"
      fi
    done 

    # Rename APP to AP in filenames
    for JSON in "$DWI_DIR"/*APP*.json; do
      [ -f "$JSON" ] || continue
      base_filename=$(basename "$JSON" .json)
      nii_file="${DWI_DIR}/${base_filename}.nii.gz"
      bval_file="${DWI_DIR}/${base_filename}.bval"
      bvec_file="${DWI_DIR}/${base_filename}.bvec"
      
      if [[ "$base_filename" == *"dir-APP"* ]]; then
        new_base_filename=$(echo "$base_filename" | sed 's/dir-APP/dir-AP/')
        
        # Move files with existence checks
        [ -f "$JSON" ] && mv "$JSON" "${DWI_DIR}/${new_base_filename}.json"
        [ -f "$nii_file" ] && mv "$nii_file" "${DWI_DIR}/${new_base_filename}.nii.gz"
        [ -f "$bval_file" ] && mv "$bval_file" "${DWI_DIR}/${new_base_filename}.bval"
        [ -f "$bvec_file" ] && mv "$bvec_file" "${DWI_DIR}/${new_base_filename}.bvec"
        
        echo "  ✅ Renamed $base_filename: APP → AP"
      fi
    done 
  fi
    # Fix PhaseEncodingDirection for APP JSONs
    for JSON in "$DWI_DIR"/*AP*.json; do
      [ -f "$JSON" ] || continue
      PHASE=$(jq -r '.PhaseEncodingDirection // empty' "$JSON")
      if [ "$PHASE" = "j" ]; then
        echo "  🔧 Fixing $JSON (j → j-)"
        jq '.PhaseEncodingDirection = "j-"' "$JSON" > "${JSON}.tmp" && mv "${JSON}.tmp" "$JSON"
      else
        echo "  ✅ OK: $(basename "$JSON") (PhaseEncodingDirection=$PHASE)"
      fi
    done
  echo ""
done

echo "✅ Done processing all subjects in $SESSION."