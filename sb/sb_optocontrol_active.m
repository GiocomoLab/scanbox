function sb_optocontrol_active(x)

global sb;

% set optotune active (1) or inactive (0)

fwrite(sb,uint8([36 x 0]));
