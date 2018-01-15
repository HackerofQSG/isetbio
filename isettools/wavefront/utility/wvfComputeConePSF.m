function [conePsf, coneSceFraction] = wvfComputeConePSF(wvf)% Return cone PSF and cone SCE Fraction using a wavefront object with PSF%% Syntax:%   [conePsf, coneSceFraction] = wvfComputeConePSF(wvf)%% Description:%    This routine finds PSFs seen by each cone class under passed spectrum%    weightingSpectrum.  It gets these by taking a weighted sum of the%    monochromatic PSFs, where the weights are given by the product of the%    LMS spectral sensitivities and the weighting spectrum.%%    The returned psfs are normalized so that they sum to unity.  If you%    want to figure out the relative amount of light seen by each cone%    class, you need to take the spectral sensitivities into account and%    also the SCE if you're using that.%%    The routine also returns the weighted average of the monochromatic%    sceFraction entries for each cone type, to make knowing this easier.%    We still need to do some conceptual thinking about exactly what this%    quantity means and how to use it.%%    If you actually know the hyperspectral image input, you probably don't%    want to use this routine. Rather, compute the monochromatic PSFs at%    each wavelength and do your optical blurring in the wavelength domain,%    before computing cone absorbtions.  Doing so is a more accurate model%    of the physics. You would use this routine under two circumstances.%    First, you might know that the image consists only of intensity%    modulations of a single relative spectrum.  In this case, you could%    use that spectrum here and speed things up, since you'd only have to%    convolve three times (one for each cone class rather than once for%    each wavelength).  This case corresponds, for example, to%    psychophysics where achromatic contrast is manipulated. Second, you%    might only know the unblurred LMS images and not have spectral data.%    Then, this routine is useful for providing an approximation to the%    blurring that will occur for each cone class. For example, your data%    might originate with a high-resolution RGB camera image, which was%    then used to estimate LMS values at each location. Keep in mind that%    what you get in that case is only an approximation, since the actual%    blur depends on the full spectral image.% %    If you want to compute a strehl ratio quantity for the LMS psfs, the%    most straightforward way is to call this routine a second time using a%    zcoeffs vector of all zeros.  This leads to computation of diffraction%    limited monochromatic psfs that are then summed just like the%    specified ones.  Taking the ratios of the peaks then gives you a%    fairly meaningful figure of merit.%% Inputs:%    wvf             - The wavefront object (with PSF already calculated)%% Outputs:%    conePSF         - The normalized cone PSFs.  This is returned as a%                      matrix, with the third dimension indexing cone type.%                      Cone types are specified by the spectral sensitivies%                      in the wvf structures conePsfInfo structure:%                      wvfGet(wvf,'calc cone psf info');%    coneSceFraction - Weighted average of the monochromatic SCE fraction%% Optional key/value pairs:%    None.%% Examples are provided in the code.%% See Also:%    wvfComputePSF, conePsfInfoCreate, conePsfInfoGet%% History:%    07/13/07  dhb  Made into a callable function, based on code provided%                   by Heidi Hofer. Remove globals, fix case of fft, get%                   rid of some vars we don't care about. Don't write files%                   here, optional plot supression.%    07/14/07  dhb  Change name a little.%    12/22/09  dhb  Return monochromatic PSFs as a cell array%    xx/xx/11       (c) Wavefront Toolbox Team 2011, 2012%    08/21/11  dhb  Update%    09/07/11  dhb  Rename.  Use wvf for i/o.%    07/20/12  dhb  Got this to run again in its modern form.%    11/10/17  jnm  Formatting% Examples:%{    % Compute cone weighted PSFs using default parameters for conePsfInfo.    wvf = wvfCreate('wave',400:10:700);    wvf = wvfComputePSF(wvf);    [cPSF, cSceFrac] = wvfComputeConePSF(wvf);    % Look how blurry that S cone PSF is, even for the diffraction limited    % case!    figure; clf; hold on    [m,n,k] = size(cPSF);    plot(cPSF(floor(m/2)+1,:,1)/max(cPSF(floor(m/2)+1,:,1)),'r','LineWidth',3);    plot(cPSF(floor(m/2)+1,:,2)/max(cPSF(floor(m/2)+1,:,2)),'g','LineWidth',2);    plot(cPSF(floor(m/2)+1,:,3)/max(cPSF(floor(m/2)+1,:,3)),'b','LineWidth',1);    xlim([0 201]); xlabel('Position (arbitrary units'); ylabel('Cone PSF');%}%% Get wavelengthswls = wvfGet(wvf, 'calc wavelengths');nWls = length(wls);% Need to use S so that spline of spectral weighting% won't crash out if just a single wavelength is used.% Since weighting vector is normalized, we can use any% delta lambda that isn't zero.  Just use 1.if (length(wls(:) == 1))    S = [wls(1) 1 1];else    S = WlsToS(wls);end%% Get weighted cone fundamentals, and normalize each weighting function.conePsfInfo = wvfGet(wvf,'calc cone psf info');T = SplineCmf(conePsfInfoGet(conePsfInfo,'wavelengths'),conePsfInfoGet(conePsfInfo,'spectralSensitivities'),wls);spdWeighting = SplineSpd(conePsfInfoGet(conePsfInfo,'wavelengths'), conePsfInfoGet(conePsfInfo,'spectralWeighting'), S);spdWeighting = spdWeighting/sum(spdWeighting);nCones = size(T, 1);coneWeight = zeros(nCones, nWls);for j = 1:nCones    coneWeight(j, :) = T(j, :) .* spdWeighting';    coneWeight(j, :) = coneWeight(j, :)/sum(coneWeight(j, :));end%% Get psfs for each wavelength.  This comes back as a cell% array unless there is only one wavelength. psf = wvfGet(wvf, 'psf');%% Get fraction of light at each wavelength lost to scesceFraction = wvfGet(wvf, 'sce fraction', wls);%% Weight up cone psfs%% Need to handle case of one wavelength separately because this doesn't% come back as a cell array.if (nWls == 1)    [m, n] = size(psf);    conePsf = zeros(m, n, nCones);    for j = 1:nCones        conePsf(:, :, j) = sceFraction * coneWeight(j) * psf;    endelse    [m, n] = size(psf{1});    conePsf = zeros(m, n, nCones);    for j = 1:nCones        for wl = 1:nWls            [m1, n1] = size(psf{wl});            if (m1 ~= m || n1 ~= n)                error(['Pixel size of individual wavelength PSFs does '...                    'not match']);            end            conePsf(:, :, j) = conePsf(:, :, j) + ...                sceFraction(wl) * coneWeight(j, wl) * psf{wl};        end    endend% Normalize each PSF to unit volume.for j = 1:nCones    conePsf(:, :, j) = conePsf(:, :, j) / sum(sum(conePsf(:, :, j)));end% Get sceFraction for each cone typefor j = 1:nCones    coneSceFraction(j, :) = coneWeight(j, :) .* sceFraction';end