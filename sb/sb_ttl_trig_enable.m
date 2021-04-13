function r = sb_ttl_trig_enable

global sb;

fwrite(sb,uint8([hex2dec('e0') hex2dec('00') hex2dec('00')]));   
