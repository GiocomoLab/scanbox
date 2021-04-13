function pco_match(fps)

% Set exposure to a fraction of the maximum

global dalsa_src;
dalsa_src.E2ExposureTime = round(1/fps*1e6);
