
function rez = datashift_external(rez, do_correction, externalDriftValues, ysamp)

% externalDriftValues is a vector with one entry per second of recording
% time containing the estimated drift at that timepoint, determined by some
% other algorithm 

% ysamp is what datashift2 calls "yblk" - you need to supply it

% >>> some initialization code copied from datashift2

if  getOr(rez.ops, 'nblocks', 1)==0
    rez.iorig = 1:rez.temp.Nbatch;
    return;
end

ops = rez.ops;

% The min and max of the y and x ranges of the channels
ymin = min(rez.yc);
ymax = max(rez.yc);
xmin = min(rez.xc);
xmax = max(rez.xc);

% Determine the average vertical spacing between channels. 
% Usually all the vertical spacings are the same, i.e. on Neuropixels probes. 
dmin = median(diff(unique(rez.yc)));
fprintf('pitch is %d um\n', dmin)
rez.ops.yup = ymin:dmin/2:ymax; % centers of the upsampled y positions

% Determine the template spacings along the x dimension
xrange = xmax - xmin;
npt = floor(xrange/16); % this would come out as 16um for Neuropixels probes, which aligns with the geometry. 
rez.ops.xup = linspace(xmin, xmax, npt+1); % centers of the upsampled x positions

spkTh = 8; % same as the usual "template amplitude", but for the generic templates

% --- end initialization code

% >>> now shift the data with our external values

% first determine the value of the shift in each block

 % assuming that blocks are evenly spaced and that the externally supplied
 % drift values cover the whole recording, we can get the time points of
 % each block like this: 
Nbatches      = rez.temp.Nbatch;
blockTimes = (1:Nbatches)/Nbatches*numel(externalDriftValues);

 % then interpolate the externally supplied values to those timepoints. 
dshift = interp1(1:numel(externalDriftValues), externalDriftValues, blockTimes); 

if do_correction
    % sigma for the Gaussian process smoothing
    sig = rez.ops.sig;
    % register the data batch by batch
    dprev = gpuArray.zeros(ops.ntbuff,ops.Nchan, 'single');
    for ibatch = 1:Nbatches
        dprev = shift_batch_on_disk2(rez, ibatch, dshift(ibatch, :), ysamp, sig, dprev);
    end
    fprintf('time %2.2f, Shifted up/down %d batches. \n', toc, Nbatches)
else
    fprintf('time %2.2f, Skipped shifting %d batches. \n', toc, Nbatches)
end

% ---

% >>> checking the result with a plot

% first detect spikes: 
[st3, rez] = standalone_detector(rez, spkTh);

figure;
subplot(2,1,1);
set(gcf, 'Color', 'w')

% plot the shift trace in um
plot(externalDriftValues)
xlabel('time (s)')
ylabel('drift (um)')
title('Estimated drift traces')
drawnow

subplot(2,1,2);
set(gcf, 'Color', 'w')
% raster plot of all spikes at their original depths
st_shift = st3(:,2); %+ imin(batch_id)' * dd;
for j = spkTh:100
    % for each amplitude bin, plot all the spikes of that size in the
    % same shade of gray
    ix = st3(:, 3)==j; % the amplitudes are rounded to integers
    plot(st3(ix, 1)/ops.fs, st_shift(ix), '.', 'color', [1 1 1] * max(0, 1-j/40)) % the marker color here has been carefully tuned
    hold on
end
axis tight

xlabel('time (sec)')
ylabel('spike position (um)')
title('Drift map')



% ---