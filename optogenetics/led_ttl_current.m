function r = led_ttl_current(current)

global led_controller

% Set the LED current 

if(~isempty(current))
    fprintf(led_controller,sprintf('SOURCE:TTL:CURRent:AMPLitude %f',current));
    r = [];
else
    r = query(led_controller,'SOURCE:TTL:CURRent:AMPLitude?');
    r=r(1:end-1);
end
