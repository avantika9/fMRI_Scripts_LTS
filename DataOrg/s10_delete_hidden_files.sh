#!/bin/bash

# Set directory path for cleaning
PATH="/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/BIDS_raw"

# Preview hidden files that will be deleted
find $PATH -name "._.*" -type f

# Delete hidden files
#find $PATH -name "._.*" -type f -delete