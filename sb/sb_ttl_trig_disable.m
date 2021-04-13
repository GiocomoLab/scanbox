function r = sb_ttl_trig_enable

global sb;

fwrite(sb,uint8([hex2dec('e1') hex2dec('00') hex2dec('00')]));   
