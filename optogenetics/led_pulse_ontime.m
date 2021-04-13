function r = led_pulse_ontime(T)

global led_controller

% Set the pulse mode brightness

if(~isempty(T))
    fprintf(led_controller,sprintf('SOURCE:PULSe:ONTime %f',T));
    r = [];
else
    r = query(led_controller,'SOURCE:PULSe:ONTime?');
    r=r(1:end-1);
end
