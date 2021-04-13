function r = speedbelt_read()

global speedbelt;

if speedbelt.BytesAvailable>0
    d = fread(speedbelt,speedbelt.BytesAvailable);
    %ix = find(d==88);
    iy = find(d==89);
    iy(end) = [];   % drop last one...
    %x = d(ix+1)+d(ix+2)*256;
    y = d(iy+1)+d(iy+2)*256;
    %fix = (x>=32767);
    %x(fix)= -(65536-x(fix));
    fix = (y>=32767);
    y(fix)= -(65536-y(fix));
    r = int32(sum(y));
else
    r = 0;
end
