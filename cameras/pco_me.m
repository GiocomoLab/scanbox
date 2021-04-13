function pco_me(x)

% Set exposure to a fraction of the maximum

global dalsa_src;
dalsa_src.E2ExposureTime = round(100000 * x);