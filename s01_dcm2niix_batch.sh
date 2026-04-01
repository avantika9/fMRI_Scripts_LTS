#!/bin/bash

# @Author: AM -Senior Research Analyst - BDL lab, May 2024
# @Date:   2024-05-14

## This script makes bids structure. How To Use:
# move dicoms to the path described below as $dcmfold
# edit the first block below for the day's scan
# unpacks with dcm2niix - version number loaded+hardcoded


## Change these
LabID=sub-7071    # LabID sub-6187
ses=1                        # Timepoint
day=1                    # Scanning day 1/2
date='03-30-26'    # Date of scanning, also in eprime output ##mm-dd-yyyy
#loadmodules="y"        # y/n only load modules once, takes time
ml dcm2niix/1.0.20230411
############################################################################################
## Stays the same
#if [ "$load" = "y" ]; then                                            # if y above, load them
#    module load GCCcore/.8.2.0
#    module load dcm2niix/1.0.20190902             # if change, also change below
#fi

root=/panfs/accrepfs.vampire/data/booth_lab/LTS_Data                # root, then dicom folder
dcmfold=dicoms_downloads/${LabID}_dicoms/${LabID}_ses-${ses}_acq-D${day}_dicoms
#behfold=dicoms_downloads/${LabID}_dicoms/${LabID}_beh/ # bids events files
bidfold=${root}/BIDS_raw/${LabID}/ses-${ses}    # bids folder
## Make directories
mkdir -p ${root}/BIDS_raw/${LabID}
chmod 770 ${root}/BIDS_raw/${LabID}
## Make directories
for fold in anat fmap func dti; do                         # make subfolders
    mkdir -p ${bidfold}/${fold}
    chmod 770 ${bidfold}/${fold}
done
# Set permissions on parent session folder
chmod 770 ${bidfold}

## Move behavioral events files
#if [ ! -d "$behfold" ]; then
#    echo "No beh folder found, put events.tsvs func folder"
#else
#    mv ${behfold}/* ${bidfold}/func/
#fi

## Check that the input folder exists, if so unpack dicoms
if [ ! -d "$root/$dcmfold" ]; then                            # if dir not exist
    echo "Move new files to:\n${dcmfold}"        # says 'put here'
    exit 1                                                                     # stops script
else                                                                             # else, runs the rest
    cd $root/$dcmfold
   dcm2niix -b y -ba y -f %n_task-%p_%s * # Unpack dicoms
fi

## Add date to jsons
alljsons=$(find $root/$dcmfold/ -name '*json')
for json in $alljsons; do
      sed -i 's/"v1.0.20190902"/"v1.0.20190902",/' $json
      sed -i "s/}/\t"\"AcqusitionDate\":\"${date}\""\n}/" $json
      taskrun=$(sed 's/.*EPI_\(.*\)_.*/\1/' <<< "$json")
      echo "json date ${taskrun}" >> dcmLog_${LabID}_ses-${ses}_acq-D${day}.txt
done


# Anatomical data
anatfiles=$(find $root/$dcmfold/ -name '*AnatBrain*T1W3D_CS4_[[:digit:]]*.nii')
if [[ ! -z $anatfiles ]]; then
  for anat in $anatfiles; do
    #anatseries=$(echo $anat | tail -c8 | cut -c1-3)
    series=${anat##*_}; anatseries=$(printf %04d ${series%%.*})
    echo $anatseries
    mv $anat  ${bidfold}/anat/"${LabID}_ses-${ses}_acq-D${day}S${anatseries}_T1w.nii"
    gzip  ${bidfold}/anat/"${LabID}_ses-${ses}_acq-D${day}S${anatseries}_T1w.nii"
    anatjson=${anat::-4}.json
    mv $anatjson  ${bidfold}/anat/"${LabID}_ses-${ses}_acq-D${day}S${anatseries}_T1w.json"
    echo "Anatomical ${LabID}_ses-${ses}_acq-D${day}S${series}" >> dcmLog_${LabID}_ses-${ses}_acq-D${day}.txt
  done
fi

# Functional data
# sem1-fs1
funcfiles_s1=$(find $root/$dcmfold/ -name '*S1*.nii')
echo $funcfiles
if [[ ! -z $funcfiles_s1 ]]; then
  for func in $funcfiles_s1; do
    #fs1series=$(echo $func | tail -c8 | cut -c1-3)
    fs1series=${func##*_}; fs1series=$(printf %04d ${fs1series%%.*})
    echo $fs1series
    mv $func ${bidfold}/func/"${LabID}_ses-${ses}_task-SemPicts_acq-D${day}S${fs1series}_run-01_bold.nii"
    gzip ${bidfold}/func/"${LabID}_ses-${ses}_task-SemPicts_acq-D${day}S${fs1series}_run-01_bold.nii"
    fs1json=${func::-4}.json
    mv $fs1json ${bidfold}/func/"${LabID}_ses-${ses}_task-SemPicts_acq-D${day}S${fs1series}_run-01_bold.json"
    echo "Functional S1 ${LabID}_ses-${ses}_acq-D${day}S${fs1series}" >> dcmLog_${LabID}_ses-${ses}_acq-D${day}.txt
  done
fi

# sem2-fs2
funcfiles_s2=$(find $root/$dcmfold/ -name '*S2*.nii')
if [[ ! -z $funcfiles_s2 ]]; then
  for func in $funcfiles_s2; do
   # fs2series=$(echo $func | tail -c8 | cut -c1-3)
    fs2series=${func##*_}; fs2series=$(printf %04d ${fs2series%%.*})
    mv $func ${bidfold}/func/"${LabID}_ses-${ses}_task-SemPicts_acq-D${day}S${fs2series}_run-02_bold.nii"
    gzip ${bidfold}/func/"${LabID}_ses-${ses}_task-SemPicts_acq-D${day}S${fs2series}_run-02_bold.nii"
    fs2json=${func::-4}.json
    mv $fs2json ${bidfold}/func/"${LabID}_ses-${ses}_task-SemPicts_acq-D${day}S${fs2series}_run-02_bold.json"
    echo "Functional S2 ${LabID}_ses-${ses}_acq-D${day}S${fs2series}" >> dcmLog_${LabID}_ses-${ses}_acq-D${day}.txt
  done
fi

# phon-fp1
funcfiles_p1=$(find $root/$dcmfold/ -name '*P1*.nii')
if [[ ! -z $funcfiles_p1 ]]; then
  for func in $funcfiles_p1; do
    #fp1series=$(echo $func | tail -c8 | cut -c1-3)
    fp1series=${func##*_}; fp1series=$(printf %04d ${fp1series%%.*})
    mv $func ${bidfold}/func/"${LabID}_ses-${ses}_task-PhonPicts_acq-D${day}S${fp1series}_run-01_bold.nii"
    gzip ${bidfold}/func/"${LabID}_ses-${ses}_task-PhonPicts_acq-D${day}S${fp1series}_run-01_bold.nii"
    fp1json=${func::-4}.json
    mv $fp1json ${bidfold}/func/"${LabID}_ses-${ses}_task-PhonPicts_acq-D${day}S${fp1series}_run-01_bold.json"
    echo "Functional P1 ${LabID}_ses-${ses}_acq-D${day}S${fp1series}" >> dcmLog_${LabID}_ses-${ses}_acq-D${day}.txt
  done
fi

# phon-fp2
funcfiles_p2=$(find $root/$dcmfold/ -name '*P2*.nii')
if [[ ! -z $funcfiles_p2 ]]; then
  for func in $funcfiles_p2; do
    #fp2series=$(echo $func | tail -c8 | cut -c1-3)
    fp2series=${func##*_}; fp2series=$(printf %04d ${fp2series%%.*})
    mv $func ${bidfold}/func/"${LabID}_ses-${ses}_task-PhonPicts_acq-D${day}S${fp2series}_run-02_bold.nii"
    gzip ${bidfold}/func/"${LabID}_ses-${ses}_task-PhonPicts_acq-D${day}S${fp2series}_run-02_bold.nii"
    fp2json=${func::-4}.json
    mv $fp2json ${bidfold}/func/"${LabID}_ses-${ses}_task-PhonPicts_acq-D${day}S${fp2series}_run-02_bold.json"
    echo "Functional P2 ${LabID}_ses-${ses}_acq-D${day}S${fp2series}" >> dcmLog_${LabID}_ses-${ses}_acq-D${day}.txt
  done
fi

# fmap data
# APP-topup
fmap_app=$(find $root/$dcmfold/ -name '*TOPUP*APP*.nii')
if [[ ! -z $fmap_app ]]; then
  for fmap in $fmap_app; do
    #app_series=$(echo $fmap | tail -c8 | cut -c1-3)
    #app_series=${fmap_app##*_}; app_series=$(printf %04d ${app_series%%.*})
    app_series=${fmap##*_}; app_series=$(printf %04d ${app_series%%.*}) # corrected 4thNov 2025
    mv $fmap ${bidfold}/fmap/"${LabID}_ses-${ses}_acq-D${day}S${app_series}_dir-APP_epi.nii"
    gzip ${bidfold}/fmap/"${LabID}_ses-${ses}_acq-D${day}S${app_series}_dir-APP_epi.nii"
    app_json=${fmap::-4}.json
    mv $app_json ${bidfold}/fmap/"${LabID}_ses-${ses}_acq-D${day}S${app_series}_dir-APP_epi.json"
  done
fi

# APA-topup
fmap_apa=$(find $root/$dcmfold/ -name '*TOPUP*APA*.nii')
if [[ ! -z $fmap_apa ]]; then
  for fmap in $fmap_apa; do
    #apa_series=$(echo $fmap | tail -c8 | cut -c1-3)
    #apa_series=${fmap_apa##*_}; apa_series=$(printf %04d ${apa_series%%.*})
    apa_series=${fmap##*_}; apa_series=$(printf %04d ${apa_series%%.*}) # corrected 4thNov 2025
    mv $fmap ${bidfold}/fmap/"${LabID}_ses-${ses}_acq-D${day}S${apa_series}_dir-APA_epi.nii"
    gzip ${bidfold}/fmap/"${LabID}_ses-${ses}_acq-D${day}S${apa_series}_dir-APA_epi.nii"
    apa_json=${fmap::-4}.json
    mv $apa_json ${bidfold}/fmap/"${LabID}_ses-${ses}_acq-D${day}S${apa_series}_dir-APA_epi.json"
  done
fi

# DTI data 96 dir # some participants acquired at 64 dir
dtifiles=$(find $root/$dcmfold/ -name '*DTI_2sh_96dir*.nii' ! -name '*.DCM')
if [[ ! -z $dtifiles ]]; then
  echo "Found DTI files:"
  echo "$dtifiles"
  
  for dtifile in $dtifiles; do
    series=${dtifile##*_}; series=$(printf %04d ${series%%.*}) # zero-pad
    outfile="${LabID}_ses-${ses}_acq-D${day}S${series}_dti96_dir-APP_epi"
    echo $outfile
    
    # Move and rename files
    dtifile=${dtifile%%.nii*}.nii
    mv $dtifile ${bidfold}/dti/"${outfile}.nii"
    echo $dtifile
    gzip ${bidfold}/dti/"${outfile}.nii"
    
    json=${dtifile%%.nii*}.json
    echo "$json"
    mv $json ${bidfold}/dti/"${outfile}.json"
    
    bval=${dtifile%%.nii*}.bval
    echo "$bval"
    mv $bval ${bidfold}/dti/"${outfile}.bval"
    
    bvec=${dtifile%%.nii*}.bvec
    echo "$bvec"
    mv $bvec ${bidfold}/dti/"${outfile}.bvec"
   
    echo "dti ${dtifile}" >> dcmLog_${LabID}_ses-${ses}_acq-D${day}.txt
  done
else
  echo "No 96 dir DTI files found in $root/$dcmfold/"
fi

# DTI data 6 dir
dtifiles=$(find $root/$dcmfold/ -name '*DTI_6dir*.nii' ! -name '*ADC*')
if [[ ! -z $dtifiles ]]; then
     echo "Found DTI files:"
     echo "$dtifiles"
 
  for dtifile in $dtifiles; do
    series=${dtifile##*_}; series=$(printf %04d ${series%%.*}) # zero-pad
    outfile="${LabID}_ses-${ses}_acq-D${day}S${series}_dti6_dir-APA_epi"
    echo $outfile
    
    # Move and rename files
    dtifile=${dtifile%%.nii*}.nii
    mv $dtifile ${bidfold}/dti/"${outfile}.nii"
    gzip ${bidfold}/dti/"${outfile}.nii"
    json=${dtifile%%.nii*}.json
    mv $json ${bidfold}/dti/"${outfile}.json"
    bval=${dtifile%%.nii*}.bval
    mv $bval ${bidfold}/dti/"${outfile}.bval"
    bvec=${dtifile%%.nii*}.bvec
    mv $bvec ${bidfold}/dti/"${outfile}.bvec"
    echo "dti ${dtifile}" >> dcmLog_${LabID}_ses-${ses}_acq-D${day}.txt
  done
fi

# DTI data 64 dir
dtifiles=$(find $root/$dcmfold/ -name '*DTI_opt64dir*.nii')
if [[ ! -z $dtifiles ]]; then
     echo "Found DTI files:"
     echo "$dtifiles"
 
  for dtifile in $dtifiles; do
    series=${dtifile##*_}; series=$(printf %04d ${series%%.*}) # zero-pad
    outfile="${LabID}_ses-${ses}_acq-D${day}S${series}_dti64_dir-APA_epi"
    echo $outfile
    
    # Move and rename files
    dtifile=${dtifile%%.nii*}.nii
    mv $dtifile ${bidfold}/dti/"${outfile}.nii"
    gzip ${bidfold}/dti/"${outfile}.nii"
    json=${dtifile%%.nii*}.json
    mv $json ${bidfold}/dti/"${outfile}.json"
    bval=${dtifile%%.nii*}.bval
    mv $bval ${bidfold}/dti/"${outfile}.bval"
    bvec=${dtifile%%.nii*}.bvec
    mv $bvec ${bidfold}/dti/"${outfile}.bvec"
    echo "dti ${dtifile}" >> dcmLog_${LabID}_ses-${ses}_acq-D${day}.txt
  done
fi

for fold in anat fmap func dti; do
    chmod -R 770 ${bidfold}/${fold}
done
