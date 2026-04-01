The Key to 1DataOrganization codes
# The code to convert data to BIDS (moves data from dicom_downloads to BIDS_raw)
1. dcm2niix_batch.sh
# The code creates events file for each .nii file
2. epmrime_to_events.m
# This script moves incomplete runs to a separate folder 
3. move_incomplete_runs.sh 
The following codes fix the data to BIDS format
4. bids_fix_funcfmapdti.sh
5. fix_json_acquisition_date.sh
6. fix_fmap_dwi_json_phase.sh
7. fix_IntendedFor_fmapjsons.sh
# Extra script that counts Volumes in incomplete run folder
8. Volumes_txt.sh 
# Script to clean up dicom downloads folder
9. cleanup_dicom_folders.sh
# Scriptto clean up hidden files
10 delete_hidden_files.sh
