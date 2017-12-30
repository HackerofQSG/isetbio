function r = ieDeg2rad(d, units)
% Convert degrees to radians
%
% Syntax:
%   r = ieDeg2rad(d, [units])
%
% Description:
%    Convert degrees to radians. Apply additional conversions if
%    appropriate units (arcmin, arcsec) are provided.
%
% Inputs:
%    d     - Degrees to convert
%    units - Units to apply to radians in conversion. 
%
% Outputs:
%    r     - measurement in Radians (unless other unit specified)
%
% Notes:
%
% See Also:
%    rad2deg

% History:
%    xx/xx/03       Copyright ImagEval Consultants, LLC, 2003.
%    12/01/17  jnm  Formatting, Add units argument, if statement based on
%                   units argument, and scale multiplier. 
%    12/22/17  BW   Introduced, removed deg2rad to avoid matlab
%                   conflict, replaced throughout code.
% Examples:
%{
    ieDeg2rad(90)
    ieDeg2rad(1, 'arcmin')
    ieDeg2rad(1, 'arcsec')
%}

if notDefined('units')
    r = (pi / 180) * d;
else
    r = (pi / 180) * d * ieUnitScaleFactor(units);
end