#!/bin/bash
################################################################################
# Script Name: fix_json_acquisition_date.sh
# Description: Fixes typo "AcqusitionDate" and removes duplicates
################################################################################

# ===== CONFIGURATION =====
BIDS_DIR="/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/BIDS_raw"
IDFILE="idfile_ses2.txt"
SESSION="ses-2"  # Change to "ses-2" as needed
SUBDIRS=("anat" "dwi" "fmap" "func")
# =========================

# Initialize counters
TOTAL_PROCESSED=0
TOTAL_SKIPPED=0
TOTAL_FIXED=0
TOTAL_ALREADY_VALID=0
TOTAL_TYPO_FIXED=0

while read -r SUBJ_ID; do
  [[ "$SUBJ_ID" != sub-* ]] && SUBJ_ID="sub-$SUBJ_ID"
  
  echo "===================="
  echo "? Processing $SUBJ_ID ($SESSION)"
  echo "===================="

  for SUBDIR in "${SUBDIRS[@]}"; do
    DIR="${BIDS_DIR}/${SUBJ_ID}/${SESSION}/${SUBDIR}"
    
    if [ ! -d "$DIR" ]; then
      echo "  ⚠️  Skipping ${SUBDIR}/ — directory not found"
      continue
    fi

    echo "  ? Checking ${SUBDIR}/ folder..."

    for JSON in "$DIR"/*.json; do
      [ -e "$JSON" ] || continue
      
      BASENAME=$(basename "$JSON")
      NEEDS_FIXING=false
      
      # STEP 1: Check for typo - sanitize output
      TYPO_COUNT=$(grep -c '"AcqusitionDate"' "$JSON" 2>/dev/null || echo "0")
      TYPO_COUNT=$(echo "$TYPO_COUNT" | tr -d '[:space:]')  # Remove whitespace
      TYPO_COUNT=${TYPO_COUNT:-0}  # Default to 0 if empty
      
      # STEP 2: Check for correct spelling - sanitize output
      CORRECT_COUNT=$(grep -c '"AcquisitionDate"' "$JSON" 2>/dev/null || echo "0")
      CORRECT_COUNT=$(echo "$CORRECT_COUNT" | tr -d '[:space:]')
      CORRECT_COUNT=${CORRECT_COUNT:-0}
      
      # STEP 3: Calculate total safely
      TOTAL_ACQUISITION_COUNT=0
      if [[ "$TYPO_COUNT" =~ ^[0-9]+$ ]] && [[ "$CORRECT_COUNT" =~ ^[0-9]+$ ]]; then
        TOTAL_ACQUISITION_COUNT=$((TYPO_COUNT + CORRECT_COUNT))
      else
        echo "    ⚠️  WARNING: Could not count entries in $BASENAME"
        continue
      fi
      
      # Determine if file needs fixing
      if [ "$TYPO_COUNT" -gt 0 ]; then
        echo "    ? TYPO FOUND: $BASENAME (found $TYPO_COUNT 'AcqusitionDate' entries)"
        NEEDS_FIXING=true
      fi
      
      if [ "$TOTAL_ACQUISITION_COUNT" -gt 1 ]; then
        echo "    ? DUPLICATES FOUND: $BASENAME (total $TOTAL_ACQUISITION_COUNT entries)"
        NEEDS_FIXING=true
      fi
      
      # If jq available, also check JSON validity
      if command -v jq &> /dev/null; then
        if ! jq empty "$JSON" 2>/dev/null; then
          echo "    ⚠️  INVALID JSON: $BASENAME"
          NEEDS_FIXING=true
        fi
      fi
      
      # Skip if no issues found
      if [ "$NEEDS_FIXING" = false ]; then
        echo "    ✅ SKIP: $BASENAME (already valid & correct)"
        ((TOTAL_SKIPPED++))
        ((TOTAL_ALREADY_VALID++))
        continue
      fi

      # STEP 4: Create backup (optional)
      # cp "$JSON" "$JSON.backup_$(date +%Y%m%d_%H%M%S)"

      # STEP 5: Process the JSON file
      awk '
        BEGIN { seen = 0; prev = "" }
        
        # Match both typo and correct spelling
        /"AcqusitionDate"|"AcquisitionDate"/ {
          # Fix the typo if present
          gsub(/"AcqusitionDate"/, "\"AcquisitionDate\"")
          
          # Handle duplicates
          if (seen == 1) next        # Skip duplicate occurrences
          seen = 1
          
          # Fix previous line: add comma if missing
          if (prev !~ /,$/) prev = prev ","
          print prev
          print $0
          prev = ""
          next
        }
        {
          if (prev != "") print prev
          prev = $0
        }
        END { if (prev != "") print prev }
      ' "$JSON" > "$JSON.fixed"

      # STEP 6: Validate and replace
      if command -v jq &> /dev/null; then
        if jq empty "$JSON.fixed" 2>/dev/null; then
          mv "$JSON.fixed" "$JSON"
          
          # Report what was fixed
          if [ "$TYPO_COUNT" -gt 0 ]; then
            echo "    ✅ FIXED TYPO: AcqusitionDate → AcquisitionDate ($TYPO_COUNT instances)"
            ((TOTAL_TYPO_FIXED++))
          fi
          if [ "$TOTAL_ACQUISITION_COUNT" -gt 1 ]; then
            echo "    ✅ REMOVED DUPLICATES: $TOTAL_ACQUISITION_COUNT → 1"
          fi
          echo "    ✅ VALIDATED: $BASENAME"
          ((TOTAL_FIXED++))
        else
          echo "    ❌ ERROR: Fixed file is invalid JSON for $BASENAME"
          echo "       Original file preserved, manual inspection needed"
          rm "$JSON.fixed"
        fi
      else
        mv "$JSON.fixed" "$JSON"
        if [ "$TYPO_COUNT" -gt 0 ]; then
          echo "    ✅ FIXED TYPO: AcqusitionDate → AcquisitionDate ($TYPO_COUNT instances)"
          ((TOTAL_TYPO_FIXED++))
        fi
        if [ "$TOTAL_ACQUISITION_COUNT" -gt 1 ]; then
          echo "    ✅ REMOVED DUPLICATES: $TOTAL_ACQUISITION_COUNT → 1"
        fi
        echo "    ✅ FIXED: $BASENAME (⚠️ not validated - install jq for validation)"
        ((TOTAL_FIXED++))
      fi

      ((TOTAL_PROCESSED++))
    done
  done
  
  echo ""

done < "$IDFILE"

# Summary
echo "════════════════════════════════"
echo "✅ Processing Complete for $SESSION"
echo "════════════════════════════════"
echo "Files already valid:     $TOTAL_ALREADY_VALID"
echo "Files with typos fixed:  $TOTAL_TYPO_FIXED"
echo "Files fixed (total):     $TOTAL_FIXED"
echo "Files skipped:           $TOTAL_SKIPPED"
echo "Files processed:         $TOTAL_PROCESSED"
echo ""
echo "Total files checked: $((TOTAL_ALREADY_VALID + TOTAL_FIXED + TOTAL_SKIPPED))"