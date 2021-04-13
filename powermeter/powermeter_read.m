function pow = powermeter_read

global pmeter

if(isempty(pmeter))
    pow = NaN;
else
    pow = 1e10;
    while(pow>100)
        str = query(pmeter,'READ?');
        pow = str2double(str);
    end
end

