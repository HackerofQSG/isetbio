function iStim = ieStimulusBar(varargin)
% Creates a movie/dynamic scene stimulus in isetbio of a white bar on a
% black background that sweeps from left to right.
% 
% Inputs: a structure that defines the parameters of the bar stimulus.
% 
% Outputs: iStim is a structure that contains the display, the scene, the
%   optical image and the sensor.
% 
% Example:
%   params.barWidth = 10;
%   params.nSteps = 20;
%   iStim = ieStimulusBar(params);
%   vcAddObject(iStim.scene); sceneWindow;
% 
% 3/2016 JRG (c) isetbio team

%% Parse inputs
p = inputParser;
addParameter(p,'barWidth',       5,     @isnumeric);
addParameter(p,'meanLuminance',  200,   @isnumeric);
addParameter(p,'nSteps',         50,    @isnumeric);
addParameter(p,'row',            64,    @isnumeric);  
addParameter(p,'col',            64,    @isnumeric);  
addParameter(p,'fov',            0.6,    @isnumeric);  
addParameter(p,'vfov',            0.4988,    @isnumeric);  

p.parse(varargin{:});

params = p.Results;
%% Compute a Gabor patch scene as a placeholder for the bar image

% Set up Gabor stimulus using sceneCreate('harmonic',params)
fov = params.fov;
vfov = params.vfov;
% % Bar width in pixels
% params.barWidth = 5;
% % Mean luminance
% params.meanLuminance = 200;
% % Size of image in (row,col)
% params.row = 64; params.col = 64;

% params.freq = 6; params.contrast = 1;
% % params.ph  = 0;  params.ang = 0;
% params.row = 64; params.col = 64;
% params.GaborFlag = 0.2; % standard deviation of the Gaussian window

% Create display
display = displayCreate('CRT-Sony-HorwitzLab');

% Set up scene, oi and sensor
scene = sceneCreate('harmonic', params);
scene = sceneSet(scene, 'h fov', fov);
% vcAddObject(scene); sceneWindow;

% These parameters are for other stuff.
params.expTime = 0.01;
params.timeInterval = 0.01;
% params.nSteps = 50;     % Number of stimulus frames

%% Initialize the optics and the sensor
oi  = oiCreate('wvf human');
sensor = sensorCreate('human');
sensor = sensorSetSizeToFOV(sensor, fov, scene, oi);

sensor = sensorSet(sensor, 'exp time', params.expTime); 
sensor = sensorSet(sensor, 'time interval', params.timeInterval); 

%% Compute a dynamic set of cone absorptions

% We want to produce a scene video that translates into an oi video that
% becomes a cone absorption video.  At present coneAbsorptions ONLY does
% this using eye movements, not by creating a series of images.  This code
% represents our first effort to produce dynamic scenes.

% We are literally going to recreate a set of scenes with different phase
% positions and produce the scenes, ois, and cone absorptions by the loop.
% The result will be a time series of the cone photon absorptions.
%
% We are reluctant to make scene(:,:,:,t) because we are frightened about
% the size.  But it still might be the right thing to do.  So the code here
% is an experiment and we aren't sure how it will go.

% sceneRGB = zeros([sceneGet(scene, 'size') params.nSteps 3]); % 3 is for R, G, B
% sensorPhotons = zeros([sensorGet(sensor, 'size') params.nSteps]);
% stimulus = zeros(1, params.nSteps);
%% Compute a dynamic set of cone absorptions for moving bar
%
%
% We want to produce a scene video that translates into an oi video that
% becomes a cone absorption video.  At present coneAbsorptions ONLY does
% this using eye movements, not by creating a series of images.  This code
% represents our first effort to produce dynamic scenes.
%
% We are literally going to recreate a set of scenes with different phase
% positions and produce the scenes, ois, and cone absorptions by the loop.
% The result will be a time series of the cone photon absorptions.
%
% We are reluctant to make scene(:,:,:,t) because we are frightened about
% the size.  But it still might be the right thing to do.  So the code here
% is an experiment and we aren't sure how it will go.

% sceneRGB = zeros([sceneGet(scene, 'size') params.nSteps 3]); % 3 is for R, G, B
% sensorPhotons = zeros([sensorGet(sensor, 'size') params.nSteps]);
% stimulus = zeros(1, params.nSteps);
fprintf('Computing cone isomerization:    \n');

% ieSessionSet('wait bar',true);
wFlag = ieSessionGet('wait bar');
if wFlag, wbar = waitbar(0,'Stimulus movie'); end

% Loop through frames to build movie
for t = 1 : params.nSteps
    if wFlag, waitbar(t/params.nSteps,wbar); end
        

%     if t == 1 
        barMovie = zeros(params.row,params.col,3);
%     end
    barMovie(:,1+t:t+params.barWidth,:) = 0.5 + 0.499*ones(params.row,params.barWidth,3);
    barMovie(1,1,:) = 0;

    % % % % Generate scene object from stimulus RGB matrix and display object
    scene = sceneFromFile(barMovie, 'rgb', params.meanLuminance, display);

    scene = sceneSet(scene, 'h fov', fov);
    
    % scene = sceneSet(scene, 'v fov', vfov);
    % sensor = sensorSet(sensor,'v fov', vfov);
    
    % Get scene RGB data    
    sceneRGB(:,:,t,:) = sceneGet(scene,'rgb');
    
    % Compute optical image
    oi = oiCompute(oi, scene);    
    
    % Compute absorptions
    sensor = sensorCompute(sensor, oi);

    if t == 1
        volts = zeros([sensorGet(sensor, 'size') params.nSteps]);
    end
    
    volts(:,:,t) = sensorGet(sensor, 'volts');
    
    % vcAddObject(scene); sceneWindow
end

if wFlag, delete(wbar); end

% Set the stimuls into the sensor object
sensor = sensorSet(sensor, 'volts', volts);
% vcAddObject(sensor); sensorWindow;

% These are both the results and the objects needed to recreate this
% script. So calling isomerizationBar(iStim) should produce the same
% results.

iStim.params  = params;

iStim.display = display;
iStim.scene   = scene;
iStim.sceneRGB = sceneRGB;
iStim.oi      = oi;
iStim.sensor  = sensor;
end