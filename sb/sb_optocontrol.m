function sb_optocontrol(vals)

global sb;

vals = uint16(vals);             % make sure they are uint16

fwrite(sb,uint8([35 0 0]));     % first set the optoctrl index to zero (and make the entire optoctrl array zero)

for i=0:length(vals)-1          % send the values (length(vals)<2048 which is max number of lines 
        b = typecast(vals(i+1),'uint8');
        fwrite(sb,uint8([25 b(2) b(1)]));
end



