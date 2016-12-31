function [absorptions, photocurrents, LMSfilters, meanCur] = computeForOISequence(obj, oiSequence, varargin)
% [absorptions, photocurrents, LMSfilters] = computeForOISequence(obj, oiSequence, varargin)
%
% Compute cone absorptions and optionally photocurrents for a @oiSequence
%
% Inputs:
%   obj         - @coneMosaic object
%   oiSequence  - @oiSequence object
%
% Optional key/value pairs:
%   'seed' - value (default 1). Value of random noise seed.
%   'emPaths' - [N x M x 2] matrix of N eye movement paths, each with Mx2 eye positions (default empty)
%   'interpFilters - [WHAT AM I?]
%   'meanCur' = [WHAT AM I?]
%   'currentFlag' - true/false (default false). Whether to compute photocurrent
%   'theExpandedMosaic' - (default empty).  We need an expanded version of the coneMosaic to deal with eye
%            movements. For multiple calls to computeForOISequence, we may want to generate it once and pass it.
%            If it is empty (default), the expanded version is generated here.
%   'workerID' - (default empty).  If this field is non-empty, the progress of
%            the computation is printed in the command window along with the
%            workerID (from a parfor loop).
%   'workDescription' - (default empty).  A string describing the condition
%            computed. Used only when workerID is non-empty.
%
% Outputs:
%   absorptions          - cone photon absorptions (photon counts in integrationTime)
%   photocurrent         - cone photocurrent
%
% There are several ways to use this function.  The simplest is to send in
% a single oiSequence and a single eye movement sequence.
%
%   coneMosaic.compute(oiSequence)
%
% It is also possible to run this for a multiple eye movement paths. In
% that case, the coneMosaic object contains only the last trial.  The full
% set of data for all the trial are contained in the returned outputs,
% absorptions and photocurrent.
%
%   [absorptions, photocurrents] = cMosaic.computeForOISequence(oiSequence);
%
% We control the photon noise by cmosaic.noiseFlag, and the photocurrent
% noise by cmosaic.os.noiseFlag.  These have the options 
%    'random','frozen','none'
% When 'frozen', you can send in a 'seed'.  May not be fully implemented yet.
%
% Examples:
%  This is an example of how to do this for 1,000 eye movement paths
%  (trials), each consisting of 100 eye movements.
%
%   nTrials = 1000; nEyeMovements = 100; 
%   emPaths = zeros(instancesBlockSize, nEyeMovements, 2);
%   for iTrial = 1:nTrials
%    theEMPaths(iTrial , :,:) = cMosaic.emGenSequence(nEyeMovements);
%   end
%   [absorptions, photocurrents] = cMosaic.computeForOISequence(...
%       theOIsequence, ...
%       'emPaths', theEMPaths, ...
%       'currentFlag', true);
%                    
% The returned absorptions has an extra dimension (the first one) so that
% we can calculate for multiple eye movement paths.  The absorptions from a
% single eye movement case would be
%
%    absorptions(thisTrial,:,:,:)
%
% The coneMosaic object (obj) has the absorptions from the last trial and
% dimensions (row,col,time).
%
% See also: coneMosaic.compute, v_cmosaic, 

% NPC ISETBIO Team 2016

%% Parse inputs
p = inputParser;
p.addRequired('oiSequence', @(x)isa(x, 'oiSequence'));
p.addParameter('seed',1, @isnumeric);             
p.addParameter('emPaths', [], @isnumeric);  
p.addParameter('trialBlocks', 8, @isnumeric);
p.addParameter('interpFilters',[],@isnumeric);    
p.addParameter('meanCur',[],@isnumeric);          
p.addParameter('currentFlag', false, @islogical); 
p.addParameter('theExpandedMosaic', []);
p.addParameter('workerID', [], @isnumeric);
p.addParameter('workDescription', '', @ischar);
p.parse(oiSequence, varargin{:});

currentSeed     = p.Results.seed;
oiSequence      = p.Results.oiSequence;
emPaths         = p.Results.emPaths;
trialBlocks     = p.Results.trialBlocks;
currentFlag     = p.Results.currentFlag;
workerID        = p.Results.workerID;
workDescription = p.Results.workDescription;
theExpandedMosaic = p.Results.theExpandedMosaic;
LMSfilters        = p.Results.interpFilters;
meanCur           = p.Results.meanCur;

% Set debugTiming to true to examine the timing between oiFrames and
% partial/full absorptions
debugTiming = false;

oiTimeAxis = oiSequence.timeAxis;
nTimes = numel(oiTimeAxis);
if (oiSequence.length ~= nTimes)
    error('oiTimeAxis and oiSequence must have equal length\n');
end

if (isempty(emPaths))
    emPaths = reshape(obj.emPositions, [1 size(obj.emPositions)]);
end

if (isempty(emPaths))
    error('Either supply an ''emPaths'' key-value pair, or preload coneMosaic.emPositions');
end

if (isempty(theExpandedMosaic))
    padRows = max(max(abs(emPaths(:,:,2))));
    padCols = max(max(abs(emPaths(:,:,1))));
    
    % We need a copy of the object because of eye movements.
    % Make it here instead of in coneMosaic.compute(), which is called multiple times.
    obj.absorptions = [];
    obj.current = [];
    obj.os.lmsConeFilter = [];
    theExpandedMosaic = obj.copy();
    theExpandedMosaic.pattern = zeros(obj.rows+2*padRows, obj.cols+2*padCols);
end
    
%% Get ready for output variables

photocurrents = [];
% varargout{1} = [];
% varargout{2} = [];

%% Save default integration time
defaultIntegrationTime = obj.integrationTime;

%% Compute eye movement time axis
nTrials       = size(emPaths,1);
nEyeMovements = size(emPaths,2);
eyeMovementTimeAxis = oiTimeAxis(1) + (0:1:(nEyeMovements-1)) * obj.integrationTime;

%% Compute OIrefresh
if (numel(oiTimeAxis) == 1)
    oiRefreshInterval = defaultIntegrationTime;
else
    oiRefreshInterval = oiTimeAxis(2)-oiTimeAxis(1);
end

% Only allocate memory for the non-null cones in a 3D matrix [instances x numel(nonNullConesIndices) x time]
nonNullConesIndices = find(obj.pattern>1);
absorptions = zeros(nTrials, numel(nonNullConesIndices), numel(eyeMovementTimeAxis), 'single');

% Organize trials in blocks if we have a hex mosaic
if (trialBlocks > 1) && (isa(obj, 'coneMosaicHex'))
end

trialsBlockSize = floor(nTrials/trialBlocks);
trialIndices = {};
for iTrialBlock = 1:trialBlocks
    firstTrial = trialBlockSize*(iTrialBlock-1) + 1;
    lastTrial = trialBlockSize*(iTrialBlock-1) + trialsBlockSize;
    trialIndices{iTrialBlock} = firstTrial:lastTrial;
    [iTrialBlock firstTrial lastTrial nTrials]
end
if (lastTrial < nTrials)
    firstTrial = lastTrial+1;
    lastTrial = nTrials;
    iTrialBlock = numel(trialIndices)+1;
    trialIndices{iTrialBlock} = firstTrial:lastTrial;
    [iTrialBlock firstTrial lastTrial nTrials]
end
        
if (oiRefreshInterval >= defaultIntegrationTime)
    % There are two main time sampling scenarios.  This one is when the oi
    % update rate is SLOWER than the cone integration time which is also
    % equal to the eye movement update rate.  
    % 
    
    % SCENARIO
    %              |----- oiRefreshInterval ----|----- oiRefreshInterval ----|----- oiRefreshInterval ----|
    %      oi      |                            |                            |                            |
    %   sequence   |                            |<-----tFrameStart           |                            |
    % _____________.____________________________|           tFrameEnd------->|____________________________|
    %     eye      |          |          |          |          |          |          |          |          |
    %   movement   |          |          |-intTime->|-intTime->|-intTime->|          |          |          |
    %   sequence   |          |          |          |          |          |          |          |          |
    % ------------------------------------******xxxx|**********|**********|--------------------------------|
    %                                       p1   p2     full        full
    %                   partial absorption_/      \_partial absorption  \_ full absorption
    %
    
    if (debugTiming)
        hFig = figure(9000); clf;
        set(hFig, 'Name', 'Visual Timing Debug Window', 'Position', [10 10 1600 200]);
        subplot('Position', [0.01 0.01 0.98 0.98]);
        hold on
    end
    
    % Loop over the optical images
    for oiIndex = 1:oiSequence.length
        
        if (~isempty(workerID))
            % Update progress in command window
            displayProgress(workerID, workDescription, 0.5*oiIndex/oiSequence.length);
        end
        
        % Current oi time limits
        tFrameStart = oiTimeAxis(oiIndex);
        tFrameEnd   = tFrameStart + oiRefreshInterval;
        
        if (debugTiming)
            x = [tFrameStart tFrameStart tFrameEnd tFrameEnd tFrameStart];
            y = [0 -10 -10 0 0];
            plot(x,y, 'r-');
        end
        
        % Find eye movement indices withing the oi limits
        indices = find( ...
            (eyeMovementTimeAxis >= tFrameStart - defaultIntegrationTime - eps(tFrameStart-defaultIntegrationTime)) & ...
            (eyeMovementTimeAxis <= tFrameEnd -   defaultIntegrationTime + eps(tFrameEnd-defaultIntegrationTime)) );
        
        if (isempty(indices))
            fprintf('No eye movements within oiIndex #%d\n', oiIndex);
            continue;
            %error('Empty indices. This should never happen.');
        end
        % the first eye movement requires special treatment as it may have started before the current frame,
        % so we need to compute partial absorptions over the previous frame and over the current frame
        idx = indices(1);
        integrationTimeForFirstPartialAbsorption = tFrameStart-eyeMovementTimeAxis(idx);
        integrationTimeForSecondPartialAbsorption = eyeMovementTimeAxis(idx)+defaultIntegrationTime-tFrameStart;
        
        if (integrationTimeForFirstPartialAbsorption < eps(tFrameStart))
            integrationTimeForFirstPartialAbsorption = 0;
        elseif (integrationTimeForSecondPartialAbsorption < eps(eyeMovementTimeAxis(idx)+defaultIntegrationTime))
            integrationTimeForSecondPartialAbsorption = 0;
        end
        
        % Partial absorptions (p1 in graph above) with previous oi
        % (across all instances)
        if (oiIndex > 1) && (integrationTimeForFirstPartialAbsorption > 0)
            % Update the @coneMosaic with the partial integration time
            obj.integrationTime = integrationTimeForFirstPartialAbsorption;
            % Compute partial absorptions
            emSubPath = reshape(squeeze(emPaths(1:nTrials,idx,:)), [nTrials 2]);
            currentSeed = currentSeed  + 1;
            absorptionsAllTrials = obj.compute(...
                oiSequence.frameAtIndex(oiIndex-1), ...
                'theExpandedMosaic', theExpandedMosaic, ...
                'seed', currentSeed , ...
                'emPath', emSubPath, ...
                'currentFlag', false ...
                );
            if (debugTiming)
                x = tFrameStart - [0 0 obj.integrationTime obj.integrationTime 0];
                y = [-1 -2 -2 -1 -1] - (oiIndex-1)*0.1;
                plot(x,y, 'b--');
            end
        else
            absorptionsAllTrials = zeros(size(obj.pattern,1), size(obj.pattern,2), nTrials);
        end
        
        if (integrationTimeForSecondPartialAbsorption > 0)
            % Partial absorptions (p2 in graph above) with current oi across all instances.
            % Update the @coneMosaic with the partial integration time
            obj.integrationTime = integrationTimeForSecondPartialAbsorption;
            % Compute partial absorptions
            emSubPath = reshape(squeeze(emPaths(1:nTrials,idx,:)), [nTrials 2]);
            currentSeed = currentSeed  + 1;
            absorptionsAllTrials =  absorptionsAllTrials + obj.compute(...
                oiSequence.frameAtIndex(oiIndex), ...
                'theExpandedMosaic', theExpandedMosaic, ...
                'seed', currentSeed, ...
                'emPath', emSubPath, ...
                'currentFlag', false ...
                );
            if (debugTiming)
                x = tFrameStart + [0 0 obj.integrationTime obj.integrationTime 0];
                y = [-1 -2 -2 -1 -1] - (oiIndex-1)*0.1;
                plot(x,y, 'm-');
            end
            % vcNewGraphWin; imagesc(absorptionsDuringCurrentFrame);
        end
        
        % Reformat and insert to time series
        firstEMinsertionIndex = round((eyeMovementTimeAxis(idx)-eyeMovementTimeAxis(1))/defaultIntegrationTime)+1;
        reformatAbsorptionsAllTrialsMatrix(nTrials, 1, size(obj.pattern,1), size(obj.pattern,2));
        absorptions(1:nTrials, :, firstEMinsertionIndex) = absorptionsAllTrials;
        
        % Full absorptions with current oi and default integration time
        if (numel(indices)>1)
            % Update the @coneMosaic with the default integration time
            obj.integrationTime = defaultIntegrationTime;
            % Compute absorptions for all remaining the OIs
            idx = indices(2:end);
            emSubPath = reshape(emPaths(1:nTrials, idx,:), [nTrials*numel(idx) 2]);
            currentSeed = currentSeed  + 1;
            absorptionsAllTrials = obj.compute(...
                oiSequence.frameAtIndex(oiIndex), ...
                'theExpandedMosaic', theExpandedMosaic, ...
                'seed', currentSeed, ...
                'emPath', emSubPath, ...
                'currentFlag', false ...
                );
            % Reformat and insert to time series
            remainingEMinsertionIndices = round((eyeMovementTimeAxis(idx)-eyeMovementTimeAxis(1))/defaultIntegrationTime)+1;
            reformatAbsorptionsAllTrialsMatrix(nTrials, numel(remainingEMinsertionIndices), size(obj.pattern,1), size(obj.pattern,2));
            absorptions(1:nTrials, :, remainingEMinsertionIndices) = absorptionsAllTrials;
            if (debugTiming)
                for kk = 2:numel(indices)
                    x = tFrameStart + integrationTimeForSecondPartialAbsorption + [0 0 (kk-1)*obj.integrationTime (kk-1)*obj.integrationTime 0];
                    y = [-1 -2 -2 -1 -1] - (oiIndex-1)*0.1;
                    plot(x,y, 'k:');
                    drawnow;
                end
            end
        end
        
        if (debugTiming)
            if (numel(indices) == 1)
                fprintf('[%3d/%3d]: p1=%05.1fms p2=%05.1fms f=%05.1fms, i1=%03d, iR=[]      i1Time=%06.1fms, iRtime=[]                     (%d)\n', oiIndex, oiSequence.length, integrationTimeForFirstPartialAbsorption*1000, integrationTimeForSecondPartialAbsorption*1000, 0, firstEMinsertionIndex, eyeMovementTimeAxis(indices(1))*1000, numel(indices));
            else
                fprintf('[%3d/%3d]: p1=%05.1fms p2=%05.1fms f=%05.1fms, i1=%03d, iR=%03d-%03d i1Time=%06.1fms, iRtime=[%06.1fms .. %06.1fms] (%d)\n', oiIndex, oiSequence.length, integrationTimeForFirstPartialAbsorption*1000, integrationTimeForSecondPartialAbsorption*1000, obj.integrationTime*1000, firstEMinsertionIndex, remainingEMinsertionIndices(1), remainingEMinsertionIndices(end), eyeMovementTimeAxis(indices(1))*1000, eyeMovementTimeAxis(indices(2))*1000, eyeMovementTimeAxis(indices(end))*1000, numel(indices));
            end
            if (oiSequence.length > 1)
                set(gca, 'XLim', [oiTimeAxis(1) oiTimeAxis(end)]); 
                pause
            end
        end
    end  % oiIndex
    
    % oiRefreshInterval > defaultIntegrationTime
else
    % There are two main time sampling scenarios.  This one is when the oi
    % update rate is FASTER than the cone integration time which is also equal
    % to the eye movement update rate
    
    % SCENARIO
    %     eye      |                             |                             |                             |
    %   movement   |                             |                             |                             |
    %   sequence   |                             |<-----emStart                |                             |
    % _____________._____________________________|                emEnd------->|_____________________________|
    %              |            |            |            |            |            |          |          |
    %      oi      |            |            |-oiRefresh->|-oiRefresh->|-oiRefresh->|          |          |
    %   sequence   |            |            |    ********|************|*******     |          |          |
    % ---------------------------------------------partial-----full-----partial-------------------------------
    %                                            absorption  absorption absorption
    
    % Loop over the eye movements
    for emIndex = 1:nEyeMovements
        
        if (~isempty(workerID))
            displayProgress(workerID, workDescription, 0.5*emIndex/nEyeMovements);
        end
        
        % Current eye movement time limits
        emStart = eyeMovementTimeAxis(emIndex);
        emEnd   = emStart + defaultIntegrationTime;
        
        % sum the partial integration times
        actualIntegrationTime = 0;
        
        % Find oi indices withing the eye movement frame time limits
        indices = find( ...
            (oiTimeAxis >= emStart - oiRefreshInterval - eps(emStart - oiRefreshInterval)) & ...
            (oiTimeAxis <= emEnd + eps(emEnd)) );
        
        if (isempty(indices))
            fprintf('No OIs within emIndex #%d\n', emIndex);
            continue;
        end
        
        % Partial absorptions during the ovelap with the OI that started before the emStart
        idx = indices(1);
        integrationTimeForFirstPartialAbsorption = oiTimeAxis(idx)+oiRefreshInterval-emStart;
        if (integrationTimeForFirstPartialAbsorption > eps(oiTimeAxis(idx)+oiRefreshInterval))
            % Update the @coneMosaic with the partial integration time
            obj.integrationTime = integrationTimeForFirstPartialAbsorption;
            % Update the sum of partial integration times
            actualIntegrationTime = actualIntegrationTime + obj.integrationTime;
            % Compute absorptions
            emSubPath = reshape(emPaths(1:nTrials, emIndex,:), [nTrials 2]);
            currentSeed = currentSeed  + 1;
            absorptionsAllTrials = obj.compute(...
                oiSequence.frameAtIndex(idx), ...
                'theExpandedMosaic', theExpandedMosaic, ...
                'seed', currentSeed, ...
                'emPath', emSubPath, ...
                'currentFlag', false ...
                );
        else
            absorptionsAllTrials = zeros(size(obj.pattern,1), size(obj.pattern,2), nTrials);
        end
        
        % Next, compute full absorptions for the remaining OIs
        if (numel(indices)>1)
            for k = 2:numel(indices)
                % Update the @coneMosaic with the partial integration time
                if (k < numel(indices))
                    % full absorption during the duration of the OI
                    obj.integrationTime = oiRefreshInterval;
                else
                    % partial absorption during the last OI
                    idx = indices(end);
                    integrationTimeForLastPartialAbsorption = emEnd - oiTimeAxis(idx);
                    obj.integrationTime = integrationTimeForLastPartialAbsorption;
                end
                
                % Update the sum of partial integration times
                actualIntegrationTime = actualIntegrationTime + obj.integrationTime;
                % Compute absorptions
                emSubPath = reshape(emPaths(1:nTrials, emIndex,:), [nTrials 2]);
                currentSeed = currentSeed  + 1;
                absorptionsAllTrials = absorptionsAllTrials + obj.compute(...
                    oiSequence.frameAtIndex(indices(k)), ...
                    'theExpandedMosaic', theExpandedMosaic, ...
                    'seed', currentSeed, ...
                    'emPath', emSubPath, ...
                    'currentFlag', false ...
                    );
            end  % for k
        end
        
        % Check the sum of partial absorptions equal the default absorption time
        if (abs(actualIntegrationTime-defaultIntegrationTime) > defaultIntegrationTime*0.0001) && (emIndex < numel(eyeMovementTimeAxis))
            error('Actual integration time (%3.5f) not equal to desired value (%3.5f) [emIndex: %d / %d]\n', actualIntegrationTime, defaultIntegrationTime, emIndex, numel(eyeMovementTimeAxis));
        end
        
        % Reformat and insert to time series
        insertionIndices = round((eyeMovementTimeAxis(emIndex)-eyeMovementTimeAxis(1))/defaultIntegrationTime)+1;
        reformatAbsorptionsAllTrialsMatrix(nTrials, numel(insertionIndices), size(obj.pattern,1), size(obj.pattern,2));
        absorptions(1:nTrials, :, insertionIndices) = absorptionsAllTrials;
    end % emIndex
end % oiRefreshInterval > defaultIntegrationTime

% Restore default integrationTime
obj.integrationTime = defaultIntegrationTime;

% Reload the full eye movement sequence for the first instance only
if (ndims(emPaths) == 3), obj.emPositions = squeeze(emPaths(1,:,:));
else                      obj.emPositions = emPaths;
end

% If we don't compute the current, we return only the absorptions from the
% last trial.  We never compute the current if there are no eye movements.
if (~currentFlag) || (numel(eyeMovementTimeAxis) == 1)
   
    if (isa(obj, 'coneMosaicHex'))
        tmp  = squeeze(absorptions(nTrials,:,:));
        if (numel(eyeMovementTimeAxis == 1))
            tmp = tmp';    
        end
        
        % Return the absorptions from the last triale after reshaping to full 3D matrix [cone_rows, cone_cols, time]
        obj.absorptions = obj.reshapeHex2DmapToHex3Dmap(tmp);  
    else
        % Reshape to full 4D matrix [instances, cone_rows, cone_cols, time]
        absorptions = reshape(absorptions, [nTrials size(obj.pattern,1) size(obj.pattern,2) numel(eyeMovementTimeAxis)]);
        
        % Return the absorptions from the last trial.
        obj.absorptions = reshape(squeeze(absorptions(nTrials,:,:)), [size(obj.pattern,1) size(obj.pattern,2) numel(eyeMovementTimeAxis)]);
    end
    return;
end

%% Photocurrent computation

% The currentFlag must be on, and there must be a few eye movements. So we
% compute. 
%

% N.B.  Not adequately checked for osBioPhys model.  Runs ok for osLinear
% model.

if (currentFlag)
    if (isa(obj, 'coneMosaicHex'))
        photocurrents = zeros(nTrials, numel(nonNullConesIndices), numel(eyeMovementTimeAxis), 'single');
        for ii=1:nTrials
            % Reshape to full 3D matrix for obj.computeCurrent
            obj.absorptions = obj.reshapeHex2DmapToHex3Dmap(squeeze(absorptions(ii,:,:)));
            currentSeed = currentSeed  + 1;
            if ii == 1 && (isempty(meanCur) || isempty(LMSfilters))
                % On the first trial, compute the interpolated linear
                % filters and the mean current, unless they were passed in
                [LMSfilters, meanCur] = obj.computeCurrent('seed', currentSeed);
            else
                LMSfilters = obj.computeCurrent('seed', currentSeed,'interpFilters',LMSfilters,'meanCur',meanCur);
            end
            % Back to 2D matrix to save space
            photocurrents(ii,:,:) = single(obj.reshapeHex3DmapToHex2Dmap(obj.current));
        end
    else
        photocurrents = zeros(nTrials, obj.rows, obj.cols, numel(eyeMovementTimeAxis), 'single');
        for ii=1:nTrials
            % Put this trial of absorptions into the cone mosaic
            obj.absorptions = reshape(squeeze(absorptions(ii,:,:,:)), [obj.rows obj.cols, numel(eyeMovementTimeAxis)]);
            currentSeed = currentSeed  + 1;
            if ii == 1 && (isempty(meanCur) || isempty(LMSfilters))
                % On the first trial, compute the interpolated linear
                % filters and the mean current
                [LMSfilters, meanCur] = obj.computeCurrent('seed', currentSeed);
            else
                % On the remaining trials, use the same interpolated
                % filters and mean current
                LMSfilters = obj.computeCurrent('seed', currentSeed,'interpFilters',LMSfilters,'meanCur',meanCur);
            end
            photocurrents(ii,:,:,:) = single(reshape(obj.current, [1 obj.rows obj.cols numel(eyeMovementTimeAxis)]));
        end
    end
end


% Reload the absorptions from the last instance (again, since we destroyed
% obj.absorptions in the current computation)
if (isa(obj, 'coneMosaicHex'))
    % Return the absorptions from the last triale after reshaping to full
    % 3D matrix [cone_rows, cone_cols, time]
    tmp = squeeze(absorptions(nTrials,:,:));
    if (numel(eyeMovementTimeAxis) == 1)
        tmp = tmp';
    end
    obj.absorptions = obj.reshapeHex2DmapToHex3Dmap(tmp);
else
    % Reshape to full 4D matrix [instances, cone_rows, cone_cols, time]
    absorptions = reshape(absorptions, [nTrials obj.rows obj.cols numel(eyeMovementTimeAxis)]);
    
    % Return the absorptions from the last trial.
    obj.absorptions = reshape(squeeze(absorptions(nTrials,:,:)), [obj.rows obj.cols numel(eyeMovementTimeAxis)]);
end

%% Nested function to reformat absorptions
    function reformatAbsorptionsAllTrialsMatrix(nTrials, timePointsNum, coneRows, coneCols)
        % Save all absorptions as singles to save space
        absorptionsAllTrials = single(absorptionsAllTrials);
        
        % Reshape to cones x instances x timePoints. Note the 3rd dimension of
        % absorptionsAllTrials is traditionally time, but when we are doing multiple instances, it is instances * time
        absorptionsAllTrials = reshape(absorptionsAllTrials, [coneRows*coneCols nTrials timePointsNum]);
        
        % Only get the absorptions for the non-null cones - this has an effect only for coneMosaicHex mosaics
        absorptionsAllTrials = absorptionsAllTrials(nonNullConesIndices,:,:);
        
        % Reshape to [instances x cones x timePoints]
        absorptionsAllTrials = permute(absorptionsAllTrials, [2 1 3]);
    end
end

%%
function displayProgress(workerID, workDescription, progress)

maxStarsNum = 32;
if (isnan(progress))
    fprintf('worker-%02d: %s |', workerID, workDescription);
    for k = 1:maxStarsNum
        fprintf('*');
    end
    fprintf('|');
else
    fprintf('worker-%02d: %s |', workerID, workDescription);
    if (progress>1)
        progress = 1;
    end
    starsNum = round(maxStarsNum*progress);
    for k = 1:starsNum
        fprintf('*');
    end
end
fprintf('\n');
end

