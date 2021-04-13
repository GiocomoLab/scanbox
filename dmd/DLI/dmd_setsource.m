
function sts = dmd_setsource(src)
% src can be
%   DVI,
% 	EXP,
% 	TPG,
% 	SL_AUTO,
% 	SL_EXT3P3,
% 	SL_EXT1P8,
% 	SL_SW,
    
sts = calllib('PortabilityLayer','DLP_Source_SetDataSource',src);

