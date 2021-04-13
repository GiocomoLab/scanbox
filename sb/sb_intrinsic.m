function sb_intrinsic(val)

global sb T;

T = uint8([]);              % reset timestamps
if(val)
    fwrite(sb,uint8([hex2dec('f0') 1 0]));   
else
    fwrite(sb,uint8([hex2dec('f0') 0 0]));
end


