function coneTypes = assignConeTypes(conePositionsMicrons, coneSpacingsMicrons, ...
            tritanopicAreaDiameterMicrons, relativeSconeSpacing, LtoMratio, roi, visualizeProcess, plotlabOBJ)
   
    conesNum = size(conePositionsMicrons,1);
    
    % Reserve all cones within the tritanopic area to be either L or M
    ecc = sqrt(sum(conePositionsMicrons.^2,2));
    fovealLorMconeIndices = find(ecc <= 0.5*tritanopicAreaDiameterMicrons);
    
    % Reserve cones outside the tritanopic are to be either L or M, except
    % cones that are separated by relativeSconeSpacing*local cone spacing,
    % which will remain S
    peripheralConeIndices = setdiff(1:conesNum, fovealLorMconeIndices);
    idx = determineLMconeIndices(conePositionsMicrons(peripheralConeIndices,:), coneSpacingsMicrons(peripheralConeIndices), relativeSconeSpacing);
    peripheralLMConeIndices = peripheralConeIndices(idx);
    
    % Assign type to all peripheralConeIndices (to L for now)
    LMconeIndices = [fovealLorMconeIndices(:); peripheralLMConeIndices(:)];
    
    % Assing L and M-cone indices
    p = rand(1,numel(LMconeIndices));
    if (isinf(LtoMratio))
        idx = 1:numel(LMconeIndices);
    else
        idx = find(p<LtoMratio/(1+LtoMratio));
    end
    LconeIndices = LMconeIndices(idx);
    MconeIndices = setdiff(LMconeIndices, LconeIndices);
    SconeIndices = setdiff(1:conesNum, LMconeIndices);
    assert(conesNum-numel(LconeIndices)-numel(MconeIndices)-numel(SconeIndices)==0, ...
        'Indices do not sum up to total cones');
    
    % Return cone types
    coneTypes = zeros(1,conesNum);
    coneTypes(LconeIndices) = 2;
    coneTypes(MconeIndices) = 3;
    coneTypes(SconeIndices) = 4;
    
    if (visualizeProcess)
        visualizeConeMosaic(conePositionsMicrons, coneTypes, roi, plotlabOBJ);
    end
end


function LMconeIndices = determineLMconeIndices(conePositionsMicrons, coneSpacingsMicrons, relativeSconeSpacing)
    conesNum = size(conePositionsMicrons,1);
    
    % Compute ecc of all cones
    ecc = sqrt(sum(conePositionsMicrons.^2,2));
    
    % Compute distances between each cone and its closest 100 cones
    [d, i] = pdist2(conePositionsMicrons, conePositionsMicrons, 'euclidean', 'smallest', 100);
    
    % Remove the distance to the cone itself
    d = d(2:end,:);
    i = i(2:end,:);
    
    % Go through all cones assigning as S-cones those that are no closer
    % than coneSpacingsMicrons(coneIndex)*relativeSconeSpacing from each other
    coneIndex = 1;
    LMconeIndices = [];
    SconeIndices = [];
    remainingConeIndices = 1:conesNum;
    
    while (numel(remainingConeIndices)>0)
        % Leave the type of the current coneIndex as S.
        SconeIndices = cat(2, SconeIndices, coneIndex);
        % This means all cones around it within the exclusion radius must be non S
        currentExclusionRadius = coneSpacingsMicrons(coneIndex)*relativeSconeSpacing;
        distancesToNearbyCones = d(:,coneIndex);
        idx = find(distancesToNearbyCones < currentExclusionRadius);
        LMconeIndices = cat(1, LMconeIndices, squeeze(i(idx, coneIndex)));
        % Keep a count of the remaining cone indices that need to be visited
        remainingConeIndices = setdiff(remainingConeIndices, SconeIndices);
        remainingConeIndices = setdiff(remainingConeIndices, LMconeIndices);
        % Next cone to visit
        [~,idx] = min(ecc(remainingConeIndices));
        coneIndex = remainingConeIndices(idx);
        
        visualizeProcess = ~true;
        if (visualizeProcess)
            figure(100); clf;
            scatter(conePositionsMicrons(SconeIndices,1), conePositionsMicrons(SconeIndices,2), 'b'); hold on;
            scatter(conePositionsMicrons(LMconeIndices,1), conePositionsMicrons(LMconeIndices,2), 'r');
            scatter(conePositionsMicrons(remainingConeIndices,1), conePositionsMicrons(remainingConeIndices,2), 'k');
            scatter(conePositionsMicrons(coneIndex,1), conePositionsMicrons(coneIndex,2), 'm');
        end
    end
    LMconeIndices = unique(LMconeIndices);
end
