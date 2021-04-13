function sb_set_mag_x_i(i,x)

global sb;

% assumes input is float with two significant digits xh.xl

xh = (floor(x));
xl = (floor((x-xh)*10));

fwrite(sb,uint8([hex2dec('b0')+i uint8(xh) uint8(xl)]));