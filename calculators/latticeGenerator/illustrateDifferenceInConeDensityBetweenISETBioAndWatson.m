function illustrateDifferenceInConeDensityBetweenISETBioAndWatson
    
    obj = WatsonRGCModel();       
    obj.dc0
    
    eccentricities = logspace(log10(0.01), log10(60), 64); eccUnits = 'deg';
    densityUnits = 'mm^2';
    rightEyeVisualFieldMeridianName = 'superior meridian';
    
    [~, coneDensityISETBio] = ...
        obj.coneRFSpacingAndDensityAlongMeridian(eccentricities, ...
        rightEyeVisualFieldMeridianName, eccUnits, densityUnits, ...
        'correctForMismatchInFovealConeDensityBetweenWatsonAndISETBio', false);
    
    [~, coneDensityWatson] = ...
        obj.coneRFSpacingAndDensityAlongMeridian(eccentricities, ...
        rightEyeVisualFieldMeridianName, eccUnits, densityUnits, ...
        'correctForMismatchInFovealConeDensityBetweenWatsonAndISETBio', true);
    
    [~, mRGCRFDensity] = ...
        obj.mRGCRFSpacingAndDensityAlongMeridian(eccentricities, ...
        rightEyeVisualFieldMeridianName, eccUnits, densityUnits);

     visualize(eccentricities, coneDensityISETBio, coneDensityWatson, ...
         mRGCRFDensity, {'ISETBio', 'Watson (2014)'}, eccUnits, densityUnits, ...
         rightEyeVisualFieldMeridianName);
     
end

function visualize(eccDegs, coneDensity1, coneDensity2, mRGCRFDensity, legends, eccUnits, densityUnits, rightEyeVisualFieldMeridianName)
    % Visualize
    % Instantiate a plotlab object
    plotlabOBJ = plotlab();

    % Apply the default plotlab recipe overriding 
    % the color order and the figure size
    plotlabOBJ.applyRecipe(...
        'renderer', 'painters', ...
        'axesXScale', 'log', ...
        'axesYScale', 'log', ...
        'colorOrder', [0 0 1; 1 0 0.5], ...
        'axesTickLength', [0.015 0.01]/2,...
        'axesFontSize', 16, ...
        'figureWidthInches', 16, ...
        'figureHeightInches', 9);
    
    % Generate figure handle
    hFig = figure(1); clf;
    
    % Generate axes in a [1x2] layout
    theAxesGrid = plotlab.axesGrid(hFig, ...
        'rowsNum', 1, 'colsNum', 2, ...
        'rightMargin', 0.02, ...
        'leftMargin', 0.09, ...
        'widthMargin', 0.08, ...
        'bottomMargin', 0.09, ...
        'topMargin', 0.05);
    
    % -------- The left plot (1,1) --------
    theLeftPlotAxes = theAxesGrid{1,1};
    scatter(theLeftPlotAxes, eccDegs, coneDensity1); hold(theLeftPlotAxes, 'on');
    scatter(theLeftPlotAxes, eccDegs, coneDensity2);
    %legend(theLeftPlotAxes, legends, 'Location', 'NorthEast');
    set(theLeftPlotAxes, 'XTick',[0.01 0.03 0.1 0.3 1 3 10 30 100], 'YTick', [1 3 10 30 100 300 1000 3000 10000 30000 100000 200000 250000 300000], 'YLim', [1000 300000]);
    xlabel(theLeftPlotAxes,sprintf('\\it eccentricity (%s)', eccUnits));
    ylabel(theLeftPlotAxes, sprintf('\\it cone density (count / %s)', densityUnits));
    
    % -------- The right plot (1,2) --------
    theRightPlotAxes = theAxesGrid{1,2};
    scatter(theRightPlotAxes, eccDegs, mRGCRFDensity./coneDensity1); hold(theRightPlotAxes, 'on');
    scatter(theRightPlotAxes, eccDegs, mRGCRFDensity./coneDensity2);
    legend(theRightPlotAxes, legends, 'Location', 'NorthEast');
    set(theRightPlotAxes, 'XTick',[0.01 0.03 0.1 0.3 1 3 10 30 100], 'YTick', [0.01 0.03 0.1 0.3 1 2 3], 'YLim',  [0.01 3]);
    xlabel(theRightPlotAxes,sprintf('\\it eccentricity (%s)', eccUnits));
    ylabel(theRightPlotAxes, sprintf('\\it cone density (count / %s)', densityUnits));
    title(rightEyeVisualFieldMeridianName);
end

