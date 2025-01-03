addpath(genpath('C:\Users\Steinmetz lab\Documents\git\Kilosort2_J')) % path to kilosort folder
addpath('C:\Users\Steinmetz lab\Documents\git\npy-matlab') % for converting to Phy
% rootZ = 'E:\spikeInterface\'; % the raw data binary file is in this folder
rootZ = 'E:\spikeInterface';
pathToYourConfigFile = 'C:\Users\Steinmetz lab\Documents\git\Kilosort2_J\configFiles'; % take from Github folder and put it somewhere else (together with the master_file)
pathToYourChanMapFile = 'C:\Users\Steinmetz lab\Documents\git\Kilosort2_J\configFiles';
% chanMapFile = 'UHDtype3.mat';
% chanMapFile = 'NPUHD2_bank0_ref0.mat';
% chanMapFile = 'NPUHD2_inner_vstripe_ref0.mat';
chanMapFile = 'neuropixelUltra_kilosortChanMap_kilosortChanMap.mat';
% ops.trange = [0 2000]; % time range to sort
ops.trange = [0 Inf]; % time range to sort
% ops.trange = [manip_t(i,1) manip_t(i,2)];
ops.NchanTOT    = 384; % total number of channels in your recording

run(fullfile(pathToYourConfigFile, 'configFile384.m'))
ops.fproc       = fullfile(rootZ, 'temp_wh.dat'); % proc file on a fast SSD
ops.chanMap = fullfile(pathToYourChanMapFile, chanMapFile);
%% this block runs all the steps of the algorithm
fprintf('Looking for data inside %s \n', rootZ)

% % is there a channel map file in this folder?
% fs = dir(fullfile(rootZ, 'chan*.mat'));
% if ~isempty(fs)
%     ops.chanMap = fullfile(rootZ, fs(1).name);
% end

% find the binary file
fs          = [dir(fullfile(rootZ, '*ap.bin')) dir(fullfile(rootZ, '*ap.dat'))];
ops.fbinary = fullfile(rootZ, fs(1).name);

% preprocess data to create temp_wh.dat
rez = preprocessDataSub(ops);
%
% time-reordering as a function of drift
rez = clusterSingleBatches(rez);

% saving here is a good idea, because the rest can be resumed after loading rez
save(fullfile(rootZ, 'rez.mat'), 'rez', '-v7.3');

% main tracking and template matching algorithm
rez = learnAndSolve8b(rez);

% final merges
rez = find_merges(rez, 1);

% final splits by SVD
rez = splitAllClusters(rez, 1);

% final splits by amplitudes
rez = splitAllClusters(rez, 0);

% decide on cutoff
rez = set_cutoff(rez);

fprintf('found %d good units \n', sum(rez.good>0))

% write to Phy
fprintf('Saving results to Phy  \n')
rezToPhy(rez, rootZ);

% if you want to save the results to a Matlab file...

% discard features in final rez file (too slow to save)
rez.cProj = [];
rez.cProjPC = [];

% final time sorting of spikes, for apps that use st3 directly
[~, isort]   = sortrows(rez.st3);
rez.st3      = rez.st3(isort, :);

% save final results as rez2
fprintf('Saving final results in rez2  \n')
fname = fullfile(rootZ, 'rez2.mat');
save(fname, 'rez', '-v7.3');