function sb_optowave_sawtooth(m,M,period)

% values between 0 and 4095

global sb otwave otwave_um;

global sbconfig;

vals = linspace(m,M,period);
vals = uint16(vals);
otwave = vals;
otwave_um = [];

if(~isempty(sbconfig.optocal))
    otwave_um = otwave;
    for(j=1:length(vals))
        d = abs(double(sbconfig.optolut)-double(vals(j)));
        m = min(d);
        k = find(d==m);
        otwave(j) = round(mean(k));
    end
    otwave = uint16(otwave);
    vals = otwave;
end


sb_optowave_init;

for(i=0:period-1)
    b = typecast(vals(i+1),'uint8');
    sb_optowave(b(2),b(1));
end

sb_optoperiod(period);

