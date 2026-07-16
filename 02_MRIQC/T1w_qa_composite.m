%%This code will be used to read in the output txt file from of the mriqc
% after running singularity mriqc-py3.simg mriqc <input> <output> group
% Then decide which T1 is the better one

filepath='/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/preproc_fMRIprep/derivatives_mriqc/mriqc';
output_name='t1w_qa_ses-1.txt';
session='ses-1';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%do not modidy below this line %%%%%%%%%%
cd(filepath);
fid=fopen(output_name,'w');
hdr='participant_id run_name quality_score';
fprintf(fid,'%s \n', hdr);
qc_data=tdfread('group_T1w.tsv');
qc_data.zefc=zscore(qc_data.efc);
qc_data.zcjv=zscore(qc_data.cjv);
qc_data.zsnr=zscore(qc_data.snr_total);
qc_data.zcnr=zscore(qc_data.cnr);
qc_data.quality=qc_data.zsnr+qc_data.zcnr-(qc_data.zcjv + qc_data.zefc);
names=qc_data.bids_name;
quality=qc_data.quality;
for j=1:length(names)
    if contains(names(j,:),session)
    sub=names(j,5:8);
    run_name=names(j,:);
    value=quality(j);
    fprintf(fid,'%s %s %d\n',sub,run_name, value);
    end
end







