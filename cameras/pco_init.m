
% init for pco camera

global dalsa_src;

dalsa_src = getselectedsource(dalsa);
dalsa_src.B1BinningHorizontal = '4';
dalsa_src.B2BinningVertical= '4';
dalsa_src.E2ExposureTime = 66666;   % 15 fps
