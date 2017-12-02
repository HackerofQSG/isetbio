function cm = ieCmap(cName, num, gam)
% Prepare simple color maps
%
% Syntax:
%   cm = ieCmap(cName, [num], [gam])
%
% Description:
%    Create a simple color map using the color map type, the number of
%    colors, and the luminance.
%
% Inputs:
%    cName - (Optional) Color map name. Default 'rg'. Options are:
%               {'rg', 'redgreen'}
%               {'by', 'blueyellow'}
%               {'bw', 'blackwhite', 'luminance'}
%    num   - (Optional) Number of elements in the color map. Default 256.
%    gam   - (Optional) Luminance, but not for rg or bw. Default 1.
%
% Outputs:
%    cm    - The color map to return
%
% Notes:
%    * [Note: XXX - (Copied from below) Check whether we want a gamma on
%      the r/g/b levels. Could be an option]
%

% History:
%    xx/xx/10       Copyright ImagEval Consultants, LLC, 2010
%    11/30/17  jnm  Formatting

% Examples:
%{
    rg  = ieCmap('rg', 256);
    plot(rg)
%}
%{
	by  = ieCmap('by', 256);
    plot(by)
%}
%{
	lum = ieCmap('bw', 256, 0.3);
    plot(lum)
%}

% [Note: XXX - Check whether we want a gamma on the r/g/b levels. Could be
% an option]
if notDefined('cName'), cName = 'rg'; end
if notDefined('num'), num = 256; end
if notDefined('gam'), gam = 1; end

cName = ieParamFormat(cName);

switch cName
    case {'redgreen', 'rg'}
        a = linspace(0, 1, num);
        cm = [a(:), flipud(a(:)), 0.5 * ones(size(a(:)))];
        
    case {'blueyellow', 'by'}
        a = linspace(0, 1, num);
        cm = [a(:), a(:), flipud(a(:))];
        
    case {'luminance', 'blackwhite', 'bw'}
        cm = gray(num) .^ gam;
        
    otherwise
        error('Unknown color map name %s\n', cName);
end

return