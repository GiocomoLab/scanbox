function r = led_pulse_brightness(level)

global led_controller

% Set the pulse mode brightness

if(~isempty(level))
    fprintf(led_controller,sprintf('SOURCE:PULSe:BRIGhtness:AMPLitude %f',level));
    r = [];
else
    r = query(led_controller,'SOURCE:PULSe:BRIGhtness:AMPLitude?');
    r=r(1:end-1);
end
