function scene = sceneInitGeometry(scene)
% Initialize scene distance parameter.  
%
% Syntax:
%	scene = sceneInitGeometry(scene);
%
% Description:
%    We are leaving this trivial routine here for potential future
%    development.
%
%    If the parameter is already set, then it is not modified by this
%    routine.
%
% Inputs:
%    scene - The scene structure
%
% Outputs:
%    scene - The modified scene structure
%

%  History:
%    xx/xx/03       Copyright ImagEval Consultants, LLC, 2003.
%    12/21/17  jnm  Formatting

% Set scene distance in meters
if notDefined('scene.distance')
    scene = sceneSet(scene,'distance', 1.2);
end

end