function r = sb_version

global sb;

fwrite(sb,uint8([hex2dec('78') hex2dec('aa') hex2dec('55')]));   
    
try
    q = fread(sb,3,'uint8');
    r = sprintf('%d.%d',q(2),q(3));
catch
    disp('Comunication failed!');
    r = 0;
end
