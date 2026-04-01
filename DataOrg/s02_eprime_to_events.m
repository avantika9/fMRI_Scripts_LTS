%Convert E-prime output to BIDS events.tsv for LTS project (block design)
% AM - Senior Research Analyst, BDL lab
%--------------------------------------------------------------------------
% Set variables
clc
clear all
% Dors path to behavioral data for LTS project
root = '/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/Behavioral/';
% BIDS folder path for LTS project
bids_folder = '/panfs/accrepfs.vampire/data/booth_lab/LTS_Data/BIDS_raw/';

%% Change the following
% Subject specific merged csv file
eprime_file = 'sub-7064_ses-1_D1_merge.csv';% CHECK DAY 1 OR DAY 2
subject = 'sub-7064';

runs = {'task-PhonPicts_run-01','task-PhonPicts_run-02','task-SemPicts_run-01'};
series_eprime = {'0004', '0005', '0008'};

%runs = {'task-PhonPicts_run-01','task-PhonPicts_run-02','task-SemPicts_run-01','task-SemPicts_run-02'};
%series_eprime = {'0007', '0008', '0003', '0007', '0008', '0004'};

day = 'D1'; % D1 for 1st scan day, if repeated D2
ses = 'ses-1';

%% Do Not Change Below
% Change the series number to match functional data pattern - e.g. 0009 is
% changed to 0901

output = cellfun(@(x)x(end-1:end), series_eprime, 'UniformOutput', false);
series= cellfun(@(x) strcat(num2str(x), '01'), output, 'UniformOutput', false);
disp(series);

% Main function
for r = 1:length(runs)
    % Specify data names
    eprime_merge = fullfile(root, subject, eprime_file);
    bidspath = bids_folder;
    
    % Read in the data
    fprintf('Reading in E-prime data from %s\n', eprime_merge);
    %eprime_data = readtable(eprime_merge, 'Delimiter', '\t');
    eprime_data = readtable(eprime_merge);
    % Read in stimuli data
    stimuli_file = fullfile(root, 'Stimuli_block.csv');
    stimuli_data = readtable(stimuli_file);%, 'Delimiter', ',');
    
    % Filter E-prime data for current run
     % Select Run
    thisrun_eprime = eprime_data(string(eprime_data.ExperimentName) == runs{r} & contains(string(eprime_data.Series), num2str(series_eprime{r})), :);
    
    % Filter stimuli data for current run
    thisrun_stimuli = stimuli_data(string(stimuli_data.ExperimentName) == runs{r}, :);
    
    % Calculate Onsets and duration
    % Calculate wait for scanner duration and offset if it does not exist
    if ~isfield(thisrun_eprime, 'WaitforScanner_Duration')
    thisrun_eprime.WaitforScanner_Duration = repmat(thisrun_eprime.TaskStart1SecFix_OnsetTime(1,1) - thisrun_eprime.WaitforScanner_OnsetTime(1,1), 40, 1);
    end
    
    if ~isfield(thisrun_eprime, 'WaitforScanner_OffsetTime')
     thisrun_eprime.WaitforScanner_OffsetTime = repmat(thisrun_eprime.WaitforScanner_OnsetTime(1,1) + thisrun_eprime.WaitforScanner_Duration(1,1), 40, 1);
    end
    
    % Onsets of trial
    if isnan(thisrun_eprime.WaitforScanner_OnsetTime(1,1))
        for n = 1:numel(thisrun_eprime.Word1_OnsetTime)
        thisrun_eprime.Trial_Onsets(n,1) = thisrun_eprime.Word1_OnsetTime(n,1) - thisrun_eprime.TaskStart1SecFix_OnsetTime(1,1);
        end
    else
       thisrun_eprime.Trial_Onsets = thisrun_eprime.Word1_OnsetTime - thisrun_eprime.WaitforScanner_OffsetTime; 
    end 
    
    % Duration of Trials
    %% Block1
    % For the first 9 trials its [Onset of trial2 - Onset of trail 1]
    for n = 1:9
    thisrun_eprime.Trial_Duration(n,1) = thisrun_eprime.Trial_Onsets(n+1,1) - thisrun_eprime.Trial_Onsets(n,1);
    end
    % For the 10th trial it is [Get Ready Onset for Block 2 - Word1OnsetTime for the 10th trial]
    if ~isfield(thisrun_eprime, 'thisrun_eprime.GetReady_OnsetTime')
        thisrun_eprime.GetReady_OnsetTime(11,1) = thisrun_eprime.TaskStart1SecFix_OnsetTime(11,1) - 4000 ;
    end    
    thisrun_eprime.Trial_Duration(10,1)= thisrun_eprime.GetReady_OnsetTime(11,1) - thisrun_eprime.Word1_OnsetTime(10,1);
    
    %% Block 2
    for n = 11:19
    thisrun_eprime.Trial_Duration(n,1) = thisrun_eprime.Trial_Onsets(n+1,1) - thisrun_eprime.Trial_Onsets(n,1);
    end
    % For the 20th trial it is [Get Ready Onset for Block 3 - Word1OnsetTime for the 20th trial]
    if ~isfield(thisrun_eprime, 'thisrun_eprime.GetReady_OnsetTime')
        thisrun_eprime.GetReady_OnsetTime(21,1) = thisrun_eprime.TaskStart1SecFix_OnsetTime(21,1) - 4000 ;
    end    
    thisrun_eprime.Trial_Duration(20,1)= thisrun_eprime.GetReady_OnsetTime(21,1) - thisrun_eprime.Word1_OnsetTime(20,1);
    
    %% Block 3
    for n = 21:29
    thisrun_eprime.Trial_Duration(n,1) = thisrun_eprime.Trial_Onsets(n+1,1) - thisrun_eprime.Trial_Onsets(n,1);
    end
    % For the 30th trial it is [Get Ready Onset for Block 4 - Word1OnsetTime for the 30th trial]
    if ~isfield(thisrun_eprime, 'thisrun_eprime.GetReady_OnsetTime')
        thisrun_eprime.GetReady_OnsetTime(31,1) = thisrun_eprime.TaskStart1SecFix_OnsetTime(31,1) - 4000 ;
    end    
    thisrun_eprime.Trial_Duration(30,1)= thisrun_eprime.GetReady_OnsetTime(31,1) - thisrun_eprime.Word1_OnsetTime(30,1);
    
    %% Block 4
    % For the first 9 trials its [Onset of trial2 - Onset of trail 1]
    for n = 31:39
    thisrun_eprime.Trial_Duration(n,1) = thisrun_eprime.Trial_Onsets(n+1,1) - thisrun_eprime.Trial_Onsets(n,1);
    end
    % For the 40th trial it is [Get End Display Onset Time - Word1OnsetTime for the 40th trial]
    thisrun_eprime.Trial_Duration(40,1)= thisrun_eprime.EndDisplay_OnsetTime(1,1) - thisrun_eprime.Word1_OnsetTime(40,1); 
    
    %% Save events.tsv file
    hasMatch = {'ExperimentName', 'Trial','Block', 'CondName', 'Word1_stim','Word2_stim','Trial_Onsets','Trial_Duration', 'Word2_CRESP','Word2_RESP','Word2_ACC','Word2_RT'} ;
    thisrun_eprime(:, thisrun_eprime.Properties.VariableNames(hasMatch))
    parts = strsplit(runs{r}, '_');% split string
    task = parts{1};
    run = parts{2};
    % Create a text file                                       sub-6009_ses-1_task-PhonPicts_acq-D1S0901_run-01_bold.json
    %filename = fullfile(bids_folder, subject, ses, 'func', sprintf(sprintf('%s_%s_%s_acq-%sS%s_%s_events.txt', subject,ses,task,day,series{r},run)));
    filename_tsv = fullfile(bids_folder, subject, ses, 'func', sprintf(sprintf('%s_%s_%s_acq-%sS%s_%s_events.tsv', subject,ses,task,day,series{r},run)));
    
    %fileID = fopen(filename, 'w');
    %writetable(thisrun_eprime(:, thisrun_eprime.Properties.VariableNames(hasMatch)), filename,'Delimiter','tab');
    
    fileID_tsv = fopen(filename_tsv, 'w');
    writetable(thisrun_eprime(:, thisrun_eprime.Properties.VariableNames(hasMatch)), filename_tsv,'Delimiter','\t','FileType','text');
    
    fclose(fileID_tsv);
    
end