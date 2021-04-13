function sb_trig_sel(val)

global sb;

fwrite(sb,uint8([hex2dec('e2') uint8(val) 0]));