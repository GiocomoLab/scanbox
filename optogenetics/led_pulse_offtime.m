function r = led_pulse_offtime(T)

global led_controller

% Set the pulse mode brightness

if(~isempty(T))
    fprintf(led_controller,sprintf('SOURCE:PULSe:OFFTime %f',T));
    r = [];
else
    r = query(led_controller,'SOURCE:PULSe:OFFTime?');
    r=r(1:end-1);
end
