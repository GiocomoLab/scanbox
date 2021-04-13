function GT2750_match(fps)

% Set exposure to match frame rate

global dalsa_src;
dalsa_src.ExposureTimeAbs = round(1/fps*1e6);
